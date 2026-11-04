# Finsys Internal Tracker

Standalone internal tool for Finsys Infotech: one place that shows **where every
ERP implementation stands** and **what every client has been asking for**.
Experimental, internal, single-tenant. Optimised for speed of change over scale
or polish.

> This repository is deliberately isolated. It shares **nothing** with any
> existing Finsys codebase, holds **no** Oracle package and **no** ERP
> credentials, and the only future link to the ERP is a hand-typed
> `client.erp_client_code` plus a stubbed read-only seam. See
> [docs/DECISIONS.md](docs/DECISIONS.md).

## Stack

- **Flutter** — everything a person touches (Web for office screens, the same
  codebase to Android/iOS for consultants in the field).
- **Supabase** — managed Postgres, Auth, Row-Level Security, and the
  auto-generated REST/realtime API. **There is no separate backend API service.**
- **Schema = checked-in SQL migrations** under `supabase/migrations/`, applied
  with the Supabase CLI. Never clicked together in the dashboard.
- **Riverpod** for state, **go_router** for routing, **Supabase Storage** for
  attachments.

## Layout

```
lib/
  main.dart                  entry; initialises Supabase with the anon key only
  src/core/                  enums, formatting, shared widgets, CSV export, async view
  src/supabase/              the single Supabase client + auth providers
  src/auth/                  login, auth controller, app_user + role providers
  src/router/                go_router wired to auth state (ShellRoute + all routes)
  src/finance/               ClientFinancialProvider seam: stub (shipped) + snapshot
  src/features/
    shell/                   navigation shell (rail / bottom bar)
    clients/                 client + contact list / detail / form
    projects/                project list, detail, stage board, modules
    queries/                 quick-log, list, detail (status machine), comments, attachments
    dashboards/              the 7 dashboards, each over one SQL view
    modules/                 module master reference data
supabase/
  config.toml                CLI config (isolated project)
  migrations/                ordered schema: enums, tables, audit, RLS, SLA, fns, views, triggers
  seed.sql                   Phase 0 reference data (modules, SLA, stage template, holidays)
  functions/
    notify-whatsapp/         Phase 4 — drains notification_outbox to the Meta Cloud API
    sync-financials/         Phase 5 — Oracle read-only view → client_financial_snapshot
docs/DECISIONS.md            the five "come back to me with" answers
test/                        Dart tests
```

## Running the database

```bash
supabase start
supabase db reset          # applies migrations/ then seed.sql
```

## Running the app

The app ships with the **anon key only**. Pass config at run time — never commit it:

```bash
flutter pub get
flutter create .           # generates platform folders (android/ios/web/...) on first setup
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR-PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
```

For office screens: `flutter run -d chrome --dart-define=...`.

## Phases

All phases from the brief are implemented:

- **Phase 0 · Skeleton** — Supabase project, schema as checked-in migrations, RLS
  on every table, Supabase Auth, Flutter shell with login and routing.
- **Phase 1 · Registry** — client + contact + module + project + stage template +
  project stage; the stage board renders from `v_project_board`.
- **Phase 2 · Queries** — quick-log (<20s) screen, query list/detail, the status
  machine via `fn_transition_query`, the SLA clock with pause, comments, and
  attachments via Supabase Storage.
- **Phase 3 · Dashboards** — implementation board, stalled list, consultant load,
  query heatmap, root-cause mix, client 360 (+ churn), SLA board — each over one
  SQL view.
- **Phase 4 · Hardening** — audit trigger on every table, CSV/Excel export on the
  lists, WhatsApp notifications via the `notify-whatsapp` Edge Function + the
  `fn_scan_sla_breaches` outbox. (Offline queue is intentionally **not** built —
  the brief gates it behind a real need; add a Drift queue in front of Supabase
  if field capture proves essential.)
- **Phase 5 · ERP seam** — the `sync-financials` Edge Function (read-only Oracle
  view → `client_financial_snapshot`, all credentials server-side) and a
  `SnapshotFinancialProvider` that reads our own snapshot table.

### Isolation held throughout

The shipped financial provider is still the **stub** (constraint #5: "ship the
stub, do not implement a real one in this build"). The seam machinery exists and
is deployable, but the app only reads real figures when built with
`--dart-define=FINANCIAL_SEAM_LIVE=true`, and even then via our own Supabase
table — never Oracle. No Oracle package or ERP credential is anywhere in the
Flutter app.

> **Not yet verified against a live toolchain.** Flutter/Dart and the Supabase
> CLI are not installed in the environment this was authored in, so the Dart has
> not been compiled and the migrations have not been applied here. First local
> steps: `flutter pub get && flutter analyze`, then `supabase db reset`. Expect
> to fix a few small issues on first compile — treat this as a thorough first
> draft of the whole app, not a battle-tested build.

### Open decisions for @yashstar

Defaults are in place but flagged in [docs/DECISIONS.md](docs/DECISIONS.md):
which two query states pause the SLA clock, project-level vs per-module sign-off
gates, and the real holiday list.
