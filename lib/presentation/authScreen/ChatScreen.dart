// lib/presentation/authScreen/ChatScreen.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../Services/FirebaseMessageService.dart';
import '../../Services/ReportService.dart';
import '../../model/MessageModel.dart';
import '../../profile/customer_technician_data_seen.dart';
import '../widgets/ReportDialog.dart';
import '../widgets/BlockDialog.dart';

/// Special marker used to encode "reply" metadata inside the plain message
/// string, so no backend/model changes are required. Format:
/// MARKER + replySenderName + MARKER + replySnippet + MARKER + actualMessage
const String _kReplyMarker = '\u0001REPLY\u0001';

String _encodeReplyMessage(
    String replySender,
    String replySnippet,
    String actual,
    ) {
  return '$_kReplyMarker$replySender$_kReplyMarker$replySnippet$_kReplyMarker$actual';
}

/// Returns null if [raw] is not a reply-encoded message.
Map<String, String>? _decodeReplyMessage(String raw) {
  if (!raw.startsWith(_kReplyMarker)) return null;
  final parts = raw.split(_kReplyMarker);
  if (parts.length < 4) return null;
  return {
    'sender': parts[1],
    'snippet': parts[2],
    'actual': parts.sublist(3).join(_kReplyMarker),
  };
}

class _ReplyPreview {
  final String senderName;
  final String snippet;
  final bool isImage;
  _ReplyPreview({
    required this.senderName,
    required this.snippet,
    this.isImage = false,
  });
}

class _PendingMessage {
  final String id;
  final String text;
  final String? imageLocalPath;
  final DateTime sentAt;
  String status;

