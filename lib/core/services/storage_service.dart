import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
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

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      _userBox = await Hive.openBox(_userBoxName);
      _recipeBox = await Hive.openBox(_recipeBoxName);
      _mealPlanBox = await Hive.openBox(_mealPlanBoxName);
      _settingsBox = await Hive.openBox(_settingsBoxName);
      _shoppingBox = await Hive.openBox(_shoppingBoxName);
      _hydrationBox = await Hive.openBox(_hydrationBoxName);
      _weightBox = await Hive.openBox(_weightBoxName);

      _isInitialized = true;
      debugPrint('StorageService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing StorageService: $e');
      rethrow;
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
