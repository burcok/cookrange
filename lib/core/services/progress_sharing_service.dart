import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/consent_model.dart' show kLegalPolicyVersion;
import '../models/progress_sharing_model.dart';
import 'auth_service.dart';
import 'crashlytics_service.dart';

/// Faz 4 §4.1/§4.2 — tiered progress-sharing consent (member side) and the
/// `generateMemberProgressSummary` callable wrapper (gym-owner/coach side).
///
/// Source of truth for consent: `users/{uid}/progress_sharing/{scopeId}`
/// (owner-only, see `progress_sharing_model.dart`'s header for why this is a
/// different shape from `ConsentService`). Source of truth for generation:
/// the `generateMemberProgressSummary` Cloud Function (`functions/
/// summaries.js`) — this service never aggregates or reads another user's
/// underlying data itself, it only calls that callable.
///
/// NOT built here (explicitly out of scope — Faz 4 §4.3): the Consent-
/// Center-adjacent screen itself, the gym/coach card UI, the "invite to
/// share" button, the tier-0 empty state. [watchAll] is the minimal stream
/// that screen needs; building it is the next step for whoever picks up
/// §4.3.
class ProgressSharingService {
  static final ProgressSharingService _instance =
      ProgressSharingService._internal();
  factory ProgressSharingService() => _instance;
  ProgressSharingService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('progress_sharing');

  // ─── Member side: grant / revoke / read own decisions ──────────────────

