import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class GpsService {
  StreamSubscription<Position>? _positionStreamSubscription;
  final _controller = StreamController<LatLng>.broadcast();
  
  Stream<LatLng> get locationStream => _controller.stream;

  Future<void> start() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Configure settings for continuous stream
    final locationSettings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1, // update every 1 meter
    );

    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
      .listen((Position? position) {
        if (position != null) {
          _controller.add(LatLng(position.latitude, position.longitude));
        }
    });
  }

  void stop() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }
  
  void dispose() {
    stop();
    _controller.close();
  }
}