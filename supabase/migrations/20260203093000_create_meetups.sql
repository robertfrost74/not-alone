create table if not exists public.meetups (
  id uuid primary key default gen_random_uuid(),
  invite_id uuid not null references public.invites(id) on delete cascade,
  invite_member_id uuid not null references public.invite_members(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  started_at timestamptz,
  ended_at timestamptz,
  extended_minutes integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint meetups_invite_member_unique unique (invite_member_id)
);

alter table public.meetups enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'meetups'
      and policyname = 'meetups_select_all'
  ) then
    create policy meetups_select_all
      on public.meetups
      for select
      to anon, authenticated
      using (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'meetups'
      and policyname = 'meetups_insert_all'
  ) then
    create policy meetups_insert_all
      on public.meetups
      for insert
      to anon, authenticated
      with check (true);
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'meetups'
      and policyname = 'meetups_update_all'
  ) then
    create policy meetups_update_all
      on public.meetups
      for update
      to anon, authenticated
      using (true)
      with check (true);
  end if;
end $$;

create index if not exists meetups_invite_id_idx on public.meetups (invite_id);
create index if not exists meetups_member_id_idx on public.meetups (invite_member_id);
