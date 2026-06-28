import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/program_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/services/program_service.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/ds/ds.dart';

class ProgramDetailScreen extends StatefulWidget {
  final ProgramModel program;

  const ProgramDetailScreen({super.key, required this.program});

  @override
  State<ProgramDetailScreen> createState() => _ProgramDetailScreenState();
}

class _ProgramDetailScreenState extends State<ProgramDetailScreen> {
  bool _descExpanded = false;
  bool _enrolling = false;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  ProgramModel get _p => widget.program;

  Future<void> _handleEnroll() async {
    final uid = _currentUid;
    if (uid == null) return;
    final l10n = AppLocalizations.of(context);

    setState(() => _enrolling = true);
    try {
      await ProgramService().enrollInProgram(uid, _p);
      if (!mounted) return;
      AppSnackBar.success(
          context, l10n.translate('program.enrollment_success'));
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  Future<void> _handleBuy() async {
    final l10n = AppLocalizations.of(context);
    await FeatureGateService().showPaywall(
      context,
      featureName: l10n.translate('program.buy'),
      featureDescription: l10n.translate('program.paid_coming_soon'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final uid = _currentUid;

    return Scaffold(
      backgroundColor: palette.background,
      body: uid == null
          ? const AppErrorState(title: 'Sign in to view programs')
          : FutureBuilder<bool>(
              future: ProgramService().isEnrolled(uid, _p.id),
              builder: (context, enrollSnap) {
                return CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(context, palette, primary, t),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            AppSpacing.screenH.w,
                            AppSpacing.md.h,
                            AppSpacing.screenH.w,
                            100.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTitleSection(context, palette, primary, t, l10n),
                            SizedBox(height: AppSpacing.md.h),
                            _buildMetaRow(context, palette, t, l10n),
                            SizedBox(height: AppSpacing.lg.h),
                            _buildCoachCard(context, palette, primary, t, l10n),
                            if (_p.highlights.isNotEmpty) ...[
                              SizedBox(height: AppSpacing.lg.h),
                              _buildHighlights(context, palette, primary, t, l10n),
                            ],
                            SizedBox(height: AppSpacing.lg.h),
                            _buildDescription(context, palette, primary, t, l10n),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: uid == null
          ? null
          : FutureBuilder<bool>(
              future: ProgramService().isEnrolled(uid, _p.id),
              builder: (context, snap) {
                final isEnrolled = snap.data ?? false;
                return _buildEnrollBar(
                    context, palette, primary, t, l10n, isEnrolled);
              },
            ),
    );
  }

  // ── Sliver AppBar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppText t,
  ) {
    return SliverAppBar(
      expandedHeight: 240.h,
      pinned: true,
      backgroundColor: palette.surface,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: _p.coverImageUrl != null
            ? Image.network(
                _p.coverImageUrl!,
                fit: BoxFit.cover,
                cacheWidth: 800,
                errorBuilder: (_, __, ___) =>
                    _CoverGradient(category: _p.category),
              )
            : _CoverGradient(category: _p.category),
      ),
    );
  }

  // ── Title section ──────────────────────────────────────────────────────────

  Widget _buildTitleSection(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppText t,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _p.title,
          style: t.headlineS.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 8.h),
        Wrap(
          spacing: 6.w,
          runSpacing: 4.h,
          children: [
            _badge(
              l10n.translate(_p.category.locKey),
              primary.withValues(alpha: 0.15),
              primary,
              t,
            ),
            _badge(
              l10n.translate(_p.difficulty.locKey),
              _difficultyColor(_p.difficulty).withValues(alpha: 0.15),
              _difficultyColor(_p.difficulty),
              t,
            ),
          ],
        ),
        if (_p.rating > 0) ...[
          SizedBox(height: 8.h),
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < _p.rating.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16.r,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              SizedBox(width: 6.w),
              Text(
                '${_p.rating.toStringAsFixed(1)} (${_p.ratingCount})',
                style: t.labelM.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Meta row ───────────────────────────────────────────────────────────────

  Widget _buildMetaRow(
    BuildContext context,
    AppPalette palette,
    AppText t,
    AppLocalizations l10n,
  ) {
    final items = [
      (
        Icons.calendar_today_outlined,
        l10n
            .translate('program.duration_weeks')
            .replaceFirst('{n}', _p.durationWeeks.toString())
      ),
      (
        Icons.repeat_rounded,
        l10n
            .translate('program.sessions_per_week')
            .replaceFirst('{n}', _p.sessionsPerWeek.toString())
      ),
      (
        Icons.people_outline_rounded,
        l10n
            .translate('program.enrollment_count')
            .replaceFirst('{n}', _p.enrollmentCount.toString())
      ),
    ];

    return Row(
      children: items
          .expand((item) => [
                _metaChip(item.$1, item.$2, palette, t),
                SizedBox(width: 8.w),
              ])
          .toList(),
    );
  }

  Widget _metaChip(
      IconData icon, String label, AppPalette palette, AppText t) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        border: Border.all(color: palette.border.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.r, color: palette.textSecondary),
          SizedBox(width: 4.w),
          Text(label,
              style: t.labelS.copyWith(color: palette.textSecondary)),
        ],
      ),
    );
  }

  // ── Coach card ─────────────────────────────────────────────────────────────

  Widget _buildCoachCard(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppText t,
    AppLocalizations l10n,
  ) {
    return AppCard(
      bordered: true,
      elevated: false,
      child: Row(
        children: [
          GestureDetector(
            onTap: () =>
                openUserProfile(context, userId: _p.coachUid),
            child: ClipOval(
              child: _p.coachPhotoUrl != null
                  ? Image.network(
                      _p.coachPhotoUrl!,
                      width: 48.r,
                      height: 48.r,
                      fit: BoxFit.cover,
                      cacheWidth: 192,
                      errorBuilder: (_, __, ___) =>
                          _coachAvatarPlaceholder(primary),
                    )
                  : _coachAvatarPlaceholder(primary),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('program.coach_section'),
                  style:
                      t.labelS.copyWith(color: palette.textSecondary),
                ),
                Text(
                  _p.coachName,
                  style: t.titleM
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                openUserProfile(context, userId: _p.coachUid),
            style: TextButton.styleFrom(foregroundColor: primary),
            child: Text(
              'View Profile',
              style:
                  t.labelM.copyWith(color: primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coachAvatarPlaceholder(Color primary) {
    return Container(
      width: 48.r,
      height: 48.r,
      color: primary.withValues(alpha: 0.15),
      child: Icon(Icons.person_rounded, color: primary, size: 24.r),
    );
  }

  // ── Highlights ─────────────────────────────────────────────────────────────

  Widget _buildHighlights(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppText t,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('program.highlights'),
          style:
              t.titleM.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 10.h),
        ..._p.highlights.map((h) => Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: EdgeInsets.only(top: 2.h, right: 10.w),
                    width: 20.r,
                    height: 20.r,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_rounded,
                        size: 12.r, color: primary),
                  ),
                  Expanded(
                    child: Text(h,
                        style: t.bodyM
                            .copyWith(color: palette.textPrimary)),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ── Description ────────────────────────────────────────────────────────────

  Widget _buildDescription(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppText t,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('program.description'),
          style:
              t.titleM.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: 8.h),
        AnimatedCrossFade(
          firstChild: Text(
            _p.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          secondChild: Text(
            _p.description,
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          crossFadeState: _descExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: AppMotion.normal,
        ),
        SizedBox(height: 4.h),
        GestureDetector(
          onTap: () => setState(() => _descExpanded = !_descExpanded),
          child: Text(
            l10n.translate(
                _descExpanded ? 'program.read_less' : 'program.read_more'),
            style: t.labelM.copyWith(
                color: primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ── Enroll sticky bar ──────────────────────────────────────────────────────

  Widget _buildEnrollBar(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppText t,
    AppLocalizations l10n,
    bool isEnrolled,
  ) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.screenH.w, 12.h, AppSpacing.screenH.w, 12.h + safeBottom),
      decoration: BoxDecoration(
        color: palette.surface,
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _p.priceDisplay,
                  style: t.titleL.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _p.isFree
                        ? const Color(0xFF10B981)
                        : primary,
                  ),
                ),
                if (_p.isFree)
                  Text(
                    l10n.translate('program.free'),
                    style: t.labelS.copyWith(color: palette.textSecondary),
                  ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            flex: 2,
            child: isEnrolled
                ? AppButton(
                    label: l10n.translate('program.enrolled'),
                    onPressed: null,
                    variant: AppButtonVariant.tonal,
                    icon: Icons.check_circle_outline_rounded,
                  )
                : _p.isFree
                    ? AppButton(
                        label: l10n.translate('program.enroll'),
                        onPressed: _enrolling ? null : _handleEnroll,
                        loading: _enrolling,
                        icon: Icons.play_arrow_rounded,
                      )
                    : AppButton(
                        label:
                            '${l10n.translate('program.buy')} — ${_p.priceDisplay}',
                        onPressed: _handleBuy,
                        icon: Icons.lock_outline_rounded,
                      ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _badge(String label, Color bg, Color fg, AppText t) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Text(label,
          style: t.labelS.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }

  Color _difficultyColor(ProgramDifficulty d) {
    switch (d) {
      case ProgramDifficulty.beginner:
        return const Color(0xFF10B981);
      case ProgramDifficulty.intermediate:
        return const Color(0xFFF59E0B);
      case ProgramDifficulty.advanced:
        return const Color(0xFFEF4444);
    }
  }
}

// ── Cover gradient ─────────────────────────────────────────────────────────────

class _CoverGradient extends StatelessWidget {
  final ProgramCategory category;
  const _CoverGradient({required this.category});

  List<Color> get _colors {
    switch (category) {
      case ProgramCategory.weightLoss:
        return [const Color(0xFFEF4444), const Color(0xFFF97316)];
      case ProgramCategory.muscleGain:
        return [const Color(0xFF6366F1), const Color(0xFF8B5CF6)];
      case ProgramCategory.endurance:
        return [const Color(0xFF06B6D4), const Color(0xFF3B82F6)];
      case ProgramCategory.flexibility:
        return [const Color(0xFF10B981), const Color(0xFF06B6D4)];
      case ProgramCategory.nutrition:
        return [const Color(0xFFF59E0B), const Color(0xFF10B981)];
      case ProgramCategory.lifestyle:
        return [const Color(0xFFEC4899), const Color(0xFF8B5CF6)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
