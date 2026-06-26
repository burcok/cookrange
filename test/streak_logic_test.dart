import 'package:flutter_test/flutter_test.dart';

/// Pure implementation of the streak calculation that mirrors
/// FirestoreService.updateUserLoginData — kept here so tests don't
/// require a live Firebase connection.
int computeNextStreak({
  required DateTime lastLogin,
  required DateTime now,
  required int currentStreak,
}) {
  final lastMidnight =
      DateTime(lastLogin.year, lastLogin.month, lastLogin.day);
  final todayMidnight = DateTime(now.year, now.month, now.day);
  final diff = todayMidnight.difference(lastMidnight).inDays;

  if (diff == 1) return currentStreak + 1;
  if (diff > 1) return 1;
  return currentStreak; // same-day login
}

void main() {
  group('Streak calculation', () {
    final base = DateTime(2024, 6, 15, 10, 0);

    test('consecutive day increments streak', () {
      final lastLogin = DateTime(2024, 6, 14, 22, 30);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 5,
      );
      expect(streak, equals(6));
    });

    test('same day login does NOT change streak', () {
      final lastLogin = DateTime(2024, 6, 15, 8, 0);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 5,
      );
      expect(streak, equals(5));
    });

    test('missing one day resets streak to 1', () {
      final lastLogin = DateTime(2024, 6, 13, 10, 0);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 7,
      );
      expect(streak, equals(1));
    });

    test('missing many days resets streak to 1', () {
      final lastLogin = DateTime(2024, 1, 1, 10, 0);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 30,
      );
      expect(streak, equals(1));
    });

    test('streak starts at 1 for first ever login (currentStreak = 0)', () {
      // FirestoreService reads streak as ?? 1, but if it were 0:
      final lastLogin = DateTime(2024, 6, 14, 10, 0);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 0,
      );
      expect(streak, equals(1));
    });

    test('midnight boundary: login at 23:59 previous day is consecutive', () {
      final lastLogin = DateTime(2024, 6, 14, 23, 59, 59);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 3,
      );
      expect(streak, equals(4));
    });

    test('midnight boundary: login at 00:01 today is same-day', () {
      final lastLogin = DateTime(2024, 6, 15, 0, 1);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 3,
      );
      expect(streak, equals(3));
    });

    test('streak never goes negative', () {
      final lastLogin = DateTime(2024, 6, 13, 10, 0);
      final streak = computeNextStreak(
        lastLogin: lastLogin,
        now: base,
        currentStreak: 1,
      );
      expect(streak, greaterThanOrEqualTo(1));
    });
  });
}
