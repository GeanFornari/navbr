// ignore_for_file: dangling_library_doc_comments
// Contém código gerado por IA

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:navbr/providers/chart_settings_provider.dart';
import 'package:navbr/theme/app_colors.dart';

/// ChartSettingsBanner
/// Widget que exibe as configurações de opacidade e opção de remover a visualização da IAC.
/// 
/// Classes/Métodos presentes:
/// - ChartSettingsBanner: Widget simplificado para ajustes da IAC.
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
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppColors.primary.withAlpha(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Opção de Remover (Ocultar tudo)
            InkWell(
              onTap: () {
                Provider.of<ChartSettingsProvider>(context, listen: false).toggleIacVisibility(false);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.visibility_off_outlined, size: 16, color: AppColors.error),
                    SizedBox(width: 8),
                    Text(
                      'Remover',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            
            const Text('Opacidade da IAC', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Consumer<ChartSettingsProvider>(
              builder: (context, provider, _) => Slider(
                value: provider.iacOpacity,
                onChanged: provider.setIacOpacity,
                activeColor: AppColors.secondary,
                inactiveColor: AppColors.secondary.withAlpha(40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
