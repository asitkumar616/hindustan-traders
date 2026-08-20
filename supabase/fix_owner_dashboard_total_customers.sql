-- Fix: owner_dashboard_summary() counted total_customers as only those
-- with is_active = true. is_active is only flipped to true once a
-- customer registers/logs in (see linkCustomerAfterOtp), so customers
-- added by the owner but not yet registered were invisible on the
-- landing page, even though the insert succeeded. total_customers should
-- count every customer in the business, matching admin_dashboard_summary's
-- distinction between total_customers (all) and active_customers (registered).

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
    (select count(*) from customers c where c.business_id = b.id)::bigint as total_customers,
    (select count(*) from invoices i where i.business_id = b.id and i.status <> 'draft' and i.created_at >= date_trunc('day', now()))::bigint as today_orders,
    (select coalesce(sum(i.total), 0) from invoices i where i.business_id = b.id and i.status <> 'draft' and i.created_at >= date_trunc('day', now())) as today_revenue,
    (select coalesce(sum(i.balance_amount), 0) from invoices i where i.business_id = b.id and i.status <> 'paid') as pending_amount
  from businesses b
  where b.id = v_business_id;
end;
$$;
