alter table public.group_members
  add column if not exists display_name text;
