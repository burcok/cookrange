import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/private/chat_prefs` — Faz 2 §2.4.
///
/// Per-user, per-chat list-view state: pin to top, archive out of the main
/// list, mute the push/bump for one conversation, "delete" (hide) a
/// conversation from the list. Lives in `private/` — covered by the existing
/// generic `match /private/{docId} { allow read, write: if isOwner(uid); }`
/// rule (firestore.rules), the same wildcard `GymPresencePrefsModel` already
/// relies on — no rules change needed for this doc.
///
/// Deliberately NOT stored as a map on the shared `chats/{chatId}` doc (the
/// way `pinnedMessageId`/`unreadCounts` are): every participant/group member
/// already listens to that doc via their `getUserChats` query snapshot, so a
/// field living there re-delivers a snapshot to EVERY other viewer on every
/// single toggle — harmless for `unreadCounts` (changes on every message,
/// already the dominant cost) but pure waste for a purely personal, no
/// other-party-visible preference like "I archived this chat". Keeping it in
/// `private/` means my pin/archive/mute/delete only ever writes to MY OWN
/// document.
///
/// Map VALUE is the server timestamp of the action. Not read for any ordering
/// logic for archive/mute/delete today, but [pinnedChats]' value sorts the
/// pinned section (most-recently-pinned first) and every map gets a free
/// audit trail ("pinned since") and a natural place to grow a duration-based
/// mute later without another schema bump. Presence of the key is what
/// matters for on/off; absence = off.
///
/// [deletedChats]' value is compared against the chat's own `updatedAt` at
/// filter time (`ChatListFilter`) rather than acting as a permanent tombstone
/// — the chat doc itself can never be deleted client-side
/// (`firestore.rules`: "Chats are never deleted client-side"), so "delete"
/// here honestly means "hide until new activity", matching how the feature
/// is described to the user (see `chat.delete_chat_confirm.message`).
class ChatPrefsModel {
  final Map<String, DateTime> pinnedChats;
  final Map<String, DateTime> archivedChats;
  final Map<String, DateTime> mutedChats;
  final Map<String, DateTime> deletedChats;

  const ChatPrefsModel({
    this.pinnedChats = const {},
    this.archivedChats = const {},
    this.mutedChats = const {},
    this.deletedChats = const {},
  });

  static const empty = ChatPrefsModel();

  static Map<String, DateTime> _parseMap(Map<String, dynamic>? d, String key) {
    final raw = d?[key];
    if (raw is! Map) return const {};
    final out = <String, DateTime>{};
    raw.forEach((k, v) {
      if (v is Timestamp) out[k.toString()] = v.toDate();
    });
    return out;
  }

  /// Never throws on malformed/missing data — a missing doc (never touched
  /// any chat's list-view state) is just [empty], mirroring
  /// `GymPresencePrefsModel.fromFirestore`'s contract.
  factory ChatPrefsModel.fromFirestore(Map<String, dynamic>? d) {
    if (d == null) return empty;
    return ChatPrefsModel(
      pinnedChats: _parseMap(d, 'pinned_chats'),
      archivedChats: _parseMap(d, 'archived_chats'),
      mutedChats: _parseMap(d, 'muted_chats'),
      deletedChats: _parseMap(d, 'deleted_chats'),
    );
  }

  bool isPinned(String chatId) => pinnedChats.containsKey(chatId);
  bool isArchived(String chatId) => archivedChats.containsKey(chatId);
  bool isMuted(String chatId) => mutedChats.containsKey(chatId);

  /// True only if [chatId] was deleted AND there has been no activity since
  /// (`chatUpdatedAt` is the chat doc's own `updatedAt` — bumped by
  /// `ChatService.sendMessage` on every new message). The moment a new
  /// message lands after the deletion timestamp, this flips back to false and
  /// the conversation naturally reappears in the list — no explicit
  /// "undelete" write required.
  bool isDeleted(String chatId, DateTime chatUpdatedAt) {
    final deletedAt = deletedChats[chatId];
    if (deletedAt == null) return false;
    return !chatUpdatedAt.isAfter(deletedAt);
  }
}
