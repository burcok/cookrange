import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/barcode_lookup_service.dart';
import '../../core/services/food_log_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/services/permission_service.dart';
import '../../core/widgets/ds/ds.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen>
    with SingleTickerProviderStateMixin {
  final _lookupService = BarcodeLookupService();
  final _logService = FoodLogService();
  // Initialized lazily after camera permission is confirmed to avoid
  // MobileScannerController accessing camera hardware before the OS grant.
  MobileScannerController? _cameraCtrl;

  bool _isLookingUp = false;
  bool _hasResult = false;
  BarcodeProduct? _product;
  String? _errorMessage;
  String _selectedMealType = 'snack';
  double _servingG = 100;
  bool _isLogging = false;
  bool _cameraReady = false;

  // Scanning animation
  late final AnimationController _lineAnim;
  late final Animation<double> _linePos;

  @override
  void initState() {
    super.initState();
    _lineAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _linePos = CurvedAnimation(parent: _lineAnim, curve: Curves.easeInOut);
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestCamera());
  }

  Future<void> _requestCamera() async {
    // Check permission without the PermissionService primer — the scanner UI
    // itself communicates why the camera is needed. This avoids the primer
    // sheet/OS-dialog double-modal race that caused spurious `pop()` calls.
    var status = await Permission.camera.status;
    if (!mounted) return;

    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.camera.request();
    }
    if (!mounted) return;

    if (status.isGranted) {
      setState(() {
        _cameraCtrl = MobileScannerController(
          detectionSpeed: DetectionSpeed.noDuplicates,
        );
        _cameraReady = true;
      });
    } else if (status.isPermanentlyDenied) {
      unawaited(PermissionService().requestCamera(context)); // shows settings sheet
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _lineAnim.dispose();
    _cameraCtrl?.dispose();
    super.dispose();
  }

  Future<void> _onBarcodeDetected(BarcodeCapture capture) async {
    if (_isLookingUp || _hasResult) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;

    unawaited(HapticFeedback.mediumImpact());
    await _cameraCtrl?.stop();

    setState(() {
      _isLookingUp = true;
      _errorMessage = null;
    });

    try {
      final product = await _lookupService.lookupBarcode(code);
      if (!mounted) return;
      setState(() {
        _product = product;
        _servingG = product.servingSizeG;
        _isLookingUp = false;
        _hasResult = true;
      });
    } on BarcodeNotFoundError {
      if (!mounted) return;
      setState(() {
        _isLookingUp = false;
        _errorMessage = null; // Show "not found" state, not generic error
      });
      _showNotFoundSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLookingUp = false;
        _errorMessage = e.toString();
      });
      // Resume scanning after error
      unawaited(_cameraCtrl?.start());
    }
  }

  void _showNotFoundSheet() {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    AppSheet.show(
      context: context,
      title: l10n.translate('barcode.not_found_title'),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl.w, vertical: AppSpacing.md.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_off_rounded,
                  size: 32.r, color: palette.warning),
            ),
            SizedBox(height: AppSpacing.lg.h),
            Text(
              l10n.translate('barcode.not_found_body'),
              style: t.bodyM.copyWith(
                  color: palette.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.xl.h),
            AppButton(
              label: l10n.translate('barcode.scan_again'),
              variant: AppButtonVariant.secondary,
              onPressed: () {
                Navigator.pop(context);
                _resetScan();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _hasResult = false;
      _product = null;
      _errorMessage = null;
      _isLookingUp = false;
    });
    unawaited(_cameraCtrl?.start());
  }

  Future<void> _log() async {
    final product = _product;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (product == null || uid == null) return;

    setState(() => _isLogging = true);
    try {
      await _logService.logBarcodeFood(
        userId: uid,
        mealType: _selectedMealType,
        product: product,
        customServingG: _servingG,
      );
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLogging = false);
      AppSnackBar.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view — only mounted after permission granted
          if (!_hasResult && _cameraReady)
            MobileScanner(
              controller: _cameraCtrl!,
              onDetect: _onBarcodeDetected,
            ),
          if (!_hasResult && !_cameraReady)
            const Center(child: SizedBox.shrink()),
          if (_hasResult)
            Container(color: palette.background),

          // Scanning overlay (only when actively scanning)
          if (!_hasResult && !_isLookingUp)
            _buildScanOverlay(l10n, palette, t, primary),

          // Looking-up overlay
          if (_isLookingUp)
            _buildLookingUpOverlay(l10n, palette, t),

          // Result card (slides up)
          if (_hasResult && _product != null)
            Positioned.fill(
              child: _buildResultView(l10n, palette, t, primary),
            ),

          // Error banner
          if (_errorMessage != null)
            Positioned(
              bottom: 120.h,
              left: AppSpacing.xl.w,
              right: AppSpacing.xl.w,
              child: AppErrorState(
                title: l10n.translate('common.error'),
                message: _errorMessage,
                retryLabel: l10n.translate('barcode.scan_again'),
                onRetry: _resetScan,
                compact: true,
              ),
            ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
              child: Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  // Torch toggle (only when scanning)
                  if (!_hasResult && !_isLookingUp)
                    GestureDetector(
                      onTap: () => unawaited(_cameraCtrl?.toggleTorch()),
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.flashlight_on_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  // Reset button (when result shown)
                  if (_hasResult)
                    GestureDetector(
                      onTap: _resetScan,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 12.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: palette.surfaceVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.qr_code_scanner_rounded,
                                size: 14.r, color: palette.textPrimary),
                            SizedBox(width: 4.w),
                            Text(
                              l10n.translate('barcode.scan_again'),
                              style: t.labelS.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
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

  Widget _buildScanOverlay(
    AppLocalizations l10n,
    AppPalette palette,
    AppText t,
    Color primary,
  ) {
    final screenW = MediaQuery.of(context).size.width;
    final boxSize = screenW * 0.72;

    return Column(
      children: [
        const Spacer(flex: 2),
        Center(
          child: SizedBox(
            width: boxSize,
            height: boxSize,
            child: Stack(
              children: [
                // Dark vignette corners
                CustomPaint(
                  painter: _ScanFramePainter(primary),
                  child: Container(),
                ),
                // Animated scanning line
                AnimatedBuilder(
                  animation: _linePos,
                  builder: (_, __) {
                    return Positioned(
                      top: _linePos.value * (boxSize - 4),
                      left: 12,
                      right: 12,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primary.withValues(alpha: 0),
                              primary,
                              primary.withValues(alpha: 0),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        Text(
          l10n.translate('barcode.scan_hint'),
          style: t.bodyM.copyWith(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _buildLookingUpOverlay(
      AppLocalizations l10n, AppPalette palette, AppText t) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppShimmer(
              child: Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),
            Text(
              l10n.translate('barcode.looking_up'),
              style: t.bodyM.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(
    AppLocalizations l10n,
    AppPalette palette,
    AppText t,
    Color primary,
  ) {
    final product = _product!;
    final effectiveCal = product.calories * (_servingG / 100);
    final effectiveP = product.protein * (_servingG / 100);
    final effectiveC = product.carbs * (_servingG / 100);
    final effectiveF = product.fat * (_servingG / 100);

    final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl.w,
        MediaQuery.of(context).padding.top + 60.h,
        AppSpacing.xl.w,
        AppSpacing.xl.h + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product card
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (product.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm.r),
                        child: Image.network(
                          product.imageUrl!,
                          width: 64.w,
                          height: 64.w,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 64.w,
                            height: 64.w,
                            color: palette.surfaceVariant,
                            child: Icon(Icons.inventory_2_outlined,
                                size: 28.r, color: palette.textTertiary),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md.w),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: t.titleL.copyWith(
                                fontWeight: FontWeight.bold,
                                color: palette.textPrimary),
                            maxLines: 2,
                          ),
                          if (product.brand != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              product.brand!,
                              style: t.labelS
                                  .copyWith(color: palette.textTertiary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg.h),

                // Serving size slider
                Text(
                  l10n.translate('barcode.serving_label'),
                  style: t.labelL.copyWith(
                      color: palette.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
                SizedBox(height: AppSpacing.xs.h),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 8),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 16),
                          activeTrackColor: primary,
                          inactiveTrackColor:
                              primary.withValues(alpha: 0.2),
                          thumbColor: primary,
                          overlayColor: primary.withValues(alpha: 0.15),
                        ),
                        child: Slider(
                          value: _servingG.clamp(10, 500),
                          min: 10,
                          max: 500,
                          divisions: 49,
                          onChanged: (v) =>
                              setState(() => _servingG = v.roundToDouble()),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 56.w,
                      child: Text(
                        '${_servingG.toInt()}g',
                        style: t.labelL.copyWith(
                            color: primary, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.lg.h),

                // Macro chips
                Row(
                  children: [
                    _MacroChip(
                        label: l10n.translate('barcode.macro_cal'),
                        value: effectiveCal.toStringAsFixed(0),
                        unit: 'kcal',
                        color: palette.calories,
                        t: t),
                    SizedBox(width: AppSpacing.xs.w),
                    _MacroChip(
                        label: l10n.translate('barcode.macro_protein'),
                        value: effectiveP.toStringAsFixed(1),
                        unit: 'g',
                        color: palette.protein,
                        t: t),
                    SizedBox(width: AppSpacing.xs.w),
                    _MacroChip(
                        label: l10n.translate('barcode.macro_carbs'),
                        value: effectiveC.toStringAsFixed(1),
                        unit: 'g',
                        color: palette.carbs,
                        t: t),
                    SizedBox(width: AppSpacing.xs.w),
                    _MacroChip(
                        label: l10n.translate('barcode.macro_fat'),
                        value: effectiveF.toStringAsFixed(1),
                        unit: 'g',
                        color: palette.fat,
                        t: t),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),

          // Meal type selector
          Text(
            l10n.translate('barcode.meal_type_label'),
            style: t.labelL.copyWith(
                color: palette.textSecondary, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            children: mealTypes.map((mt) {
              final isSelected = mt == _selectedMealType;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: mt != mealTypes.last ? 6.w : 0),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedMealType = mt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? primary.withValues(alpha: 0.15)
                            : palette.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppRadius.sm.r),
                        border: Border.all(
                          color: isSelected
                              ? primary
                              : palette.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        l10n.translate('food_scan.meal.$mt'),
                        style: t.labelS.copyWith(
                          color: isSelected
                              ? primary
                              : palette.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: AppSpacing.xl.h),

          // Log button
          AppButton(
            label: l10n.translate('barcode.log_btn'),
            loading: _isLogging,
            onPressed: _log,
          ),
        ],
      ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;
  final AppText t;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: t.labelS.copyWith(
                  color: palette.textTertiary, fontSize: 9.sp),
              maxLines: 1,
            ),
            SizedBox(height: 2.h),
            Text(
              '$value$unit',
              style: t.labelM.copyWith(
                  color: color, fontWeight: FontWeight.w700),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws corner brackets for the scan frame.
class _ScanFramePainter extends CustomPainter {
  final Color color;
  _ScanFramePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final len = size.width * 0.14;
    const r = 8.0;

    // Top-left
    canvas.drawLine(Offset(r, len + r), const Offset(r, r), paint);
    canvas.drawLine(const Offset(r, r), Offset(len + r, r), paint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - r, r), Offset(size.width - len - r, r), paint);
    canvas.drawLine(
        Offset(size.width - r, r), Offset(size.width - r, len + r), paint);
    // Bottom-left
    canvas.drawLine(
        Offset(r, size.height - r), Offset(len + r, size.height - r), paint);
    canvas.drawLine(Offset(r, size.height - len - r),
        Offset(r, size.height - r), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - len - r, size.height - r),
        Offset(size.width - r, size.height - r), paint);
    canvas.drawLine(Offset(size.width - r, size.height - len - r),
        Offset(size.width - r, size.height - r), paint);
  }

  @override
  bool shouldRepaint(_ScanFramePainter old) => old.color != color;
}
