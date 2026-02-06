alter table if exists public.profiles enable row level security;

create policy if not exists "profiles_select_public" on public.profiles
for select
using (true);
