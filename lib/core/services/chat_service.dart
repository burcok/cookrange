import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/chat_prefs_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';
import 'log_service.dart';
import 'storage_upload_service.dart';

/// Thrown by [ChatService.sendMessage] when Firestore permanently rejected
/// the write (rules/App Check/unauthenticated) rather than merely queuing it
/// for retry. Firestore's own offline mutation queue
/// (`persistenceEnabled: true`) already retries every recoverable network
/// failure automatically, including across an app restart, so a plain
/// dropped-connection or timeout never reaches a caller as this type — only
/// a rejection Firestore has already given up on does. Deliberately NOT a
/// `FirebaseException` re-throw: keeping the Firebase-specific error-code
/// classification inside this service, not the screen, is what lets
/// `chat_detail_screen.dart` catch a plain Dart type instead of importing
/// `cloud_firestore` itself (architecture rule — UI never touches Firebase).
class ChatSendRejectedException implements Exception {
  final String code;
  final Object cause;
  const ChatSendRejectedException(this.code, this.cause);

  @override
  String toString() => 'ChatSendRejectedException($code): $cause';
}

class ChatService {
  // Faz 0 §0.5 — every call site already used the zero-arg `ChatService()`
  // constructor (grep-confirmed across the app), so this is a pure internal
  // change: no caller needs to change, and every screen now shares one
  // instance instead of silently duplicating state (`docs/SERVICES.md`'s
  // `static final _instance` pattern, §5.2).
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  final LogService _logger = LogService();

  // Get all chats for a user, sorted by update time. Capped (Faz 0 §0.5 —
  // this had no bound at all; also the underlying stream for
  // getUserChatsWithStatus below, so this is the real chat-list path).
  /// Faz 3 — merges the legacy `participants arrayContains` query with the
  /// new `chat_inbox` read-model, rather than switching to `chat_inbox`
  /// outright. Why both are still needed:
  ///
  /// - The legacy query is exactly right for a DM, an ad-hoc multi-party
  ///   chat (`participants` genuinely lists everyone there), and a
  ///   group-backed chat's OWNER (who IS in `participants` — see
  ///   `CommunityGroupService.createGroup`). Zero regression risk for any
  ///   of those; unchanged behavior.
  /// - It structurally CANNOT surface a group-backed chat for any
  ///   non-owner member — `chats/{id}.participants` only ever holds the
  ///   owner for that shape (`firestore.rules`' `canAccessGroupChat()` note)
  ///   — which is exactly `PROJECT_STATE.md`'s tracked "group unread is
  ///   structurally always zero for non-owners" defect. `chat_inbox`
  ///   (server-authored by `onChatMessageCreated`, seeded on every message
  ///   AND on every join/leave/rename via Faz 5's system messages) is the
  ///   real fix: a row exists there for every real member the moment they
  ///   join or any activity happens after this deployment.
  /// - Known, accepted gap (not silently ignored — stated here): a member
  ///   who joined a group BEFORE this deployment and whose group has had no
  ///   activity since won't have a `chat_inbox` row yet, so their view of
  ///   that one chat stays exactly as broken as it already was. A backfill
  ///   sweep closes that; not built in this pass since this app has zero
  ///   real users to backfill for yet (`PROJECT_STATE.md`) — tracked as a
  ///   pre-launch follow-up, not a silent omission.
  ///
  /// Where a chatId appears in BOTH sources, the `chat_inbox` row's `unread`
  /// count wins (it's the one Cloud Functions actually keeps correct now —
  /// the legacy doc's own `unreadCounts` map is a dual-write kept only for
  /// clients still on the fallback path, see `onChatMessageCreated`'s doc
  /// comment) and its `updated_at` is preferred for sort order, since it's
  /// server-timestamped at the moment of the SAME event.
  Stream<List<ChatModel>> getUserChats(String userId, {int limit = 200}) {
    final legacy$ = _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => {
              for (final doc in snapshot.docs)
                doc.id: ChatModel.fromJson(doc.data(), doc.id),
            });

