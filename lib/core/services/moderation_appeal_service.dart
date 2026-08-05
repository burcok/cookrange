import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/community_group_model.dart';
import '../models/moderation_appeal_model.dart';
import 'crashlytics_service.dart';

/// Faz 2 §2.6 — appeal path for a group moderation action (mute/kick/ban).
/// Mirrors `PrivacyRequestService` exactly: client files its own record,
/// admin reviews/resolves later (`AdminService.resolveModerationAppeal`) —
/// no callable, same DSAR-style pattern documented in `docs/COMPLIANCE.md`.
class ModerationAppealService {
  static final ModerationAppealService _instance =
      ModerationAppealService._internal();
  factory ModerationAppealService() => _instance;
  ModerationAppealService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('moderation_appeals');

  /// Files an appeal against one specific moderation action. [moderationActionId]
  /// becomes the appeal doc's own id (firestore.rules relies on this: it
  /// `get()`s `community_groups/{groupId}/moderation/{moderationActionId}`
  /// using the SAME id to confirm the action is real and targets the
  /// caller) — at most one appeal per action, enforced by Firestore's
  /// create-vs-update semantics rather than a query.
  Future<void> file({
    required String groupId,
    required String groupName,
    required String moderationActionId,
    required GroupModerationAction action,
    required String message,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    try {
      final model = ModerationAppealModel(
        id: moderationActionId,
        uid: uid,
        groupId: groupId,
        groupName: groupName,
        action: action,
        rawAction: action.value,
        message: message.trim(),
        status: ModerationAppealStatus.pending,
      );
      await _col.doc(moderationActionId).set(model.toCreate());
      debugPrint(
          '[ModerationAppealService] filed appeal $moderationActionId for group $groupId');
    } catch (e, st) {
      debugPrint('[ModerationAppealService] file error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'ModerationAppealService.file'));
      rethrow;
    }
  }

  /// Faz 5 §5.2 — appeal against a shadow-restriction (`credit_moderation`
  /// log entry, not a group moderation action). [creditModerationEntryId]
  /// becomes the appeal doc's own id, mirroring [file]'s exact idempotency
  /// idea — firestore.rules' `moderation_appeals` create rule cross-checks
  /// `users/{callerUid}/credit_moderation/{this id}.action == 'restrict'`
  /// via `get()`, so a client can't appeal a restriction that isn't theirs
  /// or doesn't exist.
  Future<void> fileCreditRestrictionAppeal({
    required String creditModerationEntryId,
    required String message,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');
    try {
      await _col.doc(creditModerationEntryId).set(
            ModerationAppealModel.toCreateCreditRestriction(
              uid: uid,
              message: message.trim(),
            ),
          );
      debugPrint(
          '[ModerationAppealService] filed credit-restriction appeal $creditModerationEntryId');
    } catch (e, st) {
      debugPrint(
          '[ModerationAppealService] fileCreditRestrictionAppeal error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'ModerationAppealService.fileCreditRestrictionAppeal'));
      rethrow;
    }
  }

  /// Live status of the appeal for one specific moderation action, if any
  /// exists yet — backs the inline "Appeal" / "Pending review" / "Upheld" /
  /// "Denied" state per row on the moderation-history screen.
  Stream<ModerationAppealModel?> watchAppeal(String moderationActionId) {
    return _col
        .doc(moderationActionId)
        .snapshots()
        .map((d) => d.exists ? ModerationAppealModel.fromFirestore(d) : null);
  }
}
