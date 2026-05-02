// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:navbr/theme/app_theme.dart';

/// ChartsViewScreen
/// Tela de visualização e gerenciamento de cartas aeronáuticas.
/// Possui uma barra superior estilo cockpit para busca e filtros.
///
/// Classes presentes:
/// - ChartsViewScreen: Widget principal da tela.
/// - _TopBarIcon: Widget auxiliar para ícones da barra superior.
/// - _SearchBar: Widget auxiliar para o campo de busca.
///
/// Métodos presentes:
/// - build: Constrói a interface da tela.
/// - _buildTopBar: Constrói a barra superior escura.

class ChartsViewScreen extends ConsumerWidget {
  const ChartsViewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.1;

    return Scaffold(
      backgroundColor: context.theme.customBackground,
      body: SafeArea(
        child: Row(
          children: [
            // Menu Lateral Esquerdo (Sidebar)
            Container(
              width: sidebarWidth,
              color: AppColors.cockpitBackground,
              child: const Column(
                children: [
                  // Conteúdo futuro do menu lateral
                ],
              ),
            ),
            // Área de Conteúdo Principal
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  const Expanded(
                    child: Center(
                      child: SizedBox(), // Vazio por enquanto conforme solicitado
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: AppColors.cockpitBackground,
      child: const SizedBox(
        height: 48,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Placeholder para o seletor de cartas se necessário futuramente
              SizedBox(width: 8),
              _TopBarIcon(icon: Icons.layers_outlined, label: 'Cartas'),
              const SizedBox(width: 8),
              _TopBarIcon(icon: Icons.tune),
              Spacer(),
              _SearchBar(),
            ],
          ),
        ),
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
                  Text(
                    label!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
