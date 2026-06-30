import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/privacy_request_model.dart';
import 'auth_service.dart';
import 'crashlytics_service.dart';

/// Submits and tracks data-subject requests (DSAR). Stored at
/// `privacy_requests/{id}`; owner creates + reads own, admin reads/updates all.
class PrivacyRequestService {
  static final PrivacyRequestService _instance =
      PrivacyRequestService._internal();
  factory PrivacyRequestService() => _instance;
  PrivacyRequestService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('privacy_requests');

  /// Files a new request. Returns the created doc id, or null on failure.
  Future<String?> submit(PrivacyRequestType type, String message) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final model = PrivacyRequestModel(
        id: '',
        uid: user.uid,
        email: user.email ?? '',
        type: type,
        message: message.trim(),
        status: PrivacyRequestStatus.pending,
      );
      final ref = await _col.add(model.toCreate());
      debugPrint('PrivacyRequest filed: ${type.key} (${ref.id})');
      unawaited(CrashlyticsService().log('privacy_request.${type.key}'));
      return ref.id;
    } catch (e, st) {
      debugPrint('PrivacyRequestService.submit error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'PrivacyRequestService.submit'));
      rethrow;
    }
  }

  /// The current user's own requests, newest first.
  Stream<List<PrivacyRequestModel>> myRequestsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('uid', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((s) => s.docs.map(PrivacyRequestModel.fromFirestore).toList());
  }
}
