import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/models/chat_model.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/models/user_model.dart';
import 'package:cookrange/core/providers/user_provider.dart';
import 'package:cookrange/core/services/active_chat_tracker.dart';
import 'package:cookrange/core/services/chat_send_failure_store.dart';
import 'package:cookrange/core/services/chat_service.dart';
import 'package:cookrange/core/services/community_group_service.dart';
import 'package:cookrange/core/services/crashlytics_service.dart';
import 'package:cookrange/core/services/permission_service.dart';
import 'package:cookrange/core/services/plan_offer_service.dart';
import 'package:cookrange/core/services/presence_service.dart';
import 'package:cookrange/core/services/storage_upload_service.dart';
import 'package:cookrange/core/services/voice_playback_service.dart';
import 'package:cookrange/core/utils/chat_message_merge.dart';
import 'package:cookrange/core/utils/message_status.dart';
import 'package:cookrange/core/utils/profile_navigation.dart';
import 'package:cookrange/core/utils/waveform_downsample.dart';
import 'package:cookrange/core/widgets/ds/ds.dart';
import 'package:cookrange/screens/chat/widgets/media_gallery_screen.dart';
import 'package:cookrange/screens/community/groups/group_info_screen.dart';
import 'package:cookrange/screens/plan_offers/offer_preview_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

/// A one-line, kind-aware preview for any non-text message — reply
/// previews, context-menu previews, and the pinned-message banner all show
/// the same "📷 Photo"/"🎤 Voice message" style summary instead of raw body
/// text (which is empty for these types anyway). Top-level (not a method on
/// `_ChatDetailScreenState`) so `_PinnedBannerResolver` below, a separate
/// widget, can share it without duplicating the branch.
String previewTextFor(AppLocalizations l10n, MessageModel m) {
  switch (m.type) {
    case MessageType.image:
      return l10n.translate('chat.preview.photo');
    case MessageType.voice:
      return l10n.translate('chat.preview.voice');
    default:
      return m.body;
  }
}

/// Faz 2 §2.2 — chat screen rebuild. Replaces the old ad-hoc private-method
/// bubble rendering with the reusable `lib/core/widgets/ds/chat/` components:
/// long-press context menu (reply/forward/copy/react/pin/star/edit/delete/
/// report), swipe-to-reply, cursor-paginated history, jump-to-date, a pinned-
/// message banner, a full media gallery, in-chat search, haptics throughout,
/// and reduced-motion support.
class ChatDetailScreen extends StatefulWidget {
  final ChatModel chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  static const int _pageSize = 30;

  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  final ChatService _chatService = ChatService();
  final CommunityGroupService _groupService = CommunityGroupService();
  final ChatSendFailureStore _failureStore = ChatSendFailureStore();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final Map<String, GlobalKey> _messageKeys = {};

  // Faz 2 §2.6 — resolved once per screen-open (not per long-press) so
  // `_showContextMenu` can stay synchronous. Only ever true for a
  // group-backed chat (`widget.chat.groupId != null`); a DM has no concept
  // of "moderator".
  bool _isGroupModerator = false;

  Timer? _typingDebounce;
  Timer? _highlightTimer;
  bool _isUploading = false;

  // Faz 6 — voice message recording state. The composer's mic button owns
  // the actual press/drag/release gesture (see `AppMessageComposer`'s doc
  // comment on `onMicPressStart` for why); this screen just holds the
  // recording session itself.
  AudioRecorder? _voiceRecorder;
  Timer? _voiceElapsedTimer;
  Duration _voiceElapsed = Duration.zero;
  final List<double> _voiceRawAmplitudes = [];
  StreamController<double>? _voiceAmplitudeController;
  StreamSubscription<Amplitude>? _voiceAmplitudeSub;
  bool _isRecordingVoice = false;
  bool _isVoiceLocked = false;
  double _voiceDragDx = 0;
  double _voiceDragDy = 0;
  String? _voiceRecordingPath;

  Stream<List<MessageModel>>? _messageStream;
  Stream<UserModel>? _otherUserStream;
  Stream<ChatModel>? _chatStream;
  Stream<Set<String>>? _starredIdsStream;
  String _otherUserId = '';

  // Cursor pagination — the live stream covers the newest [_pageSize]
  // messages; `_olderMessages` extends it backward on scroll.
  List<MessageModel> _liveMessagesCache = [];
  List<MessageModel> _olderMessages = [];
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;

  // Jump mode (date-jump or search-result-jump): a static, non-live snapshot
  // replacing the normal live+older combination until the user backs out.
  List<MessageModel>? _jumpMessages;
  bool _isLoadingJump = false;

  MessageModel? _replyingTo;
  MessageModel? _editingMessage;

  // Group/gym sender-name + @mention resolution. Bounded whereIn (10),
  // mirrors ChatService.getUserChatsWithStatus's existing convention.
  Map<String, String> _nameCache = {};
  List<AppMentionCandidate> _mentionCandidates = [];

  // Unread divider — computed ONCE from the first snapshot (freezing it
  // avoids the divider vanishing mid-view as markChatAsRead stamps read_by).
  bool _unreadDividerComputed = false;
  String? _unreadDividerBeforeId;
  int _unreadDividerCount = 0;

  String? _highlightedMessageId;

  bool _searchMode = false;
  bool _searching = false;
  List<MessageModel> _searchSource = [];
  List<MessageModel> _searchResults = [];

