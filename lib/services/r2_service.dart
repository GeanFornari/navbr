import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../models/r2_manifest.dart';

class R2Service {
  static const _baseUrl = 'https://pub-cca17949fcc04b1ca9e632ae8b19d69c.r2.dev';

  Future<R2Latest> fetchLatest() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/latest.json'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('latest.json não disponível (HTTP ${response.statusCode})');
    }
    return R2Latest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<R2Manifest> fetchManifest(String folder) async {
    final response = await http
        .get(Uri.parse('$_baseUrl/$folder/manifest.json'))
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('manifest.json não disponível (HTTP ${response.statusCode})');
    }
    return R2Manifest.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      folder,
    );
  }

  Future<String> get _chartsBaseDir async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/charts';
  }

  Future<Map<String, int>> countAllLocalFiles(
    String folder,
    List<R2ChartGroup> groups,
  ) async {
    final base = await _chartsBaseDir;
    final counts = <String, int>{};
    for (final group in groups) {
      final dir = Directory('$base/$folder/${group.especie}/${group.tipo}');
      if (!await dir.exists()) {
        counts[group.key] = 0;
      } else {
        final entities = await dir.list().toList();
        counts[group.key] = entities.whereType<File>().length;
      }
    }
    return counts;
  }

  Future<int> countLocalFiles(String folder, R2ChartGroup group) async {
    final base = await _chartsBaseDir;
    final dir = Directory('$base/$folder/${group.especie}/${group.tipo}');
    if (!await dir.exists()) return 0;
    final entities = await dir.list().toList();
    return entities.whereType<File>().length;
  }

  Future<void> downloadFile(
    String folder,
    R2ManifestFile file, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final base = await _chartsBaseDir;
    final localPath = '$base/$folder/${file.path}';
    final localFile = File(localPath);

    if (await localFile.exists() && await localFile.length() == file.size) {
      return;
    }

    await Directory(localPath.substring(0, localPath.lastIndexOf('/')))
        .create(recursive: true);

    final request = http.Request('GET', Uri.parse('$_baseUrl/$folder/${file.path}'));
    final response = await request.send();
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} para ${file.path}');
    }

    final sink = localFile.openWrite();
    int received = 0;
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      onProgress?.call(received, file.size);
    }
    await sink.close();
  }

  Future<void> deleteFolder(String folder) async {
    final base = await _chartsBaseDir;
    final dir = Directory('$base/$folder');
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}
