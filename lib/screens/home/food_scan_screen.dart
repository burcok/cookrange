import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/food_analysis_service.dart';
import '../../core/services/food_log_service.dart';

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

  late AnimationController _resultAnimController;
  late Animation<double> _resultFade;
  late Animation<Offset> _resultSlide;

  @override
  void initState() {
    super.initState();
    _resultAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _resultFade = CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.easeOut,
    );
    _resultSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _resultAnimController,
      curve: Curves.easeOut,
    ));
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
      if (result != null) {
        unawaited(_resultAnimController.forward());
      }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFFCFBF9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          l10n.translate('food_scan.title'),
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF2E3A59),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white70 : const Color(0xFF2E3A59)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.translate('food_scan.subtitle'),
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
            SizedBox(height: 20.h),
            _buildInputCard(context, isDark, primary, l10n),
            SizedBox(height: 16.h),
            if (!_analysisService.isAvailable) _buildNotConfiguredBanner(isDark, l10n),
            if (_errorMessage != null) _buildErrorBanner(isDark),
            if (_isAnalyzing) _buildAnalyzingIndicator(primary, l10n),
            if (_estimate != null) ...[
              SlideTransition(
                position: _resultSlide,
                child: FadeTransition(
                  opacity: _resultFade,
                  child: _buildResultCard(context, isDark, primary, l10n),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputCard(BuildContext context, bool isDark, Color primary,
      AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2332) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: 3,
            minLines: 2,
            style: TextStyle(
              fontSize: 15.sp,
              color: isDark ? Colors.white : const Color(0xFF2E3A59),
            ),
            decoration: InputDecoration(
              hintText: l10n.translate('food_scan.input_hint'),
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey[400],
                fontSize: 14.sp,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: primary, width: 2),
              ),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
            ),
          ),
          SizedBox(height: 12.h),
          ElevatedButton.icon(
            onPressed:
                (_isAnalyzing || !_analysisService.isAvailable) ? null : _analyze,
            icon: _isAnalyzing
                ? SizedBox(
                    width: 16.w,
                    height: 16.h,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(
              _isAnalyzing
                  ? l10n.translate('food_scan.analyzing')
                  : l10n.translate('food_scan.analyze_btn'),
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primary.withValues(alpha: 0.4),
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfiguredBanner(bool isDark, AppLocalizations l10n) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              l10n.translate('food_scan.not_configured'),
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzingIndicator(Color primary, AppLocalizations l10n) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Column(
        children: [
          CircularProgressIndicator(color: primary),
          SizedBox(height: 12.h),
          Text(
            l10n.translate('food_scan.analyzing'),
            style: TextStyle(
              fontSize: 14.sp,
              color: primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, bool isDark, Color primary,
      AppLocalizations l10n) {
    final est = _estimate!;
    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2332) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 16.r,
            offset: Offset(0, 6.h),
          ),
        ],
        border: Border.all(
          color: primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(Icons.restaurant_menu, color: primary, size: 20),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      est.foodName,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2E3A59),
                      ),
                    ),
                    if (est.servingSize.isNotEmpty)
                      Text(
                        est.servingSize,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? Colors.white54 : Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '${est.calories.toInt()} kcal',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              _macroChip(l10n.translate('food_scan.protein'),
                  est.protein, Colors.blue, isDark),
              SizedBox(width: 8.w),
              _macroChip(l10n.translate('food_scan.carbs'),
                  est.carbs, Colors.orange, isDark),
              SizedBox(width: 8.w),
              _macroChip(l10n.translate('food_scan.fat'),
                  est.fat, Colors.purple, isDark),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            l10n.translate('food_scan.meal_type_label'),
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.grey[700],
            ),
          ),
          SizedBox(height: 10.h),
          _buildMealTypeSelector(isDark, primary, l10n),
          SizedBox(height: 16.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLogging ? null : _logEstimate,
              icon: _isLogging
                  ? SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                l10n.translate('food_scan.log_btn'),
                style:
                    TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primary.withValues(alpha: 0.4),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroChip(
      String label, double value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.2 : 0.08),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Text(
              '${value.toInt()}g',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTypeSelector(
      bool isDark, Color primary, AppLocalizations l10n) {
    final types = [
      ('breakfast', l10n.translate('food_scan.meal.breakfast'), Icons.wb_sunny_outlined),
      ('lunch', l10n.translate('food_scan.meal.lunch'), Icons.lunch_dining_outlined),
      ('dinner', l10n.translate('food_scan.meal.dinner'), Icons.dinner_dining_outlined),
      ('snack', l10n.translate('food_scan.meal.snack'), Icons.apple_outlined),
    ];

    return Row(
      children: types.map((t) {
        final isSelected = _selectedMealType == t.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMealType = t.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: t.$1 != 'snack' ? 6.w : 0),
              padding: EdgeInsets.symmetric(vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected
                    ? primary
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: isSelected ? primary : Colors.transparent,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    t.$3,
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white54 : Colors.grey[600]),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    t.$2,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white54 : Colors.grey[600]),
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
