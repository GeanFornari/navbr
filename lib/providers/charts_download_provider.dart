import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/r2_manifest.dart';
import '../services/r2_service.dart';
import '../services/geotiff_parser.dart';
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
  final _tiffParser = GeoTiffParser();

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

          // Index the downloaded file in the database
          final localPath =
              '$chartsBaseDir/${state.manifest!.folder}/${file.path}';
          final ext = file.path.split('.').last.toLowerCase();

          if (ext == 'tif' || ext == 'tiff') {
            final bounds = await _tiffParser.extractBoundingBox(localPath);
            if (bounds != null) {
              await _db.saveChart(
                ChartIndex(
                  key: file.path,
                  type: file.tipo,
                  path: localPath,
                  north: bounds['north']!,
                  south: bounds['south']!,
                  east: bounds['east']!,
                  west: bounds['west']!,
                ),
              );
            }
          }

          completed++;

          final updatedProgress = Map<String, (int, int)>.from(
            state.downloadProgress,
          );
          updatedProgress[uiGroupKey] = (completed, totalFiles);
          state = state.copyWith(downloadProgress: updatedProgress);
        } catch (_) {
          // Continua nos erros individuais
        }
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
