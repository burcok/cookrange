import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/utils/stable_hash.dart';

// Faz A §A3 — a shared vector table, asserted here AND in
// functions/test/stable_hash.test.js against the SAME expected outputs.
// That duplication is the point: it is what proves the Dart and Node
// implementations agree, which is the entire reason this hash replaced
// String.hashCode (a Cloud Function must reproduce the same rollout
// bucket a client computed). The first three vectors are the well-known
// public FNV-1a-32 reference vectors (independent confirmation this is a
// textbook-correct implementation, not just internally self-consistent);
// the rest are realistic `"$feature:$uid"`-shaped inputs mirroring
// AppConfigService.isInRollout's actual usage, plus edge cases (empty
// string, non-ASCII/Turkish text, long input, short numeric-looking
// strings that could collide if truncation were wrong).
void main() {
  final vectors = <String, int>{
    '': 2166136261,
    'a': 3826002220,
    'foobar': 3214735720,
    'gym:abc123': 2999454414,
    'coach:xyz789': 1718838574,
    'squad:uid_0001': 3313215373,
    'programs:': 1538371286,
    ':uid': 1822523445,
    'gym_invite_codes:9f8e7d6c5b4a3210': 3511076557,
    'a' * 100: 168538585,
    'Türkçe karakterler: çğıöşü': 3039875672,
    '0': 890022063,
    '00': 569209421,
    'meal_plan_templates:uidWithMixedCASE123': 820354505,
    'gym_attribution:uid-with-dashes-999': 152514592,
  };

  group('fnv1a32 — shared vector table (cross-checked against functions/test/stable_hash.test.js)', () {
    vectors.forEach((input, expected) {
      final label = input.length > 24 ? '${input.substring(0, 24)}…' : input;
      test('"$label" (len ${input.length}) -> $expected', () {
        expect(fnv1a32(input), expected);
      });
    });
  });

  group('fnv1a32 — properties', () {
    test('always returns a value in the unsigned 32-bit range', () {
      for (final input in vectors.keys) {
        final h = fnv1a32(input);
        expect(h, greaterThanOrEqualTo(0));
        expect(h, lessThanOrEqualTo(0xFFFFFFFF));
      }
    });

    test('is deterministic across repeated calls', () {
      const input = 'gym:repeat-me';
      final first = fnv1a32(input);
      for (var i = 0; i < 5; i++) {
        expect(fnv1a32(input), first);
      }
    });

    test('different inputs produce different hashes (no trivial collision '
        'among these vectors)', () {
      final hashes = vectors.values.toSet();
      expect(hashes.length, vectors.length);
    });
  });
}
