import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/services/chat_send_failure_store.dart';
import 'package:cookrange/core/utils/chat_message_merge.dart';

const _me = 'me';

MessageModel _live({
  required String id,
  String? clientId,
  DateTime? serverTimestamp,
  bool hasPendingWrites = false,
  String senderId = _me,
  String body = 'hi',
}) {
  return MessageModel(
    id: id,
    senderId: senderId,
    type: MessageType.text,
    body: body,
    clientId: clientId ?? id,
    serverTimestamp: serverTimestamp,
    hasPendingWrites: hasPendingWrites,
  );
}

PendingSendFailure _failure({
  required String clientId,
  DateTime? createdAt,
  String body = 'failed',
}) {
  return PendingSendFailure(
    clientId: clientId,
    chatId: 'chat1',
    senderId: _me,
    type: MessageType.text,
    body: body,
    createdAt: createdAt ?? DateTime(2026, 1, 1, 12),
    errorCode: 'permission-denied',
  );
}

void main() {
  group('ChatMessageMerge.merge — ordering', () {
    test('acked messages sort by server_timestamp descending', () {
      final result = ChatMessageMerge.merge(
        live: [
          _live(id: 'a', serverTimestamp: DateTime(2026, 1, 1, 10)),
          _live(id: 'b', serverTimestamp: DateTime(2026, 1, 1, 12)),
          _live(id: 'c', serverTimestamp: DateTime(2026, 1, 1, 11)),
        ],
        failed: const [],
        currentUid: _me,
      );
      expect(result.map((m) => m.id), ['b', 'c', 'a']);
    });

    test(
        'a pending write (null server_timestamp) sorts to the top, not the '
        'bottom, alongside already-acked history', () {
      final result = ChatMessageMerge.merge(
        live: [
          _live(id: 'old', serverTimestamp: DateTime(2026, 1, 1, 9)),
          _live(id: 'pending', serverTimestamp: null, hasPendingWrites: true),
        ],
        failed: const [],
        currentUid: _me,
      );
      expect(result.first.id, 'pending');
    });
  });

  group('ChatMessageMerge.merge — failed sends', () {
    test(
        'a failed send with no matching live doc appears as a synthetic '
        'entry', () {
      final result = ChatMessageMerge.merge(
        live: [_live(id: 'sent', serverTimestamp: DateTime(2026, 1, 1, 9))],
        failed: [_failure(clientId: 'never-landed')],
        currentUid: _me,
      );
      expect(result.map((m) => m.id), containsAll(['sent', 'never-landed']));
      final failedEntry = result.firstWhere((m) => m.id == 'never-landed');
      expect(failedEntry.sendFailed, isTrue);
      expect(failedEntry.body, 'failed');
    });

    test(
        'a successful retry (live doc with the same clientId) supersedes '
        'its own stale failure record — no duplicate bubble', () {
      final result = ChatMessageMerge.merge(
        live: [
          _live(id: 'server-doc-id', clientId: 'retry-1', body: 'made it'),
        ],
        failed: [_failure(clientId: 'retry-1', body: 'made it')],
        currentUid: _me,
      );
      expect(result, hasLength(1));
      expect(result.single.sendFailed, isFalse);
      expect(result.single.body, 'made it');
    });

    test(
        'dedups by clientId, not by doc id, when both a legacy id-as-'
        'clientId live message and a distinct failure exist', () {
      final result = ChatMessageMerge.merge(
        live: [
          _live(id: 'legacy-1')
        ], // clientId falls back to id == 'legacy-1'
        failed: [_failure(clientId: 'legacy-1')],
        currentUid: _me,
      );
      expect(result, hasLength(1));
      expect(result.single.sendFailed, isFalse);
    });

    test('multiple independent failures all survive the merge', () {
      final result = ChatMessageMerge.merge(
        live: const [],
        failed: [
          _failure(clientId: 'f1', createdAt: DateTime(2026, 1, 1, 10)),
          _failure(clientId: 'f2', createdAt: DateTime(2026, 1, 1, 11)),
        ],
        currentUid: _me,
      );
      expect(result.map((m) => m.clientId), ['f2', 'f1']); // newest first
    });
  });
}
