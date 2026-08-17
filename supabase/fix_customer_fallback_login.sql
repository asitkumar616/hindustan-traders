-- Fix: customer login fails with "Mobile number is not registered." (P0001)
-- for customers added via the owner's "Manage customers" screen.
--
-- Root cause: mvp_login_with_phone only ever looked the phone up in the
-- profiles table. Owners/admins are pre-registered there (via
-- admin_owner_create), but "Manage customers" (see
-- lib/src/services/customer_business_service.dart -> createCustomerRecord)
-- only inserts into the customers table -- it never creates a profiles row.
-- So a customer added by their owner had nowhere to be found on their first
-- login attempt.
--
-- Fix: when no match is found in profiles, fall back to looking the phone
-- up in customers (blocked only if status = 'BLOCKED'), and treat a match
-- there as a first-time customer login -- resolving their business directly
-- from that row instead of requiring a pre-existing profiles row. Same
-- function name/signature/return columns; no schema or table changes.

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
  v_customer customers%rowtype;
  v_role text;
  v_name text;
  v_business_id uuid;
  v_source_profile_id uuid;
  v_profile_phone text;
  v_session_phone text;
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

  if found then
    if (v_profile.role in ('owner', 'customer')) and v_profile.approval_status <> 'approved' then
      raise exception 'Mobile number is not approved yet.';
    end if;

    if v_profile.is_active = false then
      raise exception 'Mobile number is inactive.';
    end if;

    v_role := v_profile.role;
    v_name := v_profile.name;
    v_business_id := v_profile.default_business_id;
    v_source_profile_id := v_profile.id;
  else
    -- No pre-registered profiles row for this phone. Owners/admins are
    -- always pre-registered via admin_owner_create, but customers are
    -- pre-registered by their owner through the "Manage customers" screen,
    -- which only writes to the customers table (never profiles). Fall back
    -- to looking the phone up there so a customer's first login succeeds.
    select * into v_customer
    from customers c
    where c.phone = v_phone
    order by c.created_at asc
    limit 1;

    if not found then
      raise exception 'Mobile number is not registered.';
    end if;

    if v_customer.status = 'BLOCKED' then
      raise exception 'Mobile number is inactive.';
    end if;

    v_role := 'customer';
    v_name := coalesce(nullif(trim(v_customer.customer_name), ''), nullif(trim(v_customer.display_name), ''), 'Customer');
    v_business_id := v_customer.business_id;
    v_source_profile_id := v_user_id;
  end if;

  v_session_phone := 'mvp-' || replace(v_user_id::text, '-', '');
  if length(v_session_phone) > 60 then
    v_session_phone := substring(v_session_phone from 1 for 60);
  end if;

  -- profiles.phone is unique. When the canonical profile is a separate,
  -- pre-existing row (owner/admin, or a customer already linked on an
  -- earlier login), mirror it here under a placeholder phone to avoid a
  -- collision. When this session's own row IS the canonical profile
  -- (first-time customer-fallback login), store the real phone on it.
  v_profile_phone := case when v_source_profile_id = v_user_id then v_phone else v_session_phone end;

  insert into profiles (id, phone, role, name, default_business_id, approval_status, is_active)
  values (
    v_user_id,
    v_profile_phone,
    v_role,
    coalesce(v_name, case when v_role = 'owner' then 'Owner' when v_role = 'admin' then 'Admin' else 'Customer' end),
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
  values (v_user_id, v_source_profile_id)
  on conflict (auth_user_id)
  do update set
    profile_id = excluded.profile_id,
    updated_at = now();

  if v_role = 'owner' then
    if v_business_id is null then
      select b.id into v_business_id
      from businesses b
      where b.owner_id = v_source_profile_id
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
  elsif v_role = 'customer' then
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
  where p.id = v_source_profile_id;
end;
$$;

grant execute on function mvp_login_with_phone(text) to authenticated;