  @override
  void initState() {
    super.initState();
    ActiveChatTracker().setActive(widget.chat.id);
    _messageStream =
        _chatService.getChatMessages(widget.chat.id, limit: _pageSize);
    _chatStream = _chatService.getChat(widget.chat.id);
    _starredIdsStream = _chatService.streamStarredMessageIds(_currentUserId);
    _chatService.markChatAsRead(widget.chat.id, _currentUserId);

    if (widget.chat.type == ChatType.private) {
      _otherUserId = widget.chat.participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      if (_otherUserId.isNotEmpty) {
        _otherUserStream = _chatService.watchUser(_otherUserId);
      }
    }

    if (widget.chat.participants.isNotEmpty) {
      _chatService.getUserDisplayNames(widget.chat.participants).then((names) {
        if (mounted) setState(() => _nameCache = names);
      });
    }

    final groupId = widget.chat.groupId;
    if (groupId != null) {
      // context.read is safe here — initState runs once, before any
      // rebuild, and UserProvider is provided above MaterialApp.
      final isSiteAdmin = context.read<UserProvider>().isAdmin;
      if (isSiteAdmin) {
        _isGroupModerator = true;
      } else {
        _groupService.isOwnerOrGroupAdmin(groupId, _currentUserId).then((v) {
          if (mounted) setState(() => _isGroupModerator = v);
        });
      }
    }

    _messageController.addListener(_onTextChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    ActiveChatTracker().clear(widget.chat.id);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _composerFocusNode.dispose();
    _typingDebounce?.cancel();
    _highlightTimer?.cancel();
    if (_otherUserId.isNotEmpty) {
      PresenceService().setTyping(widget.chat.id, _currentUserId, false);
    }
    _voiceElapsedTimer?.cancel();
    _voiceAmplitudeSub?.cancel();
    _voiceAmplitudeController?.close();
    _voiceRecorder?.dispose();
    // App-wide singleton — must not keep playing a voice note after this
    // screen closes (VoicePlaybackService's own class doc).
    unawaited(VoicePlaybackService().stop());
    super.dispose();
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _labelFor(String uid) {
    if (uid == _currentUserId) return _l10n.translate('common.you');
    return _nameCache[uid] ?? '';
  }

  // ─── Typing status + @mention detection ──────────────────────────────────

  void _onTextChanged() {
    if (_typingDebounce?.isActive ?? false) _typingDebounce!.cancel();
    PresenceService().setTyping(widget.chat.id, _currentUserId, true);
    _typingDebounce = Timer(const Duration(milliseconds: 1500), () {
      PresenceService().setTyping(widget.chat.id, _currentUserId, false);
    });
    _updateMentionCandidates();
  }

  void _updateMentionCandidates() {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      if (_mentionCandidates.isNotEmpty) {
        setState(() => _mentionCandidates = []);
      }
      return;
    }
    final upToCursor = text.substring(0, cursor);
    final atIndex = upToCursor.lastIndexOf('@');
    if (atIndex == -1 ||
        upToCursor.substring(atIndex).contains(RegExp(r'[\s\n]'))) {
      if (_mentionCandidates.isNotEmpty) {
        setState(() => _mentionCandidates = []);
      }
      return;
    }
    final query = upToCursor.substring(atIndex + 1).toLowerCase();
    final matches = _nameCache.entries
        .where((e) =>
            e.key != _currentUserId &&
            e.value.isNotEmpty &&
            e.value.toLowerCase().startsWith(query))
        .take(5)
        .map((e) => AppMentionCandidate(uid: e.key, name: e.value))
        .toList();
    setState(() => _mentionCandidates = matches);
  }

  void _onSelectMention(AppMentionCandidate candidate) {
    final text = _messageController.text;
    final cursor = _messageController.selection.baseOffset < 0
        ? text.length
        : _messageController.selection.baseOffset;
    final upToCursor = text.substring(0, cursor);
    final atIndex = upToCursor.lastIndexOf('@');
    if (atIndex == -1) return;
    final before = text.substring(0, atIndex);
    final after = text.substring(cursor);
    final insertion = '@${candidate.name} ';
    _messageController.value = TextEditingValue(
      text: '$before$insertion$after',
      selection: TextSelection.collapsed(offset: (before + insertion).length),
    );
    setState(() => _mentionCandidates = []);
  }

  /// Re-scans the final text for "@FullName" occurrences rather than
  /// tracking insertion offsets live — robust to further edits after a
  /// mention is inserted, at the cost of not catching a manually-typed
  /// "@SomeoneNotInCache".
  List<MessageMention> _extractMentions(String text) {
    final mentions = <MessageMention>[];
    _nameCache.forEach((uid, name) {
      if (name.isEmpty) return;
      final token = '@$name';
      var searchFrom = 0;
      while (true) {
        final idx = text.indexOf(token, searchFrom);
        if (idx == -1) break;
        mentions.add(MessageMention(uid: uid, offset: idx, len: token.length));
        searchFrom = idx + token.length;
      }
    });
    mentions.sort((a, b) => a.offset.compareTo(b.offset));
    return mentions;
  }

  // ─── Sending ──────────────────────────────────────────────────────────────

  MessageReplyTo _buildReplyTo(MessageModel m) {
    String preview;
    if (m.isDeletedFor(_currentUserId)) {
      preview = _l10n.translate('chat.message.deleted_placeholder');
    } else if (m.type == MessageType.image || m.type == MessageType.voice) {
      preview = previewTextFor(_l10n, m);
    } else {
      preview = m.body.length > 120 ? '${m.body.substring(0, 120)}…' : m.body;
    }
    return MessageReplyTo(
        id: m.id,
        senderId: m.senderId,
        preview: preview,
        kind: m.type.wireValue);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final reduceMotion = AccessibilityUtils.reduceMotion(context);
    if (reduceMotion) {
      _scrollController.jumpTo(0);
    } else {
      _scrollController.animateTo(0,
          duration: AppMotion.normal, curve: AppMotion.standard);
    }
  }

  Future<void> _handleSendTap() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessage != null) {
      await _chatService.editMessage(
        chatId: widget.chat.id,
        messageId: _editingMessage!.id,
        newBody: text,
      );
      _messageController.clear();
      setState(() => _editingMessage = null);
      return;
    }

    final replyTo = _replyingTo != null ? _buildReplyTo(_replyingTo!) : null;
    final mentions = _extractMentions(text);
    final clientId = _chatService.newClientId();

    // Faz 0 §0.2 — clear the composer synchronously and fire the send
    // unawaited. Firestore's own offline mutation queue
    // (`persistenceEnabled: true`) echoes the pending write to this
    // screen's own `getChatMessages` listener immediately and retries every
    // recoverable failure automatically, including across an app restart —
    // there is nothing to wait on here. Only a hard rejection needs custom
    // handling, via `_handleSendFailure` below.
    _messageController.clear();
    _typingDebounce?.cancel();
    unawaited(
        PresenceService().setTyping(widget.chat.id, _currentUserId, false));
    setState(() {
      _replyingTo = null;
      _mentionCandidates = [];
    });
    _scrollToBottom();

