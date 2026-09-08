begin;

-- Keep this migration safe for the existing production database.
-- It can be applied repeatedly without exposing admin records publicly.

alter table public.participants
  add column if not exists verification_consent boolean not null default false;

-- Admins may read only their own allow-list record. This is required by the
-- browser admin login check while keeping the admin list private.
drop policy if exists "Admins can read own admin record" on public.admin_users;
create policy "Admins can read own admin record"
on public.admin_users
for select
to authenticated
using (user_id = auth.uid());

-- Public registration is restricted to a valid giveaway submission.
drop policy if exists "Public can submit giveaway entries" on public.participants;
create policy "Public can submit giveaway entries"
on public.participants
for insert
to anon
with check (
  consent = true
  and verification_consent = true
  and verification_status = 'pending'
  and share_repost_verified = false
  and follow_channels_verified = false
  and youtube_subscribed_verified = false
  and verified_at is null
  and verified_by is null
  and status = 'eligible'
  and gift_card_status = 'not_sent'
  and gift_card_code is null
  and gift_card_sent_at is null
  and gift_card_claimed_at is null
);

commit;
