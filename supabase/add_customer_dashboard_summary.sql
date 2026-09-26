-- ============================================================
-- OdiaTraders: customer dashboard summary (spending + balance).
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
    (select coalesce(sum(i.balance_amount), 0) from invoices i where i.customer_id = auth.uid() and i.status <> 'paid');
end;
$$;
