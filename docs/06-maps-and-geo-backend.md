# 6. Maps and the geographic backend

*Status: designed, not built. The prototype draws the track on a plain "paper map" with no tiles. SQL below is illustrative and was not run.*

## Where a map comes from
A map on your phone is lots of small square images or vector pieces called **tiles**, one set per zoom level.

| | Raster tiles | Vector tiles |
|---|---|---|
| What | Small pictures (PNG/JPG) | Shapes and labels, drawn by the phone |
| Size | Big | Much smaller |
| Style changes | Re-make all tiles | Change style on the phone |
| Offline pack | Very large | Practical |
| Verdict | Simple | **Best for a hiking app** |

### Where tiles can come from
- **OpenStreetMap** data: free, with trails, huts, and water sources. Good coverage in many regions, patchy in others.
- **Elevation data** (SRTM / Copernicus DEM): for contours and hillshade.
- **Providers:** Mapbox, MapTiler, Stadia (paid, easy) or **self-hosted PMTiles** (a single file, served from cheap storage, cheapest at scale).
- **Renderer in Flutter:** `maplibre` packages, which support offline regions.

## Offline map packs
1. The hiker picks an area on a map (a rectangle).
2. The app estimates the size ("86 MB") **before** downloading.
3. Download on Wi-Fi, with pause and resume.
4. Store in app storage, and let the user delete packs.
5. Tell the user when a pack is old.

Hard parts: storage limits, resumable downloads, cache eviction, and licences (check each provider's rules for offline use).

## PostGIS: the geographic database
PostgreSQL has an extension called **PostGIS** that understands shapes on the earth. It makes questions like "which trails are near me?" fast.

```sql
CREATE EXTENSION postgis;

CREATE TABLE trails (
  id          uuid PRIMARY KEY,
  name        text NOT NULL,
  difficulty  int,
  length_m    real,
  gain_m      real,
  geom        geography(LineString, 4326) NOT NULL
);
CREATE INDEX trails_geom_idx ON trails USING gist (geom);   -- makes spatial queries fast

-- Trails within 20 km of a point (lon, lat), nearest first
SELECT id, name,
       ST_Distance(geom, ST_MakePoint(98.487, 18.588)::geography) AS metres
FROM trails
WHERE ST_DWithin(geom, ST_MakePoint(98.487, 18.588)::geography, 20000)
ORDER BY metres
LIMIT 20;
```

Without the index, this would scan every trail. With it, a database with a million trails answers quickly.

### Other geo questions the backend will answer
- *Trails inside the visible map box* (a bounding-box query).
- *Total distance and climb of an uploaded track* (recomputed on the server, since phones differ).
- *Is this uploaded hike an existing trail?* (match a track to known trails).
- *Simplify for the map view* (`ST_Simplify`), so the list never ships thousands of points.

## Routing
"Plan a route from A to B along trails" needs a **routing graph** built from trail data. Open-source engines: GraphHopper, Valhalla, OSRM (check each for hiking profiles). Heavy to run, so it is usually **v2**, after recording and maps work.

## File formats you must know

| Format | Used for |
|---|---|
| **GPX** | The universal hike file. Every watch and app reads it |
| GeoJSON | Shapes in web and APIs |
| KML | Google Earth style |
| MBTiles / PMTiles | Map tile containers |

Plan GPX **import and export** early. Hikers will bring years of history from other apps.
