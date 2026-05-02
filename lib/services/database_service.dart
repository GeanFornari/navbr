import 'package:hive_flutter/hive_flutter.dart';

class ChartIndex {
  final String key;
  final String type; // 'wac', 'enrcl', 'enrch', 'iac', etc.
  final String path;
  final double north;
  final double south;
  final double east;
  final double west;

  ChartIndex({
    required this.key,
    required this.type,
    required this.path,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}

class ChartIndexAdapter extends TypeAdapter<ChartIndex> {
  @override
  final int typeId = 0;

  @override
  ChartIndex read(BinaryReader reader) {
    return ChartIndex(
      key: reader.readString(),
      type: reader.readString(),
      path: reader.readString(),
      north: reader.readDouble(),
      south: reader.readDouble(),
      east: reader.readDouble(),
      west: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ChartIndex obj) {
    writer.writeString(obj.key);
    writer.writeString(obj.type);
    writer.writeString(obj.path);
    writer.writeDouble(obj.north);
    writer.writeDouble(obj.south);
    writer.writeDouble(obj.east);
    writer.writeDouble(obj.west);
  }
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Box<ChartIndex>? _box;

  Future<Box<ChartIndex>> get box async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<ChartIndex>('charts');
    return _box!;
  }

  Future<void> saveChart(ChartIndex chart) async {
    final b = await box;
    await b.put(chart.key, chart); // using the file key as the primary key
  }

  Future<List<ChartIndex>> getChartsByType(String type) async {
    final b = await box;
    return b.values.where((c) => c.type == type).toList();
  }

  Future<void> clearAllCharts() async {
    final b = await box;
    await b.clear();
  }

  Future<void> deleteChart(String key) async {
    final b = await box;
    await b.delete(key);
  }
}
