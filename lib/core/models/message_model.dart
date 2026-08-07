import 'package:cloud_firestore/cloud_firestore.dart';

/// Faz 2 §2.1 — wire values match exactly what's stored in the `type` field.
/// Deliberately NOT `.name` (which would emit `planOffer`, not `plan_offer`)
/// so the enum can use normal lowerCamelCase Dart identifiers while still
/// round-tripping the snake_case the schema defines.
enum MessageType {
  text('text'),
  image('image'),
  system('system'),
  planOffer('plan_offer'),
  announcement('announcement'),
  voice('voice');

  final String wireValue;
  const MessageType(this.wireValue);

  static MessageType fromWire(String? value) {
    return MessageType.values.firstWhere(
      (e) => e.wireValue == value,
      orElse: () => MessageType.text,
    );
  }
}

/// One piece of media/file attached to a message. `kind` is a free string
/// (`'image'` for photos, `'audio'` for a `MessageType.voice` note's
/// attachment — chat_detail_screen.dart's senders) so a future `'video'`/
/// `'file'` doesn't need another schema bump.
///
/// Faz 5 — [storagePath]/[thumbStoragePath] are ADDITIVE, not a replacement
/// for [url]/[thumbUrl]. Two upload shapes coexist by design
/// (`StorageUploadService.uploadChatImage` vs `.uploadGroupChatMedia`):
///  - Legacy/current (`chat_images/{scopeId}/` uploads): [url]/[thumbUrl]
///    are already-resolved `https://` download URLs, rendered directly.
///  - New (`chat_media/{chatId}/{uid}/{fileName}` uploads — the group-chat
///    storage-scoping fix): that Storage path's `read` rule is always
///    `false`, so there IS no direct download URL — [storagePath]/
///    [thumbStoragePath] carry the bare path instead, resolved at render
///    time through `ChatMediaUrlCache` (`getChatMediaUrl` callable, which
///    re-verifies chat membership server-side before minting a short-lived
///    signed URL). See `ChatAttachmentImage` (the one place both shapes are
///    reconciled for rendering).
class MessageAttachment {
  final String kind;
  final String url;
  final String? mime;
  final int? width;
  final int? height;
  final int? size;
  final String? thumbUrl;
  final String? caption;

  /// Voice-note duration in milliseconds. Null for every non-audio kind.
  final int? durationMs;

  /// Voice-note waveform, downsampled to a fixed-length (48-bucket)
  /// `List<int>` of 0-100 normalized amplitudes by
  /// `WaveformDownsampler.downsample` at record time
  /// (`waveform_downsample.dart`). Denormalized onto the SENDER's own
  /// attachment so `AppVoicePlayer` can render the static waveform straight
  /// from Firestore — audio is never decoded client-side just to draw one.
  /// Null for every non-audio kind.
  final List<int>? peaks;

  final String? storagePath;
  final String? thumbStoragePath;

  const MessageAttachment({
    required this.kind,
    required this.url,
    this.mime,
    this.width,
    this.height,
    this.size,
    this.thumbUrl,
    this.caption,
    this.durationMs,
    this.peaks,
    this.storagePath,
    this.thumbStoragePath,
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      kind: json['kind'] as String? ?? 'file',
      url: json['url'] as String? ?? '',
      mime: json['mime'] as String?,
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      size: (json['size'] as num?)?.toInt(),
      thumbUrl: json['thumb_url'] as String?,
      caption: json['caption'] as String?,
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      peaks: (json['peaks'] as List?)?.map((e) => (e as num).toInt()).toList(),
      storagePath: json['storage_path'] as String?,
      thumbStoragePath: json['thumb_storage_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'url': url,
      if (mime != null) 'mime': mime,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (size != null) 'size': size,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (caption != null) 'caption': caption,
      if (durationMs != null) 'duration_ms': durationMs,
      if (peaks != null) 'peaks': peaks,
      if (storagePath != null) 'storage_path': storagePath,
      if (thumbStoragePath != null) 'thumb_storage_path': thumbStoragePath,
    };
  }
}

/// Quoted-message preview shown above a reply (WhatsApp-style). A
/// denormalized snapshot taken at reply time — not a live reference — so it
/// keeps rendering even if the original is later edited or deleted.
class MessageReplyTo {
  final String id;
  final String senderId;
  final String preview;
  final String kind; // mirrors the parent message's MessageType.wireValue

  const MessageReplyTo({
    required this.id,
    required this.senderId,
    required this.preview,
    required this.kind,
  });

