import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/progress_sharing_model.dart';
import '../../core/services/coach_service.dart';
import '../../core/services/gym_service.dart';
import '../../core/services/progress_sharing_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Faz 4 §4.1/§4.2/§4.3 — the member-side "see every gym/coach's current
/// progress-sharing tier, revoke with one tap" surface the §4.1/§4.2 agent
/// deferred (`ProgressSharingService`'s own header comment names this
/// screen as the next step, backed by [ProgressSharingService.watchAll]).
///
/// Deliberately its OWN screen, not another card in the `ConsentPurpose`
/// grid on [ConsentCenterScreen] — that screen already has a precedent for
/// this exact shape of decision (Faz 1 §1.3/§1.7's `gymPresence` card routes
/// to `GymPresenceConsentScreen` for its own full flow), but progress
/// sharing is structurally different from every OTHER entry in that grid:
/// it is not one global bool purpose, it is a variable-length list (0..N)
/// of PER-RELATIONSHIP tiers (0-3). Folding a variable list of gym/coach
/// cards into the fixed 8-item purpose grid would conflate two different
/// consent models on one screen; `ConsentCenterScreen` instead gets a
/// single entry point ("İlerleme Paylaşımı") that opens this screen, same
/// pattern as the gymPresence precedent.
///
/// Explicitly NOT built here: a "discover your gyms/coaches and grant for
/// the first time" flow. [ProgressSharingService.watchAll] only returns
/// scopes with an EXISTING decision — there is no UI anywhere in this
/// codebase yet that lets a member grant an initial tier to a gym/coach
/// (confirmed: zero call sites of `ProgressSharingService` before this
/// task). That initial-grant entry point likely belongs on the gym
/// membership screen and the coach relationship screen respectively — a
/// separate surface, not one of this task's enumerated deliverables. This
/// screen manages what already exists: view current tier, change it,
/// revoke it.
class ProgressSharingConsentScreen extends StatefulWidget {
  const ProgressSharingConsentScreen({super.key});

  @override
  State<ProgressSharingConsentScreen> createState() =>
      _ProgressSharingConsentScreenState();
}

