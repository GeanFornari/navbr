# CLAUDE.md

## User Profile
- **Role**: Administrator, Aviation Professional
- **Dev Experience**: 6 months (newbie)
- **Language**: English (intermediate), Portuguese (native)

## Code Style
- Formatting: `dart format`
- Fix all lint errors before committing

## UI Constraints

**Never use `AppBar`.** Use custom headers (Stack/Container/SafeArea). All existing ones are pending replacement — do not add new ones.

**Always use `AppColors`.** Never hardcode `Color(0x...)`, `Colors.white`, etc. Add missing colors to `AppColors` first.

**Always wrap screen content in `SafeArea`.** Full-screen map screens: apply `SafeArea` per overlay widget (not the whole screen).

## Commands
```bash
flutter run
flutter analyze
flutter test
flutter test test/geotiff_parser_test.dart
flutter pub get
flutter pub upgrade --major-versions
```

## Project
**navbr** — Flutter aeronautical Moving Map for DECEA charts (Brazil). Riverpod state management, georeferenced rendering (Lat/Lon → XY).

## Architecture

### Navigation Shell
`MainScreen`: 5-tab `BottomNavigationBar` + `IndexedStack` + per-tab `Navigator` keys. Tab 1 = Map/Nav (primary). Tabs 0, 3, 4 = stubs.

### State: ChartSettingsProvider
`ChangeNotifier` + `SharedPreferences`. Holds WAC/IAC paths, bounding boxes, IAC opacity/visibility. Call `refreshCharts()` before navigating to map tab.

### Chart Types

**WAC (GeoTIFF)** ~170MB raster. `GeoTiffParser` manually scans IFD binary:
- Tags 33922+33550 → origin+scale → bbox; Tag 34264 → affine fallback
- Rendered via `FileImage` → `OverlayImageLayer`

**IAC (GeoPDF)** PDF with OGC geo metadata. `GeoPdfParser` regex-scans binary for `/GPTS` (Lat/Lon) and `/LPTS` (0–1 page-fraction offsets). Rendered to PNG at 3× via `pdfx`, cached to documents dir. `/LPTS` offsets not yet applied to crop overlay.

### Map Rendering
`flutter_map` + OSM tiles. Charts as `OverlayImageLayer`. Aircraft marker in `MarkerLayer(rotate: false)`.

**North Up**: rotation=0, icon rotates by bearing. **Track Up**: map rotates by `360−bearing`, icon at 0°.

**NaN guard**: GPS duplicates → `NaN` bearing. Always check `bearing.isNaN` before use.

**MapController guard**: `_isMapReady` flag (set in `onMapReady`) — never call `move/rotate` before map is ready.

### GPS
`GpsService` (real, via geolocator) / `FakeGpsService` (SDCO→SBBU sim, 800m/500ms). Swap at call site in `initState`.

### API & Downloads
`AiswebApiService`: `https://aisweb.decea.mil.br/api/` (XML) — credentials from `.env`.

`DownloadService` auto-fixes: `&amp;`→`&`, `.gov.br`→`.mil.br`.

Dependency policy: latest versions always; use `dependency_overrides` for conflicts.

## Technical Debt
- GeoTIFF fully loaded into RAM — server should pre-extract bbox to sidecar JSON.
- IAC `/LPTS` offsets read but not applied — overlay aligns from full A4, not chart bounds.
- Large GeoTIFFs → OOM on low-memory devices — fix: tile-based rendering (MBTiles/gdal2tiles).
