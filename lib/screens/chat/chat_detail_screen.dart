import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/models/chat_model.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/services/chat_service.dart';
import 'package:cookrange/core/services/firestore_service.dart';
import 'package:cookrange/core/models/user_model.dart';
import 'package:cookrange/core/services/storage_upload_service.dart';
import 'package:cookrange/core/utils/profile_navigation.dart';
import 'package:cookrange/core/widgets/ds/ds.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _isUploadingImage = false;

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

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingImage = true);
    try {
      final url = await StorageUploadService().uploadChatImage(
        userId: _currentUserId,
        imageFile: File(picked.path),
      );
      if (!mounted) return;
      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        text: url,
        type: MessageType.image,
      );
      if (_scrollController.hasClients) {
        unawaited(_scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
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
      return "Az önce";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes} dk önce";
    } else if (difference.inHours < 24 && _isSameDay(now, timestamp)) {
      return "${difference.inHours} saat önce";
    } else if (difference.inDays < 1 && !_isSameDay(now, timestamp)) {
      return "Dün ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
    } else {
      return "${timestamp.day}/${timestamp.month}/${timestamp.year}";
    }
  }

  void _showMoreOptions(BuildContext context, AppPalette palette,
      AppLocalizations l10n) {
    AppSheet.show(
      context: context,
      title: l10n.translate('chat.more_options'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_otherUserId.isNotEmpty)
            ListTile(
              leading:
                  Icon(Icons.person_outline_rounded, color: palette.textPrimary),
              title: Text(l10n.translate('chat.view_profile'),
                  style: AppText.of(context)
                      .bodyM
                      .copyWith(color: palette.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                openUserProfile(context, userId: _otherUserId);
              },
            ),
          ListTile(
            leading:
                Icon(Icons.flag_outlined, color: palette.error),
            title: Text(l10n.translate('community.menu.report'),
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.error)),
            onTap: () {
              Navigator.pop(context);
              if (_otherUserId.isNotEmpty) {
                _showReportDialog(context, palette, l10n);
              }
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, AppPalette palette,
      AppLocalizations l10n) {
    final reasons = [
      l10n.translate('community.report.reason_spam'),
      l10n.translate('community.report.reason_harassment'),
      l10n.translate('community.report.reason_inappropriate'),
      l10n.translate('community.report.reason_other'),
    ];
    String? selectedReason;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text(l10n.translate('community.report.dialog_title'),
              style:
                  AppText.of(context).titleM.copyWith(color: palette.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons.map((r) {
              final isSelected = selectedReason == r;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r,
                    style: AppText.of(context)
                        .bodyM
                        .copyWith(color: palette.textPrimary)),
                trailing: isSelected
                    ? Icon(Icons.check_rounded,
                        color: palette.info, size: 20)
                    : null,
                onTap: () => setDialogState(() => selectedReason = r),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.translate('common.cancel'),
                  style: TextStyle(color: palette.textSecondary)),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await FirebaseFirestore.instance
                            .collection('reports')
                            .add({
                          'reportedBy':
                              FirebaseAuth.instance.currentUser?.uid ?? '',
                          'targetId': _otherUserId,
                          'targetType': 'user',
                          'reason': selectedReason,
                          'status': 'pending',
                          'timestamp': FieldValue.serverTimestamp(),
                        });
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(l10n
                                  .translate('community.report.submitted')),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (_) {}
                    },
              child: Text(l10n.translate('common.confirm'),
                  style: TextStyle(
                      color: selectedReason != null
                          ? palette.info
                          : palette.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final appText = AppText.of(context);
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AppBar(
              backgroundColor: palette.surface.withValues(alpha: 0.8),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: palette.textPrimary),
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

                    if (widget.chat.type != ChatType.private) {
                      // Group/gym titles stay as passed in widget.chat
                    }

                    return GestureDetector(
                      onTap: (widget.chat.type == ChatType.private &&
                              _otherUserId.isNotEmpty)
                          ? () => openUserProfile(context, userId: _otherUserId)
                          : null,
                      child: Row(
                      children: [
                        if (chatImage != null)
                          CircleAvatar(
                            backgroundImage: NetworkImage(chatImage),
                            radius: 16,
                          )
                        else
                          CircleAvatar(
                            backgroundColor: palette.surfaceVariant,
                            radius: 16,
                            child: Icon(
                              Icons.person,
                              size: 20,
                              color: palette.textTertiary,
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
                                style: appText.titleM.copyWith(
                                  color: palette.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.chat.type == ChatType.private)
                                if (isOnline)
                                  Text(
                                    'Online',
                                    style: TextStyle(
                                      color: palette.success,
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
                                      color: palette.textTertiary,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    );
                  }),
              actions: [
                IconButton(
                  icon: Icon(Icons.more_vert, color: palette.textPrimary),
                  onPressed: () => _showMoreOptions(context, palette, localizations),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: palette.background),
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
                          style: TextStyle(color: palette.textTertiary),
                        ),
                      );
                    }

                    final messages = snapshot.data!;

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: const EdgeInsets.only(
                          top: 100, bottom: 20, left: 16, right: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == _currentUserId;

                        bool showDateSeparator = false;
                        if (index == messages.length - 1) {
                          showDateSeparator = true;
                        } else {
                          final nextMessage = messages[index + 1];
                          if (!_isSameDay(
                              message.timestamp, nextMessage.timestamp)) {
                            showDateSeparator = true;
                          }
                        }

                        final br = BorderRadius.circular(20).copyWith(
                          bottomRight: isMe
                              ? const Radius.circular(0)
                              : const Radius.circular(20),
                          bottomLeft: isMe
                              ? const Radius.circular(20)
                              : const Radius.circular(0),
                        );
                        final isImage = message.type == MessageType.image;
                        final timestampWidget = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}",
                              style: TextStyle(
                                fontSize: 10,
                                // On image overlays keep white; on text bubbles use palette
                                color: isImage
                                    ? Colors.white
                                    : (isMe
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : palette.textTertiary),
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
                                    ? palette.info
                                    : Colors.white.withValues(alpha: 0.7),
                              ),
                            ],
                          ],
                        );

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
                                constraints:
                                    const BoxConstraints(maxWidth: 240),
                                decoration: BoxDecoration(
                                  color: isImage
                                      ? null
                                      : (isMe
                                          ? theme.primaryColor
                                          : palette.surfaceVariant),
                                  borderRadius: br,
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.shadow
                                          .withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: isImage
                                    ? ClipRRect(
                                        borderRadius: br,
                                        child: Stack(
                                          children: [
                                            Image.network(
                                              message.text,
                                              fit: BoxFit.cover,
                                              width: 240,
                                              loadingBuilder:
                                                  (ctx, child, progress) =>
                                                      progress == null
                                                          ? child
                                                          : const SizedBox(
                                                              width: 240,
                                                              height: 180,
                                                              child: Center(
                                                                child:
                                                                    CircularProgressIndicator(),
                                                              ),
                                                            ),
                                              errorBuilder:
                                                  (ctx, err, st) =>
                                                      SizedBox(
                                                        width: 240,
                                                        height: 180,
                                                        child: Center(
                                                          child: Icon(
                                                              Icons.broken_image,
                                                              color: palette.textTertiary),
                                                        ),
                                                      ),
                                            ),
                                            Positioned(
                                              bottom: 6,
                                              right: 8,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.black54,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: timestampWidget,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              message.text,
                                              style: TextStyle(
                                                // sent → white (intentional contrast); received → textPrimary
                                                color: isMe
                                                    ? Colors.white
                                                    : palette.textPrimary,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            timestampWidget,
                                          ],
                                        ),
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
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: palette.surface.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.shadow.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: palette.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Yazıyor...",
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                  color: palette.surface,
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _isUploadingImage
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            color: palette.textTertiary,
                            onPressed: _pickAndSendImage,
                          ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: palette.surfaceVariant,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: localizations.translate(
                                'chat.actions.placeholder_message_input'),
                            hintStyle: TextStyle(color: palette.textTertiary),
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
    final palette = AppPalette.of(context);
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
      text =
          "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
