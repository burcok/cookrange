import '../models/message_model.dart';

/// The WhatsApp-style send lifecycle for one of the CURRENT user's own
/// messages. Meaningless for a message someone else sent — callers only
/// need it when `message.senderId == currentUid`.
enum MessageSendState { sending, sent, delivered, read, failed }

/// Pure, Firebase-free derivation — unit-tested at
/// `test/message_status_test.dart`, following `chat_list_filter.dart`'s
/// precedent. Extracts `chat_detail_screen.dart`'s previous inline
/// `_isDelivered`/`_isRead` methods (Faz 0 §0.3), which only ever answered
/// "delivered" or "read" — with no way to represent "still in Firestore's
/// local write queue" or "Firestore rejected this outright", both of which
/// `MessageModel.hasPendingWrites`/`sendFailed` (Faz 0 §0.2) now carry.
class MessageStatusResolver {
  const MessageStatusResolver._();

  static MessageSendState resolve({
    required MessageModel message,
    required List<String> otherParticipantIds,

    /// True only for a chat backed by a `community_groups/{id}` doc
    /// (`chat.groupId != null`). For that shape, `chats/{id}.participants`
    /// holds only the group's OWNER (`firestore.rules`' `canAccessGroupChat`
    /// grants access via group membership, not that array) — so
    /// "read by every other participant" can never be true for a real
    /// multi-member group and must degrade to "read by anyone". An ad-hoc
    /// multi-party chat with no `groupId` has no such gap: its `participants`
    /// array genuinely lists every member, so "read by everyone" stays
    /// meaningful there.
    required bool isCommunityGroupChat,
  }) {
    if (message.sendFailed) return MessageSendState.failed;
    if (message.hasPendingWrites || message.serverTimestamp == null) {
      return MessageSendState.sending;
    }
    if (otherParticipantIds.isEmpty) return MessageSendState.sent;

    final isRead = isCommunityGroupChat
        ? otherParticipantIds.any(message.isReadBy)
        : otherParticipantIds.every(message.isReadBy);
    if (isRead) return MessageSendState.read;

    final isDelivered = otherParticipantIds.any(message.isDeliveredTo);
    if (isDelivered) return MessageSendState.delivered;

    return MessageSendState.sent;
  }
}
