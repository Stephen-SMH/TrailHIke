# 8. Cost and scale

*These are **thinking numbers**, built from clearly stated assumptions. Prices change, so always check current provider pricing before quoting a client.*

## Where the money goes
For this kind of app, usually in this order:
1. **Map tiles and bandwidth** (the biggest)
2. Storage for tracks and photos
3. Database and servers (small at first)
4. Push notifications, email, weather API
5. The people building it

## Back-of-envelope: tracks
Assumptions: 1 GPS fix every 5 s, a 10-hour hike, about 40 bytes per fix.

```
fixes per hike   = 10 h x 3600 s / 5 s        = 7,200
raw size         = 7,200 x 40 bytes           = ~290 KB
```

Scenario: **10,000 monthly users, 4 hikes each per month.**
```
new hikes per month = 10,000 x 4              = 40,000
new data per month  = 40,000 x 290 KB         = ~11.6 GB
after one year      = ~140 GB
```
At typical object-storage prices (roughly a couple of cents per GB-month), 140 GB costs a **few dollars a month**. Tracks are cheap. Photos are bigger: 3 photos x 3 MB x 40,000 = **360 GB per month**, so photos matter far more than GPS.

## Back-of-envelope: map tiles
Assumption (to be measured): one offline region of vector tiles is about 50 to 150 MB.

```
downloads per month = 10,000 users x 1 pack      = 10,000
traffic             = 10,000 x 100 MB            = ~1 TB / month
```
- At a typical big-cloud egress price (about 9 cents per GB): **~$90 / month**.
- On storage with **zero egress fees** (some providers offer this): close to **$0** for egress.
- A **per-request** map provider can cost much more at this volume. Compare before choosing.

If raster tiles were used, the same pack could be 10x bigger, so vector tiles pay off.

**Lesson:** the choice of *how to serve tiles* can change monthly cost by 10x. It is an early architecture decision, not a detail.

## Scaling behaviour
| Pressure | What happens | Plan |
|---|---|---|
| Weekend spikes (sunny Saturday) | Many uploads at once | Queue uploads, scale workers, cache reads |
| Sync stampede (a mountain village regains signal) | Many phones push together | Back-off with random jitter |
| Big uploads on weak signal | Failures midway | Resumable chunked uploads |
| Live sharing | Many tiny writes | Keep only the *latest* position per user in a fast store |
| Trail search | Heavy geo queries | PostGIS index, cache popular areas |

## Operating it
- **Crash reporting** (Crashlytics, Sentry).
- **Sync health:** how many outbox items are older than 24 h? That number shows silent failure.
- **Cost alerts** on bandwidth, so a viral post does not become a surprise bill.
- **Backups** of the database, tested by restoring.

## Cheapest sensible start
1. App + SQLite on the phone.
2. One small API with Postgres + PostGIS.
3. Object storage for GPX and photos.
4. Self-hosted PMTiles on zero-egress storage, or a provider free tier.
5. Add the rest only when users ask.
