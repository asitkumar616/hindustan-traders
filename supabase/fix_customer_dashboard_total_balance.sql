-- ============================================================
-- OdiaTraders: fix customer_dashboard_summary()'s total_balance, which
-- compared invoices.customer_id (a customers.id row, one per business a
-- customer shops with) directly to auth.uid() (the profiles.id/auth user).
-- Those are different id spaces, so the comparison never matched. Joins
-- through customers.profile_id = auth.uid() instead, the same pattern
-- customer_my_businesses() already uses correctly.
-- Safe to re-run (create or replace).
-- ============================================================
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
    (select count(*) from orders o where o.customer_id = auth.uid())::bigint,
    (select coalesce(sum(o.total_amount), 0) from orders o where o.customer_id = auth.uid()),
    (select count(*) from orders o where o.customer_id = auth.uid()
       and (o.created_at at time zone 'Asia/Kolkata') >= date_trunc('day', now() at time zone 'Asia/Kolkata'))::bigint,
    (select coalesce(sum(o.total_amount), 0) from orders o where o.customer_id = auth.uid()
       and (o.created_at at time zone 'Asia/Kolkata') >= date_trunc('day', now() at time zone 'Asia/Kolkata')),
    (select coalesce(sum(i.balance_amount), 0) from invoices i
       join customers c on c.id = i.customer_id
       where c.profile_id = auth.uid() and i.status <> 'paid');
end;
$$;
