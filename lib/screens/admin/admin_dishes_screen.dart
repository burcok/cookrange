import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/dish_model.dart';
import '../../core/services/dish_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Admin screen to browse, search, and edit the Firestore dish database.
class AdminDishesScreen extends StatefulWidget {
  const AdminDishesScreen({super.key});

  @override
  State<AdminDishesScreen> createState() => _AdminDishesScreenState();
}

class _AdminDishesScreenState extends State<AdminDishesScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _categoryFilter;

  static const _categories = [
    'chicken',
    'red_meat',
    'fish',
    'breakfast',
    'vegetarian',
    'vegan',
    'diet',
    'sport',
    'turkish_classic',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DishModel> _filtered(List<DishModel> all) {
    return all.where((d) {
      final q = _query;
      final matchQ = q.isEmpty ||
          d.nameEn.toLowerCase().contains(q) ||
          d.name.toLowerCase().contains(q);
      final matchC = _categoryFilter == null || d.category == _categoryFilter;
      return matchQ && matchC;
    }).toList();
  }

  void _openEdit(BuildContext context, DishModel dish) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    AppSheet.show(
      context: context,
      title: dish.nameEn.isNotEmpty ? dish.nameEn : dish.name,
      child: _DishEditSheet(dish: dish, l10n: l10n, palette: palette, t: t),
    );
  }

  void _confirmReseed(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text(
          l10n.translate('admin.dishes_reseed_title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          l10n.translate('admin.dishes_reseed_body'),
          style: t.bodyM.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.translate('common.cancel'),
                style: t.labelM.copyWith(color: palette.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _doReseed(context, l10n);
            },
            child: Text(
              l10n.translate('admin.dishes_reseed_btn'),
              style: t.labelM.copyWith(
                  color: palette.warning, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _doReseed(BuildContext context, AppLocalizations l10n) async {
    try {
      await DishService().seedDatabase();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.translate('admin.dishes_reseed_done'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20.r),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('admin.dishes_title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: palette.textSecondary, size: 22.r),
            tooltip: l10n.translate('admin.dishes_reseed_btn'),
            onPressed: () => _confirmReseed(context),
          ),
        ],
      ),
      body: StreamBuilder<List<DishModel>>(
        stream: DishService().getAllDishesStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
                padding: EdgeInsets.all(16),
                child: AppSkeletonList(itemCount: 8));
          }
          if (snap.hasError) {
            return AppErrorState(
                title: l10n.translate('common.error'),
                message: snap.error.toString());
          }

          final all = snap.data ?? [];
          final visible = _filtered(all);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search + count ──────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _SearchField(
                        ctrl: _searchCtrl,
                        palette: palette,
                        t: t,
                        hint: l10n.translate('admin.dishes_search_hint'),
                        onChanged: (v) =>
                            setState(() => _query = v.toLowerCase().trim()),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      '${visible.length}/${all.length}',
                      style: t.labelM.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              // ── Category filter chips ───────────────────────────────
              SizedBox(
                height: 32.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: _categories.length + 1,
                  separatorBuilder: (_, __) => SizedBox(width: 6.w),
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return _FilterChip(
                        label: l10n.translate('admin.dishes_all'),
                        selected: _categoryFilter == null,
                        onTap: () => setState(() => _categoryFilter = null),
                        palette: palette,
                        t: t,
                      );
                    }
                    final cat = _categories[i - 1];
                    return _FilterChip(
                      label: l10n.translate('admin.dish_cat_$cat'),
                      selected: _categoryFilter == cat,
                      onTap: () => setState(() => _categoryFilter =
                          _categoryFilter == cat ? null : cat),
                      palette: palette,
                      t: t,
                    );
                  },
                ),
              ),
              SizedBox(height: 6.h),
              // ── Dish list ───────────────────────────────────────────
              Expanded(
                child: visible.isEmpty
                    ? AppEmptyState(
                        icon: Icons.restaurant_menu_rounded,
                        title: l10n.translate('admin.dishes_empty'),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(
                            horizontal: 16.w, vertical: 8.h),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => SizedBox(height: 8.h),
                        itemBuilder: (_, i) => _DishCard(
                          dish: visible[i],
                          palette: palette,
                          t: t,
                          catLabel: l10n.translate(
                              'admin.dish_cat_${visible[i].category}'),
                          onTap: () => _openEdit(context, visible[i]),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Dish Card ─────────────────────────────────────────────────────────────────

class _DishCard extends StatelessWidget {
  final DishModel dish;
  final AppPalette palette;
  final AppText t;
  final String catLabel;
  final VoidCallback onTap;

  const _DishCard({
    required this.dish,
    required this.palette,
    required this.t,
    required this.catLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.nameEn.isNotEmpty ? dish.nameEn : dish.name,
                    style: t.bodyM.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dish.nameEn.isNotEmpty && dish.name.isNotEmpty) ...[
                    SizedBox(height: 1.h),
                    Text(
                      dish.name,
                      style: t.labelS.copyWith(color: palette.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 5.h),
                  // Macro strip
                  Row(
                    children: [
                      _MacroPill(
                          '${dish.calories.toInt()} kcal', palette.calories),
                      SizedBox(width: 4.w),
                      _MacroPill('P ${dish.protein.toStringAsFixed(0)}g',
                          palette.protein),
                      SizedBox(width: 4.w),
                      _MacroPill(
                          'C ${dish.carbs.toStringAsFixed(0)}g', palette.carbs),
                      SizedBox(width: 4.w),
                      _MacroPill(
                          'F ${dish.fat.toStringAsFixed(0)}g', palette.fat),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _CatBadge(label: catLabel, palette: palette, t: t),
                SizedBox(height: 8.h),
                Icon(Icons.edit_rounded,
                    size: 16.r, color: palette.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit Sheet ────────────────────────────────────────────────────────────────

class _DishEditSheet extends StatefulWidget {
  final DishModel dish;
  final AppLocalizations l10n;
  final AppPalette palette;
  final AppText t;

  const _DishEditSheet({
    required this.dish,
    required this.l10n,
    required this.palette,
    required this.t,
  });

  @override
  State<_DishEditSheet> createState() => _DishEditSheetState();
}

class _DishEditSheetState extends State<_DishEditSheet> {
  late final _nameTrCtrl = TextEditingController(text: widget.dish.name);
  late final _nameEnCtrl = TextEditingController(text: widget.dish.nameEn);
  late final _calCtrl =
      TextEditingController(text: widget.dish.calories.toStringAsFixed(0));
  late final _protCtrl =
      TextEditingController(text: widget.dish.protein.toStringAsFixed(1));
  late final _carbCtrl =
      TextEditingController(text: widget.dish.carbs.toStringAsFixed(1));
  late final _fatCtrl =
      TextEditingController(text: widget.dish.fat.toStringAsFixed(1));
  late final _fiberCtrl =
      TextEditingController(text: widget.dish.fiber.toStringAsFixed(1));
  late String _category = widget.dish.category;
  late String _mealType = widget.dish.mealType;
  late String _difficulty = widget.dish.difficulty;
  bool _loading = false;
  bool _hasChanges = false;

  @override
  void dispose() {
    _nameTrCtrl.dispose();
    _nameEnCtrl.dispose();
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _fiberCtrl.dispose();
    super.dispose();
  }

  void _markChanged() => setState(() => _hasChanges = true);

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await DishService().updateDish(widget.dish.id, {
        'name': _nameTrCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim(),
        'calories': double.tryParse(_calCtrl.text) ?? widget.dish.calories,
        'protein': double.tryParse(_protCtrl.text) ?? widget.dish.protein,
        'carbs': double.tryParse(_carbCtrl.text) ?? widget.dish.carbs,
        'fat': double.tryParse(_fatCtrl.text) ?? widget.dish.fat,
        'fiber': double.tryParse(_fiberCtrl.text) ?? widget.dish.fiber,
        'category': _category,
        'meal_type': _mealType,
        'difficulty': _difficulty,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.l10n.translate('admin.dishes_saved'))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final t = widget.t;
    final l10n = widget.l10n;

    const cats = [
      'chicken',
      'red_meat',
      'fish',
      'breakfast',
      'vegetarian',
      'vegan',
      'diet',
      'sport',
      'turkish_classic',
    ];
    const mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
    const difficulties = ['easy', 'medium', 'hard'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetField(
            ctrl: _nameTrCtrl,
            label: l10n.translate('admin.dish_name_tr'),
            palette: palette,
            t: t,
            onChanged: (_) => _markChanged(),
          ),
          SizedBox(height: 8.h),
          _SheetField(
            ctrl: _nameEnCtrl,
            label: l10n.translate('admin.dish_name_en'),
            palette: palette,
            t: t,
            onChanged: (_) => _markChanged(),
          ),
          SizedBox(height: 12.h),
          _SheetDropdown(
            label: l10n.translate('admin.dish_category'),
            value: _category,
            items: cats,
            labelOf: (v) => l10n.translate('admin.dish_cat_$v'),
            palette: palette,
            t: t,
            onChanged: (v) {
              if (v != null)
                setState(() {
                  _category = v;
                  _hasChanges = true;
                });
            },
          ),
          SizedBox(height: 8.h),
          Row(children: [
            Expanded(
              child: _SheetDropdown(
                label: l10n.translate('admin.dish_meal_type'),
                value: _mealType,
                items: mealTypes,
                labelOf: (v) => l10n.translate('admin.dish_meal_$v'),
                palette: palette,
                t: t,
                onChanged: (v) {
                  if (v != null)
                    setState(() {
                      _mealType = v;
                      _hasChanges = true;
                    });
                },
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _SheetDropdown(
                label: l10n.translate('admin.dish_difficulty'),
                value: _difficulty,
                items: difficulties,
                labelOf: (v) => l10n.translate('admin.dish_diff_$v'),
                palette: palette,
                t: t,
                onChanged: (v) {
                  if (v != null)
                    setState(() {
                      _difficulty = v;
                      _hasChanges = true;
                    });
                },
              ),
            ),
          ]),
          SizedBox(height: 12.h),
          Text(l10n.translate('admin.dish_macros'),
              style: t.labelM.copyWith(color: palette.textSecondary)),
          SizedBox(height: 6.h),
          Row(children: [
            Expanded(
                child: _SheetField(
                    ctrl: _calCtrl,
                    label: 'kcal',
                    palette: palette,
                    t: t,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _markChanged())),
            SizedBox(width: 6.w),
            Expanded(
                child: _SheetField(
                    ctrl: _protCtrl,
                    label: l10n.translate('admin.dishes.label_protein'),
                    palette: palette,
                    t: t,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _markChanged())),
          ]),
          SizedBox(height: 6.h),
          Row(children: [
            Expanded(
                child: _SheetField(
                    ctrl: _carbCtrl,
                    label: l10n.translate('admin.dishes.label_carbs'),
                    palette: palette,
                    t: t,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _markChanged())),
            SizedBox(width: 6.w),
            Expanded(
                child: _SheetField(
                    ctrl: _fatCtrl,
                    label: l10n.translate('admin.dishes.label_fat'),
                    palette: palette,
                    t: t,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _markChanged())),
            SizedBox(width: 6.w),
            Expanded(
                child: _SheetField(
                    ctrl: _fiberCtrl,
                    label: l10n.translate('admin.dishes.label_fiber'),
                    palette: palette,
                    t: t,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _markChanged())),
          ]),
          SizedBox(height: 16.h),
          AppButton(
            label: l10n.translate('admin.dishes_save'),
            loading: _loading,
            onPressed: _hasChanges ? _save : null,
          ),
          SizedBox(height: 8.h),
        ],
      ),
    );
  }
}

// ── Reusable helpers ──────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController ctrl;
  final AppPalette palette;
  final AppText t;
  final String hint;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.ctrl,
    required this.palette,
    required this.t,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: t.bodyM.copyWith(color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: t.bodyM.copyWith(color: palette.textSecondary),
        prefixIcon: Icon(Icons.search_rounded,
            size: 18.r, color: palette.textSecondary),
        contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input.r),
          borderSide: BorderSide(color: palette.textPrimary),
        ),
        filled: true,
        fillColor: palette.surfaceVariant,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final AppPalette palette;
  final AppText t;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).primaryColor
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          border: Border.all(
            color: selected ? Theme.of(context).primaryColor : palette.border,
          ),
        ),
        child: Text(
          label,
          style: t.labelS.copyWith(
            color: selected ? Colors.white : palette.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MacroPill(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _CatBadge extends StatelessWidget {
  final String label;
  final AppPalette palette;
  final AppText t;

  const _CatBadge({
    required this.label,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        label,
        style: t.labelS.copyWith(color: palette.textSecondary),
        maxLines: 1,
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final AppPalette palette;
  final AppText t;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.palette,
    required this.t,
    this.keyboardType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelS.copyWith(color: palette.textSecondary)),
        SizedBox(height: 4.h),
        TextField(
          controller: ctrl,
          onChanged: onChanged,
          keyboardType: keyboardType,
          style: t.bodyM.copyWith(color: palette.textPrimary),
          decoration: InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(color: palette.border),
            ),
            filled: true,
            fillColor: palette.surfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SheetDropdown extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final String Function(String) labelOf;
  final AppPalette palette;
  final AppText t;
  final ValueChanged<String?> onChanged;

  const _SheetDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.palette,
    required this.t,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.labelS.copyWith(color: palette.textSecondary)),
        SizedBox(height: 4.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: palette.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.input.r),
            border: Border.all(color: palette.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: palette.surface,
              style: t.bodyM.copyWith(color: palette.textPrimary),
              onChanged: onChanged,
              items: items
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(labelOf(v),
                            style:
                                t.bodyM.copyWith(color: palette.textPrimary)),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
