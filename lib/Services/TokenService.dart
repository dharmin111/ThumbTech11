// Services/TokenService.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TokenService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save FCM token to Firestore
  static Future<bool> saveFCMToken(String userId) async {
    if (userId.isEmpty) {
      print('❌ Cannot save token: User ID is empty');
      return false;
    }

    try {
      // Request notification permissions
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('⚠️ Notification permissions not granted');
        return false;
      }

      // Get FCM token
      final token = await FirebaseMessaging.instance.getToken();

      if (token == null || token.isEmpty) {
        print('❌ No FCM token available');
        return false;
      }

      // Save to Firestore
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ FCM token saved for user: $userId');
      print('📱 Token: ${token.substring(0, 20)}...');
      return true;

    } catch (e) {
      print('❌ Error saving FCM token: $e');
      return false;
    }
  }

  // Ensure FCM token exists for current user
  static Future<void> ensureFCMToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      print('ℹ️ No user logged in, skipping token save');
      return;
    }

    try {
      // Check if token already exists
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final existingToken = userDoc.data()?['fcmToken'];

      // Get current token
      final currentToken = await FirebaseMessaging.instance.getToken();

      if (currentToken == null || currentToken.isEmpty) {
        print('❌ Could not get FCM token');
        return;
      }

      // If token doesn't exist or has changed, update it
      if (existingToken != currentToken) {
        await _firestore.collection('users').doc(user.uid).set({
          'fcmToken': currentToken,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ FCM token updated for user: ${user.uid}');
      } else {
        print('✅ FCM token already exists and is valid');
      }

    } catch (e) {
      print('❌ Error ensuring FCM token: $e');
    }
  }

  // Remove FCM token when user logs out
  static Future<void> clearFCMToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
        'tokenRemovedAt': FieldValue.serverTimestamp(),
      });
      print('✅ FCM token cleared for user: ${user.uid}');
    } catch (e) {
      print('❌ Error clearing FCM token: $e');
    }
  }

  // Check if user has valid FCM token
  static Future<bool> hasValidFCMToken(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final token = userDoc.data()?['fcmToken'];
      return token != null && token.toString().isNotEmpty;
    } catch (e) {
      print('❌ Error checking token: $e');
      return false;
    }
  }

  // Refresh FCM token
  static Future<String?> refreshFCMToken() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      final newToken = await FirebaseMessaging.instance.getToken();

      if (newToken != null && newToken.isNotEmpty) {
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore.collection('users').doc(user.uid).set({
            'fcmToken': newToken,
            'tokenRefreshedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        print('✅ FCM token refreshed: ${newToken.substring(0, 20)}...');
        return newToken;
      }
      return null;
    } catch (e) {
      print('❌ Error refreshing token: $e');
      return null;
    }
  }
}