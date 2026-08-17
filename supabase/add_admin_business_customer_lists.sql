-- Adds two new admin-only, read-only listing functions backing the admin
-- dashboard's "Businesses" / "Total customers" / "Active customers" cards.
-- Neither existed before -- these are new functions, not replacements of
-- anything. Both are security definer (like the existing admin_* functions)
-- because the admin's session has no business_members row anywhere, so it
-- cannot see businesses/customers rows through the normal RLS policies.

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

grant execute on function admin_business_list(text) to authenticated;
grant execute on function admin_customer_list(text, boolean) to authenticated;
