/// Maps the current hour to a meal-type key used throughout the app.
/// Returns a key consistent with FoodLogService meal types.
abstract class MealTimeUtil {
  MealTimeUtil._();

  /// Returns `'breakfast' | 'lunch' | 'snack' | 'dinner'` based on [hour].
  /// Falls back to `'snack'` for late-night / early-morning hours.
  static String mealTypeForHour(int hour) {
    if (hour >= 6 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 14) return 'lunch';
    if (hour >= 17 && hour < 22) return 'dinner';
    return 'snack';
  }
}
