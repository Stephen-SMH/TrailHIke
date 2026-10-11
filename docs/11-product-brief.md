# 11. Product brief: why serious hikers need this app

## Why a dedicated app
Komoot plans and navigates well, but serious hikers (multi-day, remote, mountain, desert) hit four gaps:

1. **No signal, no app.** Planning and social features stop working where the risk is highest.
2. **Weak safety.** Little live tracking, check-in or emergency flow.
3. **Stale conditions.** Closures, water sources, flooding, snow and heat change daily and live in forums and chat groups.
4. **Hard to find partners.** Solo hikers want a safe, verified way to meet others.

## User journeys

**1. Solo multi-day hiker**
1. Plans the route and downloads offline maps, water points and campsites.
2. Sets a safety plan: expected finish time plus two emergency contacts.
3. On trail, the phone logs the track in the background with battery-saver mode.
4. If a check-in is missed by X hours, contacts get an alert with the last known location.
5. After the hike, shares the track and adds trail condition reports.

**2. Group leader**
1. Creates a group trip and invites members.
2. Members see each other's positions on an offline map via Bluetooth or Wi-Fi when there is no signal.
3. An alert fires if someone falls N meters behind or leaves the route.

**3. Emergency**
1. Hiker presses SOS, or a fall is detected.
2. The app sends GPS coordinates by SMS or satellite when data is unavailable, and shares them with rescue services.
3. Opt-in nearby users (for example a doctor with a first-aid kit) are notified and one can accept.

**4. Finding a hiking partner**
1. Filters by pace, experience and date; profiles are verified and rated.
2. Meets in a group chat before the hike; location sharing is opt-in only.

**5. Trail reporter**
1. Posts "bridge washed out" or "spring is dry" with a photo pinned to the exact trail point.
2. Others confirm or dispute it; reports expire automatically.

## Features by priority
Safety and offline come first; social features come last because Komoot, Strava and AllTrails already cover them.

| Priority | Features |
|---|---|
| Must | Offline maps and routing, GPS tracking, SOS, check-in timer, trail condition reports |
| Should | Group live location, weather and flood alerts, elevation and ETA estimates, water and camp POIs |
| Could | Partner matching, social feed, achievements, photo sharing |
| Later | Mesh or satellite messaging, wearable integration, nearby-responder network |

## Peer-to-peer, social, or Grab-style matching
Only peer-to-peer messaging and an emergency-only responder network are worth building early. A general taxi-style dispatch is the wrong model.

| Option | Fit | Notes |
|---|---|---|
| Social (feed, follow, kudos) | Low priority | Already well served by Komoot, Strava, AllTrails |
| Peer-to-peer mesh | Useful offline | Bluetooth LE or Wi-Fi Direct (Bridgefy, Briar) or LoRa devices (Meshtastic); about 50-100 m per hop, so best for groups or busy trails |
| Grab-style "nearest accepts" | Emergencies only | Opt-in volunteer responders (like GoodSAM) when someone is hurt; rescue services stay primary. No payment or supply side exists for normal hikes |

## Routing and where Dijkstra fits
Dijkstra is only needed for routing and for ranking responders by real walking time. Use an existing engine rather than writing it.

Nearby matching has two steps:
1. Find candidates with a geospatial index (PostGIS, Redis GEO, H3 or geohash) inside a radius.
2. Rank them by travel time along the trail network. A person 500 m away across a ravine may be 3 hours away on foot, so this is a shortest-path problem.

For routing, production engines use A* or contraction hierarchies rather than plain Dijkstra. Edge weights should be walking time (Naismith's rule or Tobler's hiking function, including slope and trail difficulty). Self-host GraphHopper, Valhalla or BRouter on OpenStreetMap data; all support hiking profiles.

## Build vs buy: SaaS and BaaS
You can avoid writing routing or matching algorithms by renting them. A BaaS plus a routing API gets an MVP running without custom backend code. Pricing and limits change, so check each vendor before committing.

| Need | Buy / use | Notes |
|---|---|---|
| Auth, database, file storage, realtime | Firebase, Supabase, Appwrite | Supabase runs PostgreSQL with PostGIS, so geo queries ("within 2 km") work without custom code |
| Routing and directions | Mapbox, GraphHopper API, openrouteservice, Stadia | Hosted hiking and walking profiles; no algorithm to write |
| Maps and offline tiles | Mapbox, MapTiler, Stadia, MapLibre with OSM data | Offline packs supported in SDKs |
| Push notifications and SMS | FCM/APNs, OneSignal, Twilio | For check-in alerts and SOS fallback |
| Realtime group location | Firebase Realtime Database, Supabase Realtime, Ably, PubNub | Live position sharing for groups |
| Satellite SOS | Garmin inReach, iPhone Emergency SOS | Hardware or OS features, not something you build |
| Existing hiking data | Komoot, Outdooractive, Wikiloc, OSM trails | Check each API's terms before using their data |

Trade-off: cost per request grows with users, you depend on the vendor, and offline use is the weak point of most hosted services. The offline map and routing layer is the part worth owning (or self-hosting) later.

## Tech stack and MVP scope
The MVP is offline maps and routing, GPS tracking, a check-in safety timer, trail condition reports and group live location. Add partner matching and the responder network once there are users.

| Layer | Choice |
|---|---|
| Mobile | Flutter (this prototype) or React Native; MapLibre GL with offline tile packs; SQLite for the offline store, syncing when back online |
| Backend | Self-built: Node, Go or Python API with PostgreSQL/PostGIS, Redis, WebSockets or MQTT. Or BaaS: Supabase or Firebase |
| Map data | OpenStreetMap plus elevation from SRTM or Copernicus DEM; routing via GraphHopper, Valhalla or a hosted API |
| Safety | Accelerometer fall detection, server-side missed check-in scheduler, emergency contact flows, optional satellite SOS integration |
| Privacy | Location sharing opt-in, time-limited and auto-deleting; verified partner profiles |

The hardest engineering piece is reliable, battery-efficient background GPS on iOS and Android.
