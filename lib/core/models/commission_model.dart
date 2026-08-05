import 'package:cloud_firestore/cloud_firestore.dart';

enum CommissionType { referral, coachSession, programSale, gymPremiumShare }

enum CommissionStatus { pending, approved, paid, rejected }

extension CommissionTypeX on CommissionType {
  String get firestoreValue => name;

  String get displayName => switch (this) {
        CommissionType.referral => 'Referral',
        CommissionType.coachSession => 'Coaching Session',
        CommissionType.programSale => 'Program Sale',
        // Faz 6 §6.6 — a gym's revenue share of an attributed member's
        // premium purchase, distinct from the flat personal `referral` reward.
        CommissionType.gymPremiumShare => 'Gym Premium Referral',
      };

  static CommissionType fromString(String? v) => switch (v) {
        'coachSession' => CommissionType.coachSession,
        'programSale' => CommissionType.programSale,
        'gymPremiumShare' => CommissionType.gymPremiumShare,
        _ => CommissionType.referral,
      };
}

extension CommissionStatusX on CommissionStatus {
  String get firestoreValue => name;

  static CommissionStatus fromString(String? v) => switch (v) {
        'approved' => CommissionStatus.approved,
        'paid' => CommissionStatus.paid,
        'rejected' => CommissionStatus.rejected,
        _ => CommissionStatus.pending,
      };
}

class CommissionModel {
  final String id;
  final String ownerUid;
  final String? refereeUid;
  final String? refereeName;
  final CommissionType type;
  final CommissionStatus status;
  final double amount;
  final String? description;
  final DateTime createdAt;
  final DateTime? paidAt;

  const CommissionModel({
    required this.id,
    required this.ownerUid,
    this.refereeUid,
    this.refereeName,
    required this.type,
    required this.status,
    required this.amount,
    this.description,
    required this.createdAt,
    this.paidAt,
  });

  bool get isPending => status == CommissionStatus.pending;
  bool get isPaid => status == CommissionStatus.paid;

  factory CommissionModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CommissionModel(
      id: doc.id,
      ownerUid: d['owner_uid'] as String? ?? '',
      refereeUid: d['referee_uid'] as String?,
      refereeName: d['referee_name'] as String?,
      type: CommissionTypeX.fromString(d['type'] as String?),
      status: CommissionStatusX.fromString(d['status'] as String?),
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      description: d['description'] as String?,
      createdAt: d['created_at'] is Timestamp
          ? (d['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      paidAt: d['paid_at'] is Timestamp
          ? (d['paid_at'] as Timestamp).toDate()
          : null,
    );
  }
}
