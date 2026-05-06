// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:navbr/providers/icao_search_provider.dart';
import 'package:navbr/theme/app_colors.dart';
import 'package:navbr/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

/// ChartsViewScreen
/// Tela de visualização e gerenciamento de cartas aeronáuticas.
/// Possui uma barra superior estilo cockpit para busca e filtros.
///
/// Classes presentes:
/// - ChartsViewScreen: Widget principal da tela.
/// - _TopBarIcon: Widget auxiliar para ícones da barra superior.
/// - _SearchBar: Widget auxiliar para o campo de busca.
/// - _ChartResultTile: Widget para exibir cada resultado da busca.
/// - _PlateViewer: Widget para download e visualização do PDF da carta.
///
/// Métodos presentes:
/// - build: Constrói a interface da tela.
/// - _buildTopBar: Constrói a barra superior escura.
/// - _buildContent: Constrói a área central com resultados, viewer ou estados vazios.

class ChartsViewScreen extends ConsumerStatefulWidget {
  const ChartsViewScreen({super.key});

  @override
  ConsumerState<ChartsViewScreen> createState() => _ChartsViewScreenState();
}

class _ChartsViewScreenState extends ConsumerState<ChartsViewScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, String>? _selectedChart;
  final Set<String> _activeFilters = {'AD', 'STAR', 'IAC', 'SID', 'OUTRAS'};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    if (value.isNotEmpty) {
      setState(() => _selectedChart = null);
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
            _buildSidebar(sidebarWidth, searchState),
            // Área de Conteúdo Principal
            Expanded(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(child: _buildContent(searchState)),
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
              _SearchBar(controller: _searchController, onSubmitted: _onSearch),
              const SizedBox(width: 4),
              _TopBarIcon(
                icon: Icons.download_outlined,
                onTap: () => context.push('/charts/download'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(IcaoSearchState state) {
    if (_selectedChart != null) {
      return _PlateViewer(
        chart: _selectedChart!,
        onClose: () => setState(() => _selectedChart = null),
      );
    }

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
              state.lastQuery.isEmpty
                  ? Icons.search
                  : Icons.sentiment_dissatisfied,
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

    // Filtragem e Ordenação
    final filteredCharts = state.charts.where((chart) {
      final category = _getFilterCategory(chart['tipo'] ?? '');
      return _activeFilters.contains(category);
    }).toList();

    final sortedCharts = List<Map<String, String>>.from(filteredCharts);
    const order = ['ADC', 'PDC', 'VAC', 'AOC', 'STAR', 'IAC', 'SID'];
    
    sortedCharts.sort((a, b) {
      final typeA = (a['tipo'] ?? '').toUpperCase();
      final typeB = (b['tipo'] ?? '').toUpperCase();
      
      int indexA = order.indexOf(typeA);
      int indexB = order.indexOf(typeB);
      
      if (indexA == -1) indexA = 99;
      if (indexB == -1) indexB = 99;
      
      if (indexA != indexB) {
        return indexA.compareTo(indexB);
      }
      
      return (a['nome'] ?? '').compareTo(b['nome'] ?? '');
    });

    if (sortedCharts.isEmpty && state.charts.isNotEmpty) {
      return Center(
        child: Text(
          'Nenhuma carta para os filtros selecionados',
          style: TextStyle(color: context.theme.customTextSecondary),
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
            itemCount: sortedCharts.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final chart = sortedCharts[index];
              return _ChartResultTile(
                chart: chart,
                onTap: () => setState(() => _selectedChart = chart),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getFilterCategory(String type) {
    final t = type.toUpperCase();
    if (['ADC', 'PDC', 'VAC', 'AOC', 'GMC'].contains(t)) return 'AD';
    if (t == 'STAR') return 'STAR';
    if (t == 'IAC') return 'IAC';
    if (t == 'SID') return 'SID';
    return 'OUTRAS';
  }

  Widget _buildSidebar(double width, IcaoSearchState state) {
    // Só mostramos filtros se houver cartas
    if (state.charts.isEmpty) {
      return Container(width: width, color: AppColors.cockpitBackground);
    }

    // Identifica quais categorias estão presentes nos resultados
    final availableCategories = state.charts
        .map((c) => _getFilterCategory(c['tipo'] ?? ''))
        .toSet()
        .toList();
    
    // Ordena as categorias para exibição consistente
    const categoryOrder = ['AD', 'STAR', 'IAC', 'SID', 'OUTRAS'];
    availableCategories.sort((a, b) => 
        categoryOrder.indexOf(a).compareTo(categoryOrder.indexOf(b)));

    return Container(
      width: width,
      color: AppColors.cockpitBackground,
      child: Column(
        children: [
          const Spacer(),
          Text(
            'FILTROS',
            style: TextStyle(
              color: context.theme.disabled,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...availableCategories.map((cat) {
            final isSelected = _activeFilters.contains(cat);
            return _SidebarFilterItem(
              label: cat,
              isSelected: isSelected,
              onChanged: (val) {
                setState(() {
                  if (val == true) {
                    _activeFilters.add(cat);
                  } else {
                    _activeFilters.remove(cat);
                  }
                });
              },
            );
          }),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _SidebarFilterItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const _SidebarFilterItem({
    required this.label,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: 0.7,
              child: SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: isSelected,
                  onChanged: onChanged,
                  activeColor: AppColors.accent,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartResultTile extends StatelessWidget {
  final Map<String, String> chart;
  final VoidCallback onTap;

  const _ChartResultTile({required this.chart, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: context.theme.customSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: context.theme.disabled.withAlpha(50)),
      ),
      child: ListTile(
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: Container(
          width: 42,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(40),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              chart['tipo'] ?? '?',
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ),
        title: Text(
          chart['nome'] ?? 'Sem nome',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.theme.customTextPrimary,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.accent, size: 18),
        onTap: onTap,
      ),
    );
  }
}

class _PlateViewer extends StatefulWidget {
  final Map<String, String> chart;
  final VoidCallback onClose;

  const _PlateViewer({required this.chart, required this.onClose});

  @override
  State<_PlateViewer> createState() => _PlateViewerState();
}

class _PlateViewerState extends State<_PlateViewer> {
  PdfControllerPinch? _pdfController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final url = widget.chart['link']!;
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final fileName =
            '${widget.chart['id']}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        _pdfController = PdfControllerPinch(
          document: PdfDocument.openFile(file.path),
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Falha ao baixar PDF: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header do Viewer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.cockpitSurface,
            border: Border(
              bottom: BorderSide(color: context.theme.disabled.withAlpha(30)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: widget.onClose,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.chart['nome'] ?? 'Visualizando Carta',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.chart['tipo'] ?? '',
                      style: TextStyle(
                        color: context.theme.customTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Conteúdo do Viewer
        Expanded(child: _buildPdfContent()),
      ],
    );
  }

  Widget _buildPdfContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: context.theme.accent),
            const SizedBox(height: 16),
            Text(
              'Baixando carta...',
              style: TextStyle(color: context.theme.customTextSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text(
                'Não foi possível carregar a carta',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.theme.customTextSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _error = null;
                  });
                  _loadPdf();
                },
                child: const Text('Tentar Novamente'),
              ),
            ],
          ),
        ),
      );
    }

    return PdfViewPinch(
      controller: _pdfController!,
      minScale: 0.5,
      maxScale: 4.0,
      backgroundDecoration: BoxDecoration(
        color: context.theme.customBackground,
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

class _SearchBar extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSubmitted;

  const _SearchBar({required this.controller, required this.onSubmitted});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  bool _showClear = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _showClear = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final show = widget.controller.text.isNotEmpty;
    if (show != _showClear) {
      setState(() => _showClear = show);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170, // Levemente maior para o ícone de fechar
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.cockpitSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: widget.controller,
        onSubmitted: widget.onSubmitted,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: AppColors.accent,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          hintText: 'ICAO',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
          prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 16),
          suffixIcon: _showClear
              ? IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.close, color: Colors.white38, size: 16),
                  onPressed: () {
                    widget.controller.clear();
                    _onTextChanged();
                  },
                )
              : null,
          border: InputBorder.none,
        ),
      ),
    );
  }
}