    final inbox$ = _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_inbox')
        .orderBy('updated_at', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) => _hydrateInboxRows(snapshot, userId));

    return _combineChatSources(legacy$, inbox$, limit: limit);
  }

  /// Combines the two `Map<chatId, ChatModel>` streams above into one
  /// sorted, deduped list — re-emitting whenever EITHER source updates, so
  /// a group's inbox-only row and a DM's legacy-only row both stay live.
  Stream<List<ChatModel>> _combineChatSources(
    Stream<Map<String, ChatModel>> legacy$,
    Stream<Map<String, ChatModel>> inbox$, {
    required int limit,
  }) {
    final controller = StreamController<List<ChatModel>>();
    var legacyChats = <String, ChatModel>{};
    var inboxChats = <String, ChatModel>{};
    var haveLegacy = false;
    var haveInbox = false;
    StreamSubscription? legacySub;
    StreamSubscription? inboxSub;

    void emit() {
      if (controller.isClosed || !haveLegacy || !haveInbox) return;
      // inbox entries win on chatId collision — see doc comment above.
      final merged = {...legacyChats, ...inboxChats};
      final sorted = merged.values.toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      controller.add(sorted.take(limit).toList());
    }

    legacySub = legacy$.listen((chats) {
      legacyChats = chats;
      haveLegacy = true;
      emit();
    }, onError: (Object e, StackTrace s) {
      _logger.error('getUserChats: legacy stream error',
          service: 'ChatService', error: e, stackTrace: s);
    });
    inboxSub = inbox$.listen((chats) {
      inboxChats = chats;
      haveInbox = true;
      emit();
    }, onError: (Object e, StackTrace s) {
      _logger.error('getUserChats: chat_inbox stream error',
          service: 'ChatService', error: e, stackTrace: s);
      // A chat_inbox failure must never blank the whole list — degrade to
      // legacy-only rather than waiting forever on a stream that errored.
      haveInbox = true;
      emit();
    });

    controller.onCancel = () {
      legacySub?.cancel();
      inboxSub?.cancel();
      controller.close();
    };
    return controller.stream;
  }

  /// Resolves each `chat_inbox` row into a real `ChatModel` via a
  /// `whereIn`-chunked batch-get of `chats/{id}` (chunk size 10 — mirrors
  /// `getUserChatsWithStatus`'s existing whereIn chunk size below), then
  /// overrides `unreadCounts[userId]` and `updatedAt` from the inbox row
  /// (the source of truth for both, per this method's doc comment). A
  /// chatId whose `chats/{id}` doc is missing/unreadable is skipped rather
  /// than crashing the whole list.
  Future<Map<String, ChatModel>> _hydrateInboxRows(
    QuerySnapshot<Map<String, dynamic>> inboxSnapshot,
    String userId,
  ) async {
    if (inboxSnapshot.docs.isEmpty) return {};

    final inboxByChatId = <String, Map<String, dynamic>>{
      for (final d in inboxSnapshot.docs) d.id: d.data(),
    };
    final chatIds = inboxByChatId.keys.toList();

    final rawChats = <String, ChatModel>{};
    for (var i = 0; i < chatIds.length; i += 10) {
      final chunk = chatIds.sublist(i, (i + 10).clamp(0, chatIds.length));
      try {
        final snap = await _firestore
            .collection('chats')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          rawChats[doc.id] = ChatModel.fromJson(doc.data(), doc.id);
        }
      } catch (e, s) {
        _logger.error('getUserChats: chat_inbox hydration chunk failed',
            service: 'ChatService', error: e, stackTrace: s);
      }
    }

    final result = <String, ChatModel>{};
    for (final entry in inboxByChatId.entries) {
      final base = rawChats[entry.key];
      if (base == null) continue;
      final unread = (entry.value['unread'] as num?)?.toInt() ?? 0;
      final updatedAt = entry.value['updated_at'];
      result[entry.key] = base.copyWith(
        unreadCounts: {...base.unreadCounts, userId: unread},
        updatedAt: updatedAt is Timestamp ? updatedAt.toDate() : base.updatedAt,
      );
    }
    return result;
  }

  // Combined stream for chats + online status
  Stream<List<ChatModel>> getUserChatsWithStatus(String userId) {
    final controller = StreamController<List<ChatModel>>();
    List<ChatModel> lastChats = [];
    Map<String, Map<String, dynamic>> userDataMap =
        {}; // Changed to store full user data
    StreamSubscription? chatsSub;
    StreamSubscription? usersSub;

    void emit() {
      if (controller.isClosed) return;
      final updatedChats = lastChats.map((chat) {
        if (chat.type == ChatType.private) {
          final otherId = chat.participants
              .firstWhere((p) => p != userId, orElse: () => '');
          if (otherId.isNotEmpty && userDataMap.containsKey(otherId)) {
            final userData = userDataMap[otherId]!;
            final newMetadata = Map<String, dynamic>.from(chat.metadata ?? {});

            // Chat Upgrade Phase 2 — `is_online` is now mirrored from RTDB's
            // real `onDisconnect()`-backed presence by
            // `functions/chat_presence.js`'s `mirrorPresence`
            // (`PresenceService`, `presence_aggregate.dart`), not a raw
            // client-written flag with no disconnect detection. The old
            // 2-minute client-side staleness re-verification was a hedge
            // against exactly the ghost-session problem RTDB's onDisconnect
            // now solves at the source — trusting the field directly here.
            newMetadata['is_online'] = userData['is_online'] ?? false;

            return chat.copyWith(
              name: userData['displayName'],
              image: userData['photoURL'],
              metadata: newMetadata,
            );
          }
        }
        return chat;
      }).toList();
      controller.add(updatedChats);
    }

    chatsSub = getUserChats(userId).listen((chats) {
      lastChats = chats;
      // Identify users to watch
      final userIdsToWatch = chats
          .where((c) => c.type == ChatType.private)
          .expand((c) => c.participants)
          .where((p) => p != userId)
          .toSet()
          .take(10) // Limit to 10 for whereIn query constraint
          .toList();

      if (userIdsToWatch.isEmpty) {
        emit();
        return;
      }

      usersSub?.cancel();
      usersSub = _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIdsToWatch)
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docs) {
          userDataMap[doc.id] = doc.data();
        }
        emit();
      });

      // Emit initial data immediately in case user status takes time
      emit();
    });

    controller.onCancel = () {
      chatsSub?.cancel();
      usersSub?.cancel();
      controller.close();
    };

    return controller.stream;
  }

  // Get messages for a specific chat. `includeMetadataChanges: true` +
  // per-doc `metadata.hasPendingWrites` (Faz 0 §0.2) is what lets the UI
  // distinguish "sent, waiting on the server" from "server-acked" — without
  // it, a locally-queued write is indistinguishable from a synced one until
  // the ack silently swaps it out from under the list.
  Stream<List<MessageModel>> getChatMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromJson(
                doc.data(),
                hasPendingWrites: doc.metadata.hasPendingWrites,
              ))
          .toList();
    });
  }

  /// A fresh idempotency key for a new send — reused unchanged on retry so
  /// `ChatMessageMerge` can tell a retried send apart from a duplicate one
  /// (Faz 0 §0.2).
  String newClientId() => _uuid.v4();

  // Doc ref helper for the message-mutation methods below.
  DocumentReference<Map<String, dynamic>> _messageRef(
      String chatId, String messageId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
  }

  DocumentReference<Map<String, dynamic>> _chatRef(String chatId) =>
      _firestore.collection('chats').doc(chatId);

  CollectionReference<Map<String, dynamic>> _messagesCol(String chatId) =>
      _chatRef(chatId).collection('messages');

  /// Faz 2 §2.2 — cursor-paginated OLDER-message fetch, backing
  /// chat_detail_screen's "load more on scroll". Mirrors
  /// `community_service.dart`'s `fetchPostsPage` shape (named `limit`/
  /// `startAfter` cursor, a record return). [startAfterMessageId] resolves to
  /// a `DocumentSnapshot` internally (one extra get) so the CALLER only ever
  /// deals with a plain message id, never a raw Firestore cursor type —
  /// keeps `cloud_firestore` out of the screen (architecture rule: UI never
  /// touches Firebase).
  ///
  /// Deliberately orders by the legacy `timestamp` field, NOT the newer
  /// `server_timestamp` (unlike this file's own doc-comment aspiration on
  /// `sendMessage`) — every pre-Faz-2.1 message has `timestamp` but NOT
  /// `server_timestamp`, and Firestore silently drops any doc missing an
  /// `orderBy` field from the result set. Switching this query would make
  /// every legacy message vanish from history/pagination without a single
  /// error — exactly the silent-exclusion class `markChatAsRead`'s doc
  /// comment already warns about elsewhere in this file. Safe to switch only
  /// after a real backfill migration writes `server_timestamp` onto every
  /// pre-v2 doc (`docs/DATABASE.md` §10) — out of scope here.
  ///
  /// No new composite index: a plain `orderBy` with no `where` is a
  /// single-field query, auto-indexed.
  Future<({List<MessageModel> messages, String? lastMessageId})>
      getMessagesPage(
    String chatId, {
    int limit = 30,
    String? startAfterMessageId,
  }) async {
    try {
      final col = _messagesCol(chatId);
      Query<Map<String, dynamic>> query =
          col.orderBy('timestamp', descending: true).limit(limit);

      if (startAfterMessageId != null) {
        final anchor = await col.doc(startAfterMessageId).get();
        if (anchor.exists) query = query.startAfterDocument(anchor);
      }

      // Faz 7 — cache-first: scroll-back into history is very likely
      // already in the live listener's local cache. An empty cache result
      // is ambiguous ("not cached yet" vs. "genuinely the oldest page,
      // nothing more exists"), so both fall back to the normal server read
      // — accepted cost: the true last page of a chat's history pays one
      // extra server read the first time it's paged to.
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get();
        }
      } catch (_) {
        snapshot = await query.get();
      }
      final messages =
          snapshot.docs.map((d) => MessageModel.fromJson(d.data())).toList();
      return (
        messages: messages,
        lastMessageId: messages.isNotEmpty ? messages.last.id : null,
      );
    } catch (e, st) {
      _logger.error('getMessagesPage failed',
          service: 'ChatService', error: e, stackTrace: st);
      return (messages: <MessageModel>[], lastMessageId: null);
    }
  }

  /// Faz 2 §2.2 — jump-to-date. One-shot fetch of the [limit] messages at or
  /// immediately before [around]. A single inequality + `orderBy` on the SAME
  /// field (`timestamp`) needs no composite index — only a `where` +
  /// `orderBy` on TWO DIFFERENT fields does.
  Future<List<MessageModel>> getMessagesAround(
    String chatId, {
    required DateTime around,
    int limit = 30,
  }) async {
    try {
      final snapshot = await _messagesCol(chatId)
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(around))
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((d) => MessageModel.fromJson(d.data())).toList();
    } catch (e, st) {
      _logger.error('getMessagesAround failed',
          service: 'ChatService', error: e, stackTrace: st);
      return const [];
    }
  }

  /// Faz 2 §2.2 — media gallery. Cursor-paginated, image-only. Needs the new
  /// `messages (type ASC, timestamp DESC)` composite index
  /// (`firestore.indexes.json`) — an equality filter (`type`) plus `orderBy`
  /// on a different field (`timestamp`) is exactly the shape that requires
  /// one (unlike the plain-orderBy queries above).
  Future<({List<MessageModel> media, String? lastMessageId})> getChatMediaPage(
    String chatId, {
    int limit = 30,
    String? startAfterMessageId,
  }) async {
    try {
      final col = _messagesCol(chatId);
      Query<Map<String, dynamic>> query = col
          .where('type', isEqualTo: MessageType.image.wireValue)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (startAfterMessageId != null) {
        final anchor = await col.doc(startAfterMessageId).get();
        if (anchor.exists) query = query.startAfterDocument(anchor);
      }

      // Faz 7 — cache-first, same fallback shape as getMessagesPage above.
      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query.get(const GetOptions(source: Source.cache));
        if (snapshot.docs.isEmpty) {
          snapshot = await query.get();
        }
      } catch (_) {
        snapshot = await query.get();
      }
      final media =
          snapshot.docs.map((d) => MessageModel.fromJson(d.data())).toList();
      return (
        media: media,
        lastMessageId: media.isNotEmpty ? media.last.id : null,
      );
    } catch (e, st) {
      _logger.error('getChatMediaPage failed',
          service: 'ChatService', error: e, stackTrace: st);
      return (media: <MessageModel>[], lastMessageId: null);
    }
  }

  // In-chat search has no text-search backend (no Algolia/Elastic in this
  // stack) — this is an honest, bounded client-side substring search over
  // the most recent [limit] messages, not the entire chat history. 300
  // mirrors the same "cap a full-window read" idea as markChatAsRead's
  // _markReadCap below, just for a different operation.
  static const int _searchWindowCap = 300;

  /// Faz 2 §2.2 — bounded one-shot fetch backing in-chat search. The caller
  /// filters client-side (substring match on `body`, case-insensitive).
  Future<List<MessageModel>> fetchMessagesForSearch(String chatId) async {
    try {
      final snapshot = await _messagesCol(chatId)
          .orderBy('timestamp', descending: true)
          .limit(_searchWindowCap)
          .get();
      return snapshot.docs.map((d) => MessageModel.fromJson(d.data())).toList();
    } catch (e, st) {
      _logger.error('fetchMessagesForSearch failed',
          service: 'ChatService', error: e, stackTrace: st);
      return const [];
    }
  }

  /// Fetches a single message by id — used to resolve a pinned message (or a
  /// reply/jump target) that has scrolled outside the currently-loaded
  /// pagination window, without re-fetching a whole page around it.
  Future<MessageModel?> getMessageOnce(String chatId, String messageId) async {
    try {
      final doc = await _messagesCol(chatId).doc(messageId).get();
      if (!doc.exists) return null;
      return MessageModel.fromJson(doc.data()!);
    } catch (e, st) {
      _logger.error('getMessageOnce failed',
          service: 'ChatService', error: e, stackTrace: st);
      return null;
    }
  }

  /// Pins [messageId] as this chat's single pinned message. Any participant
  /// may pin/unpin (mirrors the reaction/engagement precedent of "any
  /// participant" rather than sender-only) — no firestore.rules change was
  /// needed, see the field doc comment on `ChatModel.pinnedMessageId`.
  Future<void> pinMessage({
    required String chatId,
    required String messageId,
    required String uid,
  }) async {
    await _chatRef(chatId).update({
      'pinnedMessageId': messageId,
      'pinnedBy': uid,
      'pinnedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unpinMessage(String chatId) async {
    await _chatRef(chatId).update({
      'pinnedMessageId': FieldValue.delete(),
      'pinnedBy': FieldValue.delete(),
      'pinnedAt': FieldValue.delete(),
    });
  }

  /// Faz 2 §2.2 — personal "star" bookmark, `users/{uid}/starred_messages/
  /// {messageId}`. Doc id = messageId so star/unstar is idempotent (a second
  /// star overwrites, never duplicates). Denormalized snapshot at star-time
  /// (mirrors `MessageReplyTo`'s precedent) so it survives a later edit/
  /// delete of the original.
  Future<void> starMessage({
    required String uid,
    required String chatId,
    required MessageModel message,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('starred_messages')
        .doc(message.id)
        .set({
      'message_id': message.id,
      'chat_id': chatId,
      'sender_id': message.senderId,
      'body': message.body,
      'type': message.type.wireValue,
      'starred_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unstarMessage({
    required String uid,
    required String messageId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('starred_messages')
        .doc(messageId)
        .delete();
  }

  /// Single aggregate listener for "which message ids has [uid] starred" —
  /// one subscription for the whole screen rather than one listener per
  /// visible bubble (R1: no N+1 listeners). Doc id IS the message id by
  /// construction (`starMessage` above), so this is just the id set.
  Stream<Set<String>> streamStarredMessageIds(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('starred_messages')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }

  /// Faz 2 §2.2 — message-level report (long-press "Report"), canonical
  /// shape (`reporterId`/`targetType`/`targetId`/`targetAuthorUid`/`reason`/
  /// `created_at` — Faz 0 §0.1's unified schema). `reports/{id}` create only
  /// checks `reporterId == auth.uid`; everything else is free-form at the
  /// rule level, same as every other report path.
  ///
  /// Faz 2 §2.6 verification fix: `AdminService.pendingReportsStream`/
  /// `reviewedReportsStream` both `orderBy('timestamp')`, and `ReportModel`
  /// reads `authorId` — both are the field names `community_service.dart`'s
  /// three report writers (post/comment/content) use, but this method only
  /// wrote `created_at`/`targetAuthorUid`. A composite-indexed `orderBy` on
  /// a field a doc doesn't have EXCLUDES that doc entirely (same silent-
  /// exclusion class as the `streakAtRiskNotifier`/broadcast bugs fixed
  /// earlier this session) — so every message/user report was invisible in
  /// the admin queue despite writing successfully. `created_at`/
  /// `targetAuthorUid` are kept (the plan's stated canonical names, and
  /// harmless extras), with `timestamp`/`authorId` now ALSO written so this
  /// report actually surfaces through the existing query/model unchanged.
  Future<void> reportMessage({
    required String chatId,
    required String messageId,
    required String reporterId,
    required String targetAuthorUid,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'targetType': 'message',
      'targetId': messageId,
      'targetAuthorUid': targetAuthorUid,
      'authorId': targetAuthorUid,
      'chatId': chatId,
      'reason': reason,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// User-level report (chat app-bar "..." → Report). Relocated here from
  /// `chat_detail_screen.dart`'s old inline `FirebaseFirestore.instance...add`
  /// call — a screen importing `cloud_firestore` directly violates
  /// `CLAUDE.md`'s "UI never touches Firebase" rule; this is a mechanical
  /// move, not a schema change, aside from adopting the canonical
  /// `targetAuthorUid`/`created_at` field names alongside the pre-existing
  /// `reporterId`/`targetId`/`targetType`/`reason` (the old call site already
  /// used those four correctly). See `reportMessage`'s doc comment above for
  /// why `authorId`/`timestamp` are ALSO written (Faz 2 §2.6 verification
  /// fix — the admin queue's query/model read those names, not these).
  Future<void> reportUser({
    required String reporterId,
    required String targetUserId,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'reporterId': reporterId,
      'targetType': 'user',
      'targetId': targetUserId,
      'targetAuthorUid': targetUserId,
      'authorId': targetUserId,
      'reason': reason,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Forwards [original] into [targetChatId] as a new message, stamping
  /// `forwarded_from` provenance. `hops` increments rather than resets on a
  /// forward-of-a-forward (`MessageForwardedFrom` doc comment).
  Future<void> forwardMessageTo({
    required String targetChatId,
    required String senderId,
    required String originalChatId,
    required MessageModel original,
  }) async {
    final previousHops = original.forwardedFrom?.hops ?? 0;
    await sendMessage(
      chatId: targetChatId,
      senderId: senderId,
      body: original.body,
      type: original.type,
      attachments: original.attachments,
      forwardedFrom: MessageForwardedFrom(
        chatId: originalChatId,
        messageId: original.id,
        hops: previousHops + 1,
      ),
    );
  }

  /// Resolves display names for a small set of currently-typing uids (never
  /// the full participant list) — bounded the same way
  /// `getUserChatsWithStatus` already caps its `whereIn` at 10.
  Future<Map<String, String>> getUserDisplayNames(List<String> uids) async {
    if (uids.isEmpty) return {};
    final capped = uids.take(10).toList();
    try {
      final snapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: capped)
          .get();
      return {
        for (final doc in snapshot.docs)
          doc.id: (doc.data()['displayName'] as String?) ?? ''
      };
    } catch (e, st) {
      _logger.error('getUserDisplayNames failed',
          service: 'ChatService', error: e, stackTrace: st);
      return {};
    }
  }

  /// Sends a message (Faz 2 §2.1 — message model v2). `body` replaces the
  /// old `text` param name; `attachments`/`replyTo`/`forwardedFrom`/
  /// `mentions` are the new v2 fields, all optional.
  ///
  /// `server_timestamp` is the schema's canonical, server-authoritative
  /// field (replaces the old client-clock `DateTime.now()` at chat_service
  /// .dart:138). `timestamp` is ALSO written, mirroring the exact same
  /// server instant — a deliberate, temporary compatibility bridge
  /// (`docs/DATABASE.md` §10, "adding a field — the safe sequence") so
  /// `getChatMessages`'s existing `orderBy('timestamp')` query keeps
  /// surfacing every message, old AND new, without excluding new docs that
  /// lack the legacy field or requiring a backfill of old ones (migration
  /// discipline: read-path adapts, nothing gets rewritten). Drop the mirror
  /// once Faz 2.2's cursor-paginated query reads `server_timestamp` directly.
  ///
  /// `unreadCounts` is deliberately NOT touched here — incrementing it is
  /// now exclusively `onChatMessageCreated`'s job (`functions/index.js`),
  /// which already reads this same chat doc's participant list to fan out
  /// the push notification. A client-side increment here would double-count.
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String body = '',
    MessageType type = MessageType.text,
    List<MessageAttachment> attachments = const [],
    MessageReplyTo? replyTo,
    MessageForwardedFrom? forwardedFrom,
    List<MessageMention> mentions = const [],
    String? clientId,
  }) async {
    final messageId = _uuid.v4();
    final chatRef = _firestore.collection('chats').doc(chatId);
    final messageRef = chatRef.collection('messages').doc(messageId);

    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      type: type,
      body: body,
      attachments: attachments,
      replyTo: replyTo,
      forwardedFrom: forwardedFrom,
      mentions: mentions,
      clientId: clientId ?? messageId,
    );

    final serverNow = FieldValue.serverTimestamp();
    final messageData = {
      ...message.toJson(),
      'server_timestamp': serverNow,
      'timestamp': serverNow, // compat mirror — see doc comment above
    };

    // No read-modify-write dependency remains once unreadCounts moved
    // server-side, so a batch (no transaction/read) is enough.
    final batch = _firestore.batch();
    batch.set(messageRef, messageData);
    batch.update(chatRef, {
      'lastMessage': messageData,
      'updatedAt': serverNow,
    });

    // Faz 0 §0.2 — a rules/App-Check/auth rejection is the one failure mode
    // Firestore's own offline mutation queue will NOT retry (it has already
    // rolled the local doc back by the time this throws); everything else
    // (network-request-failed, unavailable, deadline-exceeded) is left to
    // resolve itself via the queue, so it's deliberately rethrown unchanged
    // rather than reported here.
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      const hardRejectionCodes = {
        'permission-denied',
        'invalid-argument',
        'unauthenticated',
      };
      if (hardRejectionCodes.contains(e.code)) {
        throw ChatSendRejectedException(e.code, e);
      }
      rethrow;
    }
  }

  // Faz 0 §0.5's crash: the old isRead-batch query had no cap at all and
  // broke past 500 unread (Firestore's per-batch write ceiling). Capped well
  // under it; a chat with more unread than this catches up over several
  // opens rather than in one batch — nobody reads 400 messages in one glance.
  static const int _markReadCap = 400;

  /// Marks [userId]'s view of this chat as caught-up. Two independent steps:
  ///
  /// 1. Zero out ONLY our own unread counter. Increments are exclusively
  ///    server-side now (`onChatMessageCreated`) — firestore.rules'
  ///    `canMarkOwnUnreadZero()` rejects anything else (another uid's key, a
  ///    non-zero value, or bundling this with any other field).
  /// 2. Stamp `read_by`/`delivered_to` on the messages this user hasn't seen
  ///    yet, capped at [_markReadCap]. There is no Firestore query for
  ///    "read_by does NOT contain uid" (only array-contains, never its
  ///    negation), so this fetches a capped, most-recent window and filters
  ///    client-side.
  ///
  /// Pre-v2 (legacy) messages have no `server_timestamp` at all, so this
  /// query never touches them — consistent with "no backward rewrite of old
  /// docs" (`docs/DATABASE.md` §10). Their frozen legacy `isRead` value is
  /// what `MessageModel.isReadBy`'s fallback already renders for them.
  Future<void> markChatAsRead(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);

    await chatRef.update({'unreadCounts.$userId': 0});

    final recent = await chatRef
        .collection('messages')
        .orderBy('server_timestamp', descending: true)
        .limit(_markReadCap)
        .get();

    if (recent.docs.isEmpty) return;

    final batch = _firestore.batch();
    var touched = 0;
    for (final doc in recent.docs) {
      final data = doc.data();
      if (data['senderId'] == userId) continue;
      final readBy = List<String>.from(data['read_by'] as List? ?? const []);
      if (readBy.contains(userId)) continue;
      batch.update(doc.reference, {
        'read_by': FieldValue.arrayUnion([userId]),
        'delivered_to': FieldValue.arrayUnion([userId]),
      });
      touched++;
    }
    if (touched > 0) {
      await batch.commit();
    }
  }

  /// Adds [uid]'s reaction to a message. Purely additive/idempotent
  /// (arrayUnion) — safe to call even if already reacted with this emoji.
  /// Any chat participant may react to any message (mirrors the post-level
  /// reaction pattern); firestore.rules' `canUpdateMessageEngagement()` is
  /// the server-side backstop.
  Future<void> addReaction({
    required String chatId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    await _messageRef(chatId, messageId).update({
      'reactions.$emoji': FieldValue.arrayUnion([uid]),
    });
  }

  /// Removes [uid]'s reaction. Safe to call even if never reacted.
  Future<void> removeReaction({
    required String chatId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    await _messageRef(chatId, messageId).update({
      'reactions.$emoji': FieldValue.arrayRemove([uid]),
    });
  }

  /// Sender-only edit. firestore.rules enforces the 15-minute window and
  /// that only `body`/`edited_at` change on this path — this is the
  /// client-side mirror of that contract, not an independent source of truth.
  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newBody,
  }) async {
    await _messageRef(chatId, messageId).update({
      'body': newBody,
      'edited_at': FieldValue.serverTimestamp(),
    });
  }

  /// "Delete for everyone" (WhatsApp-style) — sender only within the same
  /// 15-minute window as `editMessage`, enforced by firestore.rules. Clears
  /// body/attachments so a stale client can't keep rendering the removed
  /// content from cache, and best-effort deletes each attachment's
  /// underlying Storage object(s) — `CHAT-05` (`TODO.md`): the Firestore
  /// reference was cleared here for a while with nothing ever removing the
  /// actual file, an orphan that also mattered for `BLK-12` (GDPR erasure
  /// completeness), not just storage cost.
  ///
  /// [attachments] is the CALLER's own already-loaded copy (every call site
  /// already has the full `MessageModel`) — no extra read needed just to
  /// learn what to delete. Runs AFTER the Firestore update succeeds, not
  /// before: a failed Storage delete must never block the message itself
  /// from being marked deleted, and is fire-and-forget (`unawaited`) for the
  /// same reason — `StorageUploadService.deleteByUrl`/`deleteByPath` already
  /// swallow-and-log their own errors, so there's nothing more for this
  /// caller to usefully do with one beyond what's already logged.
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    List<MessageAttachment> attachments = const [],
  }) async {
    await _messageRef(chatId, messageId).update({
      'is_deleted': true,
      'deleted_for': 'everyone',
      'body': '',
      'attachments': <Map<String, dynamic>>[],
    });

    final storage = StorageUploadService();
    for (final a in attachments) {
      if (a.url.isNotEmpty) unawaited(storage.deleteByUrl(a.url));
      if (a.thumbUrl != null) unawaited(storage.deleteByUrl(a.thumbUrl!));
      if (a.storagePath != null) {
        unawaited(storage.deleteByPath(a.storagePath!));
      }
      if (a.thumbStoragePath != null) {
        unawaited(storage.deleteByPath(a.thumbStoragePath!));
      }
    }
  }

  /// Faz 2 §2.6 — a group owner/admin (or site admin) takes down ANOTHER
  /// member's message. Deliberately narrower than [deleteMessageForEveryone]:
  /// only flips `is_deleted`/`deleted_for` — firestore.rules'
  /// `canModeratorDeleteMessage()` rejects any attempt to also touch `body`
  /// (or anything else), so a moderator can remove visibility but can never
  /// rewrite or impersonate what the sender actually said. The original
  /// `body` is deliberately left in Firestore (not wiped, unlike the
  /// sender's own privacy-motivated delete above) — `MessageModel
  /// .isDeletedFor` gates rendering on the flag alone, so it never reaches
  /// the UI, while still being available for an appeal/audit review if one
  /// is ever needed. Only meaningful on a group-backed chat (`groupId` set)
  /// — the rule has no concept of "moderator" outside a community group.
  Future<void> deleteMessageAsModerator({
    required String chatId,
    required String messageId,
  }) async {
    await _messageRef(chatId, messageId).update({
      'is_deleted': true,
      'deleted_for': 'everyone',
    });
  }

  /// "Delete for me" — hides the message for [uid] only; every other
  /// participant's view is unaffected, and this is allowed for ANY
  /// participant, not just the sender (firestore.rules'
  /// `canUpdateMessageEngagement()` accepts `deleted_for` only as a list —
  /// the sender-only 'everyone' string stays exclusively on
  /// `deleteMessageForEveryone`'s path). Not meaningful on a message that's
  /// already deleted for everyone; callers shouldn't offer this action then.
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String uid,
  }) async {
    await _messageRef(chatId, messageId).update({
      'deleted_for': FieldValue.arrayUnion([uid]),
    });
  }

  // Chat Upgrade Phase 2 — typing status moved off Firestore entirely onto
  // RTDB (`PresenceService.setTyping`, `presence_service.dart`): every
  // keystroke previously wrote `chats/{id}.typingUsers.$userId` on the
  // SHARED chat doc, fanning that write to every participant's chat-list
  // listener, and had no TTL — a killed app left a permanent "still typing"
  // ghost. `setTypingStatus` (formerly here) is gone; `chat_detail_screen
  // .dart` calls `PresenceService().setTyping` directly now.

  /// Wraps `FirestoreService.getUserDocStream` and maps straight to
  /// `UserModel` — keeps `cloud_firestore` (and the `DocumentSnapshot` cast)
  /// out of chat_detail_screen.dart entirely (architecture rule: UI never
  /// touches Firebase, not even for a type name). Used for the private-chat
  /// app-bar title (other participant's name/photo/online status).
  Stream<UserModel> watchUser(String uid) {
    return FirestoreService().getUserDocStream(uid).map(
          (doc) => UserModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>),
        );
  }

  // Get single chat stream
  Stream<ChatModel> getChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) throw Exception("Chat not found");
      return ChatModel.fromJson(doc.data()!, doc.id);
    });
  }

  // Create or get existing private chat
  Future<String> createOrGetPrivateChat(
      String currentUserId, String otherUserId) async {
    // Ideally, we might want to query if a chat already exists between these two.
    // However, Firestore doesn't support easy "exact array equality" queries.
    // A common pattern is to store a unique ID generated from sorted user IDs.
    // Or we can just query chats containing currentUserId and filter client-side (costly if many chats).

    // For now, simpler approach: Query chats where 'participants' contains currentUserId
    // Then filter for the one that also has otherUserId and size is 2.

    final querySnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in querySnapshot.docs) {
      final List<dynamic> participants = doc.data()['participants'];
      if (participants.length == 2 && participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Create new chat
    final newChatId = _uuid.v4();
    final now = DateTime.now();

    final newChat = ChatModel(
      id: newChatId,
      participants: [currentUserId, otherUserId],
      unreadCounts: {currentUserId: 0, otherUserId: 0},
      type: ChatType.private,
      updatedAt: now,
    );

    await _firestore.collection('chats').doc(newChatId).set(newChat.toJson());
    return newChatId;
  }

  /// Stream of total unread message count across all chats. Server-side
  /// authoritative: sums `unreadCounts[userId]`, which `onChatMessageCreated`
  /// (functions/index.js) is the ONLY writer of (Faz 2 §2.1). Faz 2 §2.4
  /// closed the one remaining gap here — for a group-backed chat that
  /// function used to derive recipients from `chats.participants` (which only
  /// ever holds the group's owner), so a real member's key in `unreadCounts`
  /// was never even created. It now sources recipients from
  /// `community_groups/{groupId}/members` for those chats, so this sum is
  /// correct for DMs AND groups/gym chats alike — no client change needed
  /// here beyond that server fix.
  Stream<int> getUnreadMessageCountStream(String userId) {
    return getUserChats(userId).map((chats) {
      return chats.fold<int>(
          0, (total, chat) => total + (chat.unreadCounts[userId] ?? 0));
    });
  }

  // ── Chat list prefs (Faz 2 §2.4) ────────────────────────────────────────
  // Per-user, per-chat pin/archive/mute/delete state — `users/{uid}/private/
  // chat_prefs`. Mirrors `FirestoreService`'s `_presencePrefsRef`/
  // `getGymPresencePrefs`/`setGymTrackingEnabled` shape (nested-map field +
  // `set(merge:true)` to add a key without disturbing sibling keys,
  // `FieldValue.delete()` on the SAME nested path to remove one). Lives under
  // the existing `private/{docId}` wildcard rule — no firestore.rules change
  // needed (see `ChatPrefsModel`'s doc comment for why this is NOT stored on
  // the shared chat doc instead).
  DocumentReference<Map<String, dynamic>> _chatPrefsRef(String uid) =>
      _firestore
          .collection('users')
          .doc(uid)
          .collection('private')
          .doc('chat_prefs');

  /// Live per-user chat-list prefs — feeds `ChatListFilter.apply` alongside
  /// the chat stream itself (two independent `StreamBuilder`s in
  /// `chat_list_screen.dart`, not a hand-merged stream: `chat_prefs` is a
  /// single document, not a per-item collection like the online-status merge
  /// `getUserChatsWithStatus` needs).
  Stream<ChatPrefsModel> getChatPrefsStream(String uid) {
    return _chatPrefsRef(uid)
        .snapshots()
        .map((snap) => ChatPrefsModel.fromFirestore(snap.data()));
  }

  Future<void> _setChatPrefFlag({
    required String uid,
    required String field,
    required String chatId,
    required bool value,
  }) async {
    try {
      if (value) {
        await _chatPrefsRef(uid).set({
          field: {chatId: FieldValue.serverTimestamp()},
        }, SetOptions(merge: true));
      } else {
        await _chatPrefsRef(uid).set({
          field: {chatId: FieldValue.delete()},
        }, SetOptions(merge: true));
      }
    } catch (e, st) {
      _logger.error('_setChatPrefFlag($field=$value) failed',
          service: 'ChatService', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> pinChat(String uid, String chatId) => _setChatPrefFlag(
      uid: uid, field: 'pinned_chats', chatId: chatId, value: true);

  Future<void> unpinChat(String uid, String chatId) => _setChatPrefFlag(
      uid: uid, field: 'pinned_chats', chatId: chatId, value: false);

  Future<void> archiveChat(String uid, String chatId) => _setChatPrefFlag(
      uid: uid, field: 'archived_chats', chatId: chatId, value: true);

  Future<void> unarchiveChat(String uid, String chatId) => _setChatPrefFlag(
      uid: uid, field: 'archived_chats', chatId: chatId, value: false);

  Future<void> muteChat(String uid, String chatId) => _setChatPrefFlag(
      uid: uid, field: 'muted_chats', chatId: chatId, value: true);

  Future<void> unmuteChat(String uid, String chatId) => _setChatPrefFlag(
      uid: uid, field: 'muted_chats', chatId: chatId, value: false);

  /// "Delete for me" at the CHAT level (distinct from `deleteMessageForMe`) —
  /// the chat doc itself is never deletable client-side, so this only hides
  /// the conversation from the list; it naturally reappears the moment a new
  /// message bumps `updatedAt` past this timestamp (`ChatPrefsModel
  /// .isDeleted`). There is no separate "undelete" — re-hiding after it
  /// reappears is just calling this again.
  Future<void> deleteChatForMe(String uid, String chatId) => _setChatPrefFlag(
      uid: uid, field: 'deleted_chats', chatId: chatId, value: true);

  /// Creates a new group chat and returns the resulting [ChatModel].
  Future<ChatModel> createGroupChat({
    required String name,
    required List<String> participantIds,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final allParticipants = {...participantIds, uid}.toList();
    final unreadCounts = {for (final p in allParticipants) p: 0};

    final ref = await _firestore.collection('chats').add({
      'type': ChatType.group.name,
      'name': name,
      'participants': allParticipants,
      'unreadCounts': unreadCounts,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdBy': uid,
    });

    final doc = await ref.get();
    return ChatModel.fromJson(doc.data()!, doc.id);
  }

  /// Preload chats to warm up cache. Best-effort — a failure here must
  /// never block app startup (`splash_screen.dart` already calls this
  /// fire-and-forget), but it must not vanish silently either (R4): the
  /// previous bare `catch { // Ignore }` is now a real logged failure,
  /// matching every other catch block in this file.
  Future<void> preloadChats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final chats = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(10)
          .get();

      // Faz 0 §0.5 — also warm the first message page of the few most-
      // recent chats (the same cursor-paginated query `ChatDetailScreen`
      // itself issues on open), not just the list row — that's the data
      // actually needed the moment a chat opens.
      await Future.wait(chats.docs.take(3).map((d) => getMessagesPage(d.id)));
    } catch (e, st) {
      _logger.error('preloadChats failed',
          service: 'ChatService', error: e, stackTrace: st);
    }
  }
}
