// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:navbr/providers/chart_settings_provider.dart';
import 'package:navbr/services/gps_service.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:provider/provider.dart';

enum MapOrientation { northUp, trackUp }

/// WacMapScreen
/// Tela de visualização individual da carta WAC.
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

    final bounds = LatLngBounds(
      LatLng(south, west),
      LatLng(north, east),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('WAC Moving Map'),
        actions: [
          IconButton(
            onPressed: _toggleOrientation,
            icon: Icon(
              _orientation == MapOrientation.northUp ? Icons.explore : Icons.navigation,
            ),
            tooltip: _orientation == MapOrientation.northUp ? 'Norte para Cima' : 'Rota para Cima',
          ),
        ],
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.surface,
      ),
      body: Consumer<ChartSettingsProvider>(
        builder: (context, settings, child) => FlutterMap(
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
                  imageProvider: FileImage(File(widget.tiffPath)),
                  opacity: settings.wacOpacity,
                ),
              ],
            ),

            if (_currentLocation != null)
              MarkerLayer(
                rotate: false,
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 60,
                    height: 60,
                    child: Transform.rotate(
                      angle: _orientation == MapOrientation.northUp 
                          ? (_currentBearing ?? 0) * (math.pi / 180) 
                          : 0.0,
                      child: const Icon(
                        Icons.airplanemode_active,
                        color: AppColors.error,
                        size: 60,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            _isFollowing = true;
          });
          _updateMapCamera();
        },
        backgroundColor: _isFollowing ? AppColors.accent : AppColors.disabled,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}


