update public.invites i
set city = p.city
from public.profiles p
where i.host_user_id = p.id
  and (i.city is null or i.city = '');
