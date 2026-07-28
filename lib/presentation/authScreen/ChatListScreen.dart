// screens/ChatListScreen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../Services/FirebaseMessageService.dart';
import '../../model/MessageModel.dart';
import 'ChatScreen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseMessageService _messageService = FirebaseMessageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Center(child: Text('Please login'));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Search functionality can be added later
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ConversationModel>>(
        stream: _messageService.getUserConversations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading chats',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final conversations = snapshot.data ?? [];

          if (conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start chatting with your service providers',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: conversations.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final conversation = conversations[index];
              return _buildConversationTile(conversation);
            },
          );
        },
      ),
    );
  }

  Widget _buildConversationTile(ConversationModel conversation) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    // Determine other user info
    final bool isCustomer = conversation.customerId == currentUser.uid;
    final String otherUserId = isCustomer
        ? conversation.technicianId
        : conversation.customerId;
    final String otherUserName = isCustomer
        ? conversation.technicianName
        : conversation.customerName;
    final String otherUserRole = isCustomer ? 'technician' : 'customer';

    // ✅ Get unread count for current user using the method
    final int unreadCount = conversation.getUnreadCount(currentUser.uid);

    // Get last message time
    String timeString = _formatTime(conversation.lastMessageTime);

    return GestureDetector(
      onTap: () {
        // Navigate to chat screen with existing ChatScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              conversationId: conversation.id,
              requestId: conversation.requestId,
              otherUserId: otherUserId,
              otherUserName: otherUserName,
              otherUserRole: otherUserRole,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: otherUserRole == 'technician'
                    ? Colors.blue.shade100
                    : Colors.green.shade100,
                child: Text(
                  otherUserName.isNotEmpty
                      ? otherUserName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: otherUserRole == 'technician'
                        ? Colors.blue.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              // Online status indicator
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  otherUserName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeString,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              // ✅ CORRECTED: Double tick logic
              // Show double tick only if there are messages and current user is the SENDER
              // Blue = read, Grey = delivered but not read
              if (conversation.lastMessage.isNotEmpty) ...[
                // 🔥 Check if current user sent the last message
                // For this we need to check the last message sender
                // We'll use a StreamBuilder for last message status
                _buildLastMessageStatus(conversation, currentUser.uid),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  conversation.lastMessage,
                  style: TextStyle(
                    color: unreadCount > 0
                        ? Colors.black87
                        : Colors.grey.shade600,
                    fontWeight: unreadCount > 0
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Unread count badge
              if (unreadCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ),
      ),
    );
  }

  // ✅ New method to show last message status with correct double tick logic
  Widget _buildLastMessageStatus(
    ConversationModel conversation,
    String currentUserId,
  ) {
    // Check if current user is the sender of the last message
    // We need to fetch the last message to check its sender

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversation.id)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final lastMessageData =
            snapshot.data!.docs.first.data() as Map<String, dynamic>;
        final String senderId = lastMessageData['senderId'] ?? '';
        final bool isRead = lastMessageData['isRead'] ?? false;

        // ✅ Only show double tick if current user is the SENDER
        final bool isCurrentUserSender = senderId == currentUserId;

        if (!isCurrentUserSender) {
          return const SizedBox.shrink(); // Don't show for received messages
        }

        // ✅ Blue tick = read, Grey tick = not read yet
        return Icon(
          Icons.done_all,
          size: 14,
          color: isRead ? const Color(0xFF2563EB) : Colors.grey.shade400,
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final DateTime now = DateTime.now();

    if (dateTime.day == now.day &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      // Today - show time
      final hour = dateTime.hour == 0
          ? 12
          : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
      final period = dateTime.hour >= 12 ? 'PM' : 'AM';
      return '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    } else if (dateTime.day == now.day - 1 &&
        dateTime.month == now.month &&
        dateTime.year == now.year) {
      return 'Yesterday';
    } else if (dateTime.year == now.year) {
      // This year - show month/day
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dateTime.month - 1]} ${dateTime.day}';
    } else {
      // Different year
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
