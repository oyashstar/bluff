-- Finsys Internal Tracker — business logic functions
-- Logic that a view cannot express. All callable from the Dart client over the
-- auto REST API (rpc). SECURITY INVOKER so RLS still applies to the caller;
-- each guards on fn_is_internal() to give a clean error to signed-out callers.

-- ---------------------------------------------------------------------------
-- fn_apply_stage_template(project, template): materialise project_stage rows
-- from a template. Project-level stages only (project_module_id = null). Safe
-- to re-run: it refuses if whole-project stages already exist for the project.
-- ---------------------------------------------------------------------------
create or replace function fn_apply_stage_template(p_project_id uuid, p_template_id uuid)
  returns int
  language plpgsql
  security invoker
  set search_path = public
as $$
declare
  v_count int;
begin
  if not fn_can_edit_delivery() then
    raise exception 'not authorised to apply a stage template';
  end if;

  if exists (
    select 1 from project_stage
    where project_id = p_project_id and project_module_id is null
  ) then
    raise exception 'project % already has project-level stages', p_project_id;
  end if;

  insert into project_stage (project_id, project_module_id, stage_template_item_id, status)
  select p_project_id, null, i.id, 'Pending'::stage_status
  from stage_template_item i
  where i.stage_template_id = p_template_id
  order by i.seq;

  get diagnostics v_count = row_count;

  update project set stage_template_id = p_template_id, updated_at = now()
  where id = p_project_id;

  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- fn_transition_query(query, to_status, actor): the ONLY way query.status
-- changes. Validates the transition, stamps lifecycle timestamps, and
-- accumulates sla_paused_minutes across AwaitingClient / AwaitingDev pauses.
-- Root cause is mandatory before Resolved/Closed.
-- ---------------------------------------------------------------------------
create or replace function fn_transition_query(
  p_query_id uuid,
  p_to       query_status,
  p_actor    uuid default auth.uid()
)
  returns query
  language plpgsql
  security invoker
  set search_path = public
as $$
declare
  q query;
  v_from query_status;
  v_now timestamptz := now();
  v_allowed boolean := false;
  v_paused_states query_status[] := array['AwaitingClient','AwaitingDev'];
begin
  if not fn_can_edit_support() then
    raise exception 'not authorised to change query status';
  end if;

  select * into q from query where id = p_query_id for update;
  if not found then
    raise exception 'query % not found', p_query_id;
  end if;
  v_from := q.status;

  if v_from = p_to then
    return q;  -- no-op
  end if;

  -- Allowed transitions (the 8-state machine; 2 states pause the clock).
  v_allowed := case v_from
    when 'New'            then p_to in ('Acknowledged','InProgress','Cancelled')
    when 'Acknowledged'   then p_to in ('InProgress','AwaitingClient','AwaitingDev','Cancelled')
    when 'InProgress'     then p_to in ('AwaitingClient','AwaitingDev','Resolved','Cancelled')
    when 'AwaitingClient' then p_to in ('InProgress','Resolved','Cancelled')
    when 'AwaitingDev'    then p_to in ('InProgress','Resolved','Cancelled')
    when 'Resolved'       then p_to in ('Closed','Reopened')
    when 'Reopened'       then p_to in ('InProgress','AwaitingClient','AwaitingDev','Cancelled')
    when 'Closed'         then p_to in ('Reopened')
    when 'Cancelled'      then false
    else false
  end;

  if not v_allowed then
    raise exception 'illegal query transition % -> %', v_from, p_to;
  end if;

  -- Root cause mandatory before Resolved or Closed.
  if p_to in ('Resolved','Closed') and q.root_cause is null then
    raise exception 'root_cause is required before a query can be marked % ', p_to;
  end if;

  -- SLA clock pause bookkeeping.
  if p_to = any(v_paused_states) and v_from <> all(v_paused_states) then
    -- entering a paused state
    q.sla_paused_since := v_now;
  elsif v_from = any(v_paused_states) and p_to <> all(v_paused_states) then
    -- leaving a paused state: fold the paused span into the accumulator
    if q.sla_paused_since is not null then
      q.sla_paused_minutes := q.sla_paused_minutes
        + fn_business_minutes_between(q.sla_paused_since, v_now);
      q.sla_paused_since := null;
    end if;
  end if;

  -- Lifecycle timestamps (set once, on first entry).
  if p_to = 'Acknowledged' and q.acknowledged_at is null then
    q.acknowledged_at := v_now;
  end if;
  if p_to = 'Resolved' and q.resolved_at is null then
    q.resolved_at := v_now;
  end if;
  if p_to = 'Closed' and q.closed_at is null then
    q.closed_at := v_now;
  end if;
  if p_to = 'Reopened' then
    q.resolved_at := null;
    q.closed_at := null;
  end if;

  update query set
    status             = p_to,
    acknowledged_at    = q.acknowledged_at,
    resolved_at        = q.resolved_at,
    closed_at          = q.closed_at,
    sla_paused_since   = q.sla_paused_since,
    sla_paused_minutes = q.sla_paused_minutes,
    updated_at         = v_now
  where id = p_query_id
  returning * into q;

  return q;
end;
$$;

-- ---------------------------------------------------------------------------
-- fn_set_query_sla(query): compute sla_response_due / sla_resolution_due from
-- sla_target and the business calendar. Called on insert (trigger) and callable
-- after a severity change.
-- ---------------------------------------------------------------------------
create or replace function fn_set_query_sla(p_query_id uuid)
  returns void
  language plpgsql
  security invoker
  set search_path = public
as $$
declare
  q query;
  s sla_target;
