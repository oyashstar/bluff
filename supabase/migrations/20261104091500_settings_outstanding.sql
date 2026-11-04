-- Finsys Internal Tracker — app settings + outstanding (AR) view
-- Adds a small key/value settings store (holds the Finsys ERP *company code*
-- that the financial seam will scope its outstanding query to) and a view that
-- surfaces each client's latest outstanding snapshot.

-- ---------------------------------------------------------------------------
-- app_setting: tenant-level configuration, editable by an Admin in the app.
-- The Finsys ERP company code lives here: the ERP is multi-company, so the
-- sync-financials Edge Function needs to know WHICH company's AR to read.
-- Per-client linkage still uses client.erp_client_code; this is the tenant key.
-- ---------------------------------------------------------------------------
create table app_setting (
  key         text primary key,
  value       text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references app_user (id)
);
alter table app_setting enable row level security;
create policy app_setting_read on app_setting
  for select using (fn_is_internal());
create policy app_setting_write on app_setting
  for all using (fn_has_role('Admin')) with check (fn_has_role('Admin'));

-- Known keys (idempotent). Values are null until an Admin fills them in.
insert into app_setting (key, value) values
  ('company_name', null),
  ('erp_company_code', null)   -- Finsys ERP company code (the tenant's own)
on conflict (key) do nothing;

-- Convenience reader (SECURITY DEFINER so the Edge Function / jobs can read it
-- without a per-row grant). Returns the value for a key, or null.
create or replace function fn_setting(p_key text) returns text
  language sql
  stable
  security definer
  set search_path = public
as $$ select value from app_setting where key = p_key $$;

-- ---------------------------------------------------------------------------
-- v_client_outstanding: one row per client with its latest financial snapshot.
-- Empty figures in v1 (the seam is stubbed); populated once sync-financials
-- runs against the ERP company code set in app_setting.
-- ---------------------------------------------------------------------------
create or replace view v_client_outstanding with (security_invoker = true) as
select
  c.id   as client_id,
  c.code,
  c.name,
  c.erp_client_code,
  s.total_outstanding,
  s.overdue_90_plus,
  s.as_of,
  s.synced_at
from client c
left join lateral (
  select total_outstanding, overdue_90_plus, as_of, synced_at
  from client_financial_snapshot cfs
  where cfs.client_id = c.id
  order by cfs.as_of desc
  limit 1
) s on true;
