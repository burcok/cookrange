import '../models/message_model.dart';
import '../services/chat_send_failure_store.dart';

/// Combines a chat's live Firestore stream with any locally hard-failed
/// sends into one canonical, correctly-ordered timeline. Pure and
/// Firebase-free — unit-tested at `test/chat_message_merge_test.dart`,
/// following `chat_list_filter.dart`'s precedent (`docs/SERVICES.md`).
///
/// Two problems this fixes that Firestore does not solve on its own:
///
/// 1. `Query.snapshots()` has no `serverTimestampBehavior` parameter (unlike
///    `DocumentReference.get()`'s `GetOptions` — confirmed absent anywhere in
///    the installed `cloud_firestore` package), so a just-sent message's
///    `server_timestamp` reads back as `null` until the server acks it.
///    Firestore's local query engine's own ordering of that pending doc
///    among historical ones is not a documented guarantee, so this function
///    re-derives the sort explicitly rather than trusting incoming list
///    order — treating a null timestamp as "now" puts an in-flight send at
///    the top, where a user expects it (Faz 0 §0.2, fixes the "optimistic
///    bubble lands in the wrong place" defect).
/// 2. A hard-rejected send (rules/App Check/invalid-argument) is rolled back
///    from Firestore's cache entirely — it will never reappear in `live`.
///    Its synthetic failure entry has to be merged in from
///    `ChatSendFailureStore` instead.
class ChatMessageMerge {
  const ChatMessageMerge._();

  static List<MessageModel> merge({
    required List<MessageModel> live,
    required List<PendingSendFailure> failed,
    required String currentUid,
  }) {
    final byClientId = <String, MessageModel>{};

    for (final m in live) {
      final key = m.clientId.isNotEmpty ? m.clientId : m.id;
      byClientId[key] = m;
    }

    for (final f in failed) {
      // A live doc with this clientId means a retry already succeeded (or
      // the original send did after all, just slowly) — the real message
      // always wins over its own stale failure record.
      if (byClientId.containsKey(f.clientId)) continue;
      byClientId[f.clientId] = f.toMessageModel();
    }

    final merged = byClientId.values.toList()
      ..sort((a, b) => _sortKey(b).compareTo(_sortKey(a)));

    return merged;
  }

  static DateTime _sortKey(MessageModel m) {
    // A pending (not yet ack'd) or failed message has no resolved server
    // timestamp — sort it as "now" so it lands at the top of a
    // `reverse: true` list instead of the bottom, where a null/epoch value
    // would otherwise put it.
    return m.serverTimestamp ?? DateTime.now();
  }
}
