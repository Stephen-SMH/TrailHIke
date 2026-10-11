# 12. Environments and deploying

Three environments, one codebase. The app is told which one to use at **build time**.

| | dev | staging | prod |
|---|---|---|---|
| Database | Local Docker (`supabase start`) | Supabase cloud project | Supabase cloud project |
| Config file | `env/dev.json` (committed; public local key) | `env/staging.json` (git-ignored) | `env/prod.json` (git-ignored) |
| Banner in app | "DEV build" | "STAGING: test data only" | none |
| Purpose | Daily work, tests | Rehearse every release with a few real phones | Real hikers |

With no config the app starts in **demo mode** (simulated hikers, no server).

## Daily work (dev)

```bash
scripts/dev_up.sh                                    # start local backend
flutter run -d chrome --dart-define-from-file=env/dev.json
scripts/test_all.sh                                  # analyze + all tests
npx supabase stop                                    # when done
```

Local ports are 5442x (API 54421, DB 54422) so they do not clash with other
Supabase projects on the same machine.

## The database (supabase/migrations)

All access goes through functions that check who you are. Rules enforced in SQL, tested by `supabase/tests/rls.test.mjs`:

- Nobody can read other people's positions. Nearby hikers are **snapped to a ~110 m grid**, first name only.
- An SOS shows its exact position only to signed-in people within 5 km who are currently sharing presence, and only while open.
- An SOS chat is readable and writable only by the victim and hikers who joined; it closes when the SOS is resolved.
- Max 3 SOS per user per hour. Messages cannot be sent as someone else.

Change the schema only by adding a **new** migration file. Never edit one that has been applied to staging or prod.

## First-time setup of staging and prod (needs your Supabase account)

Do this once per environment (run each step with that project's ref):

1. Create a project at supabase.com (enable the PostGIS extension: it is created by the first migration).
2. Authentication -> Sign In / Providers -> turn **on "Allow anonymous sign-ins"**.
3. Authentication -> Rate limits: set anonymous sign-ins per hour per IP to something sane (default 30).
4. `npx supabase login` then `npx supabase link --project-ref <ref>`
5. `npx supabase db push` applies the migrations.
6. Schedule `select public.cleanup();` hourly (Database -> Cron, or any scheduler with the service key). It removes stale presence rows and old incidents.
7. Copy `env/staging.example.json` to `env/staging.json` and fill in the project URL and publishable key (Project Settings -> API).
8. Run the rules test against it with a throwaway project first, never against prod: `API_URL=... ANON_KEY=... node supabase/tests/rls.test.mjs` (it creates test users).

## Release flow

1. Merge to main; CI runs analyze, unit/widget tests, the database rules and the real client test.
2. `supabase db push` to **staging**, then `scripts/build_web.sh staging` and upload `build/web` to the staging site.
3. Try it: two phones, SOS, help, chat. Check the numbers for your region.
4. Same two steps for **prod** (`db push` to prod first, then the prod web build).

`scripts/build_web.sh <env>` produces plain static files in `build/web`. Any static host works. Serve over **HTTPS**: browsers only allow location on HTTPS (localhost is fine for dev).

## Known limits of the web version

- Browsers cannot run in the background, so a closed tab shares no location and receives no SOS alerts. Real push alerts need the native app, or Web Push (not built).
- `sms:` and `tel:` links open the phone's own apps; on a desktop browser they do nothing useful.
- Location accuracy on desktop is rough (Wi-Fi/IP based).
