import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Shared weight-logging bottom sheet (local Hive storage via StorageService).
///
/// Used by the home TrackingCard and the profile completeness card so a single
/// implementation handles input, recent history, and persistence. Opening the
/// sheet never pops the host screen.
class WeightLogSheet extends StatelessWidget {
  final double? initialWeight;
  final List<dynamic> weightHistory;
  final Future<void> Function(double) onSave;

  const WeightLogSheet._({
    required this.initialWeight,
    required this.weightHistory,
    required this.onSave,
  });

  /// Opens the weight sheet. [onSaved] fires after a successful save so the
  /// caller can refresh local state. Returns true when a weight was saved.
  static Future<bool> show(
    BuildContext context, {
    VoidCallback? onSaved,
  }) async {
    final l10n = AppLocalizations.of(context);
    final storage = StorageService();
    final today = DateTime.now();
    var saved = false;

    await AppSheet.show(
      context: context,
      title: l10n.translate('tracking.weight.log_title'),
      child: WeightLogSheet._(
        initialWeight: storage.getWeight(today),
        weightHistory: storage.getWeightHistory().take(7).toList(),
        onSave: (val) async {
          await storage.saveWeight(DateTime.now(), val);
          saved = true;
          onSaved?.call();
        },
      ),
    );
    return saved;
  }

  @override
  Widget build(BuildContext context) {
    return _WeightInputBody(
      initialWeight: initialWeight,
      weightHistory: weightHistory,
      onSave: onSave,
    );
  }
}

class _WeightInputBody extends StatefulWidget {
  final double? initialWeight;
  final List<dynamic> weightHistory;
  final Future<void> Function(double) onSave;

  const _WeightInputBody({
    required this.initialWeight,
    required this.weightHistory,
    required this.onSave,
  });

  @override
  State<_WeightInputBody> createState() => _WeightInputBodyState();
}

class _WeightInputBodyState extends State<_WeightInputBody> {
  late final TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialWeight?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          cursorColor: primary,
          style: t.bodyL.copyWith(color: palette.textPrimary),
          decoration: InputDecoration(
            labelText: l10n.translate('tracking.weight.field_label'),
            labelStyle: TextStyle(color: palette.textSecondary),
            suffixText: 'kg',
            suffixStyle: t.bodyL.copyWith(color: palette.textSecondary),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              borderSide: BorderSide(color: primary, width: 2),
            ),
            filled: true,
            fillColor: palette.surfaceVariant.withValues(alpha: 0.5),
            contentPadding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xl.w, vertical: AppSpacing.md.h),
          ),
        ),
        if (widget.weightHistory.isNotEmpty) ...[
          SizedBox(height: AppSpacing.lg.h),
          Text(
            l10n.translate('tracking.weight.recent'),
            style: t.labelM.copyWith(
                fontWeight: FontWeight.w600, color: palette.textSecondary),
          ),
          SizedBox(height: AppSpacing.xs.h),
          ...widget.weightHistory.take(5).map(
                (e) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 5.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e['date'] as String,
                          style:
                              t.labelS.copyWith(color: palette.textSecondary)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppRadius.xs.r),
                        ),
                        child: Text('${e['weight']} kg',
                            style: t.labelS.copyWith(
                                fontWeight: FontWeight.w700, color: primary)),
                      ),
                    ],
                  ),
                ),
              ),
        ],
        SizedBox(height: AppSpacing.xl.h),
        AppButton(
          label: l10n.translate('common.save'),
          loading: _isSaving,
          onPressed: _isSaving
              ? null
              : () async {
                  final val = double.tryParse(_controller.text.trim());
                  if (val == null || val <= 0) return;
                  final nav = Navigator.of(context);
                  setState(() => _isSaving = true);
                  await widget.onSave(val);
                  if (!mounted) return;
                  nav.pop();
                },
        ),
      ],
    );
  }
}
