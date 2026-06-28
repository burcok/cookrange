import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/friend_service.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/ds/ds.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FriendService _friendService = FriendService();

  List<UserModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounce;

  final Map<String, FriendshipStatus> _statusCache = {};
  final Set<String> _pendingRequest = {};

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await _friendService.searchUsers(query.trim());

      final myId = _friendService.currentUserId ?? '';
      final filtered = results.where((u) => u.uid != myId).toList();

      final statuses = await Future.wait(
        filtered.map((u) => _friendService.checkFriendshipStatus(u.uid)),
      );

      if (mounted) {
        setState(() {
          _results = filtered;
          _hasSearched = true;
          for (var i = 0; i < filtered.length; i++) {
            _statusCache[filtered[i].uid] = statuses[i];
          }
        });
      }
    } catch (e) {
      debugPrint('UserSearchScreen._search error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest(UserModel user) async {
    if (_pendingRequest.contains(user.uid)) return;
    setState(() => _pendingRequest.add(user.uid));
    try {
      await _friendService.sendFriendRequest(context, user.uid);
      if (mounted) {
        setState(() => _statusCache[user.uid] = FriendshipStatus.pending_sent);
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _pendingRequest.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.translate('user_search.title'), style: t.headlineS),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
            child: AppTextField(
              controller: _controller,
              hintText: l10n.translate('user_search.hint'),
              prefixIcon: Icon(Icons.search_rounded, color: palette.textSecondary),
              suffixIcon: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primary))
                  : _controller.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: palette.textSecondary),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = [];
                              _hasSearched = false;
                            });
                          },
                        )
                      : null,
              onChanged: _onQueryChanged,
            ),
          ),

          // Results
          Expanded(
            child: !_hasSearched
                ? _buildInitialState(palette, t, l10n)
                : _results.isEmpty
                    ? AppEmptyState(
                        icon: Icons.person_search_rounded,
                        title: l10n.translate('user_search.empty_title'),
                        message: l10n.translate('user_search.empty_subtitle'),
                      )
                    : ListView.separated(
                        padding:
                            EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: AppSpacing.sm.h),
                        itemBuilder: (context, i) => _UserTile(
                          user: _results[i],
                          status: _statusCache[_results[i].uid] ??
                              FriendshipStatus.none,
                          isPending: _pendingRequest.contains(_results[i].uid),
                          onAddFriend: () => _sendRequest(_results[i]),
                          primary: primary,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState(
      AppPalette palette, AppText t, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_rounded,
              size: 64.sp, color: palette.textTertiary),
          SizedBox(height: 16.h),
          Text(l10n.translate('user_search.hint'),
              style: t.bodyM.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final FriendshipStatus status;
  final bool isPending;
  final VoidCallback onAddFriend;
  final Color primary;

  const _UserTile({
    required this.user,
    required this.status,
    required this.isPending,
    required this.onAddFriend,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => openUserProfile(context, userId: user.uid),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: palette.border.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24.r,
              backgroundColor: primary.withValues(alpha: 0.15),
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Text(
                      (user.displayName?.isNotEmpty == true)
                          ? user.displayName![0].toUpperCase()
                          : '?',
                      style: t.titleL.copyWith(color: primary),
                    )
                  : null,
            ),
            SizedBox(width: 12.w),

            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? user.email ?? '',
                    style: t.titleM,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.email != null)
                    Text(
                      user.email!,
                      style: t.labelS,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            SizedBox(width: 8.w),

            // Friend action button
            _buildActionButton(context, l10n, t, palette),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AppLocalizations l10n,
      AppText t, AppPalette palette) {
    switch (status) {
      case FriendshipStatus.friends:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: palette.success.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.button.r),
          ),
          child: Text(
            l10n.translate('user_search.already_friends'),
            style: t.labelS.copyWith(
                color: palette.success, fontWeight: FontWeight.w600),
          ),
        );
      case FriendshipStatus.pending_sent:
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
          decoration: BoxDecoration(
            color: palette.textTertiary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.button.r),
          ),
          child: Text(
            l10n.translate('user_search.request_sent'),
            style: t.labelS.copyWith(color: palette.textSecondary),
          ),
        );
      default:
        return AppButton(
          label: l10n.translate('user_search.add_friend'),
          variant: AppButtonVariant.primary,
          size: AppButtonSize.small,
          loading: isPending,
          onPressed: onAddFriend,
        );
    }
  }
}
