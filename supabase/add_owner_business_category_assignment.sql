-- ============================================================
-- OdiaTraders: Admin-assigned Primary + Additional business categories
-- for an owner, set at Add/Edit Owner time. Additive only -- extends the
-- existing business_categories table (already used by the owner-facing
-- "What does your business sell?" flow) with one nullable-by-default
-- column; no existing row is touched, and nothing here can delete a
-- product, order, or invoice.
-- ============================================================

alter table business_categories add column if not exists is_primary boolean not null default false;

-- At most one primary category per business.
create unique index if not exists business_categories_one_primary
  on business_categories (business_id)
  where is_primary;

-- ----------------------------------------------------------
-- Admin: read a business's current category selection (admin isn't
-- necessarily a business_member of every business, so this can't rely
-- on the existing business_categories_select_member RLS policy -- same
-- security-definer + explicit role check pattern as the rest of
-- add_admin_catalog_management.sql).
-- ----------------------------------------------------------
create or replace function admin_get_business_categories(p_business_id uuid)
returns table(category_id uuid, is_primary boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  return query
  select bc.category_id, bc.is_primary
  from business_categories bc
  where bc.business_id = p_business_id
    and bc.is_active = true;
end;
$$;

grant execute on function admin_get_business_categories(uuid) to authenticated;

-- ----------------------------------------------------------
-- Admin: set a business's primary + additional categories in one call.
-- Never deletes a row -- a category removed from the selection is only
-- soft-deactivated (is_active = false), so it stops showing in the
-- owner's default Add-from-Catalog filter without touching any product,
-- order, or invoice that already references it.
-- ----------------------------------------------------------
create or replace function admin_set_owner_categories(
  p_business_id uuid,
  p_primary_category_id uuid,
  p_additional_category_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_category_id uuid;
  v_keep_ids uuid[];
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  if p_primary_category_id is null then
    raise exception 'A primary business category is required.';
  end if;

  v_keep_ids := array_append(coalesce(p_additional_category_ids, '{}'), p_primary_category_id);

  insert into business_categories (business_id, category_id, is_primary, is_active)
  values (p_business_id, p_primary_category_id, true, true)
  on conflict (business_id, category_id)
  do update set is_primary = true, is_active = true;

  -- Demote anything that was previously primary for this business (the
  -- partial unique index above would otherwise reject having two).
  update business_categories
  set is_primary = false
  where business_id = p_business_id
    and category_id <> p_primary_category_id
    and is_primary = true;

  foreach v_category_id in array coalesce(p_additional_category_ids, '{}')
  loop
    if v_category_id = p_primary_category_id then
      continue;
    end if;
    insert into business_categories (business_id, category_id, is_primary, is_active)
    values (p_business_id, v_category_id, false, true)
    on conflict (business_id, category_id)
    do update set is_active = true, is_primary = false;
  end loop;

  update business_categories
  set is_active = false
  where business_id = p_business_id
    and not (category_id = any (v_keep_ids))
    and is_active = true;
end;
$$;

grant execute on function admin_set_owner_categories(uuid, uuid, uuid[]) to authenticated;
