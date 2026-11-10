# Handoff — Finsys Internal Tracker

Pick-up notes for continuing this work on another machine or in a fresh (local)
Claude Code session. Nothing here contains secrets or live customer data —
those were delivered separately as files; see "Generated artifacts" below.

## What this is

A standalone internal tool (Flutter + Supabase) that tracks ERP **implementation
projects** and **client queries** for Finsys, with dashboards and an **Outstanding
(AR)** view fed from the Finsys ERP. Built per `docs/` design brief; experimental,
single-tenant, optimise for speed of change.

- **Branch:** `claude/cool-clarke-l8osb2` on `github.com/oyashstar/bluff`.
- **Status:** app complete through all phases; `flutter analyze` clean,
  `flutter test` green, `flutter build web` compiles; migrations verified on
  Postgres 16 and on a full local Supabase stack with seeded data.

## Read these first

| File | What it covers |
|------|----------------|
| `README.md` | Stack, layout, phases, isolation rules |
| `RUNNING.md` | How to run the backend + app (local Docker, or hosted) |
| `docs/USAGE.md` | How to use the app day to day (roles, workflows) |
| `docs/DECISIONS.md` | The 5 design answers + open decisions |
| `supabase/tests/` | DB + RLS smoke tests |

## Hosted Supabase (your project)

Project ref `qytgovgjxiiywqfpbfmd` (region/URL in your dashboard). From a fresh
clone the DB is empty; set it up:

1. **Schema + seed** — run `finsys_hosted_setup.sql` in the SQL Editor (it is the
   concatenation of `supabase/migrations/*` + `supabase/seed.sql`; regenerate any
   time with:
   `for f in supabase/migrations/*.sql; do cat "$f"; done > out.sql; cat supabase/seed.sql >> out.sql`).
2. **Create your login** — Authentication → Users → Add user (Auto Confirm).
3. **Make yourself Admin** — `update app_user set role='Admin' where email='…';`
4. **Run the app** with the **anon / publishable** key (never the secret key):
   ```bash
   flutter run -d chrome \
     --dart-define=SUPABASE_URL=https://qytgovgjxiiywqfpbfmd.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=sb_publishable_... \
     --dart-define=FINANCIAL_SEAM_LIVE=true
   ```
   `FINANCIAL_SEAM_LIVE=true` makes the client-detail card read outstanding too
   (the Outstanding dashboard shows it regardless).

> First time in a clone: `flutter pub get && flutter create .` (generates the
> gitignored platform folders), then the run command above.

## ERP → Outstanding integration

The Finsys ERP (company **MLGI**) is reachable in claude.ai via the
`finsys_MLGI` connector (read-only SQL). Key facts:

- **Customers = account group `16`** (sundry debtors) in the ERP.
- **`RECDATAW_ALL`** = bill-wise outstanding (`ACODE`, `INVDATE`, `NET` where
  NET>0 means the customer owes us). **`FAMST`** = accounts master (`ACODE`,
  `ANAME`, address, `GST_NO`, `EMAIL`, `MOBILE`). Join on `TRIM(ACODE)`.
- **Client-wise outstanding + 90+ aging** (the query behind everything):
  ```sql
  SELECT TRIM(r.ACODE) AS erp_client_code,
         ROUND(SUM(r.NET)) AS total_outstanding,
         ROUND(SUM(CASE WHEN r.INVDATE < SYSDATE-90 THEN r.NET ELSE 0 END)) AS overdue_90_plus
  FROM RECDATAW_ALL r
  WHERE r.GRP = '16'
  GROUP BY TRIM(r.ACODE)
  HAVING SUM(r.NET) > 0
  ```
  Balances are open bill amounts, **tax-inclusive**, net of receipts.
- Each tracker `client.erp_client_code` = the ERP `ACODE` (e.g. `16Y006`); that
  is the join key. Settings → ERP company code = `MLGI`.

### One-time load (done via the connector)
`finsys_clients_load.sql` (delivered separately — holds real names/figures, so
it is **not** committed) upserts the top debtors into `client` +
`client_financial_snapshot`. Re-pull more/other clients any time by re-running
the query above through the connector and regenerating that SQL.

### Ongoing automatic sync (the C# task)
The Phase-5 seam keeps outstanding fresh without manual loads, with Oracle
credentials staying on the internal network (isolation rule):

1. **`supabase/functions/sync-financials/index.ts`** (already in the repo) calls
   `ORACLE_BRIDGE_URL` and upserts `client_financial_snapshot`, matching by
   `erp_client_code`, scoped to the company code in `app_setting`.
2. **The bridge = your `finsysUltraApi` (VS 2022) C# API.** Add a read-only
   endpoint shaped like your existing controllers (copy `SalesOrderController`,
   **no DB-layer changes**):
   - `GET /outstanding?company_code=MLGI` →
     `[{ "erp_client_code":"16Y006", "total_outstanding":1153000, "overdue_90_plus":120000 }, ...]`
   - backed by the GRP-16 query above.
3. Deploy the function, set its secrets
   (`supabase secrets set ORACLE_BRIDGE_URL=... ORACLE_BRIDGE_TOKEN=...`), and
   schedule it (pg_cron or an external scheduler).

The Flutter app and Supabase never talk to Oracle — only the C# bridge does.

## Open next steps

- [ ] Build `OutstandingController` in `finsysUltraApi` (do this in a **local**
      Claude Code session — it can read the C# source this cloud session cannot).
- [ ] Deploy `sync-financials`, point `ORACLE_BRIDGE_URL` at the bridge, schedule it.
- [ ] Enter real implementation **projects** for the loaded clients (Phase 1).
- [ ] Confirm the open design decisions in `docs/DECISIONS.md` (which 2 query
      states pause the SLA clock; project-level vs per-module sign-off gates;
      the real office holiday list in the `holiday` table).

## Security notes

- The app ships the **anon / publishable** key only. The **service-role /
  secret** key must never go in the client or the repo.
- **Rotate** the secret key if it was ever pasted into a terminal/chat
  (Dashboard → Project Settings → API → roll `service_role`).
- Oracle/ERP credentials live only in the C# bridge (internal network), never in
  Supabase or the Flutter app.

## Generated artifacts (delivered as files, not in the repo)

- `finsys_hosted_setup.sql` — migrations + seed, for the SQL Editor.
- `finsys_clients_load.sql` — the real top-client + outstanding load.
- Screenshots of the running app.

Regenerate the first two from the repo + the ERP query above at any time.
