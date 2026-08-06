# Multi-tenant architecture plan

## 1. Current database architecture

The current schema uses a simple profile-to-business relationship:

- profiles: one `business_id` per profile
- businesses: one `owner_id` per business
- products, orders, notifications: each record is linked to a `business_id`

This works for a very small prototype but it does not model a real multi-owner system because:

- a profile can only belong to one business through `profiles.business_id`
- there is no explicit business membership table
- owner access is inferred indirectly instead of enforced by a robust membership model
- RLS is minimal and does not cover the full tenant boundary

## 2. Problems with the current single-owner approach

The current design makes the following assumptions that conflict with the requirements:

1. A single business per profile is too restrictive.
2. Owners and customers are not modeled as distinct business members with roles.
3. There is no explicit `business_members` table for ownership, staff, and customer relationships.
4. The current RLS rules are too weak for strong tenant isolation.
5. The schema is not ready for future multi-shop customer relationships or business-specific pricing and reporting.

## 3. Proposed multi-tenant ER/data model

The architecture should be centered around businesses and business memberships:

- `profiles`: identity records for auth users
- `businesses`: independent shops/tenants
- `business_members`: membership table for owner/staff/customer relationships
- `customers`: customer records scoped to one business (initial version)
- `products`: product catalog per business
- `product_prices`: business-specific pricing history
- `orders`, `order_items`: orders scoped to one business
- `invoices`, `invoice_items`: invoices scoped to one business
- `payments`, `ledger_entries`: financial records scoped to one business
- `notifications`: notifications scoped to a business and recipient
- `expenses`, `stock_movements`: business operations data

## 4. Tables that need changes

### Existing tables to refactor

- `profiles`
  - retain identity and role information
  - remove the single-business assumption from the app layer
  - keep a nullable `default_business_id` only as a convenience if needed

- `businesses`
  - keep as the main tenant container
  - add `slug`, `status`, `currency`, and `settings` fields later if needed

- `products`
  - keep `business_id`
  - ensure all products are business-scoped

- `orders`
  - keep `business_id`
  - ensure every order is tied to one business

### New tables to add

- `business_members`
- `customers`
- `invoices`
- `invoice_items`
- `payments`
- `ledger_entries`
- `expenses`
- `stock_movements`

## 5. RLS strategy

RLS must be based on business membership and not on Flutter-side filtering.

### Owner/staff access

Owners and staff can access data only when:

- the record belongs to a business
- the authenticated user is an active member of that business
- the member role permits the action

### Customer access

Customers can access records only when:

- the record belongs to a business
- the customer is linked to that business via `business_members`

### Important rule

The database must reject any attempt to access data outside the authenticated user's membership scope.

## 6. Migration plan

1. Add the new `business_members` table and `customers` table.
2. Update the existing schema to stop relying on `profiles.business_id` as the primary tenancy selector.
3. Create RLS policies for businesses, products, orders, customers, invoices, payments, and ledger entries.
4. Add a registration path that creates a business and links the owner as the initial member.
5. Add customer creation flows that assign the customer to a specific business.
6. Add security tests that verify cross-business access is denied.
