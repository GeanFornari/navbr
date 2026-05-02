import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/r2_manifest.dart';
import '../providers/charts_download_provider.dart';
import '../theme/app_colors.dart';

const _tipoLabels = {
  'adc': 'ADC',
  'arc': 'ARC',
  'gmc': 'GMC',
  'iac': 'IAC',
  'lc': 'LC',
  'pdc': 'PDC',
  'sid': 'SID',
  'star': 'STAR',
  'vac': 'VAC',
  'cv': 'CV',
  'rea': 'REA',
  'reast': 'REAST',
  'reh': 'REH',
  'reul': 'REUL',
  'wac': 'WAC',
  'enrc': 'ENRC',
  'enrcl': 'ENRC L',
  'enrch': 'ENRC H',
};

const _tipoDescriptions = {
  'adc': 'Aerodrome Chart',
  'arc': 'Aerodrome Radar Chart',
  'gmc': 'Ground Movement Chart',
  'iac': 'Instrument Approach Chart',
  'lc': 'Location Chart',
  'pdc': 'Parking & Docking Chart',
  'sid': 'Standard Instrument Departure',
  'star': 'Standard Terminal Arrival',
  'vac': 'Visual Approach Chart',
  'cv': 'Carta Visual',
  'rea': 'Rota Especial',
  'reast': 'Rota Especial (Aterrissagem)',
  'reh': 'Rota Especial (Helicóptero)',
  'reul': 'Rota Especial (Ultralight)',
  'wac': 'World Aeronautical Chart',
  'enrc': 'En-Route Chart (Baixa Altitude)',
  'enrcl': 'En-Route Chart (Baixa Altitude)',
  'enrch': 'En-Route Chart (Alta Altitude)',
};

const _tipoToCategory = {
  'iac': 'Cartas de ADs',
  'sid': 'Cartas de ADs',
  'star': 'Cartas de ADs',
  'adc': 'Cartas de ADs',
  'gmc': 'Cartas de ADs',
  'pdc': 'Cartas de ADs',
  'vac': 'Cartas de ADs',
  'cv': 'Cartas de ADs',
  'lc': 'Cartas de ADs',
  'arc': 'ARC',
  'rea': 'REA',
  'reh': 'REH',
  'reul': 'REUL',
  'wac': 'WAC',
  'enrc': 'ENRC L',
  'enrcl': 'ENRC L',
  'enrch': 'ENRC H',
  'reast': 'REAST',
};

const _categoryOrder = [
  'Cartas de ADs',
  'ARC',
  'REA',
  'REH',
  'REUL',
  'WAC',
  'ENRC L',
  'ENRC H',
  'REAST',
];

class _UIGroup {
  final String key;
  final String title;
  final String subtitle;
  final List<R2ChartGroup> originalGroups;

  _UIGroup({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.originalGroups,
  });

  int get totalFiles => originalGroups.fold(0, (s, g) => s + g.files.length);
  int get totalSize => originalGroups.fold(0, (s, g) => s + g.totalSize);
}

