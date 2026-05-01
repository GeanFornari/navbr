import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class DownloadService {
  /// Downloads a file from the [url] and saves it locally.
  /// Returns the path to the downloaded file.
  Future<String> downloadFile(String url, String filename) async {
    // Correct URL encoding if the API returns things like '&amp;'
    String cleanUrl = url.replaceAll('&amp;', '&');
    
    // The DECEA API sometimes returns links with .gov.br which is deprecated/offline.
    // It must be .mil.br
    cleanUrl = cleanUrl.replaceAll('.gov.br', '.mil.br');
    
    try {
      final response = await http.get(Uri.parse(cleanUrl));
      
      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$filename';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        return filePath;
      } else {
        throw Exception('Failed to download file. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading file: $e');
    }
  }

  /// Downloads a GeoTIFF WAC chart from GeoAISWEB static directory.
  /// Example wacName: 'WAC_3262_SAO_PAULO'
  Future<String> downloadGeoTiff(String wacName) async {
    final url = 'https://geoaisweb.decea.mil.br/src/geotiffs/$wacName.tif';
    return downloadFile(url, '$wacName.tif');
  }
}
