# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## User Profile

- **User Role**: Administrator
- **Knowledge**: Aviation Professional
- **Development Experience**: 6 months, Newbie
- **Language**: 
    - English: Intermediate
    - Portuguese: Native


## Code Style
- **Formatting**: Use `dart format` (not `clang_format`)
- **Linting**: Fix all lint errors before committing

## UI Constraints

**Never use `AppBar`.** All existing `AppBar`s in the codebase are pending replacement with a custom solution. Do not add new ones under any circumstances.

**Always use `AppColors` for every color value.** Never hardcode `Color(0x...)`, `Colors.white`, `Colors.black`, or any literal color outside of `AppColors`. If a needed color does not exist in `AppColors`, add it there first, then reference it.

**Always wrap screen content in `SafeArea`.** Every screen must account for notches and home indicators. For full-screen map screens where the map intentionally extends edge-to-edge, apply `SafeArea` individually to each overlay widget (top bar, bottom strip) rather than the whole screen.

## Commands

```bash
# Run the app
flutter run

# Analyze (lint)
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/geotiff_parser_test.dart

# Get/upgrade dependencies
flutter pub get
flutter pub upgrade --major-versions
```

## Project Purpose

This is **navbr** — a full-fledged standalone Flutter application for aeronautical Moving Map navigation using charts from DECEA (Brazil's Department of Airspace Control). The architecture is continuously evolving, utilizing modern Flutter state management (Riverpod) and focusing on high-performance georeferenced rendering (Lat/Lon → XY).

## Architecture

### Navigation Shell
`MainScreen` wraps the entire app in a 5-tab `BottomNavigationBar` with `IndexedStack` + per-tab `Navigator` keys to preserve state. The app starts on tab 2 (Cartas). Tab 1 (Map/Nav) is the primary navigation screen. Tabs 0, 3, and 4 are placeholder stubs.

### State: ChartSettingsProvider
A single `ChangeNotifier` (Provider) backed by `SharedPreferences` holds all chart state:
- Paths to the downloaded WAC `.tif` and IAC `.pdf` on disk
- Bounding boxes (`north/south/east/west`) for both charts
- IAC opacity and visibility toggles

`refreshCharts()` must be called before navigating to the map tab so the provider re-reads persisted paths.

### Two Chart Types and Their Parsers

**WAC (GeoTIFF)** — World Aeronautical Chart, raster image (~170MB for SP).
- Downloaded from `geoaisweb.decea.mil.br/src/geotiffs/<NAME>.tif`
- `GeoTiffParser` does manual binary IFD scanning (no library support for geo tags):
  - Tag 33922 `ModelTiepointTag` + Tag 33550 `ModelPixelScaleTag` → origin + pixel scale → bounding box
  - Tag 34264 `ModelTransformationTag` → 4×4 affine matrix fallback
- Rendered directly via `FileImage` into `flutter_map`'s `OverlayImageLayer`

**IAC (GeoPDF)** — Instrument Approach Chart, PDF with embedded OGC geo metadata.
- Downloaded from the AISWEB XML API (`AiswebApiService`) via ICAO code lookup
- `GeoPdfParser` regex-scans the raw binary for `/GPTS` (Lat/Lon pairs) and `/LPTS` (0.0–1.0 page-fraction offsets)
- The PDF is rendered to PNG at 3× scale via `pdfx` before use; the PNG is cached to the documents directory
- **Important:** `/LPTS` values define where the geographic map sits within the A4 page (it's not full-bleed). Future precision work requires applying these offsets as a crop/offset to align the overlay exactly.

### Map Rendering (NavigationMapScreen / WacMapScreen / IacMapScreen)
`flutter_map` with OpenStreetMap tiles as base. Charts are laid as `OverlayImageLayer`. The aircraft marker lives in a `MarkerLayer(rotate: false)` — the layer itself never rotates, so the icon stays immune to map rotation.

**Orientation modes:**
- **North Up**: map rotation = `0`, icon rotates by `bearing` angle.
- **Track Up**: map rotates by `360 - bearing`, icon stays at angle `0`.

**NaN guard:** GPS duplicate coordinates yield `NaN` bearing from the distance matrix. Always check `bearing.isNaN` before applying it.

**MapController guard:** `_isMapReady` flag (set in `MapOptions.onMapReady`) prevents calling `_mapController.move/rotate` before `FlutterMap` is initialized.

### GPS
`GpsService` streams real device location via `geolocator`. `FakeGpsService` simulates a SDCO→SBBU flight route at 800m/tick (500ms) for simulator testing. Neither is currently hot-swappable at runtime; swap at call site in `initState`.

### API & Downloads
`AiswebApiService` calls `https://aisweb.decea.mil.br/api/` (XML response) with credentials from `.env` (`AISWEB_API_KEY`, `AISWEB_API_PASS`).

`DownloadService` handles HTTP downloads with two automatic fixes:
1. HTML-encoded `&amp;` → `&`
2. Deprecated `.gov.br` domain → `.mil.br`

### Dependency Policy
Always use latest package versions. Resolve version conflicts with `dependency_overrides` rather than downgrading.

## Technical Debt & Future Improvements
- WAC GeoTIFF is loaded fully into RAM for binary parsing. In production, a server/CLI should pre-extract the bounding box to a sidecar JSON.
- IAC `LPTS` offsets are read but not yet applied to crop the overlay — the chart currently aligns from the full A4 page bounds.
- Large GeoTIFFs on low-memory devices will OOM. The fix is tile-based rendering (MBTiles/XYZ via `gdal2tiles`).