begin
  select * into q from query where id = p_query_id;
  if not found then return; end if;
  select * into s from sla_target where severity = q.severity;
  if not found then return; end if;

  update query set
    sla_response_due   = fn_add_business_minutes(q.created_at, s.first_response_minutes),
    sla_resolution_due = fn_add_business_minutes(q.created_at, s.resolution_minutes)
  where id = p_query_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- fn_recompute_health(project): writes project.health_score (0–100) and
-- project.health_breakdown (jsonb). Scoring per the design brief. 100 = healthy;
-- each signal deducts up to its weight. Store the breakdown so the number is
-- explainable on hover. Recompute nightly (pg_cron) and on write.
--
-- Signals and weights:
--   stage_overrun            25  (days in current stage vs template duration)
--   open_severity            25  (open S1/S2 queries)
--   staleness                20  (days since last touchpoint)
--   signoff_pending          15  (days a completed stage waits for sign-off)
--   golive_revisions         15  (times planned go-live was revised)
-- ---------------------------------------------------------------------------
create or replace function fn_recompute_health(p_project_id uuid)
  returns int
  language plpgsql
  security definer            -- runs from pg_cron with no auth.uid(); safe, read-mostly
  set search_path = public
as $$
declare
  p project;
  v_stage int := 25;
  v_sev int := 25;
  v_stale int := 20;
  v_signoff int := 15;
  v_revise int := 15;
  v_total int;

  v_days_in_stage int;
  v_tmpl_days int;
  v_open_s1 int;
  v_open_s2 int;
  v_days_since_touch int;
  v_signoff_wait int;
  v_breakdown jsonb;
begin
  select * into p from project where id = p_project_id;
  if not found then return null; end if;

  -- (1) stage overrun: earliest incomplete project-level stage.
  select
    coalesce((current_date - ps.actual_start), 0),
    coalesce(sti.default_duration_days, 0)
  into v_days_in_stage, v_tmpl_days
  from project_stage ps
  join stage_template_item sti on sti.id = ps.stage_template_item_id
  where ps.project_id = p_project_id
    and ps.project_module_id is null
    and ps.status in ('Pending','InProgress','Blocked')
  order by sti.seq
  limit 1;

  if v_tmpl_days is null or v_tmpl_days = 0 then
    v_stage := 25;                                   -- no benchmark yet: assume fine
  elsif v_days_in_stage > v_tmpl_days * 2 then
    v_stage := 0;                                    -- red: over by 100%+
  elsif v_days_in_stage > v_tmpl_days * 1.5 then
    v_stage := 12;                                   -- amber: over by 50%+
  else
    v_stage := 25;
  end if;

  -- (2) open severity.
  select
    count(*) filter (where severity = 'S1' and status not in ('Resolved','Closed','Cancelled')),
    count(*) filter (where severity = 'S2' and status not in ('Resolved','Closed','Cancelled'))
  into v_open_s1, v_open_s2
  from query where client_id = p.client_id;

  if v_open_s1 >= 1 or v_open_s2 >= 3 then
    v_sev := 0;                                      -- red
  elsif v_open_s2 >= 1 then
    v_sev := 12;                                     -- amber
  else
    v_sev := 25;
  end if;

  -- (3) staleness: days since last touchpoint for the client.
  select coalesce((current_date - max(occurred_on)::date), 999)
  into v_days_since_touch
  from touchpoint where client_id = p.client_id;

  if v_days_since_touch >= 45 then
    v_stale := 0;
  elsif v_days_since_touch >= 21 then
    v_stale := 10;
  else
    v_stale := 20;
  end if;

  -- (4) sign-off pending on a completed stage.
  select coalesce(max(current_date - ps.actual_end), 0)
  into v_signoff_wait
  from project_stage ps
  join stage_template_item sti on sti.id = ps.stage_template_item_id
  where ps.project_id = p_project_id
    and sti.requires_signoff
    and ps.status = 'Done'
    and ps.actual_end is not null
    and not exists (select 1 from signoff s where s.project_stage_id = ps.id and s.signed_on is not null);

  if v_signoff_wait >= 30 then
    v_signoff := 0;
  elsif v_signoff_wait >= 15 then
    v_signoff := 7;
  else
    v_signoff := 15;
  end if;

  -- (5) go-live revisions.
  if p.golive_revisions >= 2 then
    v_revise := 0;
  elsif p.golive_revisions = 1 then
    v_revise := 7;
  else
    v_revise := 15;
  end if;

  v_total := v_stage + v_sev + v_stale + v_signoff + v_revise;

  v_breakdown := jsonb_build_object(
    'stage_overrun',    jsonb_build_object('score', v_stage,  'days_in_stage', v_days_in_stage, 'template_days', v_tmpl_days),
    'open_severity',    jsonb_build_object('score', v_sev,    'open_s1', coalesce(v_open_s1,0), 'open_s2', coalesce(v_open_s2,0)),
    'staleness',        jsonb_build_object('score', v_stale,  'days_since_touchpoint', v_days_since_touch),
    'signoff_pending',  jsonb_build_object('score', v_signoff,'max_wait_days', v_signoff_wait),
    'golive_revisions', jsonb_build_object('score', v_revise, 'revisions', p.golive_revisions),
    'total',            v_total,
    'computed_at',      now()
  );

  update project set health_score = v_total, health_breakdown = v_breakdown, updated_at = now()
  where id = p_project_id;

  return v_total;
end;
$$;

-- Convenience: recompute every project (nightly job target).
create or replace function fn_recompute_all_health()
  returns void
  language plpgsql
  security definer
  set search_path = public
as $$
declare r record;
begin
  for r in select id from project where status not in ('Closed','Dropped') loop
    perform fn_recompute_health(r.id);
  end loop;
end;
$$;
