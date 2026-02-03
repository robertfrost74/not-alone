create extension if not exists pg_cron with schema extensions;

create or replace function public.delete_expired_invites()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.invite_members m
  using public.invites i
  where m.invite_id = i.id
    and i.meeting_time is not null
    and i.meeting_time < now();

  delete from public.invites
  where meeting_time is not null
    and meeting_time < now();
end;
$$;

do $$
declare
  existing_job_id bigint;
begin
  select jobid
  into existing_job_id
  from cron.job
  where jobname = 'delete-expired-invites-every-15m'
  limit 1;

  if existing_job_id is not null then
    perform cron.unschedule(existing_job_id);
  end if;

  perform cron.schedule(
    'delete-expired-invites-every-15m',
    '*/15 * * * *',
    'select public.delete_expired_invites();'
  );
end;
$$;
