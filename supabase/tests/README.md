# Database tests

Developer smoke tests for the schema, business logic and RLS. They were run
against PostgreSQL 16 and all pass. They are plain `psql` scripts (not pgTAP),
each self-asserting via `assert` in DO blocks — a failed assertion aborts with a
clear message; a clean run ends with `ALL ... TESTS PASSED`.

## Against local Supabase (recommended)

`auth` and `storage` already exist, so skip the shim:

```bash
supabase start
supabase db reset            # applies migrations + seed.sql
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" -v ON_ERROR_STOP=1 -f supabase/tests/10_functional.sql
psql "$(supabase status -o env | grep DB_URL | cut -d= -f2-)" -v ON_ERROR_STOP=1 -f supabase/tests/20_rls.sql
```

Run against a freshly reset DB — the functional test inserts fixed rows
(`ACME01`, etc.) that would collide on a second run.

## Against a bare PostgreSQL (CI without Docker)

Apply the shim first; it creates the minimal `auth`/`storage` objects Supabase
normally provides (an `auth.uid()` backed by the `app.uid` GUC so the RLS test
can impersonate users):

```bash
createdb finsys
psql finsys -f supabase/tests/00_shims_for_bare_postgres.sql
for f in supabase/migrations/*.sql; do psql finsys -v ON_ERROR_STOP=1 -f "$f"; done
psql finsys -f supabase/seed.sql
psql finsys -v ON_ERROR_STOP=1 -f supabase/tests/10_functional.sql
psql finsys -v ON_ERROR_STOP=1 -f supabase/tests/20_rls.sql
```

## What they cover

**10_functional.sql**
- seed (9 modules, 4 SLA targets, 11 stages with 3 sign-off gates)
- business-hours calendar: `fn_business_minutes_between` (720 min across a
  Fri→Mon weekend) and `fn_add_business_minutes`
- `auth.users` → `app_user` provisioning trigger (name from metadata)
- `fn_apply_stage_template` materialises 11 stages; board derives current stage
- query SLA stamping on insert; `fn_transition_query` enforces the status
  machine (illegal transitions rejected), accumulates the SLA pause, and
  requires a root cause before Resolved/Closed
- `fn_recompute_health` writes score + breakdown
- all 9 dashboard views execute; `audit_log` is populated

**20_rls.sql** (impersonates users via the `authenticated`/`anon` roles)
- Viewer can read but cannot insert a client, and cannot escalate its own role
- Consultant can insert a client
- anon (no `app_user` row / no grant) sees nothing
