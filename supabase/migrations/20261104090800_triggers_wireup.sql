-- Finsys Internal Tracker — trigger wiring + scheduled jobs

-- ---------------------------------------------------------------------------
-- auth.users -> app_user: every authenticated person gets exactly one app_user.
-- New sign-ups default to Viewer; an Admin promotes them. Keeps RLS honest:
-- fn_my_role() returns null until a row exists, so an unprovisioned login can
-- see nothing.
-- ---------------------------------------------------------------------------
create or replace function fn_handle_new_user() returns trigger
  language plpgsql
  security definer
  set search_path = public, auth
as $$
begin
  insert into app_user (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    'Viewer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_handle_new_user on auth.users;
create trigger trg_handle_new_user
  after insert on auth.users
  for each row execute function fn_handle_new_user();

-- ---------------------------------------------------------------------------
-- query SLA stamping. BEFORE INSERT sets the due dates from sla_target and the
-- business calendar. BEFORE UPDATE recomputes them if severity changes while
-- the ticket is still open (not yet resolved).
-- ---------------------------------------------------------------------------
create or replace function fn_query_sla_stamp() returns trigger
  language plpgsql
  security definer
  set search_path = public
as $$
declare s sla_target;
begin
  if (tg_op = 'UPDATE' and new.severity = old.severity) then
    return new;
  end if;

  select * into s from sla_target where severity = new.severity;
  if found then
    new.sla_response_due   := fn_add_business_minutes(coalesce(new.created_at, now()), s.first_response_minutes);
    new.sla_resolution_due := fn_add_business_minutes(coalesce(new.created_at, now()), s.resolution_minutes);
  end if;
  return new;
end;
$$;

create trigger trg_query_sla_insert
  before insert on query
  for each row execute function fn_query_sla_stamp();

create trigger trg_query_sla_severity
  before update of severity on query
  for each row execute function fn_query_sla_stamp();

-- ---------------------------------------------------------------------------
-- updated_at maintenance for the tables that carry it.
-- ---------------------------------------------------------------------------
create or replace function fn_touch_updated_at() returns trigger
  language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare
  t text;
  touched text[] := array[
    'app_user','client','client_contact','project','project_stage','query'
  ];
begin
  foreach t in array touched loop
    execute format(
      'create trigger trg_touch_%1$s before update on %1$I
         for each row execute function fn_touch_updated_at()', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Scheduled jobs via pg_cron (Supabase). Guarded: if pg_cron is not installed
-- (e.g. a bare local Postgres), the migration still succeeds and the jobs are
-- simply not scheduled — run fn_recompute_all_health() manually or wire a
-- scheduled Edge Function instead.
-- ---------------------------------------------------------------------------
do $$
begin
  create extension if not exists pg_cron;
  -- Nightly health recompute at 02:00 IST (20:30 UTC previous day).
  perform cron.schedule('finsys-health-nightly', '30 20 * * *', 'select fn_recompute_all_health();');
exception when others then
  raise notice 'pg_cron not available (%). Schedule fn_recompute_all_health() externally.', sqlerrm;
end;
$$;