    unawaited(_chatService
        .sendMessage(
      chatId: widget.chat.id,
      senderId: _currentUserId,
      body: text,
      replyTo: replyTo,
      mentions: mentions,
      clientId: clientId,
    )
        .catchError((Object error) {
      _handleSendFailure(
        clientId: clientId,
        type: MessageType.text,
        body: text,
        replyTo: replyTo,
        mentions: mentions,
        error: error,
      );
    }));
  }

  /// A hard-rejected send never reaches Firestore's cache, so it needs a
  /// synthetic bubble the user can see and retry — `_buildMessageList`
  /// merges this store's contents in via `ChatMessageMerge` (Faz 0 §0.2).
  /// Anything else `sendMessage` can throw is not a
  /// `ChatSendRejectedException` (the service itself only rethrows a
  /// recoverable failure), which Firestore's own mutation queue is already
  /// retrying — reporting or remembering that here would just be noise.
  void _handleSendFailure({
    required String clientId,
    required MessageType type,
    required String body,
    List<MessageAttachment> attachments = const [],
    MessageReplyTo? replyTo,
    List<MessageMention> mentions = const [],
    required Object error,
  }) {
    if (error is! ChatSendRejectedException) return;

    _failureStore.add(PendingSendFailure(
      clientId: clientId,
      chatId: widget.chat.id,
      senderId: _currentUserId,
      type: type,
      body: body,
      attachments: attachments,
      replyTo: replyTo,
      mentions: mentions,
      createdAt: DateTime.now(),
      errorCode: error.code,
    ));

    debugPrint(
        'ChatDetailScreen: send rejected chatId=${widget.chat.id} code=${error.code}');
    unawaited(CrashlyticsService().recordError(
      error,
      StackTrace.current,
      reason:
          'ChatDetailScreen.sendMessage rejected chatId=${widget.chat.id} code=${error.code}',
    ));
  }

  /// Re-sends a failed message with the SAME clientId — `ChatMessageMerge`
  /// treats a live doc bearing that id as superseding its own failure
  /// record, so a successful retry replaces the failed bubble in place.
  void _retryFailedSend(MessageModel m) {
    _failureStore.remove(widget.chat.id, m.clientId);
    unawaited(_chatService
        .sendMessage(
      chatId: widget.chat.id,
      senderId: m.senderId,
      body: m.body,
      type: m.type,
      attachments: m.attachments,
      replyTo: m.replyTo,
      mentions: m.mentions,
      clientId: m.clientId,
    )
        .catchError((Object error) {
      _handleSendFailure(
        clientId: m.clientId,
        type: m.type,
        body: m.body,
        attachments: m.attachments,
        replyTo: m.replyTo,
        mentions: m.mentions,
        error: error,
      );
    }));
  }

  String _chatImageScope() {
    final c = widget.chat;
    if (c.type == ChatType.private && c.participants.length == 2) {
      final ids = [...c.participants]..sort();
      return ids.join('_');
    }
    return c.id;
  }

  Future<void> _pickAndSendImages({required bool camera}) async {
    final granted = camera
        ? await PermissionService().requestCamera(context)
        : await PermissionService().requestPhotos(context);
    if (!mounted || !granted) return;

    final picker = ImagePicker();
    final List<XFile> picked;
    if (camera) {
      final single =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      picked = single != null ? [single] : [];
    } else {
      picked = await picker.pickMultiImage(imageQuality: 80);
    }
    if (picked.isEmpty || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final attachments = <MessageAttachment>[];
      for (final file in picked) {
        // Faz 5 (Piece C) — uploadChatImage now also returns a thumbnail
        // URL + the full image's pixel dimensions, generated from the same
        // decode pass as the full-size image (storage_upload_service.dart).
        final uploaded = await StorageUploadService().uploadChatImage(
          chatScopeId: _chatImageScope(),
          imageFile: File(file.path),
        );
        attachments.add(MessageAttachment(
          kind: 'image',
          url: uploaded.url,
          thumbUrl: uploaded.thumbUrl,
          width: uploaded.width,
          height: uploaded.height,
        ));
      }
      if (!mounted) return;
      final replyTo = _replyingTo;
      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        type: MessageType.image,
        attachments: attachments,
        replyTo: replyTo != null ? _buildReplyTo(replyTo) : null,
      );
      setState(() => _replyingTo = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showAttachSheet() {
    final palette = AppPalette.of(context);
    AppSheet.show(
      context: context,
      title: _l10n.translate('chat.attach_sheet_title'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading:
                Icon(Icons.photo_camera_outlined, color: palette.textPrimary),
            title: Text(_l10n.translate('chat.actions.camera'),
                style: AppText.of(context)
                    .bodyL
                    .copyWith(color: palette.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _pickAndSendImages(camera: true);
            },
          ),
          ListTile(
            leading:
                Icon(Icons.photo_library_outlined, color: palette.textPrimary),
            title: Text(_l10n.translate('chat.actions.gallery'),
                style: AppText.of(context)
                    .bodyL
                    .copyWith(color: palette.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _pickAndSendImages(camera: false);
            },
          ),
          SizedBox(height: AppSpacing.xs.h),
        ],
      ),
    );
  }

  // ─── Reply / edit compose state ───────────────────────────────────────────

  void _startReply(MessageModel m) {
    setState(() {
      _replyingTo = m;
      _editingMessage = null;
    });
    _composerFocusNode.requestFocus();
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  void _startEdit(MessageModel m) {
    _messageController.text = m.body;
    _messageController.selection =
        TextSelection.collapsed(offset: _messageController.text.length);
    setState(() {
      _editingMessage = m;
      _replyingTo = null;
    });
    _composerFocusNode.requestFocus();
  }

  void _cancelEdit() {
    _messageController.clear();
    setState(() => _editingMessage = null);
  }

  // ─── Plan offer card (Faz 3 §3.5) ──────────────────────────────────────────

  /// Resolves a `plan_offer`-typed bubble's [MessagePlanOfferInfo.offerId]
  /// into the actual offer doc, then opens its preview. Only ever wired for
  /// the RECIPIENT's own bubble (`AppMessageBubble` never invokes this for
  /// `isMe`) — `users/{uid}/plan_offers/{id}` read is owner-only, so
  /// `_currentUserId` here is always the same uid the offer itself belongs
  /// to.
  Future<void> _openPlanOffer(MessagePlanOfferInfo info) async {
    final offer =
        await PlanOfferService().getOfferOnce(_currentUserId, info.offerId);
    if (!mounted) return;
    if (offer == null) {
      AppSnackBar.error(context,
          AppLocalizations.of(context).translate('chat.plan_offer.not_found'));
      return;
    }
    unawaited(Navigator.of(context)
        .push(AppTransitions.slideUp(PlanOfferPreviewScreen(offer: offer))));
  }

  // ─── Reactions ────────────────────────────────────────────────────────────

  void _toggleReaction(MessageModel m, String emoji) {
    final reacted = m.reactions[emoji]?.contains(_currentUserId) ?? false;
    if (reacted) {
      _chatService.removeReaction(
          chatId: widget.chat.id,
          messageId: m.id,
          uid: _currentUserId,
          emoji: emoji);
    } else {
      HapticFeedback.selectionClick();
      _chatService.addReaction(
          chatId: widget.chat.id,
          messageId: m.id,
          uid: _currentUserId,
          emoji: emoji);
    }
  }

  Future<void> _showMoreReactionsDialog(MessageModel m) async {
    final controller = TextEditingController();
    final palette = AppPalette.of(context);
    final emoji = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(_l10n.translate('chat.more_reactions.title'),
            style: AppText.of(context)
                .titleM
                .copyWith(color: palette.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
              hintText: _l10n.translate('chat.more_reactions.hint')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(_l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(_l10n.translate('common.confirm')),
          ),
        ],
      ),
    );
    if (emoji != null && emoji.trim().isNotEmpty) {
      _toggleReaction(m, emoji.trim().characters.first);
    }
  }

  // ─── Pin / star / copy / delete / report / forward ────────────────────────

  Future<void> _pinMessage(MessageModel m) async {
    await _chatService.pinMessage(
        chatId: widget.chat.id, messageId: m.id, uid: _currentUserId);
    if (mounted) {
      AppSnackBar.success(context, _l10n.translate('chat.message_pinned'));
    }
  }

  Future<void> _unpinMessage() async {
    await _chatService.unpinMessage(widget.chat.id);
    if (mounted) {
      AppSnackBar.info(context, _l10n.translate('chat.message_unpinned'));
    }
  }

  Future<void> _toggleStar(MessageModel m, bool currentlyStarred) async {
    unawaited(HapticFeedback.selectionClick());
    if (currentlyStarred) {
      await _chatService.unstarMessage(uid: _currentUserId, messageId: m.id);
      if (mounted) {
        AppSnackBar.info(context, _l10n.translate('chat.message_unstarred'));
      }
    } else {
      await _chatService.starMessage(
          uid: _currentUserId, chatId: widget.chat.id, message: m);
      if (mounted) {
        AppSnackBar.success(context, _l10n.translate('chat.message_starred'));
      }
    }
  }

  void _copyMessage(MessageModel m) {
    Clipboard.setData(ClipboardData(text: m.body));
    AppSnackBar.info(context, _l10n.translate('chat.copied_to_clipboard'));
  }

  Future<void> _confirmDelete(MessageModel m, {required bool everyone}) async {
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(_l10n.translate('chat.delete_confirm.title'),
            style: AppText.of(context)
                .titleM
                .copyWith(color: palette.textPrimary)),
        content: Text(
          _l10n.translate(everyone
              ? 'chat.delete_confirm.for_everyone_message'
              : 'chat.delete_confirm.for_me_message'),
          style:
              AppText.of(context).bodyM.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n.translate('common.delete'),
                style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    unawaited(HapticFeedback.mediumImpact());
    if (everyone) {
      await _chatService.deleteMessageForEveryone(
          chatId: widget.chat.id, messageId: m.id, attachments: m.attachments);
    } else {
      await _chatService.deleteMessageForMe(
          chatId: widget.chat.id, messageId: m.id, uid: _currentUserId);
    }
  }

  /// Faz 2 §2.6 — group owner/admin (or site admin) takes down ANOTHER
  /// member's message. Distinct confirmation copy from [_confirmDelete]'s
  /// "for everyone" case (that one is the SENDER removing their own words;
  /// this is a moderator removing someone else's).
  Future<void> _confirmModeratorDelete(MessageModel m) async {
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(_l10n.translate('chat.delete_confirm.title'),
            style: AppText.of(context)
                .titleM
                .copyWith(color: palette.textPrimary)),
        content: Text(
          _l10n.translate('chat.delete_confirm.moderator_message'),
          style:
              AppText.of(context).bodyM.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_l10n.translate('common.delete'),
                style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    unawaited(HapticFeedback.mediumImpact());
    try {
      await _chatService.deleteMessageAsModerator(
          chatId: widget.chat.id, messageId: m.id);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, _l10n.translate('common.something_wrong'));
      }
    }
  }

  Future<void> _reportTarget({
    required String targetId,
    required String targetAuthorUid,
    required String targetType,
    required String chatIdForMessage,
  }) async {
    final palette = AppPalette.of(context);
    final reasons = [
      _l10n.translate('community.report.reason_spam'),
      _l10n.translate('community.report.reason_harassment'),
      _l10n.translate('community.report.reason_inappropriate'),
      _l10n.translate('community.report.reason_other'),
    ];
    String? selectedReason;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text(_l10n.translate('community.report.dialog_title'),
              style: AppText.of(context)
                  .titleM
                  .copyWith(color: palette.textPrimary)),
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
                    ? Icon(Icons.check_rounded, color: palette.info, size: 20)
                    : null,
                onTap: () => setDialogState(() => selectedReason = r),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_l10n.translate('common.cancel'),
                  style: TextStyle(color: palette.textSecondary)),
            ),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        if (targetType == 'message') {
                          await _chatService.reportMessage(
                            chatId: chatIdForMessage,
                            messageId: targetId,
                            reporterId: _currentUserId,
                            targetAuthorUid: targetAuthorUid,
                            reason: selectedReason!,
                          );
                        } else {
                          await _chatService.reportUser(
                            reporterId: _currentUserId,
                            targetUserId: targetId,
                            reason: selectedReason!,
                          );
                        }
                        if (mounted) {
                          messenger.showSnackBar(SnackBar(
                            content: Text(
                                _l10n.translate('community.report.submitted')),
                            behavior: SnackBarBehavior.floating,
                          ));
                        }
                      } catch (_) {
                        if (mounted) {
                          AppSnackBar.error(context,
                              _l10n.translate('common.something_wrong'));
                        }
                      }
                    },
              child: Text(_l10n.translate('common.confirm'),
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

  Future<void> _showForwardSheet(MessageModel m) async {
    final chats = await _chatService.getUserChats(_currentUserId).first;
    final others = chats.where((c) => c.id != widget.chat.id).toList();
    if (!mounted) return;

    await AppSheet.show(
      context: context,
      title: _l10n.translate('chat.forward_sheet.title'),
      child: others.isEmpty
          ? Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg.h),
              child: Text(_l10n.translate('chat.forward_sheet.no_chats'),
                  style: AppText.of(context).bodyM),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 360.h),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: others.length,
                // Named `itemContext` (NOT `context`) deliberately — shadowing
                // the State's own `context` here would make the `onTap`
                // closure's `Navigator.pop(context)`/`AppSnackBar.success`
                // calls resolve to the ITEM's context, whose lifetime is
                // unrelated to this State's `mounted` guard.
                itemBuilder: (itemContext, i) {
                  final c = others[i];
                  return ListTile(
                    leading: c.image != null
                        ? CircleAvatar(
                            backgroundImage:
                                CachedNetworkImageProvider(c.image!))
                        : const CircleAvatar(
                            child: Icon(Icons.chat_bubble_outline_rounded)),
                    title: Text(c.name ?? _l10n.translate('chat.unnamed_user'),
                        style: AppText.of(itemContext).bodyL),
                    onTap: () async {
                      Navigator.pop(context);
                      await _chatService.forwardMessageTo(
                        targetChatId: c.id,
                        senderId: _currentUserId,
                        originalChatId: widget.chat.id,
                        original: m,
                      );
                      if (mounted) {
                        AppSnackBar.success(
                            context,
                            _l10n.translate('chat.forwarded_to', variables: {
                              'name':
                                  c.name ?? _l10n.translate('chat.unnamed_user')
                            }));
                      }
                    },
                  );
                },
              ),
            ),
    );
  }

  // ─── Long-press context menu ──────────────────────────────────────────────

  void _showContextMenu(MessageModel m,
      {required bool isPinned, required bool isStarred}) {
    // A synthetic failed-send entry was never actually persisted — none of
    // reply/forward/pin/star/edit/moderator-delete are meaningful on it.
    if (m.sendFailed) {
      _showFailedMessageMenu(m);
      return;
    }

    final withinEditWindow =
        DateTime.now().difference(m.timestamp) < const Duration(minutes: 15);
    final canEdit = m.senderId == _currentUserId &&
        withinEditWindow &&
        m.type == MessageType.text;
    final canDeleteEveryone = m.senderId == _currentUserId && withinEditWindow;
    final hasBody = m.body.isNotEmpty;

    final actions = <AppMessageContextMenuAction>[
      AppMessageContextMenuAction(
        icon: Icons.reply_rounded,
        label: _l10n.translate('chat.context_menu.reply'),
        onTap: () => _startReply(m),
      ),
      AppMessageContextMenuAction(
        icon: Icons.forward_rounded,
        label: _l10n.translate('chat.context_menu.forward'),
        onTap: () => _showForwardSheet(m),
      ),
      if (hasBody)
        AppMessageContextMenuAction(
          icon: Icons.copy_rounded,
          label: _l10n.translate('chat.context_menu.copy'),
          onTap: () => _copyMessage(m),
        ),
      AppMessageContextMenuAction(
        icon: Icons.push_pin_rounded,
        label: _l10n.translate(
            isPinned ? 'chat.context_menu.unpin' : 'chat.context_menu.pin'),
        onTap: () => isPinned ? _unpinMessage() : _pinMessage(m),
      ),
      AppMessageContextMenuAction(
        icon: isStarred ? Icons.star_rounded : Icons.star_border_rounded,
        label: _l10n.translate(
            isStarred ? 'chat.context_menu.unstar' : 'chat.context_menu.star'),
        onTap: () => _toggleStar(m, isStarred),
      ),
      if (canEdit)
        AppMessageContextMenuAction(
          icon: Icons.edit_rounded,
          label: _l10n.translate('chat.context_menu.edit'),
          onTap: () => _startEdit(m),
        ),
      AppMessageContextMenuAction(
        icon: Icons.delete_outline_rounded,
        label: _l10n.translate('chat.context_menu.delete_for_me'),
        destructive: true,
        onTap: () => _confirmDelete(m, everyone: false),
      ),
      if (canDeleteEveryone)
        AppMessageContextMenuAction(
          icon: Icons.delete_forever_rounded,
          label: _l10n.translate('chat.context_menu.delete_for_everyone'),
          destructive: true,
          onTap: () => _confirmDelete(m, everyone: true),
        ),
      // Faz 2 §2.6: a group owner/admin (or site admin) may take down
      // ANOTHER member's message — distinct from canDeleteEveryone above,
      // which is sender-only within the 15-minute edit window. Never shown
      // for the moderator's OWN message (they already have the sender path)
      // or one already removed.
      if (_isGroupModerator &&
          m.senderId != _currentUserId &&
          !m.isDeletedFor(_currentUserId))
        AppMessageContextMenuAction(
          icon: Icons.remove_moderator_outlined,
          label: _l10n.translate('chat.context_menu.delete_as_moderator'),
          destructive: true,
          onTap: () => _confirmModeratorDelete(m),
        ),
      if (m.senderId != _currentUserId)
        AppMessageContextMenuAction(
          icon: Icons.flag_outlined,
          label: _l10n.translate('chat.context_menu.report'),
          destructive: true,
          onTap: () => _reportTarget(
            targetId: m.id,
            targetAuthorUid: m.senderId,
            targetType: 'message',
            chatIdForMessage: widget.chat.id,
          ),
        ),
    ];

    AppMessageContextMenu.show(
      context,
      previewSenderLabel: _labelFor(m.senderId),
      previewText: previewTextFor(_l10n, m),
      onReact: (emoji) => _toggleReaction(m, emoji),
      onMoreReactions: () => _showMoreReactionsDialog(m),
      actions: actions,
    );
  }

  void _showFailedMessageMenu(MessageModel m) {
    AppMessageContextMenu.show(
      context,
      previewSenderLabel: _labelFor(m.senderId),
      previewText: previewTextFor(_l10n, m),
      onReact: (_) {},
      actions: [
        AppMessageContextMenuAction(
          icon: Icons.refresh_rounded,
          label: _l10n.translate('chat.context_menu.retry'),
          onTap: () => _retryFailedSend(m),
        ),
        AppMessageContextMenuAction(
          icon: Icons.delete_outline_rounded,
          label: _l10n.translate('chat.context_menu.delete_failed'),
          destructive: true,
          onTap: () => _failureStore.remove(widget.chat.id, m.clientId),
        ),
      ],
    );
  }

  // ─── Pagination + jump-to-message/date ────────────────────────────────────

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    if (_isLoadingOlder) return;
    final inJump = _jumpMessages != null;
    if (!inJump && !_hasMoreOlder) return;

    final anchorId = inJump
        ? (_jumpMessages!.isNotEmpty ? _jumpMessages!.last.id : null)
        : (_olderMessages.isNotEmpty
            ? _olderMessages.last.id
            : (_liveMessagesCache.isNotEmpty
                ? _liveMessagesCache.last.id
                : null));
    if (anchorId == null) return;

    setState(() => _isLoadingOlder = true);
    final page = await _chatService.getMessagesPage(widget.chat.id,
        startAfterMessageId: anchorId);
    if (!mounted) return;
    setState(() {
      if (inJump) {
        _jumpMessages = [..._jumpMessages!, ...page.messages];
      } else {
        _olderMessages = [..._olderMessages, ...page.messages];
        _hasMoreOlder = page.messages.length >= _pageSize;
      }
      _isLoadingOlder = false;
    });
  }

  void _flashHighlight(String messageId) {
    _highlightTimer?.cancel();
    setState(() => _highlightedMessageId = messageId);
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  Future<void> _jumpToMessage(
      String messageId, DateTime approxTimestamp) async {
    final key = _messageKeys[messageId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(key!.currentContext!,
          duration: AppMotion.normal,
          curve: AppMotion.standard,
          alignment: 0.5);
      _flashHighlight(messageId);
      return;
    }

    setState(() => _isLoadingJump = true);
    final page = await _chatService.getMessagesAround(widget.chat.id,
        around: approxTimestamp);
    if (!mounted) return;
    setState(() {
      _jumpMessages = page;
      _isLoadingJump = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final k = _messageKeys[messageId];
      if (k?.currentContext != null) {
        Scrollable.ensureVisible(k!.currentContext!,
            duration: AppMotion.normal,
            curve: AppMotion.standard,
            alignment: 0.5);
        _flashHighlight(messageId);
      }
    });
  }

  Future<void> _pickJumpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _isLoadingJump = true);
    final page =
        await _chatService.getMessagesAround(widget.chat.id, around: picked);
    if (!mounted) return;
    setState(() {
      _jumpMessages = page;
      _isLoadingJump = false;
    });
  }

  void _backToLive() => setState(() => _jumpMessages = null);

  // ─── In-chat search ────────────────────────────────────────────────────────

  Future<void> _openSearch() async {
    setState(() {
      _searchMode = true;
      _searching = true;
    });
    _searchSource = await _chatService.fetchMessagesForSearch(widget.chat.id);
    if (mounted) setState(() => _searching = false);
  }

  void _closeSearch() {
    setState(() {
      _searchMode = false;
      _searchController.clear();
      _searchResults = [];
    });
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() {
      _searchResults = _searchSource
          .where((m) =>
              !m.isDeletedFor(_currentUserId) &&
              m.type == MessageType.text &&
              m.body.toLowerCase().contains(q))
          .toList();
    });
  }

  void _onTapSearchResult(MessageModel m) {
    _closeSearch();
    _jumpToMessage(m.id, m.timestamp);
  }

  // ─── Send/delivery status ──────────────────────────────────────────────────

  /// Faz 0 §0.3 — delegates to the pure, unit-tested
  /// `MessageStatusResolver`, which also fixes the group-backed correctness
  /// gap the old inline `_isRead` had: `chat.participants` only ever holds
  /// the OWNER for a `chat.groupId != null` chat, so requiring every
  /// participant to have read it could never be true for a real group.
  MessageSendState _resolveStatus(MessageModel m, ChatModel chat) {
    final others = chat.type == ChatType.private
        ? (_otherUserId.isEmpty ? const <String>[] : [_otherUserId])
        : chat.participants.where((p) => p != _currentUserId).toList();
    return MessageStatusResolver.resolve(
      message: m,
      otherParticipantIds: others,
      isCommunityGroupChat: chat.groupId != null,
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _searchMode ? _buildSearchAppBar(palette) : _buildAppBar(palette),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: palette.background)),
          ...AppGradients.meshGlow(palette, Theme.of(context).primaryColor),
          if (_searchMode)
            _buildSearchBody(palette)
          else
            StreamBuilder<ChatModel>(
              stream: _chatStream,
              builder: (context, chatSnapshot) {
                final chatData = chatSnapshot.data ?? widget.chat;
                return Column(
                  children: [
                    if (chatData.pinnedMessageId != null)
                      _PinnedBannerResolver(
                        key: ValueKey(chatData.pinnedMessageId),
                        chatId: widget.chat.id,
                        messageId: chatData.pinnedMessageId!,
                        loadedMessages: _allLoadedMessages(),
                        chatService: _chatService,
                        labelFor: _labelFor,
                        l10n: _l10n,
                        onTap: (m) => _jumpToMessage(m.id, m.timestamp),
                        onUnpin: _unpinMessage,
                      ),
                    if (_jumpMessages != null)
                      _JumpModeBanner(onBackToLive: _backToLive),
                    Expanded(child: _buildMessageList(chatData)),
                    _buildTypingIndicator(chatData),
                    _buildComposer(),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  List<MessageModel> _allLoadedMessages() {
    if (_jumpMessages != null) return _jumpMessages!;
    return [..._liveMessagesCache, ..._olderMessages];
  }

  PreferredSizeWidget _buildAppBar(AppPalette palette) {
    final theme = Theme.of(context);

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface.withValues(alpha: 0.8),
              border: Border(
                  bottom: BorderSide(color: palette.glassStroke, width: 0.5)),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                        gradient: AppGradients.brand(theme.primaryColor)),
                  ),
                ),
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: palette.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: widget.chat.type == ChatType.private
                      ? _buildPrivateTitle(palette)
                      : _buildGroupTitle(palette),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.search_rounded,
                          color: palette.textPrimary),
                      onPressed: _openSearch,
                    ),
                    IconButton(
                      tooltip: _l10n.translate('chat.jump_to_date'),
                      icon: Icon(Icons.calendar_month_outlined,
                          color: palette.textPrimary),
                      onPressed: _pickJumpDate,
                    ),
                    IconButton(
                      icon: Icon(Icons.more_vert, color: palette.textPrimary),
                      onPressed: _showMoreOptions,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateTitle(AppPalette palette) {
    return StreamBuilder<UserModel>(
      stream: _otherUserStream,
      builder: (context, snapshot) {
        String chatTitle =
            widget.chat.name ?? _l10n.translate('chat.unnamed_user');
        String? chatImage = widget.chat.image;
        bool isOnline = false;
        DateTime? lastActiveAt;

        final user = snapshot.data;
        if (user != null) {
          chatTitle = user.displayName ?? chatTitle;
          chatImage = user.photoURL ?? chatImage;
          isOnline = user.isOnline;
          lastActiveAt = user.lastActiveAt?.toDate();
        }

        return GestureDetector(
          onTap: _otherUserId.isNotEmpty
              ? () => openUserProfile(context, userId: _otherUserId)
              : null,
          child: Row(
            children: [
              chatImage != null
                  ? CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(chatImage),
                      radius: 16.r)
                  : CircleAvatar(
                      backgroundColor: palette.surfaceVariant,
                      radius: 16.r,
                      child: Icon(Icons.person,
                          size: 20.r, color: palette.textTertiary),
                    ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chatTitle,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.of(context).titleM.copyWith(
                            color: palette.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold)),
                    if (isOnline)
                      Text(_l10n.translate('chat.online'),
                          style: TextStyle(
                              color: palette.success, fontSize: 12.sp))
                    else if (lastActiveAt != null)
                      Text(
                        _l10n.translate('profile.chat.last_active_at',
                            variables: {
                              'time': _formatLastActive(lastActiveAt)
                            }),
                        style: TextStyle(
                            color: palette.textTertiary, fontSize: 10.sp),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupTitle(AppPalette palette) {
    final row = Row(
      children: [
        widget.chat.image != null
            ? CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(widget.chat.image!),
                radius: 16.r)
            : CircleAvatar(
                backgroundColor: palette.surfaceVariant,
                radius: 16.r,
                child: Icon(Icons.groups_rounded,
                    size: 18.r, color: palette.textTertiary),
              ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.chat.name ?? _l10n.translate('chat.unnamed_user'),
                  overflow: TextOverflow.ellipsis,
                  style: AppText.of(context).titleM.copyWith(
                      color: palette.textPrimary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold)),
              Text(
                _l10n.translate('chat.member_count_label', variables: {
                  'count': widget.chat.participants.length.toString()
                }),
                style: TextStyle(color: palette.textTertiary, fontSize: 11.sp),
              ),
            ],
          ),
        ),
      ],
    );

    // Faz 5 — "clicking group name/photo opens the group info screen"
    // (WhatsApp's own header gesture). Only meaningful for a
    // community-group-backed chat; an ad-hoc multi-party chat has no
    // `GroupInfoScreen` to show.
    final groupId = widget.chat.groupId;
    if (groupId == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context)
          .push(AppTransitions.slideRight(GroupInfoScreen(groupId: groupId))),
      child: row,
    );
  }

  String _formatLastActive(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inMinutes < 1) return _l10n.translate('chat.time.now');
    if (difference.inMinutes < 60) {
      return _l10n.translate('chat.time.mins_ago',
          variables: {'m': difference.inMinutes.toString()});
    }
    if (difference.inHours < 24 && _isSameDay(now, timestamp)) {
      return _l10n.translate('chat.time.hours_ago',
          variables: {'h': difference.inHours.toString()});
    }
    if (difference.inDays < 1 && !_isSameDay(now, timestamp)) {
      final time =
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      return _l10n
          .translate('chat.time.yesterday_at', variables: {'time': time});
    }
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }

  PreferredSizeWidget _buildSearchAppBar(AppPalette palette) {
    return AppBar(
      backgroundColor: palette.surface,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: palette.textPrimary),
        onPressed: _closeSearch,
      ),
      title: AppTextField(
        controller: _searchController,
        autofocus: true,
        hintText: _l10n.translate('chat.search.placeholder'),
        onChanged: _onSearchChanged,
      ),
    );
  }

  Widget _buildSearchBody(AppPalette palette) {
    if (_searching) {
      return const AppSkeletonList();
    }
    if (_searchController.text.trim().isEmpty) {
      return Padding(
        padding: EdgeInsets.all(AppSpacing.lg.r),
        child: Text(_l10n.translate('chat.search.scope_note'),
            style: AppText.of(context)
                .bodyM
                .copyWith(color: palette.textTertiary)),
      );
    }
    if (_searchResults.isEmpty) {
      // Faz 7 — the same "searching your most recent messages" caveat shown
      // above before a query is typed also belongs here: an empty result
      // is ambiguous between "not found" and "outside the bounded search
      // window" without it.
      return AppEmptyState(
        icon: Icons.search_off_rounded,
        title: _l10n.translate('chat.search.no_results'),
        message: _l10n.translate('chat.search.scope_note'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
          child: Text(
            _l10n.translate('chat.search.result_count',
                variables: {'count': _searchResults.length.toString()}),
            style: AppText.of(context)
                .labelM
                .copyWith(color: palette.textTertiary),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _searchResults.length,
            itemBuilder: (context, i) {
              final m = _searchResults[i];
              return ListTile(
                leading: Icon(Icons.chat_bubble_outline_rounded,
                    color: palette.textTertiary),
                title: Text(_labelFor(m.senderId),
                    style: AppText.of(context).labelL),
                subtitle:
                    Text(m.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => _onTapSearchResult(m),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMoreOptions() {
    final palette = AppPalette.of(context);
    AppSheet.show(
      context: context,
      title: _l10n.translate('chat.more_options'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.chat.type == ChatType.private && _otherUserId.isNotEmpty)
            ListTile(
              leading: Icon(Icons.person_outline_rounded,
                  color: palette.textPrimary),
              title: Text(_l10n.translate('chat.view_profile'),
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
                Icon(Icons.photo_library_outlined, color: palette.textPrimary),
            title: Text(_l10n.translate('chat.media_gallery.title'),
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(AppTransitions.slideRight(
                  MediaGalleryScreen(chatId: widget.chat.id)));
            },
          ),
          if (widget.chat.type == ChatType.private && _otherUserId.isNotEmpty)
            ListTile(
              leading: Icon(Icons.flag_outlined, color: palette.error),
              title: Text(_l10n.translate('community.menu.report'),
                  style:
                      AppText.of(context).bodyM.copyWith(color: palette.error)),
              onTap: () {
                Navigator.pop(context);
                _reportTarget(
                  targetId: _otherUserId,
                  targetAuthorUid: _otherUserId,
                  targetType: 'user',
                  chatIdForMessage: widget.chat.id,
                );
              },
            ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatModel chatData) {
    if (_jumpMessages != null) {
      return _isLoadingJump
          ? const Center(child: CircularProgressIndicator())
          : _messagesListView(_jumpMessages!, chatData);
    }

    return ValueListenableBuilder<List<PendingSendFailure>>(
      valueListenable: _failureStore.watch(widget.chat.id),
      builder: (context, failed, _) {
        return StreamBuilder<List<MessageModel>>(
          stream: _messageStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const AppSkeletonList();
            }

            // `_liveMessagesCache` stays exactly what Firestore returned
            // (unmerged) — `_loadOlder`'s pagination cursor and
            // `_allLoadedMessages()` both anchor on real doc ids, and a
            // synthetic failed-send entry (id = a local clientId, no
            // matching doc) must never become that anchor.
            _liveMessagesCache = snapshot.data ?? const [];
            if (_liveMessagesCache.isEmpty && failed.isEmpty) {
              return AppEmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: _l10n.translate('chat.no_messages_yet'),
              );
            }

            if (!_unreadDividerComputed) {
              _unreadDividerComputed = true;
              final capturedUnread =
                  widget.chat.unreadCounts[_currentUserId] ?? 0;
              if (capturedUnread > 0) {
                for (final m in _liveMessagesCache) {
                  if (m.senderId != _currentUserId &&
                      !m.isReadBy(_currentUserId)) {
                    _unreadDividerBeforeId = m.id;
                    _unreadDividerCount = capturedUnread;
                    break;
                  }
                }
              }
            }

            final mergedLive = ChatMessageMerge.merge(
              live: _liveMessagesCache,
              failed: failed,
              currentUid: _currentUserId,
            );
            final combined = [...mergedLive, ..._olderMessages];
            return _messagesListView(combined, chatData);
          },
        );
      },
    );
  }

  Widget _messagesListView(List<MessageModel> messages, ChatModel chatData) {
    final isGroup = chatData.type != ChatType.private;

    return StreamBuilder<Set<String>>(
      stream: _starredIdsStream,
      builder: (context, starredSnapshot) {
        final starredIds = starredSnapshot.data ?? const <String>{};

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: EdgeInsets.only(
              top: 100.h, bottom: 20.h, left: 16.w, right: 16.w),
          itemCount: messages.length + (_isLoadingOlder ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= messages.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }

            final message = messages[index];
            final isMe = message.senderId == _currentUserId;
            final isLast = index == messages.length - 1;
            final next = isLast ? null : messages[index + 1];

            final showDateSeparator =
                isLast || !_isSameDay(message.timestamp, next!.timestamp);
            final showSenderLabel = isGroup &&
                !isMe &&
                (isLast ||
                    next!.senderId != message.senderId ||
                    !_isSameDay(message.timestamp, next.timestamp));
            final showUnreadDivider = message.id == _unreadDividerBeforeId;
            final isHighlighted = message.id == _highlightedMessageId;

            final key = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

            return Column(
              key: key,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDateSeparator)
                  AppDateSeparator(date: message.timestamp),
                if (showUnreadDivider)
                  AppUnreadDivider(count: _unreadDividerCount),
                AnimatedContainer(
                  duration: AppMotion.normal,
                  color: isHighlighted
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  child: Align(
                    alignment:
                        isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.h),
                      child: AppMessageBubble(
                        message: message,
                        isMe: isMe,
                        currentUid: _currentUserId,
                        senderLabel: showSenderLabel
                            ? _labelFor(message.senderId)
                            : null,
                        status: _resolveStatus(message, chatData),
                        isPinned: chatData.pinnedMessageId == message.id,
                        isStarred: starredIds.contains(message.id),
                        resolveSenderLabel: _labelFor,
                        onLongPress: () => _showContextMenu(
                          message,
                          isPinned: chatData.pinnedMessageId == message.id,
                          isStarred: starredIds.contains(message.id),
                        ),
                        onSwipeReply: () => _startReply(message),
                        onTapReplyPreview: message.replyTo != null
                            ? () => _jumpToMessage(
                                message.replyTo!.id, message.timestamp)
                            : null,
                        onTapImage: (i) => Navigator.of(context).push(
                            AppTransitions.fadeScale(
                                MediaGalleryScreen(chatId: widget.chat.id))),
                        onToggleReaction: (emoji) =>
                            _toggleReaction(message, emoji),
                        onTapPlanOffer: _openPlanOffer,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTypingIndicator(ChatModel chatData) {
    final typingUsers = chatData.typingUsers ?? {};
    final typingUids = typingUsers.entries
        .where((e) => e.value && e.key != _currentUserId)
        .map((e) => e.key)
        .toList();
    final names =
        typingUids.map((u) => _labelFor(u)).where((n) => n.isNotEmpty).toList();

    return AppTypingIndicator(visible: typingUids.isNotEmpty, names: names);
  }

  // ─── Voice messages (Faz 6) ────────────────────────────────────────────────

  Future<void> _startVoiceRecording() async {
    final granted = await PermissionService().requestMicrophone(context);
    if (!mounted || !granted) return;

    final recorder = AudioRecorder();
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    try {
      await recorder.start(
        const RecordConfig(bitRate: 64000), // encoder defaults to aacLc
        path: path,
      );
    } catch (e, st) {
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'ChatDetailScreen._startVoiceRecording'));
      if (mounted) AppSnackBar.error(context, e.toString());
      return;
    }

    _voiceRecorder = recorder;
    _voiceRecordingPath = path;
    _voiceRawAmplitudes.clear();
    _voiceAmplitudeController = StreamController<double>.broadcast();

    setState(() {
      _isRecordingVoice = true;
      _isVoiceLocked = false;
      _voiceElapsed = Duration.zero;
      _voiceDragDx = 0;
      _voiceDragDy = 0;
    });

    _voiceElapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _voiceElapsed += const Duration(seconds: 1));
    });

    _voiceAmplitudeSub =
        recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
      (amp) {
        _voiceRawAmplitudes.add(amp.current);
        // Same floor as WaveformDownsampler.silenceFloorDb — normalizes the
        // LIVE waveform bar the same way the final downsample will.
        final normalized =
            ((amp.current.clamp(WaveformDownsampler.silenceFloorDb, 0.0) -
                    WaveformDownsampler.silenceFloorDb) /
                (-WaveformDownsampler.silenceFloorDb) *
                100);
        _voiceAmplitudeController?.add(normalized);
      },
      onError: (Object e, StackTrace st) {
        _log(e, st, 'onAmplitudeChanged');
      },
    );
  }

  void _log(Object e, StackTrace st, String where) {
    unawaited(CrashlyticsService()
        .recordError(e, st, reason: 'ChatDetailScreen.$where'));
  }

  Future<void> _cancelVoiceRecording() async {
    unawaited(HapticFeedback.mediumImpact());
    _voiceElapsedTimer?.cancel();
    unawaited(_voiceAmplitudeSub?.cancel());
    unawaited(_voiceAmplitudeController?.close());
    try {
      await _voiceRecorder?.stop();
    } catch (_) {
      // Best-effort — we're discarding the recording either way.
    }
    final path = _voiceRecordingPath;
    if (path != null) {
      unawaited(File(path).delete().catchError((_) => File(path)));
    }
    unawaited(_voiceRecorder?.dispose());
    _voiceRecorder = null;
    _voiceRecordingPath = null;
    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _isVoiceLocked = false;
      });
    }
  }

  Future<void> _finishVoiceRecordingAndSend() async {
    _voiceElapsedTimer?.cancel();
    unawaited(_voiceAmplitudeSub?.cancel());
    unawaited(_voiceAmplitudeController?.close());

    String? path;
    try {
      path = await _voiceRecorder?.stop();
    } catch (e, st) {
      _log(e, st, '_finishVoiceRecordingAndSend.stop');
    }
    unawaited(_voiceRecorder?.dispose());
    _voiceRecorder = null;

    final durationMs = _voiceElapsed.inMilliseconds;
    final peaks = WaveformDownsampler.downsample(_voiceRawAmplitudes);

    if (!mounted || path == null || durationMs < 1000) {
      // Under 1s is almost certainly an accidental tap, not a real note —
      // discard silently rather than sending a near-zero-length recording.
      if (path != null) {
        unawaited(File(path).delete().catchError((_) => File(path!)));
      }
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _isVoiceLocked = false;
        });
      }
      return;
    }

    setState(() {
      _isRecordingVoice = false;
      _isVoiceLocked = false;
      _isUploading = true;
    });

    try {
      final url = await StorageUploadService().uploadChatVoice(
          chatScopeId: _chatImageScope(), audioFile: File(path));
      final replyTo = _replyingTo;
      await _chatService.sendMessage(
        chatId: widget.chat.id,
        senderId: _currentUserId,
        type: MessageType.voice,
        attachments: [
          MessageAttachment(
              kind: 'audio', url: url, durationMs: durationMs, peaks: peaks),
        ],
        replyTo: replyTo != null ? _buildReplyTo(replyTo) : null,
      );
      if (mounted) setState(() => _replyingTo = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      unawaited(File(path).delete().catchError((_) => File(path!)));
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildComposer() {
    if (_isRecordingVoice) {
      return AppVoiceRecorder(
        elapsed: _voiceElapsed,
        amplitudeStream: _voiceAmplitudeController?.stream,
        dragDx: _voiceDragDx,
        dragDy: _voiceDragDy,
        onCancel: _cancelVoiceRecording,
        onLock: () => setState(() => _isVoiceLocked = true),
        onRelease: _finishVoiceRecordingAndSend,
      );
    }
    return AppMessageComposer(
      controller: _messageController,
      focusNode: _composerFocusNode,
      onChanged: (_) {},
      onSend: _handleSendTap,
      onAttachTap: _showAttachSheet,
      isUploading: _isUploading,
      replyingToSenderLabel: _editingMessage != null
          ? _l10n.translate('chat.edit_message.editing_label')
          : (_replyingTo != null ? _labelFor(_replyingTo!.senderId) : null),
      replyingToPreview: _editingMessage?.body ??
          (_replyingTo != null ? previewTextFor(_l10n, _replyingTo!) : null),
      replyingToIcon: switch (_replyingTo?.type) {
        MessageType.image => Icons.image_outlined,
        MessageType.voice => Icons.mic_none_rounded,
        _ => null,
      },
      onCancelReply: _editingMessage != null
          ? _cancelEdit
          : (_replyingTo != null ? _cancelReply : null),
      mentionCandidates: _mentionCandidates,
      onSelectMention: _onSelectMention,
      onMicPressStart: _startVoiceRecording,
      onMicDragUpdate: (dx, dy) {
        setState(() {
          _voiceDragDx = dx;
          _voiceDragDy = dy;
        });
      },
      onMicPressEnd: () {
        if (!_isRecordingVoice || _isVoiceLocked) return;
        // Locked mode is hands-free — the recorder bar's own send/delete
        // buttons take over from here (AppVoiceRecorder.onRelease/onCancel).
        if (_voiceDragDy >= AppVoiceRecorder.lockThresholdPx ||
            _voiceDragDx >= AppVoiceRecorder.cancelThresholdPx) {
          return;
        }
        _finishVoiceRecordingAndSend();
      },
    );
  }
}

/// Resolves the pinned message (from already-loaded messages, falling back to
/// a single `getMessageOnce` fetch) and renders [AppPinnedBanner]. A tiny
/// self-contained widget so the fetch-and-cache doesn't need to live in the
/// screen's State just for one banner.
class _PinnedBannerResolver extends StatefulWidget {
  final String chatId;
  final String messageId;
  final List<MessageModel> loadedMessages;
  final ChatService chatService;
  final String Function(String uid) labelFor;
  final AppLocalizations l10n;
  final ValueChanged<MessageModel> onTap;
  final VoidCallback onUnpin;

  const _PinnedBannerResolver({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.loadedMessages,
    required this.chatService,
    required this.labelFor,
    required this.l10n,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  State<_PinnedBannerResolver> createState() => _PinnedBannerResolverState();
}

class _PinnedBannerResolverState extends State<_PinnedBannerResolver> {
  MessageModel? _resolved;
  bool _fetching = false;

  @override
  void didUpdateWidget(covariant _PinnedBannerResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) _resolved = null;
  }

  MessageModel? _fromLoaded() {
    for (final m in widget.loadedMessages) {
      if (m.id == widget.messageId) return m;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _fromLoaded();
    final message = loaded ?? _resolved;

    if (message == null && !_fetching) {
      _fetching = true;
      widget.chatService
          .getMessageOnce(widget.chatId, widget.messageId)
          .then((m) {
        if (mounted && m != null) setState(() => _resolved = m);
      });
    }

    if (message == null) return const SizedBox.shrink();

    return AppPinnedBanner(
      senderLabel: widget.labelFor(message.senderId),
      previewText: previewTextFor(widget.l10n, message),
      kindIcon: switch (message.type) {
        MessageType.image => Icons.image_outlined,
        MessageType.voice => Icons.mic_none_rounded,
        _ => null,
      },
      onTap: () => widget.onTap(message),
      onUnpin: widget.onUnpin,
    );
  }
}

class _JumpModeBanner extends StatelessWidget {
  final VoidCallback onBackToLive;
  const _JumpModeBanner({required this.onBackToLive});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: InkWell(
        onTap: onBackToLive,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
          child: Row(
            children: [
              Icon(Icons.history_rounded,
                  size: 16.r, color: Theme.of(context).primaryColor),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Text(l10n.translate('chat.back_to_latest'),
                    style: AppText.of(context).labelM.copyWith(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w700)),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 14.r, color: palette.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
