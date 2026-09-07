-- DIV GIVEAWAY — Supabase database schema
-- Run this entire file in Supabase SQL Editor.
--
-- Security model:
--   * Anonymous visitors can INSERT giveaway entries only.
--   * Anonymous visitors cannot SELECT, UPDATE, or DELETE participants.
--   * Authenticated admins are stored in public.admin_users and can manage entries.
--   * Gift-card codes are never exposed to the anon role.
--   * Admin authorization is checked in a private SECURITY DEFINER function.
--   * No service-role/secret key belongs in browser code.

begin;

create extension if not exists pgcrypto;

-- Keep the admin helper outside the exposed public API schema.
create schema if not exists private;

-- ============================================================
-- ADMIN USERS
-- ============================================================
-- The id must match a user id from auth.users.
-- Create the user first in Supabase Auth, then insert that UUID here.
create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

revoke all on table public.admin_users from anon, authenticated;
grant select on table public.admin_users to authenticated;

-- Only the server/database owner should be able to manage this allow-list.
-- Do not create client-side INSERT/UPDATE/DELETE policies for admin_users.

-- ============================================================
-- ADMIN CHECK
-- ============================================================
create or replace function private.is_div_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users
    where user_id = (select auth.uid())
  );
$$;

revoke execute on function private.is_div_admin() from public;
revoke execute on function private.is_div_admin() from anon;
grant execute on function private.is_div_admin() to authenticated;

