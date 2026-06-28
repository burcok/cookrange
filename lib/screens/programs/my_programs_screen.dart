import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/program_enrollment_model.dart';
import '../../core/models/program_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/program_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'program_detail_screen.dart';
import 'program_marketplace_screen.dart';

class MyProgramsScreen extends StatelessWidget {
  const MyProgramsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('program.my_programs'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.explore_outlined,
                color: palette.textSecondary, size: 22),
            onPressed: () => Navigator.of(context).push(AppTransitions.slideUp(
                const ProgramMarketplaceScreen())),
            tooltip: l10n.translate('program.my_programs_explore'),
          ),
        ],
      ),
      body: uid == null
          ? const AppErrorState(title: 'Sign in to view your programs')
          : StreamBuilder<
                List<
                    ({
                      ProgramEnrollmentModel enrollment,
                      ProgramModel? program
                    })>>(
              stream: ProgramService().getEnrolledProgramsStream(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: AppSkeletonList(itemCount: 4),
                  );
                }

                if (snap.hasError) {
                  return AppErrorState(
                    title: l10n.translate('common.error'),
                    onRetry: () => setState(() {}),
                  );
                }

                final pairs = snap.data ?? [];

                if (pairs.isEmpty) {
                  return AppEmptyState(
                    icon: Icons.fitness_center_rounded,
                    title: l10n.translate('program.my_programs_empty'),
                    message: l10n.translate('program.my_programs_empty_msg'),
                    actionLabel:
                        l10n.translate('program.my_programs_explore'),
                    onAction: () => Navigator.of(context).pushReplacement(
                      AppTransitions.slideUp(
                          const ProgramMarketplaceScreen()),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 40.h),
                  itemCount: pairs.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final p = pairs[index];
                    return _ProgramCard(
                      enrollment: p.enrollment,
                      program: p.program,
                      primary: primary,
                      palette: palette,
                      l10n: l10n,
                      t: t,
                    );
                  },
                );
              },
            ),
    );
  }

  void setState(VoidCallback fn) {} // suppress lint; not a StatefulWidget
}

// ── Program card ──────────────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  final ProgramEnrollmentModel enrollment;
  final ProgramModel? program;
  final Color primary;
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _ProgramCard({
    required this.enrollment,
    required this.program,
    required this.primary,
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final p = program;

    return AppCard(
      onTap: p == null
          ? null
          : () => Navigator.of(context).push(
                AppTransitions.slideUp(ProgramDetailScreen(program: p)),
              ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover / category gradient
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
            child: p?.coverImageUrl != null
                ? Image.network(
                    p!.coverImageUrl!,
                    width: 72.r,
                    height: 72.r,
                    fit: BoxFit.cover,
                    cacheWidth: 288,
                    errorBuilder: (_, __, ___) =>
                        _GradientThumb(category: p.category, size: 72.r),
                  )
                : _GradientThumb(
                    category: p?.category ?? ProgramCategory.lifestyle,
                    size: 72.r,
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enrollment.programTitle,
                  style: t.bodyM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  l10n
                      .translate('program.progress_label')
                      .replaceFirst(
                          '{current}', enrollment.currentWeek.toString())
                      .replaceFirst(
                          '{total}', enrollment.totalWeeks.toString()),
                  style: t.labelS.copyWith(color: palette.textSecondary),
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: enrollment.progressPercent,
                    backgroundColor: primary.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                    minHeight: 5.h,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(enrollment.progressPercent * 100).toInt()}%',
                      style: t.labelS.copyWith(
                          color: primary, fontWeight: FontWeight.w700),
                    ),
                    if (p != null)
                      Text(
                        l10n.translate('program.continue_label'),
                        style: t.labelS.copyWith(
                            color: primary, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini gradient thumbnail ───────────────────────────────────────────────────

class _GradientThumb extends StatelessWidget {
  final ProgramCategory category;
  final double size;
  const _GradientThumb({required this.category, required this.size});

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
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(Icons.fitness_center_rounded,
          color: Colors.white.withValues(alpha: 0.7), size: size * 0.4),
    );
  }
}
