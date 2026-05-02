import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import '../services/database_service.dart';
import '../services/geotiff_parser.dart';
import '../services/geopdf_parser.dart';

class BaseChart {
  final String path;
  final Map<String, double> boundingBox;

  const BaseChart({required this.path, required this.boundingBox});
}

class ChartSettings {
  const ChartSettings({
    this.wacOpacity = 1.0,
    this.iacOpacity = 0.7,
    this.isIacVisible = true,
    this.iacPath,
    this.iacBoundingBox,
    this.selectedBaseChart = 'WAC',
    this.baseCharts = const [],
    this.isLoadingBaseCharts = false,
  });

  final double wacOpacity;
  final double iacOpacity;
  final bool isIacVisible;
  final String? iacPath;
  final Map<String, double>? iacBoundingBox;

  final String selectedBaseChart; // 'ENRC L', 'ENRC H', 'WAC', 'Nenhum'
  final List<BaseChart> baseCharts;
  final bool isLoadingBaseCharts;

  ChartSettings copyWith({
    double? wacOpacity,
    double? iacOpacity,
    bool? isIacVisible,
    String? iacPath,
    Map<String, double>? iacBoundingBox,
    String? selectedBaseChart,
    List<BaseChart>? baseCharts,
    bool? isLoadingBaseCharts,
  }) => ChartSettings(
    wacOpacity: wacOpacity ?? this.wacOpacity,
    iacOpacity: iacOpacity ?? this.iacOpacity,
    isIacVisible: isIacVisible ?? this.isIacVisible,
    iacPath: iacPath ?? this.iacPath,
    iacBoundingBox: iacBoundingBox ?? this.iacBoundingBox,
    selectedBaseChart: selectedBaseChart ?? this.selectedBaseChart,
    baseCharts: baseCharts ?? this.baseCharts,
    isLoadingBaseCharts: isLoadingBaseCharts ?? this.isLoadingBaseCharts,
  );
}

class ChartSettingsNotifier extends Notifier<ChartSettings> {
  final _db = DatabaseService();

  @override
  ChartSettings build() {
    Future.microtask(_load);
    return const ChartSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    String? iacPath = prefs.getString('saved_iac_path');
    if (iacPath != null && !File(iacPath).existsSync()) {
      iacPath = null;
    }

    final selectedBase = prefs.getString('selected_base_chart') ?? 'WAC';

    state = ChartSettings(
      iacOpacity: prefs.getDouble('iac_opacity') ?? 0.7,
      isIacVisible: prefs.getBool('is_iac_visible') ?? true,
      selectedBaseChart: selectedBase,
      iacPath: iacPath,
      iacBoundingBox: iacPath == null
          ? null
          : {
              'north': prefs.getDouble('saved_iac_north') ?? 0.0,
              'south': prefs.getDouble('saved_iac_south') ?? 0.0,
              'east': prefs.getDouble('saved_iac_east') ?? 0.0,
              'west': prefs.getDouble('saved_iac_west') ?? 0.0,
            },
    );

    await _loadBaseCharts(selectedBase);
  }

  Future<void> refresh() => _load();

