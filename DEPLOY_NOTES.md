# Deploy Notes

## Scope
- Invite flow UX and state handling in `InvitesScreen`.
- Correct RPC parameter for deleting own invites (`soft_delete_invite`).
- Added/updated tests for join/leave/delete behavior.

## Included Changes
- `Gå med`:
  - Does not auto-open `Meet`.
  - Does not auto-switch tab.
  - Keeps other cards visible in `Andras`.
- `Lämna`:
  - Keeps user on current tab.
  - No forced reload/tab jump.
  - Invite returns logically to `Andras`.
- Host invite card action:
  - Main button shows `Radera` for own invites.
  - Uses existing delete confirmation flow.
- Card status/count after optimistic join:
  - 1:1 invite now shows `1/1` and `Full` immediately.
- Delete RPC:
  - Calls `soft_delete_invite` with `p_invite_id` (required signature).

## Database Prerequisites
- Ensure function exists with expected signature:
  - `public.soft_delete_invite(p_invite_id uuid)`
- Relevant migration file:
  - `supabase/migrations/20260206171000_invites_soft_delete_and_audit.sql`

## Validation Run
- `flutter test test/invites_screen_flow_test.dart`
- `flutter test`
- `flutter analyze`

## Manual QA Checklist
1. Open `Andras`, join one invite:
   - Joined card disappears from `Andras`.
   - Other cards stay visible.
   - User remains on current tab.
2. Open `Tackat ja`:
   - Joined 1:1 invite shows `1/1` and `Full`.
3. Tap `Lämna` on joined invite:
   - User remains on current tab.
   - Invite appears again in `Andras`.
4. Open `Mina` for own invite:
   - Main button text is `Radera`.
   - Confirm delete works without RPC parameter error.

## Rollback
- Revert commit(s) affecting:
  - `lib/screens/invites_screen.dart`
  - `test/invites_screen_flow_test.dart`
  - `test/invite_buckets_test.dart`
- If needed, redeploy previous app build while keeping DB unchanged.
