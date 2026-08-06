# Backend Setup (Supabase)

## 1. Create Supabase project
- Create a new project in Supabase.
- Copy the project URL and anon key.

## 2. Configure local environment
Update `.env` in project root:

```env
DEFAULT_LANGUAGE=or
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

## 3. Apply database schema
- Open SQL editor in Supabase.
- Run schema from `supabase/schema.sql`.

## 4. Enable Phone Auth
- In Supabase Auth settings, enable phone sign-in.
- Configure OTP provider for dev/prod as needed.

## 5. Run app
- `flutter pub get`
- `flutter run`

## Notes
- Login flow now sends and verifies SMS OTP.
- Role routing currently defaults to customer until profile role fetch is added.
