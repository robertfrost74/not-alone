create table if not exists public.invites (
  id uuid primary key default gen_random_uuid(),
  host_user_id uuid references auth.users(id) on delete set null,
  activity text not null,
  mode text not null default 'one_to_one',
  max_participants integer,
  energy text,
  talk_level text,
  duration integer,
  meeting_time timestamptz,
  place text,
  age_min integer,
  age_max integer,
  target_gender text default 'all',
  status text not null default 'open',
  group_id uuid references public.groups(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table if exists public.invites
  add column if not exists group_id uuid references public.groups(id) on delete set null;

create index if not exists invites_status_idx on public.invites (status);
create index if not exists invites_created_at_idx on public.invites (created_at desc);
create index if not exists invites_host_user_id_idx on public.invites (host_user_id);
create index if not exists invites_group_id_idx on public.invites (group_id);

create table if not exists public.invite_members (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.invites(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  role text not null default 'member',
  status text not null default 'accepted',
  created_at timestamptz not null default now()
);

create index if not exists invite_members_invite_id_idx on public.invite_members (invite_id);
create index if not exists invite_members_user_id_idx on public.invite_members (user_id);
