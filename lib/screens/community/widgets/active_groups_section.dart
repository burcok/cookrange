import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/community_group_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_detail_screen.dart';

/// "Günün en aktif grupları" (Faz 2 §2.5) — sits directly below the
/// community tab's header, replacing the old dead carousel that was backed
/// by `CommunityService.getGroups()` (a permanently-empty `const []` stub,
/// now removed). Two rows:
///  1. Global top 5 public groups by server-computed `activity_score`
///     (`CommunityGroupService.getTopActiveGroups` —
///     `computeGroupActivityScores`, functions/groups.js, is the only writer
///     of that field; this widget only ever reads it).
///  2. A city-scoped strip using the already-persisted `groups_last_city`
///     preference (`GroupsDiscoveryScreen`'s own key — read here, never
///     written here) — no GPS/location permission involved.
///
/// Cold start: each row renders its own "be the first to start a group"
/// empty state instead of nothing (R7) — see
/// `CommunityGroupService.seedOfficialGroups` for the server-side seed data
/// that should make an empty row rare in practice once run.
class ActiveGroupsSection extends StatefulWidget {
  const ActiveGroupsSection({super.key});

  @override
  State<ActiveGroupsSection> createState() => _ActiveGroupsSectionState();
}

class _ActiveGroupsSectionState extends State<ActiveGroupsSection> {
  // Same key GroupsDiscoveryScreen already persists to — deliberately
  // reused, never duplicated, per the plan's "groups_last_city tercihi
  // zaten var" instruction. This widget only reads it.
  static const _prefsCity = 'groups_last_city';

  final _service = CommunityGroupService();

  bool _loadingTop = true;
  bool _loadingCity = true;
  List<CommunityGroupModel> _topActive = const [];
  List<CommunityGroupModel> _cityActive = const [];
  String? _city;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTop());
    unawaited(_loadCity());
  }

  Future<void> _loadTop() async {
    final top = await _service.getTopActiveGroups();
    if (!mounted) return;
    setState(() {
      _topActive = top;
      _loadingTop = false;
    });
  }

  Future<void> _loadCity() async {
    final prefs = await SharedPreferences.getInstance();
    final city = prefs.getString(_prefsCity);
    if (!mounted) return;
    if (city == null || city.isEmpty) {
      setState(() => _loadingCity = false);
      return;
    }
    final cityGroups = await _service.getActiveGroupsInCity(city);
    if (!mounted) return;
    setState(() {
      _city = city;
      _cityActive = cityGroups;
      _loadingCity = false;
    });
  }

  // Re-fetch both rows after a join/request succeeds — member_count and
  // (eventually, on the next 15-min cron pass) activity_score change, and a
  // freshly-joined group disappearing from "most active" isn't expected
  // here anyway, so a full reload (not a local splice) keeps this simple.
  void _reload() {
    unawaited(_loadTop());
    unawaited(_loadCity());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xs),
          child: Text(
            l10n.translate('community.groups.active_today_title'),
            style: t.headlineM,
          ),
        ),
        _loadingTop
            ? const _GroupsRowSkeleton()
            : _topActive.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    child: _EmptyGroupsCta(city: null),
                  )
                : _GroupsRow(groups: _topActive, onChanged: _reload),
        const SizedBox(height: AppSpacing.lg),
        if (!_loadingCity && _city != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xs),
            child: Text(
              l10n
                  .translate('community.groups.new_in_city_title')
                  .replaceAll('{city}', _city!),
              style: t.headlineM,
            ),
          ),
          _cityActive.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: _EmptyGroupsCta(city: _city),
                )
              : _GroupsRow(groups: _cityActive, onChanged: _reload),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _GroupsRowSkeleton extends StatelessWidget {
  const _GroupsRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (_, __) => const AppSkeletonBox(width: 152, height: 176),
      ),
    );
  }
}

class _GroupsRow extends StatelessWidget {
  final List<CommunityGroupModel> groups;
  final VoidCallback onChanged;
  const _GroupsRow({required this.groups, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) => RepaintBoundary(
          child: _ActiveGroupCard(group: groups[i], onChanged: onChanged),
        ),
      ),
    );
  }
}

class _ActiveGroupCard extends StatefulWidget {
  final CommunityGroupModel group;
  final VoidCallback onChanged;
  const _ActiveGroupCard({required this.group, required this.onChanged});

  @override
  State<_ActiveGroupCard> createState() => _ActiveGroupCardState();
}

class _ActiveGroupCardState extends State<_ActiveGroupCard> {
  final _service = CommunityGroupService();
  bool _busy = false;

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  void _openGroup() {
    Navigator.of(context).push(
      AppTransitions.slideRight(GroupDetailScreen(groupId: widget.group.id)),
    );
  }

