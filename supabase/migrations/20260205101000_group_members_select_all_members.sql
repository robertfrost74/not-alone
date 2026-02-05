drop policy if exists "group_members_select_self" on public.group_members;

create or replace function public.can_view_group_members(gid uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select
    exists (
      select 1 from public.group_members
      where group_id = gid and user_id = auth.uid()
    )
    or exists (
      select 1 from public.groups
      where id = gid and owner_id = auth.uid()
    );
$$;

grant execute on function public.can_view_group_members(uuid) to authenticated;

create policy "group_members_select_group"
  on public.group_members
  for select
  to authenticated
  using (public.can_view_group_members(group_id));
