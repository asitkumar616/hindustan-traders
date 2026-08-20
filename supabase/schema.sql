-- Supabase schema for Hindustan Traders

create extension if not exists "uuid-ossp";

create table if not exists profiles (
  id uuid primary key default uuid_generate_v4(),
  phone text unique not null,
  role text not null check (role in ('customer', 'owner', 'staff')),
  name text,
  default_business_id uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists businesses (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  owner_id uuid not null references profiles(id),
  status text not null default 'active' check (status in ('active', 'inactive', 'suspended')),
  currency text not null default 'INR',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists business_members (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  role text not null default 'customer' check (role in ('owner', 'staff', 'customer')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (business_id, user_id)
);

create table if not exists customers (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  profile_id uuid references profiles(id),
  customer_code text,
  customer_name text,
  shop_name text,
  display_name text not null,
  phone text,
  address text,
  credit_limit numeric default 0,
  opening_balance numeric default 0,
  status text default 'NOT_REGISTERED' check (status in ('NOT_REGISTERED', 'ACTIVE', 'BLOCKED')),
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists customer_businesses (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid not null references customers(id) on delete cascade,
  business_id uuid not null references businesses(id) on delete cascade,
  customer_code text,
  status text not null default 'ACTIVE' check (status in ('ACTIVE', 'BLOCKED')),
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (customer_id, business_id)
);

create table if not exists products (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id),
  name text not null,
  code text,
  unit text not null,
  is_active boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists product_prices (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid not null references products(id),
  price numeric not null,
  valid_from timestamptz default now(),
  created_at timestamptz default now()
);

create table if not exists orders (
  id uuid primary key default uuid_generate_v4(),
  customer_id uuid not null references profiles(id),
  business_id uuid not null references businesses(id),
  status text not null default 'pending' check (status in ('pending', 'ready', 'completed')),
  total_amount numeric not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists order_items (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references orders(id),
  product_id uuid references products(id),
  quantity numeric not null,
  unit text not null,
  price numeric not null,
  amount numeric not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists notifications (
  id uuid primary key default uuid_generate_v4(),
  recipient_id uuid not null references profiles(id),
  business_id uuid not null references businesses(id),
  title text not null,
  body text not null,
  is_read boolean default false,
  data jsonb,
  created_at timestamptz default now()
);

create table if not exists invoices (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  order_id uuid,
  invoice_number text not null,
  status text not null default 'draft' check (status in ('draft', 'pending', 'paid', 'overdue')),
  subtotal numeric not null default 0,
  discount numeric not null default 0,
  total numeric not null default 0,
  paid_amount numeric not null default 0,
  balance_amount numeric not null default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists invoice_items (
  id uuid primary key default uuid_generate_v4(),
  invoice_id uuid not null references invoices(id) on delete cascade,
  product_id uuid references products(id),
  description text not null,
  quantity numeric not null default 0,
  unit text,
  price numeric not null default 0,
  amount numeric not null default 0,
  created_at timestamptz default now()
);

create table if not exists payments (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  invoice_id uuid references invoices(id),
  amount numeric not null,
  payment_method text,
  payment_status text default 'pending',
  reference_number text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists ledger_entries (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  invoice_id uuid references invoices(id),
  payment_id uuid references payments(id),
  entry_type text not null,
  debit numeric default 0,
  credit numeric default 0,
  balance numeric default 0,
  created_at timestamptz default now()
);

create table if not exists expenses (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  description text not null,
  amount numeric not null,
  expense_date timestamptz default now(),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists stock_movements (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  product_id uuid not null references products(id) on delete cascade,
  movement_type text not null,
  quantity numeric not null,
  note text,
  created_at timestamptz default now()
);

create table if not exists mvp_identity_links (
  auth_user_id uuid primary key references profiles(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table profiles drop constraint if exists profiles_role_check;
alter table profiles add constraint profiles_role_check check (role in ('customer', 'owner', 'staff', 'admin'));
alter table profiles add column if not exists approval_status text not null default 'pending' check (approval_status in ('pending', 'approved', 'rejected'));
alter table profiles add column if not exists is_active boolean not null default true;
alter table businesses add column if not exists address text;

create or replace function update_timestamp() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at before update on profiles for each row execute function update_timestamp();
create trigger businesses_updated_at before update on businesses for each row execute function update_timestamp();
create trigger business_members_updated_at before update on business_members for each row execute function update_timestamp();
create trigger customers_updated_at before update on customers for each row execute function update_timestamp();
create trigger customer_businesses_updated_at before update on customer_businesses for each row execute function update_timestamp();
create trigger products_updated_at before update on products for each row execute function update_timestamp();
create trigger orders_updated_at before update on orders for each row execute function update_timestamp();
create trigger order_items_updated_at before update on order_items for each row execute function update_timestamp();
create trigger invoices_updated_at before update on invoices for each row execute function update_timestamp();
create trigger payments_updated_at before update on payments for each row execute function update_timestamp();
create trigger expenses_updated_at before update on expenses for each row execute function update_timestamp();
create trigger mvp_identity_links_updated_at before update on mvp_identity_links for each row execute function update_timestamp();

create or replace function admin_dashboard_summary()
returns table (
  total_owners bigint,
  total_businesses bigint,
  total_customers bigint,
  active_customers bigint
)
language sql
security definer
set search_path = public
as $$
  select
    (select count(*) from profiles where role = 'owner')::bigint as total_owners,
    (select count(*) from businesses)::bigint as total_businesses,
    (select count(*) from customers)::bigint as total_customers,
    (select count(*) from customers where is_active = true)::bigint as active_customers;
$$;

create or replace function admin_owner_customer_breakdown()
returns table (
  owner_id uuid,
  owner_name text,
  owner_phone text,
  business_count bigint,
  customer_count bigint
)
language sql
security definer
set search_path = public
as $$
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
$$;

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
  customer_count bigint
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
    count(c.id)::bigint as customer_count
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
  group by p.id, p.name, p.phone, b.id, b.name, b.address, p.approval_status, p.is_active
  order by p.created_at desc;
$$;

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
  if p_status not in ('pending', 'approved', 'rejected') then
    raise exception 'Invalid owner status.';
  end if;

  update profiles
  set
    approval_status = p_status,
    is_active = p_is_active,
    updated_at = now()
  where id = p_profile_id
    and role = 'owner';

  update businesses
  set
    status = case when p_is_active = true and p_status = 'approved' then 'active' else 'inactive' end,
    updated_at = now()
  where owner_id = p_profile_id;
end;
$$;

-- Admin-only read: list businesses across all owners, for the dashboard's
-- "Businesses" drill-down. The admin session has no business_members row
-- for any business, so it cannot see rows via the normal RLS policies;
-- security definer bypasses RLS for this read-only, admin-gated listing.
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
language sql
security definer
set search_path = public
as $$
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
$$;

-- Admin-only read: list customers across every business, for the
-- dashboard's "Total customers" / "Active customers" drill-downs.
-- p_active_only lets the same function serve both cards.
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
  created_at timestamptz
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
    c.created_at
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

-- Owner-scoped dashboard summary. business_id is derived from the caller's
-- own active business_members row -- never accepted as a parameter -- so an
-- owner can never pull another owner's numbers by passing a different id.
-- "Orders"/"revenue" are read from invoices (excluding drafts, which are
-- not yet confirmed sales) rather than the orders table, since invoices are
-- this app's authoritative billing record and orders has no real
-- completed/cancelled lifecycle today -- this avoids inventing a second,
-- parallel revenue calculation.
create or replace function owner_dashboard_summary()
returns table (
  business_id uuid,
  business_name text,
  total_customers bigint,
  today_orders bigint,
  today_revenue numeric,
  pending_amount numeric
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  select bm.business_id into v_business_id
  from business_members bm
  where bm.user_id = auth.uid()
    and bm.role = 'owner'
    and bm.status = 'active'
  order by bm.created_at asc
  limit 1;

  if v_business_id is null then
    raise exception 'No active business found for the current owner.';
  end if;

  return query
  select
    b.id as business_id,
    b.name as business_name,
    (select count(*) from customers c where c.business_id = b.id)::bigint as total_customers,
    (select count(*) from invoices i where i.business_id = b.id and i.status <> 'draft' and i.created_at >= date_trunc('day', now()))::bigint as today_orders,
    (select coalesce(sum(i.total), 0) from invoices i where i.business_id = b.id and i.status <> 'draft' and i.created_at >= date_trunc('day', now())) as today_revenue,
    (select coalesce(sum(i.balance_amount), 0) from invoices i where i.business_id = b.id and i.status <> 'paid') as pending_amount
  from businesses b
  where b.id = v_business_id;
end;
$$;

-- Owner-scoped customer list with outstanding balance and last invoice
-- date, backing the "Total Customers" / "Pending Amount" drill-downs.
-- outstanding_amount and last_order_at both come from invoices (which
-- reference customers.id directly), matching how pending_amount is
-- computed in owner_dashboard_summary above.
create or replace function owner_customer_balances(p_only_outstanding boolean default false)
returns table (
  customer_id uuid,
  display_name text,
  phone text,
  status text,
  is_active boolean,
  outstanding_amount numeric,
  last_order_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_business_id uuid;
begin
  select bm.business_id into v_business_id
  from business_members bm
  where bm.user_id = auth.uid()
    and bm.role = 'owner'
    and bm.status = 'active'
  order by bm.created_at asc
  limit 1;

  if v_business_id is null then
    raise exception 'No active business found for the current owner.';
  end if;

  return query
  select
    c.id as customer_id,
    c.display_name,
    c.phone,
    c.status,
    c.is_active,
    coalesce((select sum(i.balance_amount) from invoices i where i.customer_id = c.id and i.status <> 'paid'), 0) as outstanding_amount,
    (select max(i.created_at) from invoices i where i.customer_id = c.id) as last_order_at
  from customers c
  where c.business_id = v_business_id
    and (
      p_only_outstanding = false
      or coalesce((select sum(i2.balance_amount) from invoices i2 where i2.customer_id = c.id and i2.status <> 'paid'), 0) > 0
    )
  order by c.created_at desc;
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
grant execute on function admin_owner_list(text) to authenticated;
grant execute on function admin_owner_create(text, text, text, text, text) to authenticated;
grant execute on function admin_owner_update(uuid, text, text, text, text) to authenticated;
grant execute on function admin_owner_set_state(uuid, text, boolean) to authenticated;
grant execute on function admin_business_list(text) to authenticated;
grant execute on function admin_customer_list(text, boolean) to authenticated;
grant execute on function owner_dashboard_summary() to authenticated;
grant execute on function owner_customer_balances(boolean) to authenticated;
grant execute on function customer_my_businesses() to authenticated;

alter table profiles enable row level security;
alter table businesses enable row level security;
alter table business_members enable row level security;
alter table customers enable row level security;
alter table customer_businesses enable row level security;
alter table mvp_identity_links enable row level security;
alter table products enable row level security;
alter table product_prices enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table notifications enable row level security;
alter table invoices enable row level security;
alter table invoice_items enable row level security;
alter table payments enable row level security;
alter table ledger_entries enable row level security;
alter table expenses enable row level security;
alter table stock_movements enable row level security;

create policy "profiles_select_own" on profiles
for select using (auth.uid() = id);

create policy "profiles_select_business_member" on profiles
for select using (
  exists (
    select 1
    from business_members bm_self
    join business_members bm_target
      on bm_target.business_id = bm_self.business_id
    where bm_self.user_id = auth.uid()
      and bm_self.status = 'active'
      and bm_self.role in ('owner', 'staff')
      and bm_target.user_id = profiles.id
      and bm_target.status = 'active'
  )
);

create policy "profiles_insert_own" on profiles
for insert with check (auth.uid() = id);

create policy "profiles_update_own" on profiles
for update using (auth.uid() = id);

create policy "mvp_identity_links_select_own" on mvp_identity_links
for select using (auth.uid() = auth_user_id);

create policy "businesses_select_member" on businesses
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = businesses.id
      and bm.status = 'active'
  )
);

create policy "businesses_insert_owner" on businesses
for insert with check (
  auth.uid() = owner_id
);

-- business_members' own RLS policies used to check membership by querying
-- business_members itself (a self-join). Every access to business_members
-- re-triggers its own policy, which re-queries business_members, which
-- re-triggers the policy again -- unbounded recursion (Postgres error
-- 42P17). This security-definer function runs as the table owner, which
-- bypasses RLS for its internal query, so the membership check no longer
-- re-invokes the policy it is used by.
create or replace function public.is_active_business_member(p_business_id uuid, p_roles text[] default null)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1
    from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = p_business_id
      and bm.status = 'active'
      and (p_roles is null or bm.role = any(p_roles))
  );
$$;

grant execute on function public.is_active_business_member(uuid, text[]) to authenticated;

drop policy if exists "business_members_select_business_member" on business_members;
create policy "business_members_select_business_member" on business_members
for select using (
  public.is_active_business_member(business_members.business_id)
);

drop policy if exists "business_members_manage_own_business" on business_members;
create policy "business_members_manage_own_business" on business_members
for all using (
  public.is_active_business_member(business_members.business_id, array['owner'])
) with check (
  public.is_active_business_member(business_members.business_id, array['owner'])
);

create policy "customers_select_business_member" on customers
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = customers.business_id
      and bm.status = 'active'
  )
);

create policy "customers_manage_business_member" on customers
for all using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = customers.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
) with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = customers.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
);

create policy "customer_businesses_select_member_or_customer" on customer_businesses
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = customer_businesses.business_id
      and bm.status = 'active'
  )
  or exists (
    select 1 from customers c
    where c.id = customer_businesses.customer_id
      and c.profile_id = auth.uid()
  )
);

create policy "customer_businesses_manage_owner" on customer_businesses
for all using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = customer_businesses.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
) with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = customer_businesses.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
);

create policy "products_select_by_business_member" on products
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = products.business_id
      and bm.status = 'active'
  )
);

