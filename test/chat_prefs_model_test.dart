import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/chat_prefs_model.dart';

void main() {
  group('ChatPrefsModel.fromFirestore', () {
    test('missing doc data returns empty', () {
      final prefs = ChatPrefsModel.fromFirestore(null);
      expect(prefs.pinnedChats, isEmpty);
      expect(prefs.archivedChats, isEmpty);
      expect(prefs.mutedChats, isEmpty);
      expect(prefs.deletedChats, isEmpty);
    });

    test('parses pinned/archived/muted/deleted maps independently', () {
      final now = Timestamp.fromDate(DateTime(2026, 1, 1));
      final prefs = ChatPrefsModel.fromFirestore({
        'pinned_chats': {'c1': now},
        'archived_chats': {'c2': now},
        'muted_chats': {'c3': now},
        'deleted_chats': {'c4': now},
      });

      expect(prefs.isPinned('c1'), isTrue);
      expect(prefs.isPinned('c2'), isFalse);
      expect(prefs.isArchived('c2'), isTrue);
      expect(prefs.isMuted('c3'), isTrue);
      expect(prefs.deletedChats['c4'], now.toDate());
    });

    test('a non-Timestamp value in a map is skipped, not crashed on', () {
      final prefs = ChatPrefsModel.fromFirestore({
        'pinned_chats': {'c1': 'not-a-timestamp'},
      });
      expect(prefs.isPinned('c1'), isFalse);
    });

    test('a non-Map value for a known field is treated as absent', () {
      final prefs = ChatPrefsModel.fromFirestore({'pinned_chats': 'oops'});
      expect(prefs.pinnedChats, isEmpty);
    });
  });

  group('ChatPrefsModel.isDeleted — reappear-on-new-activity semantics', () {
    test('not deleted at all -> false regardless of chat updatedAt', () {
      expect(
          ChatPrefsModel.empty.isDeleted('c1', DateTime(2026, 1, 1)), isFalse);
    });

    test('deleted, no activity since -> true', () {
      final deletedAt = Timestamp.fromDate(DateTime(2026, 1, 10));
      final prefs = ChatPrefsModel.fromFirestore({
        'deleted_chats': {'c1': deletedAt},
      });
      // chat.updatedAt at or before the deletion instant: still hidden.
      expect(prefs.isDeleted('c1', DateTime(2026, 1, 10)), isTrue);
      expect(prefs.isDeleted('c1', DateTime(2026, 1, 5)), isTrue);
    });

    test('deleted, but a later message bumped updatedAt -> reappears', () {
      final deletedAt = Timestamp.fromDate(DateTime(2026, 1, 10));
      final prefs = ChatPrefsModel.fromFirestore({
        'deleted_chats': {'c1': deletedAt},
      });
      expect(prefs.isDeleted('c1', DateTime(2026, 1, 11)), isFalse);
    });
  });
}
