import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:navbr/services/download_service.dart';
import 'package:navbr/services/geotiff_parser.dart';
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

  test('extract GeoTIFF metadata', () async {
    final downloadService = DownloadService();
    // Download a smaller WAC to test parsing quickly if possible, or just the one we know
    print('Downloading WAC...');
    final filePath = await downloadService.downloadGeoTiff('WAC_3262_SAO_PAULO');
    
    print('Parsing TIFF...');
    final parser = GeoTiffParser();
    await parser.extractBoundingBox(filePath);
    
    // Cleanup
    await File(filePath).delete();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
