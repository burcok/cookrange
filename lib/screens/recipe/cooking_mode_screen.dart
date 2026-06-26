import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/models/recipe_model.dart';
import '../../core/services/food_log_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../constants.dart';

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
    String selectedMealType = 'dinner';
    bool isLogging = false;

    final calories = (widget.recipe.macros['calories'] ?? 0).round();
    final protein = (widget.recipe.macros['protein'] ?? 0).round();
    final carbs = (widget.recipe.macros['carbs'] ?? 0).round();
    final fat = (widget.recipe.macros['fat'] ?? 0).round();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C2330),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate('cooking.finish.title'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.recipe.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Macro row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macroChip(l10n.translate('cooking.finish.calories'),
                          '$calories', const Color(0xFFFF6B6B)),
                      _macroChip(l10n.translate('cooking.finish.protein'),
                          '${protein}g', const Color(0xFF4ECDC4)),
                      _macroChip(l10n.translate('cooking.finish.carbs'),
                          '${carbs}g', const Color(0xFFFFBE0B)),
                      _macroChip(l10n.translate('cooking.finish.fat'),
                          '${fat}g', const Color(0xFFA8DADC)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Meal type selector
                  Text(
                    l10n.translate('cooking.finish.meal_type'),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: ['breakfast', 'lunch', 'dinner', 'snack']
                        .map((type) {
                      final isSelected = selectedMealType == type;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedMealType = type),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? primaryColor
                                  : Colors.white24,
                            ),
                          ),
                          child: Text(
                            l10n.translate('cooking.finish.meal.$type'),
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : Colors.white60,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
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
                            side: const BorderSide(color: Colors.white24),
                            foregroundColor: Colors.white70,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(l10n.translate('cooking.finish.skip')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Log & Finish button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: isLogging
                              ? null
                              : () async {
                                  setSheetState(() => isLogging = true);
                                  final nav = Navigator.of(context);
                                  final sheetNav = Navigator.of(sheetCtx);
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
                                      setSheetState(() => isLogging = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: isLogging
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  l10n.translate('cooking.finish.log'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              color: color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(
                    'Step ${_currentStep + 1} of ${widget.recipe.instructions.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isTimerRunning ? Icons.pause_circle : Icons.play_circle,
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
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: _toggleTimer,
                  onLongPress: _resetTimer,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              _isTimerRunning ? primaryColor : Colors.grey),
                    ),
                    child: Text(
                      _formatTime(_secondsElapsed),
                      style: TextStyle(
                        color:
                            _isTimerRunning ? primaryColor : Colors.white,
                        fontSize: 24,
                        fontFamily: 'Courier',
                        fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          widget.recipe.instructions[index],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
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
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    FloatingActionButton(
                      heroTag: 'prev',
                      backgroundColor: Colors.grey[800],
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child:
                          const Icon(Icons.arrow_back, color: Colors.white),
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
                      backgroundColor: Colors.grey[800],
                      color: primaryColor,
                    ),
                  ),

                  FloatingActionButton(
                    heroTag: 'next',
                    backgroundColor: _currentStep <
                            widget.recipe.instructions.length - 1
                        ? primaryColor
                        : Colors.green,
                    onPressed: () {
                      if (_currentStep <
                          widget.recipe.instructions.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
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
