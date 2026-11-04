-- Finsys Internal Tracker — Phase 3/4 additions
-- The SLA board and churn views the dashboards read, the notification outbox
-- and breach scan (Phase 4), and the attachments storage bucket + policies.

-- ---------------------------------------------------------------------------
-- v_sla_board: open tickets with response/resolution SLA status, net of paused
-- time. The resolution due date is pushed out by the paused minutes (including
-- an in-progress pause), so a ticket parked AwaitingClient does not "breach"
-- while the clock is stopped.
-- ---------------------------------------------------------------------------
create or replace view v_sla_board with (security_invoker = true) as
with base as (
  select
    q.id as query_id, q.ticket_no, q.subject, q.severity,
    c.name as client_name, q.assignee_user_id, au.name as assignee_name,
    q.acknowledged_at, q.sla_response_due, q.sla_resolution_due,
    q.sla_paused_minutes
      + case when q.sla_paused_since is not null
             then fn_business_minutes_between(q.sla_paused_since, now())
             else 0 end as total_paused
  from query q
  join client c on c.id = q.client_id
  left join app_user au on au.id = q.assignee_user_id
  where q.status not in ('Resolved','Closed','Cancelled')
)
select
  b.query_id, b.ticket_no, b.subject, b.severity, b.client_name,
  b.assignee_user_id, b.assignee_name,
  case
    when b.acknowledged_at is not null then
      case when b.sla_response_due is null or b.acknowledged_at <= b.sla_response_due
           then 'met' else 'breached' end
    else case when b.sla_response_due is not null and now() > b.sla_response_due
              then 'breached' else 'pending' end
  end as response_status,
  eff.effective_resolution_due,
  case
    when eff.effective_resolution_due is null then 'on_track'
    when now() >= eff.effective_resolution_due then 'breached'
    when fn_business_minutes_between(now(), eff.effective_resolution_due) <= 120 then 'at_risk'
    else 'on_track'
  end as resolution_status
from base b
cross join lateral (
  select fn_add_business_minutes(b.sla_resolution_due, b.total_paused) as effective_resolution_due
) eff;

-- ---------------------------------------------------------------------------
-- v_silent_clients: the churn signal. Clients that went live more than 30 days
-- ago and whose last query (or go-live, if none) is older than 30 days — i.e.
-- their query volume dropped to zero after go-live.
-- ---------------------------------------------------------------------------
create or replace view v_silent_clients with (security_invoker = true) as
with golive as (
  select client_id, min(actual_golive) as first_golive
  from project
  where actual_golive is not null
  group by client_id
),
lastq as (
  select client_id, max(created_at) as last_query_at
  from query
  group by client_id
)
select
  c.id as client_id,
  c.name,
  c.code,
  lq.last_query_at,
  (current_date - coalesce(lq.last_query_at::date, g.first_golive))::int as days_silent
from client c
join golive g on g.client_id = c.id
left join lastq lq on lq.client_id = c.id
where g.first_golive <= current_date - 30
  and coalesce(lq.last_query_at, g.first_golive::timestamptz) < now() - interval '30 days';

-- ---------------------------------------------------------------------------
-- notification_outbox (Phase 4). Rows are enqueued here (by the breach scan or
-- future app code) and drained by the notify-whatsapp Edge Function via the
-- service role. dedupe_key prevents re-notifying the same breach.
-- ---------------------------------------------------------------------------
create table notification_outbox (
  id                  bigint generated always as identity primary key,
  channel             text not null default 'whatsapp',
  recipient           text,
  template            text,
  payload             jsonb not null default '{}'::jsonb,
  related_entity_type text,
  related_entity_id   text,
  status              text not null default 'pending',   -- pending | sent | failed
  dedupe_key          text unique,
  created_at          timestamptz not null default now(),
  sent_at             timestamptz,
  error               text
);
alter table notification_outbox enable row level security;
create policy notification_outbox_read on notification_outbox
  for select using (fn_has_role('Admin','Manager'));
-- No client write policy: the breach scan (SECURITY DEFINER) and the Edge
-- Function (service role) are the only writers.

-- Enqueue notifications for tickets whose resolution SLA is breached. Idempotent
-- via dedupe_key. Run on a schedule; the notify Edge Function sends them.
create or replace function fn_scan_sla_breaches() returns int
  language plpgsql
  security definer
  set search_path = public
as $$
declare v int;
begin
  insert into notification_outbox
    (channel, template, payload, related_entity_type, related_entity_id, dedupe_key)
  select
    'whatsapp',
    'sla_breach',
    jsonb_build_object(
      'ticket_no', b.ticket_no,
      'subject',   b.subject,
      'client',    b.client_name,
      'severity',  b.severity,
      'assignee',  coalesce(b.assignee_name, 'Unassigned')
    ),
    'query',
    b.query_id,
    'sla_breach:' || b.query_id
  from v_sla_board b
  where b.resolution_status = 'breached'
  on conflict (dedupe_key) do nothing;
  get diagnostics v = row_count;
  return v;
end;
$$;

-- ---------------------------------------------------------------------------
-- Attachments storage bucket + policies. Private bucket; internal users read,
-- support editors write. Supabase enables RLS on storage.objects already.
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;

create policy "attachments_read" on storage.objects
  for select using (bucket_id = 'attachments' and fn_is_internal());
create policy "attachments_insert" on storage.objects
  for insert with check (bucket_id = 'attachments' and fn_can_edit_support());
create policy "attachments_update" on storage.objects
  for update using (bucket_id = 'attachments' and fn_can_edit_support());
create policy "attachments_delete" on storage.objects
  for delete using (bucket_id = 'attachments' and fn_has_role('Admin','Manager'));

-- ---------------------------------------------------------------------------
-- Schedule the breach scan every 15 minutes (guarded, like the health job).
-- ---------------------------------------------------------------------------
do $$
begin
  perform cron.schedule('finsys-sla-breach-scan', '*/15 * * * *', 'select fn_scan_sla_breaches();');
exception when others then
  raise notice 'pg_cron not available (%). Schedule fn_scan_sla_breaches() externally.', sqlerrm;
end;
$$;