class _ProgressSharingConsentScreenState
    extends State<ProgressSharingConsentScreen> {
  final _service = ProgressSharingService();
  final _busy = <String>{};

  // Display names are resolved lazily, one-shot, memoized — a member has a
  // handful of gym/coach relationships at most, not hundreds, so N small
  // fetches (never repeated once resolved) is the right trade-off; there is
  // no bulk "resolve these scope ids to names" endpoint and building one
  // for a screen this size would be over-engineering.
  final Map<String, String> _resolvedNames = {};
  final Set<String> _resolving = {};

  Map<String, DateTime> _lastAccess = {};

  @override
  void initState() {
    super.initState();
    unawaited(_loadLastAccess());
  }

  Future<void> _loadLastAccess() async {
    final result = await _service.getLastAccessByScope();
    if (!mounted) return;
    setState(() => _lastAccess = result);
  }

  Future<void> _resolveName(ProgressSharingScope scope) async {
    if (_resolvedNames.containsKey(scope.scopeId) ||
        _resolving.contains(scope.scopeId)) {
      return;
    }
    _resolving.add(scope.scopeId);
    var name = scope.ownerId;
    try {
      if (scope.type == ProgressSharingScopeType.gym) {
        final gym = await GymService().getGym(scope.ownerId);
        if (gym != null) name = gym.name;
      } else {
        final coach = await CoachService().getCoachProfile(scope.ownerId);
        if (coach != null) name = coach.displayName;
      }
    } catch (e) {
      // A display-name lookup failure must never block the member from
      // still seeing/revoking their own sharing decision — fall back to
      // the raw id (still meaningful enough to act on) rather than an
      // error state for the whole card.
      debugPrint('ProgressSharingConsentScreen._resolveName error: $e');
    }
    if (!mounted) return;
    setState(() => _resolvedNames[scope.scopeId] = name);
  }

  Future<void> _revoke(ProgressSharingScope scope) async {
    if (_busy.contains(scope.scopeId)) return;
    setState(() => _busy.add(scope.scopeId));
    final l10n = AppLocalizations.of(context);
    try {
      await _service.revoke(scope);
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.success(context, l10n.translate('progress_sharing.revoked'));
    } catch (e) {
      debugPrint('ProgressSharingConsentScreen._revoke error: $e');
      if (!mounted) return;
      AppSnackBar.error(
          context, l10n.translate('progress_sharing.revoke_error'));
    } finally {
      if (mounted) setState(() => _busy.remove(scope.scopeId));
    }
  }

  Future<void> _changeTier(
      ProgressSharingScope scope, ProgressSharingTier current) async {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final picked = await AppSheet.show<ProgressSharingTier>(
      context: context,
      title: l10n.translate('progress_sharing.change_tier_title'),
      child: _TierPickerSheet(current: current, l10n: l10n, palette: palette),
    );
    if (picked == null || picked == current || !mounted) return;
    setState(() => _busy.add(scope.scopeId));
    try {
      await _service.grantTier(scope, picked);
      if (!mounted) return;
      AppSnackBar.success(context, l10n.translate('progress_sharing.saved'));
    } catch (e) {
      debugPrint('ProgressSharingConsentScreen._changeTier error: $e');
      if (!mounted) return;
      AppSnackBar.error(context, l10n.translate('progress_sharing.save_error'));
    } finally {
      if (mounted) setState(() => _busy.remove(scope.scopeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.translate('progress_sharing.title'), style: t.titleL),
      ),
      body: StreamBuilder<Map<String, ProgressSharingModel>>(
        stream: _service.watchAll(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: AppSkeletonList(itemCount: 3),
            );
          }
          if (snap.hasError) {
            return AppErrorState(title: l10n.translate('errors.general'));
          }

          final all = snap.data ?? {};
          final scopes = all.values.toList()
            ..sort((a, b) =>
                (b.grantedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                    .compareTo(
                        a.grantedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

          if (scopes.isEmpty) {
            return _emptyState(palette, l10n, t);
          }

          for (final model in scopes) {
            unawaited(_resolveName(model.scope));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _header(l10n, palette, t),
              const SizedBox(height: 16),
              for (final model in scopes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ScopeCard(
                    model: model,
                    displayName: _resolvedNames[model.scope.scopeId],
                    lastAccess: _lastAccess[model.scope.scopeId],
                    isBusy: _busy.contains(model.scope.scopeId),
                    onRevoke: () => _revoke(model.scope),
                    onChangeTier: () => _changeTier(model.scope, model.tier),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header(AppLocalizations l10n, AppPalette palette, AppText t) {
    return AppGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('progress_sharing.header_title'),
            style: t.titleM.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('progress_sharing.header_body'),
            style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(AppPalette palette, AppLocalizations l10n, AppText t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined,
                size: 48, color: palette.textTertiary),
            const SizedBox(height: 16),
            Text(
              l10n.translate('progress_sharing.empty_title'),
              textAlign: TextAlign.center,
              style: t.titleM.copyWith(
                  fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('progress_sharing.empty_body'),
              textAlign: TextAlign.center,
              style:
                  t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _ScopeCard extends StatelessWidget {
  final ProgressSharingModel model;
  final String? displayName;
  final DateTime? lastAccess;
  final bool isBusy;
  final VoidCallback onRevoke;
  final VoidCallback onChangeTier;

  const _ScopeCard({
    required this.model,
    required this.displayName,
    required this.lastAccess,
    required this.isBusy,
    required this.onRevoke,
    required this.onChangeTier,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;
    final isGym = model.scope.type == ProgressSharingScopeType.gym;
    final shared = model.isShared;
    final name = displayName ?? model.scope.ownerId;
    final tone = shared ? palette.success : palette.textTertiary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                    isGym ? Icons.fitness_center_rounded : Icons.person_rounded,
                    color: tone,
                    size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: t.titleM.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      isGym
                          ? l10n.translate('progress_sharing.scope_gym')
                          : l10n.translate('progress_sharing.scope_coach'),
                      style: t.labelS.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onChangeTier,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (shared ? primary : palette.textTertiary)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    shared
                        ? l10n.translate('progress_sharing.tier_label',
                            variables: {'tier': '${model.tier.level}'})
                        : l10n.translate('progress_sharing.tier0_label'),
                    style: t.labelS.copyWith(
                      color: shared ? primary : palette.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (lastAccess != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                l10n.translate('progress_sharing.last_viewed',
                    variables: {'date': _formatDate(lastAccess!)}),
                style: t.labelS.copyWith(color: palette.textTertiary),
              ),
            ),
          if (shared)
            // §4.1: "tek dokunuş geri çek" — one tap, no confirmation
            // dialog; withdrawing must be at least as easy as granting was.
            AppButton(
              label: l10n.translate('progress_sharing.revoke_button'),
              variant: AppButtonVariant.destructive,
              size: AppButtonSize.small,
              loading: isBusy,
              onPressed: isBusy ? null : onRevoke,
            )
          else
            AppButton(
              label: l10n.translate('progress_sharing.share_again_button'),
              variant: AppButtonVariant.tonal,
              size: AppButtonSize.small,
              loading: isBusy,
              onPressed: isBusy ? null : onChangeTier,
            ),
        ],
      ),
    );
  }
}

/// Tier 0-3 picker with a short, honest description per tier (§4.1's own
/// content spec) — used both to RAISE an existing scope's tier and to
/// re-share after a revoke. Not the same heavyweight, atlanamaz
/// (un-skippable) explanation flow §1.3 mandates for `gymPresence` — that
/// is a location + health special-category consent; a tier CHANGE on an
/// already-established relationship is a lighter decision, and
/// `ProgressSharingService.grantTier`'s own doc comments describe it as
/// usable directly from "a UI toggle/slider."
class _TierPickerSheet extends StatelessWidget {
  final ProgressSharingTier current;
  final AppLocalizations l10n;
  final AppPalette palette;

  const _TierPickerSheet({
    required this.current,
    required this.l10n,
    required this.palette,
  });

  String _title(ProgressSharingTier tier) => switch (tier) {
        ProgressSharingTier.none =>
          l10n.translate('progress_sharing.tier0_title'),
        ProgressSharingTier.attendance =>
          l10n.translate('progress_sharing.tier1_title'),
        ProgressSharingTier.adherence =>
          l10n.translate('progress_sharing.tier2_title'),
        ProgressSharingTier.weightTrend =>
          l10n.translate('progress_sharing.tier3_title'),
      };

  String _desc(ProgressSharingTier tier) => switch (tier) {
        ProgressSharingTier.none =>
          l10n.translate('progress_sharing.tier0_desc'),
        ProgressSharingTier.attendance =>
          l10n.translate('progress_sharing.tier1_desc'),
        ProgressSharingTier.adherence =>
          l10n.translate('progress_sharing.tier2_desc'),
        ProgressSharingTier.weightTrend =>
          l10n.translate('progress_sharing.tier3_desc'),
      };

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final tier in ProgressSharingTier.values)
          InkWell(
            onTap: () => Navigator.of(context).pop(tier),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tier == current
                    ? primary.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: tier == current ? primary : palette.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    tier == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: tier == current ? primary : palette.textTertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title(tier),
                            style: t.bodyL.copyWith(
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary)),
                        const SizedBox(height: 2),
                        Text(_desc(tier),
                            style: t.labelS.copyWith(
                                color: palette.textSecondary, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
