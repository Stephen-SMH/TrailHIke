# 10. Roadmap and questions for the client

## Suggested phases

| Phase | Goal | Main work |
|---|---|---|
| **0. Prototype** *(this)* | Prove offline recording and sync | Done |
| **1. Solid recording** | Trustworthy on a real mountain | Background tracking, barometer, GPX import/export, field tests, battery measuring |
| **2. Real backend** | Accounts and backup | Login, API, Postgres + PostGIS, resumable uploads |
| **3. Maps** | The paid feature | MapLibre, offline packs, contours, trail overlays |
| **4. Discovery** | Find trails | Trail data, search, difficulty, reviews |
| **5. Safety** | Live position, check-in timer | Server-side alerts, privacy controls, legal review |
| **6. Wearables** | Serious-hiker expectations | Apple Watch, Wear OS, Garmin / BLE sensors |

Do **phase 1** before anything else. If recording is not trustworthy, nothing else matters.

## Questions to ask the client
**Users**
1. Day hikers, multi-day trekkers, or mountaineers? (changes safety needs a lot)
2. Which countries and regions? (map data, weather source, laws)
3. Social app (feeds, groups) or a personal tool?

**Product**
4. What is the money? Subscription for offline maps? One-off purchase?
5. Must it work with watches or satellite messengers?
6. Do users bring existing GPX files?

**Business and risk**
7. Does the app claim any safety function?
8. Who is liable if something fails? Has a lawyer looked at it?
9. Budget for map and tile costs, and for the team that maintains it?
10. Is there a deadline tied to a season?

## What I need to learn (priority order)
1. **Offline-first sync** (done in this prototype; practice with a real server)
2. **Background location** on iOS and Android (hardest platform work)
3. **PostGIS** basics (write the queries in doc 06 against real data)
4. **MapLibre and offline tile packs**
5. **Resumable uploads and background jobs**
6. **Privacy and safety design**

## One-line summary for the client
> "I will make the app work with no signal first, make sure your users never lose a hike, and add maps, sharing and safety on top of that foundation."
