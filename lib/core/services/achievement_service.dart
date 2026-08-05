import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import '../models/achievement_model.dart';
import 'reputation_service.dart';

/// One self-reported XP-triggering instant (Faz 5 §5.1), passed to
/// [AchievementService.checkAndGrant]'s `xpEvents`. The server
/// (`functions/progress.js`'s `syncProgress`) independently verifies the
/// referenced doc exists and is owned by the caller before deciding how many
/// points it's worth — this class only carries WHICH instance happened,
/// never a point value (there is deliberately no `points` field here; see
/// `progress.js`'s header comment for the full trust model).
///
/// Only the five kinds below may ever be client-reported at all — streak
/// days, gym check-ins, template acceptance and achievement grants are
/// awarded entirely server-side from their own already-verified triggers,
/// never from a client event (same file).
class XpEvent {
  final String kind;

  /// The doc id that makes this instance idempotent server-side — a
  /// `food_logs` id, a post id, a comment id. Left null for
  /// `reaction_given`, which the server synthesizes from [postId]/
  /// [commentId]/[emoji] instead (a reaction toggle has no doc id of its
  /// own to key off).
  final String? refId;

  /// Required for `comment_created` and `reaction_given` (the server needs
  /// the parent post to look up the comment/reaction doc for verification).
  final String? postId;

  /// Only set for a comment-level reaction.
  final String? commentId;

  /// Required for `reaction_given`.
  final String? emoji;

  const XpEvent._({
    required this.kind,
    this.refId,
    this.postId,
    this.commentId,
    this.emoji,
  });

  factory XpEvent.mealLogged(String logId) =>
      XpEvent._(kind: 'meal_logged', refId: logId);

  factory XpEvent.recipeCooked(String logId) =>
      XpEvent._(kind: 'recipe_cooked', refId: logId);

  factory XpEvent.postCreated(String postId) =>
      XpEvent._(kind: 'post_created', refId: postId);

  factory XpEvent.commentCreated({
    required String postId,
    required String commentId,
  }) =>
      XpEvent._(kind: 'comment_created', refId: commentId, postId: postId);

  factory XpEvent.reactionGiven({
    required String postId,
    String? commentId,
    required String emoji,
  }) =>
      XpEvent._(
        kind: 'reaction_given',
        postId: postId,
        commentId: commentId,
        emoji: emoji,
      );

  Map<String, dynamic> toRequestMap() => {
        'kind': kind,
        if (refId != null) 'refId': refId,
        if (postId != null) 'postId': postId,
        if (commentId != null) 'commentId': commentId,
        if (emoji != null) 'emoji': emoji,
      };
}

/// Manages badge/achievement earning for a user.
///
/// Granting is server-authoritative (audit N2/Faz-0 §0.4, `syncProgress` /
/// `backfillProgress` in `functions/progress.js`) — `firestore.rules` denies
/// client writes to `users/{uid}/achievements/*` unconditionally, closing a
/// self-grant hole (any authenticated user could previously write any badge
/// directly, no eligibility check enforced). Every call site still calls
/// [checkAndGrant] the same way as before (fire-and-forget via `unawaited`);
/// the server independently re-derives streak/reputation-tier badges from
/// truth and only honours the four momentary event flags for the caller's
/// own uid — see the doc comment in `functions/progress.js` for the full
/// trust-boundary rationale.
class AchievementService {
  static final AchievementService _instance = AchievementService._internal();
  factory AchievementService() => _instance;
  AchievementService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('achievements');

  // ──────────────────────────────────────────────────────────────────────────
  // Read
  // ──────────────────────────────────────────────────────────────────────────

  Stream<List<AchievementRecord>> getAchievementsStream(String uid) {
    return _col(uid).snapshots().map((snap) => snap.docs
        .map((d) => AchievementRecord.fromFirestore(d.id, d.data()))
        .toList());
  }

  Future<Set<AchievementKey>> getEarnedKeys(String uid) async {
    final snap = await _col(uid).get();
    final keys = <AchievementKey>{};
    for (final doc in snap.docs) {
      try {
        keys.add(AchievementKey.values.firstWhere((k) => k.name == doc.id));
      } catch (_) {}
    }
    return keys;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Grant logic — call unawaited from existing success paths
  // ──────────────────────────────────────────────────────────────────────────

  /// Reports momentary events + triggers a server-side re-sync. [streak] and
  /// [tier] are accepted for source compatibility with existing call sites
  /// but are no longer sent — the server always re-derives both from the
  /// user's own stored data, never a client-supplied number.
  ///
  /// [xpEvents] (Faz 5 §5.1) reports which XP-worthy instant(s) just
  /// happened — e.g. `logRecipe` reports BOTH a `meal_logged` and a
  /// `recipe_cooked` event for the same food_logs doc, same as it already
  /// sets both [justLoggedMeal] and [justCookedAndLogged] for achievements.
  /// The server independently verifies each referenced doc before awarding
  /// anything (see `progress.js`); a failed verification is skipped
  /// server-side, never surfaced as an error here.
  Future<void> checkAndGrant(
    String uid, {
    int? streak,
    ReputationTier? tier,
    bool justLoggedMeal = false,
    bool justLoggedPhoto = false,
    bool justPosted = false,
    bool justCookedAndLogged = false,
    List<XpEvent> xpEvents = const [],
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('syncProgress')
          .call<Map<String, dynamic>>({
        if (justLoggedMeal) 'justLoggedMeal': true,
        if (justLoggedPhoto) 'justLoggedPhoto': true,
        if (justPosted) 'justPosted': true,
        if (justCookedAndLogged) 'justCookedAndLogged': true,
        if (xpEvents.isNotEmpty)
          'xpEvents': xpEvents.map((e) => e.toRequestMap()).toList(),
      });
      debugPrint('AchievementService: syncProgress for $uid → '
          'granted=${result.data['granted']}, level=${result.data['level']}, '
          'leveledUp=${result.data['leveledUp']}');
    } catch (e) {
      debugPrint('AchievementService: checkAndGrant error: $e');
    }
  }

  /// Backfill — call once on first app open after the feature ships.
  /// Evaluates all static signals server-side from existing data.
  Future<void> backfillForUser(String uid) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('backfillProgress').call();
    } catch (e) {
      debugPrint('AchievementService: backfill error: $e');
    }
  }
}
