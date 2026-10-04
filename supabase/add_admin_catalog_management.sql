-- ============================================================
-- OdiaTraders: Admin Catalog Management -- Phase 3.
-- Security-definer RPCs so admin writes work regardless of the existing
-- regular-user RLS on categories/master_products (read is open, write is
-- intentionally not -- see add_catalog_categories.sql's comment). Every
-- RPC here re-checks the caller's own profile role = 'admin' before doing
-- anything, since (unlike the older admin_owner_* RPCs) these can create
-- or hide catalog data every business sees.
-- ============================================================

create or replace function admin_category_upsert(
  p_id uuid default null,
  p_name text default null,
  p_parent_id uuid default null,
  p_display_order int default 0
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'Category name is required.';
  end if;

  if p_id is not null then
    update categories
    set name = trim(p_name), parent_id = p_parent_id, display_order = p_display_order
    where id = p_id
    returning id into v_id;
  else
    insert into categories (name, parent_id, display_order)
    values (trim(p_name), p_parent_id, p_display_order)
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

create or replace function admin_category_set_active(p_id uuid, p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;
  update categories set is_active = p_is_active where id = p_id;
end;
$$;

create or replace function admin_master_product_upsert(
  p_id uuid default null,
  p_product_name text default null,
  p_category text default null,
  p_category_id uuid default null,
  p_subcategory_id uuid default null,
  p_brand text default null,
  p_image_url text default null,
  p_base_unit text default 'KG',
  p_specifications jsonb default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  if p_product_name is null or trim(p_product_name) = '' then
    raise exception 'Product name is required.';
  end if;

  if p_id is not null then
    update master_products
    set product_name = trim(p_product_name),
        category = p_category,
        category_id = p_category_id,
        subcategory_id = p_subcategory_id,
        brand = p_brand,
        image_url = p_image_url,
        base_unit = coalesce(p_base_unit, base_unit),
        specifications = p_specifications
    where id = p_id
    returning id into v_id;
  else
    insert into master_products (product_name, category, category_id, subcategory_id, brand, image_url, base_unit, specifications)
    values (trim(p_product_name), p_category, p_category_id, p_subcategory_id, p_brand, p_image_url, coalesce(p_base_unit, 'KG'), p_specifications)
    returning id into v_id;
  end if;

  return v_id;
end;
$$;

create or replace function admin_master_product_set_active(p_id uuid, p_is_active boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;
  update master_products set is_active = p_is_active where id = p_id;
end;
$$;

-- Bulk import -- takes an array of rows already validated client-side by
-- the Import Preview screen (category resolved, unit checked, duplicates
-- flagged) and inserts them in one transaction, so a bad row anywhere
-- can't leave a file half-imported.
create or replace function admin_master_product_bulk_import(p_rows jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
  v_count int := 0;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  for v_row in select * from jsonb_array_elements(p_rows)
  loop
    insert into master_products (product_name, category, category_id, subcategory_id, brand, image_url, base_unit, specifications)
    values (
      trim(v_row->>'product_name'),
      v_row->>'category',
      (v_row->>'category_id')::uuid,
      (v_row->>'subcategory_id')::uuid,
      v_row->>'brand',
      v_row->>'image_url',
      coalesce(v_row->>'base_unit', 'KG'),
      case when v_row->'specifications' is null or v_row->'specifications' = 'null'::jsonb then null else v_row->'specifications' end
    );
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

grant execute on function admin_category_upsert(uuid, text, uuid, int) to authenticated;
grant execute on function admin_category_set_active(uuid, boolean) to authenticated;
grant execute on function admin_master_product_upsert(uuid, text, text, uuid, uuid, text, text, text, jsonb) to authenticated;
grant execute on function admin_master_product_set_active(uuid, boolean) to authenticated;
grant execute on function admin_master_product_bulk_import(jsonb) to authenticated;

-- ----------------------------------------------------------
-- Admin-only image uploads for the master catalog -- a separate bucket
-- from the owner-scoped "catalog-products" bucket (add_catalog_phase2.sql),
-- since master catalog images aren't tied to any one business_id.
-- ----------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('master-catalog-images', 'master-catalog-images', true)
on conflict (id) do nothing;

drop policy if exists "master_catalog_images_public_read" on storage.objects;
create policy "master_catalog_images_public_read" on storage.objects
for select using (bucket_id = 'master-catalog-images');

drop policy if exists "master_catalog_images_admin_write" on storage.objects;
create policy "master_catalog_images_admin_write" on storage.objects
for insert with check (
  bucket_id = 'master-catalog-images'
  and exists (select 1 from profiles where id = auth.uid() and role = 'admin')
);

drop policy if exists "master_catalog_images_admin_update" on storage.objects;
create policy "master_catalog_images_admin_update" on storage.objects
for update using (
  bucket_id = 'master-catalog-images'
  and exists (select 1 from profiles where id = auth.uid() and role = 'admin')
);

drop policy if exists "master_catalog_images_admin_delete" on storage.objects;
create policy "master_catalog_images_admin_delete" on storage.objects
for delete using (
  bucket_id = 'master-catalog-images'
  and exists (select 1 from profiles where id = auth.uid() and role = 'admin')
);
