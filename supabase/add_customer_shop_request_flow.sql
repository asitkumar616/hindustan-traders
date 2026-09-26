-- ============================================================
-- OdiaTraders: customer-initiated "Request to Join Shop" flow.
-- Additive only. Safe to re-run (create or replace / drop if exists).
-- ============================================================

-- ----------------------------------------------------------
-- 1. Directory: every active business, plus the calling customer's
--    existing relationship status with it (null if none yet).
-- ----------------------------------------------------------
create or replace function customer_business_directory()
returns table(business_id uuid, business_name text, business_address text, relationship_status text)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return query
  select
    b.id,
    b.name,
    b.address,
    (
      select cb.status from customer_businesses cb
      join customers c on c.id = cb.customer_id
      where c.profile_id = auth.uid() and cb.business_id = b.id
      limit 1
    )
  from businesses b
  where b.status = 'active'
  order by b.name asc;
end;
$$;


-- ----------------------------------------------------------
-- 2. Customer sends a request to join a shop. Creates (or reuses) the
--    customers row for this (business, phone) pair and marks it PENDING.
--    Blocks duplicate requests while one is PENDING or already ACTIVE;
--    a prior REJECTED request can be re-sent.
-- ----------------------------------------------------------
create or replace function customer_request_shop_access(p_business_id uuid)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_phone text;
  v_name text;
  v_customer_id uuid;
  v_existing_status text;
  v_owner_id uuid;
begin
  select phone, name into v_phone, v_name from profiles where id = auth.uid();
  if v_phone is null then
    raise exception 'Profile not found for current user.';
  end if;

  select c.id, cb.status into v_customer_id, v_existing_status
  from customers c
  left join customer_businesses cb on cb.customer_id = c.id and cb.business_id = p_business_id
  where c.business_id = p_business_id and c.phone = v_phone
  limit 1;

  if v_existing_status in ('PENDING', 'ACTIVE') then
    raise exception 'A request already exists for this shop (status: %).', v_existing_status;
  end if;

  if v_customer_id is null then
    insert into customers (business_id, phone, display_name, customer_name, profile_id, status, is_active)
    values (p_business_id, v_phone, v_name, v_name, auth.uid(), 'PENDING', false)
    returning id into v_customer_id;
  else
    update customers set status = 'PENDING', is_active = false, profile_id = auth.uid() where id = v_customer_id;
  end if;

  insert into customer_businesses (customer_id, business_id, status)
  values (v_customer_id, p_business_id, 'PENDING')
  on conflict (customer_id, business_id) do update set status = 'PENDING';

  select owner_id into v_owner_id from businesses where id = p_business_id;
  if v_owner_id is not null then
    insert into notifications (recipient_id, business_id, title, body, data)
    values (
      v_owner_id,
      p_business_id,
      'New shop access request',
      coalesce(v_name, 'A customer') || ' requested access to your shop.',
      jsonb_build_object('customer_id', v_customer_id)
    );
  end if;
end;
$$;


-- ----------------------------------------------------------
-- 3. Customer's own pending/rejected requests, for the "Pending" section
--    on My Shops. (Active ones already come from customer_my_businesses.)
-- ----------------------------------------------------------
create or replace function customer_pending_shop_requests()
returns table(business_id uuid, business_name text, status text, requested_at timestamptz)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  return query
  select b.id, b.name, cb.status, cb.created_at
  from customer_businesses cb
  join customers c on c.id = cb.customer_id
  join businesses b on b.id = cb.business_id
  where c.profile_id = auth.uid() and cb.status in ('PENDING', 'REJECTED')
  order by cb.created_at desc;
end;
$$;


-- ----------------------------------------------------------
-- 4. Owner approves/rejects a pending request. Self-contained
--    authorization check -- no new RLS policy needed.
-- ----------------------------------------------------------
create or replace function owner_respond_to_shop_request(p_customer_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_business_id uuid;
  v_profile_id uuid;
  v_customer_name text;
  v_caller_is_member boolean;
begin
  select business_id, profile_id, coalesce(display_name, customer_name, 'Customer')
    into v_business_id, v_profile_id, v_customer_name
  from customers where id = p_customer_id;

  if v_business_id is null then
    raise exception 'Customer request not found.';
  end if;

  select exists (
    select 1 from business_members bm
    where bm.business_id = v_business_id and bm.user_id = auth.uid() and bm.status = 'active'
  ) into v_caller_is_member;

  if not v_caller_is_member then
    raise exception 'Not authorized to respond to this request.';
  end if;

  if p_approve then
    update customers set status = 'ACTIVE', is_active = true where id = p_customer_id;
    update customer_businesses set status = 'ACTIVE' where customer_id = p_customer_id and business_id = v_business_id;
  else
    update customers set status = 'REJECTED', is_active = false where id = p_customer_id;
    update customer_businesses set status = 'REJECTED' where customer_id = p_customer_id and business_id = v_business_id;
  end if;

  if v_profile_id is not null then
    insert into notifications (recipient_id, business_id, title, body, data)
    values (
      v_profile_id,
      v_business_id,
      case when p_approve then 'Shop request approved' else 'Shop request declined' end,
      case when p_approve then 'Your request to join has been approved. You can now shop here.'
           else 'Your request to join this shop was declined.' end,
      jsonb_build_object('business_id', v_business_id)
    );
  end if;
end;
$$;

-- ============================================================
-- One assumption to flag: this filters the directory to
-- businesses.status = 'active' -- if your businesses actually use a
-- different status value (e.g. 'approved'), tell Claude after running
-- this and it'll adjust. Also assumes customer_businesses has a unique
-- constraint on (customer_id, business_id) (used by the ON CONFLICT
-- clause) and a created_at column.
-- ============================================================
