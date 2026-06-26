import '../models/dish_model.dart';
import '../models/food_log_model.dart';
import '../models/recipe_model.dart';
import '../services/food_log_service.dart';
import '../services/test_mode_service.dart';
import '../data/test_data_library.dart';

/// Repository for food log data.
///
/// Provides a real-time stream of today's logs and write operations.
/// In test mode, the stream emits a fixed set of high-volume dummy logs
/// without touching Firestore — this makes test mode work instantly
/// without any network dependency.
class FoodLogRepository {
  static final FoodLogRepository _instance = FoodLogRepository._internal();
  factory FoodLogRepository() => _instance;
  FoodLogRepository._internal();

  final FoodLogService _service = FoodLogService();

  /// Real-time stream of today's food logs.
  ///
  /// In test mode returns a single-event stream with dummy data.
  Stream<List<FoodLog>> todayLogsStream(String uid) {
    if (TestModeService().isActive) {
      return Stream.value(TestDataLibrary.todayFoodLogs(uid));
    }
    return _service.todayLogsStream(uid);
  }

  /// Log a dish from the meal plan.
  ///
  /// No-op in test mode (avoids writing dummy data to Firestore).
  Future<void> logMeal({
    required String userId,
    required String mealType,
    required DishModel dish,
  }) {
    if (TestModeService().isActive) return Future.value();
    return _service.logMeal(userId: userId, mealType: mealType, dish: dish);
  }

  /// Log a cooked recipe as a meal entry.
  ///
  /// No-op in test mode.
  Future<void> logRecipe({
    required String userId,
    required String mealType,
    required Recipe recipe,
  }) {
    if (TestModeService().isActive) return Future.value();
    return _service.logRecipe(userId: userId, mealType: mealType, recipe: recipe);
  }

  /// Remove a previously logged meal entry.
  Future<void> removeLog(String userId, String logId) {
    if (TestModeService().isActive) return Future.value();
    return _service.removeLog(userId, logId);
  }

  /// Returns logs for each of the last 7 days, keyed by `YYYY-MM-DD`.
  ///
  /// In test mode returns synthetic data so the analytics screen works offline.
  Future<Map<String, List<FoodLog>>> getWeeklyLogs(String userId) async {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 6));
    if (TestModeService().isActive) {
      return TestDataLibrary.weeklyFoodLogs(userId, start, end);
    }
    return _service.getLogsForDateRange(userId, start, end);
  }
}
