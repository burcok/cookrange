import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/dish_model.dart';
import '../../../core/models/meal_entry_model.dart';
import '../../../core/utils/plan_nutrition_calculator.dart';
import '../../../core/widgets/ds/ds.dart';
import 'dish_picker_sheet.dart';

/// Faz 3 §3.3 path 2 ("sıfırdan kur") — one day's meal-slot grid.
///
/// Fixed breakfast/lunch/dinner/snack sections (each can hold 0+ entries —
/// snack commonly has more than one), reorderable WITHIN their own section
/// via `ReorderableListView` (Flutter's built-in widget — satisfies "drag-
/// and-drop or equivalent reorder" with no new dependency). Every add/
/// remove/replace/reorder/portion change calls [onChanged] with a brand-new
/// full `meals` list — this widget holds no state of its own, so the parent
/// screen stays the single source of truth and can recompute live nutrition
/// after every single edit.
class TemplateDayEditor extends StatelessWidget {
  final List<MealEntry> meals;
  final Map<String, DishModel> dishCatalog;

  /// The pool [DishPickerSheet] searches for manual add/replace. Deliberately
  /// the FULL catalog, not allergen-pre-filtered: for paths 2/3 (manual
  /// build / fork), conflicts are surfaced via `TemplateAllergenPanel`'s red
  /// warning AFTER a dish is added, not blocked at search time — the author
  /// stays free to consciously override with reason (e.g. "this member
  /// tolerates a small amount"). Path 1 (AI-generate) is the one place a
  /// pre-filter is MANDATORY (`MealPlanTemplateService.generateDraftFromAI`);
  /// that pre-filtering happens before this widget is ever shown a draft.
  final List<DishModel> pickerCatalog;
  final ValueChanged<List<MealEntry>> onChanged;

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  const TemplateDayEditor({
    super.key,
    required this.meals,
    required this.dishCatalog,
    required this.pickerCatalog,
    required this.onChanged,
  });

  Future<void> _addMeal(BuildContext context, String mealType) async {
    final result = await DishPickerSheet.show(context, catalog: pickerCatalog);
    if (result == null) return;
    final entry = result.dish != null
        ? MealEntry(dishId: result.dish!.id, mealType: mealType)
        : MealEntry(customFood: result.customFoodName, mealType: mealType);
    onChanged([...meals, entry]);
  }

  Future<void> _replaceMeal(BuildContext context, int index) async {
    final result = await DishPickerSheet.show(context, catalog: pickerCatalog);
    if (result == null) return;
    final old = meals[index];
    // NOT copyWith: copyWith's `field ?? this.field` pattern can never null
    // OUT a field, so switching dish->custom (or back) needs a fresh entry
    // to guarantee exactly one of dishId/customFood survives, matching
    // MealEntry's own "at most one is meaningful" contract.
    final updated = result.dish != null
        ? MealEntry(
            dishId: result.dish!.id,
            mealType: old.mealType,
            portion: old.portion,
            note: old.note)
        : MealEntry(
            customFood: result.customFoodName,
            mealType: old.mealType,
            portion: old.portion,
            note: old.note);
    final next = [...meals];
    next[index] = updated;
    onChanged(next);
  }

  void _removeMeal(int index) {
    final next = [...meals]..removeAt(index);
    onChanged(next);
  }

  void _setPortion(int index, double portion) {
    if (portion < 0.25) return;
    final next = [...meals];
    next[index] = next[index].copyWith(portion: portion);
    onChanged(next);
  }

