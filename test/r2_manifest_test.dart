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
