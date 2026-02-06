alter table if exists public.profiles enable row level security;

drop policy if exists "profiles_select_public" on public.profiles;

create policy "profiles_select_public" on public.profiles
for select
using (true);
