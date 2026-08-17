# MVP Authentication (Approved Mobile Number)

This project currently uses an MVP login flow without OTP.

## Current Login Flow

1. User enters mobile number.
2. App signs in with Supabase anonymous auth.
3. App calls `mvp_login_with_phone` RPC.
4. RPC validates that mobile number exists in `profiles`, is approved, and active.
5. RPC links the current authenticated user to the right role/business using existing tables.
6. User is routed to Owner, Customer, or Admin area.

## Tables Used

- `profiles` (role, phone, approval_status, is_active, default_business_id)
- `businesses`
- `business_members`
- `customers`
- `customer_businesses`

## Admin Owner Management

Admin features use these RPCs:

- `admin_owner_list`
- `admin_owner_create`
- `admin_owner_update`
- `admin_owner_set_state`

Owner status is controlled by:

- `approval_status`: `pending` | `approved` | `rejected`
- `is_active`: `true` | `false`

## Security Notes

- No OTP is used in MVP mode.
- No `service_role` key is used in Flutter.
- RLS remains enabled.
- Access control is enforced in security-definer RPCs and role-linked business membership.

## Run

- `flutter run`
- `flutter run -d chrome`
- `flutter build apk --release`

## Before Production Release

1. Replace MVP mobile approval login with real production authentication.
2. Remove anonymous-login dependency if not needed.
3. Re-validate RLS for production auth identities.
