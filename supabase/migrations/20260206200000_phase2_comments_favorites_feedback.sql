create table if not exists public.invite_comments (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.invites (id) on delete cascade,
  author_id uuid not null references auth.users (id) on delete cascade,
  author_name text,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists invite_comments_invite_idx
  on public.invite_comments (invite_id);
create index if not exists invite_comments_author_idx
  on public.invite_comments (author_id);

alter table public.invite_comments enable row level security;

create policy "invite_comments_select_all"
  on public.invite_comments
  for select
  to authenticated
  using (true);

create policy "invite_comments_insert_self"
  on public.invite_comments
  for insert
  to authenticated
  with check (author_id = auth.uid());

create table if not exists public.user_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  target_user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, target_user_id)
);

create index if not exists user_favorites_user_idx
  on public.user_favorites (user_id);
create index if not exists user_favorites_target_idx
  on public.user_favorites (target_user_id);

alter table public.user_favorites enable row level security;

create policy "user_favorites_select_self"
  on public.user_favorites
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "user_favorites_insert_self"
  on public.user_favorites
  for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "user_favorites_delete_self"
  on public.user_favorites
  for delete
  to authenticated
  using (user_id = auth.uid());

create table if not exists public.invite_feedback (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.invites (id) on delete cascade,
  invite_member_id uuid not null references public.invite_members (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique (invite_member_id)
);

create index if not exists invite_feedback_invite_idx
  on public.invite_feedback (invite_id);
create index if not exists invite_feedback_user_idx
  on public.invite_feedback (user_id);

alter table public.invite_feedback enable row level security;

create policy "invite_feedback_select_self"
  on public.invite_feedback
  for select
  to authenticated
  using (user_id = auth.uid());

create policy "invite_feedback_insert_self"
  on public.invite_feedback
  for insert
  to authenticated
  with check (user_id = auth.uid());
