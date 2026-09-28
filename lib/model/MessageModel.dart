// models/MessageModel.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'customer' or 'technician'
  final String receiverId;
  final String receiverName;
  final String receiverRole;
  final String message;
  final String messageType; // 'text', 'image', 'location'
  final bool isRead;
  final DateTime sentAt;
  final DateTime? readAt;
  final String? imageUrl;
  final String requestId; // Which service request this message belongs to

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.receiverId,
    required this.receiverName,
    required this.receiverRole,
    required this.message,
    required this.messageType,
    required this.isRead,
    required this.sentAt,
    this.readAt,
    this.imageUrl,
    required this.requestId,
  });

  Map<String, dynamic> toMap() {
    return {
      'conversationId': conversationId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverRole': receiverRole,
      'message': message,
      'messageType': messageType,
      'isRead': isRead,
      'sentAt': FieldValue.serverTimestamp(),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'imageUrl': imageUrl,
      'requestId': requestId,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map, String id) {
    return MessageModel(
      id: id,
      conversationId: map['conversationId'] ?? '',
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      senderRole: map['senderRole'] ?? '',
      receiverId: map['receiverId'] ?? '',
      receiverName: map['receiverName'] ?? '',
      receiverRole: map['receiverRole'] ?? '',
      message: map['message'] ?? '',
      messageType: map['messageType'] ?? 'text',
      isRead: map['isRead'] ?? false,
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (map['readAt'] as Timestamp?)?.toDate(),
      imageUrl: map['imageUrl'],
      requestId: map['requestId'] ?? '',
    );
  }
}

// ============================================
// ✅ Conversation Model (Fixed)
// ============================================
class ConversationModel {
  final String id;
  final String requestId;
  final String customerId;
  final String customerName;
  final String technicianId;
  final String technicianName;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int customerUnreadCount; // ✅ Separate for customer
  final int technicianUnreadCount; // ✅ Separate for technician
  final String serviceName;
  final String status; // 'active', 'completed', 'archived'

  ConversationModel({
    required this.id,
    required this.requestId,
    required this.customerId,
    required this.customerName,
    required this.technicianId,
    required this.technicianName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.customerUnreadCount,
    required this.technicianUnreadCount,
    required this.serviceName,
    required this.status,
  });

  // ✅ Get unread count based on current user
  int getUnreadCount(String currentUserId) {
    if (customerId == currentUserId) {
      return customerUnreadCount;
    } else if (technicianId == currentUserId) {
      return technicianUnreadCount;
    }
    return 0;
  }

  // ✅ Get total unread count (for backwards compatibility)
  int get totalUnreadCount {
    return customerUnreadCount + technicianUnreadCount;
  }

  Map<String, dynamic> toMap() {
    return {
      'requestId': requestId,
      'customerId': customerId,
      'customerName': customerName,
      'technicianId': technicianId,
      'technicianName': technicianName,
      'lastMessage': lastMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'customerUnreadCount': customerUnreadCount,
      'technicianUnreadCount': technicianUnreadCount,
      'serviceName': serviceName,
      'status': status,
    };
  }

  factory ConversationModel.fromMap(Map<String, dynamic> map, String id) {
    return ConversationModel(
      id: id,
      requestId: map['requestId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? 'Customer',
      technicianId: map['technicianId'] ?? '',
      technicianName: map['technicianName'] ?? 'Technician',
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: (map['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      customerUnreadCount: map['customerUnreadCount'] ?? 0,
      technicianUnreadCount: map['technicianUnreadCount'] ?? 0,
      serviceName: map['serviceName'] ?? 'Service',
      status: map['status'] ?? 'active',
    );
  }
}