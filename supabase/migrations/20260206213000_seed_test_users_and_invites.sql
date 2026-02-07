-- TODO(launch): Remove this test-data migration before production release.
create extension if not exists pgcrypto;
with seed as (
  select generate_series(1, 10) as idx
),
new_users as (
  insert into auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  )
  select
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    'testuser' || lpad(idx::text, 2, '0') || '@social.local',
    extensions.crypt('social123', extensions.gen_salt('bf')),
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    jsonb_build_object(
      'username', 'Test' || idx,
      'full_name', 'Test User ' || idx,
      'age', 20 + (idx % 15),
      'gender', case when idx % 2 = 0 then 'female' else 'male' end,
      'city', 'Linköping',
      'bio', 'Testprofil för demo',
      'interests', 'Promenad, fika, träning'
    ),
    now(),
    now()
  from seed
  returning id, raw_user_meta_data, email
),
existing_users as (
  select
    id,
    raw_user_meta_data,
    email
  from auth.users
  where email like 'testuser%@social.local'
),
seed_users as (
  select id, raw_user_meta_data, email from new_users
  union all
  select id, raw_user_meta_data, email from existing_users
),
profile_rows as (
  insert into public.profiles (
    id,
    username,
    full_name,
    age,
    gender,
    bio,
    city,
    interests,
    updated_at
  )
  select
    id,
    raw_user_meta_data->>'username',
    raw_user_meta_data->>'full_name',
    (raw_user_meta_data->>'age')::int,
    raw_user_meta_data->>'gender',
    raw_user_meta_data->>'bio',
    raw_user_meta_data->>'city',
    raw_user_meta_data->>'interests',
    now()
  from seed_users
  on conflict (id) do update
    set username = excluded.username,
        full_name = excluded.full_name,
        age = excluded.age,
        gender = excluded.gender,
        bio = excluded.bio,
        city = excluded.city,
        interests = excluded.interests,
        updated_at = excluded.updated_at
  returning id
),
invite_seed as (
  select
    u.id as user_id,
    u.row_num,
    i.inv_idx
  from (
    select id, row_number() over () as row_num
    from seed_users
  ) u
  cross join generate_series(1, 3) as i(inv_idx)
),
invite_data as (
  select
    user_id,
    row_num,
    inv_idx,
    (0.5 + ((row_num * 7 + inv_idx * 3) % 20))::double precision as distance_km,
    ((row_num * 37 + inv_idx * 73) % 360)::double precision as angle_deg
  from invite_seed
)
insert into public.invites (
  host_user_id,
  activity,
  mode,
  max_participants,
  energy,
  talk_level,
  duration,
  meeting_time,
  place,
  age_min,
  age_max,
  target_gender,
  status,
  lat,
  lon,
  city,
  radius_km
)
select
  user_id,
  (array['walk', 'coffee', 'workout', 'lunch', 'dinner'])[
    ((row_num + inv_idx) % 5) + 1
  ],
  case when inv_idx = 1 then 'one_to_one' else 'group' end,
  case
    when inv_idx = 1 then null
    when inv_idx = 2 then 3
    else 6
  end,
  (array['low', 'medium', 'high'])[
    ((row_num + inv_idx) % 3) + 1
  ],
  (array['low', 'medium', 'high'])[
    ((row_num + inv_idx + 1) % 3) + 1
  ],
  (array[20, 30, 45, 60, 90])[
    ((row_num + inv_idx) % 5) + 1
  ],
  now() + (((row_num + inv_idx) % 10) + 1) * interval '2 hours',
  (array[
    'Stadsparken',
    'Café Central',
    'Resecentrum',
    'Trädgårdsföreningen',
    'Gamla Linköping'
  ])[((row_num + inv_idx) % 5) + 1],
  18,
  80,
  'all',
  'open',
  58.4186282 + (distance_km / 111.0) * cos(radians(angle_deg)),
  15.6130613 +
    (distance_km / (111.0 * cos(radians(58.4186282)))) *
    sin(radians(angle_deg)),
  'Linköping',
  20
from invite_data;
