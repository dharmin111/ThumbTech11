import 'package:cloud_firestore/cloud_firestore.dart';
class LocationModel {
  final double latitude;
  final double longitude;
  final String? address;
  final String? placeName;
  final DateTime? timestamp;

  LocationModel({
    required this.latitude,
    required this.longitude,
    this.address,
    this.placeName,
    this.timestamp,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address ?? '',
      'placeName': placeName ?? '',
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'geoPoint': GeoPoint(latitude, longitude),
    };
  }

  // Create from Map
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    return LocationModel(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      placeName: map['placeName'] ?? '',
      timestamp: map['timestamp']?.toDate(),
    );
  }

  // Create from GeoPoint
  factory LocationModel.fromGeoPoint(GeoPoint geoPoint) {
    return LocationModel(
      latitude: geoPoint.latitude,
      longitude: geoPoint.longitude,
    );
  }
}