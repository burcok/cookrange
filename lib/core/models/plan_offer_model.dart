import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/plan_offers/{offerId}` (Faz 3 §3.2) — a
/// `meal_plan_templates/{id}` sent to this user by a gym/coach/admin.
///
/// `create` is server-only (`sendPlanOffer` callable, `functions/
/// templates.js`) — a client can never plant an offer on itself or forge who
/// it's from. The recipient may only move `status`/`respondedAt` (accept /
/// decline), never rewrite [fromUid]/[templateSnapshot] (`firestore.rules`).
///
/// [templateSnapshot] is an **immutable copy** of the template's fields
/// taken at send time, not a live reference — if the source
/// `meal_plan_templates/{id}` is edited or deleted afterward, this offer is
/// unaffected. Left as a raw map (rather than eagerly parsed into a
/// `MealPlanTemplate`) since rendering/accepting it is §3.5's job, not
/// built here; a future caller can do
/// `MealPlanTemplate.fromJson(offer.templateSnapshot, offer.templateId)`.
class PlanOffer {
  final String id;
  final String templateId;
  final Map<String, dynamic> templateSnapshot;
  final String fromUid;

  /// 'gym' | 'coach' | 'admin' — mirrors the source template's `author_type`
  /// at send time.
  final String fromType;
  final String fromName;
  final String? message;

  /// 'pending' | 'accepted' | 'declined' | 'expired'.
  final String status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  const PlanOffer({
    required this.id,
    required this.templateId,
    this.templateSnapshot = const {},
    required this.fromUid,
    required this.fromType,
    this.fromName = '',
    this.message,
    this.status = 'pending',
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';

  /// True once past [expiresAt], regardless of the persisted `status` — the
  /// server-side expiry sweep (§3.5) flips `status` to 'expired' but may lag
  /// by up to its own run interval; this lets the client show "expired"
  /// immediately rather than trusting a stale 'pending'.
  bool get isExpired =>
      status == 'expired' || (isPending && DateTime.now().isAfter(expiresAt));

  factory PlanOffer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PlanOffer.fromJson(data, doc.id);
  }

  factory PlanOffer.fromJson(Map<String, dynamic> json, [String? id]) {
    final rawSnapshot = json['template_snapshot'];
    return PlanOffer(
      id: id ?? json['id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      templateSnapshot: rawSnapshot is Map
          ? Map<String, dynamic>.from(rawSnapshot)
          : const {},
      fromUid: json['from_uid'] as String? ?? '',
      fromType: json['from_type'] as String? ?? 'admin',
      fromName: json['from_name'] as String? ?? '',
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: (json['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (json['expires_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (json['responded_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'template_id': templateId,
      'template_snapshot': templateSnapshot,
      'from_uid': fromUid,
      'from_type': fromType,
      'from_name': fromName,
      'message': message,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      'expires_at': Timestamp.fromDate(expiresAt),
      'responded_at':
          respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
    };
  }
}
