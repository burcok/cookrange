import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/notification_model.dart';
import '../../core/services/notification_service.dart';
import '../community/widgets/community_widgets.dart';
import '../../core/services/friend_service.dart';
import '../../screens/community/widgets/glass_refresher.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();
  final FriendService _friendService = FriendService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // all, unread, friends, system

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

  Future<void> _markAllRead() async {
    for (var n in _notifications) {
      if (!n.isRead) {
        await _service.markAsRead(n.id);
      }
    }
    await _loadNotifications();
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
      await _friendService.acceptFriendRequest(context, senderId);

      // Logic handles deletion in backend, but we remove from UI instantly for better UX
      setState(() {
        _notifications.removeWhere((n) => n.id == notificationId);
      });
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)
                .translate('community.friend_request_rejected'))));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  List<NotificationModel> get _filteredNotifications {
    switch (_selectedFilter) {
      case 'unread':
        return _notifications.where((n) => !n.isRead).toList();
      case 'friends':
        return _notifications
            .where((n) =>
                n.type == NotificationType.friend_request ||
                n.type == NotificationType.friend_accepted ||
                n.type == NotificationType.follow)
            .toList();
      case 'system':
        return _notifications
            .where((n) => n.type == NotificationType.system)
            .toList();
      default:
        return _notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background Elements
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                  color: primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: primaryColor.withOpacity(0.3), blurRadius: 100)
                  ]),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.5,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(isDark ? 0.1 : 0.2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.blue.withOpacity(0.2), blurRadius: 100)
                ],
              ),
              child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                  child: Container()), // Blur attempt
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(isDark ? 0.1 : 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.purple.withOpacity(0.2), blurRadius: 150)
                  ]),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withOpacity(0.8)
                  : const Color(0xFFF8FAFC).withOpacity(0.8),
            ),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).padding.top + 24),

                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(left: 24),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[600]),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)
                            .translate('community.notifications_title'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.grey[200] : Colors.grey[800],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 24),
                        child: IconButton(
                          icon: Icon(Icons.settings,
                              color:
                                  isDark ? Colors.grey[300] : Colors.grey[600]),
                          onPressed: () {
                            // Navigate to settings or show options
                          },
                        ),
                      ),
                    ]),
                SizedBox(height: 24),

                // Filters
                SizedBox(
                  height: 48,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildFilterChip(
                          'all',
                          AppLocalizations.of(context)
                              .translate('community.all'),
                          primaryColor,
                          isDark),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                          'unread',
                          AppLocalizations.of(context)
                              .translate('community.unread'),
                          primaryColor,
                          isDark),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                          'friends',
                          AppLocalizations.of(context)
                              .translate('community.friends'),
                          primaryColor,
                          isDark),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                          'system',
                          AppLocalizations.of(context)
                              .translate('community.system'),
                          primaryColor,
                          isDark),
                    ],
                  ),
                ),

                // Mark all Read Action
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: _markAllRead,
                        child: Row(
                          children: [
                            Icon(Icons.done_all, size: 16, color: primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              AppLocalizations.of(context)
                                  .translate('community.mark_all_read'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // List
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: primaryColor))
                      : _filteredNotifications.isEmpty
                          ? _buildEmptyState(context)
                          : GlassRefresher(
                              onRefresh: _loadNotifications,
                              topPadding:
                                  MediaQuery.of(context).padding.top + 24,
                              child: ListView.separated(
                                physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics()),
                                padding:
                                    const EdgeInsets.fromLTRB(24, 24, 24, 100),
                                itemCount: _filteredNotifications.length,
                                separatorBuilder: (c, i) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final notification =
                                      _filteredNotifications[index];
                                  return _buildNotificationCard(
                                      notification, isDark, primaryColor);
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String filterId, String label, Color primaryColor, bool isDark) {
    final isSelected = _selectedFilter == filterId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : (isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.6)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4))
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[300] : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
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
    );
  }

  Widget _buildNotificationCard(
      NotificationModel notification, bool isDark, Color primaryColor) {
    // Determine style based on type
    Color iconBgColor;
    Color iconColor;
    IconData iconData;
    String headerText;

    switch (notification.type) {
      case NotificationType.like:
        iconBgColor = isDark ? Colors.red.withOpacity(0.2) : Colors.red.shade50;
        iconColor = Colors.red;
        iconData = Icons.favorite;
        headerText = AppLocalizations.of(context)
            .translate('community.friends'); // Or "Community"
        break;
      case NotificationType.comment:
        iconBgColor =
            isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50;
        iconColor = Colors.blue;
        iconData = Icons.chat_bubble;
        headerText =
            AppLocalizations.of(context).translate('community.friends');
        break;
      case NotificationType.friend_request:
        iconBgColor =
            isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.shade50;
        iconColor = Colors.purple;
        iconData = Icons.person_add;
        headerText =
            AppLocalizations.of(context).translate('community.friends');
        break;
      case NotificationType.friend_accepted:
        iconBgColor =
            isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50;
        iconColor = Colors.green;
        iconData = Icons.person_add;
        headerText =
            AppLocalizations.of(context).translate('community.friends');
        break;
      case NotificationType.system:
        iconBgColor = isDark
            ? Colors.amber.withOpacity(0.2)
            : Colors.amber.shade50; // Or slate
        iconColor = Colors.amber.shade800;
        iconData = Icons.system_update;
        headerText = AppLocalizations.of(context).translate('community.system');
        break;
      default:
        iconBgColor = isDark
            ? primaryColor.withOpacity(0.2)
            : primaryColor.withOpacity(0.1);
        iconColor = primaryColor;
        iconData = Icons.notifications;
        headerText = AppLocalizations.of(context).translate('community.system');
    }

    // Override for specific "Meal Plan" if title matches
    if (notification.title.contains("Plan") ||
        notification.title.contains("Yemek")) {
      iconBgColor =
          isDark ? Colors.green.withOpacity(0.2) : Colors.green.shade50;
      iconColor = Colors.green;
      iconData = Icons.restaurant;
      headerText = "Meal Plan"; // Localization needed
    }
    // Override for "Water"
    if (notification.title.contains("Water") ||
        notification.title.contains("Su")) {
      iconBgColor = isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.shade50;
      iconColor = Colors.blue;
      iconData = Icons.water_drop;
      headerText = "Goal";
    }

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(notification.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red[400],
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GlassContainer(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        opacity: isDark ? 0.6 : 0.7,
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Stack(
          children: [
            // Unread dot
            if (!notification.isRead)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: primaryColor.withOpacity(0.3), blurRadius: 4)
                      ]),
                ),
              ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(iconData, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerText, // Category
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.grey[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTime(notification.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),

                      // Actions for Friend Request
                      if (notification.type ==
                              NotificationType.friend_request &&
                          notification.relatedId != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _acceptRequest(
                                  notification.relatedId!, notification.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                        color: primaryColor.withOpacity(0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                child: const Text("Accept",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _rejectRequest(
                                  notification.relatedId!, notification.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withOpacity(0.05)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: Colors.red.withOpacity(0.5)),
                                ),
                                child: const Text("Reject",
                                    style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ]
                    ],
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60)
      return "${diff.inMinutes} ${AppLocalizations.of(context).translate('community.time.min')}";
    if (diff.inHours < 24)
      return "${diff.inHours} ${AppLocalizations.of(context).translate('community.time.hour')}";
    return "${diff.inDays} ${AppLocalizations.of(context).translate('community.time.day')}";
  }
}