  Future<void> setIacOpacity(double value) async {
    state = state.copyWith(iacOpacity: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('iac_opacity', value);
  }

  Future<void> setIacVisible(bool value) async {
    state = state.copyWith(isIacVisible: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_iac_visible', value);
  }

  Future<void> setSelectedBaseChart(String type) async {
    if (state.selectedBaseChart == type) return;

    state = state.copyWith(
      selectedBaseChart: type,
      baseCharts: [],
      isLoadingBaseCharts: true,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_base_chart', type);

    await _loadBaseCharts(type);
  }

  Future<String> _ensureRenderedPath(String originalPath) async {
    if (!originalPath.toLowerCase().endsWith('.pdf')) {
      return originalPath;
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = originalPath.split('/').last.replaceAll('.pdf', '');
    final renderedPath = '${dir.path}/rendered_$fileName.png';

    if (!File(renderedPath).existsSync()) {
      try {
        final document = await PdfDocument.openFile(originalPath);
        final page = await document.getPage(1);

        final pageImage = await page.render(
          width: page.width * 2,
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );

        await page.close();
        await document.close();

        if (pageImage != null) {
          await File(renderedPath).writeAsBytes(pageImage.bytes);
          return renderedPath;
        }
      } catch (e) {
        return originalPath;
      }
    }

    return renderedPath;
  }

  Future<void> _loadBaseCharts(String type) async {
    if (type == 'Nenhum') {
      state = state.copyWith(baseCharts: [], isLoadingBaseCharts: false);
      return;
    }

    state = state.copyWith(isLoadingBaseCharts: true);

    try {
      final String tipoQuery;
      if (type == 'WAC') {
        tipoQuery = 'wac';
      } else if (type == 'ENRC L') {
        tipoQuery = 'enrcl';
      } else if (type == 'ENRC H') {
        tipoQuery = 'enrch';
      } else {
        state = state.copyWith(baseCharts: [], isLoadingBaseCharts: false);
        return;
      }

      final chartsFromDb = await _db.getChartsByType(tipoQuery);
      final List<BaseChart> loadedCharts = [];

      for (final c in chartsFromDb) {
        String finalPath = await _ensureRenderedPath(c.path);

        loadedCharts.add(
          BaseChart(
            path: finalPath,
            boundingBox: {
              'north': c.north,
              'south': c.south,
              'east': c.east,
              'west': c.west,
            },
          ),
        );
      }

      // Sincronização preguiçosa: Verifica se há arquivos na pasta que não estão no DB (caso tenham sido baixados antes do DB)
      final dir = await getApplicationDocumentsDirectory();
      final chartsDir = Directory('${dir.path}/charts');
      if (await chartsDir.exists()) {
        final cycleDirs = chartsDir.listSync().whereType<Directory>();
        for (final cycleDir in cycleDirs) {
          final espDirs = cycleDir.listSync().whereType<Directory>();
          for (final espDir in espDirs) {
            final tipoDir = Directory('${espDir.path}/$tipoQuery');
            if (await tipoDir.exists()) {
              final files = tipoDir.listSync().whereType<File>();
              for (final file in files) {
                if (!loadedCharts.any((c) => c.path == file.path)) {
                  final ext = file.path.split('.').last.toLowerCase();
                  Map<String, double>? bounds;

                  if (ext == 'tif' || ext == 'tiff') {
                    bounds = await GeoTiffParser().extractBoundingBox(
                      file.path,
                    );
                  } else if (ext == 'pdf') {
                    final dynBounds = await GeoPdfParser().extractGeoData(
                      file.path,
                    );
                    if (dynBounds != null) {
                      bounds = {
                        'north': dynBounds['north'] as double,
                        'south': dynBounds['south'] as double,
                        'east': dynBounds['east'] as double,
                        'west': dynBounds['west'] as double,
                      };
                    }
                  }

                  if (bounds != null) {
                    final newChart = ChartIndex(
                      key: file.path,
                      type: tipoQuery,
                      path: file.path,
                      north: bounds['north']!,
                      south: bounds['south']!,
                      east: bounds['east']!,
                      west: bounds['west']!,
                    );
                    await _db.saveChart(newChart);

                    final renderedPath = await _ensureRenderedPath(file.path);
                    loadedCharts.add(
                      BaseChart(path: renderedPath, boundingBox: bounds),
                    );
                  }
                }
              }
            }
          }
        }
      }

      // Se o usuário baixou WAC individual no PoC, mantemos a compatibilidade
      if (type == 'WAC') {
        final prefs = await SharedPreferences.getInstance();
        final wacPath = prefs.getString('saved_wac_path');
        if (wacPath != null && File(wacPath).existsSync()) {
          if (!loadedCharts.any((c) => c.path == wacPath)) {
            final north = prefs.getDouble('saved_wac_north');
            final south = prefs.getDouble('saved_wac_south');
            final east = prefs.getDouble('saved_wac_east');
            final west = prefs.getDouble('saved_wac_west');
            if (north != null &&
                south != null &&
                east != null &&
                west != null) {
              loadedCharts.add(
                BaseChart(
                  path: wacPath,
                  boundingBox: {
                    'north': north,
                    'south': south,
                    'east': east,
                    'west': west,
                  },
                ),
              );
            }
          }
        }
      }

      state = state.copyWith(
        baseCharts: loadedCharts,
        isLoadingBaseCharts: false,
      );
    } catch (e) {
      state = state.copyWith(baseCharts: [], isLoadingBaseCharts: false);
    }
  }
}

final chartSettingsProvider =
    NotifierProvider<ChartSettingsNotifier, ChartSettings>(
      ChartSettingsNotifier.new,
    );
