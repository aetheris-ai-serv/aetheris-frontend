import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_services.dart';

class SpeedService {
  SpeedService._internal();
  static final SpeedService _instance = SpeedService._internal();
  factory SpeedService() => _instance;

  final StreamController<double> _speedController =
      StreamController.broadcast();

  Stream<double> get speedStream => _speedController.stream;

  StreamSubscription<Position>? _positionStream;

  Future<void> start() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 1,
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            double speed = position.speed * 3.6;
            if (speed < 2) speed = 0;

            _speedController.add(speed);

            // 🔥 Send to backend from ONE place
            ApiService.sendSpeed(speed);
          },
        );
  }

  void stop() {
    _positionStream?.cancel();
  }
}
