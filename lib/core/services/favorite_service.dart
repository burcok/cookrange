import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/recipe_model.dart';
import 'auth_service.dart';

/// Manages recipe favorites (bookmarks) for the current user.
/// Collection: users/{uid}/favorites/{recipeId}
class FavoriteService {
  static final FavoriteService _instance = FavoriteService._internal();
  factory FavoriteService() => _instance;
  FavoriteService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _favRef(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  /// Toggle favorite. Returns true if now favorited, false if removed.
  Future<bool> toggleFavorite(Recipe recipe) async {
    final uid = _uid;
    if (uid == null) return false;

    final docRef = _favRef(uid).doc(recipe.id);
    final doc = await docRef.get();

    if (doc.exists) {
      await docRef.delete();
      return false;
    } else {
      await docRef.set({
        ...recipe.toJson(),
        'savedAt': FieldValue.serverTimestamp(),
      });
      return true;
    }
  }

  /// Real-time stream: is this recipe favorited by the current user?
  Stream<bool> isFavoriteStream(String recipeId) {
    final uid = _uid;
    if (uid == null) return Stream.value(false);
    return _favRef(uid)
        .doc(recipeId)
        .snapshots()
        .map((doc) => doc.exists)
        .handleError((Object e) {
      debugPrint('FavoriteService.isFavoriteStream error: $e');
      return false;
    });
  }

  /// Real-time stream of all favorited recipes, newest first.
  Stream<List<Recipe>> getFavoritesStream() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _favRef(uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              try {
                return Recipe.fromJson(doc.data());
              } catch (e) {
                debugPrint('FavoriteService parse error for ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Recipe>()
            .toList())
        .handleError((Object e) {
      debugPrint('FavoriteService.getFavoritesStream error: $e');
      return <Recipe>[];
    });
  }

  /// One-shot check — useful for init state.
  Future<bool> isFavorite(String recipeId) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final doc = await _favRef(uid).doc(recipeId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('FavoriteService.isFavorite error: $e');
      return false;
    }
  }

  /// Total count of favorited recipes.
  Future<int> getFavoritesCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final snap = await _favRef(uid).count().get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('FavoriteService.getFavoritesCount error: $e');
      return 0;
    }
  }
}
