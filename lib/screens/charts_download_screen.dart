import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/r2_manifest.dart';
import '../providers/charts_download_provider.dart';
import '../theme/app_theme.dart';

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
  'ccvRea': 'CCV REA',
  'ccvReh': 'CCV REH',
  'rea': 'REA',
  'reast': 'REAST',
  'reh': 'REH',
  'wac': 'WAC',
  'enrc': 'ENRC',
  'enrcl': 'ENRC L',
  'enrch': 'ENRC H',
  'enrc_l': 'ENRC L',
  'enrc_h': 'ENRC H',
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
  'ccvRea': 'Cobertura VFR — Rota Especial (Área)',
  'ccvReh': 'Cobertura VFR — Rota Especial (Helicóptero)',
  'rea': 'REA — Rota Especial (Área)',
  'reast': 'REAST — Rota Especial (Aterrissagem)',
  'reh': 'REH — Rota Especial (Helicóptero)',
  'wac': 'World Aeronautical Chart',
  'enrc': 'En-Route Chart',
  'enrcl': 'En-Route Chart (Baixa Altitude)',
  'enrch': 'En-Route Chart (Alta Altitude)',
  'enrc_l': 'En-Route Chart (Baixa Altitude)',
  'enrc_h': 'En-Route Chart (Alta Altitude)',
};

const _tipoToCategory = {
  'iac': 'Cartas de Aeródromos',
  'sid': 'Cartas de Aeródromos',
  'star': 'Cartas de Aeródromos',
  'adc': 'Cartas de Aeródromos',
  'gmc': 'Cartas de Aeródromos',
  'pdc': 'Cartas de Aeródromos',
  'vac': 'Cartas de Aeródromos',
  'cv': 'Cartas de Aeródromos',
  'lc': 'Cartas de Aeródromos',
  'arc': 'Cartas IFR',
  'ccvRea': 'Cartas VFR',
  'ccvReh': 'Cartas VFR',
  'rea': 'Cartas VFR',
  'reh': 'Cartas VFR',
  'wac': 'Cartas VFR',
  'enrc': 'Cartas IFR',
  'enrcl': 'Cartas IFR',
  'enrch': 'Cartas IFR',
  'enrc_l': 'Cartas IFR',
  'enrc_h': 'Cartas IFR',
  'reast': 'Cartas IFR',
};

