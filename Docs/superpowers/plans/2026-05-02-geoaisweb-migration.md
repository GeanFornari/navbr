# GeoAISWeb Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate route/area charts (ENRC, ARC, WAC, REA, REH, CCV_REA, CCV_REH) from AISWEB API PDFs to GeoTIFFs downloaded from `geoaisweb.decea.mil.br`, embedding bboxes in the manifest so the Flutter app can index charts without runtime parsing.

**Architecture:** The CLI discovers chart layers dynamically via WMS GetCapabilities (returns layer names + bboxes), downloads GeoTIFFs from `geoaisweb.decea.mil.br/src/geotiffs/<LAYER>.tif`, extracts bboxes from AD PDFs via `/GPTS` regex, and embeds all bboxes in `manifest.json`. The app reads `bbox` from the manifest instead of calling `GeoTiffParser`.

**Tech Stack:** Dart 3, `http`, `xml`, `crypto`, `path`, `yaml` (CLI); Flutter + Riverpod + Hive (app).

---

## File Map

### `charts_loader_cli` (repo at `/Users/gean/Projetos/charts_loader_cli`)

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/src/models/bounding_box.dart` | **Create** | `BoundingBox` value class used by CLI |
| `lib/src/models/chart.dart` | **Modify** | add `ccvRea`, `ccvReh`; remove `reul` |
| `lib/src/util/semaphore.dart` | **Create** | extract `Semaphore` from `chart_download_service.dart` |
| `lib/src/services/chart_download_service.dart` | **Modify** | import `Semaphore` from new util file |
| `lib/src/discovery/wms_discovery.dart` | **Create** | WMS GetCapabilities → `List<WmsChart>` |
| `lib/src/services/geopdf_extractor.dart` | **Create** | `/GPTS` regex extractor → `BoundingBox?` |
| `lib/src/services/geoaisweb_download_service.dart` | **Create** | streaming GeoTIFF downloader |
| `lib/src/packaging/package_manifest.dart` | **Modify** | `ManifestFile` gets optional `bbox`; `buildManifest` accepts `bboxByRelPath` |
| `lib/src/discovery/chart_discovery.dart` | **Modify** | add `ChecklistResult` + `parseChecklist` |
| `bin/charts_loader_cli.dart` | **Modify** | new `package` orchestration (WMS + AD + checklist diff) |
| `test/wms_discovery_test.dart` | **Create** | unit tests for WMS XML parsing |
| `test/geopdf_extractor_test.dart` | **Create** | unit tests for `/GPTS` extraction |
| `test/package_manifest_test.dart` | **Create** | unit tests for bbox in manifest JSON |
| `test/chart_discovery_test.dart` | **Create** | unit tests for `parseChecklist` |

### `navbr` (repo at `/Users/gean/Projetos/navbr`)

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/models/r2_manifest.dart` | **Modify** | add `BoundingBox` class + optional `bbox` on `R2ManifestFile` |
| `lib/providers/charts_download_provider.dart` | **Modify** | use manifest `bbox` for GeoTIFFs; `GeoPdfParser` fallback for PDFs |
| `lib/screens/charts_download_screen.dart` | **Modify** | add `ccvRea`/`ccvReh`; remove `reul`; fix ENRC split for new filenames |

---

## Task 1: `BoundingBox` model + update `chart.dart` (CLI)

**Files:**
- Create: `charts_loader_cli/lib/src/models/bounding_box.dart`
- Modify: `charts_loader_cli/lib/src/models/chart.dart`

- [ ] **Step 1: Create `bounding_box.dart`**

```dart
// lib/src/models/bounding_box.dart
class BoundingBox {
  const BoundingBox({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  Map<String, dynamic> toJson() => {
    'north': north,
    'south': south,
    'east': east,
    'west': west,
  };
}
```

- [ ] **Step 2: Update `chart.dart` enum and `parseTipo`**

Replace the `ChartTipo` enum and `parseTipo` switch with:

```dart
enum ChartTipo {
  // IFR
  adc, arc, gmc, iac, lc, pdc, sid, star, vac,
  // VFR
  cv, ccvRea, ccvReh, rea, reast, reh, wac,
  // ROTA
  enrc,
}
```

Replace the `parseTipo` switch body:

```dart
  return switch (upper) {
    'ADC'     => ChartTipo.adc,
    'ARC'     => ChartTipo.arc,
    'GMC'     => ChartTipo.gmc,
    'IAC'     => ChartTipo.iac,
    'LC'      => ChartTipo.lc,
    'PDC'     => ChartTipo.pdc,
    'SID'     => ChartTipo.sid,
    'STAR'    => ChartTipo.star,
    'VAC'     => ChartTipo.vac,
    'CV'      => ChartTipo.cv,
    'CCV_REA' => ChartTipo.ccvRea,
    'CCV_REH' => ChartTipo.ccvReh,
    'REA'     => ChartTipo.rea,
    'REAST'   => ChartTipo.reast,
    'REH'     => ChartTipo.reh,
    'WAC'     => ChartTipo.wac,
    'ENRC'    => ChartTipo.enrc,
    _         => null,
  };
```

- [ ] **Step 3: Run analyze**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart analyze
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add lib/src/models/bounding_box.dart lib/src/models/chart.dart
git commit -m "feat: add BoundingBox model; add ccvRea/ccvReh, remove reul from ChartTipo"
```

---

## Task 2: Extract `Semaphore` utility (CLI)

**Files:**
- Create: `charts_loader_cli/lib/src/util/semaphore.dart`
- Modify: `charts_loader_cli/lib/src/services/chart_download_service.dart`

- [ ] **Step 1: Create `semaphore.dart`**

```dart
// lib/src/util/semaphore.dart
import 'dart:async';

class Semaphore {
  Semaphore(this._max);

  final int _max;
  int _count = 0;
  final _queue = <Completer<void>>[];

  Future<void> acquire() async {
    if (_count < _max) {
      _count++;
      return;
    }
    final completer = Completer<void>();
    _queue.add(completer);
    await completer.future;
    _count++;
  }

  void release() {
    _count--;
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    }
  }
}
```

- [ ] **Step 2: Update `chart_download_service.dart`**

Add import at the top:
```dart
import '../util/semaphore.dart';
```

Delete the private `_Semaphore` class at the bottom of the file (the 20-line class starting with `class _Semaphore`).

Replace the two occurrences of `_Semaphore(concurrency)` with `Semaphore(concurrency)` in `downloadAll`.

- [ ] **Step 3: Run tests to confirm nothing broke**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test
```

Expected: all tests pass (or "No tests ran" if test directory is empty).

- [ ] **Step 4: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add lib/src/util/semaphore.dart lib/src/services/chart_download_service.dart
git commit -m "refactor: extract Semaphore to shared util"
```

---

## Task 3: `WmsDiscovery` (CLI)

**Files:**
- Create: `charts_loader_cli/lib/src/discovery/wms_discovery.dart`
- Create: `charts_loader_cli/test/wms_discovery_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/wms_discovery_test.dart
import 'package:test/test.dart';
import 'package:charts_loader_cli/src/discovery/wms_discovery.dart';

