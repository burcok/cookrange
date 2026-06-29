import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/streak_squad_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/streak_squad_service.dart';
import '../../core/widgets/ds/ds.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StreakSquadScreen
// ─────────────────────────────────────────────────────────────────────────────

class StreakSquadScreen extends StatefulWidget {
  const StreakSquadScreen({super.key});

  @override
  State<StreakSquadScreen> createState() => _StreakSquadScreenState();
}

class _StreakSquadScreenState extends State<StreakSquadScreen> {
  final StreakSquadService _service = StreakSquadService();

  void _showCreateSheet(String uid) {
    AppSheet.show<void>(
      context: context,
      title: AppLocalizations.of(context).translate('squad.create_title'),
      child: _CreateSquadSheet(uid: uid, service: _service),
    );
  }

  void _showJoinSheet(String uid) {
    AppSheet.show<void>(
      context: context,
      title: AppLocalizations.of(context).translate('squad.join_title'),
      child: _JoinSquadSheet(uid: uid, service: _service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<UserProvider>().user?.uid ?? '';
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // ── Ambient mesh-glow background ──
          Positioned(
            top: -80,
            right: -60,
            child: _AmbientBlob(color: primary, size: 280),
          ),
          Positioned(
            bottom: 80,
            left: -80,
            child: _AmbientBlob(
                color: AppPalette.energyDark.withValues(alpha: 0.6), size: 220),
          ),
          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // AppBar-style header
                _SquadAppBar(
                  title: loc.translate('squad.title'),
                  primaryColor: primary,
                  onCreateTap: uid.isNotEmpty ? () => _showCreateSheet(uid) : null,
                ),
                // Body stream
                Expanded(
                  child: uid.isEmpty
                      ? AppEmptyState(
                          icon: Icons.group_rounded,
                          title: loc.translate('squad.empty_title'),
                          message: loc.translate('squad.empty_msg'),
                        )
                      : StreamBuilder<List<StreakSquadModel>>(
                          stream: _service.getMySquadsStream(uid),
                          builder: (context, snap) {
                            if (snap.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.only(top: AppSpacing.lg),
                                child: AppSkeletonList(itemCount: 4),
                              );
                            }

                            final squads = snap.data ?? [];

                            if (squads.isEmpty) {
                              return AppEmptyState(
                                icon: Icons.group_rounded,
                                title: loc.translate('squad.empty_title'),
                                message: loc.translate('squad.empty_msg'),
                                actionLabel: loc.translate('squad.join_action'),
                                onAction: () => _showJoinSheet(uid),
                              );
                            }

                            return ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.screenH.w,
                                AppSpacing.md.h,
                                AppSpacing.screenH.w,
                                AppSpacing.xxxl.h,
                              ),
                              itemCount: squads.length,
                              itemBuilder: (context, i) => _SquadCard(
                                key: ValueKey(squads[i].squadId),
                                squad: squads[i],
                                currentUid: uid,
                                service: _service,
                                index: i,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: uid.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showCreateSheet(uid),
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SquadAppBar
// ─────────────────────────────────────────────────────────────────────────────

class _SquadAppBar extends StatelessWidget {
  final String title;
  final Color primaryColor;
  final VoidCallback? onCreateTap;

  const _SquadAppBar({
    required this.title,
    required this.primaryColor,
    this.onCreateTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH.w,
            AppSpacing.md.h,
            AppSpacing.xs.w,
            0,
          ),
          child: Row(
            children: [
              if (Navigator.of(context).canPop())
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: palette.textPrimary,
                  iconSize: 20.r,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (Navigator.of(context).canPop()) SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Text(title, style: t.headlineM),
              ),
            ],
          ),
        ),
        SizedBox(height: AppSpacing.xs.h),
        // Gradient accent line
        Container(
          height: 2.h,
          margin: EdgeInsets.symmetric(horizontal: AppSpacing.screenH.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, AppPalette.energyDark],
            ),
            borderRadius: BorderRadius.circular(AppRadius.full.r),
          ),
        ),
        SizedBox(height: AppSpacing.md.h),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AmbientBlob — decorative background glow
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _AmbientBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size.r,
        height: size.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.18),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SquadCard
// ─────────────────────────────────────────────────────────────────────────────

class _SquadCard extends StatefulWidget {
  final StreakSquadModel squad;
  final String currentUid;
  final StreakSquadService service;
  final int index;

  const _SquadCard({
    super.key,
    required this.squad,
    required this.currentUid,
    required this.service,
    required this.index,
  });

  @override
  State<_SquadCard> createState() => _SquadCardState();
}

class _SquadCardState extends State<_SquadCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryCtrl = AnimationController(
    vsync: this,
    duration: AppMotion.normal +
        Duration(milliseconds: widget.index * 60),
  );

  late final Animation<double> _fade =
      CurvedAnimation(parent: _entryCtrl, curve: AppMotion.decelerate);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _entryCtrl, curve: AppMotion.emphasized));

