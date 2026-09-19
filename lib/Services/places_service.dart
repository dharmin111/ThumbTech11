// lib/services/places_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/LocationModel.dart';
import '../config/env_config.dart';

class PlacesService {
  static final PlacesService _instance = PlacesService._internal();
  factory PlacesService() => _instance;
  PlacesService._internal();

  Future<List<LocationModel>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final apiKey = EnvConfig.googleMapsApiKey;

      // ✅ Naya Places API (New) endpoint
      final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');

      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        // ✅ Field mask zaroori hai — iske bagair 400 error aata hai
        'X-Goog-FieldMask':
        'places.displayName,places.formattedAddress,places.location',
      };

      final body = jsonEncode({'textQuery': query});

      print('🔍 Places (New) Search: "$query"');

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        final err = json.decode(response.body);
        throw Exception(
          'Places API Error: ${err['error']?['message'] ?? response.body}',
        );
      }

      final data = json.decode(response.body);
      final List places = data['places'] ?? [];
      print('✅ Found ${places.length} places');

      return places.map<LocationModel>((p) {
        final lat = (p['location']['latitude'] as num).toDouble();
        final lng = (p['location']['longitude'] as num).toDouble();
        final name = p['displayName']?['text'] ?? '';
        final addr = p['formattedAddress'] ?? '';
        return LocationModel(
          latitude: lat,
          longitude: lng,
          address: addr,
          placeName: name.isNotEmpty ? name : addr.split(',').first.trim(),
        );
      }).toList();
    } catch (e) {
      print('❌ Places search error: $e');
      rethrow;
    }
  }
}