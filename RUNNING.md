# Running Finsys Tracker

Two parts: a **Supabase backend** (Postgres + Auth + PostgREST + Storage) and
the **Flutter app**. Pick Option A (local, best for development) or Option B
(a hosted Supabase project).

## Prerequisites

- **Flutter** 3.35+ — https://docs.flutter.dev/get-started/install
  (`flutter doctor` should be green for your target: Chrome for web, Android
  Studio for Android, Xcode for iOS).
- For a **local** backend: **Docker** + the **Supabase CLI**
  (https://supabase.com/docs/guides/cli).

First time in a fresh clone, generate the platform folders (they are gitignored):

```bash
flutter pub get
flutter create .          # adds web/ android/ ios/ … without touching lib/
```

---

## Option A — Local backend (recommended for dev)

```bash
supabase start            # boots the full stack in Docker
supabase db reset         # applies supabase/migrations/* then supabase/seed.sql
supabase status           # prints the API URL and anon key you need below
```

`supabase status` prints something like:

```
API URL: http://127.0.0.1:54321
anon key: eyJhbGciOiJIUzI1Ni...
Studio URL: http://127.0.0.1:54323
```

**Create the first user** (self-signup is disabled on purpose). Open Studio
(the Studio URL) → **Authentication → Add user** → set an email + password and
tick "Auto Confirm User". The DB trigger creates a matching `app_user` as
**Viewer**. Promote yourself to Admin in Studio → **SQL Editor**:

```sql
update app_user set role = 'Admin' where email = 'you@finsys.test';
```

**Run the app** (web is easiest for the office screens):

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_ANON_KEY=<anon key from supabase status>
```

Sign in with the email/password you created.

> Android emulator can't see `127.0.0.1` (that's the phone). Use
> `--dart-define=SUPABASE_URL=http://10.0.2.2:54321`. A physical device uses
> your machine's LAN IP.

---

## Option B — Hosted Supabase project

Create a project at https://supabase.com, then from this repo:

```bash
supabase link --project-ref <your-project-ref>
supabase db push          # applies migrations to the hosted database
```

`db push` does **not** run `seed.sql`. Seed the reference data once via the
dashboard **SQL Editor** (paste the contents of `supabase/seed.sql`) or:

```bash
psql "<your connection string>" -f supabase/seed.sql
```

Create a user in the dashboard (**Authentication → Users → Add user**) and
promote to Admin in the SQL editor (same `update app_user …` as above). Grab the
**Project URL** and **anon key** from **Project Settings → API**, then:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon key>
```

---

## Building for release

```bash
flutter build web \
  --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
# output in build/web — serve it as static files
flutter build apk    # Android
flutter build ipa    # iOS (needs a Mac + signing)
```

## Optional: the ERP financial seam (Phases 4–5)

Everything above runs with the financial seam **stubbed** (outstanding shows
"not linked"). To enable it later:

1. Set the **Finsys ERP company code** in the app under **Settings** (Admin).
2. Deploy the Edge Functions and their secrets:
   ```bash
   supabase functions deploy sync-financials
   supabase functions deploy notify-whatsapp
   supabase secrets set ORACLE_BRIDGE_URL=... ORACLE_BRIDGE_TOKEN=... \
     WHATSAPP_TOKEN=... WHATSAPP_PHONE_ID=... NOTIFY_FALLBACK_NUMBER=...
   ```
3. Build the app with `--dart-define=FINANCIAL_SEAM_LIVE=true`.

The Flutter app still never talks to Oracle — only the `sync-financials`
function does, server-side.

## Troubleshooting

- **"SUPABASE_URL and SUPABASE_ANON_KEY are not set"** — you didn't pass the two
  `--dart-define` flags.
- **Login fails / can't sign up** — self-signup is disabled; add the user in
  Studio/dashboard first.
- **Empty screens** — expected until you enter real clients (Phase 1); no fake
  data is seeded beyond the Phase 0 reference rows.
- **Verify the backend without the app** — see `supabase/tests/README.md`.
