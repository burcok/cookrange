import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/weekly_meal_plan_model.dart';

/// Exports a WeeklyMealPlanModel as an iCalendar (.ics) file,
/// which can be imported into Apple Calendar, Google Calendar, or Outlook.
class MealPlanCalendarService {
  static final MealPlanCalendarService _instance =
      MealPlanCalendarService._internal();
  factory MealPlanCalendarService() => _instance;
  MealPlanCalendarService._internal();

  // Fixed meal slot times (local, 24h): start hour + minute, duration minutes
  static const Map<String, _MealTime> _mealTimes = {
    'breakfast': _MealTime(8, 0, 30),
    'lunch': _MealTime(12, 30, 45),
    'dinner': _MealTime(19, 0, 45),
    'snack': _MealTime(15, 30, 20),
  };

  static const Map<String, String> _mealEmoji = {
    'breakfast': '🌅',
    'lunch': '☀️',
    'dinner': '🌙',
    'snack': '🍎',
  };

  /// Generates and shares an .ics file for [plan].
  ///
  /// [dishNames] maps dishId → human-readable dish name; falls back to meal
  /// type capitalized when a dish name is unavailable.
  /// [mealTypeLabels] maps mealType → localized label (e.g. "Breakfast").
  Future<void> exportToCalendar({
    required WeeklyMealPlanModel plan,
    Map<String, String> dishNames = const {},
    Map<String, String> mealTypeLabels = const {},
  }) async {
    debugPrint('MealPlanCalendarService: generating .ics for plan ${plan.id}');

    final icsContent = _buildIcs(plan, dishNames, mealTypeLabels);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/cookrange_meal_plan.ics');
    await file.writeAsString(icsContent);

    debugPrint(
        'MealPlanCalendarService: wrote ${icsContent.length} chars → ${file.path}');

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/calendar')],
      subject: 'Cookrange Meal Plan',
    );
  }

  String _buildIcs(
    WeeklyMealPlanModel plan,
    Map<String, String> dishNames,
    Map<String, String> mealTypeLabels,
  ) {
    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//Cookrange//Meal Plan//EN');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');
    buf.writeln('X-WR-CALNAME:Cookrange Meal Plan');
    buf.writeln('X-WR-TIMEZONE:floating');

    for (final day in plan.days) {
      for (final entry in day.meals.entries) {
        final mealType = entry.key; // e.g. 'breakfast'
        final dishId = entry.value;
        final mealTime = _mealTimes[mealType];
        if (mealTime == null) continue;

        final dishName = dishNames[dishId] ?? '';
        final mealLabel = mealTypeLabels[mealType] ??
            '${mealType[0].toUpperCase()}${mealType.substring(1)}';
        final emoji = _mealEmoji[mealType] ?? '🍽️';

        final summary = dishName.isNotEmpty
            ? '$emoji $mealLabel: $dishName'
            : '$emoji $mealLabel';

        final start = DateTime(
          day.date.year,
          day.date.month,
          day.date.day,
          mealTime.hour,
          mealTime.minute,
        );
        final end = start.add(Duration(minutes: mealTime.durationMin));

        final uid = 'cookrange-${mealType.substring(0, 2)}-'
            '${_fmt(day.date.year)}${_fmt(day.date.month)}${_fmt(day.date.day)}'
            '@cookrange.app';

        String calStr(String dt) =>
            '${_fmt(dt.substring(0, 4))}${_fmt(dt.substring(5, 7))}'
            '${_fmt(dt.substring(8, 10))}T${_fmt(dt.substring(11, 13))}'
            '${_fmt(dt.substring(14, 16))}00';

        final startStr = start.toIso8601String().substring(0, 16);
        final endStr = end.toIso8601String().substring(0, 16);

        buf.writeln('BEGIN:VEVENT');
        buf.writeln('UID:$uid');
        buf.writeln('DTSTART:${calStr(startStr)}');
        buf.writeln('DTEND:${calStr(endStr)}');
        buf.writeln('SUMMARY:${_escapeCal(summary)}');
        if (day.totalCalories > 0) {
          final cal = day.totalCalories.toInt();
          buf.writeln('DESCRIPTION:~$cal kcal/day');
        }
        buf.writeln('END:VEVENT');
      }
    }

    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  String _fmt(dynamic v) {
    final s = v.toString();
    return s.padLeft(2, '0');
  }

  String _escapeCal(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll(',', '\\,').replaceAll('\n', '\\n');
}

class _MealTime {
  final int hour;
  final int minute;
  final int durationMin;
  const _MealTime(this.hour, this.minute, this.durationMin);
}