const _fixtureXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<WMT_MS_Capabilities version="1.1.0">
  <Capability>
    <Layer>
      <Layer queryable="1">
        <Name>ICA:ENRC_H1</Name>
        <LatLonBoundingBox minx="-59.155" miny="-34.350" maxx="-41.026" maxy="-23.745"/>
      </Layer>
      <Layer queryable="1">
        <Name>ICA:ARC_ACADEMIA</Name>
        <LatLonBoundingBox minx="-180" miny="-90" maxx="180" maxy="90"/>
      </Layer>
      <Layer queryable="1">
        <Name>ICA:WAC_3262_SAO_PAULO</Name>
        <LatLonBoundingBox minx="-49.5" miny="-25.2" maxx="-43.2" maxy="-21.8"/>
      </Layer>
      <Layer queryable="1">
        <Name>ICA:CCV_REA_XP2_SAO_PAULO</Name>
        <LatLonBoundingBox minx="-47.5" miny="-24.5" maxx="-45.8" maxy="-22.8"/>
      </Layer>
      <Layer queryable="1">
        <Name>ICA:UNKNOWN_LAYER</Name>
        <LatLonBoundingBox minx="-50" miny="-30" maxx="-40" maxy="-20"/>
      </Layer>
    </Layer>
  </Capability>
