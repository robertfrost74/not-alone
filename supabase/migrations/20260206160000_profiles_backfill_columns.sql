alter table public.profiles
  add column if not exists username text,
  add column if not exists full_name text,
  add column if not exists age int,
  add column if not exists gender text,
  add column if not exists bio text,
  add column if not exists city text,
  add column if not exists interests text,
  add column if not exists avatar_url text,
  add column if not exists avatar_preset_id text,
  add column if not exists updated_at timestamptz default now();

notify pgrst, 'reload schema';
