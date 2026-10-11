# Glossary

| Word | Plain meaning |
|---|---|
| **Offline-first** | The app works fully with no internet; the network is a bonus |
| **Local database** | The phone's own storage of hikes and points |
| **Outbox** | The list of changes waiting to be sent to the server |
| **Sync** | Making the phone and the server agree |
| **Push / Pull** | Send my changes / ask for theirs |
| **Cursor** | A bookmark: "I have everything up to change #12" |
| **Idempotent** | Doing it twice has the same effect as once |
| **Conflict** | Two devices changed the same thing |
| **Last-write-wins (LWW)** | The newest edit is kept |
| **Append-only** | Data that is only added, never changed, so it cannot conflict |
| **GPS fix** | One position reading from the chip |
| **Accuracy** | How wrong a fix might be, in metres |
| **Elevation gain** | Total climbing, not counting descent |
| **Hysteresis** | Ignoring small changes until they pass a threshold |
| **Simplify (Douglas-Peucker)** | Remove points that do not change the shape |
| **GPX** | The standard file format for tracks |
| **Tile** | One small square of a map |
| **Vector / raster tiles** | Shapes drawn by the phone / ready-made pictures |
| **PMTiles / MBTiles** | A single file that holds a whole map |
| **PostGIS** | The geography add-on for the PostgreSQL database |
| **Egress** | Data leaving a cloud provider (often billed) |
| **Foreground service** | An Android notification that lets the app keep running |
