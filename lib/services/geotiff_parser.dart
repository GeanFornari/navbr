import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class GeoTiffParser {
  /// Extracts the geospatial metadata from a GeoTIFF file via raw binary parsing.
  Future<Map<String, double>?> extractBoundingBox(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      
      // We will still use image decoder to get the width/height
      final decoder = img.TiffDecoder();
      final imageInfo = decoder.startDecode(bytes);
      
      if (imageInfo == null) {
        throw Exception('Failed to decode TIFF headers');
      }

      final width = imageInfo.width.toDouble();
      final height = imageInfo.height.toDouble();
      
      // Let's implement a minimal TIFF IFD scanner to find tags 33922 and 33550
      final data = ByteData.view(bytes.buffer);
      
      // Read endianness (first 2 bytes: 'II' = little, 'MM' = big)
      final isLittleEndian = bytes[0] == 0x49 && bytes[1] == 0x49;
      
      // Read offset to first IFD (bytes 4-7)
      var ifdOffset = isLittleEndian ? data.getUint32(4, Endian.little) : data.getUint32(4, Endian.big);
      
      List<double>? tiepoints;
      List<double>? pixelScale;
      List<double>? transformationMatrix;
      
      // Parse IFD
      final numDirEntries = isLittleEndian ? data.getUint16(ifdOffset, Endian.little) : data.getUint16(ifdOffset, Endian.big);
      ifdOffset += 2;
      
      for (var i = 0; i < numDirEntries; i++) {
        final tag = isLittleEndian ? data.getUint16(ifdOffset, Endian.little) : data.getUint16(ifdOffset, Endian.big);
        // field type (unused — only tag, count, and valueOffset are needed)
        data.getUint16(ifdOffset + 2, isLittleEndian ? Endian.little : Endian.big);
        final count = isLittleEndian ? data.getUint32(ifdOffset + 4, Endian.little) : data.getUint32(ifdOffset + 4, Endian.big);
        final valueOffset = isLittleEndian ? data.getUint32(ifdOffset + 8, Endian.little) : data.getUint32(ifdOffset + 8, Endian.big);
        
        if (tag == 33922) { // ModelTiepointTag
          tiepoints = _readDoubles(data, valueOffset, count, isLittleEndian);
        } else if (tag == 33550) { // ModelPixelScaleTag
          pixelScale = _readDoubles(data, valueOffset, count, isLittleEndian);
        } else if (tag == 34264) { // ModelTransformationTag
           transformationMatrix = _readDoubles(data, valueOffset, count, isLittleEndian);
        } else if (tag == 34735) { // GeoKeyDirectoryTag (just a hint we are in a GeoTIFF)
           // It exists, we can use this to know for sure it's a GeoTIFF
           print('Found GeoKeyDirectoryTag');
        }
        
        ifdOffset += 12;
      }
      
      double? north, south, east, west;

      if (tiepoints != null && tiepoints.length >= 6 && pixelScale != null && pixelScale.length >= 2) {
        final originLon = tiepoints[3];
        final originLat = tiepoints[4];
        
        final scaleX = pixelScale[0];
        final scaleY = pixelScale[1]; 
        
        west = originLon;
        east = originLon + (width * scaleX);
        north = originLat;
        south = originLat - (height * scaleY); 
        
      } else if (transformationMatrix != null && transformationMatrix.length == 16) {
        // ModelTransformationTag is a 4x4 matrix (16 doubles)
        // [ a  b  c  Tx ]
        // [ d  e  f  Ty ]
        // [ g  h  i  Tz ]
        // [ 0  0  0  1  ]
        // Geographic X (Lon) = a*PixelX + b*PixelY + c*PixelZ + Tx
        // Geographic Y (Lat) = d*PixelX + e*PixelY + f*PixelZ + Ty
        
        final a = transformationMatrix[0];
        final b = transformationMatrix[1];
        final tx = transformationMatrix[3];
        
        final d = transformationMatrix[4];
        final e = transformationMatrix[5];
        final ty = transformationMatrix[7];

        // Origin (Pixel X=0, Y=0)
        final originLon = tx;
        final originLat = ty;
        
        // Bottom Right (Pixel X=width, Y=height)
        final endLon = a * width + b * height + tx;
        final endLat = d * width + e * height + ty;

        west = originLon;
        north = originLat;
        east = endLon;
        south = endLat;
      }
      
      if (north != null && south != null && east != null && west != null) {
        print('GeoTIFF Extracted!');
        print('Top Left (NW): $north, $west');
        print('Bottom Right (SE): $south, $east');
        
        return {
          'north': north,
          'west': west,
          'south': south,
          'east': east,
        };
      } else {
         print('Could not find necessary GeoTIFF tags.');
         print('tiepoints found: ${tiepoints != null}');
         print('pixelScale found: ${pixelScale != null}');
         print('transformationMatrix found: ${transformationMatrix != null}');
         return null;
      }
    } catch (e) {
      print('Error parsing GeoTIFF: $e');
      return null;
    }
  }
  
  List<double> _readDoubles(ByteData data, int offset, int count, bool isLittleEndian) {
    List<double> result = [];
    for (int i = 0; i < count; i++) {
      // Type 12 in TIFF is DOUBLE (8 bytes)
      final val = isLittleEndian ? data.getFloat64(offset + (i * 8), Endian.little) : data.getFloat64(offset + (i * 8), Endian.big);
      result.add(val);
    }
    return result;
  }
}
