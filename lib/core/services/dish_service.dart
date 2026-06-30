import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/dish_model.dart';
import 'admin_service.dart';
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
      debugPrint('Error fetching dishes: $e');
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
      debugPrint('Error fetching dishes by category $category: $e');
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
      debugPrint('Error fetching dish $id: $e');
      return null;
    }
  }

  /// Live stream of all dishes ordered alphabetically by English name.
  Stream<List<DishModel>> getAllDishesStream() {
    return _firestore
        .collection('dishes')
        .orderBy('name_en')
        .snapshots()
        .map(
            (snap) => snap.docs.map((d) => DishModel.fromFirestore(d)).toList())
        .handleError((e) {
      debugPrint('DishService: getAllDishesStream error — $e');
      return <DishModel>[];
    });
  }

  /// Updates editable fields on a dish document. Always stamps `updated_at`.
  Future<void> updateDish(String id, Map<String, dynamic> data) async {
    debugPrint('DishService: updateDish id=$id');
    await _firestore.collection('dishes').doc(id).update({
      ...data,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
    await AdminService().logAuditAction(
      action: 'update_dish',
      targetUid: id,
      metadata: {'fields': data.keys.toList()},
    );
  }

  /// Deletes a dish document. Irreversible — use with care.
  Future<void> deleteDish(String id) async {
    debugPrint('DishService: deleteDish id=$id');
    await _firestore.collection('dishes').doc(id).delete();
    await AdminService().logAuditAction(
      action: 'delete_dish',
      targetUid: id,
    );
  }

  // Seed the database if empty or forced
  Future<void> seedDatabase() async {
    final seeder = DishSeederService();
    await seeder.seedAllDishes();
  }
}
