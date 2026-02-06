alter table public.invite_members
  alter column status set default 'coming';

update public.invite_members
set status = 'coming'
where status is null
   or status in ('joined', 'accepted');

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reported_id uuid not null references auth.users (id) on delete cascade,
  invite_id uuid references public.invites (id) on delete set null,
  reason text not null,
  details text,
  created_at timestamptz not null default now()
);

create index if not exists user_reports_reporter_idx
  on public.user_reports (reporter_id);
create index if not exists user_reports_reported_idx
  on public.user_reports (reported_id);
create index if not exists user_reports_invite_idx
  on public.user_reports (invite_id);

alter table public.user_reports enable row level security;

create policy "user_reports_insert_self"
  on public.user_reports
  for insert
  to authenticated
  with check (reporter_id = auth.uid());

create policy "user_reports_select_self"
  on public.user_reports
  for select
  to authenticated
  using (reporter_id = auth.uid());

create or replace function public.set_invite_member_status(
  invite_member_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_normalized text := lower(coalesce(p_status, ''));
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  if v_normalized not in ('coming', 'maybe', 'cannot_attend') then
    raise exception 'invalid_status' using errcode = 'P0001';
  end if;

  update public.invite_members
  set status = v_normalized,
      cannot_come_at = case
        when v_normalized = 'cannot_attend' then now()
        else null
      end
  where id = invite_member_id
    and user_id = v_user;
end;
$$;

grant execute on function public.set_invite_member_status(uuid, text) to authenticated;

create or replace function public.join_invite(p_invite_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_existing uuid;
  v_invite record;
  v_accepted int;
  v_max int;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into v_invite
  from public.invites
  where id = p_invite_id and status = 'open'
  for update;

  if not found then
    raise exception 'invite_closed' using errcode = 'P0001';
  end if;

  if v_invite.host_user_id is not null
     and public.is_blocked(v_user, v_invite.host_user_id) then
    raise exception 'user_blocked' using errcode = 'P0001';
  end if;

  select id into v_existing
  from public.invite_members
  where invite_id = p_invite_id and user_id = v_user
  limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  select count(*) into v_accepted
  from public.invite_members
  where invite_id = p_invite_id and status != 'cannot_attend';

  if v_invite.mode = 'one_to_one' then
    v_max := 1;
  else
    v_max := coalesce(v_invite.max_participants, 4);
  end if;

  if v_accepted >= v_max then
    raise exception 'invite_full' using errcode = 'P0001';
  end if;

  insert into public.invite_members (invite_id, user_id, role)
  values (p_invite_id, v_user, 'member')
  returning id into v_existing;

  return v_existing;
end;
$$;

grant execute on function public.join_invite(uuid) to authenticated;

create or replace function public.fetch_open_invites_nearby(
  p_lat double precision,
  p_lon double precision,
  p_radius_km int,
  p_city text,
  p_limit int default 50
)
returns table(
  id uuid,
  host_user_id uuid,
  max_participants int,
  target_gender text,
  age_min int,
  age_max int,
  created_at timestamptz,
  activity text,
  mode text,
  energy text,
  talk_level text,
  duration int,
  place text,
  meeting_time timestamptz,
  group_id uuid,
  groups jsonb,
  invite_members jsonb
)
language sql
security definer
set search_path = public
as $$
  select
    i.id,
    i.host_user_id,
    i.max_participants,
    i.target_gender,
    i.age_min,
    i.age_max,
    i.created_at,
    i.activity,
    i.mode,
    i.energy,
    i.talk_level,
    i.duration,
    i.place,
    i.meeting_time,
    i.group_id,
    (select jsonb_build_object('name', g.name)
       from public.groups g
      where g.id = i.group_id) as groups,
    (select coalesce(
        jsonb_agg(jsonb_build_object('status', m.status, 'user_id', m.user_id)),
        '[]'::jsonb
      )
     from public.invite_members m
     where m.invite_id = i.id) as invite_members
  from public.invites i
  where i.status = 'open'
    and (
      i.host_user_id is null
      or not public.is_blocked(auth.uid(), i.host_user_id)
    )
    and (
      (
        p_lat is not null and p_lon is not null
        and i.lat is not null and i.lon is not null
        and public.haversine_km(p_lat, p_lon, i.lat, i.lon) <= p_radius_km
      )
      or (
        (p_lat is null or p_lon is null)
        and p_city is not null
        and i.city = p_city
      )
      or (
        p_lat is not null and p_lon is not null
        and i.lat is null and i.lon is null
        and p_city is not null
        and i.city = p_city
      )
      or (
        p_lat is null and p_lon is null
        and (p_city is null or p_city = '')
      )
    )
  order by i.created_at desc
  limit p_limit;
$$;

grant execute on function public.fetch_open_invites_nearby(
  double precision,
  double precision,
  int,
  text,
  int
) to authenticated;
