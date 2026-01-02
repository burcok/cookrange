import 'package:flutter/material.dart';
import '../../core/models/ingredient_model.dart';
import '../../constants.dart';
import '../../core/services/storage_service.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final StorageService _storageService = StorageService();
  List<Ingredient> _shoppingList = [];
  final Set<String> _checkedItems = {};

  @override
  void initState() {
    super.initState();
    _loadShoppingList();
  }

  void _loadShoppingList() {
    setState(() {
      _shoppingList = _storageService.getShoppingList();
    });
  }

  void _toggleItem(String name) {
    setState(() {
      if (_checkedItems.contains(name)) {
        _checkedItems.remove(name);
      } else {
        _checkedItems.add(name);
      }
    });
  }

  Future<void> _deleteItem(String name) async {
    await _storageService.removeFromShoppingList(name);
    _loadShoppingList();
  }

  Future<void> _clearList() async {
    await _storageService.clearShoppingList();
    _loadShoppingList();
  }

  void _showAddItemDialog() {
    String name = '';
    double amount = 1.0;
    String unit = 'pcs';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Item Name'),
              onChanged: (value) => name = value,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType: TextInputType.number,
                    onChanged: (value) =>
                        amount = double.tryParse(value) ?? 1.0,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Unit'),
                    onChanged: (value) => unit = value,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (name.isNotEmpty) {
                final navigator = Navigator.of(context);

                await _storageService.addToShoppingList(Ingredient(
                  name: name,
                  amount: amount,
                  unit: unit,
                  calories: 0,
                ));

                if (mounted) {
                  navigator.pop();
                  _loadShoppingList();
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shopping List',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sharing coming soon!')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear List'),
                  content: const Text(
                      'Are you sure you want to clear your entire shopping list?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        _clearList();
                        Navigator.pop(context);
                      },
                      child: const Text('Clear',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _shoppingList.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_basket_outlined,
                      size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Your shopping list is empty',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _shoppingList.length,
              itemBuilder: (context, index) {
                final ingredient = _shoppingList[index];
                final isChecked = _checkedItems.contains(ingredient.name);

                return Dismissible(
                  key: Key(ingredient.name),
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _deleteItem(ingredient.name);
                  },
                  child: Card(
                    elevation: 0,
                    color: isChecked
                        ? Colors.grey[100]
                        : backgroundColorLight, // Using constant from theme
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            isChecked ? Colors.transparent : Colors.grey[300]!,
                      ),
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: isChecked,
                        activeColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (bool? value) {
                          _toggleItem(ingredient.name);
                        },
                      ),
                      title: Text(
                        ingredient.name,
                        style: TextStyle(
                          decoration: isChecked
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: isChecked ? Colors.grey : Colors.black87,
                          fontWeight:
                              isChecked ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                      trailing: Text(
                        '${ingredient.amount} ${ingredient.unit}',
                        style: TextStyle(
                          color: isChecked ? Colors.grey : primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () => _toggleItem(ingredient.name),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: primaryColor,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Item', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
