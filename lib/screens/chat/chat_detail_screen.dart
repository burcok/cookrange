import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/models/chat_model.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/services/chat_service.dart';
import 'package:cookrange/core/services/firestore_service.dart';
import 'package:cookrange/core/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatModel chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatService _chatService = ChatService();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  Timer? _typingDebounce;

  Stream<List<MessageModel>>? _messageStream;
  Stream<DocumentSnapshot>? _otherUserStream;
  Stream<ChatModel>? _chatStream;
  String _otherUserId = '';

  @override
  void initState() {
    super.initState();
    _messageStream = _chatService.getChatMessages(widget.chat.id);
    _chatStream = _chatService.getChat(widget.chat.id);
    _chatService.markChatAsRead(widget.chat.id, _currentUserId);

    if (widget.chat.type == ChatType.private) {
      _otherUserId = widget.chat.participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      if (_otherUserId.isNotEmpty) {
        _otherUserStream = FirestoreService().getUserDocStream(_otherUserId);
      }
    }

    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _typingDebounce?.cancel();
    // Set not typing on exit
    if (_otherUserId.isNotEmpty) {
      _chatService.setTypingStatus(widget.chat.id, _currentUserId, false);
    }
    super.dispose();
  }

  void _onTextChanged() {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();

    _chatService.setTypingStatus(widget.chat.id, _currentUserId, true);

    _typingDebounce = Timer(const Duration(milliseconds: 1500), () {
      _chatService.setTypingStatus(widget.chat.id, _currentUserId, false);
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    _chatService.sendMessage(
      chatId: widget.chat.id,
      senderId: _currentUserId,
      text: _messageController.text.trim(),
    );

    _messageController.clear();
    // Reset typing status immediately
    _typingDebounce?.cancel();
    _chatService.setTypingStatus(widget.chat.id, _currentUserId, false);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  String _formatLastActive(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return "Az önce"; // Just now
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} dk önce";
    } else if (difference.inHours < 24 && _isSameDay(now, timestamp)) {
      return "${difference.inHours} saat önce";
    } else if (difference.inDays < 1 && !_isSameDay(now, timestamp)) {
      // Yesterday logic could be here, but "Dün" usually implies 1 day diff
      return "Dün ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
    } else {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AppBar(
              backgroundColor: isDark
                  ? const Color(0xFF111827).withOpacity(0.8)
                  : Colors.white.withOpacity(0.8),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back,
                    color: isDark ? Colors.white : Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: StreamBuilder<DocumentSnapshot>(
                  stream: _otherUserStream,
                  builder: (context, snapshot) {
                    String chatTitle = widget.chat.name ?? 'Chat';
                    String? chatImage = widget.chat.image;
                    bool isOnline = false;
                    DateTime? lastActiveAt;

                    if (snapshot.hasData &&
                        snapshot.data != null &&
                        snapshot.data!.exists) {
                      final user = UserModel.fromFirestore(snapshot.data!
                          as DocumentSnapshot<Map<String, dynamic>>);
                      chatTitle = user.displayName ?? chatTitle;
                      chatImage = user.photoURL ?? chatImage;
                      isOnline = user.isOnline;
                      lastActiveAt = user.lastActiveAt?.toDate();
                    }

                    // Fallback for non-private chats remains static for now
                    if (widget.chat.type != ChatType.private) {
                      // Logic for group/gym titles/images remains as passed in widget.chat
                    }

                    return Row(
                      children: [
                        if (chatImage != null)
                          CircleAvatar(
                            backgroundImage: NetworkImage(chatImage),
                            radius: 16,
                          )
                        else
                          CircleAvatar(
                            backgroundColor: Colors.grey.shade300,
                            radius: 16,
                            child: Icon(
                              Icons.person,
                              size: 20,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                chatTitle,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.chat.type == ChatType.private)
                                if (isOnline)
                                  const Text(
                                    'Online',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 12,
                                    ),
                                  )
                                else if (lastActiveAt != null)
                                  Text(
                                    localizations.translate(
                                        'profile.chat.last_active_at',
                                        variables: {
                                          'time': _formatLastActive(
                                              context, lastActiveAt)
                                        }),
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
              actions: [
                IconButton(
                  icon: Icon(Icons.more_vert,
                      color: isDark ? Colors.white : Colors.black),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient/Image
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _messageStream ??=
                      _chatService.getChatMessages(widget.chat.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text(
                          'No messages yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    final messages = snapshot.data!;

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Chat fills from bottom
                      padding: const EdgeInsets.only(
                          top: 100, bottom: 20, left: 16, right: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == _currentUserId;

                        // Check if we need a date separator
                        // Since list is reversed:
                        // current (index) is NEWER than next (index + 1)
                        // We want separator ABOVE the OLDER message when day changes?
                        // Wait, list is reversed. Bottom is index 0 (Newest). Top is index length-1 (Oldest).
                        // Visual order: Top -> Bottom (Old -> New)
                        // ListView order: Bottom -> Top (0 -> N)

                        // We want separator ABOVE a group of messages from the same day.
                        // In a reserved list, "Above" means "After" in the list (higher index).
                        // So if message[index] and message[index+1] are different days,
                        // the separator should be displayed *between* them?
                        // No, customary in chat: Date Header, then messages.
                        // So if I am at `index` (Newer), and `index+1` (Older) is different day:
                        // That means `index` is the START of a new day block (visually bottom-most of that day block?).
                        // Actually, simpler:
                        // Iterate through messages.
                        // If it's the last message (visually top, index == length-1), SHOW separator.
                        // If `message[index]` (newer) and `message[index+1]` (older) have different dates,
                        // then `message[index]` is the FIRST message of the NEWER day.
                        // So we should show a separator ABOVE `message[index]`.
                        // Since it's `reverse: true`, "Above" means "After" in render order?
                        // "Head" of the list in reverse view is the bottom.
                        // So `ItemBuilder` returns widgets starting from bottom.

                        // Let's visualize:
                        // [Msg 2 (Today 10:05)] (Index 0)
                        // [Msg 1 (Today 10:00)] (Index 1)
                        // [Separator Today]
                        // [Msg 0 (Yesterday 23:00)] (Index 2)
                        // [Separator Yesterday]

                        // At Index 0: Next is Index 1 (Today). Same day. Just show Msg 2.
                        // At Index 1: Next is Index 2 (Yesterday). Diff day. Show Msg 1 AND Separator Today?
                        // If we attach separator to Index 1, it will be "below" Msg 1 in code, but "above" visually?
                        // Reverse View:
                        // Item 0: Bottom-most.
                        // Item 1: Above Item 0.
                        // So if I return a Column([Separator, Msg]), in reverse view:
                        // The Column is one item.
                        // Visually:
                        // Separator
                        // Msg
                        // This seems correct for "Date header above message".

                        bool showDateSeparator = false;
                        if (index == messages.length - 1) {
                          // Last item (visually top-most), always show date
                          showDateSeparator = true;
                        } else {
                          final nextMessage =
                              messages[index + 1]; // Older message
                          if (!_isSameDay(
                              message.timestamp, nextMessage.timestamp)) {
                            showDateSeparator = true;
                          }
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (showDateSeparator)
                              _DateSeparator(date: message.timestamp),
                            Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? theme.primaryColor
                                      : (isDark
                                          ? const Color(0xFF374151)
                                          : Colors.white),
                                  borderRadius:
                                      BorderRadius.circular(20).copyWith(
                                    bottomRight: isMe
                                        ? const Radius.circular(0)
                                        : const Radius.circular(20),
                                    bottomLeft: isMe
                                        ? const Radius.circular(20)
                                        : const Radius.circular(0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      message.text,
                                      style: TextStyle(
                                        color: isMe
                                            ? Colors.white
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white.withOpacity(0.7)
                                                : Colors.grey,
                                          ),
                                        ),
                                        if (isMe) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            message.isRead
                                                ? Icons.done_all
                                                : Icons.done,
                                            size: 14,
                                            color: message.isRead
                                                ? Colors.blue.shade100
                                                : Colors.white.withOpacity(0.7),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Typing Indicator
              if (widget.chat.type == ChatType.private)
                StreamBuilder<ChatModel>(
                    stream: _chatStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final chatData = snapshot.data!;
                      final typingUsers = chatData.typingUsers ?? {};
                      final isOtherTyping = typingUsers[_otherUserId] ?? false;

                      if (!isOtherTyping) return const SizedBox.shrink();

                      return Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                color: isDark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.black.withOpacity(0.05),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Yazıyor...", // Could be localized
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

              // Input Area
              Container(
                padding: EdgeInsets.fromLTRB(
                    16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1F2937) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      color: Colors.grey,
                      onPressed: () {},
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF374151)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: localizations.translate(
                                'chat.actions.placeholder_message_input'),
                            hintStyle: const TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.send,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;

  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    String text;
    final localizations = AppLocalizations.of(context);

    if (dateToCheck == today) {
      text = localizations.translate('profile.chat.today');
    } else if (dateToCheck == yesterday) {
      text = localizations.translate('profile.chat.yesterday');
    } else {
      // Fallback or full date
      // Simple manual formatting or use intl if available in project
      // Since we are not sure about intl package availability in this file context without seeing imports,
      // we'll do a simple format: DD/MM/YYYY
      text =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: isDark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              child: Text(
                text,
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
