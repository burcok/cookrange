import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/recipe_generation_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../recipe/recipe_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
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
          unawaited(Navigator.push(
            context,
            AppTransitions.slideUp(RecipeDetailScreen(recipe: recipe)),
          ));
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
    super.build(context);
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

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
                      color: palette.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                "Search for any ingredient or dish, and our AI will create a personalized recipe for you.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: palette.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "e.g., Salmon with asparagus...",
                  prefixIcon: Icon(Icons.search, color: primary),
                  suffixIcon: IconButton(
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(Icons.arrow_forward, color: primary),
                    onPressed: _isLoading ? null : _handleSearch,
                  ),
                  filled: true,
                  fillColor: palette.surfaceVariant,
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
                  child: Text(_error!,
                      style: TextStyle(color: palette.error)),
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
                  _suggestionChip("Quick Pasta", palette, primary),
                  _suggestionChip("Low Carb Chicken", palette, primary),
                  _suggestionChip("Vegan Burger", palette, primary),
                  _suggestionChip("Healthy Breakfast", palette, primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, AppPalette palette, Color primary) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        _searchController.text = label;
        _handleSearch();
      },
      backgroundColor: primary.withValues(alpha: 0.1),
      labelStyle:
          TextStyle(color: primary, fontWeight: FontWeight.bold),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
