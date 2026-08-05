import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';

// Faz 2 §2.3 audit: 'system' was rendered (chat_list_screen.dart's old
// `_buildSystemChatCard`) but never produced by any writer — removed.
// 'gym' was in the same state (rendered, never produced) but is now real:
// CommunityGroupService.createGroup / AdminService.approveGymApplication
// create a paired chat of this type for kind:'gym' groups.
enum ChatType { private, group, gym }

class ChatModel {
  final String id;
  final List<String> participants;
  final MessageModel? lastMessage;
  final Map<String, int> unreadCounts;
  final ChatType type;
  final DateTime updatedAt;
  final String? name; // For group chats
  final String? image; // For group chats
  final Map<String, dynamic>? metadata; // Flex field for specific card data
  final Map<String, bool>? typingUsers;

  // Faz 2 §2.2 — single pinned message per chat. Deliberately camelCase to
  // match every sibling field on THIS doc (participants/unreadCounts/
  // updatedAt/createdBy/typingUsers are all camelCase) — the snake_case
  // convention elsewhere in the schema applies to the MESSAGE subdocument
  // shape (Faz 2 §2.1), not this doc. No firestore.rules change was needed:
  // canUpdateChatMeta() is a blocklist (only participants/type/createdBy/
  // unreadCounts are protected), so any participant could already write
  // these three fields before this model even declared them.
  final String? pinnedMessageId;
  final String? pinnedBy;
  final DateTime? pinnedAt;

  // Faz 2 §2.3 — back-reference to the owning `community_groups/{groupId}`
  // doc (whose `chat_id` field points back here). Null for a DM or the
  // pre-existing ad-hoc `createGroupChat` flow — both remain ungoverned,
  // plain participant-array chats. When set, firestore.rules'
  // `canAccessGroupChat()` grants the WHOLE group's membership read/react
  // access (and post access, subject to `announcement_only`) regardless of
  // whether they appear in `participants` — see that function's doc comment
  // for why `participants` alone doesn't scale to a group's membership.
  final String? groupId;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.unreadCounts,
    required this.type,
    required this.updatedAt,
    this.name,
    this.image,
    this.metadata,
    this.typingUsers,
    this.pinnedMessageId,
    this.pinnedBy,
    this.pinnedAt,
    this.groupId,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json, String id) {
    return ChatModel(
      id: id,
      participants: List<String>.from(json['participants'] ?? []),
      lastMessage: json['lastMessage'] != null
          ? MessageModel.fromJson(json['lastMessage'])
          : null,
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      type: ChatType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ChatType.private,
      ),
      updatedAt: json['updatedAt'] is Timestamp
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      name: json['name'],
      image: json['image'],
      metadata: json['metadata'],
      typingUsers: (json['typingUsers'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as bool),
      ),
      pinnedMessageId: json['pinnedMessageId'] as String?,
      pinnedBy: json['pinnedBy'] as String?,
      pinnedAt: json['pinnedAt'] is Timestamp
          ? (json['pinnedAt'] as Timestamp).toDate()
          : null,
      groupId: json['groupId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'participants': participants,
      'lastMessage': lastMessage?.toJson(),
      'unreadCounts': unreadCounts,
      'type': type.name,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'name': name,
      'image': image,
      'metadata': metadata,
      'typingUsers': typingUsers,
      if (pinnedMessageId != null) 'pinnedMessageId': pinnedMessageId,
      if (pinnedBy != null) 'pinnedBy': pinnedBy,
      if (pinnedAt != null) 'pinnedAt': Timestamp.fromDate(pinnedAt!),
      if (groupId != null) 'groupId': groupId,
    };
  }

  ChatModel copyWith({
    String? id,
    List<String>? participants,
    MessageModel? lastMessage,
    Map<String, int>? unreadCounts,
    ChatType? type,
    DateTime? updatedAt,
    String? name,
    String? image,
    Map<String, dynamic>? metadata,
    Map<String, bool>? typingUsers,
    String? pinnedMessageId,
    String? pinnedBy,
    DateTime? pinnedAt,
    String? groupId,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      type: type ?? this.type,
      updatedAt: updatedAt ?? this.updatedAt,
      name: name ?? this.name,
      image: image ?? this.image,
      metadata: metadata ?? this.metadata,
      typingUsers: typingUsers ?? this.typingUsers,
      pinnedMessageId: pinnedMessageId ?? this.pinnedMessageId,
      pinnedBy: pinnedBy ?? this.pinnedBy,
      pinnedAt: pinnedAt ?? this.pinnedAt,
      groupId: groupId ?? this.groupId,
    );
  }
}
