//<!--            android:value="thumstech_channel" />-->
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

class OneSignalNotificationService {
  static bool _isInitialized = false;
  static const String _oneSignalAppId = '36709973-f516-4746-a694-c58ad52a532d';
  static const String _oneSignalApiKey =
 'os_v2_app_gzyjs47vczdunjuuywfnkkstfxezryqycbiue7u6iu467b5bluxxtvjaypafcyaldcqxkmqefinzzdxi5aqjjwe7gc3q4teixmac77y';

  // ================= INIT =================
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      OneSignal.initialize(_oneSignalAppId);
     await OneSignal.Notifications.requestPermission(true);
      _isInitialized = true;
      print('✅ OneSignal initialized');

      // CLICK LISTENER WITH NAVIGATION
      OneSignal.Notifications.addClickListener((event) {
        final data = event.notification.additionalData ?? {};
        print('📱 Notification Clicked: $data');
        _handleNotificationTap(Map<String, dynamic>.from(data));
      });

      // FOREGROUND LISTENER
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        print('📨 Foreground Notification: ${event.notification.additionalData}');
        event.notification.display();
      });
    } catch (e) {
      print('❌ OneSignal init error: $e');
    }
  }

  // ================= NAVIGATION HANDLER =================
  static void _handleNotificationTap(Map<String, dynamic> data) {
    String type = data['type'] ?? '';
    print('🔍 Notification type: $type');
    print('📦 Data: $data');

    if (type == 'new_message') {
      final conversationId = data['conversationId'] ?? '';
      final requestId = data['requestId'] ?? '';
      String otherUserId = data['senderId'] ?? '';
      final otherUserName = data['senderName'] ?? 'User';
      final otherUserRole = data['senderRole'] ?? 'customer';

      if (otherUserId.isEmpty && conversationId.isNotEmpty) {
        final parts = conversationId.split('_');
        if (parts.length >= 3) {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            if (parts[1] == currentUser.uid) {
              otherUserId = parts[2];
            } else {
              otherUserId = parts[1];
            }
          }
        }
      }

      if (otherUserId.isEmpty) {
        print('❌ ERROR: Cannot navigate - otherUserId is empty');
        return;
      }

      navigatorKey.currentState?.pushNamed(
        '/chat',
        arguments: {
          'conversationId': conversationId,
          'requestId': requestId,
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'otherUserRole': otherUserRole,
        },
      );
    } else if (type == 'new_request' || type == 'request_accepted' || type == 'task') {
      navigatorKey.currentState?.pushNamed('/technician-dashboard');
    } else if (type == 'service_request') {
      final serviceName = data['serviceName'] ?? 'Service Request';
      navigatorKey.currentState?.pushNamed(
        '/service-details',
        arguments: {'serviceName': serviceName},
      );
    } else if (type == 'request_posted') {
      navigatorKey.currentState?.pushNamed('/customer-dashboard');
    } else if (type == 'request_rejected') {
      navigatorKey.currentState?.pushNamed('/customer-dashboard');
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
          if (doc.exists) {
            final role = doc.data()?['role'] ?? 'customer';
            if (role == 'technician') {
              navigatorKey.currentState?.pushNamed('/technician-dashboard');
            } else {
              navigatorKey.currentState?.pushNamed('/customer-dashboard');
            }
          }
        });
      }
    }
  }

  // ================= GET ID =================
  static String? getOneSignalId() {
    try {
      return OneSignal.User.pushSubscription.id;
    } catch (e) {
      print('❌ Error getting OneSignal ID: $e');
      return null;
    }
  }

  // ================= SAVE ONE SIGNAL ID =================
  static Future<bool> saveOneSignalId({
    required String userId,
    required String userRole,
  }) async {
    try {
      print('📱 Saving OneSignal ID for user: $userId (Role: $userRole)');

      String? oneSignalId;
      for (int i = 0; i < 10; i++) {
        oneSignalId = OneSignal.User.pushSubscription.id;
        if (oneSignalId != null && oneSignalId.isNotEmpty) {
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (oneSignalId == null || oneSignalId.isEmpty) {
        print('❌ OneSignal ID not ready yet');
        return false;
      }

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'oneSignalId': oneSignalId,
        'userRole': userRole,
        'notificationsEnabled': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ OneSignal ID saved: $oneSignalId');
      return true;
    } catch (e) {
      print('❌ Save ID error: $e');
      return false;
    }
  }

  // ================= SAVE CURRENT USER ID =================
  static Future<void> saveCurrentUserOneSignalId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No user logged in');
      return;
    }

    String? oneSignalId;
    for (int i = 0; i < 10; i++) {
      oneSignalId = OneSignal.User.pushSubscription.id;
      if (oneSignalId != null && oneSignalId.isNotEmpty) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (oneSignalId == null || oneSignalId.isEmpty) {
      print('❌ OneSignal ID not available');
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'oneSignalId': oneSignalId,
      'notificationsEnabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    print('✅ OneSignal ID saved for user: ${user.uid}');
    print('📱 OneSignal ID: $oneSignalId');
  }

  // ================= SEND NOTIFICATION =================
  static Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!doc.exists) {
        print('❌ User not found');
        return false;
      }

      final oneSignalId = doc.data()?['oneSignalId'];

      if (oneSignalId == null || oneSignalId.toString().isEmpty) {
        print('❌ No OneSignal ID found for user: $userId');
        return false;
      }

      print('📤 Sending notification to: $oneSignalId');
      print('📝 Title: $title');
      print('📝 Body: $body');
      print('📦 Data: $data');

      final payload = {
        'app_id': _oneSignalAppId,
        'include_player_ids': [oneSignalId],
        'headings': {'en': title},
        'contents': {'en': body},
        'data': data,
        'priority': 10,
        'android_channel_id': 'cbfb12cf-b86d-4007-95e6-8e6afc888a5b',
        'android_sound': 'notification_sound',

      };

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_oneSignalApiKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ Notification sent successfully. ID: ${responseData['id']}');

        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': userId,
          'title': title,
          'body': body,
          'type': data['type'],
          'data': data,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      } else {
        print('❌ Failed to send: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Send error: $e');
      return false;
    }
  }

  // ================= SEND MESSAGE NOTIFICATION =================
  static Future<bool> sendMessageNotification({
    required String receiverId,
    required String senderName,
    required String message,
    required String conversationId,
    required String requestId,
    required String senderId,
    required String senderRole,
  }) async {
    return sendNotificationToUser(
      userId: receiverId,
      title: '💬 New Message from $senderName',
      body: message.length > 100 ? '${message.substring(0, 100)}...' : message,
      data: {
        'type': 'new_message',
        'conversationId': conversationId,
        'requestId': requestId,
        'senderName': senderName,
        'senderId': senderId,
        'senderRole': senderRole,
      },
    );
  }

  // ================= SEND TASK NOTIFICATION =================
  static Future<bool> sendTaskNotification({
    required String technicianId,
    required String title,
    required String body,
    required String requestId,
    required String serviceName,
  }) async {
    return sendNotificationToUser(
      userId: technicianId,
      title: title,
      body: body,
      data: {
        'type': 'task',
        'requestId': requestId,
        'serviceName': serviceName,
      },
    );
  }

  // ================= SEND NEW REQUEST NOTIFICATION =================
  static Future<bool> sendNewRequestNotification({
    required String technicianId,
    required String serviceName,
    required String customerName,
    required String requestId,
  }) async {
    return sendNotificationToUser(
      userId: technicianId,
      title: '🔧 New Service Request',
      body: '$customerName needs $serviceName',
      data: {
        'type': 'new_request',
        'requestId': requestId,
        'serviceName': serviceName,
        'customerName': customerName,
      },
    );
  }

  // ================= SEND REQUEST POSTED NOTIFICATION =================
  static Future<bool> sendRequestPostedNotification({
    required String customerId,
    required String serviceName,
    required String requestId,
  }) async {
    return sendNotificationToUser(
      userId: customerId,
      title: '✅ Request Posted Successfully!',
      body: 'Your service request for $serviceName has been posted. Technicians will respond shortly.',
      data: {
        'type': 'request_posted',
        'requestId': requestId,
        'serviceName': serviceName,
      },
    );
  }

  // ================= SEND REQUEST ACCEPTED NOTIFICATION =================
  static Future<bool> sendRequestAcceptedNotification({
    required String customerId,
    required String technicianName,
    required String technicianPhone,
    required String requestId,
    required String serviceName,
  }) async {
    return sendNotificationToUser(
      userId: customerId,
      title: '✅ Request Accepted!',
      body: '$technicianName has accepted your service request for $serviceName.',
      data: {
        'type': 'request_accepted',
        'requestId': requestId,
        'serviceName': serviceName,
        'technicianName': technicianName,
        'technicianPhone': technicianPhone,
      },
    );
  }

  // ================= SEND REQUEST REJECTED NOTIFICATION =================
  static Future<bool> sendRequestRejectedNotification({
    required String customerId,
    required String requestId,
    required String serviceName,
  }) async {
    return sendNotificationToUser(
      userId: customerId,
      title: '❌ Request Rejected',
      body: 'Your service request for $serviceName has been rejected. You can post a new request.',
      data: {
        'type': 'request_rejected',
        'requestId': requestId,
        'serviceName': serviceName,
      },
    );
  }

  // ================= MATCH TECHNICIANS =================
  static Future<void> notifyMatchingTechnicians({
    required String serviceType,
    required String pincode,
    required String requestId,
    required String serviceName,
    required String customerName,
  }) async {
    try {
      print('🔍 Looking for technicians:');
      print('   Service: $serviceType');
      print('   Customer Pincode: $pincode');

      final techs = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'technician')
          .get();

      print('📊 Total technicians: ${techs.docs.length}');

      int matchedCount = 0;
      int sentCount = 0;

      for (final doc in techs.docs) {
        final d = doc.data();

        final categories = List<String>.from(d['categories'] ?? []);
        List<String> technicianPincodes = [];
        if (d['pincodes'] != null && (d['pincodes'] as List).isNotEmpty) {
          technicianPincodes = List<String>.from(d['pincodes']);
        } else if (d['pincode'] != null && d['pincode'].toString().isNotEmpty) {
          technicianPincodes = [d['pincode'].toString()];
        }

        final categoryMatches = categories.contains(serviceType);
        final pincodeMatches = technicianPincodes.contains(pincode);

        if (categoryMatches && pincodeMatches) {
          matchedCount++;
          final technicianName = d['name'] ?? 'Technician';

          print('✅ MATCH: $technicianName');

          final success = await sendNewRequestNotification(
            technicianId: doc.id,
            serviceName: serviceName,
            customerName: customerName,
            requestId: requestId,
          );

          if (success) {
            sentCount++;
            await FirebaseFirestore.instance
                .collection('technician_pending_requests')
                .doc('${doc.id}_$requestId')
                .set({
              'technicianId': doc.id,
              'technicianName': technicianName,
              'requestId': requestId,
              'serviceName': serviceName,
              'customerName': customerName,
              'customerPincode': pincode,
              'createdAt': FieldValue.serverTimestamp(),
              'status': 'pending',
            });
          }
        }
      }

      print('📊 Results: Matched=$matchedCount, Notifications Sent=$sentCount');
    } catch (e) {
      print('❌ Matching error: $e');
    }
  }

  // ================= ENSURE ID EXISTS =================
  static Future<void> ensureOneSignalIdForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final oneSignalId = doc.data()?['oneSignalId'];

    if (oneSignalId == null || oneSignalId.toString().isEmpty) {
      print('⚠️ No OneSignal ID found, saving now...');
      await saveCurrentUserOneSignalId();
    } else {
      print('✅ OneSignal ID already exists: $oneSignalId');
    }
  }

  // ================= BULK SEND =================
  static Future<Map<String, bool>> sendNotificationToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final results = <String, bool>{};

    for (final id in userIds) {
      results[id] = await sendNotificationToUser(
        userId: id,
        title: title,
        body: body,
        data: data,
      );
    }

    return results;
  }
}