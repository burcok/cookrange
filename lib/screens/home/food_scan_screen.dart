import 'dart:async';
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
/// Reference implementation of the Cookrange Design System (Rule R7).
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

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(l10n.translate('food_scan.title'), style: t.headlineS),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.qr_code_scanner_rounded,
                color: palette.textPrimary),
            tooltip: l10n.translate('barcode.scan_btn'),
            onPressed: () => unawaited(Navigator.of(context).push(
              AppTransitions.slideUp(const BarcodeScanScreen()),
            )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH.w, vertical: AppSpacing.xs.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.translate('food_scan.subtitle'), style: t.bodyM),
            SizedBox(height: AppSpacing.lg.h),
            _buildInputCard(l10n, palette, t),
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
                  child: _buildResultCard(l10n, palette, t),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    return AppCard(
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
              fillColor: palette.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                borderSide: BorderSide(color: palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.input.r),
                borderSide: BorderSide(color: primary, width: 2),
              ),
              contentPadding: EdgeInsets.all(AppSpacing.sm.r),
            ),
          ),
          SizedBox(height: AppSpacing.sm.h),
          AppButton(
            label: _isAnalyzing
                ? l10n.translate('food_scan.analyzing')
                : l10n.translate('food_scan.analyze_btn'),
            icon: Icons.auto_awesome,
            loading: _isAnalyzing,
            onPressed: _analysisService.isAvailable ? _analyze : null,
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfiguredBanner(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    return Container(
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

  Widget _buildResultCard(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    final est = _estimate!;
    final primary = context.watch<ThemeProvider>().primaryColor;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs.r),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                ),
                child: Icon(Icons.restaurant_menu_rounded,
                    color: primary, size: AppSize.iconMd.r),
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
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  '${est.calories.toInt()} kcal',
                  style: t.labelM.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg.h),
          Row(
            children: [
              _macroChip(l10n.translate('food_scan.protein'), est.protein,
                  palette.protein, t),
              SizedBox(width: AppSpacing.xs.w),
              _macroChip(l10n.translate('food_scan.carbs'), est.carbs,
                  palette.carbs, t),
              SizedBox(width: AppSpacing.xs.w),
              _macroChip(l10n.translate('food_scan.fat'), est.fat, palette.fat, t),
            ],
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(l10n.translate('food_scan.meal_type_label'), style: t.titleM),
          SizedBox(height: AppSpacing.sm.h),
          _buildMealTypeSelector(l10n, palette, t, primary),
          SizedBox(height: AppSpacing.md.h),
          AppButton(
            label: l10n.translate('food_scan.log_btn'),
            icon: Icons.add_circle_outline_rounded,
            loading: _isLogging,
            onPressed: _logEstimate,
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, double value, Color color, AppText t) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        child: Column(
          children: [
            Text('${value.toInt()}g',
                style: t.titleL.copyWith(color: color)),
            SizedBox(height: AppSpacing.xxxs.h),
            Text(label, style: t.labelS),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector(
      AppLocalizations l10n, AppPalette palette, AppText t, Color primary) {
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
              margin: EdgeInsets.only(right: type.$1 != 'snack' ? AppSpacing.xs.w : 0),
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
              decoration: BoxDecoration(
                color: isSelected ? primary : palette.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
              ),
              child: Column(
                children: [
                  Icon(
                    type.$3,
                    size: AppSize.iconSm.r,
                    color: isSelected ? Colors.white : palette.textSecondary,
                  ),
                  SizedBox(height: AppSpacing.xxxs.h),
                  Text(
                    type.$2,
                    style: t.labelS.copyWith(
                      color: isSelected ? Colors.white : palette.textSecondary,
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
