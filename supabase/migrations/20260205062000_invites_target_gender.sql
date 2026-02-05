alter table public.invites
  add column if not exists target_gender text;

update public.invites
set target_gender = coalesce(target_gender, 'all')
where target_gender is null;

alter table public.invites
  alter column target_gender set default 'all';
