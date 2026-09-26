-- ============================================================
-- OdiaTraders: make Today's Revenue payment-aware (paid orders only)
-- and add Pending COD. Return type changed (new pending_cod column),
-- so the function must be dropped first -- this only removes the
-- function definition, not any data.
--
-- Depends on add_payment_flow.sql (orders.payment_method /
-- payment_status columns) -- run that one first.
-- ============================================================
DROP FUNCTION IF EXISTS owner_dashboard_summary();

CREATE FUNCTION public.owner_dashboard_summary()
 RETURNS TABLE(business_id uuid, business_name text, total_customers bigint, today_orders bigint, today_revenue numeric, pending_amount numeric, pending_cod numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_business_id uuid;
begin
  select bm.business_id into v_business_id from business_members bm
  where bm.user_id = auth.uid() and bm.role = 'owner' and bm.status = 'active'
  order by bm.created_at asc limit 1;
  if v_business_id is null then raise exception 'No active business found for the current owner.'; end if;

  return query
  select
    b.id,
    b.name,
    (select count(*) from customers c where c.business_id = b.id)::bigint,
    (select count(*) from orders o where o.business_id = b.id
       and (o.created_at at time zone 'Asia/Kolkata') >= date_trunc('day', now() at time zone 'Asia/Kolkata'))::bigint,
    (select coalesce(sum(o.total_amount), 0) from orders o where o.business_id = b.id
       and o.payment_status = 'paid'
       and (o.created_at at time zone 'Asia/Kolkata') >= date_trunc('day', now() at time zone 'Asia/Kolkata')),
    (select coalesce(sum(i.balance_amount), 0) from invoices i where i.business_id = b.id and i.status <> 'paid'),
    (select coalesce(sum(o.total_amount), 0) from orders o where o.business_id = b.id
       and o.payment_method = 'cash_on_delivery' and o.payment_status = 'pending'
       and (o.created_at at time zone 'Asia/Kolkata') >= date_trunc('day', now() at time zone 'Asia/Kolkata'))
  from businesses b where b.id = v_business_id;
end;
$function$;
