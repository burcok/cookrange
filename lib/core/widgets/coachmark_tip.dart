import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// A one-time tooltip-style coachmark widget.
///
/// Shown once per install, gated by a [SharedPreferences] boolean keyed on
/// [prefKey]. Dismisses on tap and never shows again after the user acts.
///
/// Place directly below the UI element you want to annotate.
class CoachmarkTip extends StatefulWidget {
  /// Unique per-tip key stored in SharedPreferences, e.g. `'coachmark_ring'`.
  final String prefKey;
  final String title;
  final String body;
  final AlignmentGeometry alignment;

  const CoachmarkTip({
    super.key,
    required this.prefKey,
    required this.title,
    required this.body,
    this.alignment = Alignment.bottomCenter,
  });

  @override
  State<CoachmarkTip> createState() => _CoachmarkTipState();
}

class _CoachmarkTipState extends State<CoachmarkTip> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _checkShouldShow();
  }

  Future<void> _checkShouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (prefs.getBool(widget.prefKey) != true) {
      setState(() => _visible = true);
    }
  }

  void _dismiss() {
    setState(() => _visible = false);
    SharedPreferences.getInstance()
        .then((p) => p.setBool(widget.prefKey, true));
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: reduceMotion ? Duration.zero : AppMotion.normal,
      child: _visible
          ? GestureDetector(
              onTap: _dismiss,
              child: Container(
                margin: EdgeInsets.all(AppSpacing.xs.r),
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.card.r),
                  border: Border.all(color: palette.border),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: t.labelM.copyWith(
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        Semantics(
                          label: AppLocalizations.of(context)
                              .translate('coachmark.dismiss_tip'),
                          button: true,
                          child: Icon(
                            Icons.close_rounded,
                            size: AppSize.iconSm.r,
                            color: palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      widget.body,
                      style: t.bodyM.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
