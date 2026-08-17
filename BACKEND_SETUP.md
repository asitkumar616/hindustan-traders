# Backend Setup (Supabase)

## 1. Create Supabase project
- Create a new project in Supabase.
- Copy the project URL and anon key.

## 2. Configure local environment
Copy `.env.example` to `.env` and update values in project root:

```env
DEFAULT_LANGUAGE=or
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

Important:
- `.env` is bundled into app assets for mobile/web builds.
- After updating `.env`, rebuild and reinstall the APK.

## 3. Apply database schema
- Open SQL editor in Supabase.
- Run schema from `supabase/schema.sql`.

## 4. Enable Anonymous Auth (MVP)
- In Supabase Auth settings, enable anonymous sign-in.
- OTP is not used in MVP mode.

## 5. Seed admin/owner/customer mobile records
- Insert admin/owner/customer rows into `profiles`.
- Set `approval_status` and `is_active` in `profiles`.
- For owners, ensure `businesses` rows are present and linked.
- For customers, ensure `customers` rows are linked to owner businesses.

## 6. Run app
- `flutter pub get`
- `flutter run`

## Notes
- Login is now mobile-number approval based in MVP.
- OTP is intentionally removed for this phase.
