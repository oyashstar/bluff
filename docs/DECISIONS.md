# Decisions & "come back to me with"

This answers the five items the brief asks the engineer to return **before
writing any UI**, plus the modelling additions worth flagging. Everything here
is implemented in `supabase/migrations/` and `lib/`.

---

## 1. Proposed `stage_template` seed — Standard New Implementation

11 stages, 3 sign-off gates (matches the brief's lifecycle picture). Seeded in
`supabase/seed.sql`. Durations are starting estimates for an MSME corrugation/
packaging shop — tune them against your real history; they only drive the health
score's "days in stage vs template" signal, nothing hard.

| # | Stage | Sign-off? | Default days |
|---|-------|-----------|--------------|
| 1 | Kickoff & Scoping | — | 3 |
| 2 | Data Collection | — | 7 |
| 3 | Master Data Setup | — | 5 |
| 4 | Configuration | — | 10 |
| 5 | **Conference Room Pilot** | ✅ gate 1 | 3 |
| 6 | User Training | — | 5 |
| 7 | Data Migration | — | 4 |
| 8 | **User Acceptance Testing** | ✅ gate 2 | 7 |
| 9 | Go-Live | — | 2 |
| 10 | Hypercare | — | 14 |
| 11 | **Project Closure** | ✅ gate 3 | 2 |

Because the lifecycle is data (`stage_template` / `stage_template_item`), not an
enum, ModuleExpansion and VersionUpgrade get their own shorter templates later
with no deploy. `fn_apply_stage_template(project, template)` materialises the
`project_stage` rows.

**Open question for you:** should CRP/UAT/Closure sign-offs be *project-level*
(one gate for the whole project) or *per-module*? The schema supports both
(`project_stage.project_module_id` nullable). The seed creates project-level
stages; if Sales can go live and get signed off while Costing is still in UAT,
you want the gates per-module instead. Your call — you see the delivery reality.

---

## 2. RLS policy design — one line per table

RLS is **on for every table**; a table with no matching policy is deny-all,
which is the safe default. Threat model is "a Support user must not edit a
project", not tenant isolation (single tenant, 15–25 trusted users). Helpers:
`fn_my_role()`, `fn_has_role(...)`, `fn_is_internal()`, `fn_can_edit_delivery()`
(Admin/Manager/Consultant), `fn_can_edit_support()` (+ Support).

| Table | Read | Write |
|-------|------|-------|
| `app_user` | all internal | Admin; self may edit own name but not role |
| `client` | all internal | delivery editors |
| `client_contact` | all internal | delivery editors |
| `module_master` | all internal | Admin/Manager |
| `stage_template` | all internal | Admin/Manager |
| `stage_template_item` | all internal | Admin/Manager |
| `project` | all internal | delivery editors |
| `project_module` | all internal | delivery editors |
| `project_stage` | all internal | delivery editors |
| `signoff` | all internal | delivery editors |
| `touchpoint` | all internal | support editors |
| `query` | all internal | support editors |
| `query_comment` | all internal | support editors |
| `attachment` | all internal | support editors |
| `holiday` | all internal | Admin/Manager |
| `sla_target` | all internal | Admin/Manager |
| `audit_log` | all internal | **nobody** (trigger writes as SECURITY DEFINER) |
| `client_financial_snapshot` | all internal | **nobody client-side** (Edge Function via service role in Phase 5) |

Views use `security_invoker = true` so the querying user's RLS flows through.

**Phase 0 acceptance** ("RLS blocks a write their role should not allow"): sign
in as a `Viewer` or `Support` user and attempt to insert a `project` — it is
rejected by `project_write`.

**Open question:** do you want *row-level* ownership on writes (a Consultant may
edit only projects they own) or is *role-level* (any Consultant may edit any
project) fine for 15–25 people? I chose role-level — simpler, and with this team
size ownership checks mostly get in the way. Easy to tighten later.

---

## 3. Managed Supabase vs self-hosted

**Recommendation: start on managed Supabase.** The migrations, SDK and RLS are
byte-identical on self-hosted, so this is a reversible decision, not a fork.

- The data is low-sensitivity operational metadata (project stages, query text,
  consultant load) — **not** client financials or ERP data. The one place real
  financial data would appear is `client_financial_snapshot`, which is empty
  until Phase 5 and fed server-side.
- Managed removes ops (backups, upgrades, Postgres tuning) from a one-engineer
  experiment that changes weekly. That is the whole point of the stack choice.

**Self-host only if** a compliance or client-contract rule says this data must
stay on Finsys infrastructure. If so, self-host Supabase on an internal VM
*before Phase 1* (hard constraint #6) — same Postgres, same migrations, same
SDK. Nothing in this repo changes except `SUPABASE_URL` / `SUPABASE_ANON_KEY`.

**This needs your sign-off before Phase 1**, because once real client rows are
in, moving is a data migration rather than a config change.

---

## 4. Business-hours & holiday calendar

Implemented in `supabase/migrations/..._calendar_sla.sql`.

- **Working window:** Mon–Sat, 09:30–18:30 IST (`Asia/Kolkata`). Sunday off.
- **Holidays:** editable `holiday` table (full-day). Seeded with national
  holidays for the rest of 2026 + 2027 — **replace these with your actual office
  holiday list before go-live**; regional/festival days vary.
- **`fn_business_minutes_between(from, to)`** — working minutes between two
  instants, net of Sundays and holidays. Used for elapsed-vs-SLA and for folding
  paused spans into `sla_paused_minutes`.
- **`fn_add_business_minutes(from, n)`** — the deadline `n` business minutes
  ahead; used to stamp `sla_response_due` / `sla_resolution_due` at ticket
  creation (BEFORE INSERT trigger) and on a severity change.
- **SLA targets** live in the editable `sla_target` table (same philosophy as
  `stage_template`), seeded:

  | Severity | First response | Resolution |
  |----------|----------------|------------|
  | S1 production stopped | 30 min | 4 business hours |
  | S2 major, workaround | 2 h | 2 business days |
  | S3 minor/cosmetic | 1 business day | 5 business days |
  | S4 how-to | 1 business day | 5 business days |

- **The clock pauses** while a ticket is `AwaitingClient` or `AwaitingDev`.
  `fn_transition_query` records when the pause began and adds the business
  minutes elapsed to `sla_paused_minutes` on resume. Breach = business minutes
  since creation, minus paused, vs target.

**Phase 2 acceptance** ("verify the SLA pause with a ticket parked in
AwaitingClient across a weekend"): park a ticket Fri 17:00 → resume Mon 11:00;
paused minutes should count only Sat 09:30–18:30 (Sun excluded), ≈ 540.

**Confirm with me:** (a) is Saturday a full working day for support, or a
half-day? (b) your real holiday list. (c) are S3 and S4 genuinely the same SLA,
or should S4 be looser?

---

## 5. Things in the domain model worth a second look

Nothing in the brief looks *wrong*; these are the judgement calls I'd want you to
confirm, since you see the support reality daily.

1. **`AwaitingDev` also pauses the clock.** The brief's status machine has "2 of
   them pause the SLA clock". I read those as `AwaitingClient` **and**
   `AwaitingDev` — time waiting on our own dev queue arguably *shouldn't* stop
   the client's clock. If you only want `AwaitingClient` to pause, change the
   `v_paused_states` array in `fn_transition_query`. **Please confirm which two.**

2. **Severity vs SLA target coupling.** Changing a ticket's severity recomputes
   its due dates from `created_at` (not from the moment of change). That matches
   "the SLA was always this" thinking. If you'd rather re-baseline from the
   change moment, say so.

3. **Churn signal is in `v_client_360`** as `post_golive_queries` (and
   `last_touchpoint_at`). The brief's "flag clients whose query volume drops to
   zero after go-live" is best computed as a scheduled check, not a static view
   column — I've exposed the inputs now and can add a dedicated
   `v_silent_clients` view (projects in Hypercare/Closed with zero post-go-live
   queries in N days) once you confirm the N.

4. **Added column: `query.sla_paused_since`** (timestamptz, nullable). Not in
   your column list. It's pure bookkeeping — marks the start of the current
   pause so `fn_transition_query` can fold it into `sla_paused_minutes`. The
   alternative (reconstructing pause spans from `audit_log`) is more fragile.
   Flagging it because you said not to change the model without asking.

5. **Added column: `project.golive_revisions`** (int). The health score needs
   "planned go-live revised once / twice+", which is a count over time. Rather
   than scan `audit_log` on every recompute, I keep a running counter. The app
   increments it when `planned_golive` changes. If you'd rather derive it from
   the audit trail, that's a one-line change to `fn_recompute_health`.

6. **Reference tables added:** `holiday` and `sla_target` (both editable,
   RLS-guarded). The brief implies both; making them tables rather than
   hard-coded constants keeps them editable without a deploy, consistent with
   the `stage_template` decision. They are the only two tables not wired to the
   audit trigger (they have no `id` column and are low-churn Admin-only config);
   easy to add if you want their edits in `audit_log` too.

---

## Build order from here (unchanged from the brief)

1. Client list & detail → 2. Project list & stage board *(Phase 1 gate: 10 real
clients, board renders from `v_project_board`)* → 3. Quick-log query *(the
make-or-break <20s screen)* → 4. Query list/detail driving
`fn_transition_query` → 5. Dashboards, each over one view.

Do not start #3 until Phase 1 holds real data. No fake data beyond the Phase 0
reference seed.