create policy "products_manage_by_business_member" on products
for all using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = products.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
) with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = products.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
);

create policy "product_prices_select_business_member" on product_prices
for select using (
  exists (
    select 1 from products p
    join business_members bm on bm.business_id = p.business_id
    where p.id = product_prices.product_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  )
);

create policy "product_prices_manage_business_member" on product_prices
for all using (
  exists (
    select 1 from products p
    join business_members bm on bm.business_id = p.business_id
    where p.id = product_prices.product_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
) with check (
  exists (
    select 1 from products p
    join business_members bm on bm.business_id = p.business_id
    where p.id = product_prices.product_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
);

create policy "orders_select_business_member_or_customer" on orders
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = orders.business_id
      and bm.status = 'active'
  )
  or customer_id = auth.uid()
);

create policy "orders_insert_customer_own" on orders
for insert with check (customer_id = auth.uid());

create policy "orders_manage_business_member" on orders
for update using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = orders.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
) with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = orders.business_id
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
);

create policy "order_items_select_related" on order_items
for select using (
  exists (
    select 1 from orders o
    where o.id = order_items.order_id
      and (
        o.customer_id = auth.uid()
        or exists (
          select 1 from business_members bm
          where bm.user_id = auth.uid()
            and bm.business_id = o.business_id
            and bm.status = 'active'
        )
      )
  )
);

