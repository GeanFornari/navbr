import 'package:hive_flutter/hive_flutter.dart';

class FlightLog {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final String? originIcao;
  final String? destIcao;
  final double distanceNm;
  final String? aircraftReg;
  final String? flightLevel;
  final String? route;
  final String? alternateIcao;

  FlightLog({
    required this.id,
    required this.startTime,
    this.endTime,
    this.originIcao,
    this.destIcao,
    this.distanceNm = 0.0,
    this.aircraftReg,
    this.flightLevel,
    this.route,
    this.alternateIcao,
  });

  Duration get flightDuration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }

  String get formattedDuration {
    final d = flightDuration;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    const months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    return '${startTime.day.toString().padLeft(2, '0')} ${months[startTime.month - 1]} ${startTime.year}';
  }

  String get originLabel => (originIcao?.isNotEmpty == true) ? originIcao! : '----';
  String get destLabel => (destIcao?.isNotEmpty == true) ? destIcao! : '----';
}

class FlightLogAdapter extends TypeAdapter<FlightLog> {
  @override
  final int typeId = 1;

  @override
  FlightLog read(BinaryReader reader) {
    final id = reader.readString();
    final startTime = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final endTime = reader.readBool() ? DateTime.fromMillisecondsSinceEpoch(reader.readInt()) : null;
    final originIcao = reader.readBool() ? reader.readString() : null;
    final destIcao = reader.readBool() ? reader.readString() : null;
    final distanceNm = reader.readDouble();

    // Extended fields — absent in records written before this version.
    String? aircraftReg;
    String? flightLevel;
    String? route;
    String? alternateIcao;
    try {
      aircraftReg = reader.readBool() ? reader.readString() : null;
      flightLevel = reader.readBool() ? reader.readString() : null;
      route = reader.readBool() ? reader.readString() : null;
      alternateIcao = reader.readBool() ? reader.readString() : null;
    } catch (_) {}

    return FlightLog(
      id: id,
      startTime: startTime,
      endTime: endTime,
      originIcao: originIcao,
      destIcao: destIcao,
      distanceNm: distanceNm,
      aircraftReg: aircraftReg,
      flightLevel: flightLevel,
      route: route,
      alternateIcao: alternateIcao,
    );
  }

  @override
  void write(BinaryWriter writer, FlightLog obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.startTime.millisecondsSinceEpoch);
    writer.writeBool(obj.endTime != null);
    if (obj.endTime != null) writer.writeInt(obj.endTime!.millisecondsSinceEpoch);
    writer.writeBool(obj.originIcao != null);
    if (obj.originIcao != null) writer.writeString(obj.originIcao!);
    writer.writeBool(obj.destIcao != null);
    if (obj.destIcao != null) writer.writeString(obj.destIcao!);
    writer.writeDouble(obj.distanceNm);
    writer.writeBool(obj.aircraftReg != null);
    if (obj.aircraftReg != null) writer.writeString(obj.aircraftReg!);
    writer.writeBool(obj.flightLevel != null);
    if (obj.flightLevel != null) writer.writeString(obj.flightLevel!);
    writer.writeBool(obj.route != null);
    if (obj.route != null) writer.writeString(obj.route!);
    writer.writeBool(obj.alternateIcao != null);
    if (obj.alternateIcao != null) writer.writeString(obj.alternateIcao!);
  }
}
