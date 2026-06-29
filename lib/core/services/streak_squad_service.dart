import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/streak_squad_model.dart';

/// Service for Streak Squads — small friend groups sharing a streak goal.
///
/// Firestore collection: `squads/{squadId}`
/// All methods follow the singleton pattern and log errors via debugPrint (R4).
class StreakSquadService {
  static final StreakSquadService _instance = StreakSquadService._internal();
  factory StreakSquadService() => _instance;
  StreakSquadService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _squads =>
      _db.collection('squads');

  // ─── Private helpers ───────────────────────────────────────────────────────

  static const _inviteChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

  String _generateInviteCode() {
    final rng = Random.secure();
    return List.generate(
      6,
      (_) => _inviteChars[rng.nextInt(_inviteChars.length)],
    ).join();
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Creates a new squad with a unique 6-char invite code.
  /// The [creatorUid] is automatically added to [memberUids].
  Future<StreakSquadModel> createSquad(
    String name,
    String creatorUid,
    int streakGoal,
  ) async {
    debugPrint(
        'StreakSquadService.createSquad: name=$name creator=$creatorUid goal=$streakGoal');
    try {
      // Generate a unique invite code (retry on collision — extremely rare).
      String inviteCode;
      int attempts = 0;
      do {
        inviteCode = _generateInviteCode();
        final existing = await _squads
            .where('inviteCode', isEqualTo: inviteCode)
            .limit(1)
            .get();
        if (existing.docs.isEmpty) break;
        attempts++;
      } while (attempts < 5);

      final docRef = _squads.doc();
      final now = Timestamp.now();
      final model = StreakSquadModel(
        squadId: docRef.id,
        name: name.trim(),
        creatorUid: creatorUid,
        memberUids: [creatorUid],
        streakGoal: streakGoal,
        inviteCode: inviteCode,
        createdAt: now,
      );

      await docRef.set(model.toFirestore());
      debugPrint(
          'StreakSquadService.createSquad: created ${docRef.id} code=$inviteCode');
      return model;
    } catch (e, st) {
      debugPrint('StreakSquadService.createSquad error: $e\n$st');
      rethrow;
    }
  }

  /// Joins a squad by its 6-char [inviteCode].
  /// Throws [StreakSquadNotFoundException] if no squad has that code.
  /// Throws [StreakSquadAlreadyMemberException] if [uid] is already a member.
  Future<void> joinSquad(String inviteCode, String uid) async {
    debugPrint(
        'StreakSquadService.joinSquad: code=${inviteCode.toUpperCase()} uid=$uid');
    try {
      final query = await _squads
          .where('inviteCode', isEqualTo: inviteCode.toUpperCase())
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        debugPrint('StreakSquadService.joinSquad: squad not found');
        throw StreakSquadNotFoundException();
      }

      final doc = query.docs.first;
      final members = List<String>.from(doc.data()['memberUids'] as List? ?? []);
      if (members.contains(uid)) {
        debugPrint('StreakSquadService.joinSquad: already a member');
        throw StreakSquadAlreadyMemberException();
      }

      await doc.reference.update({
        'memberUids': FieldValue.arrayUnion([uid]),
      });
      debugPrint('StreakSquadService.joinSquad: ${doc.id} joined by $uid');
    } on StreakSquadNotFoundException {
      rethrow;
    } on StreakSquadAlreadyMemberException {
      rethrow;
    } catch (e, st) {
      debugPrint('StreakSquadService.joinSquad error: $e\n$st');
      rethrow;
    }
  }

  /// Removes [uid] from [squadId]'s memberUids.
  /// If the squad becomes empty after removal, the document is deleted.
  Future<void> leaveSquad(String squadId, String uid) async {
    debugPrint('StreakSquadService.leaveSquad: squad=$squadId uid=$uid');
    try {
      final docRef = _squads.doc(squadId);
      final snap = await docRef.get();
      if (!snap.exists) return;

      final members = List<String>.from(
          snap.data()?['memberUids'] as List? ?? []);
      members.remove(uid);

      if (members.isEmpty) {
        await docRef.delete();
        debugPrint(
            'StreakSquadService.leaveSquad: squad $squadId deleted (no members)');
      } else {
        await docRef.update({
          'memberUids': FieldValue.arrayRemove([uid]),
        });
        debugPrint('StreakSquadService.leaveSquad: $uid removed from $squadId');
      }
    } catch (e, st) {
      debugPrint('StreakSquadService.leaveSquad error: $e\n$st');
      rethrow;
    }
  }

  /// Live stream of all squads where [uid] is a member, ordered by createdAt.
  Stream<List<StreakSquadModel>> getMySquadsStream(String uid) {
    debugPrint('StreakSquadService.getMySquadsStream: uid=$uid');
    return _squads
        .where('memberUids', arrayContains: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map(StreakSquadModel.fromFirestore).toList())
        .handleError((Object e, StackTrace st) {
      debugPrint('StreakSquadService.getMySquadsStream error: $e\n$st');
    });
  }

  /// Live stream for a single squad document.
  Stream<StreakSquadModel?> getSquadStream(String squadId) {
    debugPrint('StreakSquadService.getSquadStream: squad=$squadId');
    return _squads.doc(squadId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return StreakSquadModel.fromFirestore(snap);
    }).handleError((Object e, StackTrace st) {
      debugPrint('StreakSquadService.getSquadStream error: $e\n$st');
    });
  }

  /// Batch-reads user docs for [memberUids] (chunked in groups of 10),
  /// returns a list of `{uid, displayName, photoURL, streak}` sorted by
  /// streak descending.
  Future<List<Map<String, dynamic>>> getMemberStreaks(
      List<String> memberUids) async {
    if (memberUids.isEmpty) return [];
    debugPrint(
        'StreakSquadService.getMemberStreaks: ${memberUids.length} members');
    try {
      final results = <Map<String, dynamic>>[];

      // Firestore whereIn supports max 10 items per query.
      const chunkSize = 10;
      for (int i = 0; i < memberUids.length; i += chunkSize) {
        final chunk = memberUids.sublist(
          i,
          (i + chunkSize).clamp(0, memberUids.length),
        );
        final snap = await _db
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final data = doc.data();
          // streak is stored nested under onboarding_data.streak
          final onboardingData =
              data['onboarding_data'] as Map<String, dynamic>? ?? {};
          results.add({
            'uid': doc.id,
            'displayName': data['displayName'] as String? ?? 'Unknown',
            'photoURL': data['photoURL'] as String? ?? '',
            'streak': (onboardingData['streak'] as num?)?.toInt() ?? 0,
          });
        }
      }

      results.sort((a, b) =>
          (b['streak'] as int).compareTo(a['streak'] as int));
      debugPrint(
          'StreakSquadService.getMemberStreaks: returned ${results.length} members');
      return results;
    } catch (e, st) {
      debugPrint('StreakSquadService.getMemberStreaks error: $e\n$st');
      rethrow;
    }
  }
}

// ─── Typed exceptions ────────────────────────────────────────────────────────

class StreakSquadNotFoundException implements Exception {
  @override
  String toString() => 'StreakSquadNotFoundException: No squad with that invite code.';
}

class StreakSquadAlreadyMemberException implements Exception {
  @override
  String toString() => 'StreakSquadAlreadyMemberException: User is already a member.';
}
