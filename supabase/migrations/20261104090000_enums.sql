-- Finsys Internal Tracker — enumerations
-- All domain enums as first-class Postgres types. Changing a lifecycle is data
-- (stage_template), but these closed sets are types on purpose: the status
-- machine, the severity ladder and the root-cause list are contracts, not config.

create type project_type as enum (
  'NewImplementation',
  'ModuleExpansion',
  'VersionUpgrade',
  'Reimplementation'
);

create type project_status as enum (
  'NotStarted',
  'InProgress',
  'OnHold',
  'Hypercare',
  'Closed',
  'Dropped'
);

create type stage_status as enum (
  'Pending',
  'InProgress',
  'Blocked',
  'Done',
  'Skipped'
);

create type query_channel as enum (
  'Phone',
  'WhatsApp',
  'Email',
  'SiteVisit',
  'Portal'
);

-- S1 production stopped · S2 major function broken, workaround exists
-- S3 minor or cosmetic · S4 how-to question
create type query_severity as enum ('S1', 'S2', 'S3', 'S4');

create type query_status as enum (
  'New',
  'Acknowledged',
  'InProgress',
  'AwaitingClient',   -- pauses the SLA clock
  'AwaitingDev',      -- pauses the SLA clock
  'Resolved',
  'Closed',
  'Reopened',
  'Cancelled'
);

create type root_cause as enum (
  'Bug',
  'TrainingGap',
  'CustomisationRequest',
  'DataIssue',
  'Infrastructure',
  'ExpectedBehaviour',
  'Enhancement'
);

-- Internal user roles. 15–25 people, single tenant. Kept deliberately small;
-- RLS write rules hang off this (see rls_policies migration).
create type app_role as enum (
  'Admin',       -- full read/write, user management
  'Manager',     -- full read/write on operational data, no user management
  'Consultant',  -- owns projects/stages/touchpoints; can log queries
  'Support',     -- owns queries/comments; read-only on projects
  'Viewer'       -- read-only everywhere
);
