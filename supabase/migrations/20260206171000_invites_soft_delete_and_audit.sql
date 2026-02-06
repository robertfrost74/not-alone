create table if not exists public.invites_audit (
  id bigserial primary key,
  invite_id uuid not null,
  actor_id uuid,
  action text not null,
  created_at timestamptz not null default now()
);

alter table public.invites
  add column if not exists archived_at timestamptz;

create or replace function public.soft_delete_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  update public.invites
  set status = 'closed',
      archived_at = now()
  where id = p_invite_id
    and host_user_id = v_user;

  insert into public.invites_audit (invite_id, actor_id, action)
  values (p_invite_id, v_user, 'soft_delete');
end;
$$;

grant execute on function public.soft_delete_invite(uuid) to authenticated;
