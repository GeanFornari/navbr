import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/r2_manifest.dart';
import '../services/r2_service.dart';
import '../services/geopdf_parser.dart';
import '../services/database_service.dart';
import 'package:path_provider/path_provider.dart';
import 'chart_settings_provider.dart';

class ChartsDownloadState {
  final R2Manifest? manifest;
  final bool loading;
  final String? error;
  final Map<String, int> localCounts;
  final Set<String> downloading;
  final Map<String, (int, int)> downloadProgress;
  final Map<String, int> failedCounts;

  const ChartsDownloadState({
    this.manifest,
    this.loading = true,
    this.error,
    this.localCounts = const {},
    this.downloading = const {},
    this.downloadProgress = const {},
    this.failedCounts = const {},
  });

  ChartsDownloadState copyWith({
    R2Manifest? manifest,
    bool? loading,
    String? error,
    Map<String, int>? localCounts,
    Set<String>? downloading,
    Map<String, (int, int)>? downloadProgress,
    Map<String, int>? failedCounts,
    bool clearError = false,
  }) {
    return ChartsDownloadState(
      manifest: manifest ?? this.manifest,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      localCounts: localCounts ?? this.localCounts,
      downloading: downloading ?? this.downloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      failedCounts: failedCounts ?? this.failedCounts,
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
    int failed = 0;
    final baseDir = await getApplicationDocumentsDirectory();
    final chartsBaseDir = '${baseDir.path}/charts';

    for (final group in originalGroups) {
      for (final file in group.files) {
        try {
          await _r2.downloadFile(state.manifest!.folder, file);

          // Index the downloaded file in the database
          final localPath =
              '$chartsBaseDir/${state.manifest!.folder}/${file.path}';
          final ext = file.path.split('.').last.toLowerCase();

          BoundingBox? bbox;

          if (ext == 'tif' || ext == 'tiff') {
            // GeoTIFF: bbox always comes from the manifest (extracted by CLI).
            bbox = file.bbox;
          } else if (ext == 'pdf') {
            // PDF: use manifest bbox if available, else parse /GPTS from file.
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
        } catch (_) {
          failed++;
        }

        completed++;
        final updatedProgress = Map<String, (int, int)>.from(
          state.downloadProgress,
        );
        updatedProgress[uiGroupKey] = (completed, totalFiles);
        state = state.copyWith(downloadProgress: updatedProgress);
      }
    }

    final newCounts = Map<String, int>.from(state.localCounts);
    for (final group in originalGroups) {
      final count = await _r2.countLocalFiles(state.manifest!.folder, group);
      newCounts[group.key] = count;
    }

    final finalDownloading = Set<String>.from(state.downloading)
      ..remove(uiGroupKey);
    final finalProgress = Map<String, (int, int)>.from(state.downloadProgress)
      ..remove(uiGroupKey);
    final newFailed = Map<String, int>.from(state.failedCounts);
    if (failed > 0) {
      newFailed[uiGroupKey] = failed;
    } else {
      newFailed.remove(uiGroupKey);
    }

    state = state.copyWith(
      localCounts: newCounts,
      downloading: finalDownloading,
      downloadProgress: finalProgress,
      failedCounts: newFailed,
    );

    ref.read(chartSettingsProvider.notifier).refresh();
  }
}

final chartsDownloadProvider =
    NotifierProvider<ChartsDownloadNotifier, ChartsDownloadState>(
      ChartsDownloadNotifier.new,
    );
