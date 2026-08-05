import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/gym_invite_code_model.dart';

// `fromFirestore` itself (like GymModel's/GymQrToken's) takes a
// DocumentSnapshot and isn't unit-tested here — same ADR-004 limitation as
// those sibling models (no fake/mock Firestore snapshot type in this repo's
// dev dependencies). What's covered below is the pure logic that has no
// excuse not to be: the display-label fallback a gym owner's management list
// actually relies on to tell codes apart.
GymInviteCodeModel _invite({
  String? campaign,
  String? locationNote,
  DateTime? printedAt,
}) =>
    GymInviteCodeModel(
      code: 'AB3X9K',
      gymId: 'g1',
      ownerUid: 'owner1',
      campaign: campaign,
      locationNote: locationNote,
      printedAt: printedAt,
      createdAt: DateTime(2026, 1, 1),
      maxUses: 5000,
      usedCount: 3,
    );

void main() {
  group('GymInviteCodeModel.displayLabel', () {
    test('campaign + location_note both present are joined', () {
      final invite =
          _invite(campaign: 'Front desk', locationNote: 'Kadıköy şube');
      expect(invite.displayLabel(), 'Front desk · Kadıköy şube');
    });

    test('only campaign present', () {
      final invite = _invite(campaign: 'March campaign');
      expect(invite.displayLabel(), 'March campaign');
    });

    test('only location_note present', () {
      final invite = _invite(locationNote: 'Cardio floor');
      expect(invite.displayLabel(), 'Cardio floor');
    });

    test('neither present falls back to the raw code, not a blank row', () {
      final invite = _invite();
      expect(invite.displayLabel(), 'AB3X9K');
    });

    test('blank/whitespace-only strings are treated as absent, same as null',
        () {
      final invite = _invite(campaign: '   ', locationNote: '');
      expect(invite.displayLabel(), 'AB3X9K');
    });

    test('surrounding whitespace on a real value is trimmed', () {
      final invite = _invite(campaign: '  Front desk  ');
      expect(invite.displayLabel(), 'Front desk');
    });
  });

  group('GymInviteCodeModel — other pure getters', () {
    test('inviteUrl matches the link format SharingService.shareReferral uses',
        () {
      final invite = _invite();
      expect(invite.inviteUrl, 'https://cookrangeapp.com/invite/AB3X9K');
    });

    test('isPrinted reflects whether printed_at has been set', () {
      expect(_invite().isPrinted, isFalse);
      expect(_invite(printedAt: DateTime(2026, 2, 1)).isPrinted, isTrue);
    });
  });
}
