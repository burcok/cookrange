import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/dish_model.dart';
import 'dish_seeder_service.dart';

class DishService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Singleton
  static final DishService _instance = DishService._internal();
  factory DishService() => _instance;
  DishService._internal();

  /// Fetches all dishes from Firestore
  Future<List<DishModel>> getAllDishes() async {
    try {
      final snapshot = await _firestore.collection('dishes').get();
      return snapshot.docs.map((doc) => DishModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching dishes: $e');
      return [];
    }
  }

  /// Fetches dishes by category
  Future<List<DishModel>> getDishesByCategory(String category) async {
    try {
      final snapshot = await _firestore
          .collection('dishes')
          .where('category', isEqualTo: category)
          .get();
      return snapshot.docs.map((doc) => DishModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error fetching dishes by category $category: $e');
      return [];
    }
  }

  /// Fetches a single dish by ID
  Future<DishModel?> getDishById(String id) async {
    try {
      final doc = await _firestore.collection('dishes').doc(id).get();
      if (doc.exists) {
        return DishModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error fetching dish $id: $e');
      return null;
    }
  }

  // Seed the database if empty or forced
  Future<void> seedDatabase() async {
    final seeder = DishSeederService();
    await seeder.seedAllDishes();
  }
}
