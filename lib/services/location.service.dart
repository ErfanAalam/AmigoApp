import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Request location permission and get current position
  Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('📍 Location services are disabled.');
        return {
          'success': false,
          'error': 'Location services are disabled',
          'latitude': null,
          'longitude': null,
        };
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        print('📍 Requesting location permission...');
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          print('📍 Location permission denied by user.');
          return {
            'success': false,
            'error': 'Location permission denied',
            'latitude': null,
            'longitude': null,
          };
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('📍 Location permissions are permanently denied.');
        return {
          'success': false,
          'error': 'Location permissions are permanently denied',
          'latitude': null,
          'longitude': null,
        };
      }

      print('📍 Location permission granted. Getting current position...');

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );

      print('📍 Location retrieved successfully:');
      print('   Latitude: ${position.latitude}');
      print('   Longitude: ${position.longitude}');
      print('   Accuracy: ${position.accuracy} meters');
      print('   Altitude: ${position.altitude} meters');

      return {
        'success': true,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'altitude': position.altitude,
        'timestamp': position.timestamp,
      };
    } catch (e) {
      print('📍 Error getting location: $e');
      return {
        'success': false,
        'error': e.toString(),
        'latitude': null,
        'longitude': null,
      };
    }
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Open app settings to manually enable location permission
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }
}
