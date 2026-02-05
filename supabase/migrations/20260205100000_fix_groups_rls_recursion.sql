drop policy if exists "groups_owner_select" on public.groups;
drop policy if exists "group_members_select_owner_or_self" on public.group_members;
drop policy if exists "group_members_select_self" on public.group_members;
drop policy if exists "groups_owner_or_member_select" on public.groups;

create policy "group_members_select_self"
  on public.group_members
  for select
  to authenticated
  using (user_id = auth.uid());

create or replace function public.is_group_member(gid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.group_members
    where group_id = gid and user_id = auth.uid()
  );
$$;

grant execute on function public.is_group_member(uuid) to authenticated;

create policy "groups_owner_or_member_select"
  on public.groups
  for select
  to authenticated
  using (
    owner_id = auth.uid()
    or public.is_group_member(id)
  );
