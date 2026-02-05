alter table public.invites
  add column if not exists age_min integer,
  add column if not exists age_max integer;

update public.invites
set age_min = coalesce(age_min, 16),
    age_max = coalesce(age_max, 120)
where age_min is null or age_max is null;

alter table public.invites
  alter column age_min set default 16,
  alter column age_max set default 120;
