# 1. The problem and what we are building

## The client's idea in one sentence
An app for **serious hikers**: people who go far from towns, for many hours, often with no phone signal.

## Why "serious hikers" changes everything
A normal app can say "No internet, try again later". A hiking app cannot. The moment it matters most is the moment there is no signal.

| Normal app | Hiking app |
|---|---|
| Internet is almost always there | Internet is usually **not** there |
| Data lives on the server | Data must live on the **phone first** |
| A bug is annoying | A bug can leave someone lost or unreachable |
| Battery lasts a day | Battery must last **10+ hours of GPS** |
| A map is a web page | A map must be **downloaded before the trip** |

## Goals of this prototype
This is a small project to *learn and demonstrate* the hard parts, not to ship a product.

1. **Prove the core idea**: record a hike with no signal, lose nothing, sync later.
2. **Show good thinking**: documents, diagrams, use cases, and tests that explain *why*, not only *what*.
3. **Be honest**: say clearly what is built, what is only designed, and what is unknown.

## What is built vs. only designed

| Feature | Status |
|---|---|
| Record a hike (real GPS or built-in demo trail) | Built |
| Filter bad GPS fixes, count distance and climb | Built, tested |
| Save everything on the phone (SQLite) | Built |
| Upload later when signal returns (outbox + sync) | Built, tested |
| Edit conflicts between two phones | Built, tested |
| Trail drawing + elevation chart | Built |
| Server | **Fake** (in memory), behaves like a real one |
| Real offline map tiles | Designed only (doc 06) |
| Background tracking with the screen off | Designed only (doc 05) |
| Live sharing, SOS, weather | Designed only (doc 07) |
| Login, photos, search | Designed only (doc 03) |

## Success looks like
- Switch the network toggle off, record a whole hike, and see "1 waiting to upload".
- Switch it on, and watch that hike reach the server with nothing duplicated or lost.
- Explain every box in the architecture picture to a client in five minutes.
