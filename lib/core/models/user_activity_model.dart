import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single event from the `user_activity` sub-collection.
class UserActivityItem {
  final String id;
  final String eventType;
  final Timestamp timestamp;
  final String? ipAddress;
  final Map<String, dynamic> fullData;

  UserActivityItem({
    required this.id,
    required this.eventType,
    required this.timestamp,
    this.ipAddress,
    required this.fullData,
  });

  /// Creates a UserActivityItem from a Firestore document snapshot.
  factory UserActivityItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserActivityItem(
      id: doc.id,
      eventType: data['event_type'] as String? ?? 'unknown',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      ipAddress: data['ip_address'] as String?,
      fullData: data,
    );
  }

  /// Creates a UserActivityItem from a Map (for array storage).
  factory UserActivityItem.fromMap(Map<String, dynamic> data) {
    return UserActivityItem(
      id: data['id'] as String? ?? '',
      eventType: data['event_type'] as String? ?? 'unknown',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      ipAddress: data['ip_address'] as String?,
      fullData: data,
    );
  }

  /// Converts UserActivityItem to a Map for storage.
  Map<String, dynamic> toMap() {
    return fullData;
  }
}
