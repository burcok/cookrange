import 'package:cookrange/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/analytics_service.dart';
import '../../../widgets/onboarding_common_widgets.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/prompt_service.dart';
import '../../../core/constants/onboarding_options.dart';

class OnboardingPage3 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final ValueNotifier<bool> isLoadingNotifier;
  const OnboardingPage3({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.isLoadingNotifier,
  });

  @override
  State<OnboardingPage3> createState() => _OnboardingPage3State();
}

class _OnboardingPage3State extends State<OnboardingPage3> {
  final _analyticsService = AnalyticsService();
  final _searchController = TextEditingController();
  DateTime? _stepStartTime;

  // Predefined ingredients from central options
  late final List<OptionData> _allIngredients =
      OnboardingOptions.predefinedIngredients.entries.map((e) {
    return OptionData(
      label: e.value['label'] as String,
      icon: e.value['icon'] as IconData,
      value: e.key,
    );
  }).toList();

  late final Set<String> _predefinedIngredientValues;
  final Set<String> _predefinedIngredientLabels = {};
  List<OptionData> _translatedIngredients = [];

  List<OptionData> _filteredIngredients = [];
  List<String> _selectedIngredientValues = [];
  final List<OptionData> _customIngredients = [];
  late int _remainingCustomSlots;
  bool _showCustomAddOption = false;
  String _currentSearchQuery = '';
  bool _isLoadingAI = false;

  @override
  void initState() {
    super.initState();
    _stepStartTime = DateTime.now();
    _predefinedIngredientValues = _allIngredients.map((i) => i.value).toSet();
    _predefinedIngredientLabels.addAll(_allIngredients.map((i) => i.label));

    final onboarding = context.read<OnboardingProvider>();

    // Reconstruct custom ingredients and populate selected values
    _selectedIngredientValues = [];
    for (final food in onboarding.dislikedFoods) {
      final value = food['value'] as String;
      _selectedIngredientValues.add(value);

      // Check if it's a custom ingredient
      if (!_predefinedIngredientValues.contains(value)) {
        _customIngredients.add(OptionData(
          label: food['label'] as String,
          value: value,
          icon: Icons.auto_awesome,
        ));
      }
    }

    _remainingCustomSlots = 3 - _customIngredients.length;

    _searchController.addListener(_filterIngredients);
    _logStepView();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _translateAndCacheIngredients();
    _filterIngredients(); // Initial filter
  }

  void _translateAndCacheIngredients() {
    final localizations = AppLocalizations.of(context);
    _translatedIngredients = _allIngredients
        .map((ingredient) => OptionData(
              label: localizations.translate(ingredient.label),
              value: ingredient.value,
              icon: ingredient.icon,
            ))
        .toList();
  }

  @override
  void dispose() {
    if (_stepStartTime != null) {
      final duration = DateTime.now().difference(_stepStartTime!);
      _analyticsService.logScreenTime(
        screenName: 'onboarding_step_3',
        duration: duration,
      );
    }
    _searchController.dispose();
    super.dispose();
  }

