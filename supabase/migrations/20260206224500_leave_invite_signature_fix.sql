drop function if exists public.leave_invite(uuid);

create or replace function public.leave_invite(invite_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_invite_member_id uuid := invite_member_id;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = 'P0001';
  end if;

  update public.invite_members
  set status = 'cannot_attend',
      cannot_come_at = now()
  where id = v_invite_member_id
    and user_id = v_user;
end;
$$;

grant execute on function public.leave_invite(uuid) to authenticated;
