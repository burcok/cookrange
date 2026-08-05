import '../models/chat_model.dart';
import '../models/chat_prefs_model.dart';

/// Faz 2 §2.4 segmented filter — "Tümü / Gruplar / Salon / DM". [group]
/// intentionally covers BOTH the pre-existing ad-hoc `createGroupChat` chats
/// AND `community_groups`-paired public/private groups (both produce
/// `ChatType.group` — only `kind:'gym'` groups produce `ChatType.gym`, which
/// gets its own segment).
enum ChatListSegment { all, groups, gym, dm }

/// Pure, Firebase-free chat-list shaping: filter (segment/unread/search/
/// archived/deleted) then sort (pinned-first, else most-recent-first). Takes
/// only already-loaded [ChatModel]/[ChatPrefsModel] values — no Firestore
/// calls — so it is fully unit-testable (`test/chat_list_filter_test.dart`)
/// without any Firebase mocking, per `CLAUDE.md` §8's "new pure logic gets a
/// unit test."
class ChatListFilter {
  ChatListFilter._();

  /// Returns the chats that belong in the requested view, sorted for display.
  ///
  /// - Deleted (Faz 2 §2.4 "delete for me") chats are always excluded unless
  ///   new activity un-hides them (`ChatPrefsModel.isDeleted`).
  /// - [archivedOnly] false (default, the main list): archived chats are
  ///   excluded. [archivedOnly] true (the "Archived" sheet): ONLY archived
  ///   chats are returned, and [segment]/[unreadOnly] still apply within
  ///   that set (an archived gym chat still shows under the Gym segment of
  ///   the archived view) but pinning has no meaning there, so pin ordering
  ///   is skipped.
  /// - Search matches [ChatModel.name] (already resolved to the other
  ///   participant's display name for a DM by `ChatService
  ///   .getUserChatsWithStatus`) OR the denormalized `lastMessage.body` —
  ///   both already loaded with the chat list itself, zero extra reads.
  static List<ChatModel> apply({
    required List<ChatModel> chats,
    required ChatPrefsModel prefs,
    required String currentUserId,
    ChatListSegment segment = ChatListSegment.all,
    bool unreadOnly = false,
    String searchQuery = '',
    bool archivedOnly = false,
  }) {
    final query = searchQuery.trim().toLowerCase();

    final filtered = chats.where((chat) {
      if (prefs.isDeleted(chat.id, chat.updatedAt)) return false;

      final archived = prefs.isArchived(chat.id);
      if (archivedOnly) {
        if (!archived) return false;
      } else if (archived) {
        return false;
      }

      final matchesSegment = switch (segment) {
        ChatListSegment.all => true,
        ChatListSegment.groups => chat.type == ChatType.group,
        ChatListSegment.gym => chat.type == ChatType.gym,
        ChatListSegment.dm => chat.type == ChatType.private,
      };
      if (!matchesSegment) return false;

      if (unreadOnly && (chat.unreadCounts[currentUserId] ?? 0) <= 0) {
        return false;
      }

      if (query.isNotEmpty) {
        final name = (chat.name ?? '').toLowerCase();
        final body = (chat.lastMessage?.body ?? '').toLowerCase();
        if (!name.contains(query) && !body.contains(query)) return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      if (!archivedOnly) {
        final aPin = prefs.pinnedChats[a.id];
        final bPin = prefs.pinnedChats[b.id];
        if (aPin != null || bPin != null) {
          if (aPin != null && bPin != null) return bPin.compareTo(aPin);
          return aPin != null ? -1 : 1;
        }
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });

    return filtered;
  }
}
