import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_client_model.dart';
import '../../core/models/coach_review_model.dart';
import '../../core/models/progress_sharing_model.dart';
import '../../core/services/coach_review_service.dart';
import '../../core/services/coach_service.dart';
import '../../core/services/progress_sharing_service.dart';
import '../../core/widgets/ds/ds.dart';

/// State machine for the coach-facing progress-summary section (§4.3/§4.4).
/// Replaces the old, unguarded `_generateAiReport()` (deleted — it called
/// `AIService().generateJson()` directly, client-side, with zero consent
/// check and zero relationship re-verification, confirmed still-live audit
/// finding C2). Every branch here is a real, distinct outcome
/// `ProgressSharingService.getCachedSummary`/`generateSummary` can produce.
enum _ProgressReportState {
  /// Checking for an already-cached summary (free, no callable call).
  loadingCache,

  /// Nothing cached yet — show the "generate" button (does NOT mean tier 0;
  /// that's only known after actually trying, see `_generateReport`).
  notGenerated,

  /// `generateSummary` call in flight.
  generating,

  /// Have a [MemberProgressSummaryResult] to render (either method).
  ready,

  /// `permission-denied` / `not_shared` — the member hasn't granted any
  /// tier for this scope. Shows the tier-0 empty state + invite button.
  tier0,

  /// `permission-denied` / `not_authorized_for_scope` — the coaching
  /// relationship this screen assumed no longer holds server-side.
  notAuthorized,

  /// `resource-exhausted` — already generated for this member within the
  /// rolling 24h window.
  rateLimited,

  /// Anything else (network, `ai_not_configured`, upstream failure, ...).
  error,
}

class CoachClientDetailScreen extends StatefulWidget {
  final CoachClientModel client;
  const CoachClientDetailScreen({super.key, required this.client});

  @override
  State<CoachClientDetailScreen> createState() =>
      _CoachClientDetailScreenState();
}

