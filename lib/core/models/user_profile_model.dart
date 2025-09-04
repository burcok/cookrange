import 'user_model.dart';
import 'login_history_model.dart';
import 'user_activity_model.dart';

/// A composite model that holds all information related to a user profile,
/// including their main data and historical activity.
class UserProfile {
  final UserModel user;
  final List<LoginHistoryItem> loginHistory;
  final List<UserActivityItem> userActivity;

  UserProfile({
    required this.user,
    required this.loginHistory,
    required this.userActivity,
  });
}
