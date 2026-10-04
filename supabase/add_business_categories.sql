-- ============================================================
-- OdiaTraders: per-business category selection ("What does your
-- business sell?"). Additive only -- existing categories/master_products/
-- products tables are untouched, and a business with zero rows here keeps
-- seeing every category exactly as before (the app falls back to "show
-- all" when a business has made no selection yet).
-- ============================================================

create table if not exists business_categories (
  id uuid primary key default uuid_generate_v4(),
  business_id uuid not null references businesses(id) on delete cascade,
  category_id uuid not null references categories(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz default now()
);

create unique index if not exists business_categories_business_category_uniq
  on business_categories (business_id, category_id);

alter table business_categories enable row level security;

-- Same "active business_members row" pattern already used for notifications
-- (see fix_notifications_insert_and_update_rls.sql) -- any active member of
-- the business (owner or staff) can read and manage its category list.
drop policy if exists business_categories_select_member on business_categories;
create policy business_categories_select_member on business_categories
for select using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = business_categories.business_id
      and bm.status = 'active'
  )
);

drop policy if exists business_categories_insert_member on business_categories;
create policy business_categories_insert_member on business_categories
for insert with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = business_categories.business_id
      and bm.status = 'active'
  )
);

drop policy if exists business_categories_update_member on business_categories;
create policy business_categories_update_member on business_categories
for update using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = business_categories.business_id
      and bm.status = 'active'
  )
) with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = business_categories.business_id
      and bm.status = 'active'
  )
);

drop policy if exists business_categories_delete_member on business_categories;
create policy business_categories_delete_member on business_categories
for delete using (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = business_categories.business_id
      and bm.status = 'active'
  )
);