  _PendingMessage({
    required this.id,
    required this.text,
    this.imageLocalPath,
    required this.sentAt,
  }) : status = 'sending';
}

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String requestId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserRole;
  final String? otherUserProfileImage;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.requestId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    this.otherUserProfileImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseMessageService _messageService = FirebaseMessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = true;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  Timer? _typingTimer;
  bool _isOtherUserTyping = false;
  bool _isBlocked = false;

  // ✅ Profile image cache
  String _cachedProfileImage = '';

  final List<_PendingMessage> _pendingMessages = [];
  _ReplyPreview? _replyingTo;
  bool _showScrollToBottom = false;
  bool _isUserScrolling = false;
  Timer? _scrollDebounceTimer;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();

    // ✅ Use cached profile image or fetch from widget
    _cachedProfileImage = widget.otherUserProfileImage ?? '';

    if (widget.otherUserId.isEmpty) {
      debugPrint('❌ ERROR: otherUserId is empty in ChatScreen!');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Unable to load chat. User not found.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
      });
      return;
    }

    _initializeChat();
    _listenToUserPresence();
    _listenToTypingStatus();
    _checkBlockStatus();
    _fetchUserProfileImage(); // ✅ Fetch updated profile image

    _focusNode.addListener(_onFocusChange);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _typingTimer?.cancel();
    _scrollDebounceTimer?.cancel();
    super.dispose();
  }

  // ==================== FETCH PROFILE IMAGE ====================

  Future<void> _fetchUserProfileImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final imageUrl = data['profileImageUrl'] ?? '';
        if (imageUrl.isNotEmpty && mounted) {
          setState(() {
            _cachedProfileImage = imageUrl;
          });
        }
      }
    } catch (e) {
      print('Error fetching profile image: $e');
    }
  }

  // ==================== BLOCK CHECK ====================

  Future<void> _checkBlockStatus() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('blocked_users')
          .doc('${currentUser.uid}_${widget.otherUserId}')
          .get();

      setState(() {
        _isBlocked = doc.exists;
      });
    } catch (e) {
      print('Error checking block status: $e');
    }
  }

  Future<bool> _canSendMessage() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final doc1 = await FirebaseFirestore.instance
          .collection('blocked_users')
          .doc('${widget.otherUserId}_${currentUser.uid}')
          .get();

      if (doc1.exists) {
        return false;
      }

      final doc2 = await FirebaseFirestore.instance
          .collection('blocked_users')
          .doc('${currentUser.uid}_${widget.otherUserId}')
          .get();

      if (doc2.exists) {
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking send permission: $e');
      return false;
    }
  }

  // ==================== NAVIGATE TO PROFILE ====================

  void _navigateToUserProfile() {
    // ✅ Navigate to profile view screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerTechnicianDataSeen(
          userId: widget.otherUserId,
          userRole: widget.otherUserRole,
        ),
      ),
    );
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _isUserScrolling = false;
      _scrollToBottom(animated: true, force: true);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final distanceFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final shouldShow = distanceFromBottom > 300;

    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }

    final isNearBottom = distanceFromBottom < 100;
    if (!isNearBottom) {
      _isUserScrolling = true;
      _scrollDebounceTimer?.cancel();
      _scrollDebounceTimer = Timer(const Duration(seconds: 3), () {
        _isUserScrolling = false;
      });
    } else {
      _isUserScrolling = false;
    }
  }

  Future<void> _initializeChat() async {
    try {
      await _createConversationIfNotExists();
      await _messageService.markMessagesAsRead(widget.conversationId);
    } catch (e) {
      debugPrint('Error initializing chat: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom(animated: false);
      }
    }
  }

  void _listenToUserPresence() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          _isOtherUserOnline = data['isOnline'] ?? false;
          _otherUserLastSeen = (data['lastSeen'] as Timestamp?)?.toDate();
          // ✅ Update profile image if changed
          final imageUrl = data['profileImageUrl'] ?? '';
          if (imageUrl.isNotEmpty && imageUrl != _cachedProfileImage) {
            _cachedProfileImage = imageUrl;
          }
        });
      }
    });
  }

  void _listenToTypingStatus() {
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data() as Map<String, dynamic>;
        final typingUserId = data['typingUserId'];
        setState(() {
          _isOtherUserTyping =
              typingUserId != null && typingUserId == widget.otherUserId;
        });
      }
    });
  }

  void _onTyping() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({
      'typingUserId': currentUser.uid,
      'typingAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId)
          .update({'typingUserId': null, 'typingAt': null})
          .catchError((_) {});
    });
  }

  Future<void> _createConversationIfNotExists() async {
    try {
      final conversationRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.conversationId);

      final conversationDoc = await conversationRef.get();

      if (!conversationDoc.exists) {
        final currentUser = FirebaseAuth.instance.currentUser!;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        final userName =
            userDoc.data()?['name'] ?? currentUser.displayName ?? 'User';

        final String customerId;
        final String customerName;
        final String technicianId;
        final String technicianName;

        if (widget.otherUserRole == 'customer') {
          customerId = widget.otherUserId;
          customerName = widget.otherUserName;
          technicianId = currentUser.uid;
          technicianName = userName;
        } else {
          customerId = currentUser.uid;
          customerName = userName;
          technicianId = widget.otherUserId;
          technicianName = widget.otherUserName;
        }

        await conversationRef.set({
          'conversationId': widget.conversationId,
          'requestId': widget.requestId,
          'customerId': customerId,
          'customerName': customerName,
          'technicianId': technicianId,
          'technicianName': technicianName,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'customerUnreadCount': 0,
          'technicianUnreadCount': 0,
          'status': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error creating conversation: $e');
    }
  }

  // ==================== SENDING MESSAGES ====================

  Future<void> _sendMessage() async {
    final rawText = _messageController.text.trim();
    if (rawText.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final canSend = await _canSendMessage();
    if (!canSend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You cannot send messages to this user.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String finalMessage = rawText;
    if (_replyingTo != null) {
      finalMessage = _encodeReplyMessage(
        _replyingTo!.senderName,
        _replyingTo!.snippet,
        rawText,
      );
    }

    final pending = _PendingMessage(
      id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      text: finalMessage,
      sentAt: DateTime.now(),
    );

    setState(() {
      _pendingMessages.add(pending);
      _messageController.clear();
      _replyingTo = null;
    });

    _scrollToBottom(animated: true, force: true);

    _typingTimer?.cancel();
    FirebaseFirestore.instance
        .collection('conversations')
        .doc(widget.conversationId)
        .update({'typingUserId': null})
        .catchError((_) {});

    await _dispatchPendingText(pending);
  }

  Future<void> _dispatchPendingText(_PendingMessage pending) async {
    try {
      await _createConversationIfNotExists();
      await _messageService.sendMessage(
        requestId: widget.requestId,
        receiverId: widget.otherUserId,
        receiverName: widget.otherUserName,
        receiverRole: widget.otherUserRole,
        message: pending.text,
        conversationId:widget.conversationId,
      );
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(
                () => _pendingMessages.removeWhere((p) => p.id == pending.id),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _pendingMessages.indexWhere((p) => p.id == pending.id);
          if (idx != -1) _pendingMessages[idx].status = 'failed';
        });
      }
    }
  }

  void _retryPendingMessage(_PendingMessage pending) {
    setState(() => pending.status = 'sending');
    if (pending.imageLocalPath != null) {
      _dispatchPendingImage(pending);
    } else {
      _dispatchPendingText(pending);
    }
  }

  Future<void> _pickAndSendImage() async {
    final canSend = await _canSendMessage();
    if (!canSend) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ You cannot send messages to this user.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: Color(0xFF2563EB),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final canSend = await _canSendMessage();
      if (!canSend) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ You cannot send messages to this user.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (image == null) return;

      String messageText = '📷 Sent an image';
      if (_replyingTo != null) {
        messageText = _encodeReplyMessage(
          _replyingTo!.senderName,
          _replyingTo!.snippet,
          messageText,
        );
      }

      final pending = _PendingMessage(
        id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
        text: messageText,
        imageLocalPath: image.path,
        sentAt: DateTime.now(),
      );

      setState(() {
        _pendingMessages.add(pending);
        _replyingTo = null;
      });

      _scrollToBottom(animated: true, force: true);

      await _dispatchPendingImage(pending);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _dispatchPendingImage(_PendingMessage pending) async {
    try {
      await _createConversationIfNotExists();

      final imageUrl = await _messageService.uploadMessageImage(
        conversationId: widget.conversationId,
        senderId: FirebaseAuth.instance.currentUser!.uid,
        imageFile: File(pending.imageLocalPath!),
      );

      if (imageUrl != null) {
        await _messageService.sendMessage(
          conversationId: widget.conversationId,
          requestId: widget.requestId,
          receiverId: widget.otherUserId,
          receiverName: widget.otherUserName,
          receiverRole: widget.otherUserRole,
          message: pending.text,
          imageUrl: imageUrl,
        );
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(
                  () => _pendingMessages.removeWhere((p) => p.id == pending.id),
            );
          }
        });
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _pendingMessages.indexWhere((p) => p.id == pending.id);
          if (idx != -1) _pendingMessages[idx].status = 'failed';
        });
      }
    }
  }

  // ==================== SCROLLING ====================

  void _scrollToBottom({bool animated = true, bool force = false}) {
    if (_isUserScrolling && !force) return;
    if (force) _isUserScrolling = false;

    void doScroll() {
      if (!mounted || !_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent <= 0) return;
      if (animated) {
        _scrollController.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxExtent);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    Future.delayed(const Duration(milliseconds: 260), doScroll);
  }

  void _onNewMessage() {
    if (!_scrollController.hasClients) return;
    final isNearBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset <
            200;
    if (isNearBottom) {
      _scrollToBottom(animated: true, force: true);
    }
  }

  void _reconcilePending(List<MessageModel> liveMessages, String myUid) {
    if (_pendingMessages.isEmpty) return;
    final toRemove = <String>[];
    for (final p in _pendingMessages) {
      if (p.status == 'failed') continue;
      final matched = liveMessages.any(
            (m) =>
        m.senderId == myUid &&
            m.message == p.text &&
            m.sentAt.difference(p.sentAt).inSeconds.abs() < 20,
      );
      if (matched) toRemove.add(p.id);
    }
    if (toRemove.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(
                () => _pendingMessages.removeWhere((p) => toRemove.contains(p.id)),
          );
        }
      });
    }
  }

  String _getLastSeenText() {
    if (_isOtherUserOnline) return 'Online';
    if (_otherUserLastSeen != null) {
      final now = DateTime.now();
      final difference = now.difference(_otherUserLastSeen!);
      if (difference.inMinutes < 1) return 'Active now';
      if (difference.inMinutes < 60)
        return 'Active ${difference.inMinutes} min ago';
      if (difference.inHours < 24)
        return 'Active ${difference.inHours} hours ago';
      return 'Last seen ${_otherUserLastSeen!.day}/${_otherUserLastSeen!.month}';
    }
    return 'Offline';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == yesterday) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  // ==================== REPORT + BLOCK ====================

  void _showChatActions(MessageModel message) {
    final isImage = message.messageType == 'image' && message.imageUrl != null;
    final currentUser = FirebaseAuth.instance.currentUser;
    final isMe = message.senderId == currentUser?.uid;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF2563EB)),
              title: const Text('Reply', style: TextStyle(fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                _startReply(
                  message.senderName,
                  message.message,
                  isImage: isImage,
                );
              },
            ),
            if (!isImage)
              ListTile(
                leading: const Icon(Icons.copy, color: Color(0xFF2563EB)),
                title: const Text('Copy', style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  final decoded = _decodeReplyMessage(message.message);
                  final textToCopy = decoded != null
                      ? decoded['actual']!
                      : message.message;
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            if (!isMe)
              ListTile(
                leading: Icon(Icons.flag, color: Colors.red.shade700),
                title: const Text('Report Message', style: TextStyle(fontSize: 16)),
                onTap: () {
                  Navigator.pop(context);
                  _showReportDialog(
                    targetId: message.id,
                    targetType: 'message',
                    targetName: 'Message from ${message.senderName}',
                    additionalInfo: message.message,
                  );
                },
              ),
            if (!isMe)
              ListTile(
                leading: Icon(Icons.block, color: Colors.red.shade700),
                title: Text(
                  'Block ${widget.otherUserName}',
                  style: const TextStyle(fontSize: 16),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(widget.otherUserId, widget.otherUserName);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showReportDialog({
    required String targetId,
    required String targetType,
    required String targetName,
    String? additionalInfo,
  }) {
    showDialog(
      context: context,
      builder: (context) => ReportDialog(
        targetId: targetId,
        targetType: targetType,
        targetName: targetName,
        additionalInfo: additionalInfo,
      ),
    );
  }

  void _blockUser(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => BlockDialog(
        userId: userId,
        userName: userName,
        onBlocked: () {
          setState(() {
            _isBlocked = true;
          });
          _messageController.clear();
          setState(() {
            _pendingMessages.clear();
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $userName has been blocked'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  void _showUnblockDialog(String userId, String userName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $userName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ReportService.unblockUser(
                  blockedUserId: userId,
                );
                setState(() {
                  _isBlocked = false;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ $userName has been unblocked'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Unblock'),
          ),
        ],
      ),
    );
  }

  // ==================== UI COMPONENTS ====================

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            _dateLabel(date),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreviewBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Container(width: 3, height: 36, color: const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo!.senderName}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                  ),
                ),
                Text(
                  _replyingTo!.snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  void _startReply(
      String senderName,
      String rawMessage, {
        bool isImage = false,
      }) {
    final decoded = _decodeReplyMessage(rawMessage);
    final actual = decoded != null ? decoded['actual']! : rawMessage;
    final snippet = isImage
        ? '📷 Photo'
        : (actual.length > 60 ? '${actual.substring(0, 60)}…' : actual);
    setState(() {
      _replyingTo = _ReplyPreview(
        senderName: senderName,
        snippet: snippet,
        isImage: isImage,
      );
    });
    _focusNode.requestFocus();
  }

  Widget _buildQuotedReplyBlock(Map<String, String> decoded, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withOpacity(0.15)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white : const Color(0xFF2563EB),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            decoded['sender'] ?? '',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white : const Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            decoded['snippet'] ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final isImage = message.messageType == 'image' && message.imageUrl != null;
    final decoded = _decodeReplyMessage(message.message);
    final displayText = decoded != null ? decoded['actual']! : message.message;

    return GestureDetector(
      onLongPress: () => _showChatActions(message),
      child: Dismissible(
        key: ValueKey(
          'msg_${message.sentAt.microsecondsSinceEpoch}_${message.senderId}',
        ),
        direction: DismissDirection.startToEnd,
        confirmDismiss: (_) async {
          _startReply(message.senderName, message.message, isImage: isImage);
          return false;
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 12),
          child: const Icon(Icons.reply, color: Color(0xFF2563EB)),
        ),
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ),
                Container(
                  padding: isImage
                      ? const EdgeInsets.all(8)
                      : const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? const Color(0xFF2563EB) : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (decoded != null)
                        _buildQuotedReplyBlock(decoded, isMe),
                      if (isImage)
                        GestureDetector(
                          onTap: () => _showFullImage(message.imageUrl!),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              message.imageUrl!,
                              width: 200,
                              height: 200,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  width: 200,
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 200,
                                    height: 200,
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.broken_image,
                                      size: 50,
                                    ),
                                  ),
                            ),
                          ),
                        )
                      else
                        Text(
                          displayText,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(message.sentAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: isMe ? Colors.white70 : Colors.grey[500],
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (isMe) ...[
                            if (message.isRead)
                              const Icon(
                                Icons.done_all,
                                size: 12,
                                color: Colors.white70,
                              )
                            else
                              const Icon(
                                Icons.done,
                                size: 12,
                                color: Colors.white70,
                              ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPendingBubble(_PendingMessage pending) {
    final decoded = _decodeReplyMessage(pending.text);
    final displayText = decoded != null ? decoded['actual']! : pending.text;
    final isImage = pending.imageLocalPath != null;
    final isFailed = pending.status == 'failed';

    return GestureDetector(
      onTap: isFailed ? () => _retryPendingMessage(pending) : null,
      child: Align(
        alignment: Alignment.centerRight,
        child: Opacity(
          opacity: isFailed ? 1 : 0.85,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Container(
              padding: isImage
                  ? const EdgeInsets.all(8)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isFailed ? Colors.red.shade300 : const Color(0xFF2563EB),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (decoded != null) _buildQuotedReplyBlock(decoded, true),
                  if (isImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(pending.imageLocalPath!),
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Text(
                      displayText,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isFailed ? 'Failed · tap to retry' : 'Sending...',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isFailed ? Icons.error_outline : Icons.access_time,
                        size: 12,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    if (_isBlocked) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.grey.shade100,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'You have blocked this user. Unblock to send messages.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _pickAndSendImage,
            icon: const Icon(Icons.photo, color: Color(0xFF2563EB)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                onChanged: (text) {
                  if (text.isNotEmpty) _onTyping();
                },
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          IconButton(
            onPressed: _sendMessage,
            icon: const Icon(Icons.send, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            panEnabled: true,
            scaleEnabled: true,
            child: Image.network(imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  void _showRequestDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(widget.requestId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(data['serviceName'] ?? 'Service Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Customer', data['userName'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Phone', data['userPhone'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Location', data['location'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Pincode', data['pincode'] ?? 'N/A'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Budget', '₹${data['budget'] ?? 0}'),
                  const SizedBox(height: 8),
                  _buildDetailRow('Issue', data['issue'] ?? 'N/A'),
                  if (data['additionalNote'] != null &&
                      data['additionalNote'].isNotEmpty)
                    _buildDetailRow('Note', data['additionalNote']),
                  if (data['status'] != null)
                    _buildDetailRow(
                      'Status',
                      data['status'].toString().toUpperCase(),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching request details: $e');
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) return '${time.day}/${time.month}/${time.year}';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > _lastBottomInset + 1) {
      _scrollToBottom(animated: true, force: true);
    }
    _lastBottomInset = bottomInset;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: GestureDetector(
          onTap: _navigateToUserProfile, // ✅ Tap on title to view profile
          child: Row(
            children: [
              // ✅ Profile Image with click
              GestureDetector(
                onTap: _navigateToUserProfile,
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: widget.otherUserRole == 'technician'
                      ? Colors.blue.shade100
                      : Colors.green.shade100,
                  backgroundImage: _cachedProfileImage.isNotEmpty
                      ? NetworkImage(_cachedProfileImage)
                      : null,
                  child: _cachedProfileImage.isEmpty
                      ? Text(
                    widget.otherUserName.isNotEmpty
                        ? widget.otherUserName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: widget.otherUserRole == 'technician'
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.otherUserName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_isBlocked) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.block,
                            color: Colors.red,
                            size: 16,
                          ),
                        ],
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isOtherUserOnline ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getLastSeenText(),
                          style: const TextStyle(fontSize: 10),
                        ),
                        if (_isOtherUserTyping) ...[
                          const SizedBox(width: 8),
                          const Text(
                            'typing...',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [

          IconButton(
            onPressed: () => _showRequestDetails(),
            icon: const Icon(Icons.info_outline),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'block') {
                if (_isBlocked) {
                  _showUnblockDialog(widget.otherUserId, widget.otherUserName);
                } else {
                  _blockUser(widget.otherUserId, widget.otherUserName);
                }
              } else if (value == 'report') {
                _showReportDialog(
                  targetId: widget.otherUserId,
                  targetType: 'user',
                  targetName: widget.otherUserName,
                );
              } else if (value == 'profile') {
                _navigateToUserProfile();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('View Profile'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    const Text('Report User'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.block_rounded : Icons.block,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Text(_isBlocked ? 'Unblock User' : 'Block User'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (_isBlocked)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block,
                          size: 64,
                          color: Colors.red.shade200,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'You have blocked ${widget.otherUserName}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Unblock to continue chatting',
                          style: TextStyle(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  StreamBuilder<List<MessageModel>>(
                    stream: _messageService.getMessages(
                      widget.conversationId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}'),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _initializeChat(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      final messages = snapshot.data!;

                      if (messages.isNotEmpty) {
                        final lastMsg = messages.last;
                        if (lastMsg.senderId != currentUser.uid) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _onNewMessage();
                          });
                        }
                      }

                      _reconcilePending(messages, currentUser.uid);

                      if (messages.isEmpty && _pendingMessages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Send a message to start the conversation',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      final items = <dynamic>[];
                      DateTime? lastDate;
                      for (final m in messages) {
                        final d = DateTime(
                          m.sentAt.year,
                          m.sentAt.month,
                          m.sentAt.day,
                        );
                        if (lastDate == null || d != lastDate) {
                          items.add(d);
                          lastDate = d;
                        }
                        items.add(m);
                      }
                      for (final p in _pendingMessages) {
                        final d = DateTime(
                          p.sentAt.year,
                          p.sentAt.month,
                          p.sentAt.day,
                        );
                        if (lastDate == null || d != lastDate) {
                          items.add(d);
                          lastDate = d;
                        }
                        items.add(p);
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          if (item is DateTime) {
                            return _buildDateSeparator(item);
                          }
                          if (item is _PendingMessage) {
                            return _buildPendingBubble(item);
                          }
                          final message = item as MessageModel;
                          final isMe = message.senderId == currentUser.uid;
                          return _buildMessageBubble(message, isMe);
                        },
                      );
                    },
                  ),
                if (_showScrollToBottom && !_isBlocked)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'scrollToBottom',
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF2563EB),
                      elevation: 2,
                      onPressed: () {
                        _isUserScrolling = false;
                        _scrollToBottom(animated: true);
                      },
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                  ),
              ],
            ),
          ),
          if (_isOtherUserTyping && !_isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.otherUserName} is typing...',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          if (_replyingTo != null) _buildReplyPreviewBar(),
          _buildMessageInput(),
        ],
      ),
    );
  }
}