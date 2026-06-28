import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/models/exercise_log_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/exercise_log_service.dart';
import '../../../core/widgets/ds/ds.dart';

class ExerciseLogSheet extends StatefulWidget {
  const ExerciseLogSheet({super.key});

  static Future<bool?> show(BuildContext context) => AppSheet.show<bool>(
        context: context,
        title: AppLocalizations.of(context).translate('exercise.title'),
        child: const ExerciseLogSheet(),
      );

  @override
  State<ExerciseLogSheet> createState() => _ExerciseLogSheetState();
}

class _ExerciseLogSheetState extends State<ExerciseLogSheet> {
  ExerciseType _selected = ExerciseType.all.first;
  int _durationMinutes = 30;
  bool _isLogging = false;

  static const _exerciseIcons = <String, IconData>{
    'running': Icons.directions_run_rounded,
    'walking': Icons.directions_walk_rounded,
    'cycling': Icons.directions_bike_rounded,
    'swimming': Icons.pool_rounded,
    'weight_training': Icons.fitness_center_rounded,
    'hiit': Icons.local_fire_department_rounded,
    'yoga': Icons.self_improvement_rounded,
    'jump_rope': Icons.sports_gymnastics,
    'basketball': Icons.sports_basketball_rounded,
    'football': Icons.sports_soccer_rounded,
    'dancing': Icons.music_note_rounded,
    'other': Icons.directions_walk_rounded,
  };

  double _estimatedCalories(UserModel? user) {
    final weight = (user?.profile.weightKg ?? 70).toDouble();
    return _selected.estimateCalories(
        weightKg: weight, durationMinutes: _durationMinutes);
  }

  Future<void> _log() async {
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    setState(() => _isLogging = true);
    unawaited(HapticFeedback.mediumImpact());

    try {
      final calories = _estimatedCalories(user);
      await ExerciseLogService().logExercise(
        userId: user.uid,
        exerciseKey: _selected.key,
        durationMinutes: _durationMinutes,
        caloriesBurned: calories,
      );

      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        Navigator.of(context).pop(true);
        AppSnackBar.success(
          context,
          AppLocalizations.of(context).translate('exercise.logged_success'),
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLogging = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final user = context.watch<UserProvider>().user;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final estimated = _estimatedCalories(user);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Estimated calorie banner
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.15),
                    primary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppRadius.card.r),
                border: Border.all(color: primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_fire_department_rounded,
                      color: palette.calories, size: 28.sp),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.translate('exercise.estimated_burn'),
                          style: t.labelM),
                      Text(
                        '${estimated.toInt()} kcal',
                        style: t.headlineM.copyWith(
                            color: palette.calories,
                            fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Exercise type grid
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(l10n.translate('exercise.type_label'), style: t.titleM),
          ),
          SizedBox(height: 10.h),
          SizedBox(
            height: 110.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              itemCount: ExerciseType.all.length,
              separatorBuilder: (_, __) => SizedBox(width: 10.w),
              itemBuilder: (context, i) {
                final ex = ExerciseType.all[i];
                final isSelected = _selected.key == ex.key;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = ex);
                  },
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    width: 80.w,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary
                          : palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.card.r),
                      border: Border.all(
                          color: isSelected
                              ? primary
                              : palette.border.withValues(alpha: 0.5)),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _exerciseIcons[ex.key] ?? Icons.sports_rounded,
                          color: isSelected ? Colors.white : palette.textSecondary,
                          size: 28.sp,
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          l10n.translate('exercise.types.${ex.key}'),
                          style: t.labelS.copyWith(
                            color: isSelected
                                ? Colors.white
                                : palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 24.h),

          // Duration slider
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.translate('exercise.duration_label'), style: t.titleM),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.button.r),
                  ),
                  child: Text(
                    '$_durationMinutes ${l10n.translate('exercise.minutes')}',
                    style: t.labelM.copyWith(
                        color: primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Slider(
            value: _durationMinutes.toDouble(),
            min: 5,
            max: 120,
            divisions: 23,
            activeColor: primary,
            inactiveColor: palette.border,
            onChanged: (v) => setState(() => _durationMinutes = v.toInt()),
          ),

          const Spacer(),

          // Log button
          Padding(
            padding: EdgeInsets.fromLTRB(
                20.w, 0, 20.w, MediaQuery.of(context).padding.bottom + 16.h),
            child: AppButton(
              label: l10n.translate('exercise.log_button'),
              loading: _isLogging,
              onPressed: _log,
            ),
          ),
        ],
      ),
    );
  }
}
