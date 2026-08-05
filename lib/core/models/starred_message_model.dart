import 'package:cloud_firestore/cloud_firestore.dart';

/// Faz 2 §2.2 — a personal bookmark of a chat message ("star" in the
/// long-press context menu). Lives at `users/{uid}/starred_messages/{messageId}`
/// with the doc ID set to the message's own ID (idempotent star/unstar — a
/// second star is just an overwrite, an unstar is a delete, never a duplicate).
///
/// Fields are a denormalized snapshot taken at star-time, not a live
/// reference — mirrors the `MessageReplyTo` precedent (`message_model.dart`)
/// so a starred message keeps rendering even if the original is later
/// edited or deleted. Snake_case fields: this is a brand-new collection with
/// no legacy camelCase shape to preserve, so it follows the majority
/// convention used elsewhere in the schema (`CLAUDE.md` §9) rather than the
/// chats/{id} doc's own camelCase, which is that doc's specific legacy.
class StarredMessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String body;
  final String type;
  final DateTime? starredAt;

  const StarredMessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.body,
    required this.type,
    this.starredAt,
  });

  factory StarredMessageModel.fromJson(Map<String, dynamic> json) {
    final ts = json['starred_at'];
    return StarredMessageModel(
      messageId: json['message_id'] as String? ?? '',
      chatId: json['chat_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      starredAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  /// Does NOT include `starred_at` — the caller stamps
  /// `FieldValue.serverTimestamp()` at write time (matches
  /// `ChatService.sendMessage`'s split between model fields and the
  /// server-timestamp sentinel, which only the call site can correctly
  /// inject).
  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'chat_id': chatId,
      'sender_id': senderId,
      'body': body,
      'type': type,
    };
  }
}
