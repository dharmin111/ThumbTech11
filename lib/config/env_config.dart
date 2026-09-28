// lib/config/env_config.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

class EnvConfig {
  static String get googleMapsApiKey {
    try {
      if (Platform.isIOS) {
        return dotenv.env['IOS_Google_Map_Api'] ?? '';
      } else if (Platform.isAndroid) {
        return dotenv.env['Android_Google_Map_Api'] ?? '';
      }
      return '';
    } catch (e) {
      print('❌ Error loading env: $e');
      return '';
    }
  }

  // ✅ Get both keys for debugging
  static String get androidKey => dotenv.env['Android_Google_Map_Api'] ?? '';
  static String get iosKey => dotenv.env['IOS_Google_Map_Api'] ?? '';
}