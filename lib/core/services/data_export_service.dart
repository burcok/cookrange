import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:share_plus/share_plus.dart';
import 'crashlytics_service.dart';

/// Collects all user data from Firestore and shares it as a JSON file.
/// Implements GDPR "right to data portability" (Art. 20).
class DataExportService {
  DataExportService._internal();
  static final DataExportService _instance = DataExportService._internal();
  factory DataExportService() => _instance;

  final _db = FirebaseFirestore.instance;

  Future<void> exportAndShare() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final data = await _collectAll(uid);
    final json = const JsonEncoder.withIndent('  ').convert(data);

    final file = XFile.fromData(
      utf8.encode(json),
      name: 'cookrange_my_data.json',
      mimeType: 'application/json',
    );

    await Share.shareXFiles(
      [file],
      text: 'My Cookrange data export',
      subject: 'cookrange_my_data.json',
    );
  }

  Future<Map<String, dynamic>> _collectAll(String uid) async {
    // GDPR Art.20 portability — export ALL personal data, including the private
    // nutrition PII subcollection and every owner subcollection, authored
    // content, and a manifest of uploaded files.
    final results = await Future.wait([
      _doc('users/$uid'), // 0
      _collection('users/$uid/private'), // 1 — height/weight/gender/DOB/allergies
      _collection('users/$uid/food_logs'), // 2
      _collection('users/$uid/meal_plans'), // 3
      _collection('users/$uid/food_analyses'), // 4
      _collection('users/$uid/exercise_logs'), // 5
      _collection('users/$uid/recipe_notes'), // 6
      _collection('users/$uid/favorites'), // 7
      _collection('users/$uid/lists'), // 8
      _collection('users/$uid/recent_foods'), // 9
      _collection('users/$uid/achievements'), // 10
      _collection('users/$uid/consents'), // 11
      _collection('users/$uid/ai_twin_projections'), // 12
      _collection('users/$uid/ai_weekly_recaps'), // 13
      _collection('users/$uid/saved_posts'), // 14
      _collection('users/$uid/notification_preferences'), // 15
      _collection('users/$uid/commissions'), // 16
      _collection('users/$uid/payout_requests'), // 17
      _collection('users/$uid/following'), // 18
      _collection('users/$uid/followers'), // 19
      _collection('users/$uid/friends'), // 20
      _posts(uid), // 21
      _authoredComments(uid), // 22
      _storageManifest(uid), // 23
    ]);

    return {
      'export_version': '2.0',
      'exported_at': DateTime.now().toIso8601String(),
      'uid': uid,
      'profile': results[0],
      'nutrition_private': results[1],
      'food_logs': results[2],
      'meal_plans': results[3],
      'food_analyses': results[4],
      'exercise_logs': results[5],
      'recipe_notes': results[6],
      'favorites': results[7],
      'lists': results[8],
      'recent_foods': results[9],
      'achievements': results[10],
      'consents': results[11],
      'ai_twin_projections': results[12],
      'ai_weekly_recaps': results[13],
      'saved_posts': results[14],
      'notification_preferences': results[15],
      'commissions': results[16],
      'payout_requests': results[17],
      'following': results[18],
      'followers': results[19],
      'friends': results[20],
      'community_posts': results[21],
      'comments': results[22],
      'uploaded_files': results[23],
    };
  }

  /// Best-effort: all comments the user authored (collection-group across posts).
  Future<List<Map<String, dynamic>>> _authoredComments(String uid) async {
    try {
      final snap = await _db
          .collectionGroup('comments')
          .where('authorId', isEqualTo: uid)
          .get();
      return snap.docs
          .map((d) => {'id': d.id, 'path': d.reference.path, ...d.data()})
          .toList();
    } catch (e) {
      unawaited(CrashlyticsService()
          .recordError(e, null, reason: 'data_export: _authoredComments'));
      return [];
    }
  }

  /// Best-effort manifest of the user's uploaded Storage objects (paths only).
  Future<List<String>> _storageManifest(String uid) async {
    final paths = <String>[
      'profile_photos/$uid',
      'post_images/$uid',
      'chat_images/$uid',
    ];
    final out = <String>[];
    for (final p in paths) {
      try {
        final res = await FirebaseStorage.instance.ref(p).listAll();
        out.addAll(res.items.map((i) => i.fullPath));
      } catch (_) {
        // prefix may not exist / not listable — skip
      }
    }
    return out;
  }

  Future<Map<String, dynamic>?> _doc(String path) async {
    try {
      final snap = await _db.doc(path).get();
      return snap.data();
    } catch (e) {
      unawaited(CrashlyticsService()
          .recordError(e, null, reason: 'data_export: _doc $path'));
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _collection(String path) async {
    try {
      final snap = await _db.collection(path).get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      unawaited(CrashlyticsService()
          .recordError(e, null, reason: 'data_export: _collection $path'));
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _posts(String uid) async {
    try {
      final snap =
          await _db.collection('posts').where('authorId', isEqualTo: uid).get();
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      unawaited(CrashlyticsService()
          .recordError(e, null, reason: 'data_export: _posts'));
      return [];
    }
  }
}
