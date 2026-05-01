// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navbr/providers/chart_settings_provider.dart';
import 'package:navbr/theme/app_colors.dart';

/// ChartSettingsBanner
/// Widget que exibe as configurações de opacidade e visibilidade da carta.
/// Projetado para ser exibido dentro de um Overlay.
/// 
/// Classes/Métodos presentes:
/// - ChartSettingsBanner: Widget que contém os controles de configuração.
class ChartSettingsBanner extends StatelessWidget {
  final String chartType;

  const ChartSettingsBanner({
    super.key,
    required this.chartType,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.primary.withAlpha(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Ajustes: $chartType',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const Divider(),
            
            // Controle de Visibilidade IAC (conforme pedido: apenas na IAC)
            if (chartType == 'IAC') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Exibir Camada IAC', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Consumer<ChartSettingsProvider>(
                    builder: (context, provider, _) => Switch(
                      value: provider.isIacVisible,
                      onChanged: provider.toggleIacVisibility,
                      activeThumbColor: AppColors.iacButton,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            const Text('Opacidade WAC', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Consumer<ChartSettingsProvider>(
              builder: (context, provider, _) => Slider(
                value: provider.wacOpacity,
                onChanged: provider.setWacOpacity,
                activeColor: AppColors.wacButton,
                inactiveColor: AppColors.wacButton.withAlpha(50),
              ),
            ),
            const Text('Opacidade IAC', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Consumer<ChartSettingsProvider>(
              builder: (context, provider, _) => Slider(
                value: provider.iacOpacity,
                onChanged: provider.setIacOpacity,
                activeColor: AppColors.iacButton,
                inactiveColor: AppColors.iacButton.withAlpha(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
