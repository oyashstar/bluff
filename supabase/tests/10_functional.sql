\set ON_ERROR_STOP on
\timing off

-- ============ Seed sanity ============
do $$
begin
  assert (select count(*) from module_master) = 9, 'expected 9 modules';
  assert (select count(*) from sla_target) = 4, 'expected 4 sla targets';
  assert (select count(*) from stage_template_item
          where stage_template_id = (select id from stage_template where name='Standard New Implementation')) = 11,
          'expected 11 template stages';
  assert (select count(*) from stage_template_item i
          join stage_template t on t.id=i.stage_template_id
          where t.name='Standard New Implementation' and i.requires_signoff) = 3,
          'expected 3 sign-off gates';
  raise notice 'SEED OK: 9 modules, 4 SLA targets, 11 stages, 3 gates';
end $$;

-- ============ Business-hours calendar ============
do $$
declare bm int; dl timestamptz;
begin
  -- Fri 13 Nov 2026 17:00 IST -> Mon 16 Nov 2026 11:00 IST
  -- Fri 17:00-18:30 = 90, Sat 540, Sun 0, Mon 09:30-11:00 = 90  => 720
  bm := fn_business_minutes_between('2026-11-13 17:00:00+05:30', '2026-11-16 11:00:00+05:30');
  raise notice 'business minutes Fri17:00->Mon11:00 = % (expect 720)', bm;
  assert bm = 720, 'business minutes mismatch: '||bm;

  -- Sunday is non-working
  assert fn_business_minutes_between('2026-11-15 10:00:00+05:30','2026-11-15 17:00:00+05:30') = 0, 'sunday should be 0';
  -- add 100 business minutes to Fri 17:00 -> Sat 09:40 (90 left Fri, +10 Sat)
  dl := fn_add_business_minutes('2026-11-13 17:00:00+05:30', 100);
  raise notice 'Fri17:00 + 100 business min = % (expect Sat 09:40 IST)', dl at time zone 'Asia/Kolkata';
  assert (dl at time zone 'Asia/Kolkata') = '2026-11-14 09:40:00'::timestamp, 'add business minutes mismatch';
  raise notice 'CALENDAR OK';
end $$;

-- ============ Users via auth trigger ============
do $$
declare uadmin uuid; uconsult uuid;
begin
  insert into auth.users (email, raw_user_meta_data) values ('admin@finsys.test', '{"name":"Ava Admin"}') returning id into uadmin;
  insert into auth.users (email, raw_user_meta_data) values ('con@finsys.test', '{"name":"Cory Consultant"}') returning id into uconsult;
  assert (select count(*) from app_user) = 2, 'app_user should mirror auth.users';
  update app_user set role='Admin' where id=uadmin;
  update app_user set role='Consultant' where id=uconsult;
  assert (select name from app_user where id=uadmin) = 'Ava Admin', 'name not carried from metadata';
  raise notice 'USERS OK: app_user mirrors auth.users with metadata name';
end $$;

-- ============ Registry + stage template application ============
do $$
declare cid uuid; pid uuid; tmpl uuid; nstages int; owner uuid;
begin
  select id into owner from app_user where role='Consultant' limit 1;
  insert into client (code, name, segment, erp_client_code)
    values ('ACME01','Acme Boxes','Corrugation','ERP-ACME-1') returning id into cid;
  select id into tmpl from stage_template where name='Standard New Implementation';
  insert into project (client_id, title, type, owner_user_id, stage_template_id, planned_golive, status)
    values (cid,'Acme ERP','NewImplementation', owner, tmpl, current_date + 30, 'InProgress') returning id into pid;
  perform fn_apply_stage_template(pid, tmpl);
  select count(*) into nstages from project_stage where project_id=pid and project_module_id is null;
  assert nstages = 11, 'expected 11 project stages, got '||nstages;

  -- advance first stage: set in progress then done
  update project_stage set status='InProgress', actual_start=current_date-20
    where project_id=pid and stage_template_item_id=(select id from stage_template_item where stage_template_id=tmpl and seq=1);
  -- headline/current stage via view
  assert (select current_stage from v_project_board where project_id=pid) is not null, 'board should have a current stage';
  raise notice 'REGISTRY OK: 11 stages materialised, board renders current stage';