  @override
  void initState() {
    super.initState();
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  void _openDetail() {
    AppSheet.show<void>(
      context: context,
      title: widget.squad.name,
      child: _SquadDetailSheet(
        squad: widget.squad,
        currentUid: widget.currentUid,
        service: widget.service,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final loc = AppLocalizations.of(context);
    final squad = widget.squad;

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: AppGlassCard(
            onTap: _openDetail,
            semanticLabel: squad.name,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Squad name + member count ──
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        squad.name,
                        style: t.titleM.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(AppRadius.full.r),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people_rounded,
                              size: 13.r, color: palette.textSecondary),
                          SizedBox(width: 4.w),
                          Text(
                            '${squad.memberUids.length}',
                            style: t.labelS.copyWith(
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xs.h),
                // ── Streak goal pill ──
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full.r),
                    border: Border.all(
                        color: palette.warning.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🔥', style: TextStyle(fontSize: 12.sp)),
                      SizedBox(width: 4.w),
                      Text(
                        loc.translate(
                          'squad.goal_days',
                          variables: {'days': squad.streakGoal.toString()},
                        ),
                        style: t.labelS.copyWith(
                          color: palette.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),
                // ── Mini leaderboard (top 3) ──
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: widget.service.getMemberStreaks(squad.memberUids),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return AppShimmer(
                        child: Row(
                          children: List.generate(
                            3,
                            (_) => Padding(
                              padding: EdgeInsets.only(right: AppSpacing.xs.w),
                              child: const AppSkeletonBox(
                                  height: AppSize.avatarMd, circle: true),
                            ),
                          ),
                        ),
                      );
                    }

                    final members = (snap.data ?? []).take(3).toList();
                    if (members.isEmpty) return const SizedBox.shrink();

                    return Row(
                      children: [
                        ...members.map((m) => Padding(
                              padding:
                                  EdgeInsets.only(right: AppSpacing.xs.w),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppInitialsAvatar(
                                    photoUrl: m['photoURL'] as String?,
                                    name: m['displayName'] as String? ?? '',
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🔥',
                                          style:
                                              TextStyle(fontSize: 10.sp)),
                                      Text(
                                        '${m['streak']}',
                                        style: t.labelS.copyWith(
                                          color: primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                        if (squad.memberUids.length > 3) ...[
                          SizedBox(width: AppSpacing.xxs.w),
                          Text(
                            '+${squad.memberUids.length - 3}',
                            style: t.labelS
                                .copyWith(color: palette.textTertiary),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SquadDetailSheet
// ─────────────────────────────────────────────────────────────────────────────

class _SquadDetailSheet extends StatefulWidget {
  final StreakSquadModel squad;
  final String currentUid;
  final StreakSquadService service;

  const _SquadDetailSheet({
    required this.squad,
    required this.currentUid,
    required this.service,
  });

  @override
  State<_SquadDetailSheet> createState() => _SquadDetailSheetState();
}

class _SquadDetailSheetState extends State<_SquadDetailSheet> {
  bool _leaving = false;

  Future<void> _confirmLeave() async {
    final loc = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('squad.leave_confirm_title')),
        content: Text(loc.translate('squad.leave_confirm_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: AppPalette.of(context).error,
            ),
            child: Text(loc.translate('squad.leave_action')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _leaving = true);
    try {
      await widget.service.leaveSquad(
          widget.squad.squadId, widget.currentUid);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.success(
          context, AppLocalizations.of(context).translate('squad.left_msg'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
          context, AppLocalizations.of(context).translate('squad.leave_error'));
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final loc = AppLocalizations.of(context);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.service.getMemberStreaks(widget.squad.memberUids),
      builder: (context, snap) {
        final members = snap.data ?? [];
        final isLoading = snap.connectionState == ConnectionState.waiting;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Invite code row
            Container(
              margin: EdgeInsets.symmetric(horizontal: AppSpacing.screenH.w),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.sm.h,
              ),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md.r),
                border: Border.all(color: primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.link_rounded, size: 16.r, color: primary),
                  SizedBox(width: AppSpacing.xs.w),
                  Text(
                    loc.translate('squad.invite_code'),
                    style: t.labelM.copyWith(color: palette.textSecondary),
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  Text(
                    widget.squad.inviteCode,
                    style: t.labelL.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(
                          ClipboardData(text: widget.squad.inviteCode));
                      HapticFeedback.lightImpact();
                      AppSnackBar.success(context,
                          loc.translate('squad.code_copied'));
                    },
                    child: Icon(Icons.copy_rounded,
                        size: 16.r, color: primary),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.md.h),
            // Leaderboard
            if (isLoading)
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH.w),
                child: const AppSkeletonList(itemCount: 4, itemHeight: 56),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 340.h),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH.w),
                  itemCount: members.length,
                  separatorBuilder: (_, __) =>
                      Divider(color: palette.divider, height: 1),
                  itemBuilder: (context, i) {
                    final m = members[i];
                    final isMe = m['uid'] == widget.currentUid;
                    return Container(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
                      decoration: BoxDecoration(
                        color: isMe
                            ? primary.withValues(alpha: 0.06)
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm.r),
                      ),
                      child: Row(
                        children: [
                          // Rank
                          SizedBox(
                            width: 28.w,
                            child: Text(
                              _rankLabel(i),
                              style: t.labelL.copyWith(
                                color: i == 0
                                    ? const Color(0xFFFFD700)
                                    : i == 1
                                        ? const Color(0xFFC0C0C0)
                                        : i == 2
                                            ? const Color(0xFFCD7F32)
                                            : palette.textTertiary,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          AppInitialsAvatar(
                            photoUrl: m['photoURL'] as String?,
                            name: m['displayName'] as String? ?? '',
                          ),
                          SizedBox(width: AppSpacing.sm.w),
                          Expanded(
                            child: Text(
                              m['displayName'] as String? ?? '',
                              style: t.bodyM.copyWith(
                                fontWeight: isMe
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isMe
                                    ? primary
                                    : palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('🔥',
                                  style: TextStyle(fontSize: 14.sp)),
                              SizedBox(width: 4.w),
                              Text(
                                '${m['streak']}',
                                style: t.labelL.copyWith(
                                  color: primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                        ],
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: AppSpacing.lg.h),
            // Leave button
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenH.w,
              ).add(EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom +
                      AppSpacing.md.h)),
              child: AppButton(
                label: loc.translate('squad.leave_action'),
                onPressed: _leaving ? null : _confirmLeave,
                variant: AppButtonVariant.destructive,
                loading: _leaving,
              ),
            ),
          ],
        );
      },
    );
  }

  String _rankLabel(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '#${index + 1}';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CreateSquadSheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateSquadSheet extends StatefulWidget {
  final String uid;
  final StreakSquadService service;

  const _CreateSquadSheet({required this.uid, required this.service});

  @override
  State<_CreateSquadSheet> createState() => _CreateSquadSheetState();
}

class _CreateSquadSheetState extends State<_CreateSquadSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  int _selectedGoal = 7;
  bool _loading = false;
  String? _nameError;

  static const List<int> _goalOptions = [7, 14, 30];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    final loc = AppLocalizations.of(context);

    if (name.isEmpty) {
      setState(() => _nameError = loc.translate('squad.name_required'));
      return;
    }

    setState(() {
      _loading = true;
      _nameError = null;
    });

    try {
      final squad = await widget.service.createSquad(
          name, widget.uid, _selectedGoal);
      if (!mounted) return;
      Navigator.of(context).pop();
      // Show the invite code in a success snackbar
      AppSnackBar.success(
        context,
        loc.translate(
          'squad.created_msg',
          variables: {'code': squad.inviteCode},
        ),
        actionLabel: loc.translate('squad.copy_code'),
        onAction: () {
          Clipboard.setData(ClipboardData(text: squad.inviteCode));
          HapticFeedback.lightImpact();
        },
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
          context, loc.translate('squad.create_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH.w,
        0,
        AppSpacing.screenH.w,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _nameCtrl,
            labelText: loc.translate('squad.name_label'),
            hintText: loc.translate('squad.name_hint'),
            errorText: _nameError,
            textInputAction: TextInputAction.done,
            maxLength: 40,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            loc.translate('squad.goal_label'),
            style: t.labelM.copyWith(color: palette.textSecondary),
          ),
          SizedBox(height: AppSpacing.xs.h),
          AppChipPicker<int>(
            options: _goalOptions
                .map((d) => AppChipOption<int>(
                      value: d,
                      label: loc.translate(
                        'squad.goal_days',
                        variables: {'days': d.toString()},
                      ),
                    ))
                .toList(),
            selected: {_selectedGoal},
            onToggle: (v) => setState(() => _selectedGoal = v),
          ),
          SizedBox(height: AppSpacing.xl.h),
          AppButton(
            label: loc.translate('squad.create_action'),
            onPressed: _loading ? null : _create,
            loading: _loading,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _JoinSquadSheet
// ─────────────────────────────────────────────────────────────────────────────

class _JoinSquadSheet extends StatefulWidget {
  final String uid;
  final StreakSquadService service;

  const _JoinSquadSheet({required this.uid, required this.service});

  @override
  State<_JoinSquadSheet> createState() => _JoinSquadSheetState();
}

class _JoinSquadSheetState extends State<_JoinSquadSheet> {
  final TextEditingController _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _codeError;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final loc = AppLocalizations.of(context);

    if (code.length != 6) {
      setState(() => _codeError = loc.translate('squad.code_invalid'));
      return;
    }

    setState(() {
      _loading = true;
      _codeError = null;
    });

    try {
      await widget.service.joinSquad(code, widget.uid);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.success(
          context, loc.translate('squad.joined_msg'));
    } on StreakSquadNotFoundException {
      if (!mounted) return;
      setState(() => _codeError = loc.translate('squad.code_not_found'));
    } on StreakSquadAlreadyMemberException {
      if (!mounted) return;
      setState(() => _codeError = loc.translate('squad.already_member'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
          context, loc.translate('squad.join_error'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH.w,
        0,
        AppSpacing.screenH.w,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _codeCtrl,
            labelText: loc.translate('squad.code_label'),
            hintText: loc.translate('squad.code_hint'),
            errorText: _codeError,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            onChanged: (v) {
              // Force uppercase while typing
              final upper = v.toUpperCase();
              if (v != upper) {
                _codeCtrl.value = _codeCtrl.value.copyWith(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }
              if (_codeError != null) setState(() => _codeError = null);
            },
            onSubmitted: (_) => _join(),
          ),
          SizedBox(height: AppSpacing.xl.h),
          AppButton(
            label: loc.translate('squad.join_action'),
            onPressed: _loading ? null : _join,
            loading: _loading,
          ),
        ],
      ),
    );
  }
}
