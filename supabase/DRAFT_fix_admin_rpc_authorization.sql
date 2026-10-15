-- ============================================================
-- DRAFT -- NOT YET RUN. Reviewing before applying, per instructions.
--
-- Closes the privilege-escalation hole: 8 pre-existing admin RPCs are
-- security definer with NO role check, so any authenticated session
-- (including a free anonymous one) can call them directly via the REST
-- API, bypassing the admin login screen entirely.
--
-- This fix is deliberately independent of the password-auth overhaul in
-- DRAFT_add_secure_password_auth.sql -- it's a single-purpose, low-risk
-- patch that can be applied on its own, immediately, without waiting for
-- the rest of the migration. It changes no data and no behavior for a
-- legitimate admin; it only blocks everyone else.
--
-- Same guard already used on every admin_* RPC added this session
-- (admin_category_upsert, admin_delete_owner, etc.):
--   if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
--     raise exception 'Not authorized.';
--   end if;
--
-- NOTE: this guard checks the CURRENT session's own profiles row. Under
-- the current mvp_login_with_phone scheme that's reliable (it keeps the
-- session's profile row's role in sync on every login). It stays correct
-- under the new password-auth scheme too, since profiles.id = auth.uid()
-- for a real Supabase Auth user exactly as it does for an mvp session.
-- ============================================================

