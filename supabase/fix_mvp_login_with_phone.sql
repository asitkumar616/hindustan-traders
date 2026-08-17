-- Fix: ambiguous column reference "id" (42702) inside mvp_login_with_phone.
-- Root cause: the function's RETURNS TABLE(id, phone, role, name, default_business_id)
-- declares OUT parameters with those names, which become PL/pgSQL variables in scope.
-- Two statements referenced a plain "id" that Postgres could not tell apart from the
-- OUT-param "id": the customer branch's `where id = v_customer_id`, and, critically,
-- `on conflict (id)` on the profiles upsert -- the latter runs on EVERY login (owner
-- and customer alike), which is why owner logins were failing too.
--
-- ON CONFLICT (column) targets are parsed as expressions, so they can't be fixed by
-- writing `on conflict (profiles.id)` the normal way. Instead of chasing every bare
-- column reference individually, this adds `#variable_conflict use_column` as the
-- first line of the function body: it tells PL/pgSQL that whenever a name could mean
-- either a table column or a function variable/OUT-param, always resolve it as the
-- column. None of this function's own variables (v_user_id, v_digits, v_phone,
-- v_profile, v_session_phone, v_business_id, v_customer_id, p_phone) collide with any
-- table column name, so this is a safe, function-scoped setting with no side effects.
--
-- Same signature, same return columns -- no DROP FUNCTION needed.

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
