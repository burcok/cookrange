enum NotificationType {
  like,
  comment,
  system,
  follow,
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  bool isRead;
  final NotificationType type;
  final String? relatedId; // e.g. postId or userId

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.relatedId,
  });
}
