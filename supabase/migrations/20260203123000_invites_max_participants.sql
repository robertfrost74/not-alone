alter table public.invites
  add column if not exists max_participants integer;

