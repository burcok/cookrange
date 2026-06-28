import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/providers/language_provider.dart';
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
    final locale =
        context.read<LanguageProvider>().currentLocale.languageCode;

    setState(() => _isGenerating = true);
    try {
      final plan =
          await WeeklyMealPlanService().getWeeklyMealPlan(user, locale: locale);
      if (plan == null || plan.days.isEmpty) {
        if (mounted) AppSnackBar.warning(context, l10n.translate('shopping.no_plan'));
        return;
      }

      // Collect all unique dish names from the plan
      final allDishNames = <String>{};
      for (final day in plan.days) {
        allDishNames.addAll(day.meals.values);
      }

      // Fetch all dishes and build an ID lookup
      final dishes = await DishService().getAllDishes();
      final idMap = {for (final d in dishes) d.id: d};

      // Aggregate ingredients, merging duplicates by name
      final merged = <String, Ingredient>{};
      for (final dishId in allDishNames) {
        final dish = idMap[dishId];
        if (dish == null) continue;
        for (final ingredient in dish.ingredients) {
          final key = ingredient.name.toLowerCase();
          if (merged.containsKey(key)) {
            final existing = merged[key]!;
            merged[key] = Ingredient(
              name: existing.name,
              amount: existing.amount + ingredient.amount,
              unit: existing.unit,
              calories: existing.calories + ingredient.calories,
            );
          } else {
            merged[key] = ingredient;
          }
        }
      }

      if (merged.isEmpty) {
        if (mounted) AppSnackBar.warning(context, l10n.translate('shopping.no_ingredients'));
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
        AppSnackBar.success(context,
            l10n.translate('shopping.generated', variables: {'count': '${merged.length}'}));
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, '${l10n.translate('common.error')}: $e');
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
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final primary = theme.colorScheme.primary;

    final unchecked =
        _shoppingList.where((i) => !_checkedItems.contains(i.name)).toList();
    final checked =
        _shoppingList.where((i) => _checkedItems.contains(i.name)).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.translate('shopping.title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
          ),
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
        actions: [
          if (_isGenerating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
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
      body: _shoppingList.isEmpty
          ? _buildEmptyState(l10n, palette, primary)
          : _buildList(l10n, palette, primary, unchecked, checked),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: Text(l10n.translate('shopping.add_item')),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, AppPalette palette, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined,
              size: 72,
              color: palette.textTertiary),
          const SizedBox(height: 16),
          Text(
            l10n.translate('shopping.empty'),
            style: TextStyle(
              color: palette.textSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _isGenerating ? null : _generateFromPlan,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(l10n.translate('shopping.generate_from_plan')),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary),
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (unchecked.isNotEmpty) ...[
          _buildSectionHeader(
            '${l10n.translate('shopping.to_buy')} (${unchecked.length})',
            palette,
          ),
          const SizedBox(height: 8),
          ...unchecked.map((item) => _buildItem(item, palette, primary)),
        ],
        if (checked.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(
            '${l10n.translate('shopping.in_cart')} (${checked.length})',
            palette,
          ),
          const SizedBox(height: 8),
          ...checked.map((item) => _buildItem(item, palette, primary)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, AppPalette palette) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: palette.textTertiary,
      ),
    );
  }

  Widget _buildItem(Ingredient item, AppPalette palette, Color primary) {
    final isChecked = _checkedItems.contains(item.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(item.name),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: palette.error,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => _deleteItem(item.name),
        child: TweenAnimationBuilder<Color?>(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          tween: ColorTween(
            begin: isChecked ? palette.surfaceVariant : palette.surface,
            end: isChecked ? palette.surfaceVariant : palette.surface,
          ),
          builder: (context, color, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChecked ? Colors.transparent : palette.border,
                ),
                boxShadow: isChecked
                    ? []
                    : [
                        BoxShadow(
                          color: palette.shadow.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: color,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(12),
                child: child,
              ),
            );
          },
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: GestureDetector(
              onTap: () => _toggleItem(item.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isChecked ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isChecked ? primary : palette.textTertiary,
                    width: 2,
                  ),
                ),
                child: isChecked
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : null,
              ),
            ),
            title: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 15,
                fontWeight:
                    isChecked ? FontWeight.normal : FontWeight.w600,
                decoration: isChecked
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationColor: palette.textTertiary,
                color: isChecked ? palette.textTertiary : palette.textPrimary,
              ),
              child: Text(item.name),
            ),
            trailing: Text(
              '${item.amount % 1 == 0 ? item.amount.toInt() : item.amount} ${item.unit}',
              style: TextStyle(
                color: isChecked ? palette.textTertiary : primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            onTap: () => _toggleItem(item.name),
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
                  final amount =
                      double.tryParse(_amountController.text) ?? 1.0;
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
