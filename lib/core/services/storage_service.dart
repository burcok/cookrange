import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/recipe_model.dart';
import '../models/meal_plan_model.dart';
import '../models/ingredient_model.dart';
import 'dart:convert';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _userBoxName = 'user_box';
  static const String _recipeBoxName = 'recipes_box';
  static const String _mealPlanBoxName = 'meal_plans_box';
  static const String _settingsBoxName = 'settings_box';
  static const String _shoppingBoxName = 'shopping_box';
  static const String _hydrationBoxName = 'hydration_box';
  static const String _weightBoxName = 'weight_box';

  late Box _userBox;
  late Box _recipeBox;
  late Box _mealPlanBox;
  late Box _settingsBox;
  late Box _shoppingBox;
  late Box _hydrationBox;
  late Box _weightBox;

  bool _isInitialized = false;

  // AES-256 key for at-rest encryption of all local Hive boxes. The key itself
  // lives in the platform secure enclave (iOS Keychain / Android Keystore-backed
  // EncryptedSharedPreferences), never in a Hive box or SharedPreferences.
  static const String _encKeyName = 'hive_enc_key_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  List<String> get _allBoxNames => [
        _userBoxName,
        _recipeBoxName,
        _mealPlanBoxName,
        _settingsBoxName,
        _shoppingBoxName,
        _hydrationBoxName,
        _weightBoxName,
      ];

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // Obtain (or create) the at-rest encryption key. If the secure enclave is
      // unavailable we degrade to plaintext rather than bricking the app, but
      // this is logged so it surfaces in monitoring.
      final HiveAesCipher? cipher = await _resolveCipher();

      _userBox = await Hive.openBox(_userBoxName, encryptionCipher: cipher);
      _recipeBox = await Hive.openBox(_recipeBoxName, encryptionCipher: cipher);
      _mealPlanBox =
          await Hive.openBox(_mealPlanBoxName, encryptionCipher: cipher);
      _settingsBox =
          await Hive.openBox(_settingsBoxName, encryptionCipher: cipher);
      _shoppingBox =
          await Hive.openBox(_shoppingBoxName, encryptionCipher: cipher);
      _hydrationBox =
          await Hive.openBox(_hydrationBoxName, encryptionCipher: cipher);
      _weightBox = await Hive.openBox(_weightBoxName, encryptionCipher: cipher);

      _isInitialized = true;
      debugPrint('StorageService initialized (encrypted=${cipher != null})');
    } catch (e) {
      debugPrint('Error initializing StorageService: $e');
      rethrow;
    }
  }

  /// Returns the AES cipher for box encryption, creating the key on first run
  /// and migrating any pre-existing plaintext boxes to encrypted form. Returns
  /// null only if the secure key store is unavailable (fail-soft).
  Future<HiveAesCipher?> _resolveCipher() async {
    try {
      String? keyB64 = await _secureStorage.read(key: _encKeyName);
      if (keyB64 == null) {
        // First run with encryption enabled: mint a key, persist it, then
        // migrate any plaintext data written by older builds.
        final key = Hive.generateSecureKey();
        keyB64 = base64Encode(key);
        await _secureStorage.write(key: _encKeyName, value: keyB64);
        await _migratePlaintextBoxes(HiveAesCipher(key));
        return HiveAesCipher(key);
      }
      return HiveAesCipher(base64Decode(keyB64));
    } catch (e) {
      debugPrint('StorageService: secure key unavailable, '
          'falling back to plaintext boxes: $e');
      return null;
    }
  }

  /// One-time migration: reads each existing plaintext box, deletes it on disk,
  /// and rewrites it encrypted. Per-box best-effort so one failure can't strand
  /// the rest. Safe on fresh installs (no boxes exist → no-op).
  Future<void> _migratePlaintextBoxes(HiveAesCipher cipher) async {
    for (final name in _allBoxNames) {
      try {
        if (!await Hive.boxExists(name)) continue;
        final plain = await Hive.openBox(name); // plaintext
        final entries = <dynamic, dynamic>{
          for (final k in plain.keys) k: plain.get(k)
        };
        await plain.close();
        await Hive.deleteBoxFromDisk(name);
        final encrypted =
            await Hive.openBox(name, encryptionCipher: cipher);
        if (entries.isNotEmpty) await encrypted.putAll(entries);
        await encrypted.close();
        debugPrint('StorageService: migrated "$name" to encrypted '
            '(${entries.length} entries)');
      } catch (e) {
        debugPrint('StorageService: migration of "$name" failed: $e');
      }
    }
  }

  // --- Hydration ---

  Future<void> saveHydration(DateTime date, double amount) async {
    final String key = date.toIso8601String().split('T')[0];
    await _hydrationBox.put(key, amount);
  }

  double getHydration(DateTime date) {
    final String key = date.toIso8601String().split('T')[0];
    return _hydrationBox.get(key, defaultValue: 0.0) as double;
  }

  // --- Weight Tracking ---

  Future<void> saveWeight(DateTime date, double weight) async {
    final String key = date.toIso8601String().split('T')[0];
    await _weightBox.put(key, weight);
  }

  double? getWeight(DateTime date) {
    final String key = date.toIso8601String().split('T')[0];
    return _weightBox.get(key) as double?;
  }

  List<Map<String, dynamic>> getWeightHistory() {
    final List<Map<String, dynamic>> history = [];
    for (var key in _weightBox.keys) {
      history.add({
        'date': key.toString(),
        'weight': _weightBox.get(key) as double,
      });
    }
    history.sort((a, b) => b['date'].compareTo(a['date']));
    return history;
  }

  // --- User Data ---

  Future<void> saveUser(Map<String, dynamic> userJson) async {
    await _userBox.put('current_user', jsonEncode(userJson));
  }

  Map<String, dynamic>? getUser() {
    final String? data = _userBox.get('current_user');
    if (data == null) return null;
    return jsonDecode(data);
  }

  Future<void> clearUser() async {
    await _userBox.delete('current_user');
  }

  // --- Recipes ---

  Future<void> saveRecipe(Recipe recipe) async {
    await _recipeBox.put(recipe.id, jsonEncode(recipe.toJson()));
  }

  Future<void> saveRecipes(List<Recipe> recipes) async {
    final Map<String, String> data = {
      for (var r in recipes) r.id: jsonEncode(r.toJson())
    };
    await _recipeBox.putAll(data);
  }

  Recipe? getRecipe(String id) {
    final String? data = _recipeBox.get(id);
    if (data == null) return null;
    return Recipe.fromJson(jsonDecode(data));
  }

  List<Recipe> getAllRecipes() {
    return _recipeBox.values
        .map((e) => Recipe.fromJson(jsonDecode(e)))
        .toList();
  }

  // --- Meal Plans ---

  Future<void> saveMealPlan(MealPlan plan) async {
    // Key by date string YYYY-MM-DD
    final String key = plan.date.toIso8601String().split('T')[0];
    await _mealPlanBox.put(key, jsonEncode(plan.toJson()));
  }

  MealPlan? getMealPlan(DateTime date) {
    final String key = date.toIso8601String().split('T')[0];
    final String? data = _mealPlanBox.get(key);
    if (data == null) return null;
    return MealPlan.fromJson(jsonDecode(data));
  }

  // --- Settings ---

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue);
  }

  // --- Shopping List ---

  Future<void> addToShoppingList(Ingredient ingredient) async {
    // Check if exists to aggregate
    final existingRaw = _shoppingBox.get(ingredient.name);
    if (existingRaw != null) {
      final existing = Ingredient.fromJson(jsonDecode(existingRaw));
      final newAmount = existing.amount + ingredient.amount;
      final updated = existing.copyWith(amount: newAmount);
      await _shoppingBox.put(ingredient.name, jsonEncode(updated.toJson()));
    } else {
      await _shoppingBox.put(ingredient.name, jsonEncode(ingredient.toJson()));
    }
  }

  List<Ingredient> getShoppingList() {
    return _shoppingBox.values
        .map((e) => Ingredient.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> removeFromShoppingList(String name) async {
    await _shoppingBox.delete(name);
  }

  Future<void> clearShoppingList() async {
    await _shoppingBox.clear();
  }
}
