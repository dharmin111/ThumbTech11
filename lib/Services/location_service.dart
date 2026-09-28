// lib/services/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../model/LocationModel.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();

  factory LocationService() => _instance;

  LocationService._internal();

  // Geocoding v5+ instance
  final Geocoding _geocoding = Geocoding();

  // ✅ Check and request location permission
  Future<bool> checkAndRequestPermission() async {
    try {
      PermissionStatus status = await Permission.location.request();

      return status == PermissionStatus.granted;
    } catch (e) {
      print('❌ Error requesting permission: $e');
      return false;
    }
  }

  // ✅ Check if location services are enabled
  Future<bool> isLocationServicesEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      print('❌ Error checking location services: $e');
      return false;
    }
  }

  // ✅ Get current location with timeout
  Future<LocationModel?> getCurrentLocation({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      // Check permissions
      bool hasPermission = await checkAndRequestPermission();

      if (!hasPermission) {
        print('❌ Location permission denied');
        return null;
      }

      // Check if location services are enabled
      bool isEnabled = await isLocationServicesEnabled();

      if (!isEnabled) {
        print('❌ Location services are disabled');
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: timeout,
      );

      // Get address from coordinates
      String address = await getAddressFromCoordinates(
        position.latitude,
        position.longitude,
      );

      return LocationModel(
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        placeName: _extractPlaceName(address),
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('❌ Error getting location: $e');
      return null;
    }
  }

  // ✅ Get address from coordinates
  // Compatible with geocoding 5.0.0+
  Future<String> getAddressFromCoordinates(
      double lat,
      double lng,
      ) async {
    try {
      // Validate coordinates
      if (lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        print('❌ Invalid coordinates: $lat, $lng');
        return 'Unknown location';
      }

      print('📍 Reverse geocoding: lat=$lat, lng=$lng');

      final List<Placemark> placemarks =
      await _geocoding.placemarkFromCoordinates(
        lat,
        lng,
      );

      if (placemarks.isEmpty) {
        print(
          '⚠️ No placemark found for: $lat, $lng',
        );
        return 'Unknown location';
      }

      final Placemark place = placemarks.first;

      final List<String> parts = [
        if (place.street != null &&
            place.street!.trim().isNotEmpty)
          place.street!.trim(),

        if (place.locality != null &&
            place.locality!.trim().isNotEmpty)
          place.locality!.trim(),

        if (place.administrativeArea != null &&
            place.administrativeArea!.trim().isNotEmpty)
          place.administrativeArea!.trim(),

        if (place.country != null &&
            place.country!.trim().isNotEmpty)
          place.country!.trim(),
      ];

      final String address = parts.isNotEmpty
          ? parts.join(', ')
          : 'Unknown location';

      print('✅ Address found: $address');

      return address;
    } catch (e) {
      print('❌ Reverse geocoding failed: $e');
      return 'Unknown location';
    }
  }

  // ✅ Get detailed address
  Future<Map<String, String>> getDetailedAddress(
      double lat,
      double lng,
      ) async {
    try {
      final List<Placemark> placemarks =
      await _geocoding.placemarkFromCoordinates(
        lat,
        lng,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;

        return {
          'street': place.street ?? '',
          'locality': place.locality ?? '',
          'administrativeArea':
          place.administrativeArea ?? '',
          'country': place.country ?? '',
          'postalCode': place.postalCode ?? '',
          'fullAddress': [
            place.street ?? '',
            place.locality ?? '',
            place.administrativeArea ?? '',
            place.country ?? '',
          ].where((s) => s.isNotEmpty).join(', '),
        };
      }

      return {
        'fullAddress': 'Unknown location',
      };
    } catch (e) {
      print('❌ Error getting detailed address: $e');

      return {
        'fullAddress': 'Unknown location',
      };
    }
  }

  // ✅ Extract place name from address
  String _extractPlaceName(String address) {
    if (address.isEmpty) {
      return 'Unknown';
    }

    final List<String> parts = address.split(',');

    return parts.isNotEmpty
        ? parts[0].trim()
        : 'Unknown';
  }

  // ✅ Get location updates stream
  Stream<LocationModel> getLocationUpdates() async* {
    try {
      // Check permission
      bool hasPermission = await checkAndRequestPermission();

      if (!hasPermission) {
        print('❌ Location permission denied');
        return;
      }

      // Check location services
      bool isEnabled = await isLocationServicesEnabled();

      if (!isEnabled) {
        print('❌ Location services are disabled');
        return;
      }

      // Listen to position changes
      await for (Position position
      in Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      )) {
        try {
          // Reverse geocode
          String address =
          await getAddressFromCoordinates(
            position.latitude,
            position.longitude,
          );

          yield LocationModel(
            latitude: position.latitude,
            longitude: position.longitude,
            address: address,
            placeName: _extractPlaceName(address),
            timestamp: DateTime.now(),
          );
        } catch (e) {
          print(
            '❌ Error processing location update: $e',
          );
        }
      }
    } catch (e) {
      print('❌ Error in location stream: $e');
    }
  }

  // ✅ Calculate distance between two locations
  double calculateDistance(
      LocationModel loc1,
      LocationModel loc2,
      ) {
    return Geolocator.distanceBetween(
      loc1.latitude,
      loc1.longitude,
      loc2.latitude,
      loc2.longitude,
    );
  }

  // ✅ Format distance
  String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    }

    return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
  }
}