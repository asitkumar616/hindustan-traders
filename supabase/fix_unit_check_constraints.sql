-- ============================================================
-- OdiaTraders: widen the base_unit/unit CHECK constraints to match the
-- expanded kVariantUnits list added for the multi-category catalog
-- (Phase 1). The old constraint only allowed the original grocery-era
-- units (KG, GRAM, LTR, ML, PCS, BAG, PACK, BOX, CARTON), which rejects
-- every new unit (TON, FEET, PAIR, STRIP, ...) needed by the new
-- business categories -- this is what "violates check constraint
-- master_products_base_unit_check" means.
--
-- Finds and drops whatever the existing check constraint is actually
-- named (introspected, not assumed) on master_products.base_unit,
-- product_variants.unit, and products.unit, then adds back a single
-- constraint allowing the full unit list. Safe to re-run.
-- ============================================================

do $$
declare
  r record;
  allowed text := $al$('KG','GRAM','LTR','ML','PCS','BAG','PACK','BOX','CARTON','BUNDLE','FEET','METER','SQFT','SQM','TON','SHEET','ROLL','PAIR','DOZEN','BOTTLE','STRIP','UNIT')$al$;
begin
  -- master_products.base_unit
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_attribute att on att.attrelid = rel.oid and att.attnum = any(con.conkey)
    where con.contype = 'c' and rel.relname = 'master_products' and att.attname = 'base_unit'
  loop
    execute format('alter table master_products drop constraint %I', r.conname);
  end loop;
  execute format('alter table master_products add constraint master_products_base_unit_check check (base_unit in %s)', allowed);

  -- product_variants.unit
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_attribute att on att.attrelid = rel.oid and att.attnum = any(con.conkey)
    where con.contype = 'c' and rel.relname = 'product_variants' and att.attname = 'unit'
  loop
    execute format('alter table product_variants drop constraint %I', r.conname);
  end loop;
  execute format('alter table product_variants add constraint product_variants_unit_check check (unit in %s)', allowed);

  -- products.unit (only if a check constraint already exists there --
  -- this table has always accepted free text as far as the app code is
  -- concerned, so this is defensive, not expected to find anything)
  for r in
    select con.conname
    from pg_constraint con
    join pg_class rel on rel.oid = con.conrelid
    join pg_attribute att on att.attrelid = rel.oid and att.attnum = any(con.conkey)
    where con.contype = 'c' and rel.relname = 'products' and att.attname = 'unit'
  loop
    execute format('alter table products drop constraint %I', r.conname);
    execute format('alter table products add constraint products_unit_check check (unit in %s)', allowed);
  end loop;
end $$;
