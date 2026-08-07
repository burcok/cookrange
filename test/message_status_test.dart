import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/message_model.dart';
import 'package:cookrange/core/utils/message_status.dart';

const _me = 'me';
const _other = 'other';
const _third = 'third';

MessageModel _msg({
  DateTime? serverTimestamp,
  bool hasPendingWrites = false,
  bool sendFailed = false,
  List<String> deliveredTo = const [],
  List<String> readBy = const [],
}) {
  return MessageModel(
    id: 'm1',
    senderId: _me,
    type: MessageType.text,
    body: 'hi',
    clientId: 'm1',
    serverTimestamp: serverTimestamp,
    hasPendingWrites: hasPendingWrites,
    sendFailed: sendFailed,
    deliveredTo: deliveredTo,
    readBy: readBy,
  );
}

void main() {
  group('MessageStatusResolver.resolve', () {
    test('a failed send is always failed, regardless of any other flag', () {
      final result = MessageStatusResolver.resolve(
        message: _msg(sendFailed: true, readBy: [_other]),
        otherParticipantIds: [_other],
        isCommunityGroupChat: false,
      );
      expect(result, MessageSendState.failed);
    });

    test('a pending write (hasPendingWrites) is sending', () {
      final result = MessageStatusResolver.resolve(
        message: _msg(hasPendingWrites: true),
        otherParticipantIds: [_other],
        isCommunityGroupChat: false,
      );
      expect(result, MessageSendState.sending);
    });

    test('a null server_timestamp is sending even without hasPendingWrites',
        () {
      final result = MessageStatusResolver.resolve(
        message: _msg(serverTimestamp: null),
        otherParticipantIds: [_other],
        isCommunityGroupChat: false,
      );
      expect(result, MessageSendState.sending);
    });

    test('acked, no receipts yet, is sent', () {
      final result = MessageStatusResolver.resolve(
        message: _msg(serverTimestamp: DateTime(2026, 1, 1)),
        otherParticipantIds: [_other],
        isCommunityGroupChat: false,
      );
      expect(result, MessageSendState.sent);
    });

    test('delivered to the other participant is delivered', () {
      final result = MessageStatusResolver.resolve(
        message: _msg(
          serverTimestamp: DateTime(2026, 1, 1),
          deliveredTo: [_other],
        ),
        otherParticipantIds: [_other],
        isCommunityGroupChat: false,
      );
      expect(result, MessageSendState.delivered);
    });

    test('read by the other participant is read (private chat)', () {
      final result = MessageStatusResolver.resolve(
        message: _msg(
          serverTimestamp: DateTime(2026, 1, 1),
          deliveredTo: [_other],
          readBy: [_other],
        ),
        otherParticipantIds: [_other],
        isCommunityGroupChat: false,
      );
      expect(result, MessageSendState.read);
    });

    test(
        'a chat with no other participants (empty state) is sent, never '
        'read/delivered', () {
      final result = MessageStatusResolver.resolve(
        message: _msg(serverTimestamp: DateTime(2026, 1, 1)),
        otherParticipantIds: const [],
        isCommunityGroupChat: false,
      );
      expect(result, MessageSendState.sent);
    });

    group('ad-hoc multi-party group (no community group id)', () {
      test('requires EVERY other participant to have read it', () {
        final onlyOneRead = MessageStatusResolver.resolve(
          message: _msg(
            serverTimestamp: DateTime(2026, 1, 1),
            readBy: [_other],
          ),
          otherParticipantIds: [_other, _third],
          isCommunityGroupChat: false,
        );
        expect(onlyOneRead, MessageSendState.sent);

        final everyoneRead = MessageStatusResolver.resolve(
          message: _msg(
            serverTimestamp: DateTime(2026, 1, 1),
            readBy: [_other, _third],
          ),
          otherParticipantIds: [_other, _third],
          isCommunityGroupChat: false,
        );
        expect(everyoneRead, MessageSendState.read);
      });
    });

    group('community-group-backed chat (participants array is owner-only)', () {
      test(
          'read by ANY other real member counts as read — "every" would '
          'never fire since `participants` never lists them', () {
        final result = MessageStatusResolver.resolve(
          message: _msg(
            serverTimestamp: DateTime(2026, 1, 1),
            readBy: [_other],
          ),
          otherParticipantIds: [_other, _third],
          isCommunityGroupChat: true,
        );
        expect(result, MessageSendState.read);
      });
    });
  });
}
