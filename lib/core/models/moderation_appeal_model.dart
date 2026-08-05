import 'package:cloud_firestore/cloud_firestore.dart';
import 'community_group_model.dart'
    show GroupModerationAction, GroupModerationActionX;

/// A contested group moderation action (Faz 2 §2.6 — "itiraz yolu"),
/// `moderation_appeals/{id}`. Mirrors `PrivacyRequestModel`'s shape and
/// lifecycle deliberately: a client files its own record (create-only,
/// owner-scoped), an admin reviews and resolves it later (update-only,
/// admin-scoped) — no callable, same as the DSAR channel this pattern is
/// copied from (see `docs/COMPLIANCE.md` §7).
///
/// The doc id IS the source `community_groups/{groupId}/moderation/{autoId}`
/// entry's own id (see `ModerationAppealService.file`) — at most one appeal
/// per action, and firestore.rules cross-checks via `get()` that the
/// referenced action really targets the caller.
///
/// Faz 5 §5.2 REUSES this exact collection/model/lifecycle for a second,
/// non-group appeal kind: `action == 'credit_restriction'` (a shadow
/// restriction — see `CreditRestrictionModel`/`CreditRestrictionScreen`).
/// That kind has no group at all, so `groupId`/`groupName` are simply empty
/// strings and `action` (the typed `GroupModerationAction` enum) is a
/// meaningless placeholder for it — `rawAction`/`isCreditRestriction` are
/// the fields any NEW code should actually branch on; `action` stays as-is
/// purely for the pre-existing group-appeal call sites, unchanged.
enum ModerationAppealStatus { pending, upheld, denied }

extension ModerationAppealStatusX on ModerationAppealStatus {
  String get key => switch (this) {
        ModerationAppealStatus.pending => 'pending',
        ModerationAppealStatus.upheld => 'upheld',
        ModerationAppealStatus.denied => 'denied',
      };

  String get labelKey => 'moderation_appeal.status.$key';

  static ModerationAppealStatus fromKey(String? k) => switch (k) {
        'upheld' => ModerationAppealStatus.upheld,
        'denied' => ModerationAppealStatus.denied,
        _ => ModerationAppealStatus.pending,
      };
}

class ModerationAppealModel {
  final String id;
  final String uid;
  final String groupId;
  final String groupName;
  final GroupModerationAction action;
  // The raw Firestore `action` string, captured independently of `action`
  // above (whose `GroupModerationActionX.fromString` silently defaults any
  // unrecognized value to `mute` — correct for the group-appeal path, wrong
  // for anything else). New code should branch on THIS, not `action`.
  final String rawAction;
  final String message;
  final ModerationAppealStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? adminNote;

  const ModerationAppealModel({
    required this.id,
    required this.uid,
    required this.groupId,
    required this.groupName,
    required this.action,
    required this.rawAction,
    required this.message,
    required this.status,
    this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.adminNote,
  });

  bool get isCreditRestriction => rawAction == 'credit_restriction';

  factory ModerationAppealModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    final rawAction = d['action'] as String? ?? '';
    return ModerationAppealModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      groupId: d['group_id'] as String? ?? '',
      groupName: d['group_name'] as String? ?? '',
      action: GroupModerationActionX.fromString(rawAction),
      rawAction: rawAction,
      message: d['message'] as String? ?? '',
      status: ModerationAppealStatusX.fromKey(d['status'] as String?),
      createdAt: ts(d['created_at']),
      resolvedAt: ts(d['resolved_at']),
      resolvedBy: d['resolved_by'] as String?,
      adminNote: d['admin_note'] as String?,
    );
  }

  Map<String, dynamic> toCreate() => {
        'uid': uid,
        'group_id': groupId,
        'group_name': groupName,
        'action': action.value,
        'message': message,
        'status': ModerationAppealStatus.pending.key,
        'created_at': FieldValue.serverTimestamp(),
      };

  /// Faz 5 §5.2 — the credit-restriction appeal's create map. A sibling to
  /// `toCreate()` above rather than a modification of it: no `groupId`/
  /// `action` enum involved, `action` is the literal string
  /// `'credit_restriction'` firestore.rules' new `moderation_appeals` branch
  /// checks for.
  static Map<String, dynamic> toCreateCreditRestriction({
    required String uid,
    required String message,
  }) =>
      {
        'uid': uid,
        'group_id': '',
        'group_name': '',
        'action': 'credit_restriction',
        'message': message,
        'status': ModerationAppealStatus.pending.key,
        'created_at': FieldValue.serverTimestamp(),
      };
}
