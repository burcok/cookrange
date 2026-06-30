import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
    final results = await Future.wait([
      _doc('users/$uid'),
      _collection('users/$uid/food_logs'),
      _collection('users/$uid/meal_plans'),
      _collection('users/$uid/lists'),
      _posts(uid),
    ]);

    return {
      'export_version': '1.0',
      'uid': uid,
      'profile': results[0],
      'food_logs': results[1],
      'meal_plans': results[2],
      'lists': results[3],
      'community_posts': results[4],
    };
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
