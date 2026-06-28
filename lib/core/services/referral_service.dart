import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notification_model.dart';
import 'commission_service.dart';
import 'crashlytics_service.dart';
import 'notification_service.dart';
import 'sharing_service.dart';

/// Manages the friend-referral program.
///
/// Flow:
///  1. User A calls [getOrCreateCode] → receives e.g. "AB3X9K".
///  2. A shares the link via [shareCode] → "cookrangeapp.com/invite/AB3X9K".
///  3. User B installs, taps the link (deep-linked) or types the code in
///     Settings → calls [applyCode("AB3X9K", uidOfB)].
///  4. Both A and B receive a 7-day premium trial.
///
/// Firestore schema:
///  `referrals/{code}` → { ownerUid, createdAt, usedByUids: [], maxUses: 10 }
class ReferralService {
  ReferralService._internal();
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;

  static const _rewardDays = 7;
  static const _maxUses = 10;

  final _db = FirebaseFirestore.instance;

  // ── Code management ─────────────────────────────────────────────────────

  /// Returns the current user's referral code, generating one if needed.
  Future<String> getOrCreateCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    // Check if a code already exists on the user doc.
    final userDoc = await _db.doc('users/$uid').get();
    final existing = userDoc.data()?['referral_code'] as String?;
    if (existing != null && existing.isNotEmpty) return existing;

    // Generate a unique 6-char code and create the referrals doc.
    final code = await _generateUniqueCode();
    await Future.wait([
      _db.doc('users/$uid').update({'referral_code': code}),
      _db.doc('referrals/$code').set({
        'owner_uid': uid,
        'created_at': FieldValue.serverTimestamp(),
        'used_by_uids': <String>[],
        'max_uses': _maxUses,
      }),
    ]);
    debugPrint('ReferralService: created code $code for $uid');
    return code;
  }

  /// Returns how many times this user's code has been used.
  Future<int> getReferralCount() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;

    final userDoc = await _db.doc('users/$uid').get();
    final code = userDoc.data()?['referral_code'] as String?;
    if (code == null) return 0;

    final refDoc = await _db.doc('referrals/$code').get();
    final usedByUids =
        (refDoc.data()?['used_by_uids'] as List<dynamic>?)?.length ?? 0;
    return usedByUids;
  }

  // ── Applying a code ──────────────────────────────────────────────────────

  /// Apply another user's referral code. Returns an error string on failure,
  /// null on success.
  Future<String?> applyCode(String rawCode) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'Not authenticated';

    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) return 'Invalid code';

    try {
      final refRef = _db.doc('referrals/$code');
      final refDoc = await refRef.get();
      if (!refDoc.exists) return 'Code not found';

      final data = refDoc.data()!;
      final ownerUid = data['owner_uid'] as String;
      final usedByUids =
          List<String>.from(data['used_by_uids'] as List<dynamic>? ?? []);
      final maxUses = (data['max_uses'] as int?) ?? _maxUses;

      if (ownerUid == uid) return 'You cannot use your own code';
      if (usedByUids.contains(uid)) return 'You have already used this code';
      if (usedByUids.length >= maxUses) {
        return 'This code has reached its usage limit';
      }

      // Also prevent a user from applying any code if they already used one.
      final myDoc = await _db.doc('users/$uid').get();
      if (myDoc.data()?['referral_used'] != null) {
        return 'You have already used a referral code';
      }

      // Apply atomically.
      final batch = _db.batch();
      final expiry = Timestamp.fromDate(
          DateTime.now().add(const Duration(days: _rewardDays)));

      // Mark the code as used.
      batch.update(refRef, {
        'used_by_uids': FieldValue.arrayUnion([uid]),
      });

      // Reward the new user (B).
      batch.update(_db.doc('users/$uid'), {
        'referral_used': code,
        'subscription_tier': 'premium',
        'subscription_expires_at': expiry,
      });

      // Reward the referrer (A).
      batch.update(_db.doc('users/$ownerUid'), {
        'subscription_tier': 'premium',
        'subscription_expires_at': expiry,
      });

      await batch.commit();

      // Notify the referrer (structured — rendered in the referrer's language).
      unawaited(
        NotificationService().sendNotification(
          targetUserId: ownerUid,
          type: NotificationType.referral,
          relatedId: code,
          metadata: {'rewardDays': _rewardDays},
        ),
      );

      // Record a €5 commission for the referral code owner.
      unawaited(CommissionService().recordReferralCommission(
        ownerUid: ownerUid,
        refereeUid: uid,
        refereeName:
            FirebaseAuth.instance.currentUser?.displayName ?? 'New User',
      ));

      debugPrint(
          'ReferralService: code $code applied by $uid → rewarded $ownerUid');
      return null; // success
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ReferralService.applyCode $code'));
      return 'Something went wrong. Please try again.';
    }
  }

  // ── Sharing ──────────────────────────────────────────────────────────────

  /// Share the user's referral link via the OS share sheet.
  Future<void> shareCode(BuildContext context, String code,
      {Rect? sharePositionOrigin}) async {
    await SharingService().shareReferral(context,
        code: code, sharePositionOrigin: sharePositionOrigin);
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<String> _generateUniqueCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();

    for (var attempt = 0; attempt < 10; attempt++) {
      final code =
          List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
      final doc = await _db.doc('referrals/$code').get();
      if (!doc.exists) return code;
    }
    // Fallback: timestamp suffix ensures uniqueness.
    final ts =
        DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
    return ts.substring(max(0, ts.length - 6));
  }
}