create or replace function admin_dashboard_summary()
returns table(
  total_owners bigint,
  total_businesses bigint,
  total_customers bigint,
  active_customers bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  return query
  select
    (select count(*) from profiles where role = 'owner')::bigint,
    (select count(*) from businesses)::bigint,
    (select count(*) from customers)::bigint,
    (select count(*) from customers where is_active = true)::bigint;
end;
$$;

create or replace function admin_owner_customer_breakdown()
returns table(
  owner_id uuid,
  owner_name text,
  owner_phone text,
  business_count bigint,
  customer_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  return query
  select
    p.id as owner_id,
    coalesce(nullif(trim(p.name), ''), 'Owner') as owner_name,
    p.phone as owner_phone,
    count(distinct b.id)::bigint as business_count,
    count(distinct c.id)::bigint as customer_count
  from profiles p
  left join businesses b on b.owner_id = p.id
  left join customers c on c.business_id = b.id
  where p.role = 'owner'
  group by p.id, p.name, p.phone
  order by owner_name asc, owner_phone asc;
end;
$$;

-- Defensive: admin_owner_list/admin_customer_list already picked up a
-- deleted_at column in add_owner_customer_soft_delete.sql. If that
-- migration's re-run (after its own return-type error) hasn't completed
-- yet, CREATE OR REPLACE below would hit the identical error -- so drop
-- first regardless of which version is currently live. No-op if the
-- signature already matches.
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
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  return query
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
end;
$$;

create or replace function admin_business_list(p_query text default null)
returns table (
  business_id uuid,
  business_name text,
  business_address text,
  business_status text,
  owner_id uuid,
  owner_name text,
  owner_phone text,
  customer_count bigint,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  return query
  select
    b.id as business_id,
    b.name as business_name,
    b.address as business_address,
    b.status as business_status,
    p.id as owner_id,
    coalesce(nullif(trim(p.name), ''), 'Owner') as owner_name,
    p.phone as owner_phone,
    count(c.id)::bigint as customer_count,
    b.created_at
  from businesses b
  join profiles p on p.id = b.owner_id
  left join customers c on c.business_id = b.id
  where (
    p_query is null
    or trim(p_query) = ''
    or b.name ilike '%' || trim(p_query) || '%'
    or p.name ilike '%' || trim(p_query) || '%'
    or p.phone ilike '%' || trim(p_query) || '%'
  )
  group by b.id, b.name, b.address, b.status, p.id, p.name, p.phone, b.created_at
  order by b.created_at desc;
end;
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
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  return query
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
end;
$$;

-- Bodies below are byte-for-byte the current schema.sql versions (verified
-- by re-reading the live source, not reconstructed from memory) with only
-- the authorization guard inserted at the top of each -- no other logic
-- changed.

create or replace function admin_owner_create(
  p_owner_name text,
  p_phone text,
  p_business_name text,
  p_business_address text default null,
  p_status text default 'pending'
)
returns table (
  profile_id uuid,
  business_id uuid
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_digits text;
  v_profile_id uuid;
  v_business_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  v_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if length(v_digits) = 10 then
    v_phone := '+91' || v_digits;
  elsif length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_phone := '+91' || substring(v_digits from 2);
  elsif length(v_digits) = 12 and left(v_digits, 2) = '91' then
    v_phone := '+' || v_digits;
  else
    raise exception 'Invalid owner mobile number.';
  end if;

  if p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Invalid owner status.';
  end if;

  insert into profiles (phone, role, name, approval_status, is_active)
  values (v_phone, 'owner', coalesce(nullif(trim(p_owner_name), ''), 'Owner'), p_status, p_status = 'approved')
  on conflict (phone)
  do update set
    role = 'owner',
    name = excluded.name,
    approval_status = excluded.approval_status,
    is_active = case when excluded.approval_status = 'approved' then true else profiles.is_active end,
    updated_at = now()
  returning id into v_profile_id;

  insert into businesses (name, owner_id, address, status, currency)
  values (
    coalesce(nullif(trim(p_business_name), ''), 'Owner Business'),
    v_profile_id,
    nullif(trim(coalesce(p_business_address, '')), ''),
    case when p_status = 'approved' then 'active' else 'inactive' end,
    'INR'
  )
  on conflict do nothing
  returning id into v_business_id;

  if v_business_id is null then
    select b.id into v_business_id
    from businesses b
    where b.owner_id = v_profile_id
    order by b.created_at asc
    limit 1;

    update businesses
    set
      name = coalesce(nullif(trim(p_business_name), ''), businesses.name),
      address = nullif(trim(coalesce(p_business_address, '')), ''),
      status = case when p_status = 'approved' then 'active' else 'inactive' end,
      updated_at = now()
    where id = v_business_id;
  end if;

  update profiles
  set default_business_id = v_business_id, updated_at = now()
  where id = v_profile_id;

  return query select v_profile_id, v_business_id;
end;
$$;

create or replace function admin_owner_update(
  p_profile_id uuid,
  p_owner_name text,
  p_phone text,
  p_business_name text,
  p_business_address text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_phone text;
  v_digits text;
  v_business_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  v_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if length(v_digits) = 10 then
    v_phone := '+91' || v_digits;
  elsif length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_phone := '+91' || substring(v_digits from 2);
  elsif length(v_digits) = 12 and left(v_digits, 2) = '91' then
    v_phone := '+' || v_digits;
  else
    raise exception 'Invalid owner mobile number.';
  end if;

  update profiles
  set
    phone = v_phone,
    name = coalesce(nullif(trim(p_owner_name), ''), 'Owner'),
    updated_at = now()
  where id = p_profile_id
    and role = 'owner';

  select b.id into v_business_id
  from businesses b
  where b.owner_id = p_profile_id
  order by b.created_at asc
  limit 1;

  if v_business_id is not null then
    update businesses
    set
      name = coalesce(nullif(trim(p_business_name), ''), businesses.name),
      address = nullif(trim(coalesce(p_business_address, '')), ''),
      updated_at = now()
    where id = v_business_id;
  end if;
end;
$$;

create or replace function admin_owner_set_state(
  p_profile_id uuid,
  p_status text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  if p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Invalid owner status.';
  end if;

  update profiles
  set approval_status = p_status, is_active = p_is_active, updated_at = now()
  where id = p_profile_id and role = 'owner';

  update businesses
  set status = case when p_is_active = true and p_status = 'approved' then 'active' else 'inactive' end,
      updated_at = now()
  where owner_id = p_profile_id;
end;
$$;

grant execute on function admin_dashboard_summary() to authenticated;
grant execute on function admin_owner_customer_breakdown() to authenticated;
grant execute on function admin_owner_list(text) to authenticated;
grant execute on function admin_business_list(text) to authenticated;
grant execute on function admin_customer_list(text, boolean) to authenticated;
grant execute on function admin_owner_create(text, text, text, text, text) to authenticated;
grant execute on function admin_owner_update(uuid, text, text, text, text) to authenticated;
grant execute on function admin_owner_set_state(uuid, text, boolean) to authenticated;
