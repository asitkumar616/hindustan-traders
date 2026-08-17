-- Adds two new owner-scoped, read-only RPCs backing the Owner Dashboard
-- (Phase 1): summary cards + the customer/outstanding-balance drill-down.
-- Neither existed before -- these are new functions, not replacements.
--
-- Both derive business_id from the caller's own active business_members
-- row (never from a parameter), so an owner can never query another
-- owner's data by passing a different business id. Both are security
-- definer, same pattern as the existing admin_* functions, since the
-- aggregation queries need to read across customers/invoices regardless of
-- which RLS policy would otherwise apply to the caller.

create or replace function owner_dashboard_summary()
returns table (
  business_id uuid,
  business_name text,
  total_customers bigint,
  today_orders bigint,
  today_revenue numeric,
  pending_amount numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  select bm.business_id into v_business_id
  from business_members bm
  where bm.user_id = auth.uid()
    and bm.role = 'owner'
    and bm.status = 'active'
  order by bm.created_at asc
  limit 1;

  if v_business_id is null then
    raise exception 'No active business found for the current owner.';
  end if;

  return query
  select
    b.id as business_id,
    b.name as business_name,
    (select count(*) from customers c where c.business_id = b.id and c.is_active = true)::bigint as total_customers,
    (select count(*) from invoices i where i.business_id = b.id and i.status <> 'draft' and i.created_at >= date_trunc('day', now()))::bigint as today_orders,
    (select coalesce(sum(i.total), 0) from invoices i where i.business_id = b.id and i.status <> 'draft' and i.created_at >= date_trunc('day', now())) as today_revenue,
    (select coalesce(sum(i.balance_amount), 0) from invoices i where i.business_id = b.id and i.status <> 'paid') as pending_amount
  from businesses b
  where b.id = v_business_id;
end;
$$;

create or replace function owner_customer_balances(p_only_outstanding boolean default false)
returns table (
  customer_id uuid,
  display_name text,
  phone text,
  status text,
  is_active boolean,
  outstanding_amount numeric,
  last_order_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  select bm.business_id into v_business_id
  from business_members bm
  where bm.user_id = auth.uid()
    and bm.role = 'owner'
    and bm.status = 'active'
  order by bm.created_at asc
  limit 1;

  if v_business_id is null then
    raise exception 'No active business found for the current owner.';
  end if;

  return query
  select
    c.id as customer_id,
    c.display_name,
    c.phone,
    c.status,
    c.is_active,
    coalesce((select sum(i.balance_amount) from invoices i where i.customer_id = c.id and i.status <> 'paid'), 0) as outstanding_amount,
    (select max(i.created_at) from invoices i where i.customer_id = c.id) as last_order_at
  from customers c
  where c.business_id = v_business_id
    and (
      p_only_outstanding = false
      or coalesce((select sum(i2.balance_amount) from invoices i2 where i2.customer_id = c.id and i2.status <> 'paid'), 0) > 0
    )
  order by c.created_at desc;
end;
$$;

grant execute on function owner_dashboard_summary() to authenticated;
grant execute on function owner_customer_balances(boolean) to authenticated;
