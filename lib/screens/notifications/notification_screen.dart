import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/community_service.dart';
import '../community/widgets/community_widgets.dart';
import '../../core/services/friend_service.dart';
import '../../screens/community/widgets/glass_refresher.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final CommunityService _service = CommunityService();
  final FriendService _friendService = FriendService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final notifications = await _service.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAll() async {
    await _service.clearAllNotifications();
    if (mounted) {
      setState(() {
        _notifications.clear();
      });
    }
  }

  Future<void> _delete(String id) async {
    await _service.deleteNotification(id);
    if (mounted) {
      setState(() {
        _notifications.removeWhere((n) => n.id == id);
      });
    }
  }

  Future<void> _acceptRequest(String senderId, String notificationId) async {
    try {
      await _friendService.acceptFriendRequest(senderId);
      await _delete(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Friend request accepted!")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Future<void> _rejectRequest(String senderId, String notificationId) async {
    try {
      await _friendService.rejectFriendRequest(senderId);
      await _delete(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Friend request rejected.")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        forceMaterialTransparency: true,
        leading:
            BackButton(color: isDark ? Colors.white : const Color(0xFF0F172A)),
        title: Text(
          AppLocalizations.of(context).translate('community.notifications'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _clearAll,
              child: Text(
                AppLocalizations.of(context).translate('community.clear_all'),
                style: const TextStyle(
                    color: Color(0xFFF97316), fontWeight: FontWeight.w600),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF8FAFC), // Fallback bg if no underlying stack
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFF97316)))
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)
                              .translate('community.no_notifications'),
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GlassRefresher(
                    onRefresh: _loadNotifications,
                    topPadding: MediaQuery.of(context).padding.top + 60,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 100, 20, 30),
                      itemCount: _notifications.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final notification = _notifications[index];
                        return Dismissible(
                          key: Key(notification.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _delete(notification.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: Colors.red[400],
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          child: GlassContainer(
                            borderRadius: BorderRadius.circular(16),
                            color:
                                isDark ? const Color(0xFF1E293B) : Colors.white,
                            opacity: 0.7,
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                _buildIcon(notification.type),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notification.body,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _formatTime(notification.timestamp),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      if (notification.type ==
                                              NotificationType.friend_request &&
                                          notification.relatedId != null) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            ElevatedButton(
                                              onPressed: () async {
                                                // Accept logic
                                                await _acceptRequest(
                                                    notification.relatedId!,
                                                    notification.id);
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                minimumSize: Size.zero,
                                                textStyle: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                              child: const Text("Accept"),
                                            ),
                                            const SizedBox(width: 8),
                                            OutlinedButton(
                                              onPressed: () async {
                                                // Reject logic
                                                await _rejectRequest(
                                                    notification.relatedId!,
                                                    notification.id);
                                              },
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 16,
                                                        vertical: 8),
                                                minimumSize: Size.zero,
                                                textStyle: const TextStyle(
                                                    fontSize: 12),
                                                side: const BorderSide(
                                                    color: Colors.red),
                                              ),
                                              child: const Text("Reject"),
                                            ),
                                          ],
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                                if (!notification.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF97316),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildIcon(NotificationType type) {
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.like:
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case NotificationType.comment:
        icon = Icons.chat_bubble;
        color = Colors.blue;
        break;
      case NotificationType.follow:
        icon = Icons.person_add;
        color = Colors.green;
        break;
      case NotificationType.friend_request:
        icon = Icons.person_add_alt_1;
        color = Colors.purple;
        break;
      case NotificationType.system:
        icon = Icons.notifications;
        color = const Color(0xFFF97316);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}
