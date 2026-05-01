import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:navbr/screens/wac_map_screen.dart';
import 'package:navbr/screens/iac_map_screen.dart';
import 'package:navbr/services/download_service.dart';
import 'package:navbr/services/geotiff_parser.dart';
import 'package:navbr/services/geopdf_parser.dart';
import 'package:navbr/services/aisweb_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AISBR Sandbox',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const InitializationScreen(),
    );
  }
}

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
        throw Exception('Falha ao extrair metadados da carta. Verifique o console para mais detalhes.');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('saved_wac_path', filePath);
      await prefs.setDouble('saved_wac_north', boundingBox['north']!);
      await prefs.setDouble('saved_wac_south', boundingBox['south']!);
      await prefs.setDouble('saved_wac_east', boundingBox['east']!);
      await prefs.setDouble('saved_wac_west', boundingBox['west']!);

      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WacMapScreen(
            tiffPath: filePath,
            boundingBox: boundingBox,
          ),
        ),
      );
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

      if (!mounted) return;
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => IacMapScreen(
            pdfPath: filePath,
            boundingBox: Map<String, double>.from(boundingBox),
          ),
        ),
      );
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
    return Scaffold(
      appBar: AppBar(title: const Text('AISBR PoC: Moving Map')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.map, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              if (_isLoading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(_status, textAlign: TextAlign.center),
              ] else ...[
                if (_status.isNotEmpty) Text(_status, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
                
                // WAC Section
                const Text('Cartas Raster (GeoTIFF)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_savedTiffPath != null) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => WacMapScreen(
                            tiffPath: _savedTiffPath!,
                            boundingBox: _savedTiffBoundingBox!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Abrir WAC São Paulo (Salva)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _startWacPoC,
                    icon: const Icon(Icons.download),
                    label: const Text('Baixar e Abrir WAC São Paulo'),
                  ),
                ],
                
                const SizedBox(height: 48),
                
                // IAC Section
                const Text('Cartas de Procedimento (GeoPDF)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (_savedPdfPath != null) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => IacMapScreen(
                            pdfPath: _savedPdfPath!,
                            boundingBox: _savedPdfBoundingBox!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Abrir IAC SBGR (Salva)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: _startIacPoC,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Baixar e Abrir IAC SBGR'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
