import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  final _searchCtrl = TextEditingController();
  final _adminService = AdminService();
  String _query = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _query = _searchCtrl.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        title: Text(l10n.translate('admin.users_title'), style: t.headlineS),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20.r),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          _SearchBar(controller: _searchCtrl, l10n: l10n, palette: palette),
          Expanded(child: _buildList(context, l10n)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, AppLocalizations l10n) {
    if (_query.isEmpty) {
      return StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getUsersStream(),
        builder: (ctx, snap) => _handleSnapshot(ctx, snap, l10n),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _adminService.searchUsers(_query),
      builder: (ctx, snap) => _handleSnapshot(ctx, snap, l10n),
    );
  }

  Widget _handleSnapshot(
    BuildContext context,
    AsyncSnapshot<List<Map<String, dynamic>>> snap,
    AppLocalizations l10n,
  ) {
    if (snap.hasError) {
      return AppErrorState(
        title: l10n.translate('common.error'),
        message: snap.error.toString(),
        onRetry: () => setState(() {}),
      );
    }
    if (!snap.hasData) {
      return const AppSkeletonList(itemCount: 5);
    }
    final users = snap.data!;
    if (users.isEmpty) {
      return AppEmptyState(
        icon: Icons.people_outline_rounded,
        title: l10n.translate('admin.no_users'),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      itemCount: users.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (ctx, i) =>
          _UserTile(user: users[i], l10n: l10n, adminService: _adminService),
    );
  }
}

// ── Search Bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final AppLocalizations l10n;
  final AppPalette palette;

  const _SearchBar({
    required this.controller,
    required this.l10n,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Container(
      color: palette.surface,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
      child: TextField(
        controller: controller,
        style: t.bodyM.copyWith(color: palette.textPrimary),
        decoration: InputDecoration(
          hintText: l10n.translate('admin.search_placeholder'),
          hintStyle: t.bodyM.copyWith(color: palette.textSecondary),
          prefixIcon: Icon(Icons.search_rounded,
              color: palette.textSecondary, size: 20.r),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: palette.textSecondary, size: 18.r),
                    onPressed: () => controller.clear(),
                  )
                : const SizedBox.shrink(),
          ),
          filled: true,
          fillColor: palette.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.input.r),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              EdgeInsets.symmetric(vertical: 10.h, horizontal: 12.w),
        ),
      ),
    );
  }
}

