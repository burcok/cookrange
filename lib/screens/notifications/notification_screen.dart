import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';

import '../../core/models/notification_model.dart';
import '../../core/services/notification_service.dart';
import '../community/widgets/community_widgets.dart';
import '../../core/services/friend_service.dart';
import '../../screens/community/widgets/glass_refresher.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/ds/ds.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final NotificationService _service = NotificationService();
  final FriendService _friendService = FriendService();

  late final StreamSubscription<List<NotificationModel>> _sub;
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _hasAutoMarkedRead = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _sub = _service.getNotificationsStream().listen(_onData);
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  void _onData(List<NotificationModel> notifications) {
    if (!mounted) return;
    setState(() {
      _notifications = notifications;
      _isLoading = false;
    });

    // Auto-mark unread as read exactly once when screen first loads
    if (!_hasAutoMarkedRead) {
      _hasAutoMarkedRead = true;
      final unreadIds =
          notifications.where((n) => !n.isRead).map((n) => n.id).toList();
      if (unreadIds.isNotEmpty) {
        _service.markMultipleAsRead(unreadIds);
      }
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    await _service.markMultipleAsRead(unread.map((n) => n.id).toList());
    // Stream will update automatically
  }

  Future<void> _delete(String id) async {
    await _service.deleteNotification(id);
    // Optimistic update — stream will confirm
    if (mounted) {
      setState(() => _notifications.removeWhere((n) => n.id == id));
    }
  }

  Future<void> _acceptRequest(
      String senderId, String notificationId) async {
    try {
      await _friendService.acceptFriendRequest(context, senderId);
      if (mounted) {
        setState(
            () => _notifications.removeWhere((n) => n.id == notificationId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).translate(
                'community.action_failed',
                variables: {'error': e.toString()}))));
      }
    }
  }

  Future<void> _rejectRequest(
      String senderId, String notificationId) async {
    try {
      await _friendService.rejectFriendRequest(senderId);
      await _delete(notificationId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)
                .translate('community.friend_request_rejected'))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).translate(
                'community.action_failed',
                variables: {'error': e.toString()}))));
      }
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
    final palette = AppPalette.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background elements
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: palette.isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: primaryColor.withValues(alpha: 0.3),
                        blurRadius: 100)
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
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.info.withValues(alpha: palette.isDark ? 0.15 : 0.25),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                  color: palette.fat.withValues(alpha: palette.isDark ? 0.1 : 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: palette.fat.withValues(alpha: 0.2),
                        blurRadius: 150)
                  ]),
            ),
          ),

          Container(
            decoration: BoxDecoration(
              color: palette.background.withValues(alpha: 0.8),
            ),
            child: Column(
              children: [
                SizedBox(
                    height: MediaQuery.of(context).padding.top + 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 24),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back,
                            color: palette.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).translate(
                          'community.notifications_title'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: palette.textPrimary,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(right: 24),
                      child: IconButton(
                        icon: Icon(Icons.done_all,
                            color: palette.textSecondary),
                        onPressed: _markAllRead,
                        tooltip: AppLocalizations.of(context)
                            .translate('community.mark_all_read'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Filters
                SizedBox(
                  height: 48,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildFilterChip('all',
                          AppLocalizations.of(context).translate('community.all'),
                          primaryColor, palette),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                          'unread',
                          AppLocalizations.of(context)
                              .translate('community.unread'),
                          primaryColor,
                          palette),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                          'friends',
                          AppLocalizations.of(context)
                              .translate('community.friends'),
                          primaryColor,
                          palette),
                      const SizedBox(width: 12),
                      _buildFilterChip(
                          'system',
                          AppLocalizations.of(context)
                              .translate('community.system'),
                          primaryColor,
                          palette),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // List
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                              color: primaryColor))
                      : _filteredNotifications.isEmpty
                          ? _buildEmptyState(context, palette)
                          : GlassRefresher(
                              onRefresh: () async {
                                // Stream keeps data live; nothing to do
                              },
                              topPadding:
                                  MediaQuery.of(context).padding.top + 24,
                              child: ListView.separated(
                                physics:
                                    const BouncingScrollPhysics(
                                        parent:
                                            AlwaysScrollableScrollPhysics()),
                                padding: const EdgeInsets.fromLTRB(
                                    24, 24, 24, 100),
                                itemCount:
                                    _filteredNotifications.length,
                                separatorBuilder: (c, i) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final n =
                                      _filteredNotifications[index];
                                  return _buildNotificationCard(
                                      n, palette, primaryColor);
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
      String filterId, String label, Color primaryColor, AppPalette palette) {
    final isSelected = _selectedFilter == filterId;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = filterId),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor
              : palette.surface.withValues(alpha: palette.isDark ? 0.05 : 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : palette.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
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
                  : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 64, color: palette.textTertiary),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)
                .translate('community.no_notifications'),
            style: TextStyle(
              fontSize: 16,
              color: palette.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      NotificationModel notification, AppPalette palette, Color primaryColor) {
    Color iconBgColor;
    Color iconColor;
    IconData iconData;
    String headerText;

    switch (notification.type) {
      case NotificationType.like:
        iconBgColor = palette.error.withValues(alpha: 0.15);
        iconColor = palette.error;
        iconData = Icons.favorite;
        headerText = AppLocalizations.of(context)
            .translate('community.friends');
        break;
      case NotificationType.comment:
        iconBgColor = palette.info.withValues(alpha: 0.15);
        iconColor = palette.info;
        iconData = Icons.chat_bubble;
        headerText = AppLocalizations.of(context)
            .translate('community.friends');
        break;
      case NotificationType.friend_request:
        iconBgColor = palette.fat.withValues(alpha: 0.15);
        iconColor = palette.fat;
        iconData = Icons.person_add;
        headerText = AppLocalizations.of(context)
            .translate('community.friends');
        break;
      case NotificationType.friend_accepted:
        iconBgColor = palette.success.withValues(alpha: 0.15);
        iconColor = palette.success;
        iconData = Icons.person_add;
        headerText = AppLocalizations.of(context)
            .translate('community.friends');
        break;
      case NotificationType.system:
        iconBgColor = palette.warning.withValues(alpha: 0.15);
        iconColor = palette.warning;
        iconData = Icons.system_update;
        headerText = AppLocalizations.of(context)
            .translate('community.system');
        break;
      default:
        iconBgColor = primaryColor.withValues(alpha: 0.15);
        iconColor = primaryColor;
        iconData = Icons.notifications;
        headerText = AppLocalizations.of(context)
            .translate('community.system');
    }

    if (notification.title.contains("Plan") ||
        notification.title.contains("Yemek")) {
      iconBgColor = palette.success.withValues(alpha: 0.15);
      iconColor = palette.success;
      iconData = Icons.restaurant;
      headerText = "Meal Plan";
    }
    if (notification.title.contains("Water") ||
        notification.title.contains("Su")) {
      iconBgColor = palette.info.withValues(alpha: 0.15);
      iconColor = palette.info;
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
          color: palette.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GlassContainer(
        enableBlur: false,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(16),
        opacity: palette.isDark ? 0.6 : 0.9,
        color: palette.surface,
        child: Stack(
          children: [
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
                            color: primaryColor.withValues(alpha: 0.3),
                            blurRadius: 4)
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
                        headerText,
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
                          color: palette.textPrimary,
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
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatRelativeTime(notification.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: palette.textTertiary,
                        ),
                      ),
                      if (notification.type ==
                              NotificationType.friend_request &&
                          notification.relatedId != null) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _acceptRequest(
                                  notification.relatedId!,
                                  notification.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                        color: primaryColor
                                            .withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2))
                                  ],
                                ),
                                child: Text(
                                    AppLocalizations.of(context)
                                        .translate('friend_actions.accept'),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _rejectRequest(
                                  notification.relatedId!,
                                  notification.id),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: palette.surface,
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                      color: palette.error.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                    AppLocalizations.of(context)
                                        .translate('friend_actions.reject'),
                                    style: TextStyle(
                                        color: palette.error,
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

  String _formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return "${diff.inMinutes} ${AppLocalizations.of(context).translate('community.time.min')}";
    }
    if (diff.inHours < 24) {
      return "${diff.inHours} ${AppLocalizations.of(context).translate('community.time.hour')}";
    }
    return "${diff.inDays} ${AppLocalizations.of(context).translate('community.time.day')}";
  }
}
