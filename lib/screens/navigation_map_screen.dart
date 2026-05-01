// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdfx/pdfx.dart';
import 'package:navbr/providers/chart_settings_provider.dart';
import 'package:navbr/services/gps_service.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:navbr/widgets/chart_settings_banner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

enum MapOrientation { northUp, trackUp }

/// NavigationMapScreen
/// Tela principal de navegação que consome dados do ChartSettingsProvider.
class NavigationMapScreen extends StatefulWidget {
  const NavigationMapScreen({super.key});

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen> {
  final _gps = GpsService();
  final MapController _mapController = MapController();
  
  LatLng? _currentLocation;
  double? _currentBearing;
  MapOrientation _orientation = MapOrientation.northUp;
  bool _isFollowing = true;
  
  String? _renderedIacPath;
  String? _lastIacPath; // Para detectar mudança e re-renderizar

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isMapReady = false;

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

  void _toggleSettingsOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry?.remove();
      _overlayEntry = null;
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          GestureDetector(
            onTap: () {
              _overlayEntry?.remove();
              _overlayEntry = null;
            },
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            width: 220,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-210, 45),
              child: const ChartSettingsBanner(
                chartType: 'IAC',
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _renderPdfToImage(String pdfPath) async {
    try {
      final document = await PdfDocument.openFile(pdfPath);
      final page = await document.getPage(1);
      
      final pageImage = await page.render(
        width: page.width * 3,
        height: page.height * 3,
        format: PdfPageImageFormat.png,
      );
      
      await page.close();
      await document.close();

      if (pageImage != null) {
        final directory = await getApplicationDocumentsDirectory();
        final imagePath = '${directory.path}/rendered_iac_nav.png';
        final file = File(imagePath);
        await file.writeAsBytes(pageImage.bytes);
        
        if (mounted) {
          setState(() {
            _renderedIacPath = imagePath;
            _lastIacPath = pdfPath;
          });
        }
      }
    } catch (e) {
      debugPrint('Error rendering PDF: $e');
    }
  }

  void _updateMapCamera() {
    if (!_isMapReady || !_isFollowing || _currentLocation == null) return;

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
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChartSettingsProvider>(
      builder: (context, settings, child) {
        // Detectar se a IAC mudou e re-renderizar
        if (settings.iacPath != null && settings.iacPath != _lastIacPath) {
          _renderPdfToImage(settings.iacPath!);
        }

        LatLngBounds? initialBounds;
        if (settings.wacPath != null && settings.wacBoundingBox != null) {
          initialBounds = LatLngBounds(
            LatLng(settings.wacBoundingBox!['south']!, settings.wacBoundingBox!['west']!),
            LatLng(settings.wacBoundingBox!['north']!, settings.wacBoundingBox!['east']!),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Navegação Map/Nav'),
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
          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCameraFit: initialBounds != null 
                    ? CameraFit.bounds(bounds: initialBounds, padding: const EdgeInsets.all(50))
                    : null,
                  onMapReady: () {
                    setState(() {
                      _isMapReady = true;
                    });
                  },
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
                  
                  if (settings.wacPath != null && settings.wacBoundingBox != null)
                    OverlayImageLayer(
                      overlayImages: [
                        OverlayImage(
                          bounds: LatLngBounds(
                            LatLng(settings.wacBoundingBox!['south']!, settings.wacBoundingBox!['west']!),
                            LatLng(settings.wacBoundingBox!['north']!, settings.wacBoundingBox!['east']!),
                          ),
                          imageProvider: FileImage(File(settings.wacPath!)),
                          opacity: settings.wacOpacity,
                        ),
                      ],
                    ),

                  if (settings.isIacVisible && _renderedIacPath != null && settings.iacBoundingBox != null)
                    OverlayImageLayer(
                      overlayImages: [
                        OverlayImage(
                          bounds: LatLngBounds(
                            LatLng(settings.iacBoundingBox!['south']!, settings.iacBoundingBox!['west']!),
                            LatLng(settings.iacBoundingBox!['north']!, settings.iacBoundingBox!['east']!),
                          ),
                          imageProvider: FileImage(File(_renderedIacPath!)),
                          opacity: settings.iacOpacity,
                        ),
                      ],
                    ),

                  MarkerLayer(
                    rotate: false,
                    markers: [
                      if (_currentLocation != null)
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
                      
                      if (settings.isIacVisible && settings.iacBoundingBox != null)
                        Marker(
                          point: LatLng(
                            settings.iacBoundingBox!['north']!,
                            settings.iacBoundingBox!['east']!,
                          ),
                          width: 30,
                          height: 30,
                          child: CompositedTransformTarget(
                            link: _layerLink,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface.withAlpha(220),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.primary, width: 1.5),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.settings, color: AppColors.primary, size: 18),
                                onPressed: _toggleSettingsOverlay,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              
              if (_currentLocation != null && !_isFollowing)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _isFollowing = true;
                      });
                      _updateMapCamera();
                    },
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
