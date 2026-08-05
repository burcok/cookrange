import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/dish_model.dart';
import '../../../core/models/meal_entry_model.dart';
import '../../../core/widgets/ds/ds.dart';

/// Faz 3 §3.5 — read-only rendering of one template day's meals, for the
/// offer-preview screen. Deliberately a SEPARATE widget from
/// `TemplateDayEditor` (§3.3) rather than that widget reused with no-op
/// callbacks: the editor's drag handles/add/replace/remove/portion-stepper
/// affordances are all still tappable-looking even when wired to nothing,
/// which would read as broken, not read-only — a member previewing an offer
/// they don't own should see a plan, not a defused editor. Mirrors that
/// widget's visual language (icons, layout, per-meal-type calorie subtotal)
/// minus every interactive control.
class OfferDayView extends StatelessWidget {
  final List<MealEntry> meals;
  final Map<String, DishModel> dishCatalog;

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  const OfferDayView({
    super.key,
    required this.meals,
    required this.dishCatalog,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _mealTypes
          .map((type) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: _MealTypeSection(
                  mealType: type,
                  meals: meals.where((m) => m.mealType == type).toList(),
                  dishCatalog: dishCatalog,
                ),
              ))
          .toList(),
    );
  }
}

class _MealTypeSection extends StatelessWidget {
  final String mealType;
  final List<MealEntry> meals;
  final Map<String, DishModel> dishCatalog;

  const _MealTypeSection({
    required this.mealType,
    required this.meals,
    required this.dishCatalog,
  });

  IconData get _icon => switch (mealType) {
        'breakfast' => Icons.wb_sunny_rounded,
        'lunch' => Icons.light_mode_rounded,
        'dinner' => Icons.nights_stay_rounded,
        _ => Icons.cookie_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    final subtotal = meals.fold<double>(0, (sum, m) {
      final dish = m.dishId != null ? dishCatalog[m.dishId] : null;
      return sum + (dish != null ? dish.calories * m.portion : 0);
    });

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, size: 16.r, color: palette.textSecondary),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(l10n.translate('food_scan.meal.$mealType'),
                    style: t.titleM),
              ),
              if (meals.isNotEmpty)
                Text('${subtotal.round()} kcal',
                    style: t.labelM.copyWith(
                        color: palette.calories, fontWeight: FontWeight.w700)),
            ],
          ),
          if (meals.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
              child: Text(
                l10n.translate('template_builder.day.empty_slot'),
                style: t.labelM.copyWith(color: palette.textTertiary),
              ),
            )
          else
            ...meals.map((m) => _MealEntryRow(
                  entry: m,
                  dish: m.dishId != null ? dishCatalog[m.dishId] : null,
                  palette: palette,
                  t: t,
                  l10n: l10n,
                )),
        ],
      ),
    );
  }
}

class _MealEntryRow extends StatelessWidget {
  final MealEntry entry;
  final DishModel? dish;
  final AppPalette palette;
  final AppText t;
  final AppLocalizations l10n;

  const _MealEntryRow({
    required this.entry,
    required this.dish,
    required this.palette,
    required this.t,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final label = dish?.name ??
        entry.customFood ??
        l10n.translate('template_builder.day.empty_item');
    final caloriesText = dish != null
        ? '${(dish!.calories * entry.portion).round()} kcal'
        : null;
    final portionText = entry.portion != 1.0
        ? '${entry.portion.toStringAsFixed(entry.portion % 1 == 0 ? 0 : 2)}x'
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(Icons.circle, size: 5.r, color: palette.textTertiary),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: t.bodyM,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (caloriesText != null)
                  Text(caloriesText,
                      style: t.labelS.copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
          if (portionText != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.full.r),
              ),
              child: Text(portionText,
                  style: t.labelS.copyWith(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
