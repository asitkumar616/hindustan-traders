-- Fix: notifications table had RLS enabled but only a SELECT policy, so
-- every insert (including the existing "invoice draft created" notice in
-- order_draft_service.dart, and the new "order packed" notice added when
-- an owner marks an order ready) was silently rejected by RLS. Also adds
-- an UPDATE policy so a recipient can mark their own notifications read.

drop policy if exists "notifications_insert_business_member" on notifications;
create policy "notifications_insert_business_member" on notifications
for insert with check (
  exists (
    select 1 from business_members bm
    where bm.user_id = auth.uid()
      and bm.business_id = notifications.business_id
      and bm.status = 'active'
  )
);

drop policy if exists "notifications_update_recipient" on notifications;
create policy "notifications_update_recipient" on notifications
for update using (recipient_id = auth.uid())
with check (recipient_id = auth.uid());
