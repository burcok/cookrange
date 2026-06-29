import 'dart:ui';
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

    final palette = AppPalette.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadius.sheet)),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: AppPalette.glassBlurDefault,
                    sigmaY: AppPalette.glassBlurDefault),
                child: Container(
                  decoration: BoxDecoration(
                    color: palette.glassFill,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.sheet)),
                    border: Border(
                      top: BorderSide(
                          color: palette.glassStroke, width: 0.8),
                      left: BorderSide(
                          color: palette.glassStroke, width: 0.5),
                      right: BorderSide(
                          color: palette.glassStroke, width: 0.5),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Gradient accent line
                      Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: AppGradients.brand(primaryColor),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.sheet)),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.xl,
                          AppSpacing.lg,
                          AppSpacing.xl,
                          AppSpacing.xl +
                              MediaQuery.of(ctx).viewInsets.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: AppSize.sheetHandleW,
                              height: AppSize.sheetHandleH,
                              decoration: BoxDecoration(
                                color: palette.border,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xs),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            // Celebration icon with glow
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        primaryColor.withValues(alpha: 0.35),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
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
                                  // Macro row — glass chips
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _glassMacroChip(
                                          ctx2,
                                          l10n.translate(
                                              'cooking.finish.calories'),
                                          '$calories',
                                          palette.calories,
                                          palette),
                                      _glassMacroChip(
                                          ctx2,
                                          l10n.translate(
                                              'cooking.finish.protein'),
                                          '${protein}g',
                                          palette.protein,
                                          palette),
                                      _glassMacroChip(
                                          ctx2,
                                          l10n.translate(
                                              'cooking.finish.carbs'),
                                          '${carbs}g',
                                          palette.carbs,
                                          palette),
                                      _glassMacroChip(
                                          ctx2,
                                          l10n.translate(
                                              'cooking.finish.fat'),
                                          '${fat}g',
                                          palette.fat,
                                          palette),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  // Meal type selector
                                  Text(
                                    l10n.translate(
                                        'cooking.finish.meal_type'),
                                    style: t.labelM,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Wrap(
                                    spacing: AppSpacing.xs,
                                    children: [
                                      'breakfast',
                                      'lunch',
                                      'dinner',
                                      'snack'
                                    ].map((type) {
                                      final isSelected =
                                          selectedMealType == type;
                                      return GestureDetector(
                                        onTap: () => setSheetState(
                                            () => selectedMealType = type),
                                        child: AnimatedContainer(
                                          duration: AppMotion.fast,
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: AppSpacing.md,
                                                  vertical: AppSpacing.xs),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? AppGradients.brand(
                                                    primaryColor)
                                                : null,
                                            color: isSelected
                                                ? null
                                                : palette.glassFill,
                                            borderRadius:
                                                BorderRadius.circular(
                                                    AppRadius.full),
                                            border: Border.all(
                                              color: isSelected
                                                  ? primaryColor.withValues(
                                                      alpha: 0.6)
                                                  : palette.glassStroke,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: primaryColor
                                                          .withValues(
                                                              alpha: 0.35),
                                                      blurRadius: 10,
                                                      offset:
                                                          const Offset(0, 4),
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                          child: Text(
                                            l10n.translate(
                                                'cooking.finish.meal.$type'),
                                            style: t.labelM.copyWith(
                                              color: isSelected
                                                  ? palette.textInverse
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
                                      // Skip button — glass style
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppRadius.button),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX:
                                                    AppPalette.glassBlurSubtle,
                                                sigmaY:
                                                    AppPalette.glassBlurSubtle),
                                            child: GestureDetector(
                                              onTap: isLogging
                                                  ? null
                                                  : () {
                                                      Navigator.of(sheetCtx)
                                                          .pop();
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical:
                                                            AppSpacing.sm),
                                                decoration: BoxDecoration(
                                                  color: palette.glassFill,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppRadius.button),
                                                  border: Border.all(
                                                      color: palette.glassStroke,
                                                      width: 0.8),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    l10n.translate(
                                                        'cooking.finish.skip'),
                                                    style: t.labelL.copyWith(
                                                        color: palette
                                                            .textSecondary),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      // Log & Finish button — gradient brand
                                      Expanded(
                                        flex: 2,
                                        child: GestureDetector(
                                          onTap: isLogging
                                              ? null
                                              : () async {
                                                  setSheetState(
                                                      () => isLogging = true);
                                                  final nav =
                                                      Navigator.of(context);
                                                  final sheetNav =
                                                      Navigator.of(sheetCtx);
                                                  try {
                                                    final uid = FirebaseAuth
                                                        .instance
                                                        .currentUser
                                                        ?.uid;
                                                    if (uid != null) {
                                                      await FoodLogService()
                                                          .logRecipe(
                                                        userId: uid,
                                                        mealType:
                                                            selectedMealType,
                                                        recipe: widget.recipe,
                                                      );
                                                    }
                                                    if (mounted &&
                                                        ctx.mounted) {
                                                      sheetNav.pop();
                                                      nav.pop();
                                                    }
                                                  } catch (_) {
                                                    if (ctx.mounted) {
                                                      setSheetState(() =>
                                                          isLogging = false);
                                                    }
                                                  }
                                                },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: AppSpacing.sm),
                                            decoration: BoxDecoration(
                                              gradient: isLogging
                                                  ? null
                                                  : AppGradients.brand(
                                                      primaryColor),
                                              color: isLogging
                                                  ? palette.surfaceVariant
                                                  : null,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.button),
                                              boxShadow: isLogging
                                                  ? null
                                                  : [
                                                      BoxShadow(
                                                        color: primaryColor
                                                            .withValues(
                                                                alpha: 0.4),
                                                        blurRadius: 14,
                                                        offset:
                                                            const Offset(0, 4),
                                                      ),
                                                    ],
                                            ),
                                            child: Center(
                                              child: isLogging
                                                  ? SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: primaryColor,
                                                      ),
                                                    )
                                                  : Text(
                                                      l10n.translate(
                                                          'cooking.finish.log'),
                                                      style: t.labelL.copyWith(
                                                          color:
                                                              palette.textInverse,
                                                          fontWeight:
                                                              FontWeight.w700),
                                                    ),
                                            ),
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
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Glass macro chip for the finish sheet
  Widget _glassMacroChip(BuildContext ctx, String label, String value,
      Color color, AppPalette palette) {
    final t = AppText.of(ctx);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: AppPalette.glassBlurSubtle,
            sigmaY: AppPalette.glassBlurSubtle),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            children: [
              Text(
                value,
                style:
                    t.titleL.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.xxxs),
              Text(label, style: t.labelS),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final totalSteps = widget.recipe.instructions.length;
    final progress = (_currentStep + 1) / totalSteps;

    return Scaffold(
      backgroundColor: palette.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Ambient mesh-glow blobs ──
          ...AppGradients.meshGlow(palette, primaryColor),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                // ── Header with glass blur ──
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: AppPalette.glassBlurSubtle,
                        sigmaY: AppPalette.glassBlurSubtle),
                    child: Container(
                      color: palette.background.withValues(alpha: 0.55),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.xs),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Close button — glass pill
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: AppPalette.glassBlurSubtle,
                                        sigmaY: AppPalette.glassBlurSubtle),
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: palette.glassFill,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: palette.glassStroke,
                                              width: 0.8),
                                        ),
                                        child: Icon(Icons.close,
                                            color: palette.textPrimary,
                                            size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Step ${_currentStep + 1} of $totalSteps',
                                  style: t.titleL.copyWith(
                                      color: palette.textPrimary),
                                ),
                                // Timer toggle — glass pill
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: AppPalette.glassBlurSubtle,
                                        sigmaY: AppPalette.glassBlurSubtle),
                                    child: GestureDetector(
                                      onTap: _toggleTimer,
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: _isTimerRunning
                                              ? primaryColor.withValues(
                                                  alpha: 0.2)
                                              : palette.glassFill,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: _isTimerRunning
                                                ? primaryColor.withValues(
                                                    alpha: 0.5)
                                                : palette.glassStroke,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Icon(
                                          _isTimerRunning
                                              ? Icons.pause_circle
                                              : Icons.play_circle,
                                          color: primaryColor,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ── Thin gradient progress bar ──
                          Stack(
                            children: [
                              Container(
                                height: 3,
                                color: palette.border,
                              ),
                              AnimatedContainer(
                                duration: AppMotion.normal,
                                curve: AppMotion.standard,
                                height: 3,
                                width: MediaQuery.of(context).size.width *
                                    progress,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.brand(primaryColor),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Timer frosted-glass pill ──
                if (_secondsElapsed > 0 || _isTimerRunning)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.md, bottom: AppSpacing.xs),
                    child: GestureDetector(
                      onTap: _toggleTimer,
                      onLongPress: _resetTimer,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(
                              sigmaX: AppPalette.glassBlurDefault,
                              sigmaY: AppPalette.glassBlurDefault),
                          child: AnimatedContainer(
                            duration: AppMotion.fast,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: _isTimerRunning
                                  ? primaryColor.withValues(alpha: 0.2)
                                  : palette.glassFill,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              border: Border.all(
                                color: _isTimerRunning
                                    ? primaryColor.withValues(alpha: 0.5)
                                    : palette.glassStroke,
                              ),
                              boxShadow: _isTimerRunning
                                  ? [
                                      BoxShadow(
                                        color:
                                            primaryColor.withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Text(
                              _formatTime(_secondsElapsed),
                              style: t.displayM.copyWith(
                                color: _isTimerRunning
                                    ? primaryColor
                                    : palette.textPrimary,
                                fontFamily: 'Courier',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Step cards (PageView of AppGlassCard) ──
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: totalSteps,
                    onPageChanged: (index) {
                      setState(() => _currentStep = index);
                    },
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: AppGlassCard(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Text(
                                widget.recipe.instructions[index],
                                textAlign: TextAlign.center,
                                style: t.headlineM.copyWith(
                                  color: palette.textPrimary,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── Bottom navigation controls ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl,
                      AppSpacing.xs, AppSpacing.xl, AppSpacing.xl),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Prev button — glass FAB
                      if (_currentStep > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                                sigmaX: AppPalette.glassBlurDefault,
                                sigmaY: AppPalette.glassBlurDefault),
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _pageController.previousPage(
                                  duration: AppMotion.normal,
                                  curve: AppMotion.standard,
                                );
                              },
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: palette.glassFill,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: palette.glassStroke, width: 0.8),
                                ),
                                child: Icon(Icons.arrow_back,
                                    color: palette.textPrimary),
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 56),

                      // Center circular progress ring
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3.5,
                              strokeCap: StrokeCap.round,
                              backgroundColor:
                                  palette.border.withValues(alpha: 0.5),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(primaryColor),
                            ),
                            Text(
                              '${_currentStep + 1}',
                              style: t.titleM.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),

                      // Next / Finish button — gradient brand
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (_currentStep < totalSteps - 1) {
                            _pageController.nextPage(
                              duration: AppMotion.normal,
                              curve: AppMotion.standard,
                            );
                          } else {
                            _onFinish();
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: _currentStep < totalSteps - 1
                                ? AppGradients.brand(primaryColor)
                                : LinearGradient(colors: [
                                    palette.success,
                                    palette.energy
                                  ]),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_currentStep < totalSteps - 1
                                        ? primaryColor
                                        : palette.success)
                                    .withValues(alpha: 0.45),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            _currentStep < totalSteps - 1
                                ? Icons.arrow_forward
                                : Icons.check,
                            color: palette.textInverse,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