  /// Live stream of the caller's OWN progress-sharing decisions, keyed by
  /// scopeId. Scopes with no recorded decision simply don't appear (unlike
  /// `ConsentService.watchConsents`, there is no fixed enum of scopes to
  /// pre-populate — a member may have zero, one, or many gym/coach scopes).
  Stream<Map<String, ProgressSharingModel>> watchAll() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col(uid).snapshots().map((snap) {
      final map = <String, ProgressSharingModel>{};
      for (final doc in snap.docs) {
        final scope = ProgressSharingScope.tryParse(doc.id);
        if (scope != null) {
          map[doc.id] = ProgressSharingModel.fromFirestore(scope, doc.data());
        }
      }
      return map;
    });
  }

  /// One-shot read of a single scope's current tier (defaults to
  /// [ProgressSharingTier.none] if never decided, matching the server's own
  /// default-closed behavior).
  Future<ProgressSharingTier> getTier(ProgressSharingScope scope) async {
    final uid = _uid;
    if (uid == null) return ProgressSharingTier.none;
    try {
      final doc = await _col(uid).doc(scope.scopeId).get();
      if (!doc.exists) return ProgressSharingTier.none;
      return ProgressSharingTier.fromLevel(doc.data()?['level'] as int?);
    } catch (e) {
      debugPrint('ProgressSharingService.getTier error: $e');
      return ProgressSharingTier.none;
    }
  }

  /// Grants (or raises/lowers, if already shared) [scope] to [tier].
  /// [ProgressSharingTier.none] is redirected to [revoke] — same write
  /// shape either way, kept as one call so a UI toggle/slider can call this
  /// unconditionally across the full 0-3 range.
  ///
  /// A partial `set(..., merge: true)`, not a full replace: only
  /// `level`/`policy_version`/`granted_at`/`revoked_at` are touched, so this
  /// can never clobber an unrelated field. `granted_at` is always
  /// re-stamped to now on every grant (including raising/lowering an
  /// existing tier) — mirrors `ConsentService.setConsent` treating every
  /// call as a fresh, auditable decision rather than trying to distinguish
  /// "first grant" from "tier change."
  Future<void> grantTier(
      ProgressSharingScope scope, ProgressSharingTier tier) async {
    if (tier == ProgressSharingTier.none) return revoke(scope);
    final uid = _uid;
    if (uid == null) return;
    try {
      await _col(uid).doc(scope.scopeId).set({
        'level': tier.level,
        'policy_version': kLegalPolicyVersion,
        'granted_at': FieldValue.serverTimestamp(),
        'revoked_at': null,
      }, SetOptions(merge: true));
      debugPrint(
          'ProgressSharing granted: ${scope.scopeId} -> tier ${tier.level}');
      unawaited(CrashlyticsService()
          .log('progress_sharing.grant.${scope.scopeId}.${tier.level}'));
    } catch (e, st) {
      debugPrint('ProgressSharingService.grantTier error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'ProgressSharingService.grantTier'));
      rethrow;
    }
  }

  /// Sets [scope] to tier 0. Takes effect immediately server-side: the
  /// `onProgressSharingWrite` trigger (`functions/summaries.js`) deletes any
  /// cached summary for this scope the moment this write lands — not on
  /// that summary's own 7-day TTL. `granted_at` is deliberately left
  /// untouched (not nulled) so the doc keeps a "granted at X, revoked at Y"
  /// history instead of erasing it.
  Future<void> revoke(ProgressSharingScope scope) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _col(uid).doc(scope.scopeId).set({
        'level': 0,
        'policy_version': kLegalPolicyVersion,
        'revoked_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('ProgressSharing revoked: ${scope.scopeId}');
      unawaited(
          CrashlyticsService().log('progress_sharing.revoke.${scope.scopeId}'));
    } catch (e, st) {
      debugPrint('ProgressSharingService.revoke error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'ProgressSharingService.revoke'));
      rethrow;
    }
  }

  // ─── Caller side: generate a summary (gym owner / coach) ────────────────

  /// Invokes the `generateMemberProgressSummary` callable
  /// (`functions/summaries.js`). All authority/consent/tier checks happen
  /// server-side — this call carries no claim the server trusts blindly.
  ///
  /// Throws `FirebaseFunctionsException` on rejection — in particular
  /// `permission-denied` with message `not_shared` (tier 0 / never decided)
  /// or `not_authorized_for_scope` (caller isn't really this gym's owner or
  /// this member's active coach), and `resource-exhausted` with message
  /// `generation_rate_limited` (already generated for this member today).
  /// Never silently swallowed — the caller (§4.3's UI) is expected to
  /// surface these as distinct, human-readable states, not a generic error.
  Future<MemberProgressSummaryResult> generateSummary({
    required String memberUid,
    required ProgressSharingScope scope,
    String locale = 'en',
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('generateMemberProgressSummary')
          .call<Map<String, dynamic>>({
        'memberUid': memberUid,
        'scopeId': scope.scopeId,
        'locale': locale,
      });
      debugPrint(
          'ProgressSharingService.generateSummary: ok memberUid=$memberUid scopeId=${scope.scopeId}');
      return MemberProgressSummaryResult.fromCallable(result.data);
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint(
          'ProgressSharingService.generateSummary error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason:
              'ProgressSharingService.generateSummary memberUid=$memberUid scopeId=${scope.scopeId}'));
      rethrow;
    } catch (e, st) {
      debugPrint('ProgressSharingService.generateSummary error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason:
              'ProgressSharingService.generateSummary memberUid=$memberUid scopeId=${scope.scopeId}'));
      rethrow;
    }
  }

  // ─── Caller side: read the cache before ever spending a generation ──────

  /// One-shot read of an already-cached summary for (scope, memberUid), if
  /// one exists and hasn't been swept — a plain Firestore get against
  /// `member_summaries/{memberUid}`, gated by the SAME owner-or-member rule
  /// as everything else in that collection, no callable involved. This is
  /// what lets `CoachClientDetailScreen` show an already-generated summary
  /// on every screen open without burning the once-per-24h generation
  /// allowance just by being viewed again — [generateSummary] is reserved
  /// for the explicit "generate" tap when nothing is cached yet.
  Future<MemberProgressSummaryResult?> getCachedSummary(
      {required String memberUid, required ProgressSharingScope scope}) async {
    try {
      final doc = await _scopeContainerRef(scope)
          .collection('member_summaries')
          .doc(memberUid)
          .get();
      if (!doc.exists) return null;
      return MemberProgressSummaryResult.fromCachedDoc(doc.data()!);
    } catch (e) {
      debugPrint('ProgressSharingService.getCachedSummary error: $e');
      return null;
    }
  }

  // ─── Caller side: tier-0 empty state (§4.3) ─────────────────────────────

  /// `gyms/{gymId}` or `coach_profiles/{coachUid}` — the container whose
  /// subcollections (`progress_share_invites`, mirrors `member_summaries`)
  /// this service reads directly rather than through another callable.
  DocumentReference<Map<String, dynamic>> _scopeContainerRef(
          ProgressSharingScope scope) =>
      scope.type == ProgressSharingScopeType.gym
          ? _db.collection('gyms').doc(scope.ownerId)
          : _db.collection('coach_profiles').doc(scope.ownerId);

  /// One-shot check of whether [memberUid] has ALREADY been sent a
  /// progress-sharing invite for [scope] — ever. Backed by a direct,
  /// owner-read-only doc get (`progress_share_invites/{memberUid}`), not a
  /// callable: the callable already re-derives authority on-write; this is
  /// a plain read the security rule itself gates, exactly like
  /// `member_summaries`/`access_log`. Used to render the tier-0 button's
  /// initial state correctly (already-invited vs. never-invited) without
  /// requiring a tap first.
  Future<bool> hasInvited(
      {required ProgressSharingScope scope, required String memberUid}) async {
    try {
      final doc = await _scopeContainerRef(scope)
          .collection('progress_share_invites')
          .doc(memberUid)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('ProgressSharingService.hasInvited error: $e');
      return false;
    }
  }

  /// Invokes `sendProgressShareInvite` (`functions/summaries.js`) — the
  /// tier-0 empty state's "send an invite" button. Fires the member a
  /// SINGLE notification, ever, for this (scope, member) pair — the server
  /// enforces the one-time guarantee via an idempotent `.create()`, so a
  /// second call (double-tap, screen re-open) always resolves to
  /// [ProgressShareInviteOutcome.alreadyInvited] rather than a duplicate
  /// send. No AI call, no credit/quota consumption.
  Future<ProgressShareInviteResult> sendInvite(
      {required ProgressSharingScope scope, required String memberUid}) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendProgressShareInvite')
          .call<Map<String, dynamic>>({
        'memberUid': memberUid,
        'scopeId': scope.scopeId,
      });
      debugPrint(
          'ProgressSharingService.sendInvite: ok memberUid=$memberUid scopeId=${scope.scopeId}');
      return ProgressShareInviteResult.fromCallable(result.data);
    } catch (e, st) {
      debugPrint('ProgressSharingService.sendInvite error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason:
              'ProgressSharingService.sendInvite memberUid=$memberUid scopeId=${scope.scopeId}'));
      rethrow;
    }
  }

  // ─── Caller side: at-risk list scoping + k-anonymity aggregate (§4.3) ───

  /// Invokes `getConsentingMemberUids` (`functions/summaries.js`): the uids
  /// of [scope]'s members who have granted tier>=1 — nothing more (no tier
  /// value, no field data). The gym owner / coach client cannot read
  /// another user's `progress_sharing` doc directly (owner-only rule), so
  /// this is the only way to filter a member LIST by consent without one
  /// `generateMemberProgressSummary` call per member. Backs the at-risk
  /// list (§4.3: scoped to tier>=1 consenters) and the k-anonymity-gated
  /// aggregate card (caller averages already-visible check-in data over
  /// this set, client-side, and hides the result below 5 included members).
  Future<Set<String>> getConsentingMemberUids(
      ProgressSharingScope scope) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getConsentingMemberUids')
          .call<Map<String, dynamic>>({'scopeId': scope.scopeId});
      final uids = result.data['uids'];
      return uids is List ? uids.map((e) => e.toString()).toSet() : const {};
    } catch (e, st) {
      debugPrint('ProgressSharingService.getConsentingMemberUids error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason:
              'ProgressSharingService.getConsentingMemberUids scopeId=${scope.scopeId}'));
      // Fails CLOSED (empty set), not open — a transient error here must
      // never fall back to "show everyone unscoped," which would silently
      // reopen the exact leak (§4.3) this method exists to close.
      return const {};
    }
  }

  // ─── Member side: transparency (§4.1 point "en son ne zaman görüntülendi") ─

  /// Most recent `access_log` entry per scopeId, for the member's own
  /// Consent-Center-adjacent screen ("last viewed on X"). One bounded query
  /// (R1 — not one per scope): `access_log` ordered by `viewed_at` desc,
  /// grouped client-side, keeping only the first (= most recent, thanks to
  /// the ordering) entry seen per scope_id.
  Future<Map<String, DateTime>> getLastAccessByScope({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return const {};
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('access_log')
          .orderBy('viewed_at', descending: true)
          .limit(limit)
          .get();
      final result = <String, DateTime>{};
      for (final doc in snap.docs) {
        final scopeId = doc.data()['scope_id'] as String?;
        final viewedAt = doc.data()['viewed_at'];
        if (scopeId == null || result.containsKey(scopeId)) continue;
        if (viewedAt is Timestamp) result[scopeId] = viewedAt.toDate();
      }
      return result;
    } catch (e) {
      debugPrint('ProgressSharingService.getLastAccessByScope error: $e');
      return const {};
    }
  }
}
