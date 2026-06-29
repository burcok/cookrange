import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/food_analysis_service.dart';
import '../../core/services/food_log_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'barcode_scan_screen.dart';

/// AI nutrition analysis — describe a food, get an estimate, log it.
/// Glassmorphism v2 update — visual layer only; all logic unchanged.
class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _analysisService = FoodAnalysisService();
  final _logService = FoodLogService();

  NutritionEstimate? _estimate;
  bool _isAnalyzing = false;
  bool _isLogging = false;
  String _selectedMealType = 'snack';
  String? _errorMessage;

  late final AnimationController _resultAnimController;
  late final Animation<double> _resultFade;
  late final Animation<Offset> _resultSlide;

  @override
  void initState() {
    super.initState();
    _resultAnimController = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _resultFade = CurvedAnimation(
        parent: _resultAnimController, curve: AppMotion.decelerate);
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _resultAnimController, curve: AppMotion.standard));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _resultAnimController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    unawaited(HapticFeedback.lightImpact());

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _estimate = null;
    });
    _resultAnimController.reset();

    try {
      final result = await _analysisService.analyzeFood(text);
      if (!mounted) return;
      setState(() {
        _estimate = result;
        _isAnalyzing = false;
      });
      if (result != null) unawaited(_resultAnimController.forward());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _logEstimate() async {
    final estimate = _estimate;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (estimate == null || uid == null) return;

    setState(() => _isLogging = true);
    try {
      await _logService.logScannedFood(
        userId: uid,
        mealType: _selectedMealType,
        estimate: estimate,
      );
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLogging = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Ambient mesh-glow background ──
          ...AppGradients.meshGlow(palette, primaryColor),

          // ── Main content ──
          Column(
            children: [
              // ── Glass AppBar ──
              _FoodScanAppBar(
                palette: palette,
                primaryColor: primaryColor,
                title: l10n.translate('food_scan.title'),
                onBack: () => Navigator.of(context).pop(),
                onBarcode: () => unawaited(Navigator.of(context).push(
                  AppTransitions.slideUp(const BarcodeScanScreen()),
                )),
                barcodeTooltip: l10n.translate('barcode.scan_btn'),
              ),

              // ── Scrollable body ──
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenH.w,
                      vertical: AppSpacing.xs.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.translate('food_scan.subtitle'), style: t.bodyM),
                      SizedBox(height: AppSpacing.lg.h),
                      _buildInputCard(l10n, palette, t, primaryColor),
                      SizedBox(height: AppSpacing.md.h),
                      if (!_analysisService.isAvailable)
                        _buildNotConfiguredBanner(l10n, palette, t),
                      if (_isAnalyzing) _buildAnalyzing(l10n, palette, t),
                      if (_errorMessage != null && !_isAnalyzing)
                        AppErrorState(
                          title: l10n.translate('common.error'),
                          message: _errorMessage,
                          retryLabel: l10n.translate('food_scan.analyze_btn'),
                          onRetry: _analyze,
                          compact: true,
                        ),
                      if (_estimate != null)
                        SlideTransition(
                          position: _resultSlide,
                          child: FadeTransition(
                            opacity: _resultFade,
                            child: _buildResultCard(
                                l10n, palette, t, primaryColor),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(AppLocalizations l10n, AppPalette palette, AppText t,
      Color primaryColor) {
    return AppGlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 3,
            minLines: 2,
            style: t.bodyL.copyWith(color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.translate('food_scan.input_hint'),
              hintStyle: t.bodyM.copyWith(color: palette.textTertiary),
              filled: true,
              fillColor: palette.surfaceVariant.withValues(alpha: 0.7),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                borderSide: BorderSide(color: palette.glassStroke),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                borderSide: BorderSide(color: palette.glassStroke),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                borderSide: BorderSide(color: primaryColor, width: 2),
              ),
              contentPadding: EdgeInsets.all(AppSpacing.sm.r),
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          // Gradient brand Analyze button
          GestureDetector(
            onTap: _analysisService.isAvailable
                ? (_isAnalyzing ? null : _analyze)
                : null,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              height: AppSize.buttonHeight.h,
              decoration: BoxDecoration(
                gradient: _analysisService.isAvailable && !_isAnalyzing
                    ? AppGradients.brand(primaryColor)
                    : null,
                color: !_analysisService.isAvailable || _isAnalyzing
                    ? palette.surfaceVariant
                    : null,
                borderRadius: BorderRadius.circular(AppRadius.button.r),
                boxShadow: _analysisService.isAvailable && !_isAnalyzing
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isAnalyzing)
                    Icon(Icons.auto_awesome,
                        color: _analysisService.isAvailable
                            ? palette.textInverse
                            : palette.textTertiary,
                        size: AppSize.iconSm.r),
                  if (!_isAnalyzing) SizedBox(width: AppSpacing.xs.w),
                  if (_isAnalyzing)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: primaryColor),
                    )
                  else
                    Text(
                      _isAnalyzing
                          ? l10n.translate('food_scan.analyzing')
                          : l10n.translate('food_scan.analyze_btn'),
                      style: t.labelL.copyWith(
                        color: _analysisService.isAvailable
                            ? palette.textInverse
                            : palette.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfiguredBanner(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: AppPalette.glassBlurSubtle,
            sigmaY: AppPalette.glassBlurSubtle),
        child: Container(
          margin: EdgeInsets.only(bottom: AppSpacing.sm.h),
          padding: EdgeInsets.all(AppSpacing.sm.r),
          decoration: BoxDecoration(
            color: palette.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(color: palette.warning.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: palette.warning, size: AppSize.iconMd.r),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Text(
                  l10n.translate('food_scan.not_configured'),
                  style: t.bodyM.copyWith(color: palette.warning),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzing(AppLocalizations l10n, AppPalette palette, AppText t) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      child: AppShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSkeletonBox(
                width: double.infinity, height: 120, radius: AppRadius.card),
            SizedBox(height: AppSpacing.sm.h),
            Row(
              children: [
                const Expanded(child: AppSkeletonBox(height: 56)),
                SizedBox(width: AppSpacing.xs.w),
                const Expanded(child: AppSkeletonBox(height: 56)),
                SizedBox(width: AppSpacing.xs.w),
                const Expanded(child: AppSkeletonBox(height: 56)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(AppLocalizations l10n, AppPalette palette, AppText t,
      Color primaryColor) {
    final est = _estimate!;
    return AppGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient header bar ──
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.card)),
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                gradient: AppGradients.brand(primaryColor),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                            sigmaX: AppPalette.glassBlurSubtle,
                            sigmaY: AppPalette.glassBlurSubtle),
                        child: Container(
                          padding: EdgeInsets.all(AppSpacing.xs.r),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm.r),
                            border: Border.all(
                                color:
                                    primaryColor.withValues(alpha: 0.25)),
                          ),
                          child: Icon(Icons.restaurant_menu_rounded,
                              color: primaryColor, size: AppSize.iconMd.r),
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(est.foodName, style: t.titleL),
                          if (est.servingSize.isNotEmpty)
                            Text(est.servingSize, style: t.labelS),
                        ],
                      ),
                    ),
                    // Calorie badge — gradient fill
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: AppSpacing.xxs.h),
                      decoration: BoxDecoration(
                        gradient: AppGradients.brand(primaryColor),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        '${est.calories.toInt()} kcal',
                        style: t.labelM.copyWith(
                            color: palette.textInverse,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg.h),
                // Macro chips — glass fill + glassStroke border
                Row(
                  children: [
                    _glassMacroChip(l10n.translate('food_scan.protein'),
                        est.protein, palette.protein, palette, t),
                    SizedBox(width: AppSpacing.xs.w),
                    _glassMacroChip(l10n.translate('food_scan.carbs'),
                        est.carbs, palette.carbs, palette, t),
                    SizedBox(width: AppSpacing.xs.w),
                    _glassMacroChip(l10n.translate('food_scan.fat'), est.fat,
                        palette.fat, palette, t),
                  ],
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(l10n.translate('food_scan.meal_type_label'),
                    style: t.titleM),
                SizedBox(height: AppSpacing.sm.h),
                _buildMealTypeSelector(l10n, palette, t, primaryColor),
                SizedBox(height: AppSpacing.md.h),
                // Log Food — gradient brand button
                GestureDetector(
                  onTap: _isLogging ? null : _logEstimate,
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    height: AppSize.buttonHeight.h,
                    decoration: BoxDecoration(
                      gradient: _isLogging
                          ? null
                          : AppGradients.brand(primaryColor),
                      color: _isLogging ? palette.surfaceVariant : null,
                      borderRadius: BorderRadius.circular(AppRadius.button.r),
                      boxShadow: _isLogging
                          ? null
                          : [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.4),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isLogging)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: primaryColor),
                          )
                        else ...[
                          Icon(Icons.add_circle_outline_rounded,
                              color: palette.textInverse,
                              size: AppSize.iconSm.r),
                          SizedBox(width: AppSpacing.xs.w),
                          Text(
                            l10n.translate('food_scan.log_btn'),
                            style: t.labelL.copyWith(
                                color: palette.textInverse,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassMacroChip(String label, double value, Color color,
      AppPalette palette, AppText t) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(
              sigmaX: AppPalette.glassBlurSubtle,
              sigmaY: AppPalette.glassBlurSubtle),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
            decoration: BoxDecoration(
              color: palette.glassFill,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(color: palette.glassStroke, width: 0.8),
            ),
            child: Column(
              children: [
                Text('${value.toInt()}g',
                    style: t.titleL.copyWith(
                        color: color, fontWeight: FontWeight.bold)),
                SizedBox(height: AppSpacing.xxxs.h),
                Text(label, style: t.labelS),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector(AppLocalizations l10n, AppPalette palette,
      AppText t, Color primaryColor) {
    final types = <(String, String, IconData)>[
      ('breakfast', l10n.translate('food_scan.meal.breakfast'),
          Icons.wb_sunny_outlined),
      ('lunch', l10n.translate('food_scan.meal.lunch'),
          Icons.lunch_dining_outlined),
      ('dinner', l10n.translate('food_scan.meal.dinner'),
          Icons.dinner_dining_outlined),
      ('snack', l10n.translate('food_scan.meal.snack'), Icons.apple_outlined),
    ];

    return Row(
      children: types.map((type) {
        final isSelected = _selectedMealType == type.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedMealType = type.$1);
            },
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              margin: EdgeInsets.only(
                  right: type.$1 != 'snack' ? AppSpacing.xs.w : 0),
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
              decoration: BoxDecoration(
                gradient:
                    isSelected ? AppGradients.brand(primaryColor) : null,
                color: isSelected ? null : palette.glassFill,
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
                border: Border.all(
                  color: isSelected
                      ? primaryColor.withValues(alpha: 0.5)
                      : palette.glassStroke,
                  width: 0.8,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    type.$3,
                    size: AppSize.iconSm.r,
                    color: isSelected
                        ? palette.textInverse
                        : palette.textSecondary,
                  ),
                  SizedBox(height: AppSpacing.xxxs.h),
                  Text(
                    type.$2,
                    style: t.labelS.copyWith(
                      color: isSelected
                          ? palette.textInverse
                          : palette.textSecondary,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Private sub-widget: glassmorphism AppBar ──────────────────────────────────

class _FoodScanAppBar extends StatelessWidget {
  final AppPalette palette;
  final Color primaryColor;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onBarcode;
  final String barcodeTooltip;

  const _FoodScanAppBar({
    required this.palette,
    required this.primaryColor,
    required this.title,
    required this.onBack,
    required this.onBarcode,
    required this.barcodeTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: AppPalette.glassBlurSubtle,
            sigmaY: AppPalette.glassBlurSubtle),
        child: Container(
          color: palette.background.withValues(alpha: 0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: topPad + AppSpacing.sm),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: palette.textSecondary),
                      onPressed: onBack,
                    ),
                    Expanded(
                      child: Text(title,
                          style: AppText.of(context).headlineS,
                          textAlign: TextAlign.center),
                    ),
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner_rounded,
                          color: palette.textSecondary),
                      tooltip: barcodeTooltip,
                      onPressed: onBarcode,
                    ),
                  ],
                ),
              ),
              // Brand gradient accent line
              Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.sunsetA,
                      primaryColor,
                      AppPalette.sunsetC,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
