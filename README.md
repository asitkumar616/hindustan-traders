# Hindustan Traders

A production-ready wholesale grocery ordering app for Hindustan Traders.

## Project setup

- Flutter frontend
- Supabase backend
- Odia, Hindi, English localization
- OTP login starter flow (phone + OTP verification)
- Role routing starter flow (customer/owner placeholders)

## Local development

1. Install Flutter
2. Run `flutter pub get`
3. Configure `.env` with Supabase settings
4. Start the app with `flutter run`

See backend details in `BACKEND_SETUP.md`.

## Current status

- Supabase schema file is available at `supabase/schema.sql`
- Localization and language selection are wired
- OTP authentication is wired to Supabase phone auth
- Profile is fetched/created after OTP verification and used for role routing
- Starter RLS policies added for core tables
- Indian phone normalization to E.164 (`+91XXXXXXXXXX`) is wired before OTP send
- Test scaffold added under `test/` for phone normalization and login integration flow

## Next steps

- Add voice order scaffolding

## Manual smoke checklist

1. Launch app and verify splash opens language selection.
2. Select each language and verify login labels/buttons change.
3. Enter invalid phone and verify validation message appears.
4. Enter valid phone and send OTP.
5. Enter OTP and verify app navigates to home screen.
6. In Supabase `profiles`, verify a row exists for first-time login.
7. Change `profiles.role` to `owner` and verify next login follows owner route.
