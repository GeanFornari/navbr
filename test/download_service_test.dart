import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:navbr/services/aisweb_api_service.dart';
import 'package:navbr/services/download_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Mock for path_provider since it needs a physical device usually
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

  test('fetch chart from AISWEB and download it', () async {
    final apiService = AiswebApiService();
    final charts = await apiService.getChartsForIcao('SBGR');
    
    expect(charts, isNotEmpty);
    
    // Pick the first IAC chart to test
    final chartToDownload = charts.firstWhere((c) => c['tipo'] == 'IAC');
    
    final downloadUrl = chartToDownload['link']!;
    final filename = '${chartToDownload['id']}.pdf';
    
    final downloadService = DownloadService();
    final filePath = await downloadService.downloadFile(downloadUrl, filename);
    
    final file = File(filePath);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
    
    print('Chart PDF downloaded successfully to: $filePath');
    
    // Cleanup
    await file.delete();
  });

  test('download GeoTIFF from GeoAISWEB', () async {
    final downloadService = DownloadService();
    // Testing with WAC_3262_SAO_PAULO
    final filePath = await downloadService.downloadGeoTiff('WAC_3262_SAO_PAULO');
    
    final file = File(filePath);
    expect(await file.exists(), isTrue);
    expect(await file.length(), greaterThan(0));
    
    print('Chart TIFF downloaded successfully to: $filePath');
    
    // Cleanup (TIFFs are huge, let's make sure we delete it)
    await file.delete();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
