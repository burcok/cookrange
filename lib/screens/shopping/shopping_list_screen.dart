import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/repositories/shopping_repository.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/dish_service.dart';
import '../../core/services/sharing_service.dart';
import '../../core/services/shopping_list_sync_service.dart';
import '../../core/services/weekly_meal_plan_service.dart';
import '../../core/widgets/ds/ds.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with SingleTickerProviderStateMixin {
  final ShoppingRepository _shoppingRepo = ShoppingRepository();
  final ShoppingListSyncService _syncService = ShoppingListSyncService();
  List<Ingredient> _shoppingList = [];
  final Set<String> _checkedItems = {};
  bool _isGenerating = false;
  late AnimationController _fabController;

  // Date filter: 'all' (this week) | 'today'.
  String _dateFilter = 'all';

  String get _todayStr {
    final d = DateTime.now();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  bool _matchesDateFilter(Ingredient i) {
    if (_dateFilter == 'all') return true;
    return i.sourceDates.contains(_todayStr); // 'today'
  }

  /// True when any generated item carries day provenance (enables the filter).
  bool get _hasDatedItems => _shoppingList.any((i) => i.sourceDates.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadShoppingList();
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _loadShoppingList() {
    setState(() {
      _shoppingList = _shoppingRepo.getList();
    });
    final uid = context.read<UserProvider>().user?.uid;
    if (uid != null) {
      _syncService.load(uid).then((remote) {
        if (remote != null && mounted) {
          setState(() {
            _shoppingList = remote.items;
            _checkedItems
              ..clear()
              ..addAll(remote.checked);
          });
        }
      });
    }
  }

  void _syncToCloud() {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null) return;
    unawaited(_syncService.save(uid, _shoppingList, _checkedItems));
  }

  void _toggleItem(String name) {
    setState(() {
      if (_checkedItems.contains(name)) {
        _checkedItems.remove(name);
      } else {
        _checkedItems.add(name);
      }
    });
    unawaited(HapticFeedback.selectionClick());
    _syncToCloud();
  }

  Future<void> _deleteItem(String name) async {
    await _shoppingRepo.remove(name);
    if (mounted) {
      setState(() {
        _shoppingList.removeWhere((i) => i.name == name);
        _checkedItems.remove(name);
      });
      _syncToCloud();
    }
  }

  Future<void> _clearList() async {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('shopping.clear_list')),
        content: Text(l10n.translate('shopping.clear_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.translate('common.clear'),
              style: TextStyle(color: palette.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _shoppingRepo.clear();
      if (mounted) {
        setState(() {
          _shoppingList.clear();
          _checkedItems.clear();
        });
        _syncToCloud();
      }
    }
  }

  Future<void> _generateFromPlan() async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<UserProvider>().user;
    if (user == null) return;
    final locale = context.read<LanguageProvider>().currentLocale.languageCode;

    setState(() => _isGenerating = true);
    try {
      final plan =
          await WeeklyMealPlanService().getWeeklyMealPlan(user, locale: locale);
      if (plan == null || plan.days.isEmpty) {
        if (mounted)
          AppSnackBar.warning(context, l10n.translate('shopping.no_plan'));
        return;
      }

      // Fetch all dishes and build an ID lookup
      final dishes = await DishService().getAllDishes();
      final idMap = {for (final d in dishes) d.id: d};

      String fmtDate(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      // Aggregate ingredients across the week, recording which dishes/days
      // require each one (per-occurrence, so a dish used on 3 days counts 3×).
      final merged = <String, Ingredient>{};
      final mealsByKey = <String, Set<String>>{};
      final datesByKey = <String, Set<String>>{};

      for (final day in plan.days) {
        final dateStr = fmtDate(day.date);
        for (final dishId in day.meals.values) {
          final dish = idMap[dishId];
          if (dish == null) continue;
          final dishLabel = (locale == 'en' && dish.nameEn.isNotEmpty)
              ? dish.nameEn
              : dish.name;
          for (final ingredient in dish.ingredients) {
            final key = ingredient.name.toLowerCase();
            final existing = merged[key];
            merged[key] = existing == null
                ? ingredient
                : existing.copyWith(
                    amount: existing.amount + ingredient.amount,
                    calories: existing.calories + ingredient.calories,
                  );
            (mealsByKey[key] ??= <String>{}).add(dishLabel);
            (datesByKey[key] ??= <String>{}).add(dateStr);
          }
        }
      }

      // Attach provenance to each merged ingredient.
      for (final key in merged.keys.toList()) {
        merged[key] = merged[key]!.copyWith(
          sourceMeals: (mealsByKey[key] ?? const <String>{}).toList(),
          sourceDates: (datesByKey[key] ?? const <String>{}).toList(),
        );
      }

      if (merged.isEmpty) {
        if (mounted)
          AppSnackBar.warning(
              context, l10n.translate('shopping.no_ingredients'));
        return;
      }

      await _shoppingRepo.clear();
      for (final ingredient in merged.values) {
        await _shoppingRepo.add(ingredient);
      }

      unawaited(AnalyticsService().logEvent(
        name: 'shopping_list_generated',
        parameters: {'item_count': merged.length},
      ));
      if (mounted) {
        _loadShoppingList();
        _syncToCloud();
        unawaited(HapticFeedback.mediumImpact());
        AppSnackBar.success(
            context,
            l10n.translate('shopping.generated',
                variables: {'count': '${merged.length}'}));
      }
    } catch (e) {
      if (mounted)
        AppSnackBar.error(context, '${l10n.translate('common.error')}: $e');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  void _copyToClipboard() {
    if (_shoppingList.isEmpty) return;
    final l10n = AppLocalizations.of(context);
    final text = _shoppingList
        .map((i) => '• ${i.name}  ${i.amount} ${i.unit}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    AppSnackBar.success(context, l10n.translate('shopping.copied'));
  }

  void _shareList(BuildContext buttonContext) {
    if (_shoppingList.isEmpty) return;

    final box = buttonContext.findRenderObject() as RenderBox?;
    final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;

    SharingService().shareShoppingList(
      buttonContext,
      _shoppingList.map((i) => '${i.name}  ${i.amount} ${i.unit}').toList(),
      sharePositionOrigin: rect,
    );
  }

  void _showAddItemDialog() {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (ctx) => _AddItemDialog(
        l10n: l10n,
        onAdd: (name, amount, unit) async {
          await _shoppingRepo.add(Ingredient(
            name: name,
            amount: amount,
            unit: unit,
            calories: 0,
          ));
          if (mounted) {
            _loadShoppingList();
            _syncToCloud();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    final filtered =
        _shoppingList.where(_matchesDateFilter).toList(growable: false);
    final unchecked =
        filtered.where((i) => !_checkedItems.contains(i.name)).toList();
    final checked =
        filtered.where((i) => _checkedItems.contains(i.name)).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: _buildAppBar(l10n, palette, primary),
      body: Stack(
        children: [
          // Mesh-glow ambient background blobs
          ...AppGradients.meshGlow(palette, primary),
          // Main content
          _shoppingList.isEmpty
              ? _buildEmptyState(l10n, palette, primary)
              : Column(
                  children: [
                    if (_hasDatedItems)
                      Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs.h),
                        child: AppFilterBar(
                          children: [
                            AppFilterPill(
                              label: l10n.translate('shopping.filter_week'),
                              icon: Icons.calendar_view_week_rounded,
                              active: _dateFilter == 'all',
                              onTap: () => setState(() => _dateFilter = 'all'),
                            ),
                            AppFilterPill(
                              label: l10n.translate('shopping.filter_today'),
                              icon: Icons.today_rounded,
                              active: _dateFilter == 'today',
                              onTap: () =>
                                  setState(() => _dateFilter = 'today'),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: _buildList(
                          l10n, palette, primary, unchecked, checked),
                    ),
                  ],
                ),
        ],
      ),
      floatingActionButton: _buildFab(l10n, primary),
    );
  }

  PreferredSizeWidget _buildAppBar(
    AppLocalizations l10n,
    AppPalette palette,
    Color primary,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 2),
      child: Column(
        children: [
          AppBar(
            backgroundColor: palette.background,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            title: Text(
              l10n.translate('shopping.title'),
              style: AppText.of(context).headlineS,
            ),
            iconTheme: IconThemeData(color: palette.textPrimary),
            actions: [
              if (_isGenerating)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primary,
                    ),
                  ),
                )
              else
                IconButton(
                  tooltip: l10n.translate('shopping.generate_from_plan'),
                  icon: const Icon(Icons.auto_awesome),
                  onPressed: _generateFromPlan,
                ),
              if (_shoppingList.isNotEmpty) ...[
                Builder(
                  builder: (buttonContext) => IconButton(
                    tooltip: l10n.translate('shopping.share'),
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => _shareList(buttonContext),
                  ),
                ),
                IconButton(
                  tooltip: l10n.translate('shopping.copy'),
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: _copyToClipboard,
                ),
                IconButton(
                  tooltip: l10n.translate('shopping.clear_list'),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clearList,
                ),
              ],
            ],
          ),
          // Gradient accent line below AppBar
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: AppGradients.brand(primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFab(AppLocalizations l10n, Color primary) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.brand(primary),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.38),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(Icons.add),
        label: Text(l10n.translate('shopping.add_item')),
      ),
    );
  }

  Widget _buildEmptyState(
    AppLocalizations l10n,
    AppPalette palette,
    Color primary,
  ) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Brand-colored glow behind the icon
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120.r,
                height: 120.r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
              AppEmptyState(
                icon: Icons.shopping_basket_outlined,
                title: l10n.translate('shopping.empty'),
                actionLabel: _isGenerating
                    ? null
                    : l10n.translate('shopping.generate_from_plan'),
                onAction: _isGenerating ? null : _generateFromPlan,
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    AppLocalizations l10n,
    AppPalette palette,
    Color primary,
    List<Ingredient> unchecked,
    List<Ingredient> checked,
  ) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md.w,
        AppSpacing.xs.h,
        AppSpacing.md.w,
        100.h,
      ),
      children: [
        if (unchecked.isNotEmpty) ...[
          _buildSectionHeader(
            '${l10n.translate('shopping.to_buy')} (${unchecked.length})',
            palette,
            primary,
          ),
          SizedBox(height: AppSpacing.xs.h),
          ...unchecked.map((item) => _buildItem(item, palette, primary)),
        ],
        if (checked.isNotEmpty) ...[
          SizedBox(height: AppSpacing.md.h),
          _buildSectionHeader(
            '${l10n.translate('shopping.in_cart')} (${checked.length})',
            palette,
            primary,
          ),
          SizedBox(height: AppSpacing.xs.h),
          ...checked.map((item) => _buildItem(item, palette, primary)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, AppPalette palette, Color primary) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: AppPalette.glassBlurSubtle,
            sigmaY: AppPalette.glassBlurSubtle,
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm.w,
              vertical: AppSpacing.xxs.h + 2,
            ),
            decoration: BoxDecoration(
              color: palette.glassFill.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
              border: Border.all(
                color: palette.glassStroke.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              title.toUpperCase(),
              style: AppText.of(context).overline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(Ingredient item, AppPalette palette, Color primary) {
    final isChecked = _checkedItems.contains(item.name);
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xs.h),
      child: Dismissible(
        key: Key(item.name),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: palette.error,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
          ),
          alignment: Alignment.centerRight,
          padding: EdgeInsets.only(right: AppSpacing.lg.w),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => _deleteItem(item.name),
        child: AppGlassCard(
          blur: isChecked
              ? AppPalette.glassBlurSubtle
              : AppPalette.glassBlurDefault,
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm.w,
            vertical: AppSpacing.xxs.h,
          ),
          onTap: () => _toggleItem(item.name),
          child: AnimatedOpacity(
            duration: AppMotion.fast,
            opacity: isChecked ? 0.65 : 1.0,
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs.w,
                vertical: AppSpacing.xxs.h,
              ),
              leading: GestureDetector(
                onTap: () => _toggleItem(item.name),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  width: 24.r,
                  height: 24.r,
                  decoration: BoxDecoration(
                    color: isChecked ? primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.xs.r),
                    border: Border.all(
                      color: isChecked ? primary : palette.textTertiary,
                      width: 2,
                    ),
                    boxShadow: isChecked
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: isChecked
                      ? Icon(Icons.check, size: 14.r, color: Colors.white)
                      : null,
                ),
              ),
              title: AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                style: AppText.of(context).titleM.copyWith(
                      decoration: isChecked
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      decorationColor: palette.textTertiary,
                      color: isChecked
                          ? palette.textTertiary
                          : palette.textPrimary,
                      fontWeight:
                          isChecked ? FontWeight.normal : FontWeight.w600,
                    ),
                child: Text(item.name),
              ),
              subtitle: item.sourceMeals.isEmpty
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(top: 2.h),
                      child: Text(
                        '${AppLocalizations.of(context).translate('shopping.source_prefix')}: ${item.sourceMeals.join(', ')}',
                        style: AppText.of(context).labelS.copyWith(
                              color: palette.textTertiary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              trailing: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs.w,
                  vertical: AppSpacing.xxs.h,
                ),
                decoration: BoxDecoration(
                  color: isChecked
                      ? palette.surfaceVariant
                      : primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xs.r),
                ),
                child: Text(
                  '${item.amount % 1 == 0 ? item.amount.toInt() : item.amount} ${item.unit}',
                  style: AppText.of(context).labelM.copyWith(
                        color: isChecked ? palette.textTertiary : primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  final AppLocalizations l10n;
  final Future<void> Function(String name, double amount, String unit) onAdd;

  const _AddItemDialog({
    required this.l10n,
    required this.onAdd,
  });

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController(text: '1');
    _unitController = TextEditingController(text: 'pcs');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.translate('shopping.add_item')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: widget.l10n.translate('shopping.item_name'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: widget.l10n.translate('shopping.amount'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _unitController,
                  decoration: InputDecoration(
                    labelText: widget.l10n.translate('shopping.unit'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.l10n.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _isAdding
              ? null
              : () async {
                  final name = _nameController.text.trim();
                  if (name.isEmpty) return;
                  setState(() => _isAdding = true);
                  final amount = double.tryParse(_amountController.text) ?? 1.0;
                  final unit = _unitController.text.trim().isEmpty
                      ? 'pcs'
                      : _unitController.text.trim();
                  final nav = Navigator.of(context);
                  await widget.onAdd(name, amount, unit);
                  if (!mounted) return;
                  nav.pop();
                },
          child: _isAdding
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.l10n.translate('common.add')),
        ),
      ],
    );
  }
}
