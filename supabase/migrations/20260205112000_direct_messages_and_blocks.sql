create table if not exists public.direct_messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references auth.users (id) on delete set null,
  recipient_id uuid references auth.users (id) on delete cascade,
  sender_name text,
  recipient_name text,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_id uuid references auth.users (id) on delete cascade,
  blocked_id uuid references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (blocker_id, blocked_id)
);

alter table public.direct_messages enable row level security;
alter table public.user_blocks enable row level security;

create or replace function public.is_blocked(a uuid, b uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.user_blocks
    where (blocker_id = a and blocked_id = b)
       or (blocker_id = b and blocked_id = a)
  );
$$;

grant execute on function public.is_blocked(uuid, uuid) to authenticated;

create policy "direct_messages_select"
  on public.direct_messages
  for select
  to authenticated
  using (sender_id = auth.uid() or recipient_id = auth.uid());

create policy "direct_messages_insert"
  on public.direct_messages
  for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and not public.is_blocked(sender_id, recipient_id)
  );

create policy "user_blocks_select_self"
  on public.user_blocks
  for select
  to authenticated
  using (blocker_id = auth.uid());

create policy "user_blocks_insert_self"
  on public.user_blocks
  for insert
  to authenticated
  with check (blocker_id = auth.uid());

create policy "user_blocks_delete_self"
  on public.user_blocks
  for delete
  to authenticated
  using (blocker_id = auth.uid());
