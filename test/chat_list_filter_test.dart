import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/chat_model.dart';
import 'package:cookrange/core/models/chat_prefs_model.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/utils/chat_list_filter.dart';

const _me = 'me';

ChatModel _chat({
  required String id,
  ChatType type = ChatType.private,
  String? name,
  String? body,
  DateTime? updatedAt,
  int unread = 0,
}) {
  return ChatModel(
    id: id,
    participants: [_me, 'other'],
    unreadCounts: {_me: unread},
    type: type,
    updatedAt: updatedAt ?? DateTime(2026, 1, 1),
    name: name ?? id,
    lastMessage: body == null
        ? null
        : MessageModel(
            id: '${id}_last',
            senderId: 'other',
            type: MessageType.text,
            body: body,
            clientId: '${id}_last',
          ),
  );
}

void main() {
  group('ChatListFilter.apply — segment', () {
    final chats = [
      _chat(id: 'dm1', type: ChatType.private),
      _chat(id: 'group1', type: ChatType.group),
      _chat(id: 'gym1', type: ChatType.gym),
    ];

    test('all returns every chat', () {
      final result = ChatListFilter.apply(
          chats: chats, prefs: ChatPrefsModel.empty, currentUserId: _me);
      expect(result.map((c) => c.id), containsAll(['dm1', 'group1', 'gym1']));
      expect(result, hasLength(3));
    });

    test('groups segment matches only ChatType.group', () {
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: ChatPrefsModel.empty,
        currentUserId: _me,
        segment: ChatListSegment.groups,
      );
      expect(result.map((c) => c.id), ['group1']);
    });

    test('gym segment matches only ChatType.gym', () {
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: ChatPrefsModel.empty,
        currentUserId: _me,
        segment: ChatListSegment.gym,
      );
      expect(result.map((c) => c.id), ['gym1']);
    });

    test('dm segment matches only ChatType.private', () {
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: ChatPrefsModel.empty,
        currentUserId: _me,
        segment: ChatListSegment.dm,
      );
      expect(result.map((c) => c.id), ['dm1']);
    });
  });

  group('ChatListFilter.apply — unread filter', () {
    test('unreadOnly excludes chats with a zero (or absent) unread count', () {
      final chats = [
        _chat(id: 'read', unread: 0),
        _chat(id: 'unread', unread: 3),
      ];
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: ChatPrefsModel.empty,
        currentUserId: _me,
        unreadOnly: true,
      );
      expect(result.map((c) => c.id), ['unread']);
    });
  });

  group('ChatListFilter.apply — search', () {
    final chats = [
      _chat(id: 'c1', name: 'Ayşe Yılmaz', body: 'see you at the gym'),
      _chat(id: 'c2', name: 'Workout Buddies', body: 'who is free tonight'),
    ];

    test('matches on name (case-insensitive)', () {
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: ChatPrefsModel.empty,
        currentUserId: _me,
        searchQuery: 'ayşe',
      );
      expect(result.map((c) => c.id), ['c1']);
    });

    test('matches on lastMessage.body (case-insensitive)', () {
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: ChatPrefsModel.empty,
        currentUserId: _me,
        searchQuery: 'TONIGHT',
      );
      expect(result.map((c) => c.id), ['c2']);
    });

    test('empty query matches everything', () {
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: ChatPrefsModel.empty,
        currentUserId: _me,
        searchQuery: '   ',
      );
      expect(result, hasLength(2));
    });
  });

  group('ChatListFilter.apply — archive', () {
    final chats = [_chat(id: 'kept'), _chat(id: 'archived')];
    final prefs =
        ChatPrefsModel(archivedChats: {'archived': DateTime(2026, 1, 1)});

    test('main list (archivedOnly: false) excludes archived chats', () {
      final result =
          ChatListFilter.apply(chats: chats, prefs: prefs, currentUserId: _me);
      expect(result.map((c) => c.id), ['kept']);
    });

    test('archivedOnly: true returns ONLY archived chats', () {
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: prefs,
        currentUserId: _me,
        archivedOnly: true,
      );
      expect(result.map((c) => c.id), ['archived']);
    });
  });

  group('ChatListFilter.apply — delete-for-me reappear semantics', () {
    test('deleted chat with no newer activity is hidden', () {
      final chats = [
        _chat(id: 'c1', updatedAt: DateTime(2026, 1, 1)),
      ];
      final prefs = ChatPrefsModel(deletedChats: {'c1': DateTime(2026, 1, 5)});
      final result =
          ChatListFilter.apply(chats: chats, prefs: prefs, currentUserId: _me);
      expect(result, isEmpty);
    });

    test('deleted chat with a later message reappears', () {
      final chats = [
        _chat(id: 'c1', updatedAt: DateTime(2026, 1, 10)),
      ];
      final prefs = ChatPrefsModel(deletedChats: {'c1': DateTime(2026, 1, 5)});
      final result =
          ChatListFilter.apply(chats: chats, prefs: prefs, currentUserId: _me);
      expect(result.map((c) => c.id), ['c1']);
    });
  });

  group('ChatListFilter.apply — sort order', () {
    test('pinned chats sort before unpinned, regardless of updatedAt', () {
      final chats = [
        _chat(id: 'recent', updatedAt: DateTime(2026, 1, 10)),
        _chat(id: 'old_but_pinned', updatedAt: DateTime(2026, 1, 1)),
      ];
      final prefs =
          ChatPrefsModel(pinnedChats: {'old_but_pinned': DateTime(2026, 1, 2)});
      final result =
          ChatListFilter.apply(chats: chats, prefs: prefs, currentUserId: _me);
      expect(result.map((c) => c.id), ['old_but_pinned', 'recent']);
    });

    test('multiple pinned chats sort most-recently-pinned first', () {
      final chats = [
        _chat(id: 'pinned_first'),
        _chat(id: 'pinned_second'),
      ];
      final prefs = ChatPrefsModel(pinnedChats: {
        'pinned_first': DateTime(2026, 1, 1),
        'pinned_second': DateTime(2026, 1, 5),
      });
      final result =
          ChatListFilter.apply(chats: chats, prefs: prefs, currentUserId: _me);
      expect(result.map((c) => c.id), ['pinned_second', 'pinned_first']);
    });

    test('unpinned chats sort by updatedAt descending', () {
      final chats = [
        _chat(id: 'older', updatedAt: DateTime(2026, 1, 1)),
        _chat(id: 'newer', updatedAt: DateTime(2026, 1, 5)),
      ];
      final result = ChatListFilter.apply(
          chats: chats, prefs: ChatPrefsModel.empty, currentUserId: _me);
      expect(result.map((c) => c.id), ['newer', 'older']);
    });

    test('pin ordering is skipped in the archived-only view', () {
      final chats = [
        _chat(id: 'archived_recent', updatedAt: DateTime(2026, 1, 10)),
        _chat(id: 'archived_old', updatedAt: DateTime(2026, 1, 1)),
      ];
      final prefs = ChatPrefsModel(
        archivedChats: {
          'archived_recent': DateTime(2026, 1, 1),
          'archived_old': DateTime(2026, 1, 1),
        },
        // Even though this one is "pinned", the archived view ignores pin
        // ordering (pinning has no meaning once a chat is archived).
        pinnedChats: {'archived_old': DateTime(2026, 1, 9)},
      );
      final result = ChatListFilter.apply(
        chats: chats,
        prefs: prefs,
        currentUserId: _me,
        archivedOnly: true,
      );
      expect(result.map((c) => c.id), ['archived_recent', 'archived_old']);
    });
  });
}
