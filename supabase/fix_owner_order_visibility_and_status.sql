-- Fix: (1) owner could not see WHO placed an order, and (2) there was no
-- way to approve a pending order or close a ready/packed one.
--
-- Root cause of (1): the only SELECT policy on `profiles` was
-- `profiles_select_own` (auth.uid() = id). When the owner's order list
-- query embeds `profiles` via the orders.customer_id foreign key, RLS
-- silently blocked the customer's profile row, so the app fell back to
-- the literal "Customer" placeholder.
--
-- Root cause of (2): `orders.status` had no allowed-values constraint and
-- the app only ever wrote 'pending'. There was no status beyond it to
-- transition into, so no "approve"/"close" action could exist. This adds
-- 'ready' and 'completed' as the next two states (pending -> ready ->
-- completed), matching UI strings already shipped in the translation
-- files (owner_orders_mark_ready / owner_orders_mark_complete) but never
-- wired up.

-- (1) Let a business owner/staff member see the profile of any other
-- active member of the same business (this covers customers, since
-- customers get a business_members row with role='customer' on signup).
drop policy if exists "profiles_select_business_member" on profiles;
create policy "profiles_select_business_member" on profiles
for select using (
  exists (
    select 1
    from business_members bm_self
    join business_members bm_target
      on bm_target.business_id = bm_self.business_id
    where bm_self.user_id = auth.uid()
      and bm_self.status = 'active'
      and bm_self.role in ('owner', 'staff')
      and bm_target.user_id = profiles.id
      and bm_target.status = 'active'
  )
);

-- (2) Constrain orders.status to the known workflow values. Safe to add
-- now since every existing row is 'pending'.
alter table orders drop constraint if exists orders_status_check;
alter table orders add constraint orders_status_check
  check (status in ('pending', 'ready', 'completed'));