  factory MessageReplyTo.fromJson(Map<String, dynamic> json) {
    return MessageReplyTo(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      preview: json['preview'] as String? ?? '',
      kind: json['kind'] as String? ?? 'text',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'senderId': senderId, 'preview': preview, 'kind': kind};
  }
}

/// Forwarding provenance. `hops` counts how many times this content has been
/// forwarded (a forward-of-a-forward increments rather than resets), so a
/// future "forwarded many times" label has data to key off without another
/// migration.
class MessageForwardedFrom {
  final String chatId;
  final String messageId;
  final int hops;

  const MessageForwardedFrom({
    required this.chatId,
    required this.messageId,
    this.hops = 1,
  });

  factory MessageForwardedFrom.fromJson(Map<String, dynamic> json) {
    return MessageForwardedFrom(
      chatId: json['chatId'] as String? ?? '',
      messageId: json['messageId'] as String? ?? '',
      hops: (json['hops'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {'chatId': chatId, 'messageId': messageId, 'hops': hops};
  }
}

/// Faz 3 §3.5 — denormalized snapshot of a `plan_offer`-typed message's
/// linked `users/{uid}/plan_offers/{offerId}`, taken at send time. Mirrors
/// `MessageReplyTo`'s precedent exactly (a snapshot, not a live reference) —
/// but here that's not just a style choice, it's the only thing that works:
/// `plan_offers` read is recipient-only (`firestore.rules`), so the SENDER's
/// own copy of this chat could never re-fetch the offer live to render this
/// card. Denormalizing every field the card needs at write time means both
/// sides of the chat render identically without either needing a permission
/// this schema deliberately doesn't grant them.
class MessagePlanOfferInfo {
  final String offerId;
  final String templateId;
  final String templateName;
  final double targetCalories;
  final String fromName;

  const MessagePlanOfferInfo({
    required this.offerId,
    required this.templateId,
    this.templateName = '',
    this.targetCalories = 0,
    this.fromName = '',
  });

  factory MessagePlanOfferInfo.fromJson(Map<String, dynamic> json) {
    return MessagePlanOfferInfo(
      offerId: json['offer_id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      templateName: json['template_name'] as String? ?? '',
      targetCalories: (json['target_calories'] as num?)?.toDouble() ?? 0,
      fromName: json['from_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'offer_id': offerId,
        'template_id': templateId,
        'template_name': templateName,
        'target_calories': targetCalories,
        'from_name': fromName,
      };
}

/// One @-mention inside `body`. `offset`/`len` are indices into `body`
/// (UTF-16 code units — Dart String indexing) so a composer can
/// highlight/re-derive spans without re-parsing text for the mentioned name.
class MessageMention {
  final String uid;
  final int offset;
  final int len;

  const MessageMention(
      {required this.uid, required this.offset, required this.len});

  factory MessageMention.fromJson(Map<String, dynamic> json) {
    return MessageMention(
      uid: json['uid'] as String? ?? '',
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      len: (json['len'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'uid': uid, 'offset': offset, 'len': len};
}

/// Faz 2 §2.1 — message model v2. Replaces the old 6-field shape
/// (id/senderId/text/type/timestamp/isRead) with attachments, replies,
/// forwarding, per-message reactions, edit/delete, per-recipient delivery
/// and read receipts, mentions, and a server-authoritative timestamp.
///
/// **Migration discipline (no backward rewrite of old docs — DATABASE.md
/// §10):** old 6-field messages are adapted entirely on the READ path here;
/// they are never rewritten. `fromJson` prefers the new field, falls back to
/// the legacy one, and nothing in this file ever persists a legacy doc in
/// its new shape.
class MessageModel {
  final String id;
  final String senderId;
  final MessageType type;
  final String body;
  final List<MessageAttachment> attachments;
  final MessageReplyTo? replyTo;
  final MessageForwardedFrom? forwardedFrom;

  /// Set only for `type == MessageType.planOffer` — null for every other
  /// type (see [MessagePlanOfferInfo]'s doc comment for why this is a
  /// snapshot, not a live reference).
  final MessagePlanOfferInfo? planOfferInfo;

  /// Faz 5 — set only for `type == MessageType.system`. An event KEY (e.g.
  /// `'member_joined'`, `'group_renamed'`), never a pre-rendered string —
  /// `AppMessageBubble` localizes the actual sentence from this +
  /// [systemParams] via `AppLocalizations` at render time, in the READER's
  /// own language (this app has EN/TR parity everywhere; a server-baked
  /// English string would break that). Written ONLY by
  /// `functions/group_system_messages.js` using the Admin SDK with
  /// `senderId: '__system__'` — deliberately NOT in `isValidNewMessage()`'s
  /// client-writable allowlist (`firestore.rules`), since a client-writable
  /// system-message-authorship path would be a straightforward impersonation
  /// vector. Null for every other type, and null for a pre-Faz-5 system doc
  /// (there are none yet, but `body` stays a valid plain-English fallback if
  /// one is ever hand-written or migrated in).
  final String? systemEvent;

  /// Named placeholders for [systemEvent]'s localized template (e.g.
  /// `{'display_name': 'Ayşe'}` for `member_joined`) — a plain
  /// `Map<String, dynamic>`, not a typed class, since each event shape is
  /// small and this never round-trips through anything but
  /// `AppLocalizations.translate`'s `variables` substitution.
  final Map<String, dynamic>? systemParams;

  final Map<String, List<String>> reactions;
  final DateTime? editedAt;
  final bool isDeleted;
  // 'everyone' | List<String> (uids who deleted it "for me only") | null.
  // Kept as the plan's literal union shape rather than split into two Dart
  // fields — see isDeletedFor().
  final dynamic deletedFor;
  final List<String> deliveredTo;
  final List<String> readBy;
  final List<MessageMention> mentions;
  final DateTime? serverTimestamp;
  final String clientId;

  /// Transient, client-only — never in `toJson`/Firestore. True while this
  /// message's write is still in the SDK's local mutation queue, not yet
  /// ack'd by the server. Sourced from `DocumentSnapshot.metadata
  /// .hasPendingWrites` via `ChatService.getChatMessages`'s
  /// `includeMetadataChanges: true` listener (Faz 0 §0.2).
  final bool hasPendingWrites;

  /// Transient, client-only — never in `toJson`/Firestore. True ONLY for a
  /// synthetic entry built by `PendingSendFailure.toMessageModel()`
  /// (`chat_send_failure_store.dart`) representing a send Firestore
  /// permanently rejected and rolled back from its cache — it never reaches
  /// `fromJson` at all. See `ChatMessageMerge`.
  final bool sendFailed;

  // Set only when parsed from a pre-v2 doc that had no `read_by` key at all —
  // its single global `isRead` bool carried no per-uid information. Never
  // written back; purely a read-path fallback for isReadBy() below.
  final bool _legacyIsRead;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.type,
    this.body = '',
    this.attachments = const [],
    this.replyTo,
    this.forwardedFrom,
    this.planOfferInfo,
    this.systemEvent,
    this.systemParams,
    Map<String, List<String>>? reactions,
    this.editedAt,
    this.isDeleted = false,
    this.deletedFor,
    List<String>? deliveredTo,
    List<String>? readBy,
    List<MessageMention>? mentions,
    this.serverTimestamp,
    required this.clientId,
    bool legacyIsRead = false,
    this.hasPendingWrites = false,
    this.sendFailed = false,
  })  : reactions = reactions ?? const {},
        deliveredTo = deliveredTo ?? const [],
        readBy = readBy ?? const [],
        mentions = mentions ?? const [],
        _legacyIsRead = legacyIsRead;

  /// True if [uid] has read this message. New-format docs answer precisely
  /// from `read_by`; a pre-v2 doc (no `read_by` key present at all) had only
  /// a single bool with no per-uid info, so it falls back to "read by
  /// someone other than the sender" — the closest equivalent, and exactly
  /// what the pre-migration UI showed.
  bool isReadBy(String uid) {
    if (readBy.contains(uid)) return true;
    if (readBy.isEmpty && _legacyIsRead && uid != senderId) return true;
    return false;
  }

  bool isDeliveredTo(String uid) => deliveredTo.contains(uid);

  /// True if this message should render as deleted for [uid] — either
  /// deleted for everyone, or [uid] specifically chose "delete for me".
  bool isDeletedFor(String uid) {
    if (isDeleted || deletedFor == 'everyone') return true;
    final df = deletedFor;
    return df is List && df.contains(uid);
  }

  /// Non-nullable convenience accessor mirroring the old model's `timestamp`
  /// field name (chat_detail_screen.dart / chat_list_screen.dart read this).
  /// [serverTimestamp] is null only for the brief local window before a
  /// just-sent message's serverTimestamp() sentinel resolves — falling back
  /// to "now" matches the old model's own behavior for that same window
  /// (`ts is Timestamp ? ts.toDate() : DateTime.now()`), never a hard-cast
  /// that would crash the viewer's chat on a pending write.
  DateTime get timestamp => serverTimestamp ?? DateTime.now();

  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    bool hasPendingWrites = false,
  }) {
    final rawTs = json['server_timestamp'] ?? json['timestamp'];
    final hasReadBy = json['read_by'] != null;

    return MessageModel(
      id: json['id'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      type: MessageType.fromWire(json['type'] as String?),
      body: (json['body'] ?? json['text']) as String? ?? '',
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => MessageAttachment.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      replyTo: json['reply_to'] != null
          ? MessageReplyTo.fromJson(
              Map<String, dynamic>.from(json['reply_to'] as Map))
          : null,
      forwardedFrom: json['forwarded_from'] != null
          ? MessageForwardedFrom.fromJson(
              Map<String, dynamic>.from(json['forwarded_from'] as Map))
          : null,
      planOfferInfo: json['plan_offer'] != null
          ? MessagePlanOfferInfo.fromJson(
              Map<String, dynamic>.from(json['plan_offer'] as Map))
          : null,
      systemEvent: json['system_event'] as String?,
      systemParams: json['system_params'] != null
          ? Map<String, dynamic>.from(json['system_params'] as Map)
          : null,
      reactions: (json['reactions'] as Map?)?.map(
            (k, v) =>
                MapEntry(k as String, List<String>.from(v as List? ?? [])),
          ) ??
          const {},
      editedAt: json['edited_at'] is Timestamp
          ? (json['edited_at'] as Timestamp).toDate()
          : null,
      isDeleted: json['is_deleted'] as bool? ?? false,
      deletedFor: json['deleted_for'] is List
          ? List<String>.from(json['deleted_for'] as List)
          : json['deleted_for'],
      deliveredTo: List<String>.from(json['delivered_to'] as List? ?? const []),
      readBy: hasReadBy
          ? List<String>.from(json['read_by'] as List? ?? const [])
          : const [],
      mentions: (json['mentions'] as List<dynamic>?)
              ?.map((e) =>
                  MessageMention.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      serverTimestamp: rawTs is Timestamp ? rawTs.toDate() : null,
      clientId: json['client_id'] as String? ?? json['id'] as String? ?? '',
      legacyIsRead: !hasReadBy && (json['isRead'] as bool? ?? false),
      hasPendingWrites: hasPendingWrites,
    );
  }

  /// Serializes the current field values. Does NOT inject
  /// `FieldValue.serverTimestamp()` for [serverTimestamp] — that sentinel is
  /// only correct at the moment of initial send, which is the call site's
  /// decision (`ChatService.sendMessage`), not this method's. Re-serializing
  /// an already-fetched message (e.g. for an edit) must preserve its real
  /// timestamp, never stamp a fresh one.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'type': type.wireValue,
      'body': body,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      if (replyTo != null) 'reply_to': replyTo!.toJson(),
      if (forwardedFrom != null) 'forwarded_from': forwardedFrom!.toJson(),
      if (planOfferInfo != null) 'plan_offer': planOfferInfo!.toJson(),
      if (systemEvent != null) 'system_event': systemEvent,
      if (systemParams != null) 'system_params': systemParams,
      'reactions': reactions,
      if (editedAt != null) 'edited_at': Timestamp.fromDate(editedAt!),
      'is_deleted': isDeleted,
      if (deletedFor != null) 'deleted_for': deletedFor,
      'delivered_to': deliveredTo,
      'read_by': readBy,
      'mentions': mentions.map((m) => m.toJson()).toList(),
      if (serverTimestamp != null)
        'server_timestamp': Timestamp.fromDate(serverTimestamp!),
      'client_id': clientId,
    };
  }

  MessageModel copyWith({
    String? body,
    Map<String, List<String>>? reactions,
    DateTime? editedAt,
    bool? isDeleted,
    dynamic deletedFor,
    List<String>? deliveredTo,
    List<String>? readBy,
    DateTime? serverTimestamp,
    bool? hasPendingWrites,
    bool? sendFailed,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      type: type,
      body: body ?? this.body,
      attachments: attachments,
      replyTo: replyTo,
      forwardedFrom: forwardedFrom,
      planOfferInfo: planOfferInfo,
      systemEvent: systemEvent,
      systemParams: systemParams,
      reactions: reactions ?? this.reactions,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedFor: deletedFor ?? this.deletedFor,
      deliveredTo: deliveredTo ?? this.deliveredTo,
      readBy: readBy ?? this.readBy,
      mentions: mentions,
      serverTimestamp: serverTimestamp ?? this.serverTimestamp,
      clientId: clientId,
      legacyIsRead: _legacyIsRead,
      hasPendingWrites: hasPendingWrites ?? this.hasPendingWrites,
      sendFailed: sendFailed ?? this.sendFailed,
    );
  }
}
