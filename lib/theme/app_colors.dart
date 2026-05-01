// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter/material.dart';

/// AppColors
/// Classe que centraliza todas as cores do aplicativo para garantir consistência visual
/// e seguir as melhores práticas de design premium.
///
/// Classes presentes:
/// - AppColors: Contém as definições de cores estáticas e constantes.
class AppColors {
  // Cores Base
  static const Color primary = Color(0xFF1A237E); // Indigo escuro
  static const Color secondary = Color(0xFF303F9F); // Indigo médio
  static const Color accent = Color(0xFF00B0FF); // Light Blue accent
  static const Color black = Color(0xFF121212); // Preto premium/escuro
  
  // Background e Superfícies
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;
  
  // Texto
  static const Color textPrimary = Color(0xFF1A237E);
  static const Color textSecondary = Color(0xFF546E7A);
  
  // Cores de Status
  static const Color success = Color(0xFF43A047);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFB8C00);
  
  // Overlays de Mapa (Com opacidade pré-calculada para evitar .withOpacity())
  // WAC: 80% opacidade -> 0xCC
  static const Color wacOverlayTint = Color(0xCCFFFFFF); 
  
  // IAC: 70% opacidade -> 0xB3
  static const Color iacOverlayTint = Color(0xB3FFFFFF);
  
  // Cores para Botões e Ícones
  static const Color wacButton = Color(0xFF2E7D32); // Verde WAC
  static const Color iacButton = Color(0xFF6A1B9A); // Roxo IAC
  static const Color combinedButton = Color(0xFF0277BD); // Azul Combinado
  
  // Tons de cinza para estados desabilitados
  static const Color disabled = Color(0xFFBDBDBD);
}