  /// One-tap join that respects §2.3's `join_policy` (the whole point of
  /// this widget existing rather than calling `joinGroup` unconditionally):
  /// 'open' joins immediately; 'request' opens the same
  /// `requestToJoin`/`join_requests` flow §2.3 already built server-side
  /// (via a small inline sheet — no dedicated request screen exists
  /// anywhere in the app yet, so this is its first real caller);
  /// 'invite'-gated groups have no client-side join OR request path at all
  /// (a code is required — functions/groups.js: redeemGroupInvite), so this
  /// routes to the group's own screen instead of silently attempting (and
  /// failing) a join.
  Future<void> _handleJoin() async {
    final l10n = AppLocalizations.of(context);
    final group = widget.group;

    if (group.joinPolicy == GroupJoinPolicy.invite) {
      _openGroup();
      return;
    }

    if (group.joinPolicy == GroupJoinPolicy.request) {
      final message = await _showRequestSheet(context, l10n);
      if (message == null) return; // cancelled
      setState(() => _busy = true);
      try {
        await _service.requestToJoin(
          group.id,
          message: message.isEmpty ? null : message,
        );
        if (mounted) {
          unawaited(HapticFeedback.mediumImpact());
          AppSnackBar.success(
              context, l10n.translate('community.groups.request_sent'));
        }
      } catch (e) {
        if (mounted) AppSnackBar.error(context, e.toString());
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    setState(() => _busy = true);
    try {
      await _service.joinGroup(group.id);
      if (mounted) {
        unawaited(HapticFeedback.mediumImpact());
        AppSnackBar.success(
          context,
          l10n
              .translate('community.groups.join_success')
              .replaceAll('{group}', group.name),
        );
      }
      widget.onChanged();
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _showRequestSheet(
      BuildContext context, AppLocalizations l10n) {
    final ctrl = TextEditingController();
    return AppSheet.show<String>(
      context: context,
      title: l10n.translate('community.groups.request_dialog_title'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: ctrl,
              hintText: l10n.translate('community.groups.request_dialog_hint'),
              maxLines: 3,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.translate('community.groups.request_dialog_send'),
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final group = widget.group;
    // activity_score is a continuous, decayed number with no inherent human
    // meaning at a glance (see functions/groups.js' decay-formula comment)
    // — shown as a simple present/absent "live" signal rather than the raw
    // figure, matching "canlı aktiflik göstergesi" (a live indicator, not a
    // score readout).
    final isLive = group.activityScore > 0;

    return SizedBox(
      width: 152,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: _openGroup,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.groups_rounded, color: primary, size: 20),
                ),
                const Spacer(),
                if (isLive)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: palette.error, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.translate('community.groups.live_now'),
                          style: t.labelS.copyWith(
                              color: palette.error,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              group.name,
              style: t.bodyM.copyWith(fontWeight: FontWeight.w700),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              l10n
                  .translate('community.groups.members_count')
                  .replaceAll('{n}', '${group.memberCount}'),
              style: t.labelS.copyWith(color: palette.textTertiary),
            ),
            const SizedBox(height: 8),
            StreamBuilder<bool>(
              stream: _service.isMemberStream(group.id, _uid),
              builder: (context, snap) {
                final isMember = snap.data ?? false;
                if (isMember) {
                  return SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: l10n.translate('community.groups.joined'),
                      variant: AppButtonVariant.secondary,
                      icon: Icons.check_rounded,
                      size: AppButtonSize.small,
                      onPressed: _openGroup,
                    ),
                  );
                }
                final label = group.joinPolicy == GroupJoinPolicy.invite
                    ? l10n.translate('community.groups.view_group')
                    : group.joinPolicy == GroupJoinPolicy.request
                        ? l10n.translate('community.groups.request_join')
                        : l10n.translate('community.groups.join');
                return SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: label,
                    size: AppButtonSize.small,
                    loading: _busy,
                    onPressed: _busy ? null : _handleJoin,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Cold-start / genuinely-empty-city empty state — a CTA, never a blank
/// space (R7). [city] null means the GLOBAL top-active row is empty (no
/// public groups exist anywhere yet); non-null means one specific city has
/// nothing, even though other cities/groups may.
class _EmptyGroupsCta extends StatelessWidget {
  final String? city;
  const _EmptyGroupsCta({required this.city});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final city = this.city;
    return AppEmptyState(
      compact: true,
      icon: Icons.groups_outlined,
      title: city == null
          ? l10n.translate('community.groups.empty_active_title')
          : l10n
              .translate('community.groups.empty_city_title')
              .replaceAll('{city}', city),
      actionLabel: l10n.translate('community.groups.create'),
      onAction: () => Navigator.of(context).push(
        AppTransitions.slideUp(CreateGroupScreen(initialCity: city)),
      ),
    );
  }
}
