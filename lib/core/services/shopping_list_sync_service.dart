import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ingredient_model.dart';

/// Syncs the shopping list to Firestore for cross-device access.
/// Path: users/{uid}/lists/shopping
/// Relies on Firestore offline persistence for cache.
class ShoppingListSyncService {
  static final ShoppingListSyncService _instance =
      ShoppingListSyncService._internal();
  factory ShoppingListSyncService() => _instance;
  ShoppingListSyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _docRef(String uid) =>
      _db.collection('users').doc(uid).collection('lists').doc('shopping');

  /// Load items and checked set from Firestore. Returns null if no data.
  Future<({List<Ingredient> items, Set<String> checked})?> load(
      String uid) async {
    try {
      final snap = await _docRef(uid).get();
      if (!snap.exists) return null;
      final data = snap.data()!;
      final rawItems = (data['items'] as List<dynamic>? ?? []);
      final items = rawItems.map((m) {
        final map = Map<String, dynamic>.from(m as Map);
        return Ingredient(
          name: map['name'] ?? '',
          amount: (map['amount'] as num?)?.toDouble() ?? 0,
          unit: map['unit'] ?? '',
          calories: (map['calories'] as num?)?.toDouble() ?? 0,
          sourceMeals: List<String>.from(map['source_meals'] ?? const []),
          sourceDates: List<String>.from(map['source_dates'] ?? const []),
        );
      }).toList();
      final checked =
          Set<String>.from(data['checkedNames'] as List<dynamic>? ?? []);
      return (items: items, checked: checked);
    } catch (_) {
      return null;
    }
  }

  /// Persist the current list snapshot to Firestore (fire-and-forget friendly).
  Future<void> save(
      String uid, List<Ingredient> items, Set<String> checked) async {
    try {
      await _docRef(uid).set({
        'items': items.map((i) => i.toJson()).toList(),
        'checkedNames': checked.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-fatal: local Hive copy is the fallback
    }
  }

  /// Delete the Firestore list document (e.g., on full clear).
  Future<void> clear(String uid) async {
    try {
      await _docRef(uid).delete();
    } catch (_) {}
  }
}
