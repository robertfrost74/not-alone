alter table public.invite_members
  add column if not exists status text not null default 'joined',
  add column if not exists cannot_come_at timestamptz;