class ChartsDownloadScreen extends ConsumerWidget {
  const ChartsDownloadScreen({super.key});

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chartsDownloadProvider);
    final notifier = ref.read(chartsDownloadProvider.notifier);

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(state, notifier),
          Expanded(child: _buildContent(state, notifier)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    ChartsDownloadState state,
    ChartsDownloadNotifier notifier,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cartas Aeronáuticas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (state.manifest != null)
                  Text(
                    'Ciclo AIRAC: ${state.manifest!.emenda}  ·  ${state.manifest!.downloaded} cartas',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: state.loading ? null : () => notifier.refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    ChartsDownloadState state,
    ChartsDownloadNotifier notifier,
  ) {
    if (state.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              'Carregando catálogo...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: AppColors.disabled),
              const SizedBox(height: 16),
              const Text(
                'Catálogo indisponível',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => notifier.refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.manifest == null) return const SizedBox.shrink();

    final byCategory = <String, List<_UIGroup>>{};

    final adGroups = <R2ChartGroup>[];
    final enrchGroups = <R2ChartGroup>[];
    final enrclGroups = <R2ChartGroup>[];
    final otherGroups = <R2ChartGroup>[];

    for (final group in state.manifest!.groups) {
      final cat = _tipoToCategory[group.tipo] ?? group.tipo.toUpperCase();
      if (cat == 'Cartas de ADs') {
        adGroups.add(group);
      } else if (group.tipo == 'enrch') {
        enrchGroups.add(group);
      } else if (group.tipo == 'enrcl' || group.tipo == 'enrc') {
        enrclGroups.add(group);
      } else {
        otherGroups.add(group);
      }
    }

    if (adGroups.isNotEmpty) {
      byCategory['Cartas de ADs'] = [
        _UIGroup(
          key: 'cartas_de_ads',
          title: 'Cartas de Aeródromos',
          subtitle: 'Todas as cartas de ADs (IAC, SID, STAR, ADC, etc)',
          originalGroups: adGroups,
        ),
      ];
    }

    if (enrclGroups.isNotEmpty) {
      byCategory['ENRC L'] = [
        _UIGroup(
          key: 'enrc_l_todas',
          title: 'ENRC L',
          subtitle: 'En-Route Chart (Baixa Altitude)',
          originalGroups: enrclGroups,
        ),
      ];
    }

    if (enrchGroups.isNotEmpty) {
      byCategory['ENRC H'] = [
        _UIGroup(
          key: 'enrc_h_todas',
          title: 'ENRC H',
          subtitle: 'En-Route Chart (Alta Altitude)',
          originalGroups: enrchGroups,
        ),
      ];
    }

    for (final group in otherGroups) {
      final cat = _tipoToCategory[group.tipo] ?? group.tipo.toUpperCase();
      final uig = _UIGroup(
        key: group.key,
        title: _tipoLabels[group.tipo] ?? group.tipo.toUpperCase(),
        subtitle: _tipoDescriptions[group.tipo] ?? '',
        originalGroups: [group],
      );
      byCategory.putIfAbsent(cat, () => []).add(uig);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final cat in _categoryOrder)
          if (byCategory[cat] != null) ...[
            _buildSectionHeader(cat),
            for (final group in byCategory[cat]!)
              _buildGroupTile(group, state, notifier),
          ],
        for (final cat in byCategory.keys)
          if (!_categoryOrder.contains(cat)) ...[
            _buildSectionHeader(cat),
            for (final group in byCategory[cat]!)
              _buildGroupTile(group, state, notifier),
          ],
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildGroupTile(
    _UIGroup uiGroup,
    ChartsDownloadState state,
    ChartsDownloadNotifier notifier,
  ) {
    int localCount = 0;
    for (final group in uiGroup.originalGroups) {
      localCount += state.localCounts[group.key] ?? 0;
    }

    final total = uiGroup.totalFiles;
    final isDownloading = state.downloading.contains(uiGroup.key);
    final progress = state.downloadProgress[uiGroup.key];
    final isComplete = localCount >= total && total > 0;
    final isPartial = localCount > 0 && localCount < total;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isComplete
                ? AppColors.success.withAlpha(80)
                : AppColors.disabled.withAlpha(50),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDownloading
                      ? AppColors.accent
                      : isComplete
                      ? AppColors.success
                      : isPartial
                      ? AppColors.warning
                      : AppColors.disabled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${uiGroup.title}  —  ${uiGroup.subtitle}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDownloading && progress != null
                          ? '${progress.$1} / ${progress.$2} arquivos'
                          : isPartial
                          ? '$localCount/$total cartas  ·  ${_formatSize(uiGroup.totalSize)}'
                          : '$total cartas  ·  ${_formatSize(uiGroup.totalSize)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isDownloading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                )
              else if (isComplete)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 22,
                )
              else
                TextButton(
                  onPressed: () => notifier.downloadGroup(
                    uiGroup.key,
                    uiGroup.originalGroups,
                    uiGroup.totalFiles,
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    isPartial ? 'Completar' : 'Baixar',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
