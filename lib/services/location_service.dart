import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<Position?> getPosition({required bool allowPrompt}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && allowPrompt) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    if (!allowPrompt) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }
}
