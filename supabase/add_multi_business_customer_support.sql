-- Phase 1: multi-business customer support (DB foundation only, no UI yet).
--
-- Business rule change: a customer is no longer restricted to one owner's
-- business. A phone number can be added as a customer by multiple owners
-- (each business keeps its own customers row -- own credit_limit,
-- customer_code, status -- these are legitimately per-business terms and
-- are NOT merged). customer_businesses (already existed, already the right
-- shape: customer_id, business_id, status) becomes the populated
-- membership layer; business_members (already supports multiple rows per
-- user) becomes the RLS access layer. No new tables, no column/constraint
-- changes, no data migration -- this only changes what mvp_login_with_phone
-- writes on login, and adds one new read-only RPC.
--
-- Root cause this fixes: mvp_login_with_phone's customer branch resolved
-- exactly ONE customers row per phone (oldest match) and wrote exactly one
-- business_members row. If the same phone existed under a second owner's
-- business, that second relationship was silently ignored at every login.
--
-- Every existing RLS policy on products/orders/invoices/customers already
-- checks business_members generically (any active row for that
-- business_id, regardless of role) -- not "the customer's one business" --
-- so no RLS policy changes are needed; they already support multi-business
-- membership once business_members actually has multiple rows per user.
--
-- Owner-side counting (owner_dashboard_summary, owner_customer_balances)
-- already scopes by customers.business_id, which remains correct and
-- unaffected by this change -- not touched here.

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
    -- A phone number can be added as a customer by more than one owner
    -- (one customers row per business relationship, same phone). Sync
    -- EVERY matching row into business_members/customer_businesses on each
    -- login -- not just one -- so the customer gets RLS access to every
    -- business they've been linked to, and newly-added businesses since
    -- their last login are picked up automatically. Each business's
    -- customers row (its own credit_limit/customer_code/status) is left
    -- untouched except for the profile_id link and status sync below.
    declare
      v_active_business_count integer := 0;
    begin
      for v_customer in
        select * from customers c where c.phone = v_phone
      loop
        insert into customer_businesses (customer_id, business_id, status)
        values (v_customer.id, v_customer.business_id, case when v_customer.status = 'BLOCKED' then 'BLOCKED' else 'ACTIVE' end)
        on conflict (customer_id, business_id)
        do update set
          status = excluded.status,
          updated_at = now();

        if v_customer.status <> 'BLOCKED' then
          v_active_business_count := v_active_business_count + 1;

          insert into business_members (business_id, user_id, role, status)
          values (v_customer.business_id, v_user_id, 'customer', 'active')
          on conflict (business_id, user_id)
          do update set
            role = excluded.role,
            status = excluded.status,
            updated_at = now();

          update customers
          set
            profile_id = v_user_id,
            status = 'ACTIVE',
            is_active = true,
            updated_at = now()
          where customers.id = v_customer.id;
        else
          -- Blocked at this specific business only -- drop access there
          -- without touching the customer's other business memberships.
          update business_members
          set status = 'inactive', updated_at = now()
          where business_members.business_id = v_customer.business_id
            and business_members.user_id = v_user_id;
        end if;
      end loop;

      if v_active_business_count = 0 then
        raise exception 'Customer business is not configured.';
      end if;
    end;
  end if;

  return query
  select p.id, p.phone, p.role, p.name, p.default_business_id
  from profiles p
  where p.id = v_source_profile_id;
end;
$$;

-- Customer-facing: list the ACTIVE businesses ("My Shops") linked to the
-- calling customer, via customer_businesses -> customers.profile_id =
-- auth.uid(). mvp_login_with_phone keeps both tables in sync on every
-- login, so this reflects every business this phone has been added to,
-- not just the one it first logged into.
create or replace function customer_my_businesses()
returns table (
  business_id uuid,
  business_name text,
  business_status text,
  customer_id uuid,
  customer_display_name text,
  relationship_status text
)
language sql
security definer
set search_path = public
as $$
  select
    b.id as business_id,
    b.name as business_name,
    b.status as business_status,
    c.id as customer_id,
    c.display_name as customer_display_name,
    cb.status as relationship_status
  from customer_businesses cb
  join customers c on c.id = cb.customer_id
  join businesses b on b.id = cb.business_id
  where c.profile_id = auth.uid()
    and cb.status = 'ACTIVE'
  order by b.name asc;
$$;

grant execute on function mvp_login_with_phone(text) to authenticated;
grant execute on function customer_my_businesses() to authenticated;