class _CoachClientDetailScreenState extends State<CoachClientDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Nullable bool: null = loading, true = can review, false = already reviewed
  bool? _canReview;

  _ProgressReportState _reportState = _ProgressReportState.loadingCache;
  MemberProgressSummaryResult? _summaryResult;

  // Tier-0 empty state's invite button. null = not checked yet (button
  // hidden until we know), true = already invited (ever), false = can invite.
  bool? _hasInvited;
  bool _isSendingInvite = false;

  ProgressSharingScope get _scope =>
      ProgressSharingScope.coach(widget.client.coachUid);

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isViewingOwnRecord => widget.client.clientUid == _currentUid;

  @override
  void initState() {
    super.initState();
    _fadeController =
        AnimationController(vsync: this, duration: AppMotion.normal);
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    if (_isViewingOwnRecord) {
      // generateMemberProgressSummary rejects memberUid==callerUid outright
      // (a member can't be summarized for themselves) — this section is
      // coach-only; a member viewing their own coaching record never sees
      // it at all (see build()), so there is nothing to load here.
      _checkCanReview();
    } else {
      unawaited(_loadCachedSummary());
    }
  }

  Future<void> _checkCanReview() async {
    final can = await CoachReviewService()
        .canReview(widget.client.coachUid, _currentUid);
    if (!mounted) return;
    setState(() => _canReview = can);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _endCoaching() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('coach.client_end_coaching')),
        content: Text(l10n.translate('coach.client_end_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('coach.client_end_coaching'),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await CoachService()
          .endCoaching(widget.client.coachUid, widget.client.clientUid);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('CoachClientDetailScreen._endCoaching error: $e');
      if (!mounted) return;
      AppSnackBar.error(
          context,
          AppLocalizations.of(context)
              .translate('coach.coaching.error.end_failed'));
    }
  }

  /// Reads a cached summary if one exists — a plain Firestore get, no
  /// callable call, so simply re-opening this screen never spends the
  /// once-per-24h generation allowance (see `_generateReport`).
  Future<void> _loadCachedSummary() async {
    setState(() => _reportState = _ProgressReportState.loadingCache);
    final cached = await ProgressSharingService()
        .getCachedSummary(memberUid: widget.client.clientUid, scope: _scope);
    if (!mounted) return;
    setState(() {
      if (cached != null) {
        _summaryResult = cached;
        _reportState = _ProgressReportState.ready;
      } else {
        _reportState = _ProgressReportState.notGenerated;
      }
    });
  }

  /// The "generate" button's action — the ONLY place this screen ever calls
  /// `generateSummary`. Every rejection the callable can throw
  /// (`functions/summaries.js`) maps to a distinct, human-readable state;
  /// none of them is swallowed into a generic error (R4).
  Future<void> _generateReport() async {
    setState(() => _reportState = _ProgressReportState.generating);
    final locale = Localizations.localeOf(context).languageCode;

    try {
      final result = await ProgressSharingService().generateSummary(
        memberUid: widget.client.clientUid,
        scope: _scope,
        locale: locale,
      );
      if (!mounted) return;
      setState(() {
        _summaryResult = result;
        _reportState = _ProgressReportState.ready;
      });
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
          'CoachClientDetailScreen._generateReport rejected: ${e.code} ${e.message}');
      if (!mounted) return;
      if (e.code == 'permission-denied' && e.message == 'not_shared') {
        setState(() => _reportState = _ProgressReportState.tier0);
        unawaited(_checkInviteStatus());
      } else if (e.code == 'permission-denied') {
        setState(() => _reportState = _ProgressReportState.notAuthorized);
      } else if (e.code == 'resource-exhausted') {
        setState(() => _reportState = _ProgressReportState.rateLimited);
      } else {
        setState(() => _reportState = _ProgressReportState.error);
      }
    } catch (e) {
      debugPrint('CoachClientDetailScreen._generateReport error: $e');
      if (!mounted) return;
      setState(() => _reportState = _ProgressReportState.error);
    }
  }

  Future<void> _checkInviteStatus() async {
    final invited = await ProgressSharingService()
        .hasInvited(scope: _scope, memberUid: widget.client.clientUid);
    if (!mounted) return;
    setState(() => _hasInvited = invited);
  }

  /// Tier-0 empty state's "send an invite" button — fires at most once ever
  /// per member (server-enforced, see `sendProgressShareInvite`); this
  /// handler just reflects whatever the server decided, it never assumes.
  Future<void> _sendInvite() async {
    if (_isSendingInvite || _hasInvited != false) return;
    setState(() => _isSendingInvite = true);
    final l10n = AppLocalizations.of(context);

    try {
      final result = await ProgressSharingService()
          .sendInvite(scope: _scope, memberUid: widget.client.clientUid);
      if (!mounted) return;
      if (result.outcome == ProgressShareInviteOutcome.alreadyShared) {
        // The member granted a tier between page load and tap — there is
        // no invite to send anymore. Re-check for a real report instead.
        AppSnackBar.success(
            context, l10n.translate('coach.client_detail.tier_now_shared'));
        unawaited(_loadCachedSummary());
        return;
      }
      setState(() => _hasInvited = true);
      if (result.outcome == ProgressShareInviteOutcome.sent) {
        AppSnackBar.success(
            context, l10n.translate('coach.client_detail.invite_sent'));
      }
    } catch (e) {
      debugPrint('CoachClientDetailScreen._sendInvite error: $e');
      if (!mounted) return;
      AppSnackBar.error(
          context, l10n.translate('coach.client_detail.invite_error'));
    } finally {
      if (mounted) setState(() => _isSendingInvite = false);
    }
  }

  Future<void> _showRateSheet() async {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await AppSheet.show(
      context: context,
      title: l10n.translate('coach.rate_title'),
      child: _RateCoachSheetContent(
        coachUid: widget.client.coachUid,
        reviewerUid: user.uid,
        reviewerName: user.displayName ?? '',
        reviewerPhotoUrl: user.photoURL,
        palette: palette,
        primary: primary,
        l10n: l10n,
        onSubmitted: () {
          _checkCanReview();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).primaryColor;
    final client = widget.client;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        title: Text(
          client.clientDisplayName ??
              l10n.translate('coach.client_detail_title'),
          style: AppText.of(context).headlineS.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.link_off_rounded, color: palette.error),
            tooltip: l10n.translate('coach.client_end_coaching'),
            onPressed: _endCoaching,
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClientHeader(context, client, palette, primary),
              const SizedBox(height: 24),
              _buildStatsSection(context, client, palette),
              const SizedBox(height: 24),

              // Progress summary (§4.2/§4.3/§4.4) — coach-only.
              // generateMemberProgressSummary rejects memberUid==callerUid
              // outright, so a member viewing their own coaching record has
              // nothing to request here; this section simply doesn't exist
              // for them (closes the OTHER half of C2 — the member side of
              // the old screen could trigger the same unguarded call).
              if (!_isViewingOwnRecord) ...[
                Text(
                  l10n.translate('coach.client_ai_report'),
                  style: AppText.of(context).titleM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildProgressSection(context, palette, l10n, primary),
                const SizedBox(height: 24),
              ],

              // Rate This Coach — only shown to the client themselves
              if (_isViewingOwnRecord) ...[
                if (_canReview == null)
                  const SizedBox.shrink()
                else if (_canReview == true)
                  AppButton(
                    label: l10n.translate('coach.rate_title'),
                    variant: AppButtonVariant.tonal,
                    icon: Icons.star_rounded,
                    onPressed: _showRateSheet,
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: palette.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: palette.info.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: palette.info, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.translate('coach.already_reviewed'),
                            style: AppText.of(context).bodyM.copyWith(
                                color: palette.info,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],

              // Send Message
              AppButton(
                label: l10n.translate('coach.client_send_message'),
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: client.clientUid,
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientHeader(BuildContext context, CoachClientModel client,
      AppPalette palette, Color primary) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: primary.withValues(alpha: 0.15),
          backgroundImage: client.clientPhotoURL != null
              ? CachedNetworkImageProvider(client.clientPhotoURL!)
              : null,
          child: client.clientPhotoURL == null
              ? Icon(Icons.person_rounded, color: primary, size: 32)
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.clientDisplayName ?? 'Client',
                style: AppText.of(context).headlineS.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Active',
                      style: AppText.of(context).overline.copyWith(
                          color: palette.success, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Since ${_formatDate(client.linkedAt)}',
                    style: AppText.of(context)
                        .labelS
                        .copyWith(color: palette.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(
      BuildContext context, CoachClientModel client, AppPalette palette) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFF97300),
            value: client.clientStreak?.toString() ?? '—',
            label: l10n.translate('coach.stats_day_streak'),
            palette: palette,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            iconColor: client.isAtRisk ? palette.warning : palette.info,
            value: client.daysSinceLastLog == 999
                ? 'Never'
                : '${client.daysSinceLastLog}d',
            label: l10n.translate('coach.stats_since_last_log'),
            palette: palette,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildProgressSection(BuildContext context, AppPalette palette,
      AppLocalizations l10n, Color primary) {
    switch (_reportState) {
      case _ProgressReportState.loadingCache:
        return _loadingRow(context, palette, primary,
            l10n.translate('coach.client_detail.checking_summary'));
      case _ProgressReportState.notGenerated:
        return AppButton(
          label: l10n.translate('coach.client_ai_report'),
          onPressed: _generateReport,
        );
      case _ProgressReportState.generating:
        return _loadingRow(context, palette, primary,
            l10n.translate('coach.client_ai_report_generating'));
      case _ProgressReportState.ready:
        return _ProgressSummaryCard(
          result: _summaryResult!,
          palette: palette,
          primary: primary,
          l10n: l10n,
        );
      case _ProgressReportState.tier0:
        return _Tier0EmptyState(
          palette: palette,
          l10n: l10n,
          hasInvited: _hasInvited,
          isSending: _isSendingInvite,
          onInvite: _sendInvite,
        );
      case _ProgressReportState.notAuthorized:
        return _InlineNotice(
          icon: Icons.link_off_rounded,
          color: palette.warning,
          palette: palette,
          text: l10n.translate('coach.client_detail.not_authorized'),
        );
      case _ProgressReportState.rateLimited:
        return _InlineNotice(
          icon: Icons.hourglass_bottom_rounded,
          color: palette.info,
          palette: palette,
          text: l10n.translate('coach.client_detail.rate_limited'),
        );
      case _ProgressReportState.error:
        return _InlineNotice(
          icon: Icons.error_outline_rounded,
          color: palette.error,
          palette: palette,
          text: l10n.translate('coach.client_ai_report_error'),
        );
    }
  }

  Widget _loadingRow(
      BuildContext context, AppPalette palette, Color primary, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppText.of(context)
                  .bodyM
                  .copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final AppPalette palette;
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(height: 8),
          Text(value,
              style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary, fontWeight: FontWeight.bold)),
          Text(label,
              style: AppText.of(context)
                  .labelS
                  .copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

/// Small icon+text banner for the non-happy-path report states
/// (not-authorized / rate-limited / generic error) — R7: no bare default
/// grey error text, every state gets a real design.
class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final AppPalette palette;
  final String text;

  const _InlineNotice({
    required this.icon,
    required this.color,
    required this.palette,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.textPrimary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// Small "K1"/"K2"/"K3"-style pill (localized — never hardcoded, R6)
/// showing which progress_sharing tier unlocked a given line, per the
/// plan's own requirement ("her satırın altında hangi kademeden geldiği
/// yazılı").
class _TierChip extends StatelessWidget {
  final int tier;
  final AppPalette palette;
  final AppLocalizations l10n;
  final bool small;

  const _TierChip({
    required this.tier,
    required this.palette,
    required this.l10n,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: palette.textTertiary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        l10n.translate('coach.client_detail.tier_badge',
            variables: {'tier': '$tier'}),
        style: TextStyle(
          fontSize: small ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

/// One entry in the fixed field-display order below — [tier] is the
/// consent level that unlocks this field (mirrors
/// `aggregateCoachFields`/`aggregateGymFields` in functions/summaries.js
/// exactly: tier 1 = attendance, tier 2 = +adherence, tier 3 = +weight
/// trend).
class _FieldSpec {
  final String key;
  final int tier;
  const _FieldSpec(this.key, this.tier);
}

const _kCoachFieldSpecs = [
  _FieldSpec('streak_days', 1),
  _FieldSpec('last_logged_at', 1),
  _FieldSpec('logging_regularity_pct', 2),
  _FieldSpec('plan_adherence_pct', 2),
  _FieldSpec('weight_trend', 3),
];

String _formatDateShort(DateTime date) =>
    '${date.day}/${date.month}/${date.year}';

/// One tier-attributed field line. Explicitly renders the
/// `'insufficient_data'` sentinel (functions/summaries.js's honest-gap
/// fields: `plan_adherence_pct`/`weight_trend` — no adherence calculator or
/// weight-history datasource exists anywhere in this codebase yet) as its
/// own clearly-labeled state — never hidden, never a fabricated number.
class _FieldRow extends StatelessWidget {
  final _FieldSpec spec;
  final dynamic value;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _FieldRow({
    required this.spec,
    required this.value,
    required this.palette,
    required this.l10n,
  });

  bool get _isInsufficient => value is String && value == 'insufficient_data';

  String _label() {
    if (_isInsufficient) {
      return l10n.translate('coach.client_detail.insufficient_data');
    }
    switch (spec.key) {
      case 'streak_days':
        return l10n.translate('coach.client_detail.field_streak_days',
            variables: {'days': '$value'});
      case 'last_logged_at':
        return value is DateTime
            ? l10n.translate('coach.client_detail.field_last_logged_at',
                variables: {'date': _formatDateShort(value)})
            : l10n.translate('coach.client_detail.field_never_logged');
      case 'logging_regularity_pct':
        return l10n.translate('coach.client_detail.field_logging_regularity',
            variables: {'pct': '$value'});
      case 'plan_adherence_pct':
        return l10n.translate('coach.client_detail.field_plan_adherence',
            variables: {'pct': '$value'});
      case 'weight_trend':
        return l10n.translate('coach.client_detail.field_weight_trend',
            variables: {'trend': '$value'});
      default:
        return '$value';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 6, color: palette.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _label(),
              style: AppText.of(context).bodyM.copyWith(
                    color: _isInsufficient
                        ? palette.textTertiary
                        : palette.textSecondary,
                    fontStyle:
                        _isInsufficient ? FontStyle.italic : FontStyle.normal,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          _TierChip(tier: spec.tier, palette: palette, l10n: l10n, small: true),
        ],
      ),
    );
  }
}

/// Renders a ready [MemberProgressSummaryResult] — either method. The
/// narrative is shown as a headline (clearly labeled AI vs. template, per
/// §4.3/§4.4: a template-only fallback must never look like a silently
/// missing AI report); every structured field below it carries its own
/// tier attribution, independent of which method produced the narrative.
class _ProgressSummaryCard extends StatelessWidget {
  final MemberProgressSummaryResult result;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;

  const _ProgressSummaryCard({
    required this.result,
    required this.palette,
    required this.primary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isAi = result.method == 'ai';
    final present = _kCoachFieldSpecs
        .where((s) => result.fields.containsKey(s.key))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                  isAi
                      ? Icons.auto_awesome_rounded
                      : Icons.description_outlined,
                  size: 16,
                  color: primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.translate(isAi
                      ? 'coach.client_detail.method_ai'
                      : 'coach.client_detail.method_template'),
                  style: AppText.of(context)
                      .labelS
                      .copyWith(color: primary, fontWeight: FontWeight.w700),
                ),
              ),
              _TierChip(tier: result.tier.level, palette: palette, l10n: l10n),
            ],
          ),
          if (result.narrative.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(result.narrative,
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.textSecondary, height: 1.45)),
          ],
          if (present.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: palette.divider),
            const SizedBox(height: 12),
            ...present.map((s) => _FieldRow(
                  spec: s,
                  value: result.fields[s.key],
                  palette: palette,
                  l10n: l10n,
                )),
          ],
          if (result.generatedAt != null)
            Text(
              l10n.translate('coach.client_detail.generated_at', variables: {
                'date': _formatDateShort(result.generatedAt!),
              }),
              style: AppText.of(context)
                  .labelS
                  .copyWith(color: palette.textTertiary),
            ),
        ],
      ),
    );
  }
}

/// Tier-0 empty state (§4.3): "this member hasn't opted in" + the one-time
/// invite button. [hasInvited] is null while that status is still being
/// checked, true once an invite has EVER been sent (button becomes a
/// permanent "sent" label, never re-enabled), false when it's safe to send.
class _Tier0EmptyState extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;
  final bool? hasInvited;
  final bool isSending;
  final VoidCallback onInvite;

  const _Tier0EmptyState({
    required this.palette,
    required this.l10n,
    required this.hasInvited,
    required this.isSending,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.visibility_off_rounded,
                  size: 18, color: palette.textTertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.translate('coach.client_detail.tier0_empty_title'),
                  style: AppText.of(context)
                      .bodyM
                      .copyWith(color: palette.textSecondary, height: 1.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasInvited == null)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: palette.textTertiary),
            )
          else if (hasInvited == true)
            Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 16, color: palette.success),
                const SizedBox(width: 6),
                Text(
                  l10n.translate('coach.client_detail.invite_sent'),
                  style: AppText.of(context).labelM.copyWith(
                      color: palette.success, fontWeight: FontWeight.w600),
                ),
              ],
            )
          else
            AppButton(
              label: l10n.translate('coach.client_detail.invite_button'),
              variant: AppButtonVariant.tonal,
              icon: Icons.notifications_outlined,
              loading: isSending,
              onPressed: isSending ? null : onInvite,
            ),
        ],
      ),
    );
  }
}

