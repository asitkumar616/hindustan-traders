-- ============================================================
-- OdiaTraders: adds an optional free-text description/notes field to
-- products, for the redesigned Add/Edit Product screens' "Additional
-- Details" section. Additive only -- existing rows get NULL, nothing
-- currently reads this column so no existing behavior changes.
-- Safe to re-run.
-- ============================================================
alter table products add column if not exists description text;