create policy "order_items_insert_customer_own" on order_items
for insert with check (
  exists (
    select 1 from orders o
    where o.id = order_items.order_id
      and o.customer_id = auth.uid()
  )
);

create policy "order_items_manage_business_member" on order_items
for update using (
  exists (
    select 1 from orders o
    join business_members bm on bm.business_id = o.business_id
    where o.id = order_items.order_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
) with check (
  exists (
    select 1 from orders o
    join business_members bm on bm.business_id = o.business_id
    where o.id = order_items.order_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.role in ('owner', 'staff')
  )
);

create policy "invoices_select_business_member" on invoices
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = invoices.business_id
      and bm.status = 'active'
  )
);

create policy "payments_select_business_member" on payments
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = payments.business_id
      and bm.status = 'active'
  )
);

create policy "ledger_entries_select_business_member" on ledger_entries
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = ledger_entries.business_id
      and bm.status = 'active'
  )
);

create policy "notifications_select_recipient_or_member" on notifications
for select using (
  recipient_id = auth.uid()
  or exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = notifications.business_id
      and bm.status = 'active'
  )
);

create policy "notifications_insert_business_member" on notifications
for insert with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = notifications.business_id
      and bm.status = 'active'
  )
);

create policy "notifications_update_recipient" on notifications
for update using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());
