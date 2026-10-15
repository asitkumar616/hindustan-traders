-- ============================================================
-- DRAFT -- NOT YET RUN. For review only (Step 4). Nothing here disables
-- the current mvp_login_with_phone path -- that happens in a separate,
-- clearly-marked statement at the bottom, which should only be run AFTER
-- the new Flutter login/activation UI is built, tested, and deployed
-- (Step 5+), so existing users are never locked out mid-migration.
--
-- Everything above that line is purely additive: new columns (nullable),
-- a new table, and new functions. No existing profile, business, order,
-- or invoice row is touched. No existing function is modified here (the
-- 8 vulnerable admin RPCs are handled separately in
-- DRAFT_fix_admin_rpc_authorization.sql, which can be applied
-- independently and immediately -- it doesn't depend on any of this).
-- ============================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------
-- 1. Profiles: link to a real Supabase Auth user, plus login-attempt
--    tracking. auth_user_id is intentionally separate from profiles.id --
--    under the CURRENT scheme profiles.id already equals auth.uid()
--    (because mvp_login_with_phone mints a fresh profile row per
--    anonymous session), but the whole point of this migration is to
--    stop doing that. Going forward, profiles.id is the stable identity
--    that orders/invoices/business_members already key off of, and
--    auth_user_id is just "which Supabase Auth user currently
--    authenticates as this profile" -- it can be re-pointed later (e.g.
--    to a phone-OTP identity) without profiles.id ever changing, which
--    is what requirement 14 (future phone-OTP support) needs.
-- ----------------------------------------------------------
alter table profiles add column if not exists auth_user_id uuid references auth.users(id);
alter table profiles add column if not exists login_email text;
alter table profiles add column if not exists failed_login_count int not null default 0;
alter table profiles add column if not exists locked_until timestamptz;

create unique index if not exists profiles_auth_user_id_uniq on profiles (auth_user_id) where auth_user_id is not null;
create unique index if not exists profiles_login_email_uniq on profiles (login_email) where login_email is not null;

-- ----------------------------------------------------------
-- 2. One-time activation / password-reset codes. RLS is enabled with NO
--    policies at all -- that means zero access for anon/authenticated
--    directly; the only way in or out is through the SECURITY DEFINER
--    functions below (and the activate-account Edge Function, which uses
--    the service-role key and bypasses RLS entirely by design).
-- ----------------------------------------------------------
create table if not exists account_activation_codes (
  id uuid primary key default uuid_generate_v4(),
  profile_id uuid not null references profiles(id) on delete cascade,
  code_hash text not null,
  purpose text not null default 'activation' check (purpose in ('activation', 'password_reset')),
  expires_at timestamptz not null,
  used_at timestamptz,
  issued_by uuid references profiles(id),
  created_at timestamptz default now()
);

create index if not exists account_activation_codes_profile_id_idx on account_activation_codes (profile_id);

alter table account_activation_codes enable row level security;
-- Deliberately no policies -- see comment above.

-- ----------------------------------------------------------
-- 3. Admin issues a one-time code (for first activation, or to help a
--    locked-out/forgetful user reset their password). Returns the
--    PLAINTEXT code exactly once -- only this call site ever sees it;
--    only its SHA-256 hash is stored. The admin relays it through
--    whatever channel they already use to talk to this owner/customer
--    (call, WhatsApp, in person) -- never automated, per the no-SMS
--    constraint.
-- ----------------------------------------------------------
create or replace function admin_issue_activation_code(
  p_profile_id uuid,
  p_purpose text default 'activation'
)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_target profiles%rowtype;
begin
  if not exists (select 1 from profiles where id = auth.uid() and role = 'admin') then
    raise exception 'Not authorized.';
  end if;

  if p_purpose not in ('activation', 'password_reset') then
    raise exception 'Invalid purpose.';
  end if;

  select * into v_target from profiles where id = p_profile_id;
  if not found then
    raise exception 'Profile not found.';
  end if;

  if p_purpose = 'activation' and v_target.auth_user_id is not null then
    raise exception 'This account is already activated. Use password_reset instead.';
  end if;

  if p_purpose = 'password_reset' and v_target.auth_user_id is null then
    raise exception 'This account has not been activated yet. Use activation instead.';
  end if;

  -- 10 chars from an unambiguous alphabet (no 0/O/1/I/l) -- read aloud or
  -- typed from a WhatsApp message without transcription errors. ~51 bits
  -- of entropy, single-use, short-lived -- adequate against a rate-limited,
  -- one-shot guess; not meant to resist offline brute force the way a
  -- long-lived password hash must.
  v_code := (
    select string_agg(substr('23456789ABCDEFGHJKMNPQRSTUVWXYZ', (random() * 31)::int + 1, 1), '')
    from generate_series(1, 10)
  );

  insert into account_activation_codes (profile_id, code_hash, purpose, expires_at, issued_by)
  values (
    p_profile_id,
    encode(digest(v_code, 'sha256'), 'hex'),
    p_purpose,
    now() + interval '48 hours',
    auth.uid()
  );

  return v_code;
