# 9. Testing and results

## What was checked

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| Unit tests (`flutter test`) | **18 passing** |
| macOS debug build | Builds |
| Screens rendered to PNG from the real widgets | Done (pictures in the README) |
| Figures generated from the real code | Done (doc 05) |

## What each test proves

### Geo maths (`test/geo_test.dart`)
| Test | Proves |
|---|---|
| One degree of latitude is about 111 km | Distance formula is right |
| Demo route is a few km with real climbing | The test trail is sane |
| Ignores GPS jitter while standing still | No fake climbing |
| Counts a real climb, not the way down | Gain is one-directional |
| Removes points on a straight line | Simplify drops what it should |
| Keeps the corner of an L-shape | Simplify keeps what it must |
| Long tracks shrink without changing length | Simplify is safe |
| Pace needs some distance first | No nonsense at the start |

### Recorder (`test/recorder_test.dart`)
- Rejects poor-accuracy fixes and tiny moves.
- Saves in batches, and `flush` saves the rest.

### Sync (`test/sync_test.dart`)
| Test | Scenario |
|---|---|
| Online save reaches server | The happy path |
| Offline: nothing lost, uploads later | The core promise |
| Retry does not duplicate | Lost "OK" |
| Many offline edits become one upload | Bandwidth saving |
| Newer edit wins (server side) | Conflict |
| My newer unsent edit survives a pull | Conflict (other direction) |
| Pull only what changed | Cursor |
| Delete syncs and hides | Soft delete |

## A bug the tests found
The first climb algorithm only used a threshold. A "standing still" test with ±1.5 m jitter reported **72 m of climb**, because the noise was as large as the threshold. The fix (smooth first) is explained in doc 05. This is exactly why tests exist.

## What was **not** tested (the honest list)
- **Real GPS in the field.** Only the simulator and unit tests. Real chips behave worse.
- **Android and iOS builds.** Only macOS was built.
- **Background tracking.** Not implemented.
- **Battery use.** Not measured.
- **A real server and real network failures.** `FakeServer` only.
- **Long hikes** (tens of thousands of points) for database and drawing speed.
- **Two real phones.** The conflict case is simulated.

## How to repeat the results
```bash
flutter analyze
flutter test
flutter test tool/screenshots_test.dart --update-goldens   # redraw screenshots
flutter test tool/make_figures_test.dart                   # redraw doc 05 figures
python3 tool/make_diagrams.py                              # redraw diagrams
```
