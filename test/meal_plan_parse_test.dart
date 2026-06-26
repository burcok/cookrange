import 'package:flutter_test/flutter_test.dart';

/// Data class mirroring DayMealPlan fields used during AI-response parse.
class ParsedDay {
  final DateTime date;
  final String dayName;
  final Map<String, String> meals;
  final double totalCalories;
  final Map<String, double> macros;

  ParsedDay({
    required this.date,
    required this.dayName,
    required this.meals,
    required this.totalCalories,
    required this.macros,
  });
}

/// Pure extraction of the AI-response → DayMealPlan parse logic from
/// WeeklyMealPlanService._generateWeeklyPlan (lines ~97-128).
/// Keeping it pure here lets us verify it without Firebase/HTTP.
List<ParsedDay> parseDays(Map<String, dynamic> jsonResponse, DateTime weekStart) {
  final rawDays = jsonResponse['days'];
  if (rawDays is! List || rawDays.isEmpty) return [];

  final result = <ParsedDay>[];
  for (final d in rawDays) {
    if (d is! Map<String, dynamic>) continue;
    try {
      final offset = (d['date_offset'] as num?)?.toInt() ?? 0;
      final rawMeals = d['meals'];
      final meals = rawMeals is Map
          ? Map<String, String>.from(
              rawMeals.map((k, v) => MapEntry(k.toString(), v.toString())))
          : <String, String>{};
      final rawMacros = d['macros'];
      final macros = rawMacros is Map
          ? rawMacros.map(
              (k, v) => MapEntry(k.toString(), (v as num? ?? 0).toDouble()))
          : <String, double>{};
      result.add(ParsedDay(
        date: weekStart.add(Duration(days: offset)),
        dayName: d['day_name']?.toString() ?? '',
        meals: meals,
        totalCalories: (d['total_calories'] as num? ?? 0).toDouble(),
        macros: macros,
      ));
    } catch (_) {
      // skip malformed
    }
  }
  return result;
}

void main() {
  final weekStart = DateTime(2024, 6, 10); // Monday

  group('WeeklyMealPlan AI-response parsing', () {
    test('parses a valid 7-day response', () {
      final json = {
        'days': List.generate(7, (i) => {
          'date_offset': i,
          'day_name': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][i],
          'meals': {
            'breakfast': 'dish_$i',
            'lunch': 'dish_${i + 10}',
            'dinner': 'dish_${i + 20}',
          },
          'total_calories': 1800 + i * 50.0,
          'macros': {
            'protein': 120.0 + i,
            'carbs': 200.0 + i,
            'fat': 60.0 + i,
          },
        }),
        'total_calories': 12600.0,
        'avg_daily_calories': 1800.0,
      };

      final days = parseDays(json, weekStart);
      expect(days.length, equals(7));
      expect(days.first.dayName, equals('Mon'));
      expect(days.first.meals['breakfast'], equals('dish_0'));
      expect(days.last.dayName, equals('Sun'));
      expect(days.last.totalCalories, closeTo(1800 + 6 * 50.0, 0.01));
    });

    test('date_offset correctly offsets from week start', () {
      final json = {
        'days': [
          {'date_offset': 0, 'day_name': 'Mon', 'meals': {}, 'total_calories': 1800, 'macros': {}},
          {'date_offset': 3, 'day_name': 'Thu', 'meals': {}, 'total_calories': 1900, 'macros': {}},
        ],
      };

      final days = parseDays(json, weekStart);
      expect(days[0].date, equals(weekStart));
      expect(days[1].date, equals(weekStart.add(const Duration(days: 3))));
    });

    test('returns empty list when days is missing', () {
      final days = parseDays({}, weekStart);
      expect(days, isEmpty);
    });

    test('returns empty list when days is empty array', () {
      final days = parseDays({'days': []}, weekStart);
      expect(days, isEmpty);
    });

    test('returns empty list when days is not a list', () {
      final days = parseDays({'days': 'invalid'}, weekStart);
      expect(days, isEmpty);
    });

    test('skips malformed days but returns valid ones', () {
      final json = {
        'days': [
          // valid
          {
            'date_offset': 0,
            'day_name': 'Mon',
            'meals': {'breakfast': 'dish_1'},
            'total_calories': 1800,
            'macros': {'protein': 100.0},
          },
          // malformed: meals is not a map (int instead of map — causes type error on cast)
          null, // null entry → not Map<String,dynamic>, skipped
          // valid
          {
            'date_offset': 2,
            'day_name': 'Wed',
            'meals': {'lunch': 'dish_2'},
            'total_calories': 1900,
            'macros': {},
          },
        ],
      };

      final days = parseDays(json, weekStart);
      expect(days.length, equals(2));
      expect(days[0].dayName, equals('Mon'));
      expect(days[1].dayName, equals('Wed'));
    });

    test('handles missing optional fields with safe defaults', () {
      final json = {
        'days': [
          <String, dynamic>{}, // completely empty
        ],
      };

      final days = parseDays(json, weekStart);
      expect(days.length, equals(1));
      expect(days.first.dayName, equals(''));
      expect(days.first.meals, isEmpty);
      expect(days.first.totalCalories, equals(0));
      expect(days.first.macros, isEmpty);
    });

    test('macros parsed as doubles from int values', () {
      final json = {
        'days': [
          {
            'date_offset': 0,
            'day_name': 'Mon',
            'meals': {},
            'total_calories': 2000,
            'macros': {'protein': 150, 'carbs': 200, 'fat': 67},
          },
        ],
      };

      final days = parseDays(json, weekStart);
      expect(days.first.macros['protein'], isA<double>());
      expect(days.first.macros['protein'], closeTo(150.0, 0.01));
      expect(days.first.macros['fat'], closeTo(67.0, 0.01));
    });
  });
}
