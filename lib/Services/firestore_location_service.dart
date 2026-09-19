// lib/services/firestore_location_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/LocationModel.dart';

class FirestoreLocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirestoreLocationService _instance =
  FirestoreLocationService._internal();
  factory FirestoreLocationService() => _instance;
  FirestoreLocationService._internal();

  // ✅ Check if user has location
  Future<bool> hasUserLocation(String userId) async {
    if (userId.isEmpty) {
      print('❌ Error: userId is empty in hasUserLocation');
      return false;
    }

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['hasLocation'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Error checking location: $e');
      return false;
    }
  }

  // ✅ Save user location - ONLY in users/{userId} document (No separate collection)
  Future<bool> saveUserLocation({
    required String userId,
    required LocationModel location,
  }) async {
    if (userId.isEmpty) {
      print('❌ Error: userId is empty in saveUserLocation');
      return false;
    }

    try {
      // ✅ ONLY update users/{userId} document - NO separate locations collection
      await _firestore.collection('users').doc(userId).set({
        'currentLocation': {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'address': location.address ?? '',
          'placeName': location.placeName ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        },
        'geoPoint': GeoPoint(location.latitude, location.longitude),
        'hasLocation': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Location saved to users/$userId');
      print('📍 Lat: ${location.latitude}, Lng: ${location.longitude}');
      print('📍 Address: ${location.address}');
      print('📍 Place: ${location.placeName}');

      return true;
    } catch (e) {
      print('❌ Error saving location: $e');
      return false;
    }
  }

  // ✅ Get user's current location from users/{userId} document
  Future<LocationModel?> getUserCurrentLocation(String userId) async {
    if (userId.isEmpty) {
      print('❌ Error: userId is empty in getUserCurrentLocation');
      return null;
    }

    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get(const GetOptions(source: Source.server));

      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        if (data.containsKey('currentLocation')) {
          Map<String, dynamic> location =
          data['currentLocation'] as Map<String, dynamic>;

          return LocationModel(
            latitude: location['latitude']?.toDouble() ?? 0.0,
            longitude: location['longitude']?.toDouble() ?? 0.0,
            address: location['address'] ?? '',
            placeName: location['placeName'] ?? '',
            timestamp: location['timestamp'] != null
                ? (location['timestamp'] as Timestamp).toDate()
                : null,
          );
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting current location: $e');
      return null;
    }
  }

  // ✅ Get nearby users (within radius) - for merchant/technician search
  Future<List<Map<String, dynamic>>> getNearbyUsers({
    required double latitude,
    required double longitude,
    required double radiusInKm,
    int limit = 20,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true)
          .where('hasLocation', isEqualTo: true)
          .limit(limit * 2)
          .get();

      List<Map<String, dynamic>> nearbyUsers = [];

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('geoPoint')) {
          GeoPoint geoPoint = data['geoPoint'];
          double distance = _calculateDistance(
            latitude,
            longitude,
            geoPoint.latitude,
            geoPoint.longitude,
          );

          if (distance <= radiusInKm) {
            nearbyUsers.add({
              'userId': doc.id,
              'data': data,
              'distance': distance,
              'distanceFormatted': _formatDistance(distance),
            });
          }
        }
      }

      nearbyUsers.sort((a, b) => a['distance'].compareTo(b['distance']));

      if (nearbyUsers.length > limit) {
        nearbyUsers = nearbyUsers.sublist(0, limit);
      }

      return nearbyUsers;
    } catch (e) {
      print('❌ Error getting nearby users: $e');
      return [];
    }
  }

  // ✅ Calculate distance in KM
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = pow(sin(dLat / 2), 2) +
        pow(sin(dLon / 2), 2) *
            cos(_toRadians(lat1)) *
            cos(_toRadians(lat2));

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180.0;
  }

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)} km';
    }
  }
}