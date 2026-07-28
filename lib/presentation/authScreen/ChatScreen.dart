import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../Services/FirebaseMessageService.dart';
import '../../model/MessageModel.dart';

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

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.requestId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseMessageService _messageService = FirebaseMessageService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final FocusNode _focusNode = FocusNode(); // ✅ For keyboard handling

  final bool _isSending = false;
  bool _isLoading = true;
  bool _isOtherUserOnline = false;
  DateTime? _otherUserLastSeen;
  Timer? _typingTimer;
  bool _isOtherUserTyping = false;

  final List<_PendingMessage> _pendingMessages = [];
  _ReplyPreview? _replyingTo;
  bool _showScrollToBottom = false;
  bool _isUserScrolling = false; // ✅ Track user scrolling
  Timer? _scrollDebounceTimer;
  double _lastBottomInset = 0; // ✅ Reliable keyboard open/close detector

  @override
  void initState() {
    super.initState();

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

    // ✅ Keyboard listener for auto-scroll
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

  // ✅ Handle keyboard open/close (backup path — build() handles the main case
  // via viewInsets, this covers the instant the field is tapped)
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

    // ✅ Detect if user is scrolling up (away from bottom)
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
        })
        .catchError((_) {});

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

    // ✅ Sending is an explicit user action — always jump to bottom.
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
      );
      // Fallback cleanup
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

      // ✅ Sending is an explicit user action — always jump to bottom.
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

  /// [force] = true skips the "user is reading old messages" guard.
  /// Use force for things the user explicitly triggered (sending a message,
  /// tapping the input field / keyboard opening, tapping the scroll-down FAB).
  /// Leave force = false for background events (a new message arriving from
  /// the other person while the user is scrolled up reading history).
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

    // Fire once right after this frame (covers the common case fast)...
    WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    // ...and once more shortly after, to cover keyboard-open / list-resize
    // animations that are still settling when the first call fires.
    Future.delayed(const Duration(milliseconds: 260), doScroll);
  }

  // ✅ Called when new messages arrive
  void _onNewMessage() {
    if (!_scrollController.hasClients) return;
    final isNearBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset <
        200;
    // Only yank the view if the user was already essentially at the bottom.
    if (isNearBottom) {
      _scrollToBottom(animated: true, force: true);
    }
  }

  // Removes any pending message once the real one has landed
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    // ✅ Most reliable way to detect the keyboard opening/closing: Flutter
    // rebuilds this widget automatically whenever viewInsets changes, so we
    // just compare against the last known value. When it grows (keyboard
    // opening), push the list to the bottom so the latest message stays
    // visible above the keyboard — exactly like WhatsApp.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset > _lastBottomInset + 1) {
      _scrollToBottom(animated: true, force: true);
    }
    _lastBottomInset = bottomInset;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                Text(_getLastSeenText(), style: const TextStyle(fontSize: 10)),
                if (_isOtherUserTyping) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'typing...',
                    style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showRequestDetails(),
            icon: const Icon(Icons.info_outline),
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

                          // ✅ Check if new message arrived from other user
                          if (messages.isNotEmpty) {
                            final lastMsg = messages.last;
                            if (lastMsg.senderId != currentUser.uid) {
                              // ✅ Auto-scroll on new message from other user
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

                          // Build flat list
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
                      if (_showScrollToBottom)
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
                if (_isOtherUserTyping)
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
                color: Colors.grey.withValues(alpha: 0.15),
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
    // ✅ Focus on text field when replying
    _focusNode.requestFocus();
  }

  void _showMessageActions(MessageModel message, bool isMe) {
    final decoded = _decodeReplyMessage(message.message);
    final isImage = message.messageType == 'image' && message.imageUrl != null;
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
            ListTile(
              leading: const Icon(Icons.reply, color: Color(0xFF2563EB)),
              title: const Text('Reply'),
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
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(context);
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
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotedReplyBlock(Map<String, String> decoded, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.white.withValues(alpha: 0.15)
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
      onLongPress: () => _showMessageActions(message, isMe),
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
                        color: Colors.grey.withValues(alpha: 0.1),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
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
                focusNode: _focusNode, // ✅ Attach focus node
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
}
