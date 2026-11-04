-- Finsys Internal Tracker — dashboard views
-- Every dashboard reads exactly one of these. No client-side aggregation.
-- security_invoker = true so the querying user's RLS applies through the view
-- (Postgres 15+ / Supabase default recommendation).

-- Headline stage per project: the earliest incomplete stage by template seq,
-- across project-level and in-scope module-level stages. "Incomplete" =
-- Pending / InProgress / Blocked.
create or replace view v_project_current_stage
  with (security_invoker = true) as
select distinct on (ps.project_id)
  ps.project_id,
  sti.name       as current_stage,
  sti.seq        as current_stage_seq,
  ps.status      as current_stage_status,
  ps.actual_start,
  coalesce(current_date - ps.actual_start, 0) as days_in_stage,
  sti.default_duration_days
from project_stage ps
join stage_template_item sti on sti.id = ps.stage_template_item_id
left join project_module pm on pm.id = ps.project_module_id
where ps.status in ('Pending','InProgress','Blocked')
  and (ps.project_module_id is null or pm.in_scope = true)
order by ps.project_id, sti.seq;

-- v_project_board: one row per project for the kanban board.
create or replace view v_project_board
  with (security_invoker = true) as
select
  p.id              as project_id,
  p.title,
  p.type,
  p.status,
  p.health_score,
  p.health_breakdown,
  p.planned_golive,
  p.actual_golive,
  p.owner_user_id,
  ou.name           as owner_name,
  c.id              as client_id,
  c.code            as client_code,
  c.name            as client_name,
  c.segment,
  cs.current_stage,
  cs.current_stage_seq,
  cs.current_stage_status,
  cs.days_in_stage,
  cs.default_duration_days
from project p
join client c on c.id = p.client_id
left join app_user ou on ou.id = p.owner_user_id
left join v_project_current_stage cs on cs.project_id = p.id;

-- v_stalled_projects: active projects with no touchpoint, stage change or query
-- activity recently, sorted by days stalled. The N-day threshold is applied by
-- the caller (where days_stalled >= N); the view exposes days_stalled.
create or replace view v_stalled_projects
  with (security_invoker = true) as
with activity as (
  select
    p.id as project_id,
    greatest(
      coalesce((select max(t.occurred_on) from touchpoint t where t.project_id = p.id), 'epoch'::timestamptz),
      coalesce((select max(ps.updated_at) from project_stage ps where ps.project_id = p.id), 'epoch'::timestamptz),
      coalesce((select max(q.created_at) from query q where q.project_id = p.id), 'epoch'::timestamptz),
      p.created_at
    ) as last_activity_at
  from project p
  where p.status in ('NotStarted','InProgress','OnHold','Hypercare')
)
select
  b.*,
  a.last_activity_at,
  (current_date - a.last_activity_at::date) as days_stalled
from activity a
join v_project_board b on b.project_id = a.project_id
order by days_stalled desc;

-- v_consultant_load: open projects and open queries per internal user.
create or replace view v_consultant_load
  with (security_invoker = true) as
select
  u.id                         as user_id,
  u.name,
  u.role,
  u.is_active,
  coalesce(pj.open_projects, 0) as open_projects,
  coalesce(qr.open_queries, 0)  as open_queries
from app_user u
left join (
  select owner_user_id, count(*) as open_projects
  from project
  where status in ('NotStarted','InProgress','OnHold','Hypercare')
  group by owner_user_id
) pj on pj.owner_user_id = u.id
left join (
  select assignee_user_id, count(*) as open_queries
  from query
  where status not in ('Resolved','Closed','Cancelled')
  group by assignee_user_id
) qr on qr.assignee_user_id = u.id
where u.is_active = true;

-- v_query_heatmap: query counts by module and severity, last 30 days.
create or replace view v_query_heatmap
  with (security_invoker = true) as
select
  m.id   as module_id,
  m.name as module_name,
  q.severity,
  count(*) as query_count
from query q
join module_master m on m.id = q.module_id
where q.created_at >= now() - interval '30 days'
group by m.id, m.name, q.severity;

-- v_root_cause_mix: closed query counts by root cause and month.
create or replace view v_root_cause_mix
  with (security_invoker = true) as
select
  date_trunc('month', q.closed_at)::date as month,
  q.root_cause,
  count(*) as query_count
from query q
where q.status = 'Closed' and q.closed_at is not null and q.root_cause is not null
group by date_trunc('month', q.closed_at), q.root_cause;

-- v_client_360: one row per client — project status roll-up, open queries,
-- last touchpoint, and the (future) outstanding figure from the seam.
create or replace view v_client_360
  with (security_invoker = true) as
select
  c.id   as client_id,
  c.code,
  c.name,
  c.segment,
  c.amc_status,
  c.amc_expiry,
  (select count(*) from project p
     where p.client_id = c.id
       and p.status in ('NotStarted','InProgress','OnHold','Hypercare')) as active_projects,
  (select count(*) from query q
     where q.client_id = c.id
       and q.status not in ('Resolved','Closed','Cancelled')) as open_queries,
  (select count(*) from query q
     where q.client_id = c.id
       and q.severity in ('S1','S2')
       and q.status not in ('Resolved','Closed','Cancelled')) as open_critical_queries,
  (select max(t.occurred_on) from touchpoint t where t.client_id = c.id) as last_touchpoint_at,
  -- Churn signal: a client with a live/hypercare project and zero queries since
  -- go-live is usually not contentment — it is silent disengagement.
  (select count(*) from query q where q.client_id = c.id and q.is_post_golive) as post_golive_queries,
  -- The seam: latest outstanding snapshot (empty in v1).
  (select cfs.total_outstanding from client_financial_snapshot cfs
     where cfs.client_id = c.id order by cfs.as_of desc limit 1) as latest_outstanding,
  (select cfs.as_of from client_financial_snapshot cfs
     where cfs.client_id = c.id order by cfs.as_of desc limit 1) as outstanding_as_of
from client c;
