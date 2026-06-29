import 'package:cloud_firestore/cloud_firestore.dart';

/// A data-subject request (KVKK Art. 11 / GDPR Art. 15–22). Self-service export
/// and deletion already exist; this covers the remaining rights and provides a
/// documented, auditable channel with statutory response times.
enum PrivacyRequestType {
  access,
  rectification,
  erasure,
  restriction,
  objection,
  portability,
  withdrawConsent,
  other,
}

extension PrivacyRequestTypeX on PrivacyRequestType {
  String get key => switch (this) {
        PrivacyRequestType.access => 'access',
        PrivacyRequestType.rectification => 'rectification',
        PrivacyRequestType.erasure => 'erasure',
        PrivacyRequestType.restriction => 'restriction',
        PrivacyRequestType.objection => 'objection',
        PrivacyRequestType.portability => 'portability',
        PrivacyRequestType.withdrawConsent => 'withdraw_consent',
        PrivacyRequestType.other => 'other',
      };

  String get titleKey => 'privacy_request.type.$key';

  static PrivacyRequestType fromKey(String? k) {
    for (final t in PrivacyRequestType.values) {
      if (t.key == k) return t;
    }
    return PrivacyRequestType.other;
  }
}

enum PrivacyRequestStatus { pending, inProgress, resolved, rejected }

extension PrivacyRequestStatusX on PrivacyRequestStatus {
  String get key => switch (this) {
        PrivacyRequestStatus.pending => 'pending',
        PrivacyRequestStatus.inProgress => 'in_progress',
        PrivacyRequestStatus.resolved => 'resolved',
        PrivacyRequestStatus.rejected => 'rejected',
      };

  String get labelKey => 'privacy_request.status.$key';

  static PrivacyRequestStatus fromKey(String? k) => switch (k) {
        'in_progress' => PrivacyRequestStatus.inProgress,
        'resolved' => PrivacyRequestStatus.resolved,
        'rejected' => PrivacyRequestStatus.rejected,
        _ => PrivacyRequestStatus.pending,
      };
}

class PrivacyRequestModel {
  final String id;
  final String uid;
  final String email;
  final PrivacyRequestType type;
  final String message;
  final PrivacyRequestStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? adminNote;

  const PrivacyRequestModel({
    required this.id,
    required this.uid,
    required this.email,
    required this.type,
    required this.message,
    required this.status,
    this.createdAt,
    this.resolvedAt,
    this.adminNote,
  });

  factory PrivacyRequestModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return PrivacyRequestModel(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      email: d['email'] as String? ?? '',
      type: PrivacyRequestTypeX.fromKey(d['type'] as String?),
      message: d['message'] as String? ?? '',
      status: PrivacyRequestStatusX.fromKey(d['status'] as String?),
      createdAt: ts(d['created_at']),
      resolvedAt: ts(d['resolved_at']),
      adminNote: d['admin_note'] as String?,
    );
  }

  Map<String, dynamic> toCreate() => {
        'uid': uid,
        'email': email,
        'type': type.key,
        'message': message,
        'status': PrivacyRequestStatus.pending.key,
        'created_at': FieldValue.serverTimestamp(),
      };
}
