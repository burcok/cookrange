import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/food_log_service.dart';
import '../../../core/widgets/ds/ds.dart';
import '../../home/food_scan_screen.dart';
import '../../challenges/challenges_screen.dart';

class _Step {
  final bool done;
  final String labelKey;
  final String ctaKey;
  final void Function(BuildContext context) onTap;
  final IconData icon;

  const _Step({
    required this.done,
    required this.labelKey,
    required this.ctaKey,
    required this.onTap,
    required this.icon,
  });
}

class ProfileCompletenessCard extends StatefulWidget {
  final UserModel user;

  const ProfileCompletenessCard({super.key, required this.user});

  @override
  State<ProfileCompletenessCard> createState() =>
      _ProfileCompletenessCardState();
}

class _ProfileCompletenessCardState extends State<ProfileCompletenessCard> {
  bool _hasMealLog = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkMealLog();
  }

  Future<void> _checkMealLog() async {
    try {
      final logs = await FoodLogService()
          .todayLogsStream(widget.user.uid)
          .first
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _hasMealLog = logs.isNotEmpty;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Step> _buildSteps(BuildContext context) => [
        _Step(
          done: widget.user.photoURL != null &&
              widget.user.photoURL!.isNotEmpty,
          labelKey: 'profile_meter.step_photo',
          ctaKey: 'profile_meter.cta_photo',
          onTap: (ctx) => Navigator.of(ctx).pop(),
          icon: Icons.add_a_photo_rounded,
        ),
        _Step(
          done: _hasMealLog,
          labelKey: 'profile_meter.step_meal',
          ctaKey: 'profile_meter.cta_meal',
          onTap: (ctx) => Navigator.of(ctx)
              .push(AppTransitions.slideRight(const FoodScanScreen())),
          icon: Icons.restaurant_rounded,
        ),
        _Step(
          done: false,
          labelKey: 'profile_meter.step_challenge',
          ctaKey: 'profile_meter.cta_challenge',
          onTap: (ctx) => Navigator.of(ctx)
              .push(AppTransitions.slideRight(const ChallengesScreen())),
          icon: Icons.emoji_events_rounded,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppSkeletonBox(
        height: 80,
        radius: AppRadius.card,
      );
    }

    final steps = _buildSteps(context);
    final completedCount = steps.where((s) => s.done).length;

    if (completedCount == steps.length) return const SizedBox.shrink();

    final pct = (completedCount / steps.length * 100).round();
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return AppCard(
      bordered: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('profile_meter.title'),
                      style: t.titleM
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      l10n
                          .translate('profile_meter.subtitle')
                          .replaceAll('{pct}', '$pct'),
                      style: t.labelM
                          .copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              Semantics(
                label: '$pct% profile complete',
                child: SizedBox(
                  width: 40.r,
                  height: 40.r,
                  child: CircularProgressIndicator(
                    value: completedCount / steps.length,
                    strokeWidth: 4,
                    backgroundColor: palette.border,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(palette.success),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...steps.where((s) => !s.done).map(
                (s) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    children: [
                      Icon(s.icon,
                          size: 16.r, color: palette.textSecondary),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          l10n.translate(s.labelKey),
                          style: t.bodyM
                              .copyWith(color: palette.textSecondary),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: l10n.translate(s.ctaKey),
                        child: GestureDetector(
                          onTap: () => s.onTap(context),
                          child: SizedBox(
                            height: 44,
                            child: Center(
                              child: Text(
                                l10n.translate(s.ctaKey),
                                style: t.labelS.copyWith(
                                  color: Theme.of(context).primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
