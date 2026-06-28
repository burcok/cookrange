import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Stores personal notes for recipes per user.
/// Path: users/{uid}/recipe_notes/{recipeId}
class RecipeNoteService {
  static final RecipeNoteService _instance = RecipeNoteService._internal();
  factory RecipeNoteService() => _instance;
  RecipeNoteService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _ref(String uid, String recipeId) =>
      _db.collection('users').doc(uid).collection('recipe_notes').doc(recipeId);

  Future<String?> getNote(String recipeId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final doc = await _ref(uid, recipeId).get();
      return doc.data()?['note'] as String?;
    } catch (e) {
      debugPrint('RecipeNoteService.getNote error: $e');
      return null;
    }
  }

  Future<void> saveNote(String recipeId, String note) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      if (note.trim().isEmpty) {
        await _ref(uid, recipeId).delete();
      } else {
        await _ref(uid, recipeId).set({
          'note': note.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('RecipeNoteService.saveNote error: $e');
    }
  }
}
