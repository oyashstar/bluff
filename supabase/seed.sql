-- Finsys Internal Tracker — Phase 0 seed (reference/config data only)
-- Applied by `supabase db reset` after migrations. This is NOT fake client
-- data: it is the module master, the SLA targets, the standard lifecycle
-- template and the holiday calendar. Real clients are entered from Phase 1.

-- ---------------------------------------------------------------------------
-- Module master
-- ---------------------------------------------------------------------------
insert into module_master (code, name, seq) values
  ('SALES',       'Sales',       10),
  ('PURCHASE',    'Purchase',    20),
  ('STORES',      'Stores',      30),
  ('PRODUCTION',  'Production',  40),
  ('COSTING',     'Costing',     50),
  ('ACCOUNTS',    'Accounts',    60),
  ('PAYROLL',     'Payroll',     70),
  ('QC',          'QC',          80),
  ('MAINTENANCE', 'Maintenance', 90)
on conflict (code) do nothing;

-- ---------------------------------------------------------------------------
-- SLA targets (business minutes). 09:30–18:30 IST, Mon–Sat.
--   S1 production stopped   : respond 30m, resolve 4 business hours
--   S2 major w/ workaround  : respond 2h,  resolve 2 business days (16h)
--   S3 minor/cosmetic       : respond 1 business day, resolve 5 business days
--   S4 how-to               : respond 1 business day, resolve 5 business days
-- ---------------------------------------------------------------------------
insert into sla_target (severity, first_response_minutes, resolution_minutes) values
  ('S1',  30,  240),
  ('S2', 120,  960),
  ('S3', 540, 2700),
  ('S4', 540, 2700)
on conflict (severity) do update set
  first_response_minutes = excluded.first_response_minutes,
  resolution_minutes     = excluded.resolution_minutes;

-- ---------------------------------------------------------------------------
-- Standard New Implementation lifecycle — 11 stages, 3 sign-off gates.
-- Sign-off gates: CRP sign-off, UAT sign-off, Project closure sign-off.
-- ---------------------------------------------------------------------------
do $$
declare v_tmpl uuid;
begin
  if not exists (select 1 from stage_template where name = 'Standard New Implementation') then
    insert into stage_template (name, project_type)
    values ('Standard New Implementation', 'NewImplementation')
    returning id into v_tmpl;

    insert into stage_template_item (stage_template_id, name, seq, requires_signoff, default_duration_days) values
      (v_tmpl, 'Kickoff & Scoping',          1, false,  3),
      (v_tmpl, 'Data Collection',            2, false,  7),
      (v_tmpl, 'Master Data Setup',          3, false,  5),
      (v_tmpl, 'Configuration',              4, false, 10),
      (v_tmpl, 'Conference Room Pilot',      5, true,   3),  -- sign-off gate 1
      (v_tmpl, 'User Training',              6, false,  5),
      (v_tmpl, 'Data Migration',             7, false,  4),
      (v_tmpl, 'User Acceptance Testing',    8, true,   7),  -- sign-off gate 2
      (v_tmpl, 'Go-Live',                    9, false,  2),
      (v_tmpl, 'Hypercare',                 10, false, 14),
      (v_tmpl, 'Project Closure',           11, true,   2); -- sign-off gate 3
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Holiday calendar — India national holidays, remainder of 2026 + 2027.
-- Edit freely; this table is the source of truth for the SLA clock.
-- (Regional/festival holidays vary by office; confirm with HR before go-live.)
-- ---------------------------------------------------------------------------
insert into holiday (holiday_date, name) values
  ('2026-11-08', 'Diwali (observed)'),
  ('2026-12-25', 'Christmas'),
  ('2027-01-26', 'Republic Day'),
  ('2027-03-04', 'Holi'),
  ('2027-08-15', 'Independence Day'),
  ('2027-10-02', 'Gandhi Jayanti')
on conflict (holiday_date) do nothing;
