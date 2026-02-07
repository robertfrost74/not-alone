drop function if exists public.join_invite(uuid);

create or replace function public.join_invite(invite_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_invite_id uuid := invite_id;
  v_existing uuid;
  v_invite record;
  v_accepted int;
  v_max int;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  select * into v_invite
  from public.invites i
  where i.id = v_invite_id and i.status = 'open'
  for update;

  if not found then
    raise exception 'invite_closed' using errcode = 'P0001';
  end if;

  if v_invite.host_user_id is not null
     and public.is_blocked(v_user, v_invite.host_user_id) then
    raise exception 'user_blocked' using errcode = 'P0001';
  end if;

  select m.id into v_existing
  from public.invite_members m
  where m.invite_id = v_invite_id and m.user_id = v_user
  limit 1;

  if v_existing is not null then
    return v_existing;
  end if;

  select count(*) into v_accepted
  from public.invite_members m
  where m.invite_id = v_invite_id and m.status != 'cannot_attend';

  if v_invite.mode = 'one_to_one' then
    v_max := 1;
  else
    v_max := coalesce(v_invite.max_participants, 4);
  end if;

  if v_accepted >= v_max then
    raise exception 'invite_full' using errcode = 'P0001';
  end if;

  insert into public.invite_members (invite_id, user_id, role)
  values (v_invite_id, v_user, 'member')
  returning id into v_existing;

  return v_existing;
end;
$$;

grant execute on function public.join_invite(uuid) to authenticated;
