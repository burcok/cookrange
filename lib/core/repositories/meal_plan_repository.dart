import '../models/user_model.dart';
import '../models/weekly_meal_plan_model.dart';
import '../services/weekly_meal_plan_service.dart';
import '../services/test_mode_service.dart';
import '../services/performance_service.dart';
import '../data/test_data_library.dart';

/// Repository for weekly meal plan data.
///
/// Single source of truth for meal plans — abstracts the real
/// [WeeklyMealPlanService] from test-mode interception. Screens and
/// providers always call this instead of the service directly.
class MealPlanRepository {
  static final MealPlanRepository _instance = MealPlanRepository._internal();
  factory MealPlanRepository() => _instance;
  MealPlanRepository._internal();

  final WeeklyMealPlanService _service = WeeklyMealPlanService();

  /// Returns the current weekly plan for [user].
  ///
  /// In test mode returns a fully-populated dummy plan without hitting
  /// Firestore. In production delegates to [WeeklyMealPlanService].
  Future<WeeklyMealPlanModel?> getWeeklyPlan(
    UserModel user, {
    bool forceRefresh = false,
  }) async {
    if (TestModeService().isActive) {
      return TestDataLibrary.weeklyPlan(user.uid);
    }
    return PerformanceService().trace(
      forceRefresh ? 'meal_plan_generate' : 'meal_plan_fetch',
      () => _service.getWeeklyMealPlan(user, forceRefresh: forceRefresh),
    );
  }

  /// Replaces a single meal slot with [newDishId].
  ///
  /// No-ops in test mode (test data is in-memory only).
  Future<WeeklyMealPlanModel?> swapMeal({
    required String userId,
    required DateTime dayDate,
    required String mealType,
    required String newDishId,
  }) async {
    if (TestModeService().isActive) return null;
    return _service.swapMeal(
      userId: userId,
      dayDate: dayDate,
      mealType: mealType,
      newDishId: newDishId,
    );
  }
}
