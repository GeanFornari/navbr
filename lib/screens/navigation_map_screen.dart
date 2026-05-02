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
  String? _lastIacPath;

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
            width: 220,
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<ChartSettingsProvider>(
      builder: (context, settings, child) {
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
          body: Stack(
            children: [
              // ── Mapa (tela cheia) ────────────────────────────────────────
              _buildMap(settings, initialBounds),

              // ── Barra superior ───────────────────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0,
                child: _buildTopBar(),
              ),

              // ── FAB de re-centralizar (acima da faixa de dados) ──────────
              if (_currentLocation != null && !_isFollowing)
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: () {
                      setState(() => _isFollowing = true);
                      _updateMapCamera();
                    },
                    backgroundColor: AppColors.accent,
                    child: const Icon(Icons.my_location, color: Colors.white),
                  ),
                ),

              // ── Faixa de dados inferior ──────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildBottomDataStrip(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Mapa
  // ---------------------------------------------------------------------------

  Widget _buildMap(ChartSettingsProvider settings, LatLngBounds? initialBounds) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCameraFit: initialBounds != null
            ? CameraFit.bounds(bounds: initialBounds, padding: const EdgeInsets.all(50))
            : null,
        onMapReady: () {
          setState(() => _isMapReady = true);
        },
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
    );
  }

  // ---------------------------------------------------------------------------
  // Barra superior
  // ---------------------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
      color: AppColors.cockpitBackground,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                _ChartSelectorButton(),
                const SizedBox(width: 8),
                _TopBarIcon(icon: Icons.route, label: 'FPL'),
                _TopBarIcon(icon: Icons.tune),
                _TopBarIcon(
                  icon: _orientation == MapOrientation.northUp
                      ? Icons.explore_outlined
                      : Icons.navigation_outlined,
                  onTap: _toggleOrientation,
                ),
                _TopBarIcon(icon: Icons.nightlight_outlined),
                const Spacer(),
                _SearchBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Faixa de dados inferior
  // ---------------------------------------------------------------------------

  Widget _buildBottomDataStrip() {
    return Container(
      color: AppColors.cockpitBackground,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const _DataColumn(label: 'Distance to Next', value: '--- nm'),
              const _StripDivider(),
              const _DataColumn(label: 'ETA Next', value: '-------'),
              const _StripDivider(),
              const _DataColumn(label: 'ETA Dest', value: '-------'),
              const _StripDivider(),
              const _DataColumn(label: 'Groundspeed', value: '0 kts'),
              const _StripDivider(),
              const _DataColumn(label: 'Flight Time', value: '00:00'),
              const _StripDivider(),
              const _DataColumn(label: 'Nearest Navaid', value: '---'),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widgets auxiliares da tela de navegação
// =============================================================================

class _ChartSelectorButton extends StatelessWidget {
  const _ChartSelectorButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cockpitSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.layers_outlined, color: Colors.white, size: 15),
          SizedBox(width: 6),
          Text(
            'WAC + IAC',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          SizedBox(width: 4),
          Icon(Icons.keyboard_arrow_down, color: Colors.white60, size: 16),
        ],
      ),
    );
  }
}

class _TopBarIcon extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback? onTap;

  const _TopBarIcon({required this.icon, this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: label != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 18),
                  const SizedBox(height: 1),
                  Text(label!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w500)),
                ],
              )
            : Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.cockpitSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          SizedBox(width: 8),
          Icon(Icons.search, color: Colors.white38, size: 16),
          SizedBox(width: 4),
          Text('Search', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}

class _StripDivider extends StatelessWidget {
  const _StripDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: AppColors.cockpitDivider);
  }
}

class _DataColumn extends StatelessWidget {
  final String label;
  final String value;

  const _DataColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.cockpitLabel, fontSize: 10),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
