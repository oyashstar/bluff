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
lib/                         Flutter app
  main.dart                  entry; initialises Supabase with the anon key only
  src/core/env.dart          anon key + URL via --dart-define (no secrets committed)
  src/supabase/              the single Supabase client + auth providers
  src/auth/                  login screen + auth controller
  src/router/                go_router wired to auth state
  src/finance/               ClientFinancialProvider seam + v1 stub
  src/features/shell/        Phase 0 landing shell
supabase/
  config.toml                CLI config (isolated project)
  migrations/                ordered schema: enums, tables, audit, RLS, SLA, fns, views, triggers
  seed.sql                   Phase 0 reference data (modules, SLA, stage template, holidays)
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

## Where this build stops

This is the **Phase 0 skeleton + Phase 1 schema foundation**: the full data
model, RLS, audit, SLA calendar, dashboard views, business-logic functions, the
stage-template seed, and the app shell (login + routing + the financial seam).

It stops there on purpose. Per the brief, query management does not start until
Phase 1 holds real client data, and no fake data is seeded beyond Phase 0. The
build order for the UI screens, and the open questions for @yashstar, are in
[docs/DECISIONS.md](docs/DECISIONS.md).

> Not yet verified against a live toolchain: Flutter/Dart and the Supabase CLI
> are not installed in the environment this skeleton was authored in, so the
> migrations and Dart have not been compiled/applied here. First local step:
> `supabase db reset` and `flutter analyze`.
