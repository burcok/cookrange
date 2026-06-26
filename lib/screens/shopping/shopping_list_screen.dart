import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/ingredient_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/dish_service.dart';
import '../../core/services/shopping_list_sync_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/weekly_meal_plan_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen>
    with SingleTickerProviderStateMixin {
  final StorageService _storageService = StorageService();
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
    // Load from Hive immediately, then try Firestore for fresher cross-device data
    setState(() {
      _shoppingList = _storageService.getShoppingList();
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
    await _storageService.removeFromShoppingList(name);
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
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _storageService.clearShoppingList();
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

    setState(() => _isGenerating = true);
    try {
      final plan = await WeeklyMealPlanService().getWeeklyMealPlan(user);
      if (plan == null || plan.days.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.translate('shopping.no_plan'))),
          );
        }
        return;
      }

      // Collect all unique dish names from the plan
      final allDishNames = <String>{};
      for (final day in plan.days) {
        allDishNames.addAll(day.meals.values);
      }

      // Fetch all dishes and build a name lookup
      final dishes = await DishService().getAllDishes();
      final nameMap = {for (final d in dishes) d.name.toLowerCase(): d};

      // Aggregate ingredients, merging duplicates by name
      final merged = <String, Ingredient>{};
      for (final dishName in allDishNames) {
        final dish = nameMap[dishName.toLowerCase()];
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(l10n.translate('shopping.no_ingredients'))),
          );
        }
        return;
      }

      // Clear current list and add aggregated ingredients
      await _storageService.clearShoppingList();
      for (final ingredient in merged.values) {
        await _storageService.addToShoppingList(ingredient);
      }

      if (mounted) {
        _loadShoppingList();
        _syncToCloud();
        unawaited(HapticFeedback.mediumImpact());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.translate('shopping.generated',
                variables: {'count': '${merged.length}'})),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.translate('common.error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.translate('shopping.copied'))),
    );
  }

  void _showAddItemDialog() {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController();
    final amountController = TextEditingController(text: '1');
    final unitController = TextEditingController(text: 'pcs');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('shopping.add_item')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.translate('shopping.item_name'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.translate('shopping.amount'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: InputDecoration(
                      labelText: l10n.translate('shopping.unit'),
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.translate('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              final navigator = Navigator.of(ctx);
              await _storageService.addToShoppingList(Ingredient(
                name: name,
                amount: double.tryParse(amountController.text) ?? 1.0,
                unit: unitController.text.trim().isEmpty
                    ? 'pcs'
                    : unitController.text.trim(),
                calories: 0,
              ));
              navigator.pop();
              if (mounted) {
                _loadShoppingList();
                _syncToCloud();
              }
            },
            child: Text(l10n.translate('common.add')),
          ),
        ],
      ),
    ).then((_) {
      nameController.dispose();
      amountController.dispose();
      unitController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFCFBF9);
    final cardBg = isDark ? const Color(0xFF1C2330) : Colors.white;

    final unchecked =
        _shoppingList.where((i) => !_checkedItems.contains(i.name)).toList();
    final checked =
        _shoppingList.where((i) => _checkedItems.contains(i.name)).toList();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          l10n.translate('shopping.title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
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
          ? _buildEmptyState(l10n, isDark, primary)
          : _buildList(l10n, isDark, primary, cardBg, unchecked, checked),
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

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark, Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined,
              size: 72,
              color: isDark ? Colors.grey[600] : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            l10n.translate('shopping.empty'),
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
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
    bool isDark,
    Color primary,
    Color cardBg,
    List<Ingredient> unchecked,
    List<Ingredient> checked,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (unchecked.isNotEmpty) ...[
          _buildSectionHeader(
            '${l10n.translate('shopping.to_buy')} (${unchecked.length})',
            isDark,
          ),
          const SizedBox(height: 8),
          ...unchecked.map((item) => _buildItem(item, isDark, primary, cardBg)),
        ],
        if (checked.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSectionHeader(
            '${l10n.translate('shopping.in_cart')} (${checked.length})',
            isDark,
          ),
          const SizedBox(height: 8),
          ...checked.map((item) => _buildItem(item, isDark, primary, cardBg)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: isDark ? Colors.grey[500] : Colors.grey[600],
      ),
    );
  }

  Widget _buildItem(
      Ingredient item, bool isDark, Color primary, Color cardBg) {
    final isChecked = _checkedItems.contains(item.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(item.name),
        direction: DismissDirection.endToStart,
        background: Container(
          decoration: BoxDecoration(
            color: Colors.red.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => _deleteItem(item.name),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: isChecked
                ? (isDark
                    ? Colors.grey[850]
                    : Colors.grey[100])
                : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isChecked
                  ? Colors.transparent
                  : isDark
                      ? Colors.white10
                      : Colors.grey.shade200,
            ),
            boxShadow: isChecked
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
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
                    color: isChecked
                        ? primary
                        : isDark
                            ? Colors.grey[500]!
                            : Colors.grey[400]!,
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
                decorationColor:
                    isDark ? Colors.grey[500] : Colors.grey[400],
                color: isChecked
                    ? (isDark ? Colors.grey[500] : Colors.grey[400])
                    : (isDark ? Colors.white : Colors.black87),
              ),
              child: Text(item.name),
            ),
            trailing: Text(
              '${item.amount % 1 == 0 ? item.amount.toInt() : item.amount} ${item.unit}',
              style: TextStyle(
                color: isChecked
                    ? (isDark ? Colors.grey[600] : Colors.grey[400])
                    : primary,
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
