import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/dish_model.dart';
import '../../../core/widgets/ds/ds.dart';

/// Either a catalog [dish] or a free-text [customFoodName] — mirrors
/// `MealEntry`'s own "at most one of dishId/customFood" contract.
class DishPickResult {
  final DishModel? dish;
  final String? customFoodName;
  const DishPickResult.dish(DishModel d)
      : dish = d,
        customFoodName = null;
  const DishPickResult.custom(String name)
      : dish = null,
        customFoodName = name;
}

/// Faz 3 §3.3 path 2 ("sıfırdan kur") — dish search for a single meal slot.
///
/// Client-side substring filter over the already-fetched full catalog
/// (`DishService.getAllDishes()`, ~180 dishes at current app scale, per
/// `docs/DATABASE.md`) — matches every other in-app dish list (no server
/// search endpoint exists, none is added here). The catalog passed in is
/// whatever the caller already pre-filtered (e.g. an allergen-safe pool);
/// this sheet does not re-fetch or re-filter it on its own.
class DishPickerSheet {
  static Future<DishPickResult?> show(
    BuildContext context, {
    required List<DishModel> catalog,
  }) {
    return AppSheet.show<DishPickResult>(
      context: context,
      title: AppLocalizations.of(context)
          .translate('template_builder.dish_picker.title'),
      child: _DishPickerBody(catalog: catalog),
    );
  }
}

class _DishPickerBody extends StatefulWidget {
  final List<DishModel> catalog;
  const _DishPickerBody({required this.catalog});

  @override
  State<_DishPickerBody> createState() => _DishPickerBodyState();
}

class _DishPickerBodyState extends State<_DishPickerBody> {
  final _searchCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _customCtrl.dispose();
    super.dispose();
  }

  List<DishModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.catalog;
    return widget.catalog
        .where((d) =>
            d.name.toLowerCase().contains(q) ||
            d.nameEn.toLowerCase().contains(q) ||
            d.category.toLowerCase().contains(q) ||
            d.tags.any((tag) => tag.toLowerCase().contains(q)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final results = _filtered;
    final pLabel = l10n.translate('nutrition.macro_protein_short');
    final cLabel = l10n.translate('nutrition.macro_carbs_short');
    final fLabel = l10n.translate('nutrition.macro_fat_short');

    return SizedBox(
      height: 0.72.sh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _searchCtrl,
            hintText:
                l10n.translate('template_builder.dish_picker.search_hint'),
            prefixIcon:
                Icon(Icons.search_rounded, color: palette.textSecondary),
            onChanged: (v) => setState(() => _query = v),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _customCtrl,
                  hintText: l10n
                      .translate('template_builder.dish_picker.custom_hint'),
                ),
              ),
              SizedBox(width: 8.w),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _customCtrl,
                builder: (context, value, _) => AppButton(
                  label:
                      l10n.translate('template_builder.dish_picker.add_custom'),
                  variant: AppButtonVariant.tonal,
                  size: AppButtonSize.medium,
                  expand: false,
                  onPressed: value.text.trim().isEmpty
                      ? null
                      : () => Navigator.of(context)
                          .pop(DishPickResult.custom(value.text.trim())),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Expanded(
            child: results.isEmpty
                ? AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: l10n
                        .translate('template_builder.dish_picker.empty_title'),
                    compact: true,
                  )
                : ListView.separated(
                    itemCount: results.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: palette.border),
                    itemBuilder: (context, i) {
                      final d = results[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(d.name, style: t.bodyM),
                        subtitle: Text(
                          '${d.calories.round()} kcal · '
                          '$pLabel${d.protein.round()} '
                          '$cLabel${d.carbs.round()} '
                          '$fLabel${d.fat.round()}',
                          style:
                              t.labelS.copyWith(color: palette.textSecondary),
                        ),
                        onTap: () =>
                            Navigator.of(context).pop(DishPickResult.dish(d)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