-- ============================================================
-- PARTICIPANTS
-- ============================================================
create table if not exists public.participants (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (char_length(trim(full_name)) between 2 and 100),
  email text not null check (char_length(trim(email)) between 5 and 160),
  phone text,
  country text not null check (char_length(trim(country)) between 2 and 60),
  app_interest text not null check (
    app_interest in (
      'DIV Song AI',
      'DIV Studio AI',
      'DIV Med AI',
      'JobGuard NG',
      'Another DIV app',
      'All upcoming DIV apps'
    )
  ),
  social_handle text,

  -- Giveaway action confirmations. These are participant claims until an admin verifies them.
  share_repost_confirmed boolean not null default false,
  follow_channels_confirmed boolean not null default false,
  youtube_subscribed_confirmed boolean not null default false,
  proof_url text,

  consent boolean not null default false,

  -- Verification state is controlled by admins only.
  verification_status text not null default 'pending' check (
    verification_status in ('pending', 'under_review', 'verified', 'rejected')
  ),
  share_repost_verified boolean not null default false,
  follow_channels_verified boolean not null default false,
  youtube_subscribed_verified boolean not null default false,
  verified_at timestamptz,
  verified_by uuid references auth.users(id) on delete set null,

  -- Giveaway/gift-card state is controlled by admins only.
  status text not null default 'eligible' check (
    status in ('eligible', 'selected', 'not_selected', 'contacted', 'completed')
  ),
  gift_card_status text not null default 'not_sent' check (
    gift_card_status in ('not_sent', 'reserved', 'sent', 'claimed', 'cancelled')
  ),
  gift_card_code text,
  gift_card_sent_at timestamptz,
  gift_card_claimed_at timestamptz,
  admin_notes text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Normalize email for duplicate detection without changing the stored value.
create unique index if not exists participants_email_unique_idx
  on public.participants (lower(trim(email)));

create index if not exists participants_created_at_idx
  on public.participants (created_at desc);

create index if not exists participants_status_idx
  on public.participants (status);

create index if not exists participants_verification_status_idx
  on public.participants (verification_status);

create index if not exists participants_country_idx
  on public.participants (country);

alter table public.participants enable row level security;

-- Explicit least-privilege grants.
revoke all on table public.participants from anon, authenticated;
grant insert on table public.participants to anon;
grant select, update on table public.participants to authenticated;

-- ============================================================
-- PARTICIPANT RLS
-- ============================================================
-- Public registration: visitors can submit only an entry in the safe initial state.
-- They cannot set themselves as verified, selected, or gift-card recipients.
drop policy if exists "Public can submit giveaway entries" on public.participants;
create policy "Public can submit giveaway entries"
on public.participants
for insert
to anon
with check (
  consent = true
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

-- Authenticated users get no general participant SELECT access.
-- Only admins can read participant records.
drop policy if exists "Admins can view participants" on public.participants;
create policy "Admins can view participants"
on public.participants
for select
to authenticated
using ((select private.is_div_admin()));

-- Only admins can update verification, winner, and gift-card fields.
drop policy if exists "Admins can update participants" on public.participants;
create policy "Admins can update participants"
on public.participants
for update
to authenticated
using ((select private.is_div_admin()))
with check ((select private.is_div_admin()));

-- No DELETE policy is intentionally provided. Keep participant history intact.

-- ============================================================
-- UPDATED_AT TRIGGER
-- ============================================================
create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke execute on function private.set_updated_at() from public;

 drop trigger if exists participants_set_updated_at on public.participants;
create trigger participants_set_updated_at
before update on public.participants
for each row
execute function private.set_updated_at();

-- ============================================================
-- ADMIN VERIFICATION FUNCTION
-- ============================================================
-- Optional convenience function for the admin dashboard.
-- It verifies the three required giveaway actions and records who verified them.
create or replace function private.verify_giveaway_entry(
  participant_id uuid,
  new_share_repost_verified boolean,
  new_follow_channels_verified boolean,
  new_youtube_subscribed_verified boolean,
  new_admin_notes text default null
)
returns public.participants
language plpgsql
security definer
set search_path = ''
as $$
declare
  result public.participants;
  all_verified boolean;
begin
  if not exists (
    select 1
    from public.admin_users
    where user_id = (select auth.uid())
  ) then
    raise exception 'Not authorized';
  end if;

  all_verified :=
    new_share_repost_verified
    and new_follow_channels_verified
    and new_youtube_subscribed_verified;

  update public.participants
  set
    share_repost_verified = new_share_repost_verified,
    follow_channels_verified = new_follow_channels_verified,
    youtube_subscribed_verified = new_youtube_subscribed_verified,
    verification_status = case when all_verified then 'verified' else 'under_review' end,
    verified_at = case when all_verified then now() else null end,
    verified_by = case when all_verified then (select auth.uid()) else null end,
    admin_notes = coalesce(new_admin_notes, admin_notes),
    updated_at = now()
  where id = participant_id
  returning * into result;

  if result.id is null then
    raise exception 'Participant not found';
  end if;

  return result;
end;
$$;

revoke execute on function private.verify_giveaway_entry(uuid, boolean, boolean, boolean, text) from public;
revoke execute on function private.verify_giveaway_entry(uuid, boolean, boolean, boolean, text) from anon;
grant execute on function private.verify_giveaway_entry(uuid, boolean, boolean, boolean, text) to authenticated;

-- ============================================================
-- ADMIN STATS VIEW
-- ============================================================
-- A security-invoker view means its access is still controlled by the
-- underlying RLS policies instead of accidentally bypassing them.
create or replace view public.admin_giveaway_stats
with (security_invoker = true)
as
select
  count(*)::bigint as total_participants,
  count(*) filter (where status = 'selected')::bigint as selected_winners,
  count(*) filter (where gift_card_status in ('sent', 'claimed'))::bigint as gift_cards_sent,
  count(*) filter (where verification_status = 'verified')::bigint as verified_entries,
  count(*) filter (where created_at >= current_date)::bigint as entries_today,
  count(*) filter (where created_at >= date_trunc('week', now()))::bigint as entries_this_week,
  count(*) filter (where created_at >= date_trunc('month', now()))::bigint as entries_this_month
from public.participants;

revoke all on public.admin_giveaway_stats from anon;
grant select on public.admin_giveaway_stats to authenticated;

-- ============================================================
-- SAFE ADMIN BOOTSTRAP
-- ============================================================
-- After creating your admin account in Supabase Auth, run ONE statement like:
--
-- insert into public.admin_users (user_id, display_name)
-- values ('YOUR-AUTH-USER-UUID', 'DIV Admin');
--
-- Do NOT put the UUID or admin credentials in browser JavaScript.

commit;

-- ============================================================
-- OPTIONAL VERIFICATION QUERIES
-- ============================================================
-- After running the schema, these should succeed in the SQL Editor:
--
-- select * from pg_policies where schemaname = 'public'
--   and tablename in ('participants', 'admin_users');
--
-- select relname, relrowsecurity
-- from pg_class
-- where relname in ('participants', 'admin_users');