end;
$$;

grant execute on function admin_issue_activation_code(uuid, text) to authenticated;

-- ----------------------------------------------------------
-- 4. Login support -- both granted to `anon` as well as `authenticated`,
--    since the whole point is to work BEFORE the user has a session.
-- ----------------------------------------------------------

-- Phone -> opaque login email, or null if the account doesn't exist,
-- isn't activated yet, is deleted/inactive/unapproved, or is currently
-- locked out. Deliberately returns null (never a distinguishing error)
-- for all of these so the client always shows one generic message and
-- can't be used to enumerate which phone numbers are registered.
create or replace function resolve_login_email(p_phone text)
returns text
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_digits text;
  v_phone text;
  v_profile profiles%rowtype;
begin
  v_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if length(v_digits) = 10 then
    v_phone := '+91' || v_digits;
  elsif length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_phone := '+91' || substring(v_digits from 2);
  elsif length(v_digits) = 12 and left(v_digits, 2) = '91' then
    v_phone := '+' || v_digits;
  else
    return null;
  end if;

  select * into v_profile from profiles where phone = v_phone;
  if not found then
    return null;
  end if;

  if v_profile.auth_user_id is null or v_profile.login_email is null then
    return null;
  end if;

  if v_profile.deleted_at is not null or v_profile.is_active = false then
    return null;
  end if;

  if (v_profile.role in ('owner', 'customer')) and v_profile.approval_status <> 'approved' then
    return null;
  end if;

  if v_profile.locked_until is not null and v_profile.locked_until > now() then
    return null;
  end if;

  return v_profile.login_email;
end;
$$;

grant execute on function resolve_login_email(text) to anon, authenticated;

-- Called by the client right after every signInWithPassword attempt.
-- This is a UX-visible defense-in-depth layer, not the primary defense --
-- Supabase's own project-level Auth rate limiting (Dashboard > Auth >
-- Rate Limits) is what actually protects signInWithPassword itself and
-- can't be bypassed by a client that skips calling this.
create or replace function record_login_attempt(p_phone text, p_success boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_digits text;
  v_phone text;
  v_count int;
begin
  v_digits := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if length(v_digits) = 10 then
    v_phone := '+91' || v_digits;
  elsif length(v_digits) = 11 and left(v_digits, 1) = '0' then
    v_phone := '+91' || substring(v_digits from 2);
  elsif length(v_digits) = 12 and left(v_digits, 2) = '91' then
    v_phone := '+' || v_digits;
  else
    return;
  end if;

  if p_success then
    update profiles set failed_login_count = 0, locked_until = null where phone = v_phone;
    return;
  end if;

  update profiles
  set failed_login_count = failed_login_count + 1
  where phone = v_phone
  returning failed_login_count into v_count;

  if v_count is not null and v_count >= 5 then
    -- Progressive: 5 min at the 5th failure, growing by 5 min per
    -- additional failure, capped at 1 hour.
    update profiles
    set locked_until = now() + (least(v_count - 4, 12) * interval '5 minutes')
    where phone = v_phone;
  end if;
end;
$$;

grant execute on function record_login_attempt(text, boolean) to anon, authenticated;

-- ============================================================
-- DO NOT RUN THE STATEMENT BELOW until the new login/activation UI is
-- built, tested, and deployed (Step 5+). Revoking this immediately would
-- lock every current owner/customer/admin out, since the live app still
-- only knows how to call mvp_login_with_phone.
-- ============================================================
-- revoke execute on function mvp_login_with_phone(text) from authenticated;
