import 'package:cloud_firestore/cloud_firestore.dart';

enum GymWarStatus { pending, active, ended }

enum GymWarMetric { checkins }

extension GymWarStatusX on GymWarStatus {
  String get firestoreValue => name;

  static GymWarStatus fromString(String? v) => switch (v) {
        'active' => GymWarStatus.active,
        'ended' => GymWarStatus.ended,
        _ => GymWarStatus.pending,
      };
}

extension GymWarMetricX on GymWarMetric {
  String get firestoreValue => name;

  static GymWarMetric fromString(String? v) => switch (v) {
        'checkins' => GymWarMetric.checkins,
        _ => GymWarMetric.checkins,
      };

  String get displayLabel => switch (this) {
        GymWarMetric.checkins => 'Check-ins',
      };
}

class GymWarModel {
  final String id;
  final String gymAId;
  final String gymBId;
  final String gymAName;
  final String gymBName;
  final String challengerUid;
  final GymWarStatus status;
  final GymWarMetric metric;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  const GymWarModel({
    required this.id,
    required this.gymAId,
    required this.gymBId,
    required this.gymAName,
    required this.gymBName,
    required this.challengerUid,
    required this.status,
    required this.metric,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  bool get isActive =>
      status == GymWarStatus.active && endDate.isAfter(DateTime.now());

  bool get hasEnded =>
      status == GymWarStatus.ended || endDate.isBefore(DateTime.now());

  int get daysRemaining =>
      endDate.difference(DateTime.now()).inDays.clamp(0, 999);

  factory GymWarModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();

    return GymWarModel(
      id: doc.id,
      gymAId: d['gym_a_id'] as String? ?? '',
      gymBId: d['gym_b_id'] as String? ?? '',
      gymAName: d['gym_a_name'] as String? ?? '',
      gymBName: d['gym_b_name'] as String? ?? '',
      challengerUid: d['challenger_uid'] as String? ?? '',
      status: GymWarStatusX.fromString(d['status'] as String?),
      metric: GymWarMetricX.fromString(d['metric'] as String?),
      startDate: ts(d['start_date']),
      endDate: ts(d['end_date']),
      createdAt: ts(d['created_at']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'gym_a_id': gymAId,
        'gym_b_id': gymBId,
        'gym_a_name': gymAName,
        'gym_b_name': gymBName,
        'challenger_uid': challengerUid,
        'status': status.firestoreValue,
        'metric': metric.firestoreValue,
        'start_date': Timestamp.fromDate(startDate),
        'end_date': Timestamp.fromDate(endDate),
        'created_at': Timestamp.fromDate(createdAt),
      };
}
