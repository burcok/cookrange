import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/gym_attribution_model.dart';
import '../models/gym_invite_code_model.dart';
import 'crashlytics_service.dart';
import 'sharing_service.dart';

/// Read-only result of [ReferralService.previewCode] — Faz 6 §6.3/§6.4's
/// pre-signup check. Deliberately NOT a verdict on whether the code can
/// actually be redeemed (only `applyReferral`, server-side, at signup time,
/// decides that for real) — just enough to show "verified, {gym}" on the
/// onboarding referral step before an account exists.
class ReferralPreview {
  final bool valid;
  final String? type;
  final String? gymName;

  const ReferralPreview({required this.valid, this.type, this.gymName});
}

/// Result of [ReferralService.applyCode] — Faz 6 §6.5: a `type: 'gym'` code
/// no longer grants a premium trial (it creates a gym attribution instead,
/// entirely server-side — see `applyReferral`'s gym branch), so "you both
/// got 7 days of Premium!" is simply FALSE for a gym-code redemption.
/// Callers need [isGymCode] to choose accurate success copy instead of a
/// single generic message. [error] is null on success, matching the plain
/// `String?` shape [applyCode] returned before this — existing callers that
/// only checked "is this null" still work unchanged.
class ReferralApplyResult {
  final String? error;
  final bool isGymCode;
  final String? gymName;

  const ReferralApplyResult({
    this.error,
    this.isGymCode = false,
    this.gymName,
  });

  bool get isSuccess => error == null;
}

/// Manages the friend-referral program.
///
/// Flow (already-signed-in redeemer — Settings' "I have a code"):
///  1. User A calls [getOrCreateCode] → receives e.g. "AB3X9K".
///  2. A shares the link via [shareCode] → "cookrangeapp.com/invite/AB3X9K".
///  3. User B is ALREADY signed in, types the code in Settings →
///     [applyCode("AB3X9K")].
///  4. Both A and B receive a 7-day premium trial.
///
/// Flow (pre-signup redeemer — Faz 6 §6.3/§6.4, the common case: B doesn't
/// have the app yet): B taps the link → `DeepLinkService` finds no session,
/// saves the code via [savePendingCode] and into `OnboardingProvider`, and
/// routes to onboarding. The referral step there calls [previewCode] (no
/// auth needed) to show "verified, {gym}"; the code is only actually
/// redeemed via [applyCode] once `OnboardingCompletion.finalizeAndRoute` has
/// a real, authenticated uid — never during onboarding itself. A signed-in
/// user tapping the SAME link gets neither path: the code is discarded
/// (invite codes are new-signup only).
///
/// Firestore schema (snake_case, matches functions/economy.js's reads —
/// Faz 0 §0.7: this comment previously said camelCase, contradicting the
/// code below, and had misled a camelCase admin-panel read into a
/// permanently-empty list / a no-op void action):
///  `referrals/{code}` → { owner_uid, created_at, used_by_uids: [], max_uses: 10 }
///
/// Faz 6 §6.1 — gym invite codes: the SAME collection, `type: 'gym'`, own
/// section below (`createGymInviteCode` etc.). A gym code is generated
/// in-app and printed/shared, not applied through this class — applying any
/// code (personal or gym) always goes through [applyCode] → `applyReferral`.
/// Faz 6 §6.5/§6.6: `applyReferral` now DOES special-case `type=='gym'` — it
/// writes a `gym_attributions/{uid}` record + notifies the gym owner instead
/// of the personal-referral trial+commission grant (see [ReferralApplyResult]
/// for how a caller tells the two outcomes apart), and a later real premium
/// purchase by that user accrues the gym's own commission via
/// `maybeAwardGymCommission` (functions/economy.js, triggered from
/// functions/purchases.js — never client-visible).
class ReferralService {
  ReferralService._internal();
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;

  /// Default use-cap for a newly-created referral code. Public so other
  /// referral-code issuers (e.g. CoachService's vanity codes) stay
  /// consistent without duplicating the literal.
  static const defaultMaxUses = 10;

  /// Default use-cap for a gym-issued invite code (Faz 6 §6.1) — a poster on
  /// a wall is scanned far more than 10 times, unlike a personal code shared
  /// 1:1. "Unlimited" isn't literal: `used_by_uids` is a plain array on this
  /// SAME doc, and a Firestore document caps out at 1 MiB — at ~30 bytes per
  /// uid, 5,000 entries is ~150 KB, comfortably clear of that ceiling for a
  /// single poster's realistic lifetime. If a code ever approaches this (a
  /// genuinely viral campaign), that's a sign `applyReferral`'s per-redemption
  /// array-append design (shared with personal/coach-vanity codes, just never
  /// stressed at their cap of 10) needs revisiting before it, not a reason to
  /// raise this constant further.
  static const gymDefaultMaxUses = 5000;

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
        'max_uses': defaultMaxUses,
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

