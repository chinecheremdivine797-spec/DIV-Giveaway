-- DIV GIVEAWAY — Supabase public registration security repair
-- Run this file in Supabase SQL Editor once.

begin;

-- Public registrations must be allowed through RLS.
alter table public.participants enable row level security;

drop policy if exists "Public can submit giveaway entries" on public.participants;
drop policy if exists "Anyone can submit giveaway entries" on public.participants;

create policy "Public can submit giveaway entries"
on public.participants
as permissive
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

-- Keep admin authorization protected.
alter table public.admin_users enable row level security;

drop policy if exists "Admins can read own admin record" on public.admin_users;
create policy "Admins can read own admin record"
on public.admin_users
as permissive
for select
to authenticated
using (user_id = auth.uid());

commit;
