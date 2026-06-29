import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';

import '../../core/models/notification_model.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/notification_presenter.dart';
import '../../core/utils/profile_navigation.dart';
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
  final ScrollController _scrollController = ScrollController();

  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    unawaited(_loadInitialPage());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore &&
        _selectedFilter == 'all') {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadInitialPage() async {
    setState(() {
      _isLoading = true;
      _notifications = [];
      _lastDoc = null;
      _hasMore = true;
    });
    try {
      final result = await _service.getNotificationsPage();
      if (!mounted) return;
      setState(() {
        _notifications = result.items;
        _lastDoc = result.lastDoc;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
      final unreadIds =
          result.items.where((n) => !n.isRead).map((n) => n.id).toList();
      if (unreadIds.isNotEmpty) {
        unawaited(_service.markMultipleAsRead(unreadIds));
      }
    } catch (e) {
      debugPrint('NotificationScreen._loadInitialPage error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.getNotificationsPage(lastDoc: _lastDoc);
      if (!mounted) return;
      setState(() {
        final existingIds = _notifications.map((n) => n.id).toSet();
        final newItems =
            result.items.where((n) => !existingIds.contains(n.id)).toList();
        _notifications.addAll(newItems);
        _lastDoc = result.lastDoc;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      debugPrint('NotificationScreen._loadMore error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    await _service.markMultipleAsRead(unread.map((n) => n.id).toList());
    if (mounted) {
      setState(() {
        _notifications = _notifications
            .map((n) => n.isRead ? n : n.copyWithRead())
            .toList();
      });
    }
  }

  Future<void> _delete(String id) async {
    if (mounted) setState(() => _notifications.removeWhere((n) => n.id == id));
    await _service.deleteNotification(id);
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
                n.type == NotificationType.friendRequest ||
                n.type == NotificationType.friendAccepted ||
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
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Mesh-glow ambient background — brand blob top-right
          Positioned(
            top: -80,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primaryColor.withValues(
                          alpha: palette.isDark ? 0.09 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Mesh-glow ambient background — info blob bottom-left
          Positioned(
            bottom: 80,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.info.withValues(
                          alpha: palette.isDark ? 0.07 : 0.05),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content column
          Column(
            children: [
              // ── AppBar with gradient accent line at bottom ──
              _NotificationAppBar(
                primaryColor: primaryColor,
                palette: palette,
                onBack: () => Navigator.pop(context),
                onMarkAllRead: _markAllRead,
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Glassmorphism filter chips ──
              SizedBox(
                height: 44,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl),
                  children: [
                    _GlassFilterChip(
                      filterId: 'all',
                      label: AppLocalizations.of(context)
                          .translate('community.all'),
                      selectedFilter: _selectedFilter,
                      primaryColor: primaryColor,
                      palette: palette,
                      onTap: () =>
                          setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _GlassFilterChip(
                      filterId: 'unread',
                      label: AppLocalizations.of(context)
                          .translate('community.unread'),
                      selectedFilter: _selectedFilter,
                      primaryColor: primaryColor,
                      palette: palette,
                      onTap: () =>
                          setState(() => _selectedFilter = 'unread'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _GlassFilterChip(
                      filterId: 'friends',
                      label: AppLocalizations.of(context)
                          .translate('community.friends'),
                      selectedFilter: _selectedFilter,
                      primaryColor: primaryColor,
                      palette: palette,
                      onTap: () =>
                          setState(() => _selectedFilter = 'friends'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _GlassFilterChip(
                      filterId: 'system',
                      label: AppLocalizations.of(context)
                          .translate('community.system'),
                      selectedFilter: _selectedFilter,
                      primaryColor: primaryColor,
                      palette: palette,
                      onTap: () =>
                          setState(() => _selectedFilter = 'system'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // ── Notification list ──
              Expanded(
                child: _isLoading
                    ? _buildLoadingState(primaryColor, palette)
                    : _filteredNotifications.isEmpty
                        ? _buildEmptyState(context)
                        : GlassRefresher(
                            onRefresh: _loadInitialPage,
                            topPadding:
                                MediaQuery.of(context).padding.top + 24,
                            child: ListView.separated(
                              controller: _selectedFilter == 'all'
                                  ? _scrollController
                                  : null,
                              physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics()),
                              padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.xl,
                                  AppSpacing.lg,
                                  AppSpacing.xl,
                                  100),
                              itemCount: _filteredNotifications.length +
                                  (_selectedFilter == 'all' &&
                                          (_isLoadingMore || _hasMore)
                                      ? 1
                                      : 0),
                              separatorBuilder: (c, i) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                if (index ==
                                    _filteredNotifications.length) {
                                  return _isLoadingMore
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(
                                                AppSpacing.md),
                                            child:
                                                CircularProgressIndicator(
                                                    color: primaryColor,
                                                    strokeWidth: 2),
                                          ),
                                        )
                                      : const SizedBox.shrink();
                                }
                                final n = _filteredNotifications[index];
                                return _buildNotificationCard(
                                    n, palette, primaryColor);
                              },
                            ),
                          ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(Color primaryColor, AppPalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: primaryColor, strokeWidth: 2),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final palette = AppPalette.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with colored glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(
                      alpha: palette.isDark ? 0.12 : 0.07),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(
                      alpha: palette.isDark ? 0.18 : 0.10),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_off_outlined,
                  size: 34,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            AppLocalizations.of(context)
                .translate('community.no_notifications'),
            style: AppText.of(context).titleL,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      NotificationModel notification, AppPalette palette, Color primaryColor) {
    final iconColor = NotificationPresenter.colorFor(
        notification.type, palette, primaryColor);
    final iconBgColor = iconColor.withValues(alpha: 0.15);
    final iconData = NotificationPresenter.iconFor(notification.type);
    final headerText =
        NotificationPresenter.categoryFor(context, notification.type);
    final titleText = NotificationPresenter.titleFor(context, notification);
    final bodyText = NotificationPresenter.bodyFor(context, notification);
    final hasActor = (notification.actorUid != null &&
        notification.actorUid!.isNotEmpty);
    final isUnread = !notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(notification.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: palette.error,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppPalette.glassBlurSubtle,
              sigmaY: AppPalette.glassBlurSubtle),
          child: Container(
            decoration: BoxDecoration(
              color: isUnread
                  ? (palette.isDark
                      ? palette.glassFill
                          .withValues(alpha: 0.75)
                      : palette.surface.withValues(alpha: 0.92))
                  : (palette.isDark
                      ? palette.glassFill
                          .withValues(alpha: 0.50)
                      : palette.surface.withValues(alpha: 0.78)),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border(
                left: BorderSide(
                  color: isUnread
                      ? primaryColor
                      : Colors.transparent,
                  width: 3,
                ),
                top: BorderSide(color: palette.glassStroke, width: 0.5),
                right: BorderSide(color: palette.glassStroke, width: 0.5),
                bottom: BorderSide(color: palette.glassStroke, width: 0.5),
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Stack(
              children: [
                if (isUnread)
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
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 6)
                          ]),
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: hasActor
                          ? () => openUserProfile(context,
                              userId: notification.actorUid)
                          : null,
                      child: _buildLeadingAvatar(
                        notification: notification,
                        iconBgColor: iconBgColor,
                        iconColor: iconColor,
                        iconData: iconData,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.6,
                              color: iconColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            onTap: hasActor
                                ? () => openUserProfile(context,
                                    userId: notification.actorUid)
                                : null,
                            child: Text(
                              titleText,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: palette.textPrimary,
                              ),
                            ),
                          ),
                          if (bodyText != null && bodyText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              bodyText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _formatRelativeTime(notification.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: palette.textTertiary,
                            ),
                          ),
                          if (notification.type ==
                                  NotificationType.friendRequest &&
                              notification.relatedId != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _acceptRequest(
                                      notification.relatedId!,
                                      notification.id),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.xs),
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.sm),
                                      boxShadow: [
                                        BoxShadow(
                                            color: primaryColor
                                                .withValues(alpha: 0.35),
                                            blurRadius: 8,
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
                                const SizedBox(width: AppSpacing.xs),
                                GestureDetector(
                                  onTap: () => _rejectRequest(
                                      notification.relatedId!,
                                      notification.id),
                                  child: ClipRRect(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: AppSpacing.xs),
                                        decoration: BoxDecoration(
                                          color: palette.glassFill,
                                          borderRadius:
                                              BorderRadius.circular(AppRadius.sm),
                                          border: Border.all(
                                              color: palette.error
                                                  .withValues(alpha: 0.5)),
                                        ),
                                        child: Text(
                                            AppLocalizations.of(context)
                                                .translate(
                                                    'friend_actions.reject'),
                                            style: TextStyle(
                                                color: palette.error,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ),
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
        ),
      ),
    );
  }

  Widget _buildLeadingAvatar({
    required NotificationModel notification,
    required Color iconBgColor,
    required Color iconColor,
    required IconData iconData,
  }) {
    final photo = notification.actorPhotoUrl;
    if (photo != null && photo.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: iconBgColor,
          image: DecorationImage(
            image: NetworkImage(photo),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconBgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
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

// ── Private sub-widgets ───────────────────────────────────────────────────────

class _NotificationAppBar extends StatelessWidget {
  final Color primaryColor;
  final AppPalette palette;
  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;

  const _NotificationAppBar({
    required this.primaryColor,
    required this.palette,
    required this.onBack,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: AppPalette.glassBlurSubtle,
            sigmaY: AppPalette.glassBlurSubtle),
        child: Container(
          color: palette.background.withValues(alpha: 0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back,
                          color: palette.textSecondary),
                      onPressed: onBack,
                    ),
                    Text(
                      AppLocalizations.of(context)
                          .translate('community.notifications_title'),
                      style: AppText.of(context).labelL.copyWith(
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: Icon(Icons.done_all,
                          color: palette.textSecondary),
                      onPressed: onMarkAllRead,
                      tooltip: AppLocalizations.of(context)
                          .translate('community.mark_all_read'),
                    ),
                  ],
                ),
              ),
              // Brand gradient accent line
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.sunsetA,
                      primaryColor,
                      AppPalette.sunsetC,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassFilterChip extends StatelessWidget {
  final String filterId;
  final String label;
  final String selectedFilter;
  final Color primaryColor;
  final AppPalette palette;
  final VoidCallback onTap;

  const _GlassFilterChip({
    required this.filterId,
    required this.label,
    required this.selectedFilter,
    required this.primaryColor,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedFilter == filterId;

    if (isSelected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                AppPalette.sunsetC,
              ],
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: [
              BoxShadow(
                  color: primaryColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: BackdropFilter(
          filter:
              ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: palette.glassFill
                  .withValues(alpha: palette.isDark ? 0.4 : 0.6),
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: palette.glassStroke,
                width: 0.8,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
