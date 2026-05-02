import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChartSettings {
  const ChartSettings({
    this.wacOpacity = 1.0,
    this.iacOpacity = 0.7,
    this.isIacVisible = true,
    this.wacPath,
    this.wacBoundingBox,
    this.iacPath,
    this.iacBoundingBox,
  });

  final double wacOpacity;
  final double iacOpacity;
  final bool isIacVisible;
  final String? wacPath;
  final Map<String, double>? wacBoundingBox;
  final String? iacPath;
  final Map<String, double>? iacBoundingBox;

  ChartSettings copyWith({
    double? wacOpacity,
    double? iacOpacity,
    bool? isIacVisible,
    String? wacPath,
    Map<String, double>? wacBoundingBox,
    String? iacPath,
    Map<String, double>? iacBoundingBox,
  }) =>
      ChartSettings(
        wacOpacity: wacOpacity ?? this.wacOpacity,
        iacOpacity: iacOpacity ?? this.iacOpacity,
        isIacVisible: isIacVisible ?? this.isIacVisible,
        wacPath: wacPath ?? this.wacPath,
        wacBoundingBox: wacBoundingBox ?? this.wacBoundingBox,
        iacPath: iacPath ?? this.iacPath,
        iacBoundingBox: iacBoundingBox ?? this.iacBoundingBox,
      );
}

class ChartSettingsNotifier extends Notifier<ChartSettings> {
  @override
  ChartSettings build() {
    _load();
    return const ChartSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final wacPath = prefs.getString('saved_wac_path');
    final iacPath = prefs.getString('saved_iac_path');

    state = ChartSettings(
      iacOpacity: prefs.getDouble('iac_opacity') ?? 0.7,
      isIacVisible: prefs.getBool('is_iac_visible') ?? true,
      wacPath: wacPath,
      wacBoundingBox: wacPath == null
          ? null
          : {
              'north': prefs.getDouble('saved_wac_north') ?? 0.0,
              'south': prefs.getDouble('saved_wac_south') ?? 0.0,
              'east': prefs.getDouble('saved_wac_east') ?? 0.0,
              'west': prefs.getDouble('saved_wac_west') ?? 0.0,
            },
      iacPath: iacPath,
      iacBoundingBox: iacPath == null
          ? null
          : {
              'north': prefs.getDouble('saved_iac_north') ?? 0.0,
              'south': prefs.getDouble('saved_iac_south') ?? 0.0,
              'east': prefs.getDouble('saved_iac_east') ?? 0.0,
              'west': prefs.getDouble('saved_iac_west') ?? 0.0,
            },
    );
  }

  Future<void> refresh() => _load();

  Future<void> setIacOpacity(double value) async {
    state = state.copyWith(iacOpacity: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('iac_opacity', value);
  }

  Future<void> setIacVisible(bool value) async {
    state = state.copyWith(isIacVisible: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_iac_visible', value);
  }
}

final chartSettingsProvider =
    NotifierProvider<ChartSettingsNotifier, ChartSettings>(
  ChartSettingsNotifier.new,
);
