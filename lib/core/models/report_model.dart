import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a community content report stored in `reports/{id}`.
class ReportModel {
  final String id;
  final String reporterId;
  final String targetType; // 'post' | 'comment'
  final String targetId;
  final String postId;
  final String? authorId;
  final String reason;
  final String status; // 'pending' | 'dismissed' | 'removed'
  final DateTime? timestamp;

  const ReportModel({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.postId,
    this.authorId,
    required this.reason,
    required this.status,
    this.timestamp,
  });

  factory ReportModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ReportModel(
      id: doc.id,
      reporterId: d['reporterId'] as String? ?? '',
      targetType: d['targetType'] as String? ?? 'post',
      targetId: d['targetId'] as String? ?? '',
      postId: d['postId'] as String? ?? '',
      authorId: d['authorId'] as String?,
      reason: d['reason'] as String? ?? '',
      status: d['status'] as String? ?? 'pending',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}
