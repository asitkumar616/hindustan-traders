-- Supabase schema for Hindustan Traders

create table if not exists profiles (
  id uuid primary key default uuid_generate_v4(),
  phone text unique not null,
  role text not null check (role in ('customer', 'owner', 'staff')),
  name text,
  business_id uuid,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists businesses (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  owner_id uuid not null references profiles(id),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
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
  status text not null default 'pending',
  total_amount numeric not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists order_items (
  id uuid primary key default uuid_generate_v4(),
  order_id uuid not null references orders(id),
  product_id uuid not null references products(id),
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

create function update_timestamp() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger profiles_updated_at before update on profiles for each row execute function update_timestamp();
create trigger businesses_updated_at before update on businesses for each row execute function update_timestamp();
create trigger products_updated_at before update on products for each row execute function update_timestamp();
create trigger orders_updated_at before update on orders for each row execute function update_timestamp();
create trigger order_items_updated_at before update on order_items for each row execute function update_timestamp();

alter table profiles enable row level security;
alter table businesses enable row level security;
alter table products enable row level security;
alter table product_prices enable row level security;
alter table orders enable row level security;
alter table order_items enable row level security;
alter table notifications enable row level security;

create policy "profiles_select_own" on profiles
for select using (auth.uid() = id);

create policy "profiles_insert_own" on profiles
for insert with check (auth.uid() = id);

create policy "profiles_update_own" on profiles
for update using (auth.uid() = id);

create policy "businesses_select_member" on businesses
for select using (
  exists (
    select 1 from profiles p
    where p.id = auth.uid() and (p.id = owner_id or p.business_id = businesses.id)
  )
);

create policy "products_select_by_business_member" on products
for select using (
  exists (
    select 1 from profiles p
    where p.id = auth.uid() and p.business_id = products.business_id
  )
);

create policy "product_prices_select_business_member" on product_prices
for select using (
  exists (
    select 1 from products p
    join profiles pr on pr.business_id = p.business_id
    where p.id = product_prices.product_id
      and pr.id = auth.uid()
  )
);

create policy "orders_select_customer_or_business_member" on orders
for select using (
  customer_id = auth.uid()
  or exists (
    select 1 from profiles p
    where p.id = auth.uid() and p.business_id = orders.business_id
  )
);

create policy "orders_insert_customer_own" on orders
for insert with check (customer_id = auth.uid());

create policy "order_items_select_related" on order_items
for select using (
  exists (
    select 1 from orders o
    where o.id = order_items.order_id
      and (o.customer_id = auth.uid() or exists (
        select 1 from profiles p
        where p.id = auth.uid() and p.business_id = o.business_id
      ))
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
