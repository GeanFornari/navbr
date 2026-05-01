// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:navbr/screens/wac_map_screen.dart';
import 'package:navbr/screens/iac_map_screen.dart';
import 'package:navbr/screens/navigation_map_screen.dart';
import 'package:navbr/services/download_service.dart';
import 'package:navbr/services/geotiff_parser.dart';
import 'package:navbr/services/geopdf_parser.dart';
import 'package:navbr/services/aisweb_api_service.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

/// MyApp
/// Widget raiz da aplicação que configura o tema global baseado em AppColors.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AISBR Sandbox',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.surface,
        ),
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.surface,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const InitializationScreen(),
    );
  }
}

/// InitializationScreen
/// Tela de boas-vindas e gerenciamento de download de cartas.
/// 
/// Classes/Métodos presentes:
/// - _InitializationScreenState: Gerencia o estado de download e caminhos dos arquivos.
/// - _checkSavedCharts: Verifica se as cartas já foram baixadas e salvas no SharedPreferences.
/// - _startWacPoC: Inicia o download e processamento da carta WAC.
/// - _startIacPoC: Inicia o download e processamento da carta IAC.
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  bool _isLoading = false;
  String _status = '';
  
  String? _savedTiffPath;
  Map<String, double>? _savedTiffBoundingBox;
  
  String? _savedPdfPath;
  Map<String, double>? _savedPdfBoundingBox;

  @override
  void initState() {
    super.initState();
    _checkSavedCharts();
  }

  Future<void> _checkSavedCharts() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check WAC
    final savedTiffPath = prefs.getString('saved_wac_path');
    if (savedTiffPath != null && File(savedTiffPath).existsSync()) {
      final north = prefs.getDouble('saved_wac_north');
      final south = prefs.getDouble('saved_wac_south');
      final east = prefs.getDouble('saved_wac_east');
      final west = prefs.getDouble('saved_wac_west');

      if (north != null && south != null && east != null && west != null) {
        setState(() {
          _savedTiffPath = savedTiffPath;
          _savedTiffBoundingBox = {
            'north': north,
            'south': south,
            'east': east,
            'west': west,
          };
        });
      }
    }
    
    // Check IAC
    final savedPdfPath = prefs.getString('saved_iac_path');
    if (savedPdfPath != null && File(savedPdfPath).existsSync()) {
      final north = prefs.getDouble('saved_iac_north');
      final south = prefs.getDouble('saved_iac_south');
      final east = prefs.getDouble('saved_iac_east');
      final west = prefs.getDouble('saved_iac_west');

      if (north != null && south != null && east != null && west != null) {
        setState(() {
          _savedPdfPath = savedPdfPath;
          _savedPdfBoundingBox = {
            'north': north,
            'south': south,
            'east': east,
            'west': west,
          };
        });
      }
    }
  }

  Future<void> _startWacPoC() async {
    setState(() {
      _isLoading = true;
      _status = 'Baixando Carta WAC de São Paulo (pode demorar um pouco)...';
    });

    try {
      final downloadService = DownloadService();
      final filePath = await downloadService.downloadGeoTiff('WAC_3262_SAO_PAULO');

      setState(() {
        _status = 'Extraindo metadados matemáticos (Lat/Lon)...';
      });

      final parser = GeoTiffParser();
      final boundingBox = await parser.extractBoundingBox(filePath);

      if (boundingBox == null) {
        throw Exception('Falha ao extrair metadados da carta.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_wac_path', filePath);
      await prefs.setDouble('saved_wac_north', boundingBox['north']!);
      await prefs.setDouble('saved_wac_south', boundingBox['south']!);
      await prefs.setDouble('saved_wac_east', boundingBox['east']!);
      await prefs.setDouble('saved_wac_west', boundingBox['west']!);

      _checkSavedCharts(); // Refresh paths
    } catch (e) {
      setState(() {
        _status = 'Erro: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _startIacPoC() async {
    setState(() {
      _isLoading = true;
      _status = 'Buscando lista de cartas de SBGR...';
    });

    try {
      final apiService = AiswebApiService();
      final charts = await apiService.getChartsForIcao('SBGR');
      final chartToDownload = charts.firstWhere((c) => c['tipo'] == 'IAC');
      
      setState(() {
        _status = 'Baixando ${chartToDownload['nome']}...';
      });
      
      final downloadService = DownloadService();
      final downloadUrl = chartToDownload['link']!;
      final filename = '${chartToDownload['id']}.pdf';
      final filePath = await downloadService.downloadFile(downloadUrl, filename);

      setState(() {
        _status = 'Extraindo metadados OGC do PDF...';
      });

      final parser = GeoPdfParser();
      final boundingBox = await parser.extractGeoData(filePath);

      if (boundingBox == null) {
        throw Exception('Falha ao extrair metadados OGC do PDF.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_iac_path', filePath);
      await prefs.setDouble('saved_iac_north', boundingBox['north']!);
      await prefs.setDouble('saved_iac_south', boundingBox['south']!);
      await prefs.setDouble('saved_iac_east', boundingBox['east']!);
      await prefs.setDouble('saved_iac_west', boundingBox['west']!);

      _checkSavedCharts(); // Refresh paths
    } catch (e) {
      setState(() {
        _status = 'Erro: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canCombine = _savedTiffPath != null && _savedPdfPath != null;

    return Scaffold(
      appBar: AppBar(title: const Text('AISBR PoC: Moving Map')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 80, color: AppColors.accent),
              const SizedBox(height: 16),
              const Text(
                'NAV BR',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 32),
              
              if (_isLoading) ...[
                const CircularProgressIndicator(color: AppColors.accent),
                const SizedBox(height: 24),
                Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              ] else ...[
                if (_status.contains('Erro')) 
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_status, style: const TextStyle(color: AppColors.error)),
                  ),
                
                // Combined Option
                if (canCombine) ...[
                  _buildCombinedCard(),
                  const SizedBox(height: 24),
                ],

                // WAC Card
                _buildChartCard(
                  title: 'Carta WAC (GeoTIFF)',
                  subtitle: 'World Aeronautical Chart - Raster',
                  path: _savedTiffPath,
                  onDownload: _startWacPoC,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WacMapScreen(
                          tiffPath: _savedTiffPath!,
                          boundingBox: _savedTiffBoundingBox!,
                        ),
                      ),
                    );
                  },
                  color: AppColors.wacButton,
                ),
                
                const SizedBox(height: 16),
                
                // IAC Card
                _buildChartCard(
                  title: 'Carta IAC (GeoPDF)',
                  subtitle: 'Instrument Approach Chart - PDF',
                  path: _savedPdfPath,
                  onDownload: _startIacPoC,
                  onOpen: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IacMapScreen(
                          pdfPath: _savedPdfPath!,
                          boundingBox: _savedPdfBoundingBox!,
                        ),
                      ),
                    );
                  },
                  color: AppColors.iacButton,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCombinedCard() {
    return Card(
      elevation: 8,
      shadowColor: AppColors.combinedButton.withAlpha(80),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.combinedButton, width: 2)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [AppColors.combinedButton, AppColors.accent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.layers, color: Colors.white),
                SizedBox(width: 8),
                Text('MAPA COMBINADO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Visualize a IAC sobreposta à WAC no Moving Map.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NavigationMapScreen(
                      tiffPath: _savedTiffPath,
                      tiffBoundingBox: _savedTiffBoundingBox,
                      pdfPath: _savedPdfPath,
                      pdfBoundingBox: _savedPdfBoundingBox,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map),
              label: const Text('ABRIR NAVEGAÇÃO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.combinedButton,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required String? path,
    required VoidCallback onDownload,
    required VoidCallback onOpen,
    required Color color,
  }) {
    final bool isSaved = path != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isSaved ? Icons.check_circle : Icons.download_for_offline, color: isSaved ? AppColors.success : AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: isSaved
                  ? ElevatedButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Abrir Carta'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: onDownload,
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar Agora'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