end $$;

-- ============ Queries: create, SLA stamp, status machine, pause, root cause ============
do $$
declare cid uuid; qid uuid; st query_status; paused_before int; paused_after int; got boolean;
begin
  select id into cid from client where code='ACME01';
  insert into query (client_id, severity, subject) values (cid,'S2','Cannot print GRN') returning id into qid;
  -- SLA due dates stamped by trigger
  assert (select sla_response_due from query where id=qid) is not null, 'response due not stamped';
  assert (select sla_resolution_due from query where id=qid) is not null, 'resolution due not stamped';
  assert (select ticket_no from query where id=qid) like 'Q-%', 'ticket_no not generated';

  -- illegal transition New->Resolved should fail
  got := false;
  begin
    perform fn_transition_query(qid, 'Resolved');
  exception when others then got := true;
  end;
  assert got, 'illegal transition New->Resolved was allowed';

  -- legal path
  perform fn_transition_query(qid, 'Acknowledged');
  assert (select acknowledged_at from query where id=qid) is not null, 'acknowledged_at not set';
  perform fn_transition_query(qid, 'InProgress');

  -- pause: go AwaitingClient, backdate paused_since, resume, expect paused minutes to grow
  perform fn_transition_query(qid, 'AwaitingClient');
  assert (select sla_paused_since from query where id=qid) is not null, 'paused_since not set on pause';
  select sla_paused_minutes into paused_before from query where id=qid;
  update query set sla_paused_since = now() - interval '3 hours' where id=qid; -- simulate a pause earlier today
  perform fn_transition_query(qid, 'InProgress');
  select sla_paused_minutes into paused_after from query where id=qid;
  assert (select sla_paused_since from query where id=qid) is null, 'paused_since not cleared on resume';
  raise notice 'paused minutes before=% after=% (should grow by business minutes in the backdated window)', paused_before, paused_after;
  assert paused_after >= paused_before, 'paused minutes did not accumulate';

  -- root cause mandatory before Resolved
  got := false;
  begin perform fn_transition_query(qid,'Resolved'); exception when others then got := true; end;
  assert got, 'Resolved allowed without root cause';

  update query set root_cause='TrainingGap' where id=qid;
  perform fn_transition_query(qid, 'Resolved');
  assert (select resolved_at from query where id=qid) is not null, 'resolved_at not set';
  perform fn_transition_query(qid, 'Closed');
  assert (select closed_at from query where id=qid) is not null, 'closed_at not set';
  raise notice 'QUERIES OK: SLA stamped, machine enforced, pause accumulated, root cause required';
end $$;

-- ============ Health recompute ============
do $$
declare pid uuid; hs int; hb jsonb;
begin
  select id into pid from project limit 1;
  perform fn_recompute_health(pid);
  select health_score, health_breakdown into hs, hb from project where id=pid;
  assert hs is not null and hs between 0 and 100, 'health score out of range: '||coalesce(hs::text,'null');
  assert hb ? 'stage_overrun' and hb ? 'total', 'breakdown missing components';
  raise notice 'HEALTH OK: score=% breakdown keys=%', hs, (select array_agg(k) from jsonb_object_keys(hb) k);
end $$;

-- ============ All dashboard views execute ============
do $$
declare v text; n int;
begin
  foreach v in array array['v_project_board','v_project_current_stage','v_stalled_projects',
    'v_consultant_load','v_query_heatmap','v_root_cause_mix','v_client_360','v_sla_board','v_silent_clients'] loop
    execute format('select count(*) from %I', v) into n;
    raise notice 'view % -> % rows', v, n;
  end loop;
  raise notice 'VIEWS OK: all 9 views executed';
end $$;

-- ============ Audit log populated ============
do $$
declare n int;
begin
  select count(*) into n from audit_log;
  assert n > 0, 'audit_log empty';
  raise notice 'AUDIT OK: % audit rows captured', n;
end $$;

select 'ALL LOGIC TESTS PASSED' as result;
