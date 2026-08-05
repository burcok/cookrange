import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/utils/xp_level_curve.dart';

void main() {
  group('XpLevelCurve.xpThresholdForLevel', () {
    test('level 1 requires 0 xp', () {
      expect(XpLevelCurve.xpThresholdForLevel(1), 0);
    });

    test('matches the triangular-number formula for several levels', () {
      expect(XpLevelCurve.xpThresholdForLevel(2), 100);
      expect(XpLevelCurve.xpThresholdForLevel(3), 300);
      expect(XpLevelCurve.xpThresholdForLevel(4), 600);
      expect(XpLevelCurve.xpThresholdForLevel(5), 1000);
      expect(XpLevelCurve.xpThresholdForLevel(10), 4500);
    });

    test('intervals strictly increase ("artan aralıklı")', () {
      int previousGap = -1;
      for (var level = 1; level < 30; level++) {
        final gap = XpLevelCurve.xpThresholdForLevel(level + 1) -
            XpLevelCurve.xpThresholdForLevel(level);
        expect(gap > previousGap, isTrue,
            reason: 'gap at level $level ($gap) should exceed the previous '
                'one ($previousGap)');
        previousGap = gap;
      }
    });

    test('level below 1 is clamped to level 1 (0 xp)', () {
      expect(XpLevelCurve.xpThresholdForLevel(0), 0);
      expect(XpLevelCurve.xpThresholdForLevel(-5), 0);
    });
  });

  group('XpLevelCurve.levelForXp', () {
    test('0 or negative xp is level 1', () {
      expect(XpLevelCurve.levelForXp(0), 1);
      expect(XpLevelCurve.levelForXp(-10), 1);
    });

    test('stays at the current level until exactly its threshold', () {
      expect(XpLevelCurve.levelForXp(99), 1);
      expect(XpLevelCurve.levelForXp(100), 2);
      expect(XpLevelCurve.levelForXp(299), 2);
      expect(XpLevelCurve.levelForXp(300), 3);
      expect(XpLevelCurve.levelForXp(599), 3);
      expect(XpLevelCurve.levelForXp(600), 4);
    });

    test('round-trips xpThresholdForLevel for many levels', () {
      for (var level = 1; level < 50; level++) {
        final threshold = XpLevelCurve.xpThresholdForLevel(level);
        expect(XpLevelCurve.levelForXp(threshold), level,
            reason: 'exactly at threshold($level)=$threshold');
        expect(XpLevelCurve.levelForXp(threshold - 1),
            level - 1 < 1 ? 1 : level - 1,
            reason: '1 xp short of threshold($level)=$threshold');
      }
    });
  });

  group('XpLevelCurve progress-bar helpers', () {
    test('xpIntoCurrentLevel is the remainder above the level floor', () {
      expect(XpLevelCurve.xpIntoCurrentLevel(150), 50); // level 2 floor=100
      expect(
          XpLevelCurve.xpIntoCurrentLevel(100), 0); // exactly level 2's floor
      expect(XpLevelCurve.xpIntoCurrentLevel(0), 0);
    });

    test('xpForNextLevel is the width of the current level band', () {
      expect(XpLevelCurve.xpForNextLevel(150), 200); // level 2: 300-100
      expect(XpLevelCurve.xpForNextLevel(0), 100); // level 1: 100-0
    });

    test('xpIntoCurrentLevel never exceeds xpForNextLevel', () {
      for (var xp = 0; xp < 5000; xp += 37) {
        expect(XpLevelCurve.xpIntoCurrentLevel(xp),
            lessThan(XpLevelCurve.xpForNextLevel(xp) + 1));
      }
    });
  });
}