// ── User Tile ───────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  final Map<String, dynamic> user;
  final AppLocalizations l10n;
  final AdminService adminService;

  const _UserTile({
    required this.user,
    required this.l10n,
    required this.adminService,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final name = (user['display_name'] as String?)?.isNotEmpty == true
        ? user['display_name'] as String
        : 'Unknown';
    final email = (user['email'] as String?) ?? '';
    final role = (user['user_role'] as String?) ?? 'consumer';
    final isBanned = user['is_banned'] == true;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Timestamp? ts;
    if (user['created_at'] is Timestamp) {
      ts = user['created_at'] as Timestamp;
    } else if (user['createdAt'] is Timestamp) {
      ts = user['createdAt'] as Timestamp;
    }
    final memberSince = ts != null
        ? l10n
            .translate('admin.user_since')
            .replaceAll('{date}', DateFormat.yMMMd().format(ts.toDate()))
        : '';

    return AppCard(
      onTap: () => _showActionSheet(context, name, email, role, isBanned),
      semanticLabel: '$name, $role${isBanned ? ', banned' : ''}',
      child: Row(
        children: [
          _Avatar(initial: initial, palette: palette, t: t),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          style: t.bodyM.copyWith(color: palette.textPrimary),
                          overflow: TextOverflow.ellipsis),
                    ),
                    SizedBox(width: 8.w),
                    _RoleChip(role: role, l10n: l10n, palette: palette, t: t),
                    if (isBanned) ...[
                      SizedBox(width: 4.w),
                      _BannedBadge(palette: palette, t: t),
                    ],
                  ],
                ),
                if (email.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(email,
                      style: t.labelM.copyWith(color: palette.textSecondary),
                      overflow: TextOverflow.ellipsis),
                ],
                if (memberSince.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(memberSince,
                      style: t.labelS.copyWith(color: palette.textTertiary)),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: palette.textTertiary, size: 18.r),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context, String name, String email,
      String role, bool isBanned) {
    AppSheet.show(
      context: context,
      title: name,
      child: _UserActionSheet(
        uid: user['uid'] as String,
        name: name,
        email: email,
        role: role,
        isBanned: isBanned,
        l10n: l10n,
        adminService: adminService,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final AppPalette palette;
  final AppText t;

  const _Avatar({
    required this.initial,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44.r,
      height: 44.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: palette.surfaceVariant,
      ),
      alignment: Alignment.center,
      child: Text(initial,
          style: t.bodyL.copyWith(
              color: palette.textSecondary, fontWeight: FontWeight.w600)),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  final AppLocalizations l10n;
  final AppPalette palette;
  final AppText t;

  const _RoleChip({
    required this.role,
    required this.l10n,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'coach' => (l10n.translate('admin.role_coach'), palette.success),
      'gym_owner' => (l10n.translate('admin.role_gym_owner'), palette.warning),
      'admin' => (l10n.translate('admin.role_admin'), palette.error),
      _ => (l10n.translate('admin.role_consumer'), palette.info),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: palette.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Text(label,
          style: t.labelS.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _BannedBadge extends StatelessWidget {
  final AppPalette palette;
  final AppText t;

  const _BannedBadge({required this.palette, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: palette.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, color: palette.error, size: 10.r),
          SizedBox(width: 2.w),
          Text(AppLocalizations.of(context).translate('admin.users.status_banned'),
              style: t.labelS
                  .copyWith(color: palette.error, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── User Action Sheet ────────────────────────────────────────────────────────

class _UserActionSheet extends StatefulWidget {
  final String uid;
  final String name;
  final String email;
  final String role;
  final bool isBanned;
  final AppLocalizations l10n;
  final AdminService adminService;

  const _UserActionSheet({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.isBanned,
    required this.l10n,
    required this.adminService,
  });

  @override
  State<_UserActionSheet> createState() => _UserActionSheetState();
}

class _UserActionSheetState extends State<_UserActionSheet> {
  late String _selectedRole;
  bool _loading = false;
  late Future<Map<String, int>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.role;
    _statsFuture = widget.adminService.getUserDataStats(widget.uid);
  }

  Future<void> _changeRole() async {
    if (_selectedRole == widget.role) return;
    setState(() => _loading = true);
    try {
      await widget.adminService.setUserRole(widget.uid, _selectedRole);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('${widget.l10n.translate('admin.action_change_role')} ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ban() async {
    final banReasonCtrl = TextEditingController();
    final confirmed = await _showBanDialog(banReasonCtrl);
    if (!confirmed || !mounted) return;
    final reason = banReasonCtrl.text.trim();
    setState(() => _loading = true);
    try {
      await widget.adminService.banUser(widget.uid, reason);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.l10n.translate('admin.action_ban')} ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showBanDialog(TextEditingController reasonCtrl) async {
    final l10n = widget.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, _) => AlertDialog(
          title: Text(l10n.translate('admin.ban_confirm')),
          content: TextField(
            controller: reasonCtrl,
            decoration: InputDecoration(
                hintText: l10n.translate('admin.ban_reason_hint')),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.translate('common.cancel')),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.translate('admin.action_ban'),
                  style: TextStyle(color: AppPalette.of(context).error)),
            ),
          ],
        ),
      ),
    );
    return result == true;
  }

  Future<void> _unban() async {
    final confirmed = await _showUnbanDialog();
    if (!confirmed || !mounted) return;
    setState(() => _loading = true);
    try {
      await widget.adminService.unbanUser(widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${widget.l10n.translate('admin.action_unban')} ✓')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _showUnbanDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.l10n.translate('admin.unban_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(widget.l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(widget.l10n.translate('admin.action_unban'),
                style: TextStyle(color: AppPalette.of(context).success)),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _forceLogout() async {
    setState(() => _loading = true);
    try {
      await widget.adminService.forceLogout(widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.l10n.translate('admin.force_logout_done'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendNotification() async {
    final l10n = widget.l10n;
    final result = await showDialog<({String title, String body})>(
      context: context,
      builder: (ctx) => _SendNotificationDialog(l10n: l10n),
    );
    if (result == null || !mounted) return;

    final title = result.title;
    final body = result.body;

    setState(() => _loading = true);
    try {
      await widget.adminService.sendNotificationToUser(
        uid: widget.uid,
        title: title.isEmpty ? l10n.translate('admin.role_admin') : title,
        body: body,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translate('admin.notif_sent'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (widget.email.isEmpty) return;
    setState(() => _loading = true);
    try {
      await widget.adminService.sendPasswordReset(widget.email);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.l10n.translate('admin.password_reset_done'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SheetUserHeader(
            name: widget.name, email: widget.email, palette: palette, t: t),
        SizedBox(height: 16.h),
        Text(l10n.translate('admin.promote_role'),
            style: t.labelM.copyWith(color: palette.textSecondary)),
        SizedBox(height: 6.h),
        _RoleDropdown(
          value: _selectedRole,
          l10n: l10n,
          palette: palette,
          t: t,
          onChanged: (v) {
            if (v != null) setState(() => _selectedRole = v);
          },
        ),
        SizedBox(height: 8.h),
        AppButton(
          label: l10n.translate('admin.action_change_role'),
          onPressed: _loading ? null : _changeRole,
          loading: _loading && _selectedRole != widget.role,
        ),
        SizedBox(height: 8.h),
        if (!widget.isBanned)
          AppButton(
            label: l10n.translate('admin.action_ban'),
            variant: AppButtonVariant.destructive,
            onPressed: _loading ? null : _ban,
            loading: _loading,
          )
        else
          AppButton(
            label: l10n.translate('admin.action_unban'),
            variant: AppButtonVariant.tonal,
            onPressed: _loading ? null : _unban,
            loading: _loading,
          ),
        SizedBox(height: 16.h),
        const Divider(height: 1),
        SizedBox(height: 12.h),
        Text(l10n.translate('admin.support_tools'),
            style: t.labelM.copyWith(color: palette.textSecondary)),
        SizedBox(height: 8.h),
        FutureBuilder<Map<String, int>>(
          future: _statsFuture,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const AppSkeletonBox(height: 56, radius: AppRadius.md);
            }
            final stats = snap.data!;
            return Row(
              children: [
                _StatChip(
                  label: l10n.translate('admin.stats_food_logs'),
                  value: '${stats['food_logs']}',
                  palette: palette,
                  t: t,
                ),
                SizedBox(width: 8.w),
                _StatChip(
                  label: l10n.translate('admin.stats_enrolled_programs'),
                  value: '${stats['enrolled_programs']}',
                  palette: palette,
                  t: t,
                ),
                SizedBox(width: 8.w),
                _StatChip(
                  label: l10n.translate('admin.stats_favorites'),
                  value: '${stats['favorites']}',
                  palette: palette,
                  t: t,
                ),
              ],
            );
          },
        ),
        SizedBox(height: 8.h),
        AppButton(
          label: l10n.translate('admin.action_send_notification'),
          variant: AppButtonVariant.tonal,
          icon: Icons.notifications_active_rounded,
          onPressed: _loading ? null : _sendNotification,
          loading: _loading,
        ),
        SizedBox(height: 8.h),
        AppButton(
          label: l10n.translate('admin.action_force_logout'),
          variant: AppButtonVariant.secondary,
          onPressed: _loading ? null : _forceLogout,
          loading: _loading,
        ),
        SizedBox(height: 8.h),
        if (widget.email.isNotEmpty)
          AppButton(
            label: l10n.translate('admin.action_password_reset'),
            variant: AppButtonVariant.ghost,
            onPressed: _loading ? null : _sendPasswordReset,
            loading: _loading,
          ),
        SizedBox(height: 8.h),
      ],
    );
  }
}

class _SheetUserHeader extends StatelessWidget {
  final String name;
  final String email;
  final AppPalette palette;
  final AppText t;

  const _SheetUserHeader({
    required this.name,
    required this.email,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Row(
      children: [
        Container(
          width: 48.r,
          height: 48.r,
          decoration: BoxDecoration(
              shape: BoxShape.circle, color: palette.surfaceVariant),
          alignment: Alignment.center,
          child: Text(initial,
              style: t.bodyL.copyWith(
                  color: palette.textSecondary, fontWeight: FontWeight.w700)),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: t.bodyL.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w600)),
              if (email.isNotEmpty)
                Text(email,
                    style: t.labelM.copyWith(color: palette.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final String value;
  final AppLocalizations l10n;
  final AppPalette palette;
  final AppText t;
  final ValueChanged<String?> onChanged;

  const _RoleDropdown({
    required this.value,
    required this.l10n,
    required this.palette,
    required this.t,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final roles = [
      ('consumer', l10n.translate('admin.role_consumer')),
      ('coach', l10n.translate('admin.role_coach')),
      ('gym_owner', l10n.translate('admin.role_gym_owner')),
      ('admin', l10n.translate('admin.role_admin')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: palette.border),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: palette.surface,
          style: t.bodyM.copyWith(color: palette.textPrimary),
          isExpanded: true,
          onChanged: onChanged,
          items: roles
              .map((r) => DropdownMenuItem(
                    value: r.$1,
                    child: Text(r.$2,
                        style: t.bodyM.copyWith(color: palette.textPrimary)),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;
  final AppText t;

  const _StatChip({
    required this.label,
    required this.value,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: t.titleL.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w700)),
            SizedBox(height: 2.h),
            Text(label,
                style: t.labelS.copyWith(color: palette.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class _SendNotificationDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _SendNotificationDialog({required this.l10n});

  @override
  State<_SendNotificationDialog> createState() =>
      _SendNotificationDialogState();
}

class _SendNotificationDialogState extends State<_SendNotificationDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _bodyCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.translate('admin.action_send_notification')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: InputDecoration(
                hintText: widget.l10n.translate('admin.notif_title_hint')),
          ),
          SizedBox(height: 8.h),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            decoration: InputDecoration(
                hintText: widget.l10n.translate('admin.notif_body_hint')),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.l10n.translate('common.cancel')),
        ),
        TextButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            final body = _bodyCtrl.text.trim();
            if (title.isEmpty && body.isEmpty) {
              return;
            }
            Navigator.of(context).pop((title: title, body: body));
          },
          child: Text(widget.l10n.translate('admin.notif_send')),
        ),
      ],
    );
  }
}
