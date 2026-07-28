import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';
import '../model/MessageModel.dart';
import 'oneSignalNotificationService.dart';

class FirebaseMessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Send a message with proper bidirectional notifications
  Future<void> sendMessage({
    required String requestId,
    required String receiverId,
    required String receiverName,
    required String receiverRole, // 'customer' or 'technician'
    required String message,
    String? imageUrl,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data();
      final senderName = userData?['name'] ?? 'User';
      final senderRole = userData?['role'] ?? 'customer';

      print('📨 Sending message:');
      print('   From: $senderName ($senderRole)');
      print('   To: $receiverName ($receiverRole)');
      print('   Message: $message');

      final String customerId = senderRole == 'customer'
          ? currentUser.uid
          : receiverId;
      final String technicianId = senderRole == 'technician'
          ? currentUser.uid
          : receiverId;
      final String customerName = senderRole == 'customer'
          ? senderName
          : receiverName;
      final String technicianName = senderRole == 'technician'
          ? senderName
          : receiverName;

      final conversationId = _getConversationId(
        requestId: requestId,
        customerId: customerId,
        technicianId: technicianId,
      );

      // Create or update conversation
      await _updateConversation(
        conversationId: conversationId,
        requestId: requestId,
        customerId: customerId,
        customerName: customerName,
        technicianId: technicianId,
        technicianName: technicianName,
        lastMessage: message,
        serviceName: await _getServiceName(requestId),
      );

      // Add message to subcollection
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
            'senderId': currentUser.uid,
            'senderName': senderName,
            'senderRole': senderRole,
            'receiverId': receiverId,
            'receiverName': receiverName,
            'receiverRole': receiverRole,
            'message': message,
            'messageType': imageUrl != null ? 'image' : 'text',
            'imageUrl': imageUrl,
            'isRead': false,
            'sentAt': FieldValue.serverTimestamp(),
            'requestId': requestId,
          });

      // ✅ Increment ONLY the receiver's unread count
      final conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);

      if (receiverRole == 'customer') {
        await conversationRef.update({
          'customerUnreadCount': FieldValue.increment(1),
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
        print('✅ Customer unread count incremented');
      } else {
        await conversationRef.update({
          'technicianUnreadCount': FieldValue.increment(1),
          'lastMessage': message,
          'lastMessageTime': FieldValue.serverTimestamp(),
        });
        print('✅ Technician unread count incremented');
      }

      // Send push notification
      await _sendPushNotification(
        receiverId: receiverId,
        receiverRole: receiverRole,
        senderName: senderName,
        message: message,
        conversationId: conversationId,
        requestId: requestId,
      );

      await _sendInAppNotification(
        receiverId: receiverId,
        title: '💬 New Message from $senderName',
        body: message,
        conversationId: conversationId,
        requestId: requestId,
      );

      print('✅ Message sent and notification delivered');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> _sendPushNotification({
    required String receiverId,
    required String receiverRole,
    required String senderName,
    required String message,
    required String conversationId,
    required String requestId,
  }) async {
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(receiverId)
          .get();
      final oneSignalId = userDoc.data()?['oneSignalId'];

      if (oneSignalId == null || oneSignalId.isEmpty) {
        print('⚠️ No OneSignal ID for $receiverRole: $receiverId');
        return;
      }

      String notificationTitle;
      if (receiverRole == 'technician') {
        notificationTitle = '🔧 New Message from Customer';
      } else {
        notificationTitle = '👤 New Message from Technician';
      }

      final result = await OneSignalNotificationService.sendNotificationToUser(
        userId: receiverId,
        title: notificationTitle,
        body: message.length > 100
            ? '${message.substring(0, 100)}...'
            : message,
        data: {
          'type': 'new_message',
          'conversationId': conversationId,
          'requestId': requestId,
          'senderName': senderName,
          'senderRole': receiverRole == 'technician'
              ? 'customer'
              : 'technician',
        },
      );

      if (result) {
        print('✅ Push notification sent to $receiverRole: $receiverId');
      } else {
        print('❌ Failed to send push notification to $receiverRole');
      }
    } catch (e) {
      print('Error sending push notification: $e');
    }
  }

  Future<void> _sendInAppNotification({
    required String receiverId,
    required String title,
    required String body,
    required String conversationId,
    required String requestId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'userId': receiverId,
        'userRole': 'user',
        'title': title,
        'body': body,
        'type': 'message',
        'conversationId': conversationId,
        'requestId': requestId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error sending in-app notification: $e');
    }
  }

  Future<void> _updateConversation({
    required String conversationId,
    required String requestId,
    required String customerId,
    required String customerName,
    required String technicianId,
    required String technicianName,
    required String lastMessage,
    required String serviceName,
  }) async {
    final conversationRef = _firestore
        .collection('conversations')
        .doc(conversationId);
    final conversationDoc = await conversationRef.get();

    if (!conversationDoc.exists) {
      await conversationRef.set({
        'requestId': requestId,
        'customerId': customerId,
        'customerName': customerName,
        'technicianId': technicianId,
        'technicianName': technicianName,
        'lastMessage': lastMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'customerUnreadCount': 0,
        'technicianUnreadCount': 0,
        'serviceName': serviceName,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ New conversation created');
    }
  }

  // Get messages for a conversation (real-time)
  Stream<List<MessageModel>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.data(), doc.id))
              .toList();
        });
  }

  // ✅ FIXED: No status filter in query - local filtering
  Stream<List<ConversationModel>> getUserConversations() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value([]);

    // ✅ Get conversations where user is customer (NO status filter)
    final customerConversations = _firestore
        .collection('conversations')
        .where('customerId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
              .where((conv) => conv.status == 'active') // ✅ Local filter
              .toList();
        });

    // ✅ Get conversations where user is technician (NO status filter)
    final technicianConversations = _firestore
        .collection('conversations')
        .where('technicianId', isEqualTo: currentUser.uid)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ConversationModel.fromMap(doc.data(), doc.id))
              .where((conv) => conv.status == 'active') // ✅ Local filter
              .toList();
        });

    return Rx.combineLatest2<
      List<ConversationModel>,
      List<ConversationModel>,
      List<ConversationModel>
    >(customerConversations, technicianConversations, (
      customerList,
      technicianList,
    ) {
      final all = [...customerList, ...technicianList];
      final uniqueMap = <String, ConversationModel>{};
      for (var conversation in all) {
        uniqueMap[conversation.id] = conversation;
      }
      final uniqueList = uniqueMap.values.toList();
      uniqueList.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return uniqueList;
    });
  }

  // ✅ FIXED: Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      print('📖 Marking messages as read for user: ${currentUser.uid}');

      final messagesRef = _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages');

      final unreadMessages = await messagesRef
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('isRead', isEqualTo: false)
          .get();

      print('📖 Found ${unreadMessages.docs.length} unread messages');

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      // Reset ONLY the current user's unread count
      final conversationRef = _firestore
          .collection('conversations')
          .doc(conversationId);
      final conversationDoc = await conversationRef.get();

      if (conversationDoc.exists) {
        final data = conversationDoc.data() as Map<String, dynamic>;
        final bool isCustomer = data['customerId'] == currentUser.uid;

        if (isCustomer) {
          await conversationRef.update({'customerUnreadCount': 0});
          print('✅ Customer unread count reset to 0');
        } else {
          await conversationRef.update({'technicianUnreadCount': 0});
          print('✅ Technician unread count reset to 0');
        }
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // ✅ FIXED: No status filter in query - local filtering
  Stream<int> getUnreadMessageCount() {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return Stream.value(0);

    // ✅ Query without status filter (to avoid permission error)
    return _firestore.collection('conversations').snapshots().map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();

        // ✅ Skip if not active (local filter)
        if (data['status'] != 'active') continue;

        // Check if current user is customer
        if (data['customerId'] == currentUser.uid) {
          final unreadCount = data['customerUnreadCount'] ?? 0;
          count += unreadCount is int ? unreadCount : 0;
        }

        // Check if current user is technician
        if (data['technicianId'] == currentUser.uid) {
          final unreadCount = data['technicianUnreadCount'] ?? 0;
          count += unreadCount is int ? unreadCount : 0;
        }
      }
      return count;
    });
  }

  // Get or create conversation ID
  String _getConversationId({
    required String requestId,
    required String customerId,
    required String technicianId,
  }) {
    return '${requestId}_${customerId}_$technicianId';
  }

  // Get service name from request ID
  Future<String> _getServiceName(String requestId) async {
    try {
      final doc = await _firestore
          .collection('service_requests')
          .doc(requestId)
          .get();
      if (doc.exists) {
        return doc.data()?['serviceName'] ?? 'Service Request';
      }
      return 'Service Request';
    } catch (e) {
      return 'Service Request';
    }
  }

  // Upload message image
  Future<String?> uploadMessageImage({
    required String conversationId,
    required String senderId,
    required File imageFile,
  }) async {
    try {
      final storage = FirebaseStorage.instance;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = storage.ref().child(
        'messages/$conversationId/$senderId/$fileName',
      );
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  // Set user online when app starts
  Future<void> setUserOnline() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('users').doc(currentUser.uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // Set user offline when app closes
  Future<void> setUserOffline() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    await _firestore.collection('users').doc(currentUser.uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }
}
