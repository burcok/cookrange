import 'package:cloud_firestore/cloud_firestore.dart';
import 'message_model.dart';

enum ChatType { private, group, system, gym }

class ChatModel {
  final String id;
  final List<String> participants;
  final MessageModel? lastMessage;
  final Map<String, int> unreadCounts;
  final ChatType type;
  final DateTime updatedAt;
  final String? name; // For group chats
  final String? image; // For group chats
  final bool isPublic; // For public checks
  final Map<String, dynamic>? metadata; // Flex field for specific card data
  final Map<String, bool>? typingUsers;

  ChatModel({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.unreadCounts,
    required this.type,
    required this.updatedAt,
    this.name,
    this.image,
    this.isPublic = false,
    this.metadata,
    this.typingUsers,
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
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      name: json['name'],
      image: json['image'],
      isPublic: json['isPublic'] ?? false,
      metadata: json['metadata'],
      typingUsers: (json['typingUsers'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, value as bool),
      ),
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
      'isPublic': isPublic,
      'metadata': metadata,
      'typingUsers': typingUsers,
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
    bool? isPublic,
    Map<String, dynamic>? metadata,
    Map<String, bool>? typingUsers,
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
      isPublic: isPublic ?? this.isPublic,
      metadata: metadata ?? this.metadata,
      typingUsers: typingUsers ?? this.typingUsers,
    );
  }
}
