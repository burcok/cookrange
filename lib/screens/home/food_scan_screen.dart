import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/food_analysis_service.dart';
import '../../core/services/food_analysis_history_service.dart';
import '../../core/services/food_log_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../ai/widgets/ai_credit_badge.dart';
import '../ai/widgets/ai_credits_sheet.dart';
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
  final _hintController = TextEditingController();
  final _focusNode = FocusNode();
  final _analysisService = FoodAnalysisService();
  final _logService = FoodLogService();
  final _picker = ImagePicker();

  NutritionEstimate? _estimate;
  bool _isAnalyzing = false;
  bool _isLogging = false;
  String _selectedMealType = 'snack';
  String? _errorMessage;

  // Input mode: 'text' (describe) | 'photo' (vision analysis).
  String _inputMode = 'text';
  Uint8List? _photoBytes;
  // Portion multiplier applied to the result (stepper). Reset on each analysis.
  double _portionFactor = 1.0;

  /// The estimate as displayed, after applying the portion multiplier.
  NutritionEstimate? get _displayEstimate =>
      _estimate?.scaled(_portionFactor);

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
    _hintController.dispose();
    _focusNode.dispose();
    _resultAnimController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _focusNode.unfocus();
    unawaited(HapticFeedback.lightImpact());

    // AI credit gate — capture user synchronously before any await.
    final userProv = context.read<UserProvider>();
    final uid = userProv.user?.uid;
    final isPremium =
        userProv.user?.subscriptionTier.isPremiumOrAbove ?? false;
    if (uid != null) {
      final canUse = await AiCreditService().checkAndConsume(uid, isPremium);
      if (!mounted) return;
      if (!canUse) {
        unawaited(AiCreditsSheet.show(context, uid: uid, isPremium: isPremium));
        return;
      }
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _estimate = null;
    });
    _resultAnimController.reset();

    try {
      final result = await _analysisService.analyzeFood(text);
      if (!mounted) return;
      // No usable result → refund the credit we just consumed.
      if (result == null && uid != null) {
        unawaited(AiCreditService().rollbackCredit(uid));
      }
      _onAnalysisResult(result, uid);
    } catch (e) {
      if (uid != null) unawaited(AiCreditService().rollbackCredit(uid));
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// Shared success handler for text + photo analysis.
  void _onAnalysisResult(NutritionEstimate? result, String? uid) {
    setState(() {
      _estimate = result;
      _portionFactor = 1.0;
      _isAnalyzing = false;
    });
    if (result != null) {
      unawaited(_resultAnimController.forward());
      if (uid != null) {
        unawaited(FoodAnalysisHistoryService().save(uid, result));
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _estimate = null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _analyzePhoto() async {
    final bytes = _photoBytes;
    if (bytes == null) return;
    _focusNode.unfocus();
    unawaited(HapticFeedback.lightImpact());

    final userProv = context.read<UserProvider>();
    final uid = userProv.user?.uid;
    final isPremium =
        userProv.user?.subscriptionTier.isPremiumOrAbove ?? false;
    if (uid != null) {
      final canUse = await AiCreditService().checkAndConsume(uid, isPremium);
      if (!mounted) return;
      if (!canUse) {
        unawaited(AiCreditsSheet.show(context, uid: uid, isPremium: isPremium));
        return;
      }
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _estimate = null;
    });
    _resultAnimController.reset();

    try {
      final result = await _analysisService.analyzeFoodPhoto(
        bytes,
        hint: _hintController.text,
      );
      if (!mounted) return;
      if (result == null && uid != null) {
        unawaited(AiCreditService().rollbackCredit(uid));
      }
      _onAnalysisResult(result, uid);
    } catch (e) {
      if (uid != null) unawaited(AiCreditService().rollbackCredit(uid));
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _logEstimate() async {
    final estimate = _displayEstimate;
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
    final user = context.watch<UserProvider>().user;
    final uid = user?.uid;
    final isPremium = user?.subscriptionTier.isPremiumOrAbove ?? false;

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
                onHistory: uid != null ? () => _openHistory(uid) : null,
                historyTooltip: l10n.translate('food_scan.history'),
                creditBadge: uid != null
                    ? AiCreditBadge(uid: uid, isPremium: isPremium)
                    : null,
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
                      if (_analysisService.isPhotoAvailable) ...[
                        _buildModeToggle(l10n, palette, t, primaryColor),
                        SizedBox(height: AppSpacing.md.h),
                      ],
                      (_inputMode == 'photo' &&
                              _analysisService.isPhotoAvailable)
                          ? _buildPhotoCard(l10n, palette, t, primaryColor)
                          : _buildInputCard(l10n, palette, t, primaryColor),
                      SizedBox(height: AppSpacing.md.h),
                      if (!_analysisService.isAvailable)
                        _buildNotConfiguredBanner(l10n, palette, t),
                      if (_isAnalyzing) _buildAnalyzing(l10n, palette, t),
                      if (_errorMessage != null && !_isAnalyzing)
                        AppErrorState(
                          title: l10n.translate('common.error'),
                          message: _errorMessage,
                          retryLabel: l10n.translate('food_scan.analyze_btn'),
                          onRetry:
                              _inputMode == 'photo' ? _analyzePhoto : _analyze,
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

  Widget _buildModeToggle(AppLocalizations l10n, AppPalette palette, AppText t,
      Color primaryColor) {
    Widget seg(String mode, IconData icon, String label) {
      final active = _inputMode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _inputMode = mode),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
            decoration: BoxDecoration(
              color: active ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.full.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: AppSize.iconSm.r,
                    color: active ? palette.textInverse : palette.textSecondary),
                SizedBox(width: AppSpacing.xxs.w),
                Text(label,
                    style: t.labelM.copyWith(
                        color: active
                            ? palette.textInverse
                            : palette.textSecondary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          seg('text', Icons.edit_note_rounded,
              l10n.translate('food_scan.mode_describe')),
          seg('photo', Icons.photo_camera_rounded,
              l10n.translate('food_scan.mode_photo')),
        ],
      ),
    );
  }

  Widget _buildPhotoCard(AppLocalizations l10n, AppPalette palette, AppText t,
      Color primaryColor) {
    final hasPhoto = _photoBytes != null;
    return AppGlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.memory(_photoBytes!, fit: BoxFit.cover),
              ),
            )
          else
            GestureDetector(
              onTap: () => _pickPhoto(ImageSource.camera),
              child: Container(
                height: 150.h,
                decoration: BoxDecoration(
                  color: palette.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                  border: Border.all(color: palette.glassStroke),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded,
                        size: 36.r, color: primaryColor),
                    SizedBox(height: AppSpacing.xs.h),
                    Text(l10n.translate('food_scan.photo_prompt'),
                        style: t.bodyM.copyWith(color: palette.textSecondary)),
                  ],
                ),
              ),
            ),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: l10n.translate(hasPhoto
                      ? 'food_scan.photo_retake'
                      : 'food_scan.photo_take'),
                  icon: Icons.photo_camera_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.small,
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: AppButton(
                  label: l10n.translate('food_scan.photo_choose'),
                  icon: Icons.photo_library_rounded,
                  variant: AppButtonVariant.ghost,
                  size: AppButtonSize.small,
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ],
          ),
          if (hasPhoto) ...[
            SizedBox(height: AppSpacing.sm.h),
            TextField(
              controller: _hintController,
              style: t.bodyM.copyWith(color: palette.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.translate('food_scan.photo_hint_field'),
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
            AppButton(
              label: l10n.translate('food_scan.analyze_photo_btn'),
              icon: Icons.auto_awesome_rounded,
              loading: _isAnalyzing,
              onPressed: _isAnalyzing ? null : _analyzePhoto,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openHistory(String uid) async {
    final selected = await AppSheet.show<NutritionEstimate>(
      context: context,
      title: AppLocalizations.of(context).translate('food_scan.history'),
      child: _HistorySheet(uid: uid),
    );
    if (selected != null && mounted) {
      setState(() {
        _estimate = selected;
        _portionFactor = 1.0;
        _errorMessage = null;
        _isAnalyzing = false;
      });
      _resultAnimController.reset();
      unawaited(_resultAnimController.forward());
    }
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
    final est = _displayEstimate!;
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
                // ── Health score + confidence ──
                if (est.healthScore > 0) ...[
                  SizedBox(height: AppSpacing.md.h),
                  _buildHealthScore(l10n, palette, t, est),
                ],
                // ── Micros (fiber / sugar / sodium) ──
                if (est.fiber > 0 || est.sugar > 0 || est.sodiumMg > 0) ...[
                  SizedBox(height: AppSpacing.md.h),
                  Text(l10n.translate('food_scan.micros_title'),
                      style: t.labelM
                          .copyWith(color: palette.textSecondary)),
                  SizedBox(height: AppSpacing.xs.h),
                  Row(
                    children: [
                      _microChip(l10n.translate('food_scan.fiber'),
                          '${est.fiber.toStringAsFixed(1)}g', palette, t),
                      SizedBox(width: AppSpacing.xs.w),
                      _microChip(l10n.translate('food_scan.sugar'),
                          '${est.sugar.toStringAsFixed(1)}g', palette, t),
                      SizedBox(width: AppSpacing.xs.w),
                      _microChip(l10n.translate('food_scan.sodium'),
                          '${est.sodiumMg.round()}mg', palette, t),
                    ],
                  ),
                ],
                // ── Allergen chips ──
                if (est.allergens.isNotEmpty) ...[
                  SizedBox(height: AppSpacing.md.h),
                  Text(l10n.translate('food_scan.allergens_title'),
                      style: t.labelM
                          .copyWith(color: palette.textSecondary)),
                  SizedBox(height: AppSpacing.xs.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: est.allergens
                        .map((a) => Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm.w,
                                  vertical: 3.h),
                              decoration: BoxDecoration(
                                color: palette.warning.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full.r),
                                border: Border.all(
                                    color: palette.warning
                                        .withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 12.r, color: palette.warning),
                                  SizedBox(width: 4.w),
                                  Text(a,
                                      style: t.labelS.copyWith(
                                          color: palette.warning,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ],
                // ── Portion stepper ──
                SizedBox(height: AppSpacing.lg.h),
                _buildPortionStepper(l10n, palette, t, primaryColor),
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

  Color _scoreColor(int score, AppPalette palette) {
    if (score >= 70) return palette.success;
    if (score >= 40) return palette.warning;
    return palette.error;
  }

  Widget _buildHealthScore(AppLocalizations l10n, AppPalette palette, AppText t,
      NutritionEstimate est) {
    final color = _scoreColor(est.healthScore, palette);
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44.r,
            height: 44.r,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: est.healthScore / 100,
                  strokeWidth: 4,
                  backgroundColor: color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text('${est.healthScore}',
                    style: t.labelM
                        .copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.translate('food_scan.health_score'),
                    style: t.titleM.copyWith(color: palette.textPrimary)),
                if (est.confidence > 0)
                  Text(
                    l10n
                        .translate('food_scan.confidence')
                        .replaceAll('{pct}', '${(est.confidence * 100).round()}'),
                    style: t.labelS.copyWith(color: palette.textTertiary),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _microChip(
      String label, String value, AppPalette palette, AppText t) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
        decoration: BoxDecoration(
          color: palette.surfaceVariant.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: [
            Text(value,
                style: t.labelL.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w700)),
            SizedBox(height: 2.h),
            Text(label,
                style: t.labelS.copyWith(color: palette.textTertiary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPortionStepper(AppLocalizations l10n, AppPalette palette,
      AppText t, Color primaryColor) {
    void step(double delta) {
      setState(() {
        _portionFactor = (_portionFactor + delta).clamp(0.25, 5.0);
      });
      unawaited(HapticFeedback.selectionClick());
    }

    Widget btn(IconData icon, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34.r,
            height: 34.r,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18.r, color: primaryColor),
          ),
        );

    return Row(
      children: [
        Text(l10n.translate('food_scan.portion_title'),
            style: t.titleM.copyWith(color: palette.textPrimary)),
        const Spacer(),
        btn(Icons.remove_rounded, () => step(-0.25)),
        SizedBox(width: AppSpacing.sm.w),
        Text('${_portionFactor.toStringAsFixed(2)}×',
            style: t.titleM.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.w700)),
        SizedBox(width: AppSpacing.sm.w),
        btn(Icons.add_rounded, () => step(0.25)),
      ],
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
  final Widget? creditBadge;
  final VoidCallback? onHistory;
  final String? historyTooltip;

  const _FoodScanAppBar({
    required this.palette,
    required this.primaryColor,
    required this.title,
    required this.onBack,
    required this.onBarcode,
    required this.barcodeTooltip,
    this.creditBadge,
    this.onHistory,
    this.historyTooltip,
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
                    if (creditBadge != null) ...[
                      creditBadge!,
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    if (onHistory != null)
                      IconButton(
                        icon: Icon(Icons.history_rounded,
                            color: palette.textSecondary),
                        tooltip: historyTooltip,
                        onPressed: onHistory,
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

// ─── Analysis history sheet ─────────────────────────────────────────────────

class _HistorySheet extends StatelessWidget {
  final String uid;
  const _HistorySheet({required this.uid});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return StreamBuilder<List<NutritionEstimate>>(
      stream: FoodAnalysisHistoryService().streamRecent(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: AppSkeletonList(itemCount: 4),
          );
        }
        final items = snap.data ?? const <NutritionEstimate>[];
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: AppEmptyState(
              icon: Icons.history_rounded,
              title: l10n.translate('food_scan.history_empty_title'),
              message: l10n.translate('food_scan.history_empty_msg'),
            ),
          );
        }
        return ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(height: 8.h),
          itemBuilder: (ctx, i) {
            final e = items[i];
            return AppCard(
              padding: const EdgeInsets.all(12),
              onTap: () => Navigator.of(context).pop(e),
              child: Row(
                children: [
                  Icon(
                    e.fromPhoto
                        ? Icons.photo_camera_rounded
                        : Icons.edit_note_rounded,
                    size: 18.r,
                    color: palette.textTertiary,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      e.foodName.isEmpty ? '—' : e.foodName,
                      style: t.bodyM.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text('${e.calories.round()} kcal',
                      style: t.labelM.copyWith(color: palette.calories)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
