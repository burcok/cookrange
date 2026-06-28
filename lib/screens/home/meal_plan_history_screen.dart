import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/weekly_meal_plan_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/weekly_meal_plan_service.dart';
import '../../core/widgets/ds/ds.dart';

class MealPlanHistoryScreen extends StatefulWidget {
  const MealPlanHistoryScreen({super.key});

  @override
  State<MealPlanHistoryScreen> createState() => _MealPlanHistoryScreenState();
}

class _MealPlanHistoryScreenState extends State<MealPlanHistoryScreen> {
  final WeeklyMealPlanService _service = WeeklyMealPlanService();

  List<WeeklyMealPlanModel> _plans = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final plans = await _service.getMealPlanHistory(uid);
      if (mounted) {
        setState(() {
          _plans = plans;
          _hasMore = plans.length >= 10;
        });
      }
    } catch (e) {
      debugPrint('MealPlanHistoryScreen load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restorePlan(WeeklyMealPlanModel plan) async {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.of(context).surface,
        title: Text(l10n.translate('meal_history.load_plan'),
            style: AppText.of(context).titleL),
        content: Text(
          l10n.translate('meal_history.load_confirm',
              variables: {'week': DateFormat('MMM d').format(plan.weekStartDate)}),
          style: AppText.of(context).bodyM,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.translate('common.cancel'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.translate('common.confirm'),
                  style: TextStyle(
                      color: context.watch<ThemeProvider>().primaryColor))),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      await _service.restorePlan(uid, plan);
      if (mounted) {
        AppSnackBar.success(
            context, AppLocalizations.of(context).translate('meal_history.loaded'));
        Navigator.pop(context, true); // signal caller to reload
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.translate('meal_history.title'), style: t.headlineS),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: AppSkeletonList(itemCount: 4))
          : _plans.isEmpty
              ? AppEmptyState(
                  icon: Icons.history_rounded,
                  title: l10n.translate('meal_history.empty_title'),
                  message: l10n.translate('meal_history.empty_subtitle'),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: primary,
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 100.h),
                    itemCount: _plans.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md.h),
                    itemBuilder: (context, index) {
                      if (index == _plans.length) {
                        return _isLoadingMore
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                      color: primary, strokeWidth: 2),
                                ),
                              )
                            : AppButton(
                                label: l10n.translate('common.load_more'),
                                variant: AppButtonVariant.ghost,
                                onPressed: _loadMore,
                              );
                      }
                      return _PlanHistoryCard(
                        plan: _plans[index],
                        primary: primary,
                        onRestore: () => _restorePlan(_plans[index]),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final uid = context.read<UserProvider>().user?.uid;
      if (uid == null) return;
      // Simple offset-based: fetch from the beginning with larger limit
      // (Firestore needs lastDoc; for now fetch next page)
      final more = await _service.getMealPlanHistory(uid, limit: 10);
      if (mounted) {
        setState(() {
          final existing = _plans.map((p) => p.id).toSet();
          _plans.addAll(more.where((p) => !existing.contains(p.id)));
          _hasMore = more.length >= 10;
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }
}

class _PlanHistoryCard extends StatelessWidget {
  final WeeklyMealPlanModel plan;
  final Color primary;
  final VoidCallback onRestore;

  const _PlanHistoryCard({
    required this.plan,
    required this.primary,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final weekLabel = DateFormat('MMMM d, yyyy').format(plan.weekStartDate);
    final mealCount = plan.days.fold<int>(
        0, (sum, day) => sum + day.meals.length);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
                child: Icon(Icons.calendar_today_rounded,
                    color: primary, size: AppSize.iconSm.sp),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.translate('meal_history.week_label')} $weekLabel',
                      style: t.titleL,
                    ),
                    Text(
                      '${plan.days.length} ${l10n.translate('meal_history.days')} · '
                      '$mealCount ${l10n.translate('meal_history.meals')}',
                      style: t.labelS,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),

          // Avg calorie & macro row
          Row(
            children: [
              _StatChip(
                  label: '${plan.avgDailyCalories.toInt()} kcal',
                  color: palette.calories),
              SizedBox(width: AppSpacing.xs.w),
              _StatChip(
                  label: 'P: ${plan.avgMacros['protein']?.toInt() ?? 0}g',
                  color: palette.protein),
              SizedBox(width: AppSpacing.xs.w),
              _StatChip(
                  label: 'C: ${plan.avgMacros['carbs']?.toInt() ?? 0}g',
                  color: palette.carbs),
              SizedBox(width: AppSpacing.xs.w),
              _StatChip(
                  label: 'F: ${plan.avgMacros['fat']?.toInt() ?? 0}g',
                  color: palette.fat),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),

          // Restore button
          AppButton(
            label: l10n.translate('meal_history.load_plan'),
            variant: AppButtonVariant.tonal,
            size: AppButtonSize.small,
            onPressed: onRestore,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs.r),
      ),
      child: Text(
        label,
        style: AppText.of(context)
            .labelS
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
