// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ChartSettingsProvider
/// Gerencia as configurações de exibição e os dados das cartas selecionadas.
class ChartSettingsProvider with ChangeNotifier {
  final double wacOpacity = 1.0;
  double _iacOpacity = 0.7;
  bool _isIacVisible = true;

  // Dados das cartas salvas
  String? _wacPath;
  Map<String, double>? _wacBoundingBox;
  String? _iacPath;
  Map<String, double>? _iacBoundingBox;

  double get iacOpacity => _iacOpacity;
  bool get isIacVisible => _isIacVisible;
  
  String? get wacPath => _wacPath;
  Map<String, double>? get wacBoundingBox => _wacBoundingBox;
  String? get iacPath => _iacPath;
  Map<String, double>? get iacBoundingBox => _iacBoundingBox;

  ChartSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _iacOpacity = prefs.getDouble('iac_opacity') ?? 0.7;
    _isIacVisible = prefs.getBool('is_iac_visible') ?? true;
    
    // Carregar caminhos das cartas
    _wacPath = prefs.getString('saved_wac_path');
    if (_wacPath != null) {
      _wacBoundingBox = {
        'north': prefs.getDouble('saved_wac_north') ?? 0.0,
        'south': prefs.getDouble('saved_wac_south') ?? 0.0,
        'east': prefs.getDouble('saved_wac_east') ?? 0.0,
        'west': prefs.getDouble('saved_wac_west') ?? 0.0,
      };
    }

    _iacPath = prefs.getString('saved_iac_path');
    if (_iacPath != null) {
      _iacBoundingBox = {
        'north': prefs.getDouble('saved_iac_north') ?? 0.0,
        'south': prefs.getDouble('saved_iac_south') ?? 0.0,
        'east': prefs.getDouble('saved_iac_east') ?? 0.0,
        'west': prefs.getDouble('saved_iac_west') ?? 0.0,
      };
    }

    notifyListeners();
  }

  Future<void> refreshCharts() async {
    await _loadSettings();
  }

  Future<void> setIacOpacity(double value) async {
    _iacOpacity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('iac_opacity', value);
  }

  Future<void> toggleIacVisibility(bool value) async {
    _isIacVisible = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_iac_visible', value);
  }
}
