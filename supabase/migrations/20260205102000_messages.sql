create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid references auth.users (id) on delete set null,
  recipient_id uuid references auth.users (id) on delete cascade,
  type text default 'message',
  title text,
  body text,
  metadata jsonb,
  created_at timestamptz not null default now()
);

alter table public.messages enable row level security;

create policy "messages_select_recipient"
  on public.messages
  for select
  to authenticated
  using (recipient_id = auth.uid());

create policy "messages_insert_sender"
  on public.messages
  for insert
  to authenticated
  with check (sender_id = auth.uid());
