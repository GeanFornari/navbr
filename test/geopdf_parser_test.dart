import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:navbr/services/aisweb_api_service.dart';
import 'package:navbr/services/download_service.dart';
import 'package:navbr/services/geopdf_parser.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
    PathProviderPlatform.instance = MockPathProviderPlatform();
  });

  test('extract GeoPDF metadata from IAC chart', () async {
    final apiService = AiswebApiService();
    final charts = await apiService.getChartsForIcao('SBGR');
    
    // Pick an IAC
    final chartToDownload = charts.firstWhere((c) => c['tipo'] == 'IAC');
    final downloadUrl = chartToDownload['link']!;
    final filename = '${chartToDownload['id']}.pdf';
    
    final downloadService = DownloadService();
    print('Downloading IAC PDF: ${chartToDownload['nome']}');
    final filePath = await downloadService.downloadFile(downloadUrl, filename);
    
    print('Parsing PDF...');
    final parser = GeoPdfParser();
    await parser.extractGeoData(filePath);
    
    await File(filePath).delete();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
