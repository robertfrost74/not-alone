create unique index if not exists invite_members_invite_user_unique
on public.invite_members (invite_id, user_id);

create unique index if not exists group_members_group_user_unique
on public.group_members (group_id, user_id);
