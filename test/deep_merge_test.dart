import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/utils/deep_merge.dart';

// Faz A Faz 1 — this is the fix for a design flaw caught before it shipped:
// AppConfigService merges app_config/global + client + critical, and three
// schema groups (ai, gamification, client) are genuinely split across more
// than one of those documents. A shallow `{...a, ...b}` spread would let a
// later, partial group object silently DISCARD every sibling sub-field an
// earlier source had. These tests pin the correct recursive behavior using
// a synthetic scenario shaped exactly like the real ai.* split (client doc
// has text_model/timeout_s; server doc has model_by_type/max_tokens).
void main() {
  group('deepMergeMaps', () {
    test('a later, PARTIAL nested map only overrides its own keys — the '
        'exact bug this exists to prevent', () {
      final earlier = {
        'ai': {'text_model': 'gpt-4o-mini', 'timeout_s': 90},
      };
      final later = {
        'ai': {'model_by_type': <String, String>{}, 'max_tokens': 8192},
      };
      final merged = deepMergeMaps([earlier, later]);
      expect(merged['ai'], {
        'text_model': 'gpt-4o-mini',
        'timeout_s': 90,
        'model_by_type': <String, String>{},
        'max_tokens': 8192,
      });
    });

    test('a later source\'s LEAF value overrides an earlier one for the '
        'SAME key', () {
      final earlier = {'maintenance': {'enabled': false}};
      final later = {'maintenance': {'enabled': true}};
      final merged = deepMergeMaps([earlier, later]);
      expect(merged['maintenance'], {'enabled': true});
    });

    test('a group entirely ABSENT from a later source is preserved from '
        'an earlier one (matches Faz 1: client/critical are empty today, '
        'so global must pass through untouched)', () {
      final global = {
        'ai': {'text_model': 'x'},
        'maintenance': {'enabled': false},
        'version': {'force_update': false},
      };
      const client = <String, dynamic>{};
      const critical = <String, dynamic>{};
      final merged = deepMergeMaps([global, client, critical]);
      expect(merged, global);
    });

    test('three-way merge — global < client < critical, matching '
        'AppConfigService\'s actual precedence order', () {
      final global = {
        'ai': {'text_model': 'old-model', 'timeout_s': 60},
        'features': {'gym': true},
      };
      final client = {
        'ai': {'text_model': 'new-model'}, // overrides global's text_model
      };
      final critical = {
        'features': {'gym': false}, // overrides global's features.gym
        'maintenance': {'enabled': true}, // new group, absent elsewhere
      };
      final merged = deepMergeMaps([global, client, critical]);
      expect(merged['ai'], {'text_model': 'new-model', 'timeout_s': 60});
      expect(merged['features'], {'gym': false});
      expect(merged['maintenance'], {'enabled': true});
    });

    test('non-object values (lists) are REPLACED wholesale, never '
        'merged element-wise', () {
      final earlier = {'ai': {'allowed_models': ['a', 'b']}};
      final later = {'ai': {'allowed_models': ['c']}};
      final merged = deepMergeMaps([earlier, later]);
      expect(merged['ai']['allowed_models'], ['c']);
    });

    test('a later scalar replaces an earlier nested map wholesale (type '
        'change is not itself an error at the merge layer)', () {
      final earlier = {'ai': {'text_model': 'x'}};
      final later = {'ai': 'not-a-map-anymore'};
      final merged = deepMergeMaps([earlier, later]);
      expect(merged['ai'], 'not-a-map-anymore');
    });

    test('empty input list returns an empty map', () {
      expect(deepMergeMaps([]), <String, dynamic>{});
    });

    test('a single map is returned equivalent to itself', () {
      final only = {'a': {'b': 1}};
      expect(deepMergeMaps([only]), only);
    });
  });
}
