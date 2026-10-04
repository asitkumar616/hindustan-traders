-- ============================================================
-- OdiaTraders: multi-category B2B catalog -- Phase 1.
-- Additive only. No existing table recreated, no existing row touched.
-- Safe to re-run (create if not exists / add column if not exists).
-- ============================================================

-- ----------------------------------------------------------
-- 1. Hierarchical categories table (replaces the hardcoded
--    kMasterProductCategories Dart list). parent_id null = a top-level
--    business category; parent_id set = a subcategory of it.
-- ----------------------------------------------------------
create table if not exists categories (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  parent_id uuid references categories(id),
  display_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz default now()
);

create unique index if not exists categories_name_parent_uniq
  on categories (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid));

alter table categories enable row level security;

drop policy if exists categories_select_authenticated on categories;
create policy categories_select_authenticated on categories
  for select
  using (auth.uid() is not null);

-- No insert/update/delete policy for regular users -- category management
-- is an admin task (Supabase dashboard for now; a future Admin UI can use
-- the same table without any further schema change).


-- ----------------------------------------------------------
-- 2. Additive, nullable structured-category columns. The existing
--    free-text `category` column on both tables is untouched and keeps
--    working exactly as before -- nothing currently reads category_id,
--    so no existing query or screen changes behavior from this alone.
-- ----------------------------------------------------------
alter table master_products add column if not exists category_id uuid references categories(id);
alter table master_products add column if not exists subcategory_id uuid references categories(id);
alter table master_products add column if not exists specifications jsonb;

alter table products add column if not exists category_id uuid references categories(id);
alter table products add column if not exists subcategory_id uuid references categories(id);

alter table product_variants add column if not exists sku text;


-- ----------------------------------------------------------
-- 3. Seed the 30 business categories plus the subcategories you listed.
--    Idempotent: ON CONFLICT DO NOTHING against the unique index above,
--    so re-running this file never creates duplicates.
-- ----------------------------------------------------------
insert into categories (name, parent_id, display_order) values
  ('Grocery & Daily Essentials', null, 1),
  ('Fruits & Vegetables', null, 2),
  ('Beverages', null, 3),
  ('Personal Care', null, 4),
  ('Household & Cleaning', null, 5),
  ('Mobile Phones', null, 6),
  ('Mobile Accessories', null, 7),
  ('Laptops & Computers', null, 8),
  ('Computer Accessories', null, 9),
  ('Electronics', null, 10),
  ('Home Appliances', null, 11),
  ('Furniture', null, 12),
  ('Medicines & Pharmacy', null, 13),
  ('Health & Wellness', null, 14),
  ('Building Materials', null, 15),
  ('Cement', null, 16),
  ('Iron & Steel', null, 17),
  ('Hardware', null, 18),
  ('Electrical', null, 19),
  ('Plumbing', null, 20),
  ('Paints', null, 21),
  ('Tiles & Flooring', null, 22),
  ('Sanitaryware', null, 23),
  ('Tools & Equipment', null, 24),
  ('Agriculture & Farming', null, 25),
  ('Stationery', null, 26),
  ('Clothing & Textiles', null, 27),
  ('Footwear', null, 28),
  ('Auto Parts', null, 29),
  ('Other', null, 30)
on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

-- Subcategories, resolved against the top-level rows just inserted above.
-- Where your examples listed an item that is also its own top-level
-- category (e.g. Cement, Iron & Steel under "Building Materials"; phone/
-- computer accessories under "Mobiles"/"Computers"), it's placed under
-- its own matching top-level category instead of duplicated as a child,
-- so the same concept never appears twice in the tree.
do $$
declare
  v_parent uuid;
begin
  -- Building Materials
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Building Materials');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Bricks', 1), ('Blocks', 2), ('Sand', 3), ('Aggregates', 4),
    ('Roofing', 5), ('Plywood', 6), ('Boards', 7), ('Construction Chemicals', 8)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Iron & Steel
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Iron & Steel');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('TMT Bars', 1), ('MS Rods', 2), ('MS Pipes', 3), ('GI Pipes', 4),
    ('Angles', 5), ('Channels', 6), ('Sheets', 7), ('Plates', 8), ('Binding Wire', 9)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Hardware
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Hardware');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Hand Tools', 1), ('Power Tools', 2), ('Fasteners', 3), ('Nuts & Bolts', 4),
    ('Locks', 5), ('Hinges', 6), ('Adhesives', 7), ('Pipes & Fittings', 8), ('Safety Equipment', 9)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Electronics
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Electronics');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Televisions', 1), ('Refrigerators', 2), ('Washing Machines', 3), ('Fans', 4),
    ('Air Conditioners', 5), ('Kitchen Appliances', 6), ('Speakers', 7), ('Cameras', 8)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Mobile Phones
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Mobile Phones');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values ('Smartphones', 1), ('Feature Phones', 2)) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Mobile Accessories
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Mobile Accessories');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Chargers', 1), ('Cables', 2), ('Power Banks', 3), ('Earphones', 4), ('Cases', 5), ('Screen Protectors', 6)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Laptops & Computers
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Laptops & Computers');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values ('Laptops', 1), ('Desktops', 2), ('Monitors', 3)) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Computer Accessories
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Computer Accessories');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Keyboards', 1), ('Mouse', 2), ('Storage', 3), ('Printers', 4), ('Networking Accessories', 5)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Furniture
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Furniture');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Chairs', 1), ('Tables', 2), ('Beds', 3), ('Sofas', 4),
    ('Wardrobes', 5), ('Office Furniture', 6), ('Shop Furniture', 7), ('Storage', 8)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Medicines & Pharmacy
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Medicines & Pharmacy');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Prescription Medicines', 1), ('OTC Medicines', 2), ('First Aid', 3), ('Medical Devices', 4), ('Wellness', 5)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;

  -- Grocery & Daily Essentials -- mirrors the existing free-text grocery
  -- categories already used on master_products.category, so the two
  -- systems describe the same concepts going forward.
  select id into v_parent from categories where parent_id is null and lower(name) = lower('Grocery & Daily Essentials');
  insert into categories (name, parent_id, display_order)
  select v, v_parent, ord from (values
    ('Rice & Grains', 1), ('Dal & Pulses', 2), ('Flour', 3), ('Oil', 4), ('Spices', 5), ('Packaged Food', 6)
  ) as t(v, ord)
  on conflict (lower(name), coalesce(parent_id, '00000000-0000-0000-0000-000000000000'::uuid)) do nothing;
end $$;

-- ============================================================
-- Note: Prescription medicines under "Medicines & Pharmacy" are NOT
-- restricted from ordering by this migration -- that needs a legal/
-- compliance + prescription-verification workflow this phase explicitly
-- does not build (per your spec). Flagging so it isn't assumed covered.
--
-- Note: existing master_products/products rows are NOT backfilled with
-- category_id/subcategory_id here -- their free-text `category` column
-- keeps working unchanged. Backfilling is a safe, optional follow-up
-- (not required for the new categories/images/units to work).
-- ============================================================
