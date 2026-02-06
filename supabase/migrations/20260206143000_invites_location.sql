alter table public.invites
  add column if not exists lat double precision,
  add column if not exists lon double precision,
  add column if not exists city text,
  add column if not exists radius_km int default 20;

create index if not exists invites_city_idx on public.invites (city);

create or replace function public.haversine_km(
  lat1 double precision,
  lon1 double precision,
  lat2 double precision,
  lon2 double precision
)
returns double precision
language sql
immutable
as $$
  select 6371 * 2 * asin(
    sqrt(
      power(sin(radians((lat2 - lat1) / 2)), 2) +
      cos(radians(lat1)) * cos(radians(lat2)) *
      power(sin(radians((lon2 - lon1) / 2)), 2)
    )
  );
$$;

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
