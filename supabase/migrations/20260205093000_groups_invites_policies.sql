drop policy if exists "group_members_select_self" on public.group_members;
create policy "group_members_select_group"
  on public.group_members
  for select
  to authenticated
  using (
    group_id in (select group_id from public.group_members where user_id = auth.uid())
  );

drop policy if exists "group_invites_owner_select" on public.group_invites;
create policy "group_invites_owner_or_invitee_select"
  on public.group_invites
  for select
  to authenticated
  using (
    inviter_id = auth.uid()
    or identifier = (auth.jwt() ->> 'email')
    or identifier = (auth.jwt() -> 'user_metadata' ->> 'username')
  );

create policy "group_invites_invitee_delete"
  on public.group_invites
  for delete
  to authenticated
  using (
    identifier = (auth.jwt() ->> 'email')
    or identifier = (auth.jwt() -> 'user_metadata' ->> 'username')
  );
