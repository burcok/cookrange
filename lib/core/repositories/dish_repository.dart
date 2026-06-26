import '../models/dish_model.dart';
import '../services/dish_service.dart';
import '../services/test_mode_service.dart';
import '../data/test_data_library.dart';

/// Repository for dish data.
///
/// Maintains a singleton in-memory cache so repeated lookups within a
/// session avoid redundant Firestore reads. The cache survives widget
/// rebuilds and route transitions — unlike the old per-screen `_dishCache`.
///
/// In test mode all lookups are served from [TestDataLibrary.dishCache]
/// without any Firestore access.
class DishRepository {
  static final DishRepository _instance = DishRepository._internal();
  factory DishRepository() => _instance;
  DishRepository._internal();

  final DishService _service = DishService();
  final Map<String, DishModel> _cache = {};

  /// Returns a cached dish, or null if not yet loaded.
  DishModel? getCached(String id) => _cache[id];

  /// Fetches a dish by ID, caching the result.
  ///
  /// In test mode returns from [TestDataLibrary] (no Firestore call).
  Future<DishModel?> getDishById(String id) async {
    if (TestModeService().isActive) {
      return TestDataLibrary.dishCache()[id];
    }
    if (_cache.containsKey(id)) return _cache[id];
    final dish = await _service.getDishById(id);
    if (dish != null) _cache[id] = dish;
    return dish;
  }

  /// Pre-fetches a list of dish IDs, skipping already-cached ones.
  Future<void> prefetch(List<String> ids) async {
    if (TestModeService().isActive) {
      _cache.addAll(TestDataLibrary.dishCache());
      return;
    }
    final missing = ids.where((id) => !_cache.containsKey(id)).toList();
    for (final id in missing) {
      final dish = await _service.getDishById(id);
      if (dish != null) _cache[id] = dish;
    }
  }

  /// Bulk-loads an already-fetched map into the cache (e.g. from test data).
  void preload(Map<String, DishModel> dishes) => _cache.addAll(dishes);

  /// Returns all dishes for the given [mealType], using the in-memory cache
  /// when possible and falling back to Firestore otherwise.
  Future<List<DishModel>> getByMealType(String mealType) async {
    if (TestModeService().isActive) {
      return TestDataLibrary.dishCache()
          .values
          .where((d) => d.mealType == mealType)
          .toList();
    }
    // Try cache first — only hit Firestore if cache is empty
    final fromCache = _cache.values.where((d) => d.mealType == mealType).toList();
    if (fromCache.isNotEmpty) return fromCache;
    final all = await _service.getAllDishes();
    for (final d in all) {
      _cache[d.id] = d;
    }
    return _cache.values.where((d) => d.mealType == mealType).toList();
  }

  /// Returns a snapshot of all currently cached dishes.
  Map<String, DishModel> get snapshot => Map.unmodifiable(_cache);
}
