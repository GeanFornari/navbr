class R2Latest {
  const R2Latest({required this.emenda, required this.folder});
  final String emenda;
  final String folder;

  factory R2Latest.fromJson(Map<String, dynamic> json) => R2Latest(
        emenda: json['emenda'] as String,
        folder: json['folder'] as String,
      );
}

class R2ManifestFile {
  const R2ManifestFile({
    required this.path,
    required this.size,
    required this.sha256,
  });
  final String path;
  final int size;
  final String sha256;

  String get especie => path.split('/').first;
  String get tipo => path.split('/')[1];
  String get filename => path.split('/').last;

  factory R2ManifestFile.fromJson(Map<String, dynamic> json) => R2ManifestFile(
        path: json['path'] as String,
        size: json['size'] as int,
        sha256: json['sha256'] as String,
      );
}

class R2ChartGroup {
  const R2ChartGroup({
    required this.especie,
    required this.tipo,
    required this.files,
  });
  final String especie;
  final String tipo;
  final List<R2ManifestFile> files;

  String get key => '$especie/$tipo';
  int get totalSize => files.fold(0, (s, f) => s + f.size);
}

class R2Manifest {
  const R2Manifest({
    required this.generatedAt,
    required this.emenda,
    required this.folder,
    required this.totalCharts,
    required this.downloaded,
    required this.files,
  });
  final DateTime generatedAt;
  final String emenda;
  final String folder;
  final int totalCharts;
  final int downloaded;
  final List<R2ManifestFile> files;

  List<R2ChartGroup> get groups {
    final map = <String, List<R2ManifestFile>>{};
    for (final file in files) {
      map.putIfAbsent('${file.especie}/${file.tipo}', () => []).add(file);
    }
    const especieOrder = {'ifr': 0, 'vfr': 1, 'rota': 2};
    return map.entries
        .map((e) {
          final parts = e.key.split('/');
          return R2ChartGroup(especie: parts[0], tipo: parts[1], files: e.value);
        })
        .toList()
      ..sort((a, b) {
          final ae = especieOrder[a.especie] ?? 3;
          final be = especieOrder[b.especie] ?? 3;
          if (ae != be) return ae.compareTo(be);
          return a.tipo.compareTo(b.tipo);
        });
  }

  factory R2Manifest.fromJson(Map<String, dynamic> json, String folder) {
    final stats = json['stats'] as Map<String, dynamic>;
    return R2Manifest(
      generatedAt: DateTime.parse(json['generatedAt'] as String),
      emenda: json['emenda'] as String,
      folder: folder,
      totalCharts: stats['totalCharts'] as int,
      downloaded: stats['downloaded'] as int,
      files: (json['files'] as List)
          .map((f) => R2ManifestFile.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
