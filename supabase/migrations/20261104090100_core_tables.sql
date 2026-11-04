-- Finsys Internal Tracker — core schema
-- 15 tables in three groups: registry, delivery, support. Real foreign keys,
-- no soft delete, no multi-tenancy. Small data (~500 clients, 30–60 active
-- implementations, 15–25 users): modelled for clarity, not scale.

-- ---------------------------------------------------------------------------
-- Group 1 · registry (who the clients are, who we are)
-- ---------------------------------------------------------------------------

-- Mirrors auth.users. The row is created by a trigger on auth.users (see
-- triggers_wireup migration) so every authenticated person has exactly one
-- app_user. role drives RLS; is_active gates login effects.
create table app_user (
  id          uuid primary key references auth.users (id) on delete cascade,
  name        text not null default '',
  email       text not null,
  role        app_role not null default 'Viewer',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
comment on table app_user is 'Internal users, 1:1 with auth.users. role drives RLS.';

create table client (
  id                   uuid primary key default gen_random_uuid(),
  code                 text not null unique,           -- our short code, e.g. ACME01
  name                 text not null,
  segment              text,                           -- e.g. Corrugation, Packaging
  city                 text,
  state                text,
  erp_version          text,
  amc_status           text,                           -- Active / Lapsed / None
  amc_expiry           date,
  onboarded_on         date,
  account_owner_user_id uuid references app_user (id),
  -- The one and only future join key to the ERP. Plain text, typed by hand.
  -- Nothing in v1 reads it; the ERP seam (client_financial_snapshot) will.
  erp_client_code      text,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);
comment on column client.erp_client_code is
  'Hand-entered ERP key. The only column that will ever join this DB to Oracle. Unused in v1.';

create table client_contact (
  id          uuid primary key default gen_random_uuid(),
  client_id   uuid not null references client (id) on delete cascade,
  name        text not null,
  role        text,                                    -- designation at the client
  phone       text,
  email       text,
  is_primary  boolean not null default false,
  is_champion boolean not null default false,          -- the internal advocate
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on client_contact (client_id);

create table module_master (
  id         uuid primary key default gen_random_uuid(),
  code       text not null unique,                     -- SALES, PURCHASE, ...
  name       text not null,
  seq        int not null default 0,
  is_active  boolean not null default true
);

-- ---------------------------------------------------------------------------
-- Group 2 · delivery (implementations, stages, sign-offs, touchpoints)
-- ---------------------------------------------------------------------------

-- A named, ordered lifecycle. Editable data, not an enum: the lifecycle can be
-- changed without a deploy, and expansions/upgrades get their own templates.
create table stage_template (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  project_type project_type not null default 'NewImplementation',
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

create table stage_template_item (
  id                    uuid primary key default gen_random_uuid(),
  stage_template_id     uuid not null references stage_template (id) on delete cascade,
  name                  text not null,
  seq                   int not null,
  requires_signoff      boolean not null default false,
  default_duration_days int not null default 0,
  unique (stage_template_id, seq)
);

create table project (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references client (id) on delete restrict,
  type             project_type not null default 'NewImplementation',
  title            text not null,
  stage_template_id uuid references stage_template (id),
  owner_user_id    uuid references app_user (id),
  planned_golive   date,
  actual_golive    date,
  status           project_status not null default 'NotStarted',
  -- Revisions of planned_golive feed the health score; kept as a running count.
  golive_revisions int not null default 0,
  health_score     int,                                -- 0–100, null until first recompute
  health_breakdown jsonb not null default '{}'::jsonb,  -- component scores, shown on hover
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index on project (client_id);
create index on project (status);

create table project_module (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references project (id) on delete cascade,
  module_id      uuid not null references module_master (id),
  in_scope       boolean not null default true,
  status         stage_status not null default 'Pending',
  planned_golive date,
  actual_golive  date,
  unique (project_id, module_id)
);

-- One row per stage instance. project_module_id NULL => a whole-project stage;
-- a value => a per-module stage. This single nullable FK is what lets a project
-- carry project-level and module-level stages in one table (load-bearing).
create table project_stage (
  id                     uuid primary key default gen_random_uuid(),
  project_id             uuid not null references project (id) on delete cascade,
  project_module_id      uuid references project_module (id) on delete cascade,
  stage_template_item_id uuid not null references stage_template_item (id),
  status                 stage_status not null default 'Pending',
  planned_start          date,
  planned_end            date,
  actual_start           date,
  actual_end             date,
  owner_user_id          uuid references app_user (id),
  blocked_reason         text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);
create index on project_stage (project_id);
create index on project_stage (project_module_id);

create table signoff (
  id               uuid primary key default gen_random_uuid(),
  project_stage_id uuid not null references project_stage (id) on delete cascade,
  contact_id       uuid references client_contact (id),
  signed_on        date,
  document_path    text,                               -- Supabase Storage path
  remarks          text,
  created_at       timestamptz not null default now()
);

create table touchpoint (
  id           uuid primary key default gen_random_uuid(),
  client_id    uuid not null references client (id) on delete cascade,
  project_id   uuid references project (id) on delete set null,
  user_id      uuid references app_user (id),
  type         text,                                   -- Call / Visit / Email / Meeting
  occurred_on  timestamptz not null default now(),
  duration_min int,
  summary      text,
  created_at   timestamptz not null default now()
);
create index on touchpoint (client_id);
create index on touchpoint (project_id);
create index on touchpoint (occurred_on);

-- ---------------------------------------------------------------------------
-- Group 3 · support (queries, comments, attachments)
-- ---------------------------------------------------------------------------

create sequence query_ticket_seq;

create table query (
  id                uuid primary key default gen_random_uuid(),
  ticket_no         text not null unique
                      default 'Q-' || lpad(nextval('query_ticket_seq')::text, 6, '0'),
  client_id         uuid not null references client (id) on delete restrict,
  project_id        uuid references project (id) on delete set null,
  module_id         uuid references module_master (id),
  contact_id        uuid references client_contact (id),
  channel           query_channel not null default 'Phone',
  severity          query_severity not null default 'S3',
  subject           text not null,
  description       text,
  status            query_status not null default 'New',
  assignee_user_id  uuid references app_user (id),
  is_post_golive    boolean not null default false,
  created_at        timestamptz not null default now(),
  acknowledged_at   timestamptz,
  resolved_at       timestamptz,
  closed_at         timestamptz,
  sla_response_due  timestamptz,
  sla_resolution_due timestamptz,
  sla_paused_minutes int not null default 0,
  -- Implementation detail (not in the handoff column list): when the clock is
  -- currently paused, this marks when the pause began. fn_transition_query
  -- rolls it into sla_paused_minutes on resume. Flagged in docs/DECISIONS.md.
  sla_paused_since  timestamptz,
  root_cause        root_cause,                         -- mandatory at Close (enforced in fn)
  resolution_notes  text,
  updated_at        timestamptz not null default now()
);
create index on query (client_id);
create index on query (status);
create index on query (severity);
create index on query (assignee_user_id);
create index on query (module_id);

create table query_comment (
  id          uuid primary key default gen_random_uuid(),
  query_id    uuid not null references query (id) on delete cascade,
  user_id     uuid references app_user (id),
  body        text not null,
  is_internal boolean not null default true,
  created_at  timestamptz not null default now()
);
create index on query_comment (query_id);

-- Polymorphic by design (entity_type + entity_id). Single tenant, small data;
-- a real FK per entity would be noise here.
create table attachment (
  id           uuid primary key default gen_random_uuid(),
  entity_type  text not null,                           -- 'query' | 'signoff' | ...
  entity_id    uuid not null,
  storage_path text not null,                           -- Supabase Storage path
  uploaded_by  uuid references app_user (id),
  uploaded_at  timestamptz not null default now()
);
create index on attachment (entity_type, entity_id);

-- ---------------------------------------------------------------------------
-- audit + the stubbed ERP seam
-- ---------------------------------------------------------------------------

-- Written only by the audit trigger (see audit migration). Never by Dart.
create table audit_log (
  id          bigint generated always as identity primary key,
  entity_type text not null,
  entity_id   text not null,
  action      text not null,                            -- INSERT | UPDATE | DELETE
  changed_by  uuid,                                     -- auth.uid() at write time
  changed_at  timestamptz not null default now(),
  before_json jsonb,
  after_json  jsonb
);
create index on audit_log (entity_type, entity_id);
create index on audit_log (changed_at);

-- The seam. Empty in v1. Phase 5 fills it from a read-only Oracle view via an
-- Edge Function. The Flutter app never reads Oracle; it reads this table.
create table client_financial_snapshot (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references client (id) on delete cascade,
  as_of            date not null,
  total_outstanding numeric(14,2),
  overdue_90_plus  numeric(14,2),
  synced_at        timestamptz not null default now(),
  unique (client_id, as_of)
);
