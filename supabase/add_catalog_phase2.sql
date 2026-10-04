-- ============================================================
-- OdiaTraders: multi-category B2B catalog -- Phase 2.
-- Additive only. No existing table recreated, no existing row touched.
-- Safe to re-run (create if not exists / add column if not exists).
-- ============================================================

-- ----------------------------------------------------------
-- 1. Advanced selling-option fields (MRP, tax rate) -- sku was already
--    added in add_catalog_categories.sql. Nullable, so every existing
--    variant keeps working unchanged with these simply unset.
-- ----------------------------------------------------------
alter table product_variants add column if not exists mrp numeric;
alter table product_variants add column if not exists tax_rate numeric;

-- ----------------------------------------------------------
-- 2. Owner-product-level specifications (category-specific attributes --
--    RAM/storage, cement grade, steel diameter, etc.) as flexible JSONB,
--    deliberately not one enormous column-per-attribute table. Lives on
--    `products` (not just `master_products`) so a custom product with no
--    master_product_id can carry its own specs too.
-- ----------------------------------------------------------
alter table products add column if not exists specifications jsonb;

-- ----------------------------------------------------------
-- 3. Storage bucket for owner-uploaded product photos (custom products).
--    Public read (customers need to load the image without being signed
--    in to this specific business), write restricted to an active member
--    of the business whose id is the first path segment of the object key
--    (e.g. "<business_id>/171234567.jpg").
-- ----------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('catalog-products', 'catalog-products', true)
on conflict (id) do nothing;

drop policy if exists "catalog_products_public_read" on storage.objects;
create policy "catalog_products_public_read" on storage.objects
for select using (bucket_id = 'catalog-products');

drop policy if exists "catalog_products_member_upload" on storage.objects;
create policy "catalog_products_member_upload" on storage.objects
for insert with check (
  bucket_id = 'catalog-products'
  and exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.business_id::text = (storage.foldername(name))[1]
  )
);

drop policy if exists "catalog_products_member_update" on storage.objects;
create policy "catalog_products_member_update" on storage.objects
for update using (
  bucket_id = 'catalog-products'
  and exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.business_id::text = (storage.foldername(name))[1]
  )
);

drop policy if exists "catalog_products_member_delete" on storage.objects;
create policy "catalog_products_member_delete" on storage.objects
for delete using (
  bucket_id = 'catalog-products'
  and exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.status = 'active'
      and bm.business_id::text = (storage.foldername(name))[1]
  )
);