</WMT_MS_Capabilities>
''';

void main() {
  group('parseWmsCapabilities', () {
    test('parses ENRC_H1 with correct bbox and paths', () {
      final charts = parseWmsCapabilities(_fixtureXml);
      final enrc = charts.firstWhere((c) => c.layerName == 'ENRC_H1');
      expect(enrc.especie, 'rota');
      expect(enrc.tipoPath, 'enrc');
      expect(enrc.bbox.north, closeTo(-23.745, 0.001));
      expect(enrc.bbox.south, closeTo(-34.350, 0.001));
    });

    test('applies ARC_ACADEMIA bbox override', () {
      final charts = parseWmsCapabilities(_fixtureXml);
      final arc = charts.firstWhere((c) => c.layerName == 'ARC_ACADEMIA');
      expect(arc.bbox.north, closeTo(-20.523, 0.001));
      expect(arc.bbox.west, closeTo(-50.1397, 0.001));
    });

    test('parses WAC with correct especie/tipo', () {
      final charts = parseWmsCapabilities(_fixtureXml);
      final wac = charts.firstWhere((c) => c.layerName == 'WAC_3262_SAO_PAULO');
      expect(wac.especie, 'vfr');
      expect(wac.tipoPath, 'wac');
    });

    test('parses CCV_REA with correct especie/tipo', () {
      final charts = parseWmsCapabilities(_fixtureXml);
      final ccv = charts.firstWhere((c) => c.layerName == 'CCV_REA_XP2_SAO_PAULO');
      expect(ccv.especie, 'vfr');
      expect(ccv.tipoPath, 'ccvRea');
    });

    test('ignores unknown layer prefixes', () {
      final charts = parseWmsCapabilities(_fixtureXml);
      expect(charts.any((c) => c.layerName == 'UNKNOWN_LAYER'), isFalse);
    });

    test('ignores world bbox layers (not overridden)', () {
      // Any layer returning bbox > 170 degrees in lat span should be skipped
      // unless it has a hardcoded override
      const badXml = '''
        <WMT_MS_Capabilities version="1.1.0">
          <Capability><Layer>
            <Layer><Name>ICA:WAC_BAD</Name>
              <LatLonBoundingBox minx="-180" miny="-90" maxx="180" maxy="90"/>
            </Layer>
          </Layer></Capability>
        </WMT_MS_Capabilities>
      ''';
      final charts = parseWmsCapabilities(badXml);
      expect(charts, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/wms_discovery_test.dart
```

Expected: FAIL — `parseWmsCapabilities` not found.

- [ ] **Step 3: Create `wms_discovery.dart`**

```dart
// lib/src/discovery/wms_discovery.dart
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/bounding_box.dart';

class WmsChart {
  const WmsChart({
    required this.layerName,
    required this.especie,
    required this.tipoPath,
    required this.bbox,
  });

  final String layerName;
  final String especie;
  final String tipoPath;
  final BoundingBox bbox;

  String get filename => '$layerName.tif';
}

const _prefixToEspecieTipo = <String, (String, String)>{
  'CCV_REA_': ('vfr', 'ccvRea'),
  'CCV_REH_': ('vfr', 'ccvReh'),
  'ENRC_':    ('rota', 'enrc'),
  'ARC_':     ('ifr', 'arc'),
  'WAC_':     ('vfr', 'wac'),
  'REA_':     ('vfr', 'rea'),
  'REH_':     ('vfr', 'reh'),
};

const _bboxOverrides = <String, BoundingBox>{
  'ARC_ACADEMIA': BoundingBox(
    north: -20.5230,
    south: -23.0993,
    east: -46.0515,
    west: -50.1397,
  ),
};

const _capsUrl =
    'https://geoaisweb.decea.mil.br/geoserver/ICA/wms'
    '?service=WMS&version=1.1.0&request=GetCapabilities';

class WmsDiscovery {
  WmsDiscovery({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsClient;

  Future<List<WmsChart>> discover() async {
    final response = await _httpClient
        .get(Uri.parse(_capsUrl))
        .timeout(const Duration(minutes: 2));

    if (response.statusCode != HttpStatus.ok) {
      throw Exception('WMS GetCapabilities HTTP ${response.statusCode}');
    }

    return parseWmsCapabilities(response.body);
  }

  void close() {
    if (_ownsClient) _httpClient.close();
  }
}

List<WmsChart> parseWmsCapabilities(String xml) {
  final doc = XmlDocument.parse(xml);
  final charts = <WmsChart>[];

  for (final layer in doc.findAllElements('Layer')) {
    final nameEl = layer.findElements('Name').firstOrNull;
    if (nameEl == null) continue;

    final rawName = nameEl.innerText.trim();
    final layerName =
        rawName.contains(':') ? rawName.split(':').last : rawName;

    final match = _prefixToEspecieTipo.entries.firstWhere(
      (e) => layerName.startsWith(e.key),
      orElse: () => const MapEntry('', ('', '')),
    );
    if (match.value.$1.isEmpty) continue;

    final override = _bboxOverrides[layerName];
    if (override != null) {
      charts.add(WmsChart(
        layerName: layerName,
        especie: match.value.$1,
        tipoPath: match.value.$2,
        bbox: override,
      ));
      continue;
    }

    final bboxEl = layer.findElements('LatLonBoundingBox').firstOrNull;
    if (bboxEl == null) continue;

    final north = double.tryParse(bboxEl.getAttribute('maxy') ?? '') ?? 0;
    final south = double.tryParse(bboxEl.getAttribute('miny') ?? '') ?? 0;
    final east = double.tryParse(bboxEl.getAttribute('maxx') ?? '') ?? 0;
    final west = double.tryParse(bboxEl.getAttribute('minx') ?? '') ?? 0;

    if (north - south > 170) continue;

    charts.add(WmsChart(
      layerName: layerName,
      especie: match.value.$1,
      tipoPath: match.value.$2,
      bbox: BoundingBox(north: north, south: south, east: east, west: west),
    ));
  }

  return charts;
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/wms_discovery_test.dart
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add lib/src/discovery/wms_discovery.dart test/wms_discovery_test.dart
git commit -m "feat: add WmsDiscovery — parses WMS GetCapabilities into WmsChart list"
```

---

## Task 4: `GeoPdfExtractor` (CLI)

**Files:**
- Create: `charts_loader_cli/lib/src/services/geopdf_extractor.dart`
- Create: `charts_loader_cli/test/geopdf_extractor_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/geopdf_extractor_test.dart
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:charts_loader_cli/src/services/geopdf_extractor.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('geopdf_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('extracts bbox from /GPTS array in PDF bytes', () async {
    // Minimal fake PDF bytes containing a /GPTS entry
    // GPTS: [lat lon lat lon ...] pairs at corners (BL, BR, TR, TL order or similar)
    const gptsContent =
        '/GPTS [ -23.75 -46.68 -23.75 -46.22 -23.39 -46.22 -23.39 -46.68 ] '
        '/LPTS [ 0.1 0.1 0.9 0.1 0.9 0.9 0.1 0.9 ]';
    final file = File(p.join(tempDir.path, 'test.pdf'));
    await file.writeAsBytes(gptsContent.codeUnits);

    final bbox = await extractBboxFromPdf(file.path);
    expect(bbox, isNotNull);
    expect(bbox!.north, closeTo(-23.39, 0.001));
    expect(bbox.south, closeTo(-23.75, 0.001));
    expect(bbox.east, closeTo(-46.22, 0.001));
    expect(bbox.west, closeTo(-46.68, 0.001));
  });

  test('returns null when no /GPTS present', () async {
    final file = File(p.join(tempDir.path, 'no_gpts.pdf'));
    await file.writeAsBytes('%PDF-1.4 no geo data'.codeUnits);

    final bbox = await extractBboxFromPdf(file.path);
    expect(bbox, isNull);
  });

  test('returns null when /GPTS has fewer than 8 values', () async {
    const gptsContent = '/GPTS [ -23.75 -46.68 -23.75 ]';
    final file = File(p.join(tempDir.path, 'short_gpts.pdf'));
    await file.writeAsBytes(gptsContent.codeUnits);

    final bbox = await extractBboxFromPdf(file.path);
    expect(bbox, isNull);
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/geopdf_extractor_test.dart
```

Expected: FAIL — `extractBboxFromPdf` not found.

- [ ] **Step 3: Create `geopdf_extractor.dart`**

```dart
// lib/src/services/geopdf_extractor.dart
import 'dart:io';

import '../models/bounding_box.dart';

Future<BoundingBox?> extractBboxFromPdf(String filePath) async {
  try {
    final bytes = await File(filePath).readAsBytes();
    final content = String.fromCharCodes(bytes);

    final gptsMatch =
        RegExp(r'/GPTS\s*\[(.*?)\]', dotAll: true).firstMatch(content);
    if (gptsMatch == null) return null;

    final parts = gptsMatch
        .group(1)!
        .trim()
        .split(RegExp(r'\s+'))
        .map(double.tryParse)
        .whereType<double>()
        .toList();

    if (parts.length < 8) return null;

    var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (var i = 0; i < parts.length - 1; i += 2) {
      final lat = parts[i];
      final lon = parts[i + 1];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lon < minLon) minLon = lon;
      if (lon > maxLon) maxLon = lon;
    }

    return BoundingBox(
      north: maxLat,
      south: minLat,
      east: maxLon,
      west: minLon,
    );
  } catch (_) {
    return null;
  }
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/geopdf_extractor_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add lib/src/services/geopdf_extractor.dart test/geopdf_extractor_test.dart
git commit -m "feat: add GeoPdfExtractor — /GPTS regex bbox extraction from AD PDFs"
```

---

## Task 5: `GeoaiswWebDownloadService` (CLI)

**Files:**
- Create: `charts_loader_cli/lib/src/services/geoaisweb_download_service.dart`

No unit test (streaming I/O): verified in integration run (Task 7).

- [ ] **Step 1: Create `geoaisweb_download_service.dart`**

```dart
// lib/src/services/geoaisweb_download_service.dart
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../discovery/wms_discovery.dart';
import '../util/semaphore.dart';

class GeoTiffDownloadResult {
  const GeoTiffDownloadResult({
    required this.chart,
    required this.filePath,
    required this.bytes,
  });

  final WmsChart chart;
  final String filePath;
  final int bytes;
}

class GeoaiswWebDownloadService {
  GeoaiswWebDownloadService({
    http.Client? httpClient,
    this.concurrency = 4,
    this.verbose = false,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  static const _baseUrl = 'https://geoaisweb.decea.mil.br/src/geotiffs';

  final http.Client _httpClient;
  final bool _ownsClient;
  final int concurrency;
  final bool verbose;

  Future<({
    List<GeoTiffDownloadResult> succeeded,
    List<({WmsChart chart, Object error})> failed,
  })>
  downloadAll(List<WmsChart> charts, String outputDir) async {
    final succeeded = <GeoTiffDownloadResult>[];
    final failed = <({WmsChart chart, Object error})>[];
    final semaphore = Semaphore(concurrency);

    final futures = charts.map((chart) async {
      await semaphore.acquire();
      try {
        final result = await _downloadOne(chart, outputDir);
        succeeded.add(result);
        _log('OK  ${result.filePath} (${result.bytes ~/ 1024} KB)');
      } catch (e) {
        failed.add((chart: chart, error: e));
        _log('ERR ${chart.layerName}: $e');
      } finally {
        semaphore.release();
      }
    });

    await Future.wait(futures);
    return (succeeded: succeeded, failed: failed);
  }

  Future<GeoTiffDownloadResult> _downloadOne(
    WmsChart chart,
    String outputDir,
  ) async {
    final url = '$_baseUrl/${chart.layerName}.tif';
    final subdir = p.join(outputDir, chart.especie, chart.tipoPath);
    final filePath = p.join(subdir, chart.filename);

    await Directory(subdir).create(recursive: true);

    final request = http.Request('GET', Uri.parse(url));
    final streamedResponse = await _httpClient
        .send(request)
        .timeout(const Duration(minutes: 10));

    if (streamedResponse.statusCode != HttpStatus.ok) {
      throw HttpException(
        'HTTP ${streamedResponse.statusCode}',
        uri: Uri.parse(url),
      );
    }

    final sink = File(filePath).openWrite();
    int bytes = 0;
    await for (final chunk in streamedResponse.stream) {
      sink.add(chunk);
      bytes += chunk.length;
    }
    await sink.close();

    return GeoTiffDownloadResult(chart: chart, filePath: filePath, bytes: bytes);
  }

  void _log(String msg) {
    if (verbose) stdout.writeln('[geoaisweb] $msg');
  }

  void close() {
    if (_ownsClient) _httpClient.close();
  }
}
```

- [ ] **Step 2: Run analyze**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart analyze
```

Expected: no errors.

- [ ] **Step 3: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add lib/src/services/geoaisweb_download_service.dart
git commit -m "feat: add GeoaiswWebDownloadService — streaming GeoTIFF downloader"
```

---

## Task 6: Bbox in `package_manifest.dart` (CLI)

**Files:**
- Modify: `charts_loader_cli/lib/src/packaging/package_manifest.dart`
- Create: `charts_loader_cli/test/package_manifest_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/package_manifest_test.dart
import 'package:test/test.dart';
import 'package:charts_loader_cli/src/models/bounding_box.dart';
import 'package:charts_loader_cli/src/packaging/package_manifest.dart';

void main() {
  group('ManifestFile.toJson', () {
    test('includes bbox when present', () {
      const file = ManifestFile(
        path: 'rota/enrc/ENRC_H1.tif',
        size: 99640716,
        sha256: 'abc123',
        bbox: BoundingBox(
          north: -23.745,
          south: -34.350,
          east: -41.026,
          west: -59.155,
        ),
      );
      final json = file.toJson();
      expect(json['path'], 'rota/enrc/ENRC_H1.tif');
      expect(json['bbox'], {
        'north': -23.745,
        'south': -34.350,
        'east': -41.026,
        'west': -59.155,
      });
    });

    test('omits bbox key when null', () {
      const file = ManifestFile(
        path: 'ifr/iac/SBGR_IAC.pdf',
        size: 524288,
        sha256: 'def456',
      );
      final json = file.toJson();
      expect(json.containsKey('bbox'), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/package_manifest_test.dart
```

Expected: FAIL — `ManifestFile` has no `bbox` parameter.

- [ ] **Step 3: Update `package_manifest.dart`**

Add import at top:
```dart
import '../models/bounding_box.dart';
```

Replace `ManifestFile` class:
```dart
class ManifestFile {
  const ManifestFile({
    required this.path,
    required this.size,
    required this.sha256,
    this.bbox,
  });

  final String path;
  final int size;
  final String sha256;
  final BoundingBox? bbox;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'path': path,
      'size': size,
      'sha256': sha256,
    };
    if (bbox != null) json['bbox'] = bbox!.toJson();
    return json;
  }
}
```

Replace the `buildManifest` signature and body to accept `bboxByRelPath`:
```dart
Future<PackageManifest> buildManifest({
  required String packageDir,
  required String emenda,
  required int totalCharts,
  required int downloaded,
  required int failed,
  Map<String, BoundingBox?> bboxByRelPath = const {},
}) async {
  final version = _readVersion();
  final files = <ManifestFile>[];

  await for (final entity in Directory(packageDir).list(recursive: true)) {
    if (entity is! File) continue;
    final bytes = await entity.readAsBytes();
    final relPath = p
        .relative(entity.path, from: packageDir)
        .replaceAll('\\', '/');
    files.add(ManifestFile(
      path: relPath,
      size: bytes.length,
      sha256: sha256.convert(bytes).toString(),
      bbox: bboxByRelPath[relPath],
    ));
  }

  files.sort((a, b) => a.path.compareTo(b.path));

  return PackageManifest(
    generatedAt: DateTime.now().toUtc(),
    version: version,
    emenda: emenda,
    totalCharts: totalCharts,
    downloaded: downloaded,
    failed: failed,
    files: files,
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/package_manifest_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add lib/src/packaging/package_manifest.dart test/package_manifest_test.dart
git commit -m "feat: add optional bbox to ManifestFile; buildManifest accepts bboxByRelPath"
```

---

## Task 7: Checklist parsing in `chart_discovery.dart` (CLI)

**Files:**
- Modify: `charts_loader_cli/lib/src/discovery/chart_discovery.dart`
- Create: `charts_loader_cli/test/chart_discovery_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/chart_discovery_test.dart
import 'package:test/test.dart';
import 'package:charts_loader_cli/src/discovery/chart_discovery.dart';

void main() {
  group('parseChecklist', () {
    test('extracts inserir and destruir IDs', () {
      const xml = '''
        <aisweb>
          <checklist>
            <inserir>
              <item id="111"/>
              <item id="222"/>
            </inserir>
            <destruir>
              <item id="333"/>
            </destruir>
          </checklist>
        </aisweb>
      ''';
      final result = parseChecklist(xml);
      expect(result.inserir, {'111', '222'});
      expect(result.destruir, {'333'});
    });

    test('returns empty sets when checklist is empty', () {
      const xml = '''
        <aisweb>
          <checklist>
            <inserir/>
            <destruir/>
          </checklist>
        </aisweb>
      ''';
      final result = parseChecklist(xml);
      expect(result.inserir, isEmpty);
      expect(result.destruir, isEmpty);
    });

    test('handles multiple IDs in destruir', () {
      const xml = '''
        <aisweb>
          <checklist>
            <inserir/>
            <destruir>
              <item id="A"/>
              <item id="B"/>
              <item id="C"/>
            </destruir>
          </checklist>
        </aisweb>
      ''';
      final result = parseChecklist(xml);
      expect(result.destruir, {'A', 'B', 'C'});
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/chart_discovery_test.dart
```

Expected: FAIL — `parseChecklist` not found.

- [ ] **Step 3: Add `ChecklistResult` and `parseChecklist` to `chart_discovery.dart`**

Add after the existing imports (no new imports needed, `xml` is already used):

```dart
class ChecklistResult {
  const ChecklistResult({
    required this.inserir,
    required this.destruir,
  });

  final Set<String> inserir;
  final Set<String> destruir;
}

ChecklistResult parseChecklist(String xml) {
  final doc = XmlDocument.parse(xml);

  Set<String> extractIds(String tag) {
    return doc
        .findAllElements(tag)
        .expand((el) => el.findElements('item'))
        .map((el) => el.getAttribute('id')?.trim() ?? el.innerText.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  return ChecklistResult(
    inserir: extractIds('inserir'),
    destruir: extractIds('destruir'),
  );
}
```

- [ ] **Step 4: Run tests**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test test/chart_discovery_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 5: Run all tests**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add lib/src/discovery/chart_discovery.dart test/chart_discovery_test.dart
git commit -m "feat: add ChecklistResult and parseChecklist to chart_discovery"
```

---

## Task 8: New `package` orchestration in `bin/charts_loader_cli.dart` (CLI)

**Files:**
- Modify: `charts_loader_cli/bin/charts_loader_cli.dart`
- Modify: `charts_loader_cli/lib/src/packaging/package_writer.dart` (update call to `buildManifest`)

The new `package` command replaces the old 3-step logic. It runs: WMS discover → AD discover → checklist fetch → WMS sync (full re-download) → AD sync (checklist diff) → bbox extraction → validate → package.

The AD chart types sourced from the API are all `ChartTipo` values **except** these WMS types: `enrc`, `arc`, `wac`, `rea`, `reh`, `ccvRea`, `ccvReh`.

- [ ] **Step 1: Update `package_writer.dart` to pass empty `bboxByRelPath`**

The `PackageWriter.write` calls `buildManifest`. Update that call to pass the empty default:

In `package_writer.dart`, find:
```dart
    final manifest = await buildManifest(
      packageDir: chartPackageDir,
      emenda: discovery.emenda,
      totalCharts: discovery.charts.length,
      downloaded: succeeded.length,
      failed: failed.length,
    );
```

The signature of `buildManifest` now has `bboxByRelPath` with a default of `const {}`, so this call still compiles as-is. No change needed — the default handles it.

Run analyze to confirm:
```bash
cd /Users/gean/Projetos/charts_loader_cli && dart analyze
```

Expected: no errors.

- [ ] **Step 2: Replace `bin/charts_loader_cli.dart` with the new version**

```dart
// bin/charts_loader_cli.dart
// ignore_for_file: dangling_library_doc_comments

import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:charts_loader_cli/src/aisweb_client.dart';
import 'package:charts_loader_cli/src/discovery/chart_discovery.dart';
import 'package:charts_loader_cli/src/discovery/wms_discovery.dart';
import 'package:charts_loader_cli/src/models/bounding_box.dart';
import 'package:charts_loader_cli/src/models/chart.dart';
import 'package:charts_loader_cli/src/services/chart_download_service.dart';
import 'package:charts_loader_cli/src/services/geoaisweb_download_service.dart';
import 'package:charts_loader_cli/src/services/geopdf_extractor.dart';
import 'package:charts_loader_cli/src/packaging/package_manifest.dart';
import 'package:charts_loader_cli/src/packaging/package_writer.dart';

const _cacheDir = 'build/cache';
const _packageDir = 'build/package';

// Chart types sourced from geoaisweb WMS — never downloaded from AISWEB API.
const _wmsTypes = {
  ChartTipo.enrc,
  ChartTipo.arc,
  ChartTipo.wac,
  ChartTipo.rea,
  ChartTipo.reh,
  ChartTipo.ccvRea,
  ChartTipo.ccvReh,
};

Future<void> main(List<String> arguments) async {
  final parser = _buildParser();
  late ArgResults parsed;

  try {
    parsed = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('Erro: ${e.message}\n${parser.usage}');
    exitCode = 64;
    return;
  }

  if (parsed['help'] as bool) {
    stdout.writeln('charts_loader_cli — Baixador de cartas aeronáuticas DECEA\n');
    stdout.writeln(parser.usage);
    return;
  }

  final command = parsed.rest.isEmpty ? null : parsed.rest.first;
  final verbose = parsed['verbose'] as bool;
  final concurrency = int.parse(parsed['concurrency'] as String);

  switch (command) {
    case 'discover':
      await _runDiscover(verbose: verbose);
    case 'download':
      await _runDownload(verbose: verbose, concurrency: concurrency);
    case 'package':
      await _runPackage(verbose: verbose, concurrency: concurrency);
    default:
      stderr.writeln('Comando inválido. Use: discover | download | package');
      stderr.writeln(parser.usage);
      exitCode = 64;
  }
}

// ---------------------------------------------------------------------------
// discover — consulta API e salva index.json (legado, mantido para debug)
// ---------------------------------------------------------------------------

Future<void> _runDiscover({required bool verbose}) async {
  final client = AiswebClient();
  try {
    final discovery = ChartDiscovery(client, verbose: verbose);
    final result = await discovery.discoverAll();
    await saveIndex(result, p.join(_cacheDir, 'index.json'));
    stdout.writeln(
      'discover: ${result.charts.length} cartas → $_cacheDir/index.json '
      '(emenda: ${result.emenda})',
    );
  } finally {
    client.close();
  }
}

// ---------------------------------------------------------------------------
// download — consome index.json e baixa os PDFs (legado, mantido para debug)
// ---------------------------------------------------------------------------

Future<void> _runDownload({
  required bool verbose,
  required int concurrency,
}) async {
  final indexPath = p.join(_cacheDir, 'index.json');
  final discovery = await loadIndex(indexPath);
  if (discovery == null) {
    stderr.writeln('index.json não encontrado. Rode "discover" primeiro.');
    exitCode = 74;
    return;
  }

  final downloadDir =
      p.join(_cacheDir, 'airac_${discovery.emenda.replaceAll(' ', '')}');
  final service = ChartDownloadService(
    concurrency: concurrency,
    verbose: verbose,
  );

  try {
    stdout.writeln('download: ${discovery.charts.length} cartas → $downloadDir');
    final result = await service.downloadAll(discovery.charts, downloadDir);
    stdout.writeln(
      'download: ${result.succeeded.length} OK, ${result.failed.length} falhas',
    );
    if (result.failed.isNotEmpty) {
      for (final f in result.failed) {
        stderr.writeln('  FALHA: ${f.chart.arquivo} — ${f.error}');
      }
      exitCode = 75;
    }
  } finally {
    service.close();
  }
}

// ---------------------------------------------------------------------------
// package — fluxo completo: WMS + AD + checklist + manifest
// ---------------------------------------------------------------------------

Future<void> _runPackage({
  required bool verbose,
  required int concurrency,
}) async {
  final apiClient = AiswebClient();
  final adService = ChartDownloadService(
    concurrency: concurrency,
    verbose: verbose,
  );
  final wmsService = GeoaiswWebDownloadService(
    concurrency: concurrency,
    verbose: verbose,
  );
  final wmsDiscovery = WmsDiscovery();

  try {
    // ── 1. DISCOVER ─────────────────────────────────────────────────────────

    stdout.writeln('[discover] Consultando WMS GetCapabilities...');
    final wmsCharts = await wmsDiscovery.discover();
    stdout.writeln('[discover] ${wmsCharts.length} layers WMS encontrados.');

    stdout.writeln('[discover] Consultando API AISWEB (cartas de AD)...');
    final apiDiscovery = ChartDiscovery(apiClient, verbose: verbose);
    final apiResult = await apiDiscovery.discoverAll();
    final allAdCharts =
        apiResult.charts.where((c) => !_wmsTypes.contains(c.tipo)).toList();
    stdout.writeln(
      '[discover] ${allAdCharts.length} cartas de AD '
      '(emenda: ${apiResult.emenda}).',
    );

    stdout.writeln('[discover] Consultando checklist...');
    final checklistXml = await apiClient.fetchChecklist();
    final checklist = parseChecklist(checklistXml);
    stdout.writeln(
      '[discover] inserir: ${checklist.inserir.length}, '
      'destruir: ${checklist.destruir.length}.',
    );

    // ── 2. SYNC ─────────────────────────────────────────────────────────────

    // WMS charts: full re-download each cycle into build/cache/wms/
    final wmsCacheDir = p.join(_cacheDir, 'wms');
    stdout.writeln('[sync] Baixando ${wmsCharts.length} GeoTIFFs (WMS)...');
    final wmsResult = await wmsService.downloadAll(wmsCharts, wmsCacheDir);
    stdout.writeln(
      '[sync] WMS: ${wmsResult.succeeded.length} OK, '
      '${wmsResult.failed.length} falhas.',
    );

    // AD charts: checklist diff into build/cache/ad/
    final adCacheDir = p.join(_cacheDir, 'ad');
    final adDirExists = await Directory(adCacheDir).exists();
    final List<Chart> chartsToDownload;

    if (!adDirExists || checklist.inserir.isEmpty) {
      chartsToDownload = allAdCharts;
      stdout.writeln(
        '[sync] Cache AD vazio ou checklist vazio — baixando todas as '
        '${allAdCharts.length} cartas de AD.',
      );
    } else {
      chartsToDownload = allAdCharts
          .where((c) => checklist.inserir.contains(c.id))
          .toList();
      stdout.writeln(
        '[sync] Incremental: baixando ${chartsToDownload.length} '
        'cartas AD (inserir).',
      );

      // Delete destruir charts from the local AD cache.
      for (final chart
          in allAdCharts.where((c) => checklist.destruir.contains(c.id))) {
        final path = _adChartPath(adCacheDir, chart);
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          if (verbose) stdout.writeln('[sync] Removido: $path');
        }
      }
    }

    final adResult = await adService.downloadAll(chartsToDownload, adCacheDir);
    stdout.writeln(
      '[sync] AD: ${adResult.succeeded.length} OK, '
      '${adResult.failed.length} falhas.',
    );

    // ── Extract bboxes ───────────────────────────────────────────────────────

    final bboxByRelPath = <String, BoundingBox?>{};

    for (final dl in wmsResult.succeeded) {
      final relPath =
          p.relative(dl.filePath, from: wmsCacheDir).replaceAll('\\', '/');
      bboxByRelPath[relPath] = dl.chart.bbox;
    }

    stdout.writeln('[bbox] Extraindo /GPTS de ${adResult.succeeded.length} PDFs...');
    for (final dl in adResult.succeeded) {
      final relPath =
          p.relative(dl.filePath, from: adCacheDir).replaceAll('\\', '/');
      bboxByRelPath[relPath] = await extractBboxFromPdf(dl.filePath);
    }

    // ── 3. VALIDATE ──────────────────────────────────────────────────────────

    if (wmsResult.failed.isNotEmpty) {
      stderr.writeln(
        'ERRO: ${wmsResult.failed.length} GeoTIFFs não baixados — abortando.',
      );
      for (final f in wmsResult.failed) {
        stderr.writeln('  ${f.chart.layerName}: ${f.error}');
      }
      exitCode = 75;
      return;
    }

    if (adResult.failed.isNotEmpty) {
      stderr.writeln(
        'WARN: ${adResult.failed.length} cartas AD não baixadas:',
      );
      for (final f in adResult.failed) {
        stderr.writeln('  ${f.chart.arquivo}: ${f.error}');
      }
    }

    // ── 4. PACKAGE ───────────────────────────────────────────────────────────

    final airacFolder =
        'airac_${apiResult.emenda.replaceAll(' ', '')}';
    final packageAiracDir = p.join(_packageDir, airacFolder);

    stdout.writeln('[package] Copiando arquivos para $packageAiracDir...');
    await _copyDir(wmsCacheDir, packageAiracDir);
    await _copyDir(adCacheDir, packageAiracDir);

    stdout.writeln('[package] Gerando manifest.json...');
    final manifest = await buildManifest(
      packageDir: packageAiracDir,
      emenda: apiResult.emenda,
      totalCharts: wmsCharts.length + allAdCharts.length,
      downloaded: wmsResult.succeeded.length + adResult.succeeded.length,
      failed: wmsResult.failed.length + adResult.failed.length,
      bboxByRelPath: bboxByRelPath,
    );

    await writeManifest(
      manifest,
      p.join(packageAiracDir, 'manifest.json'),
    );

    stdout.writeln(
      'package: concluído — ${manifest.downloaded} cartas, '
      'emenda ${manifest.emenda}',
    );

    if (adResult.failed.isNotEmpty || wmsResult.failed.isNotEmpty) {
      exitCode = 75;
    }
  } finally {
    apiClient.close();
    adService.close();
    wmsService.close();
    wmsDiscovery.close();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _adChartPath(String adCacheDir, Chart chart) {
  final filename = chart.arquivo.endsWith('.pdf')
      ? chart.arquivo
      : '${chart.arquivo}.pdf';
  return p.join(adCacheDir, chart.especie.name, chart.tipo.name, filename);
}

Future<void> _copyDir(String srcDir, String destDir) async {
  final src = Directory(srcDir);
  if (!await src.exists()) return;
  await for (final entity in src.list(recursive: true)) {
    if (entity is! File) continue;
    final relPath = p.relative(entity.path, from: srcDir);
    final dest = File(p.join(destDir, relPath));
    await dest.parent.create(recursive: true);
    await entity.copy(dest.path);
  }
}

// ---------------------------------------------------------------------------
// Parser de argumentos
// ---------------------------------------------------------------------------

ArgParser _buildParser() => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false, help: 'Mostra esta ajuda')
  ..addFlag('verbose', abbr: 'v', negatable: false, help: 'Saída detalhada')
  ..addOption(
    'concurrency',
    abbr: 'c',
    defaultsTo: '4',
    help: 'Downloads simultâneos',
  );
```

- [ ] **Step 3: Run analyze**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart analyze
```

Expected: no errors. Fix any if found.

- [ ] **Step 4: Run all tests**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart test
```

Expected: all tests pass.

- [ ] **Step 5: Smoke test — discover only (no full download)**

```bash
cd /Users/gean/Projetos/charts_loader_cli && dart run bin/charts_loader_cli.dart discover -v
```

Expected: CLI prints count of discovered charts and writes `build/cache/index.json`.

- [ ] **Step 6: Commit**

```bash
cd /Users/gean/Projetos/charts_loader_cli
git add bin/charts_loader_cli.dart lib/src/packaging/package_writer.dart
git commit -m "feat: new package command — WMS + AD + checklist diff + bbox in manifest"
```

---

## Task 9: `BoundingBox` + `bbox` in `r2_manifest.dart` (App)

**Files:**
- Modify: `navbr/lib/models/r2_manifest.dart`

- [ ] **Step 1: Write the failing test**

Add to `navbr/test/` (create file):

```dart
// test/r2_manifest_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:navbr/models/r2_manifest.dart';

void main() {
  group('R2ManifestFile.fromJson', () {
    test('parses bbox when present', () {
      final json = {
        'path': 'rota/enrc/ENRC_H1.tif',
        'size': 99640716,
        'sha256': 'abc123',
        'bbox': {
          'north': -23.745,
          'south': -34.350,
          'east': -41.026,
          'west': -59.155,
        },
      };
      final file = R2ManifestFile.fromJson(json);
      expect(file.bbox, isNotNull);
      expect(file.bbox!.north, closeTo(-23.745, 0.001));
      expect(file.bbox!.west, closeTo(-59.155, 0.001));
    });

    test('bbox is null when absent from json', () {
      final json = {
        'path': 'ifr/iac/SBGR_IAC.pdf',
        'size': 524288,
        'sha256': 'def456',
      };
      final file = R2ManifestFile.fromJson(json);
      expect(file.bbox, isNull);
    });
  });
}
```

- [ ] **Step 2: Run test to confirm it fails**

```bash
cd /Users/gean/Projetos/navbr && flutter test test/r2_manifest_test.dart
```

Expected: FAIL — `R2ManifestFile` has no `bbox` field.

- [ ] **Step 3: Update `r2_manifest.dart`**

Add `BoundingBox` class at the top of the file (before `R2Latest`):

```dart
class BoundingBox {
  const BoundingBox({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  factory BoundingBox.fromJson(Map<String, dynamic> json) => BoundingBox(
        north: (json['north'] as num).toDouble(),
        south: (json['south'] as num).toDouble(),
        east: (json['east'] as num).toDouble(),
        west: (json['west'] as num).toDouble(),
      );
}
```

Replace `R2ManifestFile` class:

```dart
class R2ManifestFile {
  const R2ManifestFile({
    required this.path,
    required this.size,
    required this.sha256,
    this.bbox,
  });

  final String path;
  final int size;
  final String sha256;
  final BoundingBox? bbox;

  String get especie => path.split('/').first;
  String get tipo => path.split('/')[1];
  String get filename => path.split('/').last;

  factory R2ManifestFile.fromJson(Map<String, dynamic> json) {
    final bboxJson = json['bbox'] as Map<String, dynamic>?;
    return R2ManifestFile(
      path: json['path'] as String,
      size: json['size'] as int,
      sha256: json['sha256'] as String,
      bbox: bboxJson != null ? BoundingBox.fromJson(bboxJson) : null,
    );
  }
}
```

- [ ] **Step 4: Run test**

```bash
cd /Users/gean/Projetos/navbr && flutter test test/r2_manifest_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Run analyze**

```bash
cd /Users/gean/Projetos/navbr && flutter analyze
```

Expected: no errors.

- [ ] **Step 6: Commit**

```bash
cd /Users/gean/Projetos/navbr
git add lib/models/r2_manifest.dart test/r2_manifest_test.dart
git commit -m "feat: add BoundingBox and optional bbox to R2ManifestFile"
```

---

## Task 10: Use manifest bbox in `charts_download_provider.dart` (App)

**Files:**
- Modify: `navbr/lib/providers/charts_download_provider.dart`

Replace the current GeoTIFF parsing path with manifest bbox lookup. Keep `GeoPdfParser` as fallback for PDFs with `bbox == null`.

- [ ] **Step 1: Update `charts_download_provider.dart`**

Remove the `_tiffParser` field and its import. Add `_pdfParser`. Replace the indexing block inside `downloadGroup`:

The complete updated file:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/r2_manifest.dart';
import '../services/r2_service.dart';
import '../services/geopdf_parser.dart';
import '../services/database_service.dart';
import 'package:path_provider/path_provider.dart';

class ChartsDownloadState {
  final R2Manifest? manifest;
  final bool loading;
  final String? error;
  final Map<String, int> localCounts;
  final Set<String> downloading;
  final Map<String, (int, int)> downloadProgress;

  const ChartsDownloadState({
    this.manifest,
    this.loading = true,
    this.error,
    this.localCounts = const {},
    this.downloading = const {},
    this.downloadProgress = const {},
  });

  ChartsDownloadState copyWith({
    R2Manifest? manifest,
    bool? loading,
    String? error,
    Map<String, int>? localCounts,
    Set<String>? downloading,
    Map<String, (int, int)>? downloadProgress,
    bool clearError = false,
  }) {
    return ChartsDownloadState(
      manifest: manifest ?? this.manifest,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      localCounts: localCounts ?? this.localCounts,
      downloading: downloading ?? this.downloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

class ChartsDownloadNotifier extends Notifier<ChartsDownloadState> {
  final _r2 = R2Service();
  final _db = DatabaseService();
  final _pdfParser = GeoPdfParser();

  @override
  ChartsDownloadState build() {
    Future.microtask(_loadManifest);
    return const ChartsDownloadState(loading: true);
  }

  Future<void> _loadManifest() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final latest = await _r2.fetchLatest();
      final manifest = await _r2.fetchManifest(latest.folder);
      final counts = await _r2.countAllLocalFiles(
        latest.folder,
        manifest.groups,
      );
      state = state.copyWith(
        manifest: manifest,
        localCounts: counts,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), loading: false);
    }
  }

  Future<void> refresh() => _loadManifest();

  Future<void> downloadGroup(
    String uiGroupKey,
    List<R2ChartGroup> originalGroups,
    int totalFiles,
  ) async {
    if (state.downloading.contains(uiGroupKey) || state.manifest == null) {
      return;
    }

    final newDownloading = Set<String>.from(state.downloading)..add(uiGroupKey);
    final newProgress = Map<String, (int, int)>.from(state.downloadProgress);
    newProgress[uiGroupKey] = (0, totalFiles);

    state = state.copyWith(
      downloading: newDownloading,
      downloadProgress: newProgress,
    );

    int completed = 0;
    final baseDir = await getApplicationDocumentsDirectory();
    final chartsBaseDir = '${baseDir.path}/charts';

    for (final group in originalGroups) {
      for (final file in group.files) {
        try {
          await _r2.downloadFile(state.manifest!.folder, file);

          final localPath =
              '$chartsBaseDir/${state.manifest!.folder}/${file.path}';
          final ext = file.path.split('.').last.toLowerCase();

          BoundingBox? bbox;

          if (ext == 'tif' || ext == 'tiff') {
            // GeoTIFF: bbox is always in the manifest (extracted by CLI).
            bbox = file.bbox;
          } else if (ext == 'pdf') {
            // PDF: use manifest bbox if available, fallback to /GPTS parsing.
            if (file.bbox != null) {
              bbox = file.bbox;
            } else {
              final parsed = await _pdfParser.extractGeoData(localPath);
              if (parsed != null) {
                bbox = BoundingBox(
                  north: (parsed['north'] as num).toDouble(),
                  south: (parsed['south'] as num).toDouble(),
                  east: (parsed['east'] as num).toDouble(),
                  west: (parsed['west'] as num).toDouble(),
                );
              }
            }
          }

          if (bbox != null) {
            await _db.saveChart(
              ChartIndex(
                key: file.path,
                type: file.tipo,
                path: localPath,
                north: bbox.north,
                south: bbox.south,
                east: bbox.east,
                west: bbox.west,
              ),
            );
          }

          completed++;
          final updatedProgress =
              Map<String, (int, int)>.from(state.downloadProgress);
          updatedProgress[uiGroupKey] = (completed, totalFiles);
          state = state.copyWith(downloadProgress: updatedProgress);
        } catch (_) {
          // Continue on individual errors.
        }
      }
    }

    final newCounts = Map<String, int>.from(state.localCounts);
    for (final group in originalGroups) {
      final count =
          await _r2.countLocalFiles(state.manifest!.folder, group);
      newCounts[group.key] = count;
    }

    final finalDownloading =
        Set<String>.from(state.downloading)..remove(uiGroupKey);
    final finalProgress =
        Map<String, (int, int)>.from(state.downloadProgress)
          ..remove(uiGroupKey);

    state = state.copyWith(
      localCounts: newCounts,
      downloading: finalDownloading,
      downloadProgress: finalProgress,
    );
  }
}

final chartsDownloadProvider =
    NotifierProvider<ChartsDownloadNotifier, ChartsDownloadState>(
      ChartsDownloadNotifier.new,
    );
```

- [ ] **Step 2: Run analyze**

```bash
cd /Users/gean/Projetos/navbr && flutter analyze
```

Expected: no errors. If `GeoTiffParser` is still imported somewhere else, that's fine — it will be removed in a separate cleanup after full migration is validated.

- [ ] **Step 3: Commit**

```bash
cd /Users/gean/Projetos/navbr
git add lib/providers/charts_download_provider.dart
git commit -m "feat: use manifest bbox for GeoTIFFs; GeoPdfParser fallback for PDFs without bbox"
```

---

## Task 11: Update `charts_download_screen.dart` (App)

**Files:**
- Modify: `navbr/lib/screens/charts_download_screen.dart`

Changes:
1. Remove `reul` from all type label/description/category maps.
2. Add `ccvRea` and `ccvReh` labels, descriptions, and category assignment.
3. Fix ENRC split logic for new filenames (`ENRC_H1.tif` instead of the old `enrc-h` naming).
4. Update VFR sort order.

- [ ] **Step 1: Update `_tipoLabels`**

Replace the entire `const _tipoLabels` map:
```dart
const _tipoLabels = {
  'adc':    'ADC',
  'arc':    'ARC',
  'gmc':    'GMC',
  'iac':    'IAC',
  'lc':     'LC',
  'pdc':    'PDC',
  'sid':    'SID',
  'star':   'STAR',
  'vac':    'VAC',
  'cv':     'CV',
  'ccvRea': 'CCV REA',
  'ccvReh': 'CCV REH',
  'rea':    'REA',
  'reast':  'REAST',
  'reh':    'REH',
  'wac':    'WAC',
  'enrc':   'ENRC',
  'enrcl':  'ENRC L',
  'enrch':  'ENRC H',
  'enrc_l': 'ENRC L',
  'enrc_h': 'ENRC H',
};
```

- [ ] **Step 2: Update `_tipoDescriptions`**

Replace the entire `const _tipoDescriptions` map:
```dart
const _tipoDescriptions = {
  'adc':    'Aerodrome Chart',
  'arc':    'Aerodrome Radar Chart',
  'gmc':    'Ground Movement Chart',
  'iac':    'Instrument Approach Chart',
  'lc':     'Location Chart',
  'pdc':    'Parking & Docking Chart',
  'sid':    'Standard Instrument Departure',
  'star':   'Standard Terminal Arrival',
  'vac':    'Visual Approach Chart',
  'cv':     'Carta Visual',
  'ccvRea': 'Cobertura VFR — Rota Especial (Área)',
  'ccvReh': 'Cobertura VFR — Rota Especial (Helicóptero)',
  'rea':    'Rota Especial (Área)',
  'reast':  'Rota Especial (Aterrissagem)',
  'reh':    'Rota Especial (Helicóptero)',
  'wac':    'World Aeronautical Chart',
  'enrc':   'En-Route Chart',
  'enrcl':  'En-Route Chart (Baixa Altitude)',
  'enrch':  'En-Route Chart (Alta Altitude)',
  'enrc_l': 'En-Route Chart (Baixa Altitude)',
  'enrc_h': 'En-Route Chart (Alta Altitude)',
};
```

- [ ] **Step 3: Update `_tipoToCategory`**

Replace the entire `const _tipoToCategory` map:
```dart
const _tipoToCategory = {
  'iac':    'Cartas de Aeródromos',
  'sid':    'Cartas de Aeródromos',
  'star':   'Cartas de Aeródromos',
  'adc':    'Cartas de Aeródromos',
  'gmc':    'Cartas de Aeródromos',
  'pdc':    'Cartas de Aeródromos',
  'vac':    'Cartas de Aeródromos',
  'cv':     'Cartas de Aeródromos',
  'lc':     'Cartas de Aeródromos',
  'arc':    'Cartas IFR',
  'ccvRea': 'Cartas VFR',
  'ccvReh': 'Cartas VFR',
  'rea':    'Cartas VFR',
  'reh':    'Cartas VFR',
  'wac':    'Cartas VFR',
  'enrc':   'Cartas IFR',
  'enrcl':  'Cartas IFR',
  'enrch':  'Cartas IFR',
  'enrc_l': 'Cartas IFR',
  'enrc_h': 'Cartas IFR',
  'reast':  'Cartas IFR',
};
```

- [ ] **Step 4: Fix the ENRC split inside `_buildContent`**

Find and replace this block:
```dart
      if (group.tipo == 'enrc') {
        // Separa as cartas ENRC em H e L baseado no nome do arquivo
        final hFiles = group.files.where((f) => f.filename.contains('enrc-h')).toList();
        final lFiles = group.files.where((f) => f.filename.contains('enrc-l')).toList();
        final otherEnrcFiles = group.files.where((f) => !f.filename.contains('enrc-h') && !f.filename.contains('enrc-l')).toList();
```

Replace with:
```dart
      if (group.tipo == 'enrc') {
        // ENRC filenames: ENRC_H1.tif ... ENRC_H9.tif and ENRC_L1.tif ... ENRC_L9.tif
        final hFiles = group.files
            .where((f) => RegExp(r'ENRC_H\d', caseSensitive: false).hasMatch(f.filename))
            .toList();
        final lFiles = group.files
            .where((f) => RegExp(r'ENRC_L\d', caseSensitive: false).hasMatch(f.filename))
            .toList();
        final otherEnrcFiles = group.files
            .where((f) =>
                !RegExp(r'ENRC_H\d', caseSensitive: false).hasMatch(f.filename) &&
                !RegExp(r'ENRC_L\d', caseSensitive: false).hasMatch(f.filename))
            .toList();
```

- [ ] **Step 5: Update VFR sort order**

Find:
```dart
      final vfrOrder = ['wac', 'rea', 'reh', 'reul'];
```

Replace with:
```dart
      final vfrOrder = ['wac', 'rea', 'reh', 'ccvRea', 'ccvReh'];
```

- [ ] **Step 6: Run analyze**

```bash
cd /Users/gean/Projetos/navbr && flutter analyze
```

Expected: no errors.

- [ ] **Step 7: Run all tests**

```bash
cd /Users/gean/Projetos/navbr && flutter test
```

Expected: all tests pass.

- [ ] **Step 8: Commit**

```bash
cd /Users/gean/Projetos/navbr
git add lib/screens/charts_download_screen.dart
git commit -m "feat: add ccvRea/ccvReh to download screen; remove reul; fix ENRC filename split"
```

---

## Self-Review Checklist

- [x] **Spec coverage**
  - WMS GetCapabilities discovery → Task 3 ✓
  - GeoTIFF download from geoaisweb → Task 5 ✓
  - /GPTS extractor for AD PDFs → Task 4 ✓
  - Checklist API diff (inserir/destruir) → Task 7, Task 8 ✓
  - Bbox in manifest → Task 6 ✓
  - App reads bbox from manifest → Task 10 ✓
  - GeoPdfParser kept as fallback → Task 10 ✓
  - ccvRea/ccvReh added, reul removed → Task 1, Task 11 ✓
  - ARC_ACADEMIA bbox hardcode → Task 3 (in `_bboxOverrides`) ✓
  - ENRC H/L splitting for new filenames → Task 11 ✓

- [x] **No placeholders** — all steps contain complete code.

- [x] **Type consistency**
  - `BoundingBox` defined in CLI `bounding_box.dart`, separately in app `r2_manifest.dart` (no cross-repo dependency needed)
  - `WmsChart.bbox` is `BoundingBox` from CLI
  - `R2ManifestFile.bbox` is `BoundingBox` from app manifest model
  - `bboxByRelPath` keys use forward-slash normalized paths matching `buildManifest` output
  - `_wmsTypes` set uses `ChartTipo` values added in Task 1
