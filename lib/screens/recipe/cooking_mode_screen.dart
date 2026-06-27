import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/models/recipe_model.dart';
import '../../core/services/food_log_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/widgets/ds/ds.dart';

class CookingModeScreen extends StatefulWidget {
  final Recipe recipe;
  final int initialStepIndex;

  const CookingModeScreen({
    super.key,
    required this.recipe,
    this.initialStepIndex = 0,
  });

  @override
  State<CookingModeScreen> createState() => _CookingModeScreenState();
}

class _CookingModeScreenState extends State<CookingModeScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentStep;
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStepIndex;
    _pageController = PageController(initialPage: _currentStep);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTimer() {
    setState(() {
      _isTimerRunning = !_isTimerRunning;
      if (_isTimerRunning) {
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() => _secondsElapsed++);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  void _resetTimer() {
    setState(() {
      _timer?.cancel();
      _isTimerRunning = false;
      _secondsElapsed = 0;
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onFinish() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    _showFinishSheet();
  }

  Future<void> _showFinishSheet() async {
    final l10n = AppLocalizations.of(context);
    final primaryColor = context.read<ThemeProvider>().primaryColor;
    String selectedMealType = 'dinner';
    bool isLogging = false;

    final calories = (widget.recipe.macros['calories'] ?? 0).round();
    final protein = (widget.recipe.macros['protein'] ?? 0).round();
    final carbs = (widget.recipe.macros['carbs'] ?? 0).round();
    final fat = (widget.recipe.macros['fat'] ?? 0).round();

    // Capture palette before async gap
    final palette = AppPalette.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.xl + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppSize.sheetHandleW,
                    height: AppSize.sheetHandleH,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Celebration icon
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events,
                        color: Color(0xFFFFD700), size: 40),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Builder(builder: (ctx2) {
                    final t = AppText.of(ctx2);
                    return Column(
                      children: [
                        Text(
                          l10n.translate('cooking.finish.title'),
                          style: t.headlineS,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          widget.recipe.title,
                          textAlign: TextAlign.center,
                          style: t.bodyM,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Macro row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _macroChip(
                                l10n.translate('cooking.finish.calories'),
                                '$calories',
                                palette.calories,
                                t),
                            _macroChip(
                                l10n.translate('cooking.finish.protein'),
                                '${protein}g',
                                palette.protein,
                                t),
                            _macroChip(
                                l10n.translate('cooking.finish.carbs'),
                                '${carbs}g',
                                palette.carbs,
                                t),
                            _macroChip(l10n.translate('cooking.finish.fat'),
                                '${fat}g', palette.fat, t),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // Meal type selector
                        Text(
                          l10n.translate('cooking.finish.meal_type'),
                          style: t.labelM,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Wrap(
                          spacing: AppSpacing.xs,
                          children: ['breakfast', 'lunch', 'dinner', 'snack']
                              .map((type) {
                            final isSelected = selectedMealType == type;
                            return GestureDetector(
                              onTap: () => setSheetState(
                                  () => selectedMealType = type),
                              child: AnimatedContainer(
                                duration: AppMotion.fast,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primaryColor
                                      : palette.surface,
                                  borderRadius: BorderRadius.circular(
                                      AppRadius.full),
                                  border: Border.all(
                                    color: isSelected
                                        ? primaryColor
                                        : palette.border,
                                  ),
                                ),
                                child: Text(
                                  l10n.translate(
                                      'cooking.finish.meal.$type'),
                                  style: t.labelM.copyWith(
                                    color: isSelected
                                        ? Colors.white
                                        : palette.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            // Skip button
                            Expanded(
                              child: OutlinedButton(
                                onPressed: isLogging
                                    ? null
                                    : () {
                                        Navigator.of(sheetCtx).pop();
                                        Navigator.of(context).pop();
                                      },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: palette.border),
                                  foregroundColor: palette.textSecondary,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.button)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm),
                                ),
                                child: Text(
                                    l10n.translate('cooking.finish.skip')),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            // Log & Finish button
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: isLogging
                                    ? null
                                    : () async {
                                        setSheetState(() => isLogging = true);
                                        final nav = Navigator.of(context);
                                        final sheetNav =
                                            Navigator.of(sheetCtx);
                                        try {
                                          final uid = FirebaseAuth
                                              .instance.currentUser?.uid;
                                          if (uid != null) {
                                            await FoodLogService().logRecipe(
                                              userId: uid,
                                              mealType: selectedMealType,
                                              recipe: widget.recipe,
                                            );
                                          }
                                          if (mounted && ctx.mounted) {
                                            sheetNav.pop();
                                            nav.pop();
                                          }
                                        } catch (_) {
                                          if (ctx.mounted) {
                                            setSheetState(
                                                () => isLogging = false);
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                          AppRadius.button)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm),
                                  elevation: 0,
                                ),
                                child: isLogging
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : Text(
                                        l10n.translate('cooking.finish.log'),
                                        style: t.labelL.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _macroChip(String label, String value, Color color, AppText t) {
    return Column(
      children: [
        Text(
          value,
          style: t.titleL.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.xxxs),
        Text(label, style: t.labelS),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of ${widget.recipe.instructions.length}',
                    style: t.titleL.copyWith(color: Colors.white),
                  ),
                  IconButton(
                    icon: Icon(
                      _isTimerRunning
                          ? Icons.pause_circle
                          : Icons.play_circle,
                      color: primaryColor,
                    ),
                    onPressed: _toggleTimer,
                  ),
                ],
              ),
            ),

            // Timer Display
            if (_secondsElapsed > 0 || _isTimerRunning)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: GestureDetector(
                  onTap: _toggleTimer,
                  onLongPress: _resetTimer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xl, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                          color: _isTimerRunning
                              ? primaryColor
                              : palette.border),
                    ),
                    child: Text(
                      _formatTime(_secondsElapsed),
                      style: t.displayM.copyWith(
                        color: _isTimerRunning
                            ? primaryColor
                            : Colors.white,
                        fontFamily: 'Courier',
                      ),
                    ),
                  ),
                ),
              ),

            // Main Content (PageView)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.recipe.instructions.length,
                onPageChanged: (index) {
                  setState(() => _currentStep = index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          widget.recipe.instructions[index],
                          textAlign: TextAlign.center,
                          style: t.headlineM.copyWith(
                            color: Colors.white,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    FloatingActionButton(
                      heroTag: 'prev',
                      backgroundColor: palette.surfaceVariant,
                      onPressed: () {
                        _pageController.previousPage(
                          duration: AppMotion.normal,
                          curve: AppMotion.standard,
                        );
                      },
                      child: const Icon(Icons.arrow_back, color: Colors.white),
                    )
                  else
                    const SizedBox(width: 56),

                  SizedBox(
                    width: 60,
                    height: 60,
                    child: CircularProgressIndicator(
                      value: (_currentStep + 1) /
                          widget.recipe.instructions.length,
                      strokeWidth: 4,
                      backgroundColor: palette.surfaceVariant,
                      color: primaryColor,
                    ),
                  ),

                  FloatingActionButton(
                    heroTag: 'next',
                    backgroundColor:
                        _currentStep < widget.recipe.instructions.length - 1
                            ? primaryColor
                            : palette.success,
                    onPressed: () {
                      if (_currentStep <
                          widget.recipe.instructions.length - 1) {
                        _pageController.nextPage(
                          duration: AppMotion.normal,
                          curve: AppMotion.standard,
                        );
                      } else {
                        _onFinish();
                      }
                    },
                    child: Icon(
                      _currentStep < widget.recipe.instructions.length - 1
                          ? Icons.arrow_forward
                          : Icons.check,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
