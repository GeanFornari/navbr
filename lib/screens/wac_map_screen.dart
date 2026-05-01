import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:navbr/services/gps_service.dart';

enum MapOrientation { northUp, trackUp }

class WacMapScreen extends StatefulWidget {
  final String tiffPath;
  final Map<String, double> boundingBox;

  const WacMapScreen({
    super.key,
    required this.tiffPath,
    required this.boundingBox,
  });

  @override
  State<WacMapScreen> createState() => _WacMapScreenState();
}

class _WacMapScreenState extends State<WacMapScreen> {
  final _gps = GpsService();
  final MapController _mapController = MapController();
  
  LatLng? _currentLocation;
  double? _currentBearing;
  MapOrientation _orientation = MapOrientation.northUp;
  bool _isFollowing = true;

  @override
  void initState() {
    super.initState();
    _gps.locationStream.listen((location) {
      if (!mounted) return;
      
      double? bearing;
      if (_currentLocation != null) {
        // Only calculate bearing if the location actually changed to avoid NaN
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

  void _updateMapCamera() {
    if (!_isFollowing || _currentLocation == null) return;

    double newRotation = _mapController.camera.rotation;
    
    if (_orientation == MapOrientation.trackUp && _currentBearing != null) {
      // flutter_map rotation is generally positive clockwise.
      // If we want the map to turn so that the plane points UP,
      // we must rotate the map negatively by the bearing amount.
      // E.g., if heading is 90 deg (East), map must rotate -90 deg so East is at the top.
      newRotation = 360 - _currentBearing!;
    } else if (_orientation == MapOrientation.northUp) {
      newRotation = 0.0;
    }

    // Move first, then rotate
    _mapController.move(_currentLocation!, _mapController.camera.zoom);
    _mapController.rotate(newRotation);
  }

  void _toggleOrientation() {
    setState(() {
      _orientation = _orientation == MapOrientation.northUp 
        ? MapOrientation.trackUp 
        : MapOrientation.northUp;
      _isFollowing = true; // snap back to following when toggling
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
    // NW corner (top left), SE corner (bottom right)
    final north = widget.boundingBox['north']!;
    final south = widget.boundingBox['south']!;
    final east = widget.boundingBox['east']!;
    final west = widget.boundingBox['west']!;

    final bounds = LatLngBounds(
      LatLng(south, west), // SouthWest
      LatLng(north, east), // NorthEast
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('WAC / ERC Moving Map'),
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
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCameraFit: CameraFit.bounds(bounds: bounds),
          onPositionChanged: (position, hasGesture) {
            // If the user drags the map, stop following automatically
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
                imageProvider: FileImage(File(widget.tiffPath)),
                opacity: 0.8,
              ),
            ],
          ),

          // Draw the route line between SDCO and SBBU
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  const LatLng(-23.4805, -47.4841), // SDCO
                  const LatLng(-22.2949, -49.0604), // SBBU
                ],
                color: Colors.deepPurple,
                strokeWidth: 4.0,
              ),
            ],
          ),

          if (_currentLocation != null)
            MarkerLayer(
              // rotate: false -> The marker does NOT rotate with the map. 
              // It stays aligned to the physical screen. This is crucial!
              rotate: false,
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 80,
                  height: 80,
                  child: Transform.rotate(
                    // If the marker ignores map rotation, its top is always your screen's top.
                    // In North Up (map is 0): We want it to point to Bearing.
                    // In Track Up (map is 360-Bearing): We want it to point straight UP to screen top (Angle 0)
                    // The icon default is pointing UP (0 radians).
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
        backgroundColor: _isFollowing ? Colors.blue : Colors.grey,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}

