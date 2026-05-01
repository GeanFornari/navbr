import 'dart:io';

class GeoPdfParser {
  /// Extracts the geospatial metadata from a GeoPDF file.
  /// GeoPDFs store OGC metadata inside PDF dictionaries, usually looking like:
  /// /Measure << /Type /Measure /Subtype /GEO ... /GPTS [x y] /LPTS [lat lon] >>
  Future<Map<String, dynamic>?> extractGeoData(String filePath) async {
    try {
      final file = File(filePath);
      // As a raw approach since most Dart PDF parsers don't support the raw OGC dictionaries easily
      // We will read the file as a string (it's binary but we can regex ascii parts)
      final bytes = await file.readAsBytes();
      final content = String.fromCharCodes(bytes);

      // We need to look for /GPTS (Geometry Points in Pixels/PDF units)
      // and /LPTS (Latitude/Longitude Points)
      
      // Let's do a basic scan to see if we find these markers
      final hasMeasure = content.contains('/Measure');
      final hasGpts = content.contains('/GPTS');
      final hasLpts = content.contains('/LPTS');
      
      print('PDF Scan - Measure: $hasMeasure, GPTS: $hasGpts, LPTS: $hasLpts');

      if (hasGpts && hasLpts) {
        // Regex to extract the arrays
        final gptsMatch = RegExp(r'/GPTS\s*\[(.*?)\]').firstMatch(content);
        final lptsMatch = RegExp(r'/LPTS\s*\[(.*?)\]').firstMatch(content);
        
        if (gptsMatch != null && lptsMatch != null) {
          final gptsRaw = gptsMatch.group(1)!;
          final lptsRaw = lptsMatch.group(1)!;
          
          final gptsParts = gptsRaw.trim().split(RegExp(r'\s+')).map((e) => double.tryParse(e) ?? 0.0).toList();
          final lptsParts = lptsRaw.trim().split(RegExp(r'\s+')).map((e) => double.tryParse(e) ?? 0.0).toList();

          // LPTS usually contains [Lat1, Lon1, Lat2, Lon2, ...]
          // GPTS usually contains percentage offsets [Y1, X1, Y2, X2, ...] from the bottom-left of the page.
          // Wait, sometimes GPTS is Lat/Lon and LPTS is X/Y depending on the exporter. Let's check the test output!
          // Output was: 
          // GPTS: -23.75 -46.68 -23.75 -46.22 ... -> These are definitely LAT / LON!
          // LPTS: 0.1 0.1 0.9 0.1 0.9 0.9 0.1 0.9 -> These are percentages of the page (from 0.0 to 1.0)!
          
          // Let's extract the bounding box from the Lat/Lon array (GPTS in this case)
          if (gptsParts.length >= 8 && lptsParts.length >= 8) {
             double minLat = 90.0;
             double maxLat = -90.0;
             double minLon = 180.0;
             double maxLon = -180.0;
             
             for (int i = 0; i < gptsParts.length; i += 2) {
                final lat = gptsParts[i];
                final lon = gptsParts[i+1];
                if (lat < minLat) minLat = lat;
                if (lat > maxLat) maxLat = lat;
                if (lon < minLon) minLon = lon;
                if (lon > maxLon) maxLon = lon;
             }
             
             // The viewport of the map inside the PDF
             // Note: The map doesn't cover the full A4 page. 
             // LPTS tells us where on the physical page these coordinates apply.
             // For example, if min X percentage is 0.1 (10%), it means the map starts 10% inward.
             // For standard OverlayImage in flutter_map, we can crop the PDF image to these margins,
             // or mathematically offset the bounds.
             
             print('GeoPDF Extracted!');
             print('Lat: $minLat to $maxLat');
             print('Lon: $minLon to $maxLon');
             
             return {
                'south': minLat,
                'north': maxLat,
                'west': minLon,
                'east': maxLon,
             };
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Error parsing GeoPDF: $e');
      return null;
    }
  }
}
