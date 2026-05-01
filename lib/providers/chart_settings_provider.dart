// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ChartSettingsProvider
/// Gerencia as configurações de exibição das cartas, como opacidade e visibilidade.
/// 
/// Classes/Métodos presentes:
/// - ChartSettingsProvider: ChangeNotifier que mantém o estado da opacidade e visibilidade.
/// - loadSettings: Carrega as preferências do SharedPreferences.
/// - setWacOpacity: Atualiza e persiste a opacidade da WAC.
/// - setIacOpacity: Atualiza e persiste a opacidade da IAC.
/// - toggleIacVisibility: Alterna a visibilidade da camada IAC.
class ChartSettingsProvider with ChangeNotifier {
  double _wacOpacity = 0.8;
  double _iacOpacity = 0.7;
  bool _isIacVisible = true;

  double get wacOpacity => _wacOpacity;
  double get iacOpacity => _iacOpacity;
  bool get isIacVisible => _isIacVisible;

  ChartSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _wacOpacity = prefs.getDouble('wac_opacity') ?? 0.8;
    _iacOpacity = prefs.getDouble('iac_opacity') ?? 0.7;
    _isIacVisible = prefs.getBool('is_iac_visible') ?? true;
    notifyListeners();
  }

  Future<void> setWacOpacity(double value) async {
    _wacOpacity = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('wac_opacity', value);
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