const _categoryOrder = ['Cartas de Aeródromos', 'Cartas VFR', 'Cartas IFR'];

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
          _buildHeader(context, state, notifier),
          Expanded(child: _buildContent(context, state, notifier)),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
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
                Text(
                  'Cartas Aeronáuticas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.theme.customTextPrimary,
                  ),
                ),
                if (state.manifest != null)
                  Text(
                    'Ciclo AIRAC: ${state.manifest!.emenda}  ·  ${state.manifest!.downloaded} cartas',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.theme.customTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: context.theme.customTextSecondary),
            onPressed: state.loading ? null : () => notifier.refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ChartsDownloadState state,
    ChartsDownloadNotifier notifier,
  ) {
    if (state.loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: context.theme.accent),
            const SizedBox(height: 16),
            Text(
              'Carregando catálogo...',
              style: TextStyle(color: context.theme.customTextSecondary),
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
              Icon(Icons.cloud_off, size: 48, color: context.theme.disabled),
              const SizedBox(height: 16),
              Text(
                'Catálogo indisponível',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.theme.customTextPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(
                  fontSize: 12,
                  color: context.theme.customTextSecondary,
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
      if (group.tipo == 'enrc') {
        // Separa as cartas ENRC em H e L baseado no nome do arquivo
        final hFiles = group.files
            .where(
              (f) => RegExp(
                r'ENRC_H\d',
                caseSensitive: false,
              ).hasMatch(f.filename),
            )
            .toList();
        final lFiles = group.files
            .where(
              (f) => RegExp(
                r'ENRC_L\d',
                caseSensitive: false,
              ).hasMatch(f.filename),
            )
            .toList();
        final otherEnrcFiles = group.files
            .where(
              (f) =>
                  !RegExp(
                    r'ENRC_H\d',
                    caseSensitive: false,
                  ).hasMatch(f.filename) &&
                  !RegExp(
                    r'ENRC_L\d',
                    caseSensitive: false,
                  ).hasMatch(f.filename),
            )
            .toList();

        if (hFiles.isNotEmpty) {
          enrchGroups.add(
            R2ChartGroup(especie: group.especie, tipo: 'enrch', files: hFiles),
          );
        }
        if (lFiles.isNotEmpty) {
          enrclGroups.add(
            R2ChartGroup(especie: group.especie, tipo: 'enrcl', files: lFiles),
          );
        }
        if (otherEnrcFiles.isNotEmpty) {
          otherGroups.add(
            R2ChartGroup(
              especie: group.especie,
              tipo: 'enrc',
              files: otherEnrcFiles,
            ),
          );
        }
        continue;
      }

      final cat = _tipoToCategory[group.tipo] ?? group.tipo.toUpperCase();
      if (cat == 'Cartas de Aeródromos') {
        adGroups.add(group);
      } else if (group.tipo == 'enrch' ||
          group.tipo == 'enrc_h' ||
          group.key.contains('enrch') ||
          group.key.contains('enrc_h')) {
        enrchGroups.add(group);
      } else if (group.tipo == 'enrcl' ||
          group.tipo == 'enrc_l' ||
          group.key.contains('enrcl') ||
          group.key.contains('enrc_l')) {
        enrclGroups.add(group);
      } else {
        otherGroups.add(group);
      }
    }

    if (adGroups.isNotEmpty) {
      byCategory['Cartas de Aeródromos'] = [
        _UIGroup(
          key: 'cartas_de_ads',
          title: 'Cartas de Aeródromos',
          subtitle: 'Todas as cartas de ADs (IAC, SID, STAR, ADC, etc)',
          originalGroups: adGroups,
        ),
      ];
    }

    if (enrchGroups.isNotEmpty || enrclGroups.isNotEmpty) {
      byCategory.putIfAbsent('Cartas IFR', () => []);
    }

    if (enrchGroups.isNotEmpty) {
      byCategory['Cartas IFR']!.add(
        _UIGroup(
          key: 'enrc_h_todas',
          title: 'ENRC H',
          subtitle: 'En-Route Chart (Alta Altitude)',
          originalGroups: enrchGroups,
        ),
      );
    }

    if (enrclGroups.isNotEmpty) {
      byCategory['Cartas IFR']!.add(
        _UIGroup(
          key: 'enrc_l_todas',
          title: 'ENRC L',
          subtitle: 'En-Route Chart (Baixa Altitude)',
          originalGroups: enrclGroups,
        ),
      );
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

    if (byCategory['Cartas VFR'] != null) {
      final vfrOrder = ['wac', 'rea', 'reh', 'ccvRea', 'ccvReh'];
      byCategory['Cartas VFR']!.sort((a, b) {
        final aType = a.originalGroups.first.tipo;
        final bType = b.originalGroups.first.tipo;
        final aIndex = vfrOrder.indexOf(aType);
        final bIndex = vfrOrder.indexOf(bType);
        return (aIndex == -1 ? 99 : aIndex).compareTo(
          bIndex == -1 ? 99 : bIndex,
        );
      });
    }

    if (byCategory['Cartas IFR'] != null) {
      final ifrOrder = ['enrch', 'enrcl', 'arc', 'reast'];
      byCategory['Cartas IFR']!.sort((a, b) {
        final aType = a.key.startsWith('enrc_h')
            ? 'enrch'
            : a.key.startsWith('enrc_l')
            ? 'enrcl'
            : a.originalGroups.first.tipo;
        final bType = b.key.startsWith('enrc_h')
            ? 'enrch'
            : b.key.startsWith('enrc_l')
            ? 'enrcl'
            : b.originalGroups.first.tipo;
        final aIndex = ifrOrder.indexOf(aType);
        final bIndex = ifrOrder.indexOf(bType);
        return (aIndex == -1 ? 99 : aIndex).compareTo(
          bIndex == -1 ? 99 : bIndex,
        );
      });
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final cat in _categoryOrder)
          if (byCategory[cat] != null) ...[
            _buildSectionHeader(context, cat),
            for (final group in byCategory[cat]!)
              _buildGroupTile(context, group, state, notifier),
          ],
        for (final cat in byCategory.keys)
          if (!_categoryOrder.contains(cat)) ...[
            _buildSectionHeader(context, cat),
            for (final group in byCategory[cat]!)
              _buildGroupTile(context, group, state, notifier),
          ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: context.theme.customTextSecondary,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildGroupTile(
    BuildContext context,
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
        color: context.theme.customSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isComplete
                ? context.theme.success.withAlpha(80)
                : context.theme.disabled.withAlpha(50),
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
                      ? context.theme.accent
                      : isComplete
                      ? context.theme.success
                      : isPartial
                      ? context.theme.warning
                      : context.theme.disabled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: (() {
                  int currentCount = localCount;
                  if (isDownloading && progress != null) {
                    currentCount = progress.$1;
                  }
                  final double sliderValue = total > 0
                      ? (currentCount / total).clamp(0.0, 1.0)
                      : 0.0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${uiGroup.title}  —  ${uiGroup.subtitle}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: context.theme.customTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: sliderValue,
                          minHeight: 6,
                          backgroundColor: context.theme.disabled.withAlpha(50),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isComplete
                                ? context.theme.success
                                : context.theme.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatSize(uiGroup.totalSize),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.theme.customTextSecondary,
                            ),
                          ),
                          Text(
                            '$currentCount/$total',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.theme.customTextSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                })(),
              ),
              const SizedBox(width: 8),
              if (isDownloading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.theme.accent,
                  ),
                )
              else if (isComplete)
                Icon(Icons.check_circle, color: context.theme.success, size: 22)
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
