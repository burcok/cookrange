// Faz 4 §4.1 — tiered, per-scope progress-sharing consent.
//
// Deliberately a DIFFERENT shape from ConsentPurpose/ConsentModel
// (consent_model.dart): that system is one doc per GLOBAL purpose with a
// bool grant. This one is one doc PER SCOPE (a specific gym or coach,
// ProgressSharingScope) carrying a 0-3 TIER (ProgressSharingTier) rather
// than a bool — a member can share attendance with their gym but nothing
// with their coach, or share more with one coach than another. Reuses that
// system's versioning/audit-trail PHILOSOPHY (kLegalPolicyVersion,
// server-authoritative timestamps) rather than being forced into the
// ConsentPurpose enum, which has no notion of "per scope."
//
// Stored at `users/{uid}/progress_sharing/{scopeId}`.

import 'package:cloud_firestore/cloud_firestore.dart';

/// scopeId = 'gym_{gymId}' | 'coach_{uid}'.
enum ProgressSharingScopeType { gym, coach }

/// A parsed view over a scopeId string. Mirrors
/// `functions/summaries.js`'s `parseScopeId` exactly — same contract on
/// both sides of the wire.
class ProgressSharingScope {
  final ProgressSharingScopeType type;
  final String ownerId; // gymId or coachUid

  const ProgressSharingScope({required this.type, required this.ownerId});

  factory ProgressSharingScope.gym(String gymId) => ProgressSharingScope(
        type: ProgressSharingScopeType.gym,
        ownerId: gymId,
      );

  factory ProgressSharingScope.coach(String coachUid) => ProgressSharingScope(
        type: ProgressSharingScopeType.coach,
        ownerId: coachUid,
      );

  String get scopeId => switch (type) {
        ProgressSharingScopeType.gym => 'gym_$ownerId',
        ProgressSharingScopeType.coach => 'coach_$ownerId',
      };