  void _logStepView() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'dietary_preferences',
      action: 'view',
      parameters: {
        'step_number': 3,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logSelection(String type, String value) {
    _analyticsService.logUserInteraction(
      interactionType: 'selection',
      target: '${type}_selection',
      parameters: {
        'step': 3,
        'type': type,
        'value': value,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logCustomIngredientAdded(String ingredient) {
    _analyticsService.logUserInteraction(
      interactionType: 'custom_ingredient',
      target: 'add_custom_ingredient',
      parameters: {
        'step': 3,
        'ingredient': ingredient,
        'remaining_slots': _remainingCustomSlots,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _filterIngredients() {
    final query = _searchController.text.toLowerCase();
    _currentSearchQuery = query;

    setState(() {
      if (query.isEmpty) {
        _filteredIngredients =
            _translatedIngredients.take(10).toList(); // Show only first 10
        _showCustomAddOption = false;
      } else {
        _filteredIngredients = _translatedIngredients
            .where(
                (ingredient) => ingredient.label.toLowerCase().contains(query))
            .take(10) // Limit to 10 results
            .toList();

        // Check if we should show custom add option
        // Only show when no results found AND no exact match exists
        final allDisplayIngredients = [
          ..._translatedIngredients,
          ..._customIngredients
        ];
        final hasExactMatch = allDisplayIngredients.any(
          (ingredient) => ingredient.label.toLowerCase() == query,
        );

        _showCustomAddOption = _filteredIngredients.isEmpty &&
            !hasExactMatch &&
            query.isNotEmpty &&
            _remainingCustomSlots > 0;
      }
    });
  }

  void _toggleIngredient(OptionData ingredient) {
    setState(() {
      if (_selectedIngredientValues.contains(ingredient.value)) {
        _selectedIngredientValues.remove(ingredient.value);

        // Find original ingredient data to save the key
        final originalIngredient = _allIngredients.firstWhere(
          (i) => i.value == ingredient.value,
          orElse: () => ingredient, // For custom ingredients
        );

        context.read<OnboardingProvider>().toggleDislikedFood({
          'label': originalIngredient.label,
          'icon': ingredient.icon.toString(),
          'value': ingredient.value,
        });
        _logSelection('remove_ingredient', ingredient.value);
      } else {
        _selectedIngredientValues.add(ingredient.value);
        // Find original ingredient data to save the key
        final originalIngredient = _allIngredients.firstWhere(
          (i) => i.value == ingredient.value,
          orElse: () => ingredient, // For custom ingredients
        );
        context.read<OnboardingProvider>().toggleDislikedFood({
          'label': originalIngredient.label,
          'icon': ingredient.icon.toString(),
          'value': ingredient.value,
        });
        _logSelection('add_ingredient', ingredient.value);
      }
    });
  }

  Future<void> _addCustomIngredient() async {
    if (_remainingCustomSlots <= 0) return;

    final query = _currentSearchQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoadingAI = true;
    });

    try {
      // Call AI API to get ingredient data
      final aiIngredient = await _callAIAPI(query);

      if (aiIngredient != null) {
        setState(() {
          _customIngredients.add(aiIngredient);
          _remainingCustomSlots--;
          _showCustomAddOption = false;
          _searchController.clear();
          _currentSearchQuery = '';
        });

        // Automatically select the newly added custom ingredient
        _toggleIngredient(aiIngredient);

        _logCustomIngredientAdded(query);
        _logCustomIngredientForValidation(
            aiIngredient.label, aiIngredient.value);
      }
    } catch (e) {
      // If AI API fails, fall back to manual addition
      _addManualCustomIngredient(query);
    } finally {
      setState(() {
        _isLoadingAI = false;
      });
    }
  }

  Future<OptionData?> _callAIAPI(String query) async {
    try {
      final prompt = PromptService().validateIngredientPrompt(query);

      final jsonResponse = await AIService().generateJson(
        prompt: prompt,
        jsonStructure: '''
{
  "label": "Display Name (Capitalized)",
  "value": "normalized_snake_case_value",
  "icon": "one of: vegetable, fruit, protein, dairy, grain, nut, other",
  "calories": number
}
''',
      );

      return OptionData(
        label: jsonResponse['label'] as String,
        icon: _getIconFromAIResponse(jsonResponse['icon'] as String),
        value: jsonResponse['value'] as String,
      );
    } catch (e) {
      // print('AI API call failed: $e');
      return null;
    }
  }

  IconData _getIconFromAIResponse(String iconType) {
    switch (iconType) {
      case 'ai-selected':
        return Icons.auto_awesome;
      case 'vegetable':
        return Icons.eco;
      case 'fruit':
        return Icons.circle;
      case 'protein':
        return Icons.fitness_center;
      case 'dairy':
        return Icons.water_drop;
      case 'grain':
        return Icons.grain;
      case 'nut':
        return Icons.circle;
      default:
        return Icons.auto_awesome;
    }
  }

  void _addManualCustomIngredient(String query) {
    // Fallback method if AI API fails
    final value = query.toLowerCase().replaceAll(' ', '_');

    final customIngredient = OptionData(
      label: query,
      icon: Icons.add_circle_outline,
      value: value,
    );

    setState(() {
      _customIngredients.add(customIngredient);
      _remainingCustomSlots--;
      _showCustomAddOption = false;
      _searchController.clear();
      _currentSearchQuery = '';
    });

    _toggleIngredient(customIngredient);
    _logCustomIngredientAdded(query);
    _logCustomIngredientForValidation(query, value);
  }

  void _logCustomIngredientForValidation(String label, String value) {
    // This will be used later for AI validation
    _analyticsService.logUserInteraction(
      interactionType: 'custom_ingredient_validation',
      target: 'pending_validation',
      parameters: {
        'step': 3,
        'label': label,
        'value': value,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _removeCustomIngredient(String ingredientValue) {
    final customIngredient = _customIngredients.firstWhere(
      (ingredient) => ingredient.value == ingredientValue,
    );
    final ingredientMap = {
      'label': customIngredient.label,
      'icon': customIngredient.icon.toString(),
      'value': customIngredient.value,
    };

    setState(() {
      _customIngredients.remove(customIngredient);
      _selectedIngredientValues.remove(ingredientValue);
      context.read<OnboardingProvider>().toggleDislikedFood(
          ingredientMap); // Remove from provider if it exists
      // Note: We don't restore the slot when removing custom ingredients
      // This prevents abuse of the system
    });
  }

  String _getIngredientLabel(OptionData ingredient) {
    final localizations = AppLocalizations.of(context);
    final isPredefined = _predefinedIngredientValues.contains(ingredient.value);

    if (isPredefined && _translatedIngredients.isNotEmpty) {
      try {
        return _translatedIngredients
            .firstWhere((i) => i.value == ingredient.value)
            .label;
      } catch (e) {
        // Fallback for safety
        return localizations.translate(_allIngredients
            .firstWhere((i) => i.value == ingredient.value)
            .label);
      }
    }

    return ingredient.label;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.backgroundColor2,
      body: SafeArea(
        child: Column(
          children: [
            // Header Section
            OnboardingHeader(
              title: localizations.translate('onboarding.page3.header'),
              currentStep: widget.step + 1,
              totalSteps: 6,
              previousStep: widget.previousStep,
              onBackButtonPressed: () {
                _analyticsService.logUserInteraction(
                  interactionType: 'navigation',
                  target: 'back_button',
                  parameters: {
                    'step': 3,
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );
                // Sayfa 3'ten sayfa 2'ye git
                if (widget.onBack != null) {
                  widget.onBack!();
                }
              },
            ),

            // Main Content Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // Main Title
                    Text(
                      localizations.translate('onboarding.page3.main_title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onboardingTitleColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      localizations.translate('onboarding.page3.subtitle'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onboardingSubtitleColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Search Input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        enableInteractiveSelection: false, // Disable paste
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z\s]')), // Only letters and spaces
                        ],
                        decoration: InputDecoration(
                          hintText: localizations
                              .translate('onboarding.page3.search_hint'),
                          hintStyle: TextStyle(
                            color: colorScheme.onboardingSubtitleColor,
                            fontSize: 14,
                            fontFamily: 'Poppins',
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: colorScheme.onboardingSubtitleColor,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Poppins',
                          color: colorScheme.onboardingTitleColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Custom Add Option
                    if (_showCustomAddOption) ...[
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: localizations.translate(
                                        'onboarding.page3.custom_not_found'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onboardingTitleColor,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                  TextSpan(
                                    text: localizations.translate(
                                        'onboarding.page3.custom_add_hint'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: colorScheme.onboardingTitleColor,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed:
                                _isLoadingAI ? null : _addCustomIngredient,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: _isLoadingAI
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onboardingOptionBgColor,
                                      ),
                                    ),
                                  )
                                : Text(
                                    localizations.translate(
                                        'onboarding.page3.custom_add'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Remaining Custom Slots Info
                    if (_remainingCustomSlots < 3) ...[
                      Text(
                        '${localizations.translate('onboarding.page3.custom_slots_remaining')}$_remainingCustomSlots',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onboardingSubtitleColor,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Selected Ingredients Section
                    if (_selectedIngredientValues.isNotEmpty) ...[
                      Text(
                        localizations
                            .translate('onboarding.page3.selected_title'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onboardingTitleColor,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children:
                            _selectedIngredientValues.map((ingredientValue) {
                          final allIngredients = [
                            ..._translatedIngredients,
                            ..._customIngredients
                          ];
                          final ingredient = allIngredients.firstWhere(
                            (ingredient) => ingredient.value == ingredientValue,
                            orElse: () {
                              final originalIngredient =
                                  _allIngredients.firstWhere(
                                (i) => i.value == ingredientValue,
                                orElse: () => OptionData(
                                    label: 'Unknown',
                                    value: ingredientValue,
                                    icon: Icons.help),
                              );
                              return OptionData(
                                label: _getIngredientLabel(originalIngredient),
                                value: ingredientValue,
                                icon: originalIngredient.icon,
                              );
                            },
                          );
                          return _buildSelectedIngredient(ingredient);
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Available Ingredients Section - Only show when there are results
                    if (_filteredIngredients.isNotEmpty ||
                        _customIngredients.any((ingredient) =>
                            !_selectedIngredientValues
                                .contains(ingredient.value))) ...[
                      Text(
                        localizations
                            .translate('onboarding.page3.available_title'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onboardingTitleColor,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          ..._filteredIngredients
                              .where((ingredient) => !_selectedIngredientValues
                                  .contains(ingredient.value))
                              .map((ingredient) =>
                                  _buildAvailableIngredient(ingredient)),
                          ..._customIngredients
                              .where((ingredient) => !_selectedIngredientValues
                                  .contains(ingredient.value))
                              .map((ingredient) =>
                                  _buildCustomAvailableIngredient(ingredient)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 100), // Space for fixed button
                  ],
                ),
              ),
            ),

            // Fixed Continue Button
            OnboardingContinueButton(
              onPressed: () {
                _analyticsService.logUserInteraction(
                  interactionType: 'button_click',
                  target: 'continue_button',
                  parameters: {
                    'step': 3,
                    'selected_ingredients': _selectedIngredientValues.join(','),
                    'custom_ingredients': _customIngredients
                        .map((ingredient) => ingredient.value)
                        .join(','),
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );

                widget.onNext?.call();
              },
              text: localizations.translate('onboarding.page3.continue'),
              isLoadingNotifier: widget.isLoadingNotifier,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedIngredient(OptionData ingredient) {
    return GestureDetector(
      onTap: () => _toggleIngredient(ingredient),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ingredient.icon,
              size: 18,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              _getIngredientLabel(ingredient),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.close,
              size: 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableIngredient(OptionData ingredient) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _toggleIngredient(ingredient),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ingredient.icon,
              size: 20,
              color: colorScheme.onboardingTitleColor,
            ),
            const SizedBox(width: 8),
            Text(
              _getIngredientLabel(ingredient),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onboardingTitleColor,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomAvailableIngredient(OptionData ingredient) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _toggleIngredient(ingredient),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.onboardingOptionBgColor,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: colorScheme.primaryColorCustom.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ingredient.icon,
              size: 20,
              color: colorScheme.primaryColorCustom,
            ),
            const SizedBox(width: 8),
            Text(
              _getIngredientLabel(ingredient),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.primaryColorCustom,
                fontFamily: 'Poppins',
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _removeCustomIngredient(ingredient.value),
              child: Icon(
                Icons.remove_circle_outline,
                size: 16,
                color: colorScheme.primaryColorCustom.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
