import 'package:flutter/material.dart';

class AppTheme {
  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1A237E),
        secondary: Color(0xFF303F9F),
        surface: Colors.white,
        error: Color(0xFFE53935),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1A237E),
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF121212),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white54,
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF8C9EFF), // Mais claro para dark mode
        secondary: Color(0xFF536DFE),
        surface: Color(0xFF1E1E1E), // Cinza escuro para cards
        error: Color(0xFFEF5350),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onError: Colors.black,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212), // Fundo principal
      useMaterial3: true,
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 0,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF000000), // Mais escuro que o background
        selectedItemColor: Color(0xFF8C9EFF), // Primary light
        unselectedItemColor: Colors.white54,
      ),
    );
  }
}

// Extensão para facilitar o acesso às cores que variam com o tema, 
// sem quebrar os lugares onde você não pode usar `Theme.of(context)`
extension ThemeColors on ThemeData {
  Color get customBackground => brightness == Brightness.light ? const Color(0xFFF5F7FA) : const Color(0xFF121212);
  Color get customSurface => brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get customTextPrimary => brightness == Brightness.light ? const Color(0xFF1A237E) : Colors.white;
  Color get customTextSecondary => brightness == Brightness.light ? const Color(0xFF546E7A) : const Color(0xFF9E9E9E);
  
  // Cores que NÃO mudam com o tema
  Color get accent => const Color(0xFF00B0FF);
  Color get success => const Color(0xFF43A047);
  Color get warning => const Color(0xFFFB8C00);
  Color get disabled => const Color(0xFFBDBDBD);
  
  Color get cockpitBackground => const Color(0xFF1C1C1E);
  Color get cockpitSurface => const Color(0xFF2C2C2E);
  Color get cockpitDivider => const Color(0xFF3A3A3C);
  Color get cockpitLabel => const Color(0xFF8E8E93);
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
}