  /// Parses a raw scopeId. Returns null if malformed (unknown prefix or an
  /// empty owner id) rather than throwing — callers treat a malformed id as
  /// "no scope," never as an exception path.
  static ProgressSharingScope? tryParse(String scopeId) {
    if (scopeId.startsWith('gym_') && scopeId.length > 4) {
      return ProgressSharingScope(
        type: ProgressSharingScopeType.gym,
        ownerId: scopeId.substring(4),
      );
    }
    if (scopeId.startsWith('coach_') && scopeId.length > 6) {
      return ProgressSharingScope(
        type: ProgressSharingScopeType.coach,
        ownerId: scopeId.substring(6),
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ProgressSharingScope &&
      other.type == type &&
      other.ownerId == ownerId;

  @override
  int get hashCode => Object.hash(type, ownerId);

  @override
  String toString() => 'ProgressSharingScope($scopeId)';
}

/// The 4 sharing tiers (§4.1). The enum index IS the wire value (`level`) —
/// keep declaration order stable.
enum ProgressSharingTier {
  /// 0 — kapalı. Default for every scope. `generateMemberProgressSummary`
  /// rejects outright at this tier (no data of any kind is aggregated).
  none,

  /// 1 — devam: check-in frequency, streak, last visit.
  attendance,

  /// 2 — devam+uyum: + plan adherence %, logging regularity.
  adherence,

  /// 3 — devam+uyum+kilo trendi: + weight trend DIRECTION and APPROXIMATE
  /// MAGNITUDE only. Raw weight history must never be exposed through this
  /// path — non-negotiable (plan's own words: "ham kilo geçmişi asla").
  weightTrend;

  int get level => index;

  static ProgressSharingTier fromLevel(int? level) => switch (level) {
        1 => ProgressSharingTier.attendance,
        2 => ProgressSharingTier.adherence,
        3 => ProgressSharingTier.weightTrend,
        _ => ProgressSharingTier.none,
      };

  bool get includesAdherence => level >= ProgressSharingTier.adherence.level;
  bool get includesWeightTrend =>
      level >= ProgressSharingTier.weightTrend.level;
}

/// A single recorded progress-sharing decision for one scope (KVKK/GDPR
/// accountability — versioned, timestamped, withdrawable). Read-only view
/// over Firestore; writes go through `ProgressSharingService.grantTier`/
/// `revoke`, which build the exact partial-update shape `firestore.rules`
/// expects (see that service's doc comments) rather than a generic
/// `toFirestore()` here — granting and revoking touch different fields, and
/// conflating them into one map risks writing `null`/serverTimestamp() into
/// the wrong one.
class ProgressSharingModel {
  final ProgressSharingScope scope;
  final ProgressSharingTier tier;
  final String policyVersion;
  final DateTime? grantedAt;
  final DateTime? revokedAt;

  const ProgressSharingModel({
    required this.scope,
    required this.tier,
    required this.policyVersion,
    this.grantedAt,
    this.revokedAt,
  });

  /// A never-decided scope (no doc exists yet) — tier defaults to
  /// [ProgressSharingTier.none], matching the server's own default-closed
  /// read (`generateMemberProgressSummary` treats a missing doc as tier 0).
  factory ProgressSharingModel.unset(ProgressSharingScope scope) =>
      ProgressSharingModel(
        scope: scope,
        tier: ProgressSharingTier.none,
        policyVersion: '',
      );

  factory ProgressSharingModel.fromFirestore(
      ProgressSharingScope scope, Map<String, dynamic> d) {
    final granted = d['granted_at'];
    final revoked = d['revoked_at'];
    return ProgressSharingModel(
      scope: scope,
      tier: ProgressSharingTier.fromLevel(d['level'] as int?),
      policyVersion: d['policy_version'] as String? ?? '',
      grantedAt: granted is Timestamp ? granted.toDate() : null,
      revokedAt: revoked is Timestamp ? revoked.toDate() : null,
    );
  }

  /// True if the user has never recorded a decision for this scope.
  bool get isUnset => policyVersion.isEmpty && grantedAt == null;

  bool get isShared => tier != ProgressSharingTier.none;
}

/// Typed view over `generateMemberProgressSummary`'s callable response
/// (`functions/summaries.js`) — kept here (a data shape) rather than in
/// `ProgressSharingService` (behavior), matching this codebase's model/
/// service split. §4.3 (the gym/coach-facing UI) is the actual consumer of
/// this; this task only builds the data-layer path to it.
class MemberProgressSummaryResult {
  final ProgressSharingTier tier;

  /// 'ai' or 'template' — whether the narrative came from an LLM call or the
  /// no-AI structured-field fallback (member lacked aiProcessing/
  /// crossBorderTransfer consent).
  final String method;
  final String narrative;

  /// Tier-gated structured fields the narrative was built from. Values are
  /// generally `num`/`String`/`DateTime`/null; a field may be the literal
  /// string `'insufficient_data'` (see functions/summaries.js's honesty note
  /// on plan_adherence_pct/weight_trend — no real data source exists yet).
  /// `last_visit_at`/`last_logged_at` are always normalized to [DateTime] by
  /// [_normalizeFields] regardless of which factory built this — a Cloud
  /// Functions HTTPS callable response does NOT auto-deserialize a Firestore
  /// Timestamp the way a direct Firestore snapshot read does (it typically
  /// arrives as its own `{_seconds, _nanoseconds}` shape); the UI layer must
  /// never import `cloud_firestore` to work around that itself (R5.1 — no
  /// Firebase import in a screen/widget), so this model owns the parsing.
  final Map<String, dynamic> fields;

  /// Set only when this result came from reading the cached
  /// `member_summaries` doc directly (`ProgressSharingService.
  /// getCachedSummary`); null when it just came back fresh from the
  /// `generateMemberProgressSummary` callable, whose response doesn't carry
  /// this field (the write happens server-side, in the same request, after
  /// the response shape is already fixed).
  final DateTime? generatedAt;

  const MemberProgressSummaryResult({
    required this.tier,
    required this.method,
    required this.narrative,
    required this.fields,
    this.generatedAt,
  });

  factory MemberProgressSummaryResult.fromCallable(Map<dynamic, dynamic> data) {
    return MemberProgressSummaryResult(
      tier: ProgressSharingTier.fromLevel((data['tier'] as num?)?.toInt()),
      method: data['method'] as String? ?? 'template',
      narrative: data['narrative'] as String? ?? '',
      fields: _normalizeFields(data['fields']),
    );
  }

  /// Parses the `gyms/{id}/member_summaries/{uid}` or
  /// `coach_profiles/{id}/member_summaries/{uid}` doc directly (the SAME
  /// fields the callable just wrote, read back without another call —
  /// `ProgressSharingService.getCachedSummary`).
  factory MemberProgressSummaryResult.fromCachedDoc(Map<String, dynamic> data) {
    final generatedAt = data['generated_at'];
    return MemberProgressSummaryResult(
      tier: ProgressSharingTier.fromLevel((data['tier'] as num?)?.toInt()),
      method: data['method'] as String? ?? 'template',
      narrative: data['narrative'] as String? ?? '',
      fields: _normalizeFields(data['fields']),
      generatedAt: generatedAt is Timestamp ? generatedAt.toDate() : null,
    );
  }
}

/// Field keys whose value is a point in time — normalized to [DateTime]
/// regardless of source shape (see [MemberProgressSummaryResult.fields]'s
/// doc comment for why this can't just be left to the UI layer).
const _dateFieldKeys = {'last_visit_at', 'last_logged_at'};

Map<String, dynamic> _normalizeFields(dynamic raw) {
  if (raw is! Map) return const {};
  final out = <String, dynamic>{};
  raw.forEach((key, value) {
    final k = key.toString();
    out[k] = _dateFieldKeys.contains(k) ? _asDateTime(value) : value;
  });
  return out;
}

DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  if (v is Map) {
    // admin.firestore.Timestamp's own toJSON() shape — the form it takes
    // when returned raw through an onCall response (see fields' doc above).
    final seconds = v['_seconds'] ?? v['seconds'];
    if (seconds is num) {
      return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
    }
  }
  return null;
}

/// Typed view over `sendProgressShareInvite`'s callable response
/// (`functions/summaries.js`) — Faz 4 §4.3's tier-0 empty-state "send an
/// invite" button.
enum ProgressShareInviteOutcome {
  /// A fresh invite was created and the member was notified.
  sent,

  /// Already invited before (ever) — the one-time guarantee held. Not an
  /// error; the UI renders this identically to [sent] (button becomes
  /// permanently disabled / shows "invite sent").
  alreadyInvited,

  /// The member's tier changed to >0 between page load and tap — no
  /// invite needed anymore.
  alreadyShared,
}

class ProgressShareInviteResult {
  final ProgressShareInviteOutcome outcome;
  const ProgressShareInviteResult(this.outcome);

  factory ProgressShareInviteResult.fromCallable(Map<dynamic, dynamic> data) {
    if (data['sent'] == true) {
      return const ProgressShareInviteResult(ProgressShareInviteOutcome.sent);
    }
    return ProgressShareInviteResult(
      data['reason'] == 'already_shared'
          ? ProgressShareInviteOutcome.alreadyShared
          : ProgressShareInviteOutcome.alreadyInvited,
    );
  }

  bool get isDone =>
      outcome == ProgressShareInviteOutcome.sent ||
      outcome == ProgressShareInviteOutcome.alreadyInvited;
}
