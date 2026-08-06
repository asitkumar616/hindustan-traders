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
  status text not null default 'pending',
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

alter table profiles enable row level security;
alter table businesses enable row level security;
alter table business_members enable row level security;
alter table customers enable row level security;
alter table customer_businesses enable row level security;
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

create policy "profiles_insert_own" on profiles
for insert with check (auth.uid() = id);

create policy "profiles_update_own" on profiles
for update using (auth.uid() = id);

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

create policy "business_members_select_business_member" on business_members
for select using (
  exists (
    select 1 from business_members current_member
    where current_member.user_id = auth.uid()
      and current_member.business_id = business_members.business_id
      and current_member.status = 'active'
  )
);

create policy "business_members_manage_own_business" on business_members
for all using (
  exists (
    select 1 from business_members current_member
    where current_member.user_id = auth.uid()
      and current_member.business_id = business_members.business_id
      and current_member.status = 'active'
      and current_member.role = 'owner'
  )
) with check (
  exists (
    select 1 from business_members current_member
    where current_member.user_id = auth.uid()
      and current_member.business_id = business_members.business_id
      and current_member.status = 'active'
      and current_member.role = 'owner'
  )
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
