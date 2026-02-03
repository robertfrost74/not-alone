alter table public.invites
  add column if not exists host_user_id uuid references auth.users(id) on delete set null;

create index if not exists invites_host_user_id_idx on public.invites(host_user_id);

alter table public.invites enable row level security;

do $$
declare
  p record;
begin
  for p in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'invites'
      and cmd = 'DELETE'
  loop
    execute format('drop policy if exists %I on public.invites', p.policyname);
  end loop;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'invites'
      and policyname = 'invites_delete_host_only'
  ) then
    create policy invites_delete_host_only
      on public.invites
      for delete
      to anon, authenticated
      using (host_user_id = auth.uid());
  end if;
end $$;

