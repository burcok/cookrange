import '../models/ingredient_model.dart';
import '../services/storage_service.dart';
import '../services/test_mode_service.dart';
import '../data/test_data_library.dart';

class ShoppingRepository {
  static final ShoppingRepository _instance = ShoppingRepository._internal();
  factory ShoppingRepository() => _instance;
  ShoppingRepository._internal();

  final StorageService _storage = StorageService();

  List<Ingredient> getList() {
    if (TestModeService().isActive) return TestDataLibrary.shoppingList();
    return _storage.getShoppingList();
  }

  Future<void> add(Ingredient ingredient) {
    if (TestModeService().isActive) return Future.value();
    return _storage.addToShoppingList(ingredient);
  }

  Future<void> remove(String name) {
    if (TestModeService().isActive) return Future.value();
    return _storage.removeFromShoppingList(name);
  }

  Future<void> clear() {
    if (TestModeService().isActive) return Future.value();
    return _storage.clearShoppingList();
  }
}
