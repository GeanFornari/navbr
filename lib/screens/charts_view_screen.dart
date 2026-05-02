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

import 'package:navbr/providers/icao_search_provider.dart';

/// ChartsViewScreen
/// Tela de visualização e gerenciamento de cartas aeronáuticas.
/// Possui uma barra superior estilo cockpit para busca e filtros.
///
/// Classes presentes:
/// - ChartsViewScreen: Widget principal da tela.
/// - _TopBarIcon: Widget auxiliar para ícones da barra superior.
/// - _SearchBar: Widget auxiliar para o campo de busca.
/// - _ChartResultTile: Widget para exibir cada resultado da busca.
///
/// Métodos presentes:
/// - build: Constrói a interface da tela.
/// - _buildTopBar: Constrói a barra superior escura.
/// - _buildContent: Constrói a área central com resultados ou estados vazios.

class ChartsViewScreen extends ConsumerStatefulWidget {
  const ChartsViewScreen({super.key});

  @override
  ConsumerState<ChartsViewScreen> createState() => _ChartsViewScreenState();
}

class _ChartsViewScreenState extends ConsumerState<ChartsViewScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    if (value.isNotEmpty) {
      ref.read(icaoSearchProvider.notifier).search(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.1;
    final searchState = ref.watch(icaoSearchProvider);

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
                  Expanded(
                    child: _buildContent(searchState),
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
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              const SizedBox(width: 8),
              const _TopBarIcon(icon: Icons.layers_outlined, label: 'Cartas'),
              const SizedBox(width: 8),
              const _TopBarIcon(icon: Icons.tune),
              const Spacer(),
              _SearchBar(
                controller: _searchController,
                onSubmitted: _onSearch,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(IcaoSearchState state) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: context.theme.accent,
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Buscando cartas para ${state.lastQuery}...',
              style: TextStyle(
                color: context.theme.customTextSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Ops! Ocorreu um erro',
                style: TextStyle(
                  color: context.theme.customTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.theme.customTextSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => _onSearch(_searchController.text),
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.charts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              state.lastQuery.isEmpty ? Icons.search : Icons.sentiment_dissatisfied,
              size: 64,
              color: context.theme.disabled,
            ),
            const SizedBox(height: 16),
            Text(
              state.lastQuery.isEmpty
                  ? 'Digite um ICAO para buscar cartas'
                  : 'Nenhuma carta encontrada para "${state.lastQuery}"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.theme.customTextSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text(
            'Resultados para ${state.lastQuery}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.theme.customTextPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: state.charts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final chart = state.charts[index];
              return _ChartResultTile(chart: chart);
            },
          ),
        ),
      ],
    );
  }
}

class _ChartResultTile extends StatelessWidget {
  final Map<String, String> chart;

  const _ChartResultTile({required this.chart});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.theme.customSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: context.theme.disabled.withAlpha(50),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              chart['tipo'] ?? '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        title: Text(
          chart['nome'] ?? 'Sem nome',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.theme.customTextPrimary,
          ),
        ),
        subtitle: Text(
          'Atualizado em: ${chart['data'] ?? '---'}',
          style: TextStyle(
            fontSize: 12,
            color: context.theme.customTextSecondary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.accent),
        onTap: () {
          // Ação futura: Abrir PDF ou Download
        },
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
  final TextEditingController controller;
  final Function(String) onSubmitted;

  const _SearchBar({
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150, // Aumentado para acomodar o texto
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.cockpitSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: AppColors.accent,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 8),
          hintText: 'ICAO (ex: SBGR)',
          hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: Icon(Icons.search, color: Colors.white38, size: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
