import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navbr/models/flight_log.dart';

class FlightsNotifier extends Notifier<List<FlightLog>> {
  Box<FlightLog>? _box;

  Future<Box<FlightLog>> get _openBox async {
    if (_box != null && _box!.isOpen) return _box!;
    _box = await Hive.openBox<FlightLog>('flights');
    return _box!;
  }

  @override
  List<FlightLog> build() {
    _load();
    return [];
  }

  Future<void> _load() async {
    final b = await _openBox;
    final sorted = b.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    state = sorted;
  }

  Future<void> add(FlightLog flight) async {
    final b = await _openBox;
    await b.put(flight.id, flight);
    await _load();
  }

  Future<void> delete(String id) async {
    final b = await _openBox;
    await b.delete(id);
    await _load();
  }
}

final flightsProvider =
    NotifierProvider<FlightsNotifier, List<FlightLog>>(FlightsNotifier.new);
