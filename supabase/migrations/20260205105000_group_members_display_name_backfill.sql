create policy "group_members_update_self"
  on public.group_members
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

alter table public.profiles
  add column if not exists username text;

alter table public.profiles
  add column if not exists full_name text;

update public.group_members gm
set display_name = coalesce(p.username, p.full_name)
from public.profiles p
where gm.user_id = p.id
  and (gm.display_name is null or gm.display_name = '')
  and coalesce(p.username, p.full_name) is not null
  and coalesce(p.username, p.full_name) <> '';
