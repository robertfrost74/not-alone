create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users (id) on delete cascade,
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table if not exists public.group_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member',
  created_at timestamptz not null default now(),
  unique (group_id, user_id)
);

create table if not exists public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  inviter_id uuid not null references auth.users (id) on delete cascade,
  identifier text not null,
  created_at timestamptz not null default now()
);

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.group_invites enable row level security;

create policy "groups_owner_select"
  on public.groups
  for select
  to authenticated
  using (
    owner_id = auth.uid()
    or id in (select group_id from public.group_members where user_id = auth.uid())
  );

create policy "groups_owner_insert"
  on public.groups
  for insert
  to authenticated
  with check (owner_id = auth.uid());

create policy "groups_owner_update"
  on public.groups
  for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create policy "groups_owner_delete"
  on public.groups
  for delete
  to authenticated
  using (owner_id = auth.uid());

create policy "group_members_select_self"
  on public.group_members
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "group_members_insert_self"
  on public.group_members
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "group_invites_owner_insert"
  on public.group_invites
  for insert
  to authenticated
  with check (inviter_id = auth.uid());

create policy "group_invites_owner_select"
  on public.group_invites
  for select
  to authenticated
  using (inviter_id = auth.uid());
