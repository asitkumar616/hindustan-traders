-- ============================================================
-- OdiaTraders: replace the generic "Smartphone"/"Feature Phone" catalog
-- entries with specific phone brands, per request. Only touches rows
-- under the "Mobile Phones" category that no owner has linked into
-- their shop yet (a master_products row an owner already added via
-- "Add from Catalog" is deliberately left alone -- deleting it would
-- orphan their products(master_product_id) reference).
-- Safe to re-run.
-- ============================================================

delete from master_products mp
where mp.category = 'Mobile Phones'
  and mp.product_name in ('Smartphone', 'Feature Phone')
  and not exists (select 1 from products p where p.master_product_id = mp.id);

with new_products (product_name, category, base_unit) as (
  values
    ('Samsung Galaxy', 'Mobile Phones', 'PCS'),
    ('Apple iPhone', 'Mobile Phones', 'PCS'),
    ('OnePlus', 'Mobile Phones', 'PCS'),
    ('Vivo', 'Mobile Phones', 'PCS'),
    ('Oppo', 'Mobile Phones', 'PCS'),
    ('Xiaomi Redmi', 'Mobile Phones', 'PCS'),
    ('Realme', 'Mobile Phones', 'PCS'),
    ('Motorola', 'Mobile Phones', 'PCS')
)
insert into master_products (product_name, category, category_id, base_unit, is_active)
select
  np.product_name,
  np.category,
  (select id from categories where parent_id is null and lower(name) = lower(np.category)),
  np.base_unit,
  true
from new_products np
where not exists (
  select 1 from master_products mp
  where lower(mp.product_name) = lower(np.product_name) and lower(mp.category) = lower(np.category)
);
