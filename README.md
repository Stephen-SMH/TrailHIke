# TrailMark

A safety network for hikers. It does **not** record hikes. It does three things:

1. **SOS.** One button alerts hikers within 5 km and texts your own emergency contacts your position.
2. **Nearby hikers.** Opt in while hiking so others close by can find you if you need help (or you them). Only first name and rounded distance are shown, never an exact position.
3. **Nearest help.** Police, ranger stations, hospitals, fire and mountain rescue near you (OpenStreetMap data, cached for offline), with call and directions buttons, plus your country's emergency numbers.

Each SOS has its own chat so the hiker and the people coming to help can talk.

## Status (honest)

| Part | State |
|---|---|
| SOS, nearby hikers, per-SOS chat, help stations, emergency numbers | Built; tested against both an in-memory server and a **real local Supabase** |
| Database rules (privacy, range, chat access, SOS rate limit) | Built and tested (`supabase/tests/rls.test.mjs`) |
| **dev** environment | Working (local Docker) |
| **staging** and **prod** | Config and migrations ready; **cloud projects not created or deployed yet** |
| Web app (mobile-first) | Builds and runs; not hosted anywhere yet |
| SOS with no signal | Texts your contacts at once; alerts nearby hikers when signal returns |
| Push alerts when the app is closed | **Not built.** Today alerts arrive only while the app is open |
| Hiker-to-hiker without signal (Bluetooth/mesh) | **Not built** |
| Rescue services | The app **never** contacts them. It shows numbers and call buttons; you call. |

Never rely on this app alone in an emergency.

## Run

```bash
flutter pub get
scripts/dev_up.sh                                     # local backend (Docker)
flutter run -d chrome --dart-define-from-file=env/dev.json
scripts/test_all.sh                                   # analyze + all tests
scripts/build_web.sh dev|staging|prod                 # static site in build/web
```

Without `--dart-define-from-file` the app runs in **demo mode** with simulated hikers.
Environments, first-time cloud setup and the release flow: [docs/12-environments-and-deploy.md](docs/12-environments-and-deploy.md).

## Code map

```
lib/
  main.dart                  start-up; picks real or demo server
  config.dart                dev / staging / prod settings
  app_state.dart             all app logic the screens use
  core/                      models, distance maths, emergency numbers
  services/
    backend.dart             what the server must do (interface)
    fake_backend.dart        in-memory server for demo mode and tests
    supabase_backend.dart    the real server
    station_finder.dart      OpenStreetMap lookup of help stations
    location_source.dart     GPS
    sos_message.dart         SOS text + phone actions (call, SMS, directions)
  ui/                        Help, Nearby, Me tabs and the SOS chat
```

## Older documents

`docs/01`-`docs/10` were written for the earlier hike-recording prototype and are **out of date**. `docs/11-product-brief.md` is the current direction.

Top level also has `supabase/` (migrations, config, database tests), `env/` (per-environment settings), `scripts/` and `web/`.
