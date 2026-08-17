-- Fix: "infinite recursion detected in policy for relation business_members" (42P17)
--
-- business_members had two RLS policies that checked membership by querying
-- business_members itself:
--
--   create policy "business_members_select_business_member" on business_members
--   for select using (
--     exists (select 1 from business_members current_member where ...)
--   );
--
-- Any access to business_members (directly, or indirectly -- e.g. customers'
-- own RLS policy does `exists (select 1 from business_members bm where ...)`)
-- re-triggers business_members' own policy, which re-queries business_members,
-- which re-triggers the policy again. Postgres detects this as unbounded
-- recursion and rejects the query outright.
--
-- Fix: move the membership check into a `security definer` function. Such a
-- function executes as its owner (the table owner in a normal Supabase
-- project), and table owners bypass RLS on their own tables by default, so
-- the function's internal query does not re-invoke the policy it's used by.
-- This only touches business_members' two policies -- no other table's
-- policies, no schema/data changes, nothing dropped or recreated elsewhere.

create or replace function public.is_active_business_member(p_business_id uuid, p_roles text[] default null)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = p_business_id
      and bm.status = 'active'
      and (p_roles is null or bm.role = any(p_roles))
  );
$$;

grant execute on function public.is_active_business_member(uuid, text[]) to authenticated;

drop policy if exists "business_members_select_business_member" on business_members;
create policy "business_members_select_business_member" on business_members
for select using (
  public.is_active_business_member(business_members.business_id)
);

drop policy if exists "business_members_manage_own_business" on business_members;
create policy "business_members_manage_own_business" on business_members
for all using (
  public.is_active_business_member(business_members.business_id, array['owner'])
) with check (
  public.is_active_business_member(business_members.business_id, array['owner'])
);
