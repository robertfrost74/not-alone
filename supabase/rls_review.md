# RLS Review Checklist

This file documents the queries used by the app and the related RLS policies
that must permit them. Keep it updated when adding new queries.

## Profiles
- App query: select `id, username` for host display names.
- Policy: `profiles_select_public` (select allowed for everyone).
- Migration: `20260206093000_profiles_select_public.sql`

## Group Members
- App query: select `group_members` by `group_id` or `user_id`.
- Policy: `group_members_select_group` via `can_view_group_members`.
- Migration: `20260205101000_group_members_select_all_members.sql`

## Group Invites
- App query: select by `identifier` (email/username).
- Policy: `group_invites_owner_or_invitee_select`.
- Migration: `20260205093000_groups_invites_policies.sql`

## Invites and Invite Members
- App query: select open invites + invite_members.
- Policy: invites select must allow open invites; invite_members select must allow
  viewing joined users for those invites.
- Migration: `20260203092000_create_invites.sql` and related policies.

## Messages
- App query: select direct and group messages.
- Policy: direct messages must allow sender/recipient; group messages must allow
  group members.
- Migration: `20260205102000_messages.sql` and `20260205110000_group_messages.sql`
