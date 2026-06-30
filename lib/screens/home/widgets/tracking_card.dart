import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/ds/ds.dart';
import 'weight_log_sheet.dart';

/// Combined hydration + weight tracking card for the home screen.
/// Uses local Hive storage (StorageService) — no Firestore dependency.
class TrackingCard extends StatefulWidget {
  const TrackingCard({super.key});

  @override
  State<TrackingCard> createState() => _TrackingCardState();
}

class _TrackingCardState extends State<TrackingCard> {
  final StorageService _storage = StorageService();
  static const double _goalMl = 2000;
  static const double _stepMl = 250;

  double _todayMl = 0;
  double? _todayWeight;
  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final today = DateTime.now();
    setState(() {
      _todayMl = _storage.getHydration(today);
      _todayWeight = _storage.getWeight(today);
      _weightHistory = _storage.getWeightHistory().take(7).toList();
    });
  }

  Future<void> _addWater() async {
    final today = DateTime.now();
    final next = (_todayMl + _stepMl).clamp(0.0, _goalMl);
    await _storage.saveHydration(today, next);
    unawaited(HapticFeedback.selectionClick());
    setState(() => _todayMl = next);
  }

  Future<void> _removeWater() async {
    final today = DateTime.now();
    final next = (_todayMl - _stepMl).clamp(0.0, double.infinity);
    await _storage.saveHydration(today, next);
    unawaited(HapticFeedback.selectionClick());
    setState(() => _todayMl = next);
  }

  Future<void> _showWeightDialog() async {
    await WeightLogSheet.show(context, onSaved: _load);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final fraction = (_todayMl / _goalMl).clamp(0.0, 1.0);
    final glasses = (_todayMl / 250).round();

    return AppCard(
      padding: EdgeInsets.all(AppSpacing.xl.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hydration section
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs.r),
                decoration: BoxDecoration(
                  color: palette.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                ),
                child: Icon(Icons.water_drop_rounded,
                    color: palette.info, size: AppSize.iconSm),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                l10n.translate('tracking.hydration.title'),
                style:
                    t.labelL.copyWith(fontWeight: FontWeight.bold, color: palette.textPrimary),
              ),
              const Spacer(),
              Text(
                '$glasses ${l10n.translate('tracking.hydration.glasses')} · ${_todayMl.round()} ml',
                style: t.labelS.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: AppMotion.normal,
              curve: AppMotion.standard,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 8,
                backgroundColor: palette.surfaceVariant,
                valueColor: AlwaysStoppedAnimation<Color>(palette.info),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(_goalMl - _todayMl).clamp(0, _goalMl).round()} ml ${l10n.translate('tracking.hydration.remaining')}',
                style: t.labelS.copyWith(color: palette.textTertiary),
              ),
              Row(
                children: [
                  _iconBtn(
                    context: context,
                    icon: Icons.remove_rounded,
                    color: palette.info,
                    palette: palette,
                    onTap: _todayMl > 0 ? _removeWater : null,
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  _iconBtn(
                    context: context,
                    icon: Icons.add_rounded,
                    color: palette.info,
                    palette: palette,
                    onTap: _todayMl < _goalMl ? _addWater : null,
                    label: '+250ml',
                  ),
                ],
              ),
            ],
          ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
            child: Divider(height: 1, color: palette.divider),
          ),

          // Weight section
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs.r),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm.r),
                ),
                child: Icon(Icons.monitor_weight_rounded,
                    color: primary, size: AppSize.iconSm),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                l10n.translate('tracking.weight.title'),
                style:
                    t.labelL.copyWith(fontWeight: FontWeight.bold, color: palette.textPrimary),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showWeightDialog,
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
                  decoration: BoxDecoration(
                    color: _todayWeight != null
                        ? primary.withValues(alpha: 0.1)
                        : primary,
                    borderRadius: BorderRadius.circular(AppRadius.full.r),
                  ),
                  child: Text(
                    _todayWeight != null
                        ? '${_todayWeight!.toStringAsFixed(1)} kg'
                        : l10n.translate('tracking.weight.log'),
                    style: t.labelM.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _todayWeight != null ? primary : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_weightHistory.length > 1) ...[
            SizedBox(height: AppSpacing.sm.h),
            _buildWeightMiniChart(primary, palette),
          ],
        ],
      ),
    );
  }

  Widget _buildWeightMiniChart(Color primary, AppPalette palette) {
    final entries = _weightHistory.reversed.toList();
    if (entries.length < 2) return const SizedBox.shrink();

    final weights = entries.map((e) => (e['weight'] as double)).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final range = (maxW - minW).clamp(0.5, double.infinity);

    return SizedBox(
      height: 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: weights.map((w) {
          final frac = (maxW - minW) < 0.1
              ? 0.5
              : ((w - minW) / range).clamp(0.1, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Tooltip(
                message: '${w.toStringAsFixed(1)} kg',
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: 36 * frac,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xs)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _iconBtn({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required AppPalette palette,
    VoidCallback? onTap,
    String? label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: label != null
            ? EdgeInsets.symmetric(
                horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h)
            : EdgeInsets.all(AppSpacing.xxs.r),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withValues(alpha: 0.12)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.sm.r),
        ),
        child: label != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: onTap != null ? color : palette.textTertiary,
                      size: AppSize.iconXs),
                  SizedBox(width: AppSpacing.xxs.w),
                  Text(
                    label,
                    style: AppText.of(context).labelS.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onTap != null ? color : palette.textTertiary,
                        ),
                  ),
                ],
              )
            : Icon(icon,
                color: onTap != null ? color : palette.textTertiary,
                size: AppSize.iconSm),
      ),
    );
  }
}
