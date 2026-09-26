-- ============================================================
-- OdiaTraders: MVP payment flow (UPI stub + Cash on Delivery).
-- Additive only. No existing table recreated. Safe to re-run.
-- ============================================================

-- ----------------------------------------------------------
-- 1. New columns on orders (existing rows default to pending/null,
--    nothing currently reads these so no existing behavior changes).
-- ----------------------------------------------------------
alter table orders add column if not exists payment_method text;
alter table orders add column if not exists payment_status text not null default 'pending';
alter table orders add column if not exists payment_reference text;
alter table orders add column if not exists paid_at timestamptz;

alter table orders drop constraint if exists orders_payment_method_check;
alter table orders add constraint orders_payment_method_check
  check (payment_method is null or payment_method in ('upi', 'cash_on_delivery'));

alter table orders drop constraint if exists orders_payment_status_check;
alter table orders add constraint orders_payment_status_check
  check (payment_status in ('pending', 'paid', 'failed'));


-- ----------------------------------------------------------
-- 2. Customer sets/changes the payment method on their own order --
--    used both at initial checkout and when switching COD after a
--    failed/abandoned UPI attempt. Never touches total_amount or
--    business_id -- those are looked up, not trusted from the client.
-- ----------------------------------------------------------
create or replace function customer_set_order_payment_method(p_order_id uuid, p_payment_method text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_customer_id uuid;
  v_current_status text;
begin
  if p_payment_method not in ('upi', 'cash_on_delivery') then
    raise exception 'Invalid payment method: %', p_payment_method;
  end if;

  select customer_id, payment_status into v_customer_id, v_current_status
  from orders where id = p_order_id;

  if v_customer_id is null then
    raise exception 'Order not found.';
  end if;

  if v_customer_id <> auth.uid() then
    raise exception 'Not authorized to update this order.';
  end if;

  if v_current_status = 'paid' then
    raise exception 'This order is already paid.';
  end if;

  update orders
  set payment_method = p_payment_method,
      payment_status = case when p_payment_method = 'cash_on_delivery' then 'pending' else payment_status end
  where id = p_order_id;
end;
$$;


-- ----------------------------------------------------------
-- 3. Owner confirms a COD payment was physically received. Atomic and
--    idempotent -- a second tap on an already-paid order is a no-op,
--    not an error and not a double-credit. Authorization + business_id
--    are derived from the order row itself, never trusted from the client.
-- ----------------------------------------------------------
create or replace function owner_confirm_cod_payment(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_business_id uuid;
  v_payment_method text;
  v_payment_status text;
  v_caller_is_member boolean;
begin
  select business_id, payment_method, payment_status
    into v_business_id, v_payment_method, v_payment_status
  from orders where id = p_order_id;

  if v_business_id is null then
    raise exception 'Order not found.';
  end if;

  select exists (
    select 1 from business_members bm
    where bm.business_id = v_business_id and bm.user_id = auth.uid() and bm.status = 'active'
  ) into v_caller_is_member;

  if not v_caller_is_member then
    raise exception 'Not authorized to confirm payment for this order.';
  end if;

  if v_payment_method is distinct from 'cash_on_delivery' then
    raise exception 'Only Cash on Delivery orders can be manually confirmed.';
  end if;

  if v_payment_status = 'paid' then
    return; -- already confirmed, idempotent no-op (guards double-tap)
  end if;

  update orders
  set payment_status = 'paid', paid_at = now()
  where id = p_order_id;
end;
$$;
