import 'package:cookrange/core/services/push_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks the pure time-spreading logic behind the precise multi-time water
/// reminder (PushNotificationService.scheduleDailyWaterReminder). The actual
/// zonedSchedule call needs a device/tz database, but the math that decides
/// *when* reminders fire is pure and validated here.
void main() {
  group('PushNotificationService.spreadReminderTimes', () {
    // Every result must be a real wall-clock time with no duplicates.
    void assertValid(List<(int, int)> times) {
      final seen = <int>{};
      for (final (h, m) in times) {
        expect(h, inInclusiveRange(0, 23));
        expect(m, inInclusiveRange(0, 59));
        expect(seen.add(h * 60 + m), isTrue, reason: 'duplicate $h:$m');
      }
    }

    test('default 08:00–23:00 window → ~6 reminders, first at wake, none at bedtime',
        () {
      final times = PushNotificationService.spreadReminderTimes(
          '08:00', '23:00', null);
      assertValid(times);
      expect(times.length, 6);
      expect(times.first, (8, 0));
      // Evenly spaced 2.5h apart; last lands one segment before sleep.
      expect(times, [
        (8, 0),
        (10, 30),
        (13, 0),
        (15, 30),
        (18, 0),
        (20, 30),
      ]);
      // Never pings exactly at bedtime.
      expect(times.contains((23, 0)), isFalse);
      // Non-wrapping window is strictly increasing.
      final mins = times.map((t) => t.$1 * 60 + t.$2).toList();
      for (var i = 1; i < mins.length; i++) {
        expect(mins[i], greaterThan(mins[i - 1]));
      }
    });

    test('window crossing midnight (night shift 22:00–06:00) wraps correctly',
        () {
      final times = PushNotificationService.spreadReminderTimes(
          '22:00', '06:00', null);
      assertValid(times);
      expect(times.first, (22, 0));
      // At least one reminder lands after midnight (hour < wake hour).
      expect(times.any((t) => t.$1 < 22), isTrue);
    });

    test('reminder count is clamped to the reserved id block (max 12)', () {
      final times = PushNotificationService.spreadReminderTimes(
          '06:00', '23:30', 100);
      assertValid(times);
      expect(times.length, lessThanOrEqualTo(12));
      expect(times.length, 12);
    });

    test('count is clamped up to a minimum of 2 for a narrow window', () {
      final times = PushNotificationService.spreadReminderTimes(
          '08:00', '09:00', null);
      assertValid(times);
      expect(times.length, 2);
      expect(times.first, (8, 0));
    });

    test('malformed HH:mm strings fall back to the 08:00–23:00 default window',
        () {
      final times = PushNotificationService.spreadReminderTimes(
          'not-a-time', '??:??', null);
      assertValid(times);
      expect(times.length, 6);
      expect(times.first, (8, 0));
    });

    test('explicit count is honoured within bounds', () {
      final times = PushNotificationService.spreadReminderTimes(
          '08:00', '23:00', 4);
      assertValid(times);
      expect(times.length, 4);
      expect(times.first, (8, 0));
    });
  });
}
