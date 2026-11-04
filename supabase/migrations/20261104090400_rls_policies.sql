-- Finsys Internal Tracker — row-level security
-- RLS on from day one, every table, no exceptions. The app ships with the anon
-- key only; the service-role key never leaves the server.
--
-- Single tenant, 15–25 trusted internal users. The threat model is "a Support
-- user should not be able to edit a project", not "tenant A must not see tenant
-- B". So: every active internal user can READ all operational data, and WRITES
-- are gated by role. One readable block per table; see docs/DECISIONS.md for the
-- one-line-per-table summary.

-- Enable RLS everywhere. Tables with no policy are then deny-all by default,
-- which is the safe failure mode.
alter table app_user                  enable row level security;
alter table client                    enable row level security;
alter table client_contact            enable row level security;
alter table module_master             enable row level security;
alter table stage_template            enable row level security;
alter table stage_template_item       enable row level security;
alter table project                   enable row level security;
alter table project_module            enable row level security;
alter table project_stage             enable row level security;
alter table signoff                   enable row level security;
alter table touchpoint                enable row level security;
alter table query                     enable row level security;
alter table query_comment             enable row level security;
alter table attachment                enable row level security;
alter table audit_log                 enable row level security;
alter table client_financial_snapshot enable row level security;

-- ---------------------------------------------------------------------------
-- app_user: everyone reads; only Admin writes; a user may update their own
-- name (but not their role).
-- ---------------------------------------------------------------------------
create policy app_user_read on app_user
  for select using (fn_is_internal());
create policy app_user_admin_write on app_user
  for all using (fn_has_role('Admin')) with check (fn_has_role('Admin'));
-- A user may update their own row but not escalate their role. fn_my_role() is
-- SECURITY DEFINER (runs as the table owner, bypassing RLS) so this does not
-- recurse into app_user's own policies.
create policy app_user_self_update on app_user
  for update using (id = auth.uid())
  with check (id = auth.uid() and role = fn_my_role());

-- ---------------------------------------------------------------------------
-- Registry (client, contact, module): read all; delivery editors write.
-- module_master changes are Admin/Manager only.
-- ---------------------------------------------------------------------------
create policy client_read on client
  for select using (fn_is_internal());
create policy client_write on client
  for all using (fn_can_edit_delivery()) with check (fn_can_edit_delivery());

create policy client_contact_read on client_contact
  for select using (fn_is_internal());
create policy client_contact_write on client_contact
  for all using (fn_can_edit_delivery()) with check (fn_can_edit_delivery());

create policy module_master_read on module_master
  for select using (fn_is_internal());
create policy module_master_write on module_master
  for all using (fn_has_role('Admin','Manager')) with check (fn_has_role('Admin','Manager'));

-- ---------------------------------------------------------------------------
-- Lifecycle templates: read all; Admin/Manager own the lifecycle.
-- ---------------------------------------------------------------------------
create policy stage_template_read on stage_template
  for select using (fn_is_internal());
create policy stage_template_write on stage_template
  for all using (fn_has_role('Admin','Manager')) with check (fn_has_role('Admin','Manager'));

create policy stage_template_item_read on stage_template_item
  for select using (fn_is_internal());
create policy stage_template_item_write on stage_template_item
  for all using (fn_has_role('Admin','Manager')) with check (fn_has_role('Admin','Manager'));

-- ---------------------------------------------------------------------------
-- Delivery (project, module, stage, signoff, touchpoint): read all;
-- delivery editors write.
-- ---------------------------------------------------------------------------
create policy project_read on project
  for select using (fn_is_internal());
create policy project_write on project
  for all using (fn_can_edit_delivery()) with check (fn_can_edit_delivery());

create policy project_module_read on project_module
  for select using (fn_is_internal());
create policy project_module_write on project_module
  for all using (fn_can_edit_delivery()) with check (fn_can_edit_delivery());

create policy project_stage_read on project_stage
  for select using (fn_is_internal());
create policy project_stage_write on project_stage
  for all using (fn_can_edit_delivery()) with check (fn_can_edit_delivery());

create policy signoff_read on signoff
  for select using (fn_is_internal());
create policy signoff_write on signoff
  for all using (fn_can_edit_delivery()) with check (fn_can_edit_delivery());

create policy touchpoint_read on touchpoint
  for select using (fn_is_internal());
create policy touchpoint_write on touchpoint
  for all using (fn_can_edit_support()) with check (fn_can_edit_support());

-- ---------------------------------------------------------------------------
-- Support (query, comment, attachment): read all; support editors write.
-- Status changes should go through fn_transition_query, but a bare update is
-- still permitted for editors (the function enforces the machine; see note).
-- ---------------------------------------------------------------------------
create policy query_read on query
  for select using (fn_is_internal());
create policy query_write on query
  for all using (fn_can_edit_support()) with check (fn_can_edit_support());

create policy query_comment_read on query_comment
  for select using (fn_is_internal());
create policy query_comment_write on query_comment
  for all using (fn_can_edit_support()) with check (fn_can_edit_support());

create policy attachment_read on attachment
  for select using (fn_is_internal());
create policy attachment_write on attachment
  for all using (fn_can_edit_support()) with check (fn_can_edit_support());

-- ---------------------------------------------------------------------------
-- audit_log: read-only to internal users. No INSERT/UPDATE/DELETE policy, so
-- direct writes are denied; the audit trigger runs as SECURITY DEFINER and
-- bypasses RLS, which is exactly the intent.
-- ---------------------------------------------------------------------------
create policy audit_log_read on audit_log
  for select using (fn_is_internal());

-- ---------------------------------------------------------------------------
-- client_financial_snapshot: read-only to internal users in v1 (empty table).
-- Phase 5 writes land via the service role from an Edge Function, which
-- bypasses RLS. No client-side write policy on purpose.
-- ---------------------------------------------------------------------------
create policy client_financial_snapshot_read on client_financial_snapshot
  for select using (fn_is_internal());
