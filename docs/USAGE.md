# Using Finsys Tracker

A practical guide to running the tool day to day. It answers two questions
nobody at Finsys can answer today without phone calls: **where every client
implementation actually stands**, and **what each client has been asking for**.

See [RUNNING.md](../RUNNING.md) to start the backend and app.

---

## Who does what (roles)

Every login is one of five roles. The role decides what you can change; everyone
can **see** everything.

| Role | Typically | Can change |
|------|-----------|------------|
| **Admin** | Lead / owner | Everything, incl. users and Settings (ERP company code) |
| **Manager** | Delivery head | All projects, clients, queries; lifecycle templates |
| **Consultant** | Implementation lead | Clients, projects, stages, sign-offs, touchpoints, queries |
| **Support** | Helpdesk | Queries, comments, touchpoints (read-only on projects) |
| **Viewer** | Stakeholder | Nothing — read-only everywhere |

A new login starts as **Viewer** and sees nothing meaningful until an Admin
promotes it. Promote in Studio/SQL: `update app_user set role='…' where email='…'`.

---

## The three everyday workflows

### 1. Support — log and work a client query

The make-or-break flow. A client calls/WhatsApps a consultant; log it in under
20 seconds before it's forgotten.

1. **Quick log** (nav rail → *Quick log*, or the ⚡ button anywhere): pick the
   client (your recent clients float to the top), tap a **severity** (S1–S4),
   type **one line**, Submit. Module/channel are optional. That's it — a ticket
   number (`Q-000123`) is assigned and SLA due-dates are stamped automatically.
2. **Work it** from *Queries* → open the ticket. Use the action buttons to move
   it through the state machine: **Acknowledge → In progress → (Awaiting
   client / Awaiting dev) → Resolved → Closed**. The app only offers legal moves;
   the database enforces them.
3. The **SLA clock pauses** automatically while a ticket is *Awaiting client* or
   *Awaiting dev* — you'll see a **Paused** chip. An overdue ticket shows a red
   **SLA breach** chip, one approaching shows **At risk**.
4. **Resolve/Close** forces a **root cause** (Bug / Training gap / Customisation
   / Data issue / Infrastructure / Expected behaviour / Enhancement). This one
   mandatory field is what makes the analytics worth having — see Root-cause mix.
5. Add **comments** (internal or client-visible) and **attachments** (screenshots
   of the error) on the ticket.

> Severity in the client's words: **S1** production stopped (can't invoice/
> dispatch/print a GRN), **S2** major function broken but a workaround exists,
> **S3** minor/cosmetic, **S4** how-to.

### 2. Consultant — drive an implementation

1. **Add the client** (*Clients* → New client): code, name, segment, city, and —
   when you have it — the **ERP client code** (the hand-typed key to the ERP).
   Add **contacts** (mark the primary and the champion) on the client's Contacts
   tab.
2. **Create a project** (client → Projects tab → New project): title, type, owner,
   pick the **Standard New Implementation** template and a planned go-live. The
   template materialises the **11-stage board** automatically.
3. Tick the **modules in scope** (Sales, Production, Costing, …) on the project.
4. **Advance the stage board**: each stage's ⋮ menu sets Pending → In progress →
   Done (or Blocked, with a reason). Starting/finishing a stage stamps the real
   dates. At a **sign-off gate** (CRP, UAT, Closure) press **Record sign-off**
   once the stage is Done — pick the client contact, date, remarks.
5. **Log touchpoints** (client → Touchpoints tab → Log touchpoint) for calls and
   visits. This is what keeps a project off the **Stalled** list and keeps its
   health honest — a project with no recent touchpoint, stage change or query is
   flagged as stalled.
6. Watch the **health score** (the coloured pill). Hover it to see the breakdown:
   stage overrun, open severity, staleness, sign-off pending, go-live revisions.

### 3. Manager / Admin — run the Monday review

Open **Dashboards** and go top to bottom:

- **Implementation board** — kanban by stage, card colour = health. Where is
  everything, and what's red?
- **Stalled** — projects with no activity for N days, worst first. *The single
  most actionable screen.* Assign follow-ups.
- **Consultant load** — open projects + tickets per person. Catch the consultant
  quietly carrying eleven go-lives.
- **SLA board** — breached / at-risk tickets grouped by assignee.
- **Query heatmap** — module × severity, last 30 days. Which module is bleeding?
- **Root-cause mix** — if *Training gap* dominates, the fix is documentation, not
  code.
- **Client 360** — one row per client; the **Silent (churn risk)** tab flags live
  clients who've gone quiet (usually they reverted to Excel).
- **Outstanding** — client AR once the ERP seam is on (below).

Every list has an **Export** button (⬇) that gives you CSV to paste into Excel.

---

## The health score, explained

Each project scores 0–100; higher is healthier. Five signals deduct from 100:

| Signal | Weight | Goes red when… |
|--------|--------|----------------|
| Days in current stage vs template | 25 | over by 100% |
| Open S1/S2 queries | 25 | any open S1, or 3+ open S2 |
| Days since last touchpoint | 20 | 45+ days |
| Sign-off pending on a done gate | 15 | 30+ days |
| Planned go-live revised | 15 | twice or more |

It recomputes nightly and whenever you change a stage, log a touchpoint, resolve
a query, or record a sign-off — so the number always reflects what just happened.
The colour: **green ≥ 75**, **amber 50–74**, **red < 50**.

---

## Outstanding & the Finsys ERP company code

Outstanding (AR) comes from your Finsys ERP, not from this tool. To light it up:

1. **Settings** (Admin) → set the **Finsys ERP company code**. The ERP is
   multi-company, so this picks *which company's* receivables to read. Each
   client is matched by its own **ERP client code** (on the client record);
   clients without one show as **not linked**.
2. Deploy the `sync-financials` Edge Function (see RUNNING.md). It reads a
   read-only Oracle view for that company code and writes snapshots into the
   tracker. The Flutter app never touches Oracle — only that server-side function
   does.
3. Build with `--dart-define=FINANCIAL_SEAM_LIVE=true`. Outstanding then appears
   on the **Outstanding** dashboard, each **Client 360** row, and the client
   detail page — with overdue-90 highlighted.

Until then everything else works fully; Outstanding simply reads "not linked".

---

## A sensible first week

1. **Day 1** — Admin creates the team's logins and sets roles; set the company
   name in Settings.
2. **Days 1–2** — Consultants enter the ~10–15 live implementations as clients +
   projects, apply the template, set each project's real current stage.
3. **From day 3** — Support logs *every* incoming query here instead of WhatsApp.
   A week of real queries is what makes the heatmap and root-cause mix useful.
4. **Each Monday** — run the review off the dashboards.

Don't bulk-import history or seed fake data — the tool earns trust fastest when
every row is real.

---

## Keyboard / navigation notes

- The left **nav rail** (wide screens) / bottom bar (phones): Overview, Clients,
  Projects, Quick log, Queries, Dashboards.
- **Search** (🔍 on Overview) finds clients, projects and queries by name/code/
  ticket.
- **Theme**: the ◐ menu on Overview, or Settings → Appearance (System/Light/Dark).