// ─── Rate Coach Sheet ─────────────────────────────────────────────────────────

class _RateCoachSheetContent extends StatefulWidget {
  final String coachUid;
  final String reviewerUid;
  final String reviewerName;
  final String? reviewerPhotoUrl;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;
  final VoidCallback onSubmitted;

  const _RateCoachSheetContent({
    required this.coachUid,
    required this.reviewerUid,
    required this.reviewerName,
    required this.reviewerPhotoUrl,
    required this.palette,
    required this.primary,
    required this.l10n,
    required this.onSubmitted,
  });

  @override
  State<_RateCoachSheetContent> createState() => _RateCoachSheetContentState();
}

class _RateCoachSheetContentState extends State<_RateCoachSheetContent> {
  int _selectedRating = 0;
  final TextEditingController _textController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedRating == 0 || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    final review = CoachReviewModel(
      coachUid: widget.coachUid,
      reviewerUid: widget.reviewerUid,
      reviewerName: widget.reviewerName,
      reviewerPhotoUrl: widget.reviewerPhotoUrl,
      rating: _selectedRating,
      text: _textController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await CoachReviewService().addReview(widget.coachUid, review);
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.success(
          context, widget.l10n.translate('coach.submit_review'));
      widget.onSubmitted();
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('_RateCoachSheetContent._submit error: $e');
      if (!mounted) return;
      AppSnackBar.error(context, widget.l10n.translate('coach.setup_error'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final primary = widget.primary;
    final l10n = widget.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Star selector
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < _selectedRating;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedRating = i + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 40,
                      color: filled ? primary : palette.textTertiary,
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),
          AppTextField(
            controller: _textController,
            hintText: l10n.translate('coach.review_placeholder'),
            maxLines: 4,
            minLines: 3,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: l10n.translate('coach.submit_review'),
            onPressed: _selectedRating > 0 && !_isSubmitting ? _submit : null,
            loading: _isSubmitting,
          ),
        ],
      ),
    );
  }
}
