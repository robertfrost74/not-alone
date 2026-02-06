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

create or replace function public.leave_invite(p_invite_member_id uuid)
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

  update public.invite_members
  set status = 'cannot_attend',
      cannot_come_at = now()
  where id = p_invite_member_id
    and user_id = v_user;
end;
$$;

grant execute on function public.leave_invite(uuid) to authenticated;
