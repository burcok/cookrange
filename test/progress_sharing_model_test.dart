import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/progress_sharing_model.dart';

void main() {
  group('ProgressSharingScope', () {
    test('parses a well-formed gym scopeId', () {
      final scope = ProgressSharingScope.tryParse('gym_abc123');
      expect(scope, isNotNull);
      expect(scope!.type, ProgressSharingScopeType.gym);
      expect(scope.ownerId, 'abc123');
    });

    test('parses a well-formed coach scopeId', () {
      final scope = ProgressSharingScope.tryParse('coach_xyz789');
      expect(scope, isNotNull);
      expect(scope!.type, ProgressSharingScopeType.coach);
      expect(scope.ownerId, 'xyz789');
    });

    test('rejects an unknown prefix', () {
      expect(ProgressSharingScope.tryParse('squad_abc'), isNull);
    });

    test('rejects a bare prefix with no owner id', () {
      expect(ProgressSharingScope.tryParse('gym_'), isNull);
      expect(ProgressSharingScope.tryParse('coach_'), isNull);
    });

    test('rejects an empty string', () {
      expect(ProgressSharingScope.tryParse(''), isNull);
    });

    test('gym()/coach() factories round-trip through scopeId', () {
      expect(ProgressSharingScope.gym('g1').scopeId, 'gym_g1');
      expect(ProgressSharingScope.coach('c1').scopeId, 'coach_c1');
      expect(
          ProgressSharingScope.tryParse(ProgressSharingScope.gym('g1').scopeId),
          ProgressSharingScope.gym('g1'));
    });

    test('equality is structural, not identity', () {
      expect(ProgressSharingScope.gym('g1'), ProgressSharingScope.gym('g1'));
      expect(ProgressSharingScope.gym('g1') == ProgressSharingScope.coach('g1'),
          isFalse);
    });
  });

  group('ProgressSharingTier', () {
    test('fromLevel maps 0-3 exactly', () {
      expect(ProgressSharingTier.fromLevel(0), ProgressSharingTier.none);
      expect(ProgressSharingTier.fromLevel(1), ProgressSharingTier.attendance);
      expect(ProgressSharingTier.fromLevel(2), ProgressSharingTier.adherence);
      expect(ProgressSharingTier.fromLevel(3), ProgressSharingTier.weightTrend);
    });

    test('fromLevel fails closed for anything out of range or absent', () {
      expect(ProgressSharingTier.fromLevel(null), ProgressSharingTier.none);
      expect(ProgressSharingTier.fromLevel(4), ProgressSharingTier.none);
      expect(ProgressSharingTier.fromLevel(-1), ProgressSharingTier.none);
    });

    test('level is the enum index (the wire value)', () {
      expect(ProgressSharingTier.none.level, 0);
      expect(ProgressSharingTier.attendance.level, 1);
      expect(ProgressSharingTier.adherence.level, 2);
      expect(ProgressSharingTier.weightTrend.level, 3);
    });

    test('includesAdherence/includesWeightTrend gate correctly by tier', () {
      expect(ProgressSharingTier.none.includesAdherence, isFalse);
      expect(ProgressSharingTier.attendance.includesAdherence, isFalse);
      expect(ProgressSharingTier.adherence.includesAdherence, isTrue);
      expect(ProgressSharingTier.weightTrend.includesAdherence, isTrue);

      expect(ProgressSharingTier.adherence.includesWeightTrend, isFalse);
      expect(ProgressSharingTier.weightTrend.includesWeightTrend, isTrue);
    });
  });

  group('ProgressSharingModel', () {
    final scope = ProgressSharingScope.gym('g1');

    test('unset() defaults to tier none with no version/timestamps', () {
      final m = ProgressSharingModel.unset(scope);
      expect(m.tier, ProgressSharingTier.none);
      expect(m.isUnset, isTrue);
      expect(m.isShared, isFalse);
      expect(m.grantedAt, isNull);
      expect(m.revokedAt, isNull);
    });

    test('fromFirestore parses a granted tier 2 doc', () {
      final grantedAt = Timestamp.fromDate(DateTime(2026, 1, 1));
      final m = ProgressSharingModel.fromFirestore(scope, {
        'level': 2,
        'policy_version': '2026-06-29',
        'granted_at': grantedAt,
        'revoked_at': null,
      });
      expect(m.tier, ProgressSharingTier.adherence);
      expect(m.policyVersion, '2026-06-29');
      expect(m.grantedAt, grantedAt.toDate());
      expect(m.revokedAt, isNull);
      expect(m.isShared, isTrue);
      expect(m.isUnset, isFalse);
    });

    test('fromFirestore parses a revoked doc (level 0, revoked_at set)', () {
      final revokedAt = Timestamp.fromDate(DateTime(2026, 2, 1));
      final m = ProgressSharingModel.fromFirestore(scope, {
        'level': 0,
        'policy_version': '2026-06-29',
        'granted_at': Timestamp.fromDate(DateTime(2026, 1, 1)),
        'revoked_at': revokedAt,
      });
      expect(m.tier, ProgressSharingTier.none);
      expect(m.isShared, isFalse);
      expect(m.revokedAt, revokedAt.toDate());
      // granted_at history survives a revoke (not nulled) — see
      // ProgressSharingService.revoke's doc comment.
      expect(m.grantedAt, isNotNull);
    });

    test('fromFirestore defaults missing fields safely', () {
      final m = ProgressSharingModel.fromFirestore(scope, {});
      expect(m.tier, ProgressSharingTier.none);
      expect(m.policyVersion, '');
      expect(m.grantedAt, isNull);
    });
  });

  group('MemberProgressSummaryResult', () {
    test('parses a full AI-method response', () {
      final r = MemberProgressSummaryResult.fromCallable({
        'tier': 2,
        'method': 'ai',
        'narrative': 'Great progress this month.',
        'fields': {
          'check_in_frequency_per_week': 3.5,
          'logging_regularity_pct': 80.0,
        },
      });
      expect(r.tier, ProgressSharingTier.adherence);
      expect(r.method, 'ai');
      expect(r.narrative, 'Great progress this month.');
      expect(r.fields['logging_regularity_pct'], 80.0);
    });

    test('defaults missing fields to safe values (template/empty)', () {
      final r = MemberProgressSummaryResult.fromCallable(const {});
      expect(r.tier, ProgressSharingTier.none);
      expect(r.method, 'template');
      expect(r.narrative, '');
      expect(r.fields, isEmpty);
    });

    // A Cloud Functions HTTPS callable response does NOT auto-deserialize a
    // Firestore Timestamp the way a direct snapshot read does — it typically
    // arrives as admin.firestore.Timestamp's own toJSON() shape
    // ({_seconds, _nanoseconds}). These four cases are every shape
    // last_visit_at/last_logged_at can realistically arrive in; the UI
    // layer must never import cloud_firestore to work around this itself
    // (R5.1), so the model normalizes it here.
    group('date-field normalization (last_visit_at/last_logged_at)', () {
      test('normalizes the {_seconds, _nanoseconds} callable wire shape', () {
        final r = MemberProgressSummaryResult.fromCallable({
          'tier': 1,
          'fields': {
            'last_logged_at': {'_seconds': 1735689600, '_nanoseconds': 0},
          },
        });
        final v = r.fields['last_logged_at'];
        expect(v, isA<DateTime>());
        expect((v as DateTime).millisecondsSinceEpoch, 1735689600 * 1000);
      });

      test('normalizes a real Timestamp (belt-and-suspenders)', () {
        final ts = Timestamp.fromDate(DateTime.utc(2026, 1, 1));
        final r = MemberProgressSummaryResult.fromCallable({
          'tier': 1,
          'fields': {'last_visit_at': ts},
        });
        expect(r.fields['last_visit_at'], ts.toDate());
      });

      test('normalizes an ISO-8601 string', () {
        final r = MemberProgressSummaryResult.fromCallable({
          'tier': 1,
          'fields': {'last_logged_at': '2026-03-15T00:00:00.000Z'},
        });
        expect(r.fields['last_logged_at'],
            DateTime.parse('2026-03-15T00:00:00.000Z'));
      });

      test('a null date field stays null, not a crash', () {
        final r = MemberProgressSummaryResult.fromCallable({
          'tier': 1,
          'fields': {'last_logged_at': null},
        });
        expect(r.fields['last_logged_at'], isNull);
      });

      test(
          'non-date fields (percentages, insufficient_data) pass through untouched',
          () {
        final r = MemberProgressSummaryResult.fromCallable({
          'tier': 3,
          'fields': {
            'streak_days': 12,
            'plan_adherence_pct': 'insufficient_data',
            'weight_trend': 'insufficient_data',
          },
        });
        expect(r.fields['streak_days'], 12);
        expect(r.fields['plan_adherence_pct'], 'insufficient_data');
        expect(r.fields['weight_trend'], 'insufficient_data');
      });
    });

    test(
        'fromCachedDoc parses generated_at as a Timestamp (real Firestore read)',
        () {
      final generatedAt = Timestamp.fromDate(DateTime.utc(2026, 5, 1));
      final r = MemberProgressSummaryResult.fromCachedDoc({
        'tier': 1,
        'method': 'template',
        'narrative': 'x',
        'fields': {'streak_days': 5},
        'generated_at': generatedAt,
      });
      expect(r.generatedAt, generatedAt.toDate());
      expect(r.fields['streak_days'], 5);
    });

    test(
        'fromCallable never sets generatedAt (the callable response has no such field)',
        () {
      final r =
          MemberProgressSummaryResult.fromCallable({'tier': 1, 'fields': {}});
      expect(r.generatedAt, isNull);
    });
  });

  group('ProgressShareInviteResult', () {
    test('sent:true maps to the sent outcome, which isDone', () {
      final r = ProgressShareInviteResult.fromCallable({'sent': true});
      expect(r.outcome, ProgressShareInviteOutcome.sent);
      expect(r.isDone, isTrue);
    });

    test(
        "sent:false + reason 'already_invited' still isDone (button stays disabled)",
        () {
      final r = ProgressShareInviteResult.fromCallable(
          {'sent': false, 'reason': 'already_invited'});
      expect(r.outcome, ProgressShareInviteOutcome.alreadyInvited);
      expect(r.isDone, isTrue);
    });

    test(
        "sent:false + reason 'already_shared' is NOT isDone (re-check for a real report)",
        () {
      final r = ProgressShareInviteResult.fromCallable(
          {'sent': false, 'reason': 'already_shared'});
      expect(r.outcome, ProgressShareInviteOutcome.alreadyShared);
      expect(r.isDone, isFalse);
    });
  });
}
