import 'package:geolocator/geolocator.dart';

class Fix {
  final double lat;
  final double lon;
  final int t; // unix ms
  const Fix(this.lat, this.lon, this.t);
}

/// Where the phone is. Real GPS on a device, a fixed point in tests and demos.
abstract class LocationSource {
  /// Throws [LocationDenied] if the user refuses, or [StateError] otherwise.
  Future<Fix> current();
}

class LocationDenied implements Exception {
  @override
  String toString() => 'Location permission denied';
}

class DeviceLocation implements LocationSource {
  @override
  Future<Fix> current() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw LocationDenied();
    }
    final p = await Geolocator.getCurrentPosition();
    return Fix(p.latitude, p.longitude, p.timestamp.millisecondsSinceEpoch);
  }
}

class FixedLocation implements LocationSource {
  Fix fix;
  FixedLocation(double lat, double lon, [int t = 0]) : fix = Fix(lat, lon, t);
  @override
  Future<Fix> current() async => fix;
}
