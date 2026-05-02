import 'package:flutter/material.dart';

import '../models/r2_manifest.dart';
import '../services/r2_service.dart';
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
  'enrc': 'En-Route Chart',
};

class ChartsDownloadScreen extends StatefulWidget {
  const ChartsDownloadScreen({super.key});

  @override
  State<ChartsDownloadScreen> createState() => _ChartsDownloadScreenState();
}

class _ChartsDownloadScreenState extends State<ChartsDownloadScreen> {
  final _r2 = R2Service();

  R2Manifest? _manifest;
  bool _loading = true;
  String? _error;

  Map<String, int> _localCounts = {};
  final Set<String> _downloading = {};
  final Map<String, (int, int)> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadManifest();
  }

  Future<void> _loadManifest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final latest = await _r2.fetchLatest();
      final manifest = await _r2.fetchManifest(latest.folder);
      final counts = await _r2.countAllLocalFiles(latest.folder, manifest.groups);
      setState(() {
        _manifest = manifest;
        _localCounts = counts;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _downloadGroup(R2ChartGroup group) async {
    if (_downloading.contains(group.key)) return;

    setState(() {
      _downloading.add(group.key);
      _downloadProgress[group.key] = (0, group.files.length);
    });

    int completed = 0;
    for (final file in group.files) {
      if (!mounted) break;
      try {
        await _r2.downloadFile(_manifest!.folder, file);
        completed++;
        if (mounted) {
          setState(() => _downloadProgress[group.key] = (completed, group.files.length));
        }
      } catch (_) {
        // Continua nos erros individuais
      }
    }

    if (mounted) {
      final newCount = await _r2.countLocalFiles(_manifest!.folder, group);
      setState(() {
        _downloading.remove(group.key);
        _downloadProgress.remove(group.key);
        _localCounts[group.key] = newCount;
      });
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                if (_manifest != null)
                  Text(
                    'Ciclo AIRAC: ${_manifest!.emenda}  ·  ${_manifest!.downloaded} cartas',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loading ? null : _loadManifest,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
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

    if (_error != null) {
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
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadManifest,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    final byEspecie = <String, List<R2ChartGroup>>{};
    for (final group in _manifest!.groups) {
      byEspecie.putIfAbsent(group.especie, () => []).add(group);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final especie in ['ifr', 'vfr', 'rota'])
          if (byEspecie[especie] != null) ...[
            _buildSectionHeader(especie.toUpperCase()),
            for (final group in byEspecie[especie]!) _buildGroupTile(group),
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

  Widget _buildGroupTile(R2ChartGroup group) {
    final localCount = _localCounts[group.key] ?? 0;
    final total = group.files.length;
    final isDownloading = _downloading.contains(group.key);
    final progress = _downloadProgress[group.key];
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
                      '${_tipoLabels[group.tipo] ?? group.tipo.toUpperCase()}  —  ${_tipoDescriptions[group.tipo] ?? ''}',
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
                              ? '$localCount/$total cartas  ·  ${_formatSize(group.totalSize)}'
                              : '$total cartas  ·  ${_formatSize(group.totalSize)}',
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
                const Icon(Icons.check_circle, color: AppColors.success, size: 22)
              else
                TextButton(
                  onPressed: () => _downloadGroup(group),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
