import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdfx/pdfx.dart';
import 'package:navbr/services/gps_service.dart';
import 'package:path_provider/path_provider.dart';

enum MapOrientation { northUp, trackUp }

class IacMapScreen extends StatefulWidget {
  final String pdfPath;
  final Map<String, double> boundingBox;

  const IacMapScreen({
    super.key,
    required this.pdfPath,
    required this.boundingBox,
  });

  @override
  State<IacMapScreen> createState() => _IacMapScreenState();
}

class _IacMapScreenState extends State<IacMapScreen> {
  final _gps = GpsService();
  final MapController _mapController = MapController();
  
  LatLng? _currentLocation;
  double? _currentBearing;
  MapOrientation _orientation = MapOrientation.northUp;
  bool _isFollowing = true;
  
  String? _renderedImagePath;

  @override
  void initState() {
    super.initState();
    _renderPdfToImage();
    
    _gps.locationStream.listen((location) {
      if (!mounted) return;
      
      double? bearing;
      if (_currentLocation != null) {
        if (_currentLocation!.latitude != location.latitude || _currentLocation!.longitude != location.longitude) {
          bearing = const Distance().bearing(_currentLocation!, location);
          if (bearing.isNaN) {
             bearing = null;
          } else if (bearing < 0) {
            bearing += 360.0;
          }
        }
      }

      setState(() {
        _currentLocation = location;
        if (bearing != null) _currentBearing = bearing;
      });
      
      _updateMapCamera();
    });
    _gps.start();
  }

  Future<void> _renderPdfToImage() async {
    try {
      final document = await PdfDocument.openFile(widget.pdfPath);
      final page = await document.getPage(1);
      
      // Render at a high resolution so it doesn't look blurry
      final pageImage = await page.render(
        width: page.width * 3,
        height: page.height * 3,
        format: PdfPageImageFormat.png,
      );
      
      await page.close();
      await document.close();

      if (pageImage != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/rendered_iac.png';
        final file = File(imagePath);
        await file.writeAsBytes(pageImage.bytes);
        
        setState(() {
          _renderedImagePath = imagePath;
        });
      }
    } catch (e) {
      print('Error rendering PDF: $e');
    }
  }

  void _updateMapCamera() {
    if (!_isFollowing || _currentLocation == null) return;

    double newRotation = _mapController.camera.rotation;
    
    if (_orientation == MapOrientation.trackUp && _currentBearing != null) {
      newRotation = 360 - _currentBearing!;
    } else if (_orientation == MapOrientation.northUp) {
      newRotation = 0.0;
    }

    _mapController.move(_currentLocation!, _mapController.camera.zoom);
    _mapController.rotate(newRotation);
  }

  void _toggleOrientation() {
    setState(() {
      _orientation = _orientation == MapOrientation.northUp 
        ? MapOrientation.trackUp 
        : MapOrientation.northUp;
      _isFollowing = true;
    });
    _updateMapCamera();
  }

  @override
  void dispose() {
    _gps.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final north = widget.boundingBox['north']!;
    final south = widget.boundingBox['south']!;
    final east = widget.boundingBox['east']!;
    final west = widget.boundingBox['west']!;

    // Note for PDFs: 
    // The bounds extracted are just the "map port" inside the PDF, not the full A4 page.
    // So if we slap the whole PDF into these bounds, it might scale weirdly.
    // For this PoC, we'll draw it to see how close it is.
    final bounds = LatLngBounds(
      LatLng(south, west),
      LatLng(north, east),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('IAC Moving Map'),
        actions: [
          TextButton.icon(
            onPressed: _toggleOrientation,
            icon: Icon(
              _orientation == MapOrientation.northUp ? Icons.explore : Icons.navigation,
              color: Colors.white,
            ),
            label: Text(
              _orientation == MapOrientation.northUp ? 'North Up' : 'Track Up',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
        backgroundColor: Colors.deepPurple[800],
        foregroundColor: Colors.white,
      ),
      body: _renderedImagePath == null 
        ? const Center(child: CircularProgressIndicator(semanticsLabel: 'Renderizando PDF...',))
        : FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(bounds: bounds),
          onPositionChanged: (position, hasGesture) {
            if (hasGesture && _isFollowing) {
              setState(() {
                _isFollowing = false;
              });
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.navbr',
          ),
          
          OverlayImageLayer(
            overlayImages: [
              OverlayImage(
                bounds: bounds,
                imageProvider: FileImage(File(_renderedImagePath!)),
                opacity: 0.7,
              ),
            ],
          ),

          if (_currentLocation != null)
            MarkerLayer(
              rotate: false,
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 80,
                  height: 80,
                  child: Transform.rotate(
                    angle: _orientation == MapOrientation.northUp 
                        ? (_currentBearing ?? 0) * (pi / 180) 
                        : 0.0,
                    child: const Icon(
                      Icons.airplanemode_active,
                      color: Colors.red,
                      size: 80,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFollowing = true;
          });
          _updateMapCamera();
        },
        backgroundColor: _isFollowing ? Colors.deepPurple : Colors.grey,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}