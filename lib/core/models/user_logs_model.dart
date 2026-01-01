import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_history_model.dart';
import 'user_activity_model.dart';

/// Represents the complete logs for a user stored in the separate logs collection.
/// This includes both login history and user activity in a single document.
class UserLogs {
  final String userId;
  final List<LoginHistoryItem> loginHistory;
  final List<UserActivityItem> userActivity;
  final Timestamp? lastUpdated;

  UserLogs({
    required this.userId,
    required this.loginHistory,
    required this.userActivity,
    this.lastUpdated,
  });

  /// Creates a UserLogs from a Firestore document snapshot.
  factory UserLogs.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // Parse login history array
    final loginHistoryData = data['login_history'] as List<dynamic>? ?? [];
    final loginHistory = loginHistoryData
        .map((item) => LoginHistoryItem.fromMap(item as Map<String, dynamic>))
        .toList();

    // Parse user activity array
    final userActivityData = data['user_activity'] as List<dynamic>? ?? [];
    final userActivity = userActivityData
        .map((item) => UserActivityItem.fromMap(item as Map<String, dynamic>))
        .toList();

    return UserLogs(
      userId: doc.id,
      loginHistory: loginHistory,
      userActivity: userActivity,
      lastUpdated: data['last_updated'] as Timestamp?,
    );
  }

  /// Converts UserLogs to a Map for Firestore storage.
  Map<String, dynamic> toFirestore() {
    return {
      'login_history': loginHistory.map((item) => item.toMap()).toList(),
      'user_activity': userActivity.map((item) => item.toMap()).toList(),
      'last_updated': FieldValue.serverTimestamp(),
    };
  }
}
