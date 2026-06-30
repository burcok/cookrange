import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/food_log_service.dart';
import '../../../core/services/recent_food_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Quick-add sheet — shows recent & frequent foods for one-tap logging.
class QuickAddSheet extends StatefulWidget {
  const QuickAddSheet({super.key});

  static Future<void> show(BuildContext context) => AppSheet.show(
        context: context,
        title: AppLocalizations.of(context).translate('quick_add.title'),
        child: const QuickAddSheet(),
      );

  @override
  State<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<QuickAddSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<RecentFoodEntry> _recent = [];
  List<RecentFoodEntry> _frequent = [];
  bool _isLoading = true;
  String _selectedMealType = 'breakfast';
  final Set<String> _logging = {};

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final svc = RecentFoodService();
    final results = await Future.wait([
      svc.getRecentFoods(),
      svc.getFrequentFoods(),
    ]);
    if (mounted) {
      setState(() {
        _recent = results[0];
        _frequent = results[1];
        _isLoading = false;
      });
    }
  }

  Future<void> _log(RecentFoodEntry entry) async {
    if (_logging.contains(entry.dishId)) return;
    setState(() => _logging.add(entry.dishId));
    unawaited(HapticFeedback.lightImpact());

    try {
      final uid = context.read<UserProvider>().user?.uid;
      if (uid == null) return;

      await FoodLogService().logQuickFood(
        userId: uid,
        mealType: _selectedMealType,
        dishId: entry.dishId,
        dishName: entry.dishName,
        calories: entry.calories,
        protein: entry.protein,
        carbs: entry.carbs,
        fat: entry.fat,
      );

      if (mounted) {
        unawaited(HapticFeedback.mediumImpact());
        AppSnackBar.success(
          context,
          AppLocalizations.of(context).translate('food_scan.log_success'),
        );
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _logging.remove(entry.dishId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          // Meal type selector
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('food_scan.meal_type_label'),
                    style: t.labelM),
                SizedBox(height: 8.h),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _mealTypes.map((type) {
                      final isSelected = _selectedMealType == type;
                      return Padding(
                        padding: EdgeInsets.only(right: 8.w),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedMealType = type),
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 8.h),
                            decoration: BoxDecoration(
                              color:
                                  isSelected ? primary : palette.surfaceVariant,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.button.r),
                              border: Border.all(
                                color: isSelected ? primary : palette.border,
                              ),
                            ),
                            child: Text(
                              l10n.translate('food_scan.meal.$type'),
                              style: t.labelM.copyWith(
                                color: isSelected
                                    ? Colors.white
                                    : palette.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Tabs
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Container(
              height: 40.h,
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                  boxShadow: [
                    BoxShadow(
                        color: primary.withValues(alpha: 0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: palette.textSecondary,
                labelStyle: t.labelM.copyWith(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: l10n.translate('quick_add.recent_title')),
                  Tab(text: l10n.translate('quick_add.frequent_title')),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),

          // List
          Expanded(
            child: _isLoading
                ? const AppSkeletonList(itemCount: 5)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildList(_recent, l10n),
                      _buildList(_frequent, l10n),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<RecentFoodEntry> items, AppLocalizations l10n) {
    if (items.isEmpty) {
      return AppEmptyState(
        icon: Icons.history_rounded,
        title: l10n.translate('quick_add.empty_title'),
        message: l10n.translate('quick_add.empty_subtitle'),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 80.h),
      itemCount: items.length,
      separatorBuilder: (_, __) => SizedBox(height: 8.h),
      itemBuilder: (context, i) => _QuickFoodTile(
        entry: items[i],
        isLogging: _logging.contains(items[i].dishId),
        onLog: () => _log(items[i]),
      ),
    );
  }
}

class _QuickFoodTile extends StatelessWidget {
  final RecentFoodEntry entry;
  final bool isLogging;
  final VoidCallback onLog;

  const _QuickFoodTile({
    required this.entry,
    required this.isLogging,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: palette.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant_menu_rounded,
                color: primary, size: AppSize.iconSm.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.dishName,
                    style: t.titleM,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.local_fire_department,
                        size: 12.sp, color: palette.calories),
                    SizedBox(width: 2.w),
                    Text('${entry.calories.toInt()} kcal',
                        style: t.labelS.copyWith(color: palette.calories)),
                    SizedBox(width: 8.w),
                    Text(
                      'P:${entry.protein.toInt()} C:${entry.carbs.toInt()} F:${entry.fat.toInt()}',
                      style: t.labelS,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: isLogging ? null : onLog,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: isLogging
                    ? palette.surfaceVariant
                    : primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: isLogging
                  ? const Center(
                      child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : Icon(Icons.add, color: primary, size: 20.sp),
            ),
          ),
        ],
      ),
    );
  }
}
