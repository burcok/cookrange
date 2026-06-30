import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/achievement_model.dart';
import '../../../core/services/achievement_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/ds/app_shimmer.dart';
import '../../../core/widgets/ds/app_sheet.dart';

/// Profile section showing all badges in a wrap grid — earned ones glow,
/// locked ones are greyed out. Tapping any badge opens a detail sheet.
class AchievementsGrid extends StatefulWidget {
  final String uid;

  const AchievementsGrid({super.key, required this.uid});

  @override
  State<AchievementsGrid> createState() => _AchievementsGridState();
}

class _AchievementsGridState extends State<AchievementsGrid> {
  late final Stream<List<AchievementRecord>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = AchievementService().getAchievementsStream(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return StreamBuilder<List<AchievementRecord>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _skeleton();
        }
        final earned = {
          for (final r in snap.data ?? <AchievementRecord>[]) r.key: r
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
              child: Text(
                l10n.translate('achievements.title'),
                style: t.titleM.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
              child: Wrap(
                spacing: AppSpacing.sm.w,
                runSpacing: AppSpacing.sm.h,
                children: kAchievementCatalog.keys.map((key) {
                  final record = earned[key];
                  return _BadgeTile(
                    def: kAchievementCatalog[key]!,
                    record: record,
                    onTap: () =>
                        _showDetail(context, kAchievementCatalog[key]!, record),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: AppSpacing.md.h),
          ],
        );
      },
    );
  }

  Widget _skeleton() => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
        child: Wrap(
          spacing: AppSpacing.sm.w,
          runSpacing: AppSpacing.sm.h,
          children: List.generate(
            6,
            (_) => AppSkeletonBox(
              width: 64.w,
              height: 80.h,
              radius: AppRadius.md.r,
            ),
          ),
        ),
      );

  void _showDetail(
      BuildContext context, AchievementDef def, AchievementRecord? record) {
    final l10n = AppLocalizations.of(context);
    AppSheet.show(
      context: context,
      title: l10n.translate(def.titleKey),
      child: _BadgeDetailSheet(def: def, record: record),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _BadgeTile extends StatefulWidget {
  final AchievementDef def;
  final AchievementRecord? record;
  final VoidCallback onTap;

  const _BadgeTile({
    required this.def,
    required this.record,
    required this.onTap,
  });

  @override
  State<_BadgeTile> createState() => _BadgeTileState();
}

class _BadgeTileState extends State<_BadgeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(vsync: this, duration: AppMotion.normal);
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctl, curve: AppMotion.spring),
    );
    if (widget.record != null) _ctl.forward();
  }

  @override
  void didUpdateWidget(_BadgeTile old) {
    super.didUpdateWidget(old);
    if (old.record == null && widget.record != null) {
      _ctl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final earned = widget.record != null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: (earned && !reduceMotion)
            ? _scale
            : const AlwaysStoppedAnimation(1.0),
        child: Container(
          width: 64.w,
          height: 80.h,
          decoration: BoxDecoration(
            color: earned
                ? palette.surface
                : palette.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: earned
                  ? palette.textTertiary.withValues(alpha: 0.4)
                  : palette.border.withValues(alpha: 0.3),
            ),
            boxShadow: earned
                ? [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.12),
                      blurRadius: 6.r,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.def.emoji,
                style: TextStyle(
                  fontSize: 26.sp,
                  color: earned ? null : palette.textTertiary,
                ),
              ),
              SizedBox(height: 4.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 3.w),
                child: Text(
                  l10n.translate(widget.def.titleKey),
                  style: t.labelS.copyWith(
                    color: earned ? palette.textPrimary : palette.textTertiary,
                    fontWeight: earned ? FontWeight.bold : FontWeight.normal,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _BadgeDetailSheet extends StatelessWidget {
  final AchievementDef def;
  final AchievementRecord? record;

  const _BadgeDetailSheet({required this.def, required this.record});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final earned = record != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.xl.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(def.emoji, style: TextStyle(fontSize: 56.sp)),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            l10n.translate(def.titleKey),
            style: t.headlineS.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            l10n.translate(def.descKey),
            style: t.bodyM.copyWith(color: palette.textSecondary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.md.h),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
            decoration: BoxDecoration(
              color: (earned ? palette.success : palette.textTertiary)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full.r),
            ),
            child: Text(
              earned
                  ? l10n.translate('achievements.earned_on', variables: {
                      'date': _fmt(record!.earnedAt),
                    })
                  : l10n.translate('achievements.locked'),
              style: t.labelM.copyWith(
                color: earned ? palette.success : palette.textTertiary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            '+${def.points} ${l10n.translate('achievements.points')}',
            style: t.labelS.copyWith(color: palette.textTertiary),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}
