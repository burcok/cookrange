import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/challenge_model.dart';

class ChallengeService {
  static final ChallengeService _instance = ChallengeService._internal();
  factory ChallengeService() => _instance;
  ChallengeService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('challenges');

  Stream<List<ChallengeModel>> getActiveChallengesStream() {
    return _col
        .where('isPublic', isEqualTo: true)
        .where('endDate', isGreaterThan: Timestamp.now())
        .orderBy('endDate')
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ChallengeModel.fromJson(d.data(), d.id)).toList());
  }

  Stream<List<ChallengeModel>> getMyChallengesStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col
        .where('participantIds', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => ChallengeModel.fromJson(d.data(), d.id)).toList());
  }

  Stream<ChallengeModel> getChallengeStream(String challengeId) {
    return _col.doc(challengeId).snapshots().map((d) {
      if (!d.exists) throw Exception('Challenge not found');
      return ChallengeModel.fromJson(d.data()!, d.id);
    });
  }

  Future<ChallengeModel> createChallenge({
    required String title,
    required String description,
    required ChallengeType type,
    required int goal,
    required String unit,
    required DateTime endDate,
    bool isPublic = true,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final doc = _col.doc();
    final model = ChallengeModel(
      id: doc.id,
      title: title,
      description: description,
      type: type,
      goal: goal,
      unit: unit,
      startDate: now,
      endDate: endDate,
      createdBy: uid,
      participantIds: [uid],
      participantProgress: {uid: 0},
      isPublic: isPublic,
      createdAt: now,
    );

    await doc.set(model.toJson());
    return model;
  }

  Future<void> joinChallenge(String challengeId) async {
    final uid = _uid;
    if (uid == null) return;
    await _col.doc(challengeId).update({
      'participantIds': FieldValue.arrayUnion([uid]),
      'participantProgress.$uid': 0,
    });
  }

  Future<void> leaveChallenge(String challengeId) async {
    final uid = _uid;
    if (uid == null) return;
    await _col.doc(challengeId).update({
      'participantIds': FieldValue.arrayRemove([uid]),
    });
    // Note: intentionally keep progress in map for leaderboard history
  }

  Future<void> updateProgress(String challengeId, int newValue) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _col.doc(challengeId).update({
        'participantProgress.$uid': newValue,
      });
    } catch (e) {
      debugPrint('ChallengeService.updateProgress error: $e');
    }
  }
}
