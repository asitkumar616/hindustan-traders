-- ============================================================
-- OdiaTraders: diagnostic for "notifications aren't working".
-- Run this in the Supabase SQL Editor and paste back the results --
-- it checks the three most likely causes: missing/wrong RLS policies,
-- whether any notification rows exist at all, and whether owners/
-- customers actually have the business_members row the insert policy
-- requires.
-- ============================================================

-- 1. What policies currently exist on notifications? (Expect 3: a SELECT,
--    an INSERT, and an UPDATE policy -- if INSERT is missing, every
--    notification insert has been silently failing.)
select policyname, cmd, qual, with_check
from pg_policies
where tablename = 'notifications';

-- 2. Is RLS even enabled on the table?
select relrowsecurity from pg_class where relname = 'notifications';

-- 3. How many notifications exist in total, and how recent is the newest?
select count(*) as total_notifications, max(created_at) as most_recent
from notifications;

-- 4. Does every owner have an 'active' business_members row for their own
--    business? (Required by the insert policy for a customer's "new
--    order" notification to reach them -- NOT required for the owner's
--    own price-change notifications.)
select b.id as business_id, b.name, b.owner_id, bm.status as owner_membership_status
from businesses b
left join business_members bm on bm.business_id = b.id and bm.user_id = b.owner_id
order by b.created_at desc
limit 20;

-- 5. Do registered customers have an 'active' business_members row?
--    (Required by the insert policy for the OWNER's price/stock/new-product
--    notifications to reach them.)
select c.business_id, c.display_name, c.profile_id, bm.status as customer_membership_status
from customers c
left join business_members bm on bm.business_id = c.business_id and bm.user_id = c.profile_id
where c.profile_id is not null
order by c.created_at desc
limit 20;