  /// Apply another user's referral code. Returns a [ReferralApplyResult] —
  /// `error == null` means success (existing `!= null` failure checks still
  /// work); [ReferralApplyResult.isGymCode]/[ReferralApplyResult.gymName]
  /// tell the caller whether to show the personal-referral "you both got
  /// Premium" copy or the gym-attribution "connected to {gym}" copy (Faz 6
  /// §6.5 — see that class's doc comment for why these are no longer the
  /// same outcome).
  ///
  /// All validation + rewards happen SERVER-SIDE via the `applyReferral` Cloud
  /// Function: it enforces no-self-referral, one-per-account, max-uses
  /// (append-only), grants premium to both parties via the server-only
  /// entitlements writer, and records the commission in a server-written ledger.
  /// The client can no longer grant premium or write commissions itself.
  ///
  /// [source] — Faz 6 §6.5's `gym_attributions/{uid}.source` classification
  /// (`'deep_link'|'manual_entry'|'in_app'`); ignored server-side for a
  /// personal/coach-vanity code. Callers should pass the most accurate value
  /// they actually know (see call sites for what each one passes and why).
  Future<ReferralApplyResult> applyCode(String rawCode,
      {String source = 'in_app'}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const ReferralApplyResult(error: 'Not authenticated');
    }

    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) {
      return const ReferralApplyResult(error: 'Invalid code');
    }

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('applyReferral')
          .call({'code': code, 'source': source});
      debugPrint('ReferralService: code $code applied by $uid (server)');
      final data = Map<String, dynamic>.from(result.data as Map? ?? {});
      return ReferralApplyResult(
        isGymCode: data['type'] == 'gym',
        gymName: data['gymName'] as String?,
      ); // success
    } on FirebaseFunctionsException catch (e) {
      final message = switch (e.message) {
        'code_not_found' => 'Code not found',
        'own_code' => 'You cannot use your own code',
        'already_used_this' => 'You have already used this code',
        'limit_reached' => 'This code has reached its usage limit',
        'already_used_any' => 'You have already used a referral code',
        'invalid_code' => 'Invalid code',
        _ => 'Something went wrong. Please try again.',
      };
      return ReferralApplyResult(error: message);
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ReferralService.applyCode $code'));
      return const ReferralApplyResult(
          error: 'Something went wrong. Please try again.');
    }
  }

  /// Read-only pre-signup check (Faz 6 §6.3/§6.4): does [rawCode] exist,
  /// still have room, and — if it's a gym code — what's the gym's name?
  /// Requires NO Firebase Auth session, unlike [applyCode]/`applyReferral` —
  /// this is the only referral operation onboarding can perform before an
  /// account exists. Never mutates anything. Returns null on any failure
  /// (network, App Check, unexpected shape); callers must treat that
  /// identically to `ReferralPreview(valid: false)` — never as a hard error,
  /// since a code that merely failed to preview can still be applied for
  /// real at signup (the callable re-validates from scratch either way).
  Future<ReferralPreview?> previewCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) return const ReferralPreview(valid: false);

    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('previewReferralCode')
          .call({'code': code});
      final data = Map<String, dynamic>.from(result.data as Map);
      return ReferralPreview(
        valid: data['valid'] == true,
        type: data['type'] as String?,
        gymName: data['gymName'] as String?,
      );
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ReferralService.previewCode $code'));
      return null;
    }
  }

  // ── Pending code (Faz 6 §6.3 — deep link → onboarding handoff) ─────────────
  //
  // Device-local staging for a code that arrived before an account exists:
  // [DeepLinkService] saves it the moment an `/invite/{code}` link arrives
  // with no signed-in session, so it survives an app kill mid-onboarding
  // (in-memory `OnboardingProvider` state does not). [pendingCodeTtl] caps
  // how stale a saved code may be before a later read discards it — a scan
  // from weeks ago shouldn't misattribute a signup that happens today.

  static const _pendingCodeKey = 'pending_referral_code';
  static const _pendingCodeSavedAtKey = 'pending_referral_code_saved_at';
  static const pendingCodeTtl = Duration(days: 7);

  /// Persists [code] as the pending pre-signup referral code. Overwrites any
  /// previously-saved code — only the most recent deep link should ever be
  /// staged.
  Future<void> savePendingCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingCodeKey, code);
      await prefs.setInt(
          _pendingCodeSavedAtKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ReferralService.savePendingCode'));
    }
  }

  /// Returns the pending code if one was saved within [pendingCodeTtl], else
  /// null. Non-destructive (does NOT clear on a successful read) — onboarding
  /// may be re-entered several times before signup actually completes, and
  /// each entry should still see the same pending code. A code found to be
  /// past its TTL IS cleared as a side effect (it can never become valid
  /// again, so there's nothing to preserve by leaving it).
  Future<String?> loadPendingCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_pendingCodeKey);
      final savedAt = prefs.getInt(_pendingCodeSavedAtKey);
      if (code == null || savedAt == null) return null;

      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(savedAt));
      if (age > pendingCodeTtl) {
        await clearPendingCode();
        return null;
      }
      return code;
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ReferralService.loadPendingCode'));
      return null;
    }
  }

  /// Clears the pending code — called once signup completes, whether the
  /// code was actually applied or discarded (Faz 6 §6.3/§6.4).
  Future<void> clearPendingCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pendingCodeKey);
      await prefs.remove(_pendingCodeSavedAtKey);
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ReferralService.clearPendingCode'));
    }
  }

  // ── Sharing ──────────────────────────────────────────────────────────────

  /// Share the user's referral link via the OS share sheet.
  Future<void> shareCode(BuildContext context, String code,
      {Rect? sharePositionOrigin}) async {
    await SharingService().shareReferral(context,
        code: code, sharePositionOrigin: sharePositionOrigin);
  }

  // ── Gym invite codes (Faz 6 §6.1) ───────────────────────────────────────

  /// Creates a new `type: 'gym'` referral code for [gymId], owned by the
  /// caller. firestore.rules independently re-verifies the caller is THAT
  /// gym's real `owner_uid` via a server-side `get()` — this client-side call
  /// can't itself grant that, it just fails with a permission error if the
  /// caller isn't actually the owner. [campaign]/[locationNote] are both
  /// optional free text (e.g. "Coach Ahmet — Instagram", "Kadıköy şube,
  /// kardiyo katı") purely for the gym's own list view — blank fields still
  /// produce a valid, usable code (falls back to showing the raw code).
  Future<String> createGymInviteCode({
    required String gymId,
    String? campaign,
    String? locationNote,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    final code = await _generateUniqueCode();
    final trimmedCampaign = campaign?.trim();
    final trimmedNote = locationNote?.trim();
    await _db.doc('referrals/$code').set({
      'owner_uid': uid,
      'type': 'gym',
      'gym_id': gymId,
      if (trimmedCampaign != null && trimmedCampaign.isNotEmpty)
        'campaign': trimmedCampaign,
      if (trimmedNote != null && trimmedNote.isNotEmpty)
        'location_note': trimmedNote,
      'created_at': FieldValue.serverTimestamp(),
      'used_by_uids': <String>[],
      'max_uses': gymDefaultMaxUses,
    });
    debugPrint('ReferralService: created gym invite code $code for gym $gymId');
    return code;
  }

  /// Streams a gym's own invite codes, newest first — backs the management
  /// list in `GymInviteCodesScreen` (`gym_id` composite index in
  /// firestore.indexes.json). Any authenticated user can technically read a
  /// `referrals/{code}` doc (rules: validate-a-code needs that), but this
  /// query only ever runs from the gym owner's own dashboard.
  Stream<List<GymInviteCodeModel>> gymInviteCodesStream(String gymId,
      {int limit = 50}) {
    return _db
        .collection('referrals')
        .where('gym_id', isEqualTo: gymId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(GymInviteCodeModel.fromFirestore).toList())
        .handleError((Object e) {
      debugPrint('ReferralService: gymInviteCodesStream error — $e');
    });
  }

  /// Best-effort "the gym owner actually exported this poster" marker — not
  /// a rigorously audited print receipt, just for the owner's own tracking
  /// (task copy: "when the poster was actually printed"). Server-timestamped
  /// so it can't be backdated; firestore.rules requires exactly this shape
  /// whenever `printed_at` changes (mirrors `last_check_in` on gym members).
  Future<void> markInviteCodePrinted(String code) async {
    await _db.doc('referrals/$code').update({
      'printed_at': FieldValue.serverTimestamp(),
    });
  }

  // ── Gym attribution — user-facing transparency (Faz 6 §6.5) ────────────

  /// Reads the current user's own `gym_attributions/{uid}` doc, if any —
  /// backs the "you signed up via {gym}" line on the user's own profile.
  /// Returns null if the user was never attributed to a gym (the overwhelming
  /// common case) OR on any read error — this is a transparency nicety, not
  /// a critical path, so a failure here must never surface as a visible
  /// error to the user.
  Future<GymAttributionModel?> getMyAttribution() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('gym_attributions').doc(uid).get();
      if (!doc.exists) return null;
      return GymAttributionModel.fromFirestore(doc);
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'ReferralService.getMyAttribution'));
      return null;
    }
  }

  /// Whether the user has chosen to hide the "you signed up via {gym}" line
  /// from their own profile (the one-tap "disconnect" — Faz 6 §6.5). This is
  /// DISPLAY-only: it never touches `gym_attributions/{uid}` itself, which
  /// stays immutable regardless (see that rule's own comment for why — the
  /// gym's already-earned/earning commission must not become erasable by the
  /// attributed user). Stored separately at `users/{uid}/private/
  /// attribution_prefs`, already covered by the existing owner-only
  /// `private/{docId}` wildcard rule — no rules change needed for this.
  Future<bool> isAttributionHidden() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    try {
      final doc = await _db.doc('users/$uid/private/attribution_prefs').get();
      return doc.data()?['hidden'] == true;
    } catch (e, stack) {
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'ReferralService.isAttributionHidden'));
      return false;
    }
  }

  /// Sets (or clears) the display-only hide preference above.
  Future<void> setAttributionHidden(bool hidden) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.doc('users/$uid/private/attribution_prefs').set(
      {'hidden': hidden},
      SetOptions(merge: true),
    );
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