  /// Reorders entries WITHIN one meal type, then splices the section back
  /// into the full flat list — the only place that needs every OTHER
  /// section's entries to stay untouched in their original relative order.
  ///
  /// [newIndex] arrives already adjusted for the removed item — this is
  /// wired to `ReorderableListView.onReorderItem` (verified against the
  /// Flutter SDK source, `_handleReorderItem` in `reorderable_list.dart`),
  /// NOT the deprecated `onReorder`, which hands back a raw index that still
  /// needs the `-1` correction done here manually. Do not add that
  /// correction back without also switching the call site back to
  /// `onReorder`.
  void _reorderSection(String mealType, int oldIndex, int newIndex) {
    final indices = <int>[];
    for (var i = 0; i < meals.length; i++) {
      if (meals[i].mealType == mealType) indices.add(i);
    }
    final section = indices.map((i) => meals[i]).toList();
    final reordered = [...section];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);
    final next = [...meals];
    for (var k = 0; k < indices.length; k++) {
      next[indices[k]] = reordered[k];
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _mealTypes
          .map((type) => Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                child: _MealTypeSection(
                  mealType: type,
                  meals: meals,
                  dishCatalog: dishCatalog,
                  onAdd: () => _addMeal(context, type),
                  onReplace: (i) => _replaceMeal(context, i),
                  onRemove: _removeMeal,
                  onPortionChanged: _setPortion,
                  onReorder: (oldIndex, newIndex) =>
                      _reorderSection(type, oldIndex, newIndex),
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
  final VoidCallback onAdd;
  final ValueChanged<int> onReplace;
  final ValueChanged<int> onRemove;
  final void Function(int index, double portion) onPortionChanged;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _MealTypeSection({
    required this.mealType,
    required this.meals,
    required this.dishCatalog,
    required this.onAdd,
    required this.onReplace,
    required this.onRemove,
    required this.onPortionChanged,
    required this.onReorder,
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

    final indices = <int>[];
    for (var i = 0; i < meals.length; i++) {
      if (meals[i].mealType == mealType) indices.add(i);
    }
    final section = indices.map((i) => meals[i]).toList();
    final subtotal =
        PlanNutritionCalculator.calculateEntries(section, dishCatalog);

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
              if (section.isNotEmpty)
                Text('${subtotal.calories.round()} kcal',
                    style: t.labelM.copyWith(
                        color: palette.calories, fontWeight: FontWeight.w700)),
              SizedBox(width: 6.w),
              IconButton(
                onPressed: onAdd,
                icon: Icon(Icons.add_circle_rounded,
                    color: Theme.of(context).primaryColor, size: 22.r),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.translate('template_builder.day.add_item'),
              ),
            ],
          ),
          if (section.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
              child: Text(
                l10n.translate('template_builder.day.empty_slot'),
                style: t.labelM.copyWith(color: palette.textTertiary),
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorderItem: onReorder,
              children: [
                for (var i = 0; i < section.length; i++)
                  _MealEntryRow(
                    key: ValueKey('${mealType}_${indices[i]}'),
                    entry: section[i],
                    dish: section[i].dishId != null
                        ? dishCatalog[section[i].dishId]
                        : null,
                    palette: palette,
                    t: t,
                    l10n: l10n,
                    onTap: () => onReplace(indices[i]),
                    onRemove: () => onRemove(indices[i]),
                    onPortionChanged: (p) => onPortionChanged(indices[i], p),
                  ),
              ],
            ),
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
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final ValueChanged<double> onPortionChanged;

  const _MealEntryRow({
    super.key,
    required this.entry,
    required this.dish,
    required this.palette,
    required this.t,
    required this.l10n,
    required this.onTap,
    required this.onRemove,
    required this.onPortionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = dish?.name ??
        entry.customFood ??
        l10n.translate('template_builder.day.empty_item');
    final caloriesText = dish != null
        ? '${(dish!.calories * entry.portion).round()} kcal'
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          // Purely a visual affordance — `ReorderableListView`'s default
          // `buildDefaultDragHandles: true` already makes the whole row
          // long-press-draggable on mobile, so no separate drag-start
          // listener is wired here (one WAS wired here with a hardcoded,
          // wrong index; removed — do not resurrect it without giving each
          // row its real position in the section).
          Icon(Icons.drag_indicator_rounded,
              size: 18.r, color: palette.textTertiary),
          SizedBox(width: 8.w),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
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
                              style: t.labelS
                                  .copyWith(color: palette.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 16.r, color: palette.textTertiary),
                ],
              ),
            ),
          ),
          if (dish != null) ...[
            SizedBox(width: 4.w),
            _PortionStepper(
              portion: entry.portion,
              onChanged: onPortionChanged,
              palette: palette,
              t: t,
            ),
          ],
          IconButton(
            onPressed: onRemove,
            icon: Icon(Icons.close_rounded, size: 16.r, color: palette.error),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _PortionStepper extends StatelessWidget {
  final double portion;
  final ValueChanged<double> onChanged;
  final AppPalette palette;
  final AppText t;

  const _PortionStepper({
    required this.portion,
    required this.onChanged,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stepBtn(Icons.remove_rounded, () => onChanged(portion - 0.25)),
          SizedBox(
            width: 30.w,
            child: Text(
              '${portion.toStringAsFixed(portion % 1 == 0 ? 0 : 2)}x',
              textAlign: TextAlign.center,
              style: t.labelS.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          _stepBtn(Icons.add_rounded, () => onChanged(portion + 0.25)),
        ],
      ),
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(4.r),
          child: Icon(icon, size: 13.r, color: palette.textSecondary),
        ),
      );
}
