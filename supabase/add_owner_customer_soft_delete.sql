-- ============================================================
-- OdiaTraders: soft-delete for Owner and Customer accounts (Admin panel).
--
-- Deliberately NOT a hard delete: an owner's products/orders/invoices and
-- a customer's order history stay fully intact and attributable forever.
-- "Delete" here means: the account can no longer log in, their business
-- (for an owner) or customer relationship (for a customer) stops being
-- active/visible, and nothing referencing them is touched. Fully
-- reversible via Restore.
--
-- Distinct from the existing Activate/Deactivate: deactivating is a
-- temporary suspension that still shows up as "Inactive" in the list;
-- deleting is the stronger, more final action an admin reaches for when
-- an account should stop existing in all the ways that matter, without
-- destroying the financial/audit trail it's part of.
-- ============================================================

alter table profiles add column if not exists deleted_at timestamptz;
alter table customers add column if not exists deleted_at timestamptz;

-- ----------------------------------------------------------
-- Owner delete/restore. Deleting also suspends their business(es) (reusing
-- the businesses.status check constraint's existing 'suspended' value,
-- which nothing else currently sets) and deactivates their business_members
-- rows, so a deleted owner can't act on any business they own even if
-- their session is still technically authenticated.
-- ----------------------------------------------------------
create or replace function admin_delete_owner(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  update profiles
  set deleted_at = now(), is_active = false, updated_at = now()
  where id = p_profile_id and role = 'owner';

  update businesses
  set status = 'suspended', updated_at = now()
  where owner_id = p_profile_id;

  update business_members
  set status = 'inactive', updated_at = now()
  where user_id = p_profile_id;
end;
$$;

create or replace function admin_restore_owner(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  update profiles
  set deleted_at = null, is_active = true, updated_at = now()
  where id = p_profile_id and role = 'owner';

  update businesses
  set status = 'active', updated_at = now()
  where owner_id = p_profile_id;

  update business_members
  set status = 'active', updated_at = now()
  where user_id = p_profile_id;
end;
$$;

grant execute on function admin_delete_owner(uuid) to authenticated;
grant execute on function admin_restore_owner(uuid) to authenticated;

-- ----------------------------------------------------------
-- Customer delete/restore. A customer can shop with multiple businesses
-- (one `customers` row each), so this only removes the ONE business
-- relationship the admin is looking at -- not the person's whole account.
-- ----------------------------------------------------------
create or replace function admin_delete_customer(p_customer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
  v_profile_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  select business_id, profile_id into v_business_id, v_profile_id
  from customers where id = p_customer_id;

  if v_business_id is null then
    raise exception 'Customer not found.';
  end if;

  update customers
  set deleted_at = now(), is_active = false, status = 'BLOCKED', updated_at = now()
  where id = p_customer_id;

  update customer_businesses
  set status = 'BLOCKED', updated_at = now()
  where customer_id = p_customer_id and business_id = v_business_id;

  if v_profile_id is not null then
    update business_members
    set status = 'inactive', updated_at = now()
    where user_id = v_profile_id and business_id = v_business_id;
  end if;
end;
$$;

create or replace function admin_restore_customer(p_customer_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
  v_profile_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  select business_id, profile_id into v_business_id, v_profile_id
  from customers where id = p_customer_id;

  if v_business_id is null then
    raise exception 'Customer not found.';
  end if;

  update customers
  set deleted_at = null, is_active = true, status = 'ACTIVE', updated_at = now()
  where id = p_customer_id;

  update customer_businesses
  set status = 'ACTIVE', updated_at = now()
  where customer_id = p_customer_id and business_id = v_business_id;

  if v_profile_id is not null then
    update business_members
    set status = 'active', updated_at = now()
    where user_id = v_profile_id and business_id = v_business_id;
  end if;
end;
$$;

grant execute on function admin_delete_customer(uuid) to authenticated;
grant execute on function admin_restore_customer(uuid) to authenticated;

-- ----------------------------------------------------------
-- Surface deleted_at in the existing admin list RPCs so the Flutter admin
-- screens can show a "Deleted" badge and switch Delete<->Restore. Adding a
-- column changes the function's return row type, which CREATE OR REPLACE
-- cannot do on its own -- an explicit DROP is required first. Safe: these
-- are read-only listing functions with no data of their own to lose.
-- ----------------------------------------------------------
drop function if exists admin_owner_list(text);
drop function if exists admin_customer_list(text, boolean);

create or replace function admin_owner_list(p_query text default null)
returns table (
  profile_id uuid,
  owner_name text,
  owner_phone text,
  business_id uuid,
  business_name text,
  business_address text,
  approval_status text,
  is_active boolean,
  customer_count bigint,
  deleted_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    p.id as profile_id,
    coalesce(nullif(trim(p.name), ''), 'Owner') as owner_name,
    p.phone as owner_phone,
    b.id as business_id,
    b.name as business_name,
    b.address as business_address,
    p.approval_status,
    p.is_active,
    count(c.id)::bigint as customer_count,
    p.deleted_at
  from profiles p
  join businesses b on b.owner_id = p.id
  left join customers c on c.business_id = b.id
  where p.role = 'owner'
    and (
      p_query is null
      or trim(p_query) = ''
      or p.name ilike '%' || trim(p_query) || '%'
      or p.phone ilike '%' || trim(p_query) || '%'
      or b.name ilike '%' || trim(p_query) || '%'
    )
  group by p.id, p.name, p.phone, b.id, b.name, b.address, p.approval_status, p.is_active, p.deleted_at
  order by p.created_at desc;
$$;

create or replace function admin_customer_list(p_query text default null, p_active_only boolean default false)
returns table (
  customer_id uuid,
  business_id uuid,
  business_name text,
  display_name text,
  customer_name text,
  shop_name text,
  phone text,
  status text,
  is_active boolean,
  created_at timestamptz,
  deleted_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select
    c.id as customer_id,
    c.business_id,
    b.name as business_name,
    c.display_name,
    c.customer_name,
    c.shop_name,
    c.phone,
    c.status,
    c.is_active,
    c.created_at,
    c.deleted_at
  from customers c
  join businesses b on b.id = c.business_id
  where (p_active_only = false or c.is_active = true)
    and (
      p_query is null
      or trim(p_query) = ''
      or c.display_name ilike '%' || trim(p_query) || '%'
      or c.customer_name ilike '%' || trim(p_query) || '%'
      or c.shop_name ilike '%' || trim(p_query) || '%'
      or c.phone ilike '%' || trim(p_query) || '%'
      or b.name ilike '%' || trim(p_query) || '%'
    )
  order by c.created_at desc;
$$;

grant execute on function admin_owner_list(text) to authenticated;
grant execute on function admin_customer_list(text, boolean) to authenticated;

-- ----------------------------------------------------------
-- Block login for a deleted owner/admin profile outright, and for a
-- customer whose relationship with the business they're resolving into
-- has been deleted -- same body as fix_mvp_login_with_phone.sql, plus
-- those two checks (search this file for "deleted" to see exactly what
-- was added).
-- ----------------------------------------------------------
create or replace function mvp_login_with_phone(p_phone text)
returns table (
  id uuid,
  phone text,
  role text,
  name text,
  default_business_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
#variable_conflict use_column
declare
  v_user_id uuid := auth.uid();
  v_digits text;
  v_phone text;
  v_profile profiles%rowtype;
  v_session_phone text;
  v_business_id uuid;
  v_customer_id uuid;
begin
  if v_user_id is null then
    raise exception 'Authentication is required. Anonymous auth must be enabled for MVP login.';
  end if;

  v_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if length(v_digits) = 10 then
    v_phone := '+91' || v_digits;
  elsif length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_phone := '+91' || substring(v_digits from 2);
  elsif length(v_digits) = 12 and left(v_digits, 2) = '91' then
    v_phone := '+' || v_digits;
  else
    raise exception 'Invalid phone number.';
  end if;

  select * into v_profile
  from profiles p
  where p.phone = v_phone
    and p.role in ('owner', 'customer', 'admin')
  order by p.created_at asc
  limit 1;

  if not found then
    raise exception 'Mobile number is not registered.';
  end if;

  -- Deleted (owner/admin). A deleted customer's own profile is left
  -- untouched by admin_delete_customer (they may still have other active
  -- business relationships), so this check is scoped to the account, not
  -- a specific business -- the per-business check below covers customers.
  if v_profile.deleted_at is not null then
    raise exception 'This account has been removed. Contact support.';
  end if;

  if (v_profile.role in ('owner', 'customer')) and v_profile.approval_status <> 'approved' then
    raise exception 'Mobile number is not approved yet.';
  end if;

  if v_profile.is_active = false then
    raise exception 'Mobile number is inactive.';
  end if;

  v_business_id := v_profile.default_business_id;

  v_session_phone := 'mvp-' || replace(v_user_id::text, '-', '');
  if length(v_session_phone) > 60 then
    v_session_phone := substring(v_session_phone from 1 for 60);
  end if;

  insert into profiles (id, phone, role, name, default_business_id, approval_status, is_active)
  values (
    v_user_id,
    v_session_phone,
    v_profile.role,
    coalesce(v_profile.name, case when v_profile.role = 'owner' then 'Owner' when v_profile.role = 'admin' then 'Admin' else 'Customer' end),
    v_business_id,
    'approved',
    true
  )
  on conflict (id)
  do update set
    role = excluded.role,
    name = excluded.name,
    default_business_id = excluded.default_business_id,
    approval_status = 'approved',
    is_active = true,
    updated_at = now();

  insert into mvp_identity_links (auth_user_id, profile_id)
  values (v_user_id, v_profile.id)
  on conflict (auth_user_id)
  do update set
    profile_id = excluded.profile_id,
    updated_at = now();

  if v_profile.role = 'owner' then
    if v_business_id is null then
      select b.id into v_business_id
      from businesses b
      where b.owner_id = v_profile.id
      order by b.created_at asc
      limit 1;
    end if;

    if v_business_id is null then
      raise exception 'Owner business is not configured.';
    end if;

    insert into business_members (business_id, user_id, role, status)
    values (v_business_id, v_user_id, 'owner', 'active')
    on conflict (business_id, user_id)
    do update set
      role = excluded.role,
      status = excluded.status,
      updated_at = now();
  elsif v_profile.role = 'customer' then
    if v_business_id is null then
      select c.business_id into v_business_id
      from customers c
      where c.phone = v_phone
      order by c.created_at asc
      limit 1;
    end if;

    if v_business_id is null then
      raise exception 'Customer business is not configured.';
    end if;

    -- Deleted customer relationship with this specific business.
    if exists (
      select 1 from customers c
      where c.business_id = v_business_id
        and c.phone = v_phone
        and c.deleted_at is not null
    ) then
      raise exception 'This customer account has been removed. Contact the shop owner.';
    end if;

    insert into business_members (business_id, user_id, role, status)
    values (v_business_id, v_user_id, 'customer', 'active')
    on conflict (business_id, user_id)
    do update set
      role = excluded.role,
      status = excluded.status,
      updated_at = now();

    select c.id into v_customer_id
    from customers c
    where c.business_id = v_business_id
      and c.phone = v_phone
    order by c.created_at asc
    limit 1;

    if v_customer_id is not null then
      update customers
      set
        profile_id = v_user_id,
        status = 'ACTIVE',
        is_active = true,
        updated_at = now()
      where customers.id = v_customer_id;

      insert into customer_businesses (customer_id, business_id, status)
      values (v_customer_id, v_business_id, 'ACTIVE')
      on conflict (customer_id, business_id)
      do update set
        status = excluded.status,
        updated_at = now();
    end if;
  end if;

  return query
  select p.id, p.phone, p.role, p.name, p.default_business_id
  from profiles p
  where p.id = v_profile.id;
end;
$$;

grant execute on function mvp_login_with_phone(text) to authenticated;
