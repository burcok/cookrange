import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crashlytics_service.dart';
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
  ///
  /// All validation + rewards happen SERVER-SIDE via the `applyReferral` Cloud
  /// Function: it enforces no-self-referral, one-per-account, max-uses
  /// (append-only), grants premium to both parties via the server-only
  /// entitlements writer, and records the commission in a server-written ledger.
  /// The client can no longer grant premium or write commissions itself.
  Future<String?> applyCode(String rawCode) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 'Not authenticated';

    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) return 'Invalid code';

    try {
      await FirebaseFunctions.instance
          .httpsCallable('applyReferral')
          .call({'code': code});
      debugPrint('ReferralService: code $code applied by $uid (server)');
      return null; // success
    } on FirebaseFunctionsException catch (e) {
      switch (e.message) {
        case 'code_not_found':
          return 'Code not found';
        case 'own_code':
          return 'You cannot use your own code';
        case 'already_used_this':
          return 'You have already used this code';
        case 'limit_reached':
          return 'This code has reached its usage limit';
        case 'already_used_any':
          return 'You have already used a referral code';
        case 'invalid_code':
          return 'Invalid code';
        default:
          return 'Something went wrong. Please try again.';
      }
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
