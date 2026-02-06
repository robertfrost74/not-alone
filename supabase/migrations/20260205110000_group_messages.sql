create table if not exists public.group_messages (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups (id) on delete cascade,
  sender_id uuid references auth.users (id) on delete set null,
  sender_name text,
  body text not null,
  created_at timestamptz not null default now()
);

alter table public.group_messages enable row level security;

create policy "group_messages_select_members"
  on public.group_messages
  for select
  to authenticated
  using (public.can_view_group_members(group_id));

create policy "group_messages_insert_members"
  on public.group_messages
  for insert
  to authenticated
  with check (public.can_view_group_members(group_id));
