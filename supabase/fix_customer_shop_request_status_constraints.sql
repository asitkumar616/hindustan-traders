-- ============================================================
-- OdiaTraders: add_customer_shop_request_flow.sql writes 'PENDING' and
-- 'REJECTED' into customers.status and customer_businesses.status, but
-- neither column's check constraint allows those values yet (customers:
-- NOT_REGISTERED/ACTIVE/BLOCKED only; customer_businesses: ACTIVE/BLOCKED
-- only). CREATE FUNCTION succeeds regardless, but customer_request_shop_
-- access() / owner_respond_to_shop_request() / customer_pending_shop_
-- requests() would fail at runtime with a check-constraint violation the
-- first time anyone actually uses the request-to-join flow.
-- Widens both constraints to include the two new values. Additive only --
-- existing rows (all already NOT_REGISTERED/ACTIVE/BLOCKED) are unaffected.
-- Safe to re-run.
-- ============================================================

alter table customers drop constraint if exists customers_status_check;
alter table customers add constraint customers_status_check
  check (status in ('NOT_REGISTERED', 'ACTIVE', 'BLOCKED', 'PENDING', 'REJECTED'));

alter table customer_businesses drop constraint if exists customer_businesses_status_check;
alter table customer_businesses add constraint customer_businesses_status_check
  check (status in ('ACTIVE', 'BLOCKED', 'PENDING', 'REJECTED'));
