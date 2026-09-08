-- DIV GIVEAWAY — Supabase migration for required verification consent
-- Run this in Supabase SQL Editor because the original schema is already installed.

begin;

alter table public.participants
  add column if not exists verification_consent boolean not null default false;

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
