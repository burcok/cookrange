import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/message_model.dart';

void main() {
  group('MessageType', () {
    test('wireValue round-trips through fromWire for every enum value', () {
      for (final t in MessageType.values) {
        expect(MessageType.fromWire(t.wireValue), t);
      }
    });

    test('plan_offer (snake_case wire value) maps to MessageType.planOffer',
        () {
      expect(MessageType.fromWire('plan_offer'), MessageType.planOffer);
      expect(MessageType.planOffer.wireValue, 'plan_offer');
    });

    test('unknown/missing type defaults to text', () {
      expect(MessageType.fromWire('bogus'), MessageType.text);
      expect(MessageType.fromWire(null), MessageType.text);
    });
  });

  group('MessageModel v2 — round trip', () {
    test('toJson → fromJson preserves every v2 field', () {
      final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final original = MessageModel(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.image,
        body: 'check this out',
        attachments: const [
          MessageAttachment(
            kind: 'image',
            url: 'https://example.com/a.jpg',
            mime: 'image/jpeg',
            width: 800,
            height: 600,
            size: 12345,
            thumbUrl: 'https://example.com/a_thumb.jpg',
            caption: 'gym selfie',
          ),
        ],
        replyTo: const MessageReplyTo(
          id: 'm0',
          senderId: 'u2',
          preview: 'earlier message',
          kind: 'text',
        ),
        forwardedFrom: const MessageForwardedFrom(
          chatId: 'c0',
          messageId: 'fm0',
          hops: 2,
        ),
        reactions: const {
          '🔥': ['u2', 'u3'],
        },
        editedAt: now,
        isDeleted: false,
        deletedFor: const ['u4'],
        deliveredTo: const ['u2', 'u3'],
        readBy: const ['u2'],
        mentions: const [MessageMention(uid: 'u5', offset: 0, len: 4)],
        serverTimestamp: now,
        clientId: 'client-abc',
      );

      final roundTripped = MessageModel.fromJson(original.toJson());

      expect(roundTripped.id, 'm1');
      expect(roundTripped.senderId, 'u1');
      expect(roundTripped.type, MessageType.image);
      expect(roundTripped.body, 'check this out');
      expect(roundTripped.attachments, hasLength(1));
      expect(roundTripped.attachments.first.url, 'https://example.com/a.jpg');
      expect(roundTripped.attachments.first.width, 800);
      expect(roundTripped.replyTo?.id, 'm0');
      expect(roundTripped.replyTo?.preview, 'earlier message');
      expect(roundTripped.forwardedFrom?.chatId, 'c0');
      expect(roundTripped.forwardedFrom?.hops, 2);
      expect(roundTripped.reactions['🔥'], ['u2', 'u3']);
      expect(roundTripped.editedAt, now);
      expect(roundTripped.isDeleted, false);
      expect(roundTripped.deletedFor, ['u4']);
      expect(roundTripped.deliveredTo, ['u2', 'u3']);
      expect(roundTripped.readBy, ['u2']);
      expect(roundTripped.mentions.first.uid, 'u5');
      expect(roundTripped.serverTimestamp, now);
      expect(roundTripped.clientId, 'client-abc');
    });

    test('missing optional fields default to empty, not null/crash', () {
      final m = MessageModel(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.text,
        clientId: 'c1',
      );
      final json = m.toJson();
      expect(json['attachments'], isEmpty);
      expect(json['reactions'], isEmpty);
      expect(json.containsKey('reply_to'), false);
      expect(json.containsKey('forwarded_from'), false);
      expect(json.containsKey('edited_at'), false);

      final parsed = MessageModel.fromJson(json);
      expect(parsed.replyTo, isNull);
      expect(parsed.forwardedFrom, isNull);
      expect(parsed.attachments, isEmpty);
      expect(parsed.isDeletedFor('anyone'), false);
    });
  });

  group('MessageModel — legacy 6-field adapter (forward-compatible read)', () {
    test('parses an old-shape doc: text→body, timestamp→serverTimestamp, type',
        () {
      final ts = Timestamp.fromDate(DateTime(2026, 1, 1, 10, 30));
      final legacy = {
        'id': 'old1',
        'senderId': 'u9',
        'text': 'hello from before the migration',
        'type': 'text',
        'timestamp': ts,
        'isRead': false,
      };

      final m = MessageModel.fromJson(legacy);

      expect(m.body, 'hello from before the migration');
      expect(m.serverTimestamp, ts.toDate());
      expect(m.timestamp, ts.toDate());
      expect(m.type, MessageType.text);
      // No client_id ever existed on old docs — falls back to the doc id so
      // callers always have a stable, non-empty key to work with.
      expect(m.clientId, 'old1');
    });

    test('legacy image message: type parses; old text field held the raw URL',
        () {
      final legacy = {
        'id': 'old2',
        'senderId': 'u9',
        'text': 'https://example.com/legacy-image.jpg',
        'type': 'image',
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'isRead': true,
      };
      final m = MessageModel.fromJson(legacy);
      expect(m.type, MessageType.image);
      // Pre-migration docs stuffed the URL into `text`/`body` — the adapter
      // preserves that as-is (no attachments[] synthesis); §2.2's UI layer
      // is expected to special-case rendering old image messages this way.
      expect(m.body, 'https://example.com/legacy-image.jpg');
      expect(m.attachments, isEmpty);
    });

    test('isReadBy falls back to the legacy bool only when read_by is absent',
        () {
      final legacyRead = MessageModel.fromJson({
        'id': 'old3',
        'senderId': 'sender1',
        'text': 'hi',
        'type': 'text',
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'isRead': true,
      });
      // The other participant is treated as having read it...
      expect(legacyRead.isReadBy('other-uid'), true);
      // ...but the sender never "reads" their own message via this fallback.
      expect(legacyRead.isReadBy('sender1'), false);

      final legacyUnread = MessageModel.fromJson({
        'id': 'old4',
        'senderId': 'sender1',
        'text': 'hi',
        'type': 'text',
        'timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'isRead': false,
      });
      expect(legacyUnread.isReadBy('other-uid'), false);
    });

    test(
        'a new-format doc with an explicit empty read_by is NOT given the legacy fallback',
        () {
      // Regression guard: presence of the `read_by` KEY (even empty) must be
      // treated as "this is a v2 doc, trust it precisely" — never fall back
      // to a stale/irrelevant legacy `isRead` that might coexist on a
      // hand-migrated or test-seeded document.
      final m = MessageModel.fromJson({
        'id': 'new1',
        'senderId': 'sender1',
        'body': 'hi',
        'type': 'text',
        'server_timestamp': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'read_by': <String>[],
        'isRead': true, // should be ignored — read_by key is present
      });
      expect(m.isReadBy('other-uid'), false);
    });
  });

  group('MessageModel — deletion semantics', () {
    test(
        'is_deleted true hides the message for everyone, including non-listed uids',
        () {
      final m = MessageModel(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.text,
        clientId: 'c1',
        isDeleted: true,
      );
      expect(m.isDeletedFor('u1'), true);
      expect(m.isDeletedFor('anyone-else'), true);
    });

    test("deleted_for: 'everyone' hides for all without is_deleted set", () {
      final m = MessageModel(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.text,
        clientId: 'c1',
        deletedFor: 'everyone',
      );
      expect(m.isDeletedFor('anyone'), true);
    });

    test('deleted_for as a uid list only hides for those specific uids', () {
      final m = MessageModel(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.text,
        clientId: 'c1',
        deletedFor: const ['u2'],
      );
      expect(m.isDeletedFor('u2'), true);
      expect(m.isDeletedFor('u3'), false);
    });
  });

  group('MessageModel.copyWith', () {
    test(
        'updates only the given fields, leaves the rest and the original untouched',
        () {
      final original = MessageModel(
        id: 'm1',
        senderId: 'u1',
        type: MessageType.text,
        body: 'original',
        clientId: 'c1',
      );
      final edited =
          original.copyWith(body: 'edited', editedAt: DateTime(2026, 1, 1));

      expect(edited.body, 'edited');
      expect(edited.id, original.id);
      expect(edited.senderId, original.senderId);
      expect(original.body, 'original');
      expect(original.editedAt, isNull);
    });
  });
}
