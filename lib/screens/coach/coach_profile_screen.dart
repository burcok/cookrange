import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_review_model.dart';
import '../../core/services/coach_review_service.dart';
import '../../core/services/coach_service.dart';
import '../../core/models/coach_profile_model.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/coach_share_card.dart';
import '../../core/widgets/coachmark_tip.dart';
import '../../core/widgets/ds/ds.dart';

class CoachProfileScreen extends StatefulWidget {
  final String coachUid;
  const CoachProfileScreen({super.key, required this.coachUid});

  @override
  State<CoachProfileScreen> createState() => _CoachProfileScreenState();
}

class _CoachProfileScreenState extends State<CoachProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isSending = false;

  String get _currentUid => FirebaseAuth.instance.currentUser?.uid ?? '';

  bool get _isSelf => widget.coachUid == _currentUid;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _sendRequest() async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await CoachService().requestCoaching(widget.coachUid, _currentUid);
      if (!mounted) return;
      setState(() => _isSending = false);
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.success(context,
          AppLocalizations.of(context).translate('coach.profile_request_sent'));
    } catch (e) {
      debugPrint('CoachProfileScreen._sendRequest error: $e');
      if (!mounted) return;
      setState(() => _isSending = false);
      AppSnackBar.error(
          context, AppLocalizations.of(context).translate('coach.setup_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      body: StreamBuilder<CoachProfileModel?>(
        stream: CoachService().getCoachProfileStream(widget.coachUid),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorState(
              title: AppLocalizations.of(context).translate('common.something_wrong'),
              message: snapshot.error.toString(),
              onRetry: () => setState(() {}),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = snapshot.data;
          if (profile == null) {
            return Scaffold(
              backgroundColor: palette.background,
              appBar: AppBar(
                backgroundColor: palette.background,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded,
                      color: palette.textPrimary, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: AppErrorState(
                title: l10n.translate('coach.not_found_title'),
                message: l10n.translate('coach.not_found_body'),
              ),
            );
          }

          return FadeTransition(
            opacity: _fadeAnimation,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(context, profile, palette, l10n, primary),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                          Text(profile.bio!,
                              style: AppText.of(context)
                                  .bodyM
                                  .copyWith(color: palette.textSecondary)),
                          const SizedBox(height: 24),
                        ],
                        if (profile.specializations.isNotEmpty) ...[
                          Text(AppLocalizations.of(context).translate('coach.profile.section_specializations'),
                              style: AppText.of(context).titleM.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.specializations
                                .map((s) => _SpecChip(
                                    label: s,
                                    palette: palette,
                                    primary: primary))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (profile.certifications.isNotEmpty) ...[
                          Text(AppLocalizations.of(context).translate('coach.profile.section_certifications'),
                              style: AppText.of(context).titleM.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: profile.certifications
                                .map((c) => _CertBadge(
                                    label: c,
                                    palette: palette,
                                    primary: primary))
                                .toList(),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _buildStatsRow(context, profile, palette),
                        const SizedBox(height: 16),
                        if (!_isSelf)
                          FutureBuilder<bool>(
                            future: CoachReviewService()
                                .canReview(profile.uid, _currentUid),
                            builder: (context, snap) {
                              if (snap.data != true) {
                                return const SizedBox.shrink();
                              }
                              return CoachmarkTip(
                                prefKey: 'rate_coach_coachmark_${profile.uid}',
                                title: l10n.translate(
                                    'coach.rate_coachmark_tip_title'),
                                body:
                                    l10n.translate('coach.rate_coachmark_tip'),
                              );
                            },
                          ),
                        const SizedBox(height: 16),
                        if (_isSelf)
                          _InfoBanner(
                            message: l10n.translate('coach.request_self'),
                            color: palette.info,
                            palette: palette,
                          )
                        else if (profile.isAcceptingClients)
                          StreamBuilder<String?>(
                            stream: CoachService().getRequestStatusStream(
                                widget.coachUid, _currentUid),
                            builder: (context, snap) {
                              if (snap.hasError) {
                                return AppErrorState(
                                  title: AppLocalizations.of(context).translate('common.something_wrong'),
                                  message: snap.error.toString(),
                                  onRetry: () => setState(() {}),
                                );
                              }
                              final status = snap.data;
                              if (status == 'accepted') {
                                return _InfoBanner(
                                  message:
                                      l10n.translate('coach.request_accepted'),
                                  color: palette.success,
                                  palette: palette,
                                );
                              }
                              if (status == 'pending') {
                                return _InfoBanner(
                                  message:
                                      l10n.translate('coach.request_pending'),
                                  color: palette.warning,
                                  palette: palette,
                                );
                              }
                              return AppButton(
                                label:
                                    l10n.translate('coach.profile_request_btn'),
                                onPressed: _isSending ? null : _sendRequest,
                                loading: _isSending,
                              );
                            },
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: palette.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                  color:
                                      palette.warning.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    color: palette.warning, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.translate('coach.profile_not_accepting'),
                                  style: AppText.of(context).bodyM.copyWith(
                                      color: palette.warning,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 32),
                        _ReviewsSection(
                          coachUid: widget.coachUid,
                          avgRating: profile.avgRating,
                          ratingCount: profile.ratingCount,
                          palette: palette,
                          l10n: l10n,
                          primary: primary,
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, CoachProfileModel profile,
      AppPalette palette, AppLocalizations l10n, Color primary) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: palette.background,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            color: palette.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon:
              Icon(Icons.share_rounded, color: palette.textSecondary, size: 22),
          tooltip: l10n.translate('share.share_profile'),
          onPressed: () => CoachShareCard.share(context, profile),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.15),
                palette.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: primary.withValues(alpha: 0.4), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                        color: primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2),
                  ],
                ),
                child: ClipOval(
                  child: profile.photoURL != null
                      ? AppImage(
                          imageUrl: profile.photoURL!,
                          memCacheWidth: 320)
                      : Container(
                          color: primary.withValues(alpha: 0.15),
                          child: Icon(Icons.person_rounded,
                              size: 40, color: primary),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    profile.displayName,
                    style: AppText.of(context).headlineS.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.translate('coach.profile_coach_badge'),
                      style: AppText.of(context).overline.copyWith(
                          color: primary, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    profile.isAcceptingClients
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 14,
                    color: profile.isAcceptingClients
                        ? palette.success
                        : palette.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l10n.translate(profile.isAcceptingClients
                        ? 'coach.profile_accepting'
                        : 'coach.profile_not_accepting'),
                    style: AppText.of(context).labelS.copyWith(
                        color: profile.isAcceptingClients
                            ? palette.success
                            : palette.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(
      BuildContext context, CoachProfileModel profile, AppPalette palette) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.people_alt_rounded,
            value: profile.clientCount.toString(),
            label: AppLocalizations.of(context).translate('coach.profile.stat_clients'),
            palette: palette,
          ),
        ),
        if (profile.hourlyRate != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.attach_money_rounded,
              value: '₺${profile.hourlyRate!.toStringAsFixed(0)}/saat',
              label: AppLocalizations.of(context).translate('coach.profile.stat_rate'),
              palette: palette,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String message;
  final Color color;
  final AppPalette palette;

  const _InfoBanner({
    required this.message,
    required this.color,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.of(context).bodyM.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final String label;
  final AppPalette palette;
  final Color primary;
  const _SpecChip(
      {required this.label, required this.palette, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: AppText.of(context)
              .labelS
              .copyWith(color: primary, fontWeight: FontWeight.w600)),
    );
  }
}

class _CertBadge extends StatelessWidget {
  final String label;
  final AppPalette palette;
  final Color primary;
  const _CertBadge(
      {required this.label, required this.palette, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 14, color: palette.success),
          const SizedBox(width: 4),
          Text(label,
              style: AppText.of(context).labelS.copyWith(
                  color: palette.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final AppPalette palette;
  const _StatCard(
      {required this.icon,
      required this.value,
      required this.label,
      required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.textSecondary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppText.of(context).titleM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.bold)),
              Text(label,
                  style: AppText.of(context)
                      .labelS
                      .copyWith(color: palette.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Reviews Section ──────────────────────────────────────────────────────────

class _ReviewsSection extends StatelessWidget {
  final String coachUid;
  final double avgRating;
  final int ratingCount;
  final AppPalette palette;
  final AppLocalizations l10n;
  final Color primary;

  const _ReviewsSection({
    required this.coachUid,
    required this.avgRating,
    required this.ratingCount,
    required this.palette,
    required this.l10n,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Text(
          l10n.translate('coach.reviews_title'),
          style: AppText.of(context).titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Rating summary
        if (ratingCount > 0) ...[
          _RatingSummary(
            avgRating: avgRating,
            ratingCount: ratingCount,
            palette: palette,
            l10n: l10n,
            primary: primary,
          ),
          const SizedBox(height: 16),
        ],
        // Review list
        StreamBuilder<List<CoachReviewModel>>(
          stream: CoachReviewService().getReviewsStream(coachUid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppErrorState(
                title: l10n.translate('common.something_wrong'),
                message: snapshot.error.toString(),
                onRetry: () {},
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppSkeletonList(itemCount: 3);
            }
            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) {
              return AppEmptyState(
                title: l10n.translate('coach.no_reviews'),
                icon: Icons.star_border_rounded,
              );
            }
            return Column(
              children: reviews
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReviewRow(
                            review: r, palette: palette, primary: primary),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _RatingSummary extends StatelessWidget {
  final double avgRating;
  final int ratingCount;
  final AppPalette palette;
  final AppLocalizations l10n;
  final Color primary;

  const _RatingSummary({
    required this.avgRating,
    required this.ratingCount,
    required this.palette,
    required this.l10n,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          avgRating.toStringAsFixed(1),
          style: AppText.of(context).displayL.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(5, (i) {
                final filled = i < avgRating.round();
                return Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 20,
                  color: filled ? primary : palette.textTertiary,
                );
              }),
            ),
            const SizedBox(height: 4),
            Text(
              l10n
                  .translate('coach.rating_count')
                  .replaceAll('{count}', ratingCount.toString()),
              style: AppText.of(context)
                  .labelS
                  .copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final CoachReviewModel review;
  final AppPalette palette;
  final Color primary;

  const _ReviewRow({
    required this.review,
    required this.palette,
    required this.primary,
  });

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) {
      return DateFormat('MMM yyyy').format(dt);
    }
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    return '${diff.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return AppGlassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppInitialsAvatar(
                  photoUrl: review.reviewerPhotoUrl,
                  name: review.reviewerName,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.reviewerName,
                        style: AppText.of(context).bodyM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          Row(
                            children: List.generate(5, (i) {
                              final filled = i < review.rating;
                              return Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 14,
                                color: filled ? primary : palette.textTertiary,
                              );
                            }),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _relativeTime(review.createdAt),
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
            ),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                review.text,
                style: AppText.of(context)
                    .bodyM
                    .copyWith(color: palette.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
