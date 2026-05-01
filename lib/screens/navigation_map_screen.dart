// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:pdfx/pdfx.dart';
import 'package:navbr/services/gps_service.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:path_provider/path_provider.dart';

enum MapOrientation { northUp, trackUp }

/// NavigationMapScreen
/// Tela principal de navegação que exibe múltiplas camadas de cartas aeronáuticas
/// (WAC e IAC) sobrepostas, com suporte a Moving Map via GPS.
///
/// Classes presentes:
/// - NavigationMapScreen: Widget Stateful para a tela de mapa.
/// - _NavigationMapScreenState: Estado que gerencia a lógica de GPS e renderização de PDF.
class NavigationMapScreen extends StatefulWidget {
  final String? tiffPath;
  final Map<String, double>? tiffBoundingBox;
  final String? pdfPath;
  final Map<String, double>? pdfBoundingBox;

  const NavigationMapScreen({
    super.key,
    this.tiffPath,
    this.tiffBoundingBox,
    this.pdfPath,
    this.pdfBoundingBox,
  });

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
  bool _isRenderingPdf = false;

  @override
  void initState() {
    super.initState();
    if (widget.pdfPath != null) {
      _renderPdfToImage();
    }
    
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
    setState(() {
      _isRenderingPdf = true;
    });
    
    try {
      final document = await PdfDocument.openFile(widget.pdfPath!);
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
        final imagePath = '${directory.path}/rendered_iac_combined.png';
        final file = File(imagePath);
        await file.writeAsBytes(pageImage.bytes);
        
        if (mounted) {
          setState(() {
            _renderedIacPath = imagePath;
            _isRenderingPdf = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error rendering PDF: $e');
      if (mounted) {
        setState(() {
          _isRenderingPdf = false;
        });
      }
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
    // Calculando bounds para a câmera inicial (prioriza IAC se disponível, senão WAC)
    LatLngBounds? initialBounds;
    if (widget.pdfBoundingBox != null) {
      initialBounds = LatLngBounds(
        LatLng(widget.pdfBoundingBox!['south']!, widget.pdfBoundingBox!['west']!),
        LatLng(widget.pdfBoundingBox!['north']!, widget.pdfBoundingBox!['east']!),
      );
    } else if (widget.tiffBoundingBox != null) {
      initialBounds = LatLngBounds(
        LatLng(widget.tiffBoundingBox!['south']!, widget.tiffBoundingBox!['west']!),
        LatLng(widget.tiffBoundingBox!['north']!, widget.tiffBoundingBox!['east']!),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navegação Combinada'),
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
              
              // Camada WAC (Fundo)
              if (widget.tiffPath != null && widget.tiffBoundingBox != null)
                OverlayImageLayer(
                  overlayImages: [
                    OverlayImage(
                      bounds: LatLngBounds(
                        LatLng(widget.tiffBoundingBox!['south']!, widget.tiffBoundingBox!['west']!),
                        LatLng(widget.tiffBoundingBox!['north']!, widget.tiffBoundingBox!['east']!),
                      ),
                      imageProvider: FileImage(File(widget.tiffPath!)),
                      opacity: 0.8, // WAC geralmente é a base
                    ),
                  ],
                ),

              // Camada IAC (Sobreposta)
              if (_renderedIacPath != null && widget.pdfBoundingBox != null)
                OverlayImageLayer(
                  overlayImages: [
                    OverlayImage(
                      bounds: LatLngBounds(
                        LatLng(widget.pdfBoundingBox!['south']!, widget.pdfBoundingBox!['west']!),
                        LatLng(widget.pdfBoundingBox!['north']!, widget.pdfBoundingBox!['east']!),
                      ),
                      imageProvider: FileImage(File(_renderedIacPath!)),
                      opacity: 0.7, // Opacidade para ver a WAC por baixo
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
          
          if (_isRenderingPdf)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.accent),
                    SizedBox(height: 16),
                    Text(
                      'Renderizando Carta IAC...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
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
        backgroundColor: _isFollowing ? AppColors.accent : AppColors.disabled,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
