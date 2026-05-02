import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdfx/pdfx.dart';
import 'package:navbr/providers/chart_settings_provider.dart';
import 'package:navbr/services/gps_service.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';
import 'package:navbr/widgets/chart_settings_banner.dart';

enum MapOrientation { northUp, trackUp }

class IacMapScreen extends ConsumerStatefulWidget {
  final String pdfPath;
  final Map<String, double> boundingBox;

  const IacMapScreen({
    super.key,
    required this.pdfPath,
    required this.boundingBox,
  });

  @override
  ConsumerState<IacMapScreen> createState() => _IacMapScreenState();
}

class _IacMapScreenState extends ConsumerState<IacMapScreen> {
  final _gps = GpsService();
  final MapController _mapController = MapController();

  LatLng? _currentLocation;
  double? _currentBearing;
  MapOrientation _orientation = MapOrientation.northUp;
  bool _isFollowing = true;
  bool _isMapReady = false;

  String? _renderedImagePath;

  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _renderPdfToImage();

    _gps.locationStream.listen((location) {
      if (!mounted) return;

      double? bearing;
      if (_currentLocation != null) {
        if (_currentLocation!.latitude != location.latitude ||
            _currentLocation!.longitude != location.longitude) {
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
            width: 250,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-210, 45),
              child: const ChartSettingsBanner(chartType: 'IAC'),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Future<void> _renderPdfToImage() async {
    try {
      final document = await PdfDocument.openFile(widget.pdfPath);
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
        final imagePath = '${directory.path}/rendered_iac_single.png';
        await File(imagePath).writeAsBytes(pageImage.bytes);

        if (mounted) {
          setState(() => _renderedImagePath = imagePath);
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
    final settings = ref.watch(chartSettingsProvider);

    final north = widget.boundingBox['north']!;
    final south = widget.boundingBox['south']!;
    final east = widget.boundingBox['east']!;
    final west = widget.boundingBox['west']!;

    final bounds = LatLngBounds(LatLng(south, west), LatLng(north, east));

    return Scaffold(
      body: Stack(
        children: [
          _renderedImagePath == null
              ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
              : FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(bounds: bounds),
                    onMapReady: () => setState(() => _isMapReady = true),
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && _isFollowing) {
                        setState(() => _isFollowing = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.navbr',
                    ),
                    if (settings.isIacVisible)
                      OverlayImageLayer(
                        overlayImages: [
                          OverlayImage(
                            bounds: bounds,
                            imageProvider: FileImage(File(_renderedImagePath!)),
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
                        if (settings.isIacVisible)
                          Marker(
                            point: LatLng(north, east),
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

          // Barra superior com SafeArea
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                color: AppColors.cockpitBackground.withAlpha(200),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(
                        _orientation == MapOrientation.northUp
                            ? Icons.explore_outlined
                            : Icons.navigation_outlined,
                        color: Colors.white,
                      ),
                      onPressed: _toggleOrientation,
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (!_isFollowing)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() => _isFollowing = true);
                  _updateMapCamera();
                },
                backgroundColor: AppColors.accent,
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
