import 'package:flutter/material.dart';
import '../../core/services/recipe_generation_service.dart';
import '../recipe/recipe_detail_screen.dart';
import '../../constants.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  final RecipeGenerationService _recipeService = RecipeGenerationService();

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipe = await _recipeService.generateRecipe(
        ingredients: [query],
        targetCalories: 500, // Default target
      );

      if (recipe != null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailScreen(recipe: recipe),
            ),
          );
        }
      } else {
        setState(() => _error = "Could not generate recipe. Please try again.");
      }
    } catch (e) {
      setState(() => _error = "Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Explore Recipes",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: title,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "Search for any ingredient or dish, and our AI will create a personalized recipe for you.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: subtitle,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "e.g., Salmon with asparagus...",
                  prefixIcon: const Icon(Icons.search, color: primaryColor),
                  suffixIcon: IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward, color: primaryColor),
                    onPressed: _isLoading ? null : _handleSearch,
                  ),
                  filled: true,
                  fillColor: inputBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _handleSearch(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child:
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 32),
              Text(
                "Try searching for:",
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _suggestionChip("Quick Pasta"),
                  _suggestionChip("Low Carb Chicken"),
                  _suggestionChip("Vegan Burger"),
                  _suggestionChip("Healthy Breakfast"),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionChip(String label) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _searchController.text = label;
        _handleSearch();
      },
      backgroundColor: primaryColor.withValues(alpha: 0.1),
      labelStyle:
          const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
