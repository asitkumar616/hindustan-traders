-- ============================================================
-- Fix: a customer's older orders (e.g. a year-old order) silently
-- disappear from "My Orders" / the Transaction Overview chart after
-- their anonymous Supabase session is replaced (app reinstall, cleared
-- app data, a long-expired session renewing on next login, a new
-- device). This is NOT a missing-data bug -- the orders are still in
-- the table -- it's an identity-matching gap in RLS.
--
-- Root cause: mvp_login_with_phone() authenticates via Supabase
-- anonymous auth, so each fresh session gets its OWN auth.uid(). On
-- every login it finds the real customer by phone number and copies
-- their role/name/business onto a profiles row at the CURRENT auth.uid()
-- (creating one if needed) -- but orders.customer_id is stamped with
-- whichever auth.uid() was active at the moment each order was placed,
-- and never gets updated afterward. `orders.customer_id = auth.uid()`
-- then only ever matches orders from the CURRENT session's identity,
-- hiding every order placed under a previous one.
--
-- mvp_login_with_phone already tracks exactly this: mvp_identity_links
-- (auth_user_id, profile_id) maps every session's auth.uid() to the
-- same stable profile_id (the original profile found by real phone
-- number, which synthetic per-session rows never match). This migration
-- uses that existing table to resolve "every auth.uid() this real
-- person has ever used" and broadens order visibility to all of them --
-- additive only, no data is modified, existing policies for owners/
-- staff are untouched.
-- ============================================================

create or replace function my_auth_identity_ids()
returns setof uuid
language sql
stable
security definer
set search_path = public
as $$
  select auth_user_id from mvp_identity_links
  where profile_id = coalesce(
    (select profile_id from mvp_identity_links where auth_user_id = auth.uid()),
    auth.uid()
  )
  union
  select auth.uid();
$$;

grant execute on function my_auth_identity_ids() to authenticated;

drop policy if exists "orders_select_business_member_or_customer" on orders;
create policy "orders_select_business_member_or_customer" on orders
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = orders.business_id
      and bm.status = 'active'
  )
  or customer_id in (select my_auth_identity_ids())
);

drop policy if exists "order_items_select_related" on order_items;
create policy "order_items_select_related" on order_items
for select using (
  exists (
    select 1 from orders o
    where o.id = order_items.order_id
      and (
        o.customer_id in (select my_auth_identity_ids())
        or exists (
          select 1 from business_members bm
          where bm.user_id = auth.uid()
            and bm.business_id = o.business_id
            and bm.status = 'active'
        )
      )
  )
);

-- Same bug, same fix, in the dashboard summary RPC (today's/total
-- orders+spend). The invoices/total_balance subquery is untouched --
-- it already joins through customers.profile_id, which mvp_login_with_phone
-- keeps pointed at the current session on every login, so it was never
-- affected by this.
create or replace function customer_dashboard_summary()
returns table(
  total_orders bigint,
  total_spent numeric,
  today_orders bigint,
  today_spent numeric,
  total_balance numeric
)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return query
  select
    (select count(*) from orders o where o.customer_id in (select my_auth_identity_ids()))::bigint,
    (select coalesce(sum(o.total_amount), 0) from orders o where o.customer_id in (select my_auth_identity_ids())),
    (select count(*) from orders o where o.customer_id in (select my_auth_identity_ids())
       and (o.created_at at time zone 'Asia/Kolkata') >= date_trunc('day', now() at time zone 'Asia/Kolkata'))::bigint,
    (select coalesce(sum(o.total_amount), 0) from orders o where o.customer_id in (select my_auth_identity_ids())
       and (o.created_at at time zone 'Asia/Kolkata') >= date_trunc('day', now() at time zone 'Asia/Kolkata')),
    (select coalesce(sum(i.balance_amount), 0) from invoices i
       join customers c on c.id = i.customer_id
       where c.profile_id = auth.uid() and i.status <> 'paid');
end;
$$;

-- Note: orders_insert_customer_own / order_items_insert_customer_own are
-- deliberately left as `customer_id = auth.uid()` -- a NEW order should
-- always be stamped with the session placing it right now, not broadened.
