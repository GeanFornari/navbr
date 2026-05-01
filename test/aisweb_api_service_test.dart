import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:navbr/services/aisweb_api_service.dart';

void main() {
  setUpAll(() async {
    // Load the .env file from the test environment root
    await dotenv.load(fileName: ".env");
  });

  test('fetch charts from AISWEB API', () async {
    final service = AiswebApiService();
    final result = await service.getChartsForIcao('SBGR');
    
    expect(result, isNotEmpty);
    print('Found ${result.length} charts. First one:');
    print(result.first);
  });
}
