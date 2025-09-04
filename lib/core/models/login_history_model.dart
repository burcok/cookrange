import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single login event from the `login_history` sub-collection.
class LoginHistoryItem {
  final String id;
  final Timestamp timestamp;
  final String? ipAddress;
  final String? deviceModel;
  final String? deviceType;
  final String? deviceOs;

  LoginHistoryItem({
    required this.id,
    required this.timestamp,
    this.ipAddress,
    this.deviceModel,
    this.deviceType,
    this.deviceOs,
  });

  /// Creates a LoginHistoryItem from a Firestore document snapshot.
  factory LoginHistoryItem.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return LoginHistoryItem(
      id: doc.id,
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      ipAddress: data['ip_address'] as String?,
      deviceModel: data['device_model'] as String?,
      deviceType: data['device_type'] as String?,
      deviceOs: data['device_os'] as String?,
    );
  }
}
