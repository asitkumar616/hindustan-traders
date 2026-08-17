# Fixes applied to the uploaded Flutter project

1. The uploaded `.env` used `NEXT_PUBLIC_SUPABASE_URL` and
   `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, while the Flutter code expected
   `SUPABASE_URL` and `SUPABASE_ANON_KEY`. The Flutter loader now accepts both
   names, and `.env.example` documents the Flutter names.

2. Android now explicitly declares INTERNET permission.

3. The Admin login now creates the existing anonymous Supabase session before
   calling Admin RPCs. This is required because the SQL grants those RPCs to
   the `authenticated` role. This is an MVP workaround, NOT production-grade
   admin authentication.

4. The real `.env` was intentionally omitted from this returned ZIP to avoid
   redistributing credentials. Create it from `.env.example` and insert your
   own Supabase project URL and publishable key.

IMPORTANT DATABASE SECURITY FINDING:
The current `admin_*` security-definer RPCs are granted to `authenticated` but
do not themselves verify that the caller is an admin. Therefore, anonymous
MVP sessions should NOT be considered secure production admin authentication.
Before going live, replace the local admin username/password + anonymous
session with a real Supabase Auth admin identity and add server-side admin
authorization checks to every admin RPC.

Also apply `supabase/schema.sql` to the same Supabase project before testing
RPCs if it has not already been applied.
