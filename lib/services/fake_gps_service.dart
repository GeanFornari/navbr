import 'dart:async';
import 'package:latlong2/latlong.dart';

class FakeGpsService {
  Timer? _timer;
  final _controller = StreamController<LatLng>.broadcast();
  
  // Rota SDCO (Sorocaba) -> SBBU (Bauru)
  final LatLng startPoint = const LatLng(-23.4805, -47.4841);
  final LatLng endPoint = const LatLng(-22.2949, -49.0604);
  
  LatLng _currentLocation = const LatLng(-23.4805, -47.4841);
  double _bearing = 0.0;
  final Distance _distance = const Distance();
  
  Stream<LatLng> get locationStream => _controller.stream;

  void start() {
    _timer?.cancel();
    
    // Calcula a proa (bearing) inicial do ponto A ao ponto B
    _bearing = _distance.bearing(startPoint, endPoint);
    _currentLocation = startPoint;
    
    // A cada 500ms, vamos mover o avião alguns metros na direção correta
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      // Avança cerca de 800 metros por tick (simulando um voo rápido para a PoC)
      _currentLocation = _distance.offset(_currentLocation, 800, _bearing);
      _controller.add(_currentLocation);
      
      // Se chegou muito perto, para o timer
      if (_distance.as(LengthUnit.Kilometer, _currentLocation, endPoint) < 2.0) {
        timer.cancel();
      }
    });
  }

  void stop() {
    _timer?.cancel();
  }
  
  void dispose() {
    stop();
    _controller.close();
  }
}