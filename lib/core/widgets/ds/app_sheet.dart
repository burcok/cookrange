import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_dimensions.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// Cookrange Design System — modern bottom sheet.
///
/// Rounded top, drag handle, blurred scrim, safe-area aware, optional title row.
/// Use [AppSheet.show] instead of calling `showModalBottomSheet` directly so
/// every sheet in the app looks and animates the same (Rule R7).
class AppSheet {
  AppSheet._();

  // Smooth enter (350ms) / exit (260ms) — no bounce, no lag.
  static const _enterCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const _exitCurve = Cubic(0.5, 0.0, 1.0, 1.0);

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
    bool showHandle = true,
    EdgeInsetsGeometry? padding,
  }) {
    final palette = AppPalette.of(context);
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: Colors.transparent,
      barrierColor: palette.scrim,
      sheetAnimationStyle: const AnimationStyle(
        curve: _enterCurve,
        duration: Duration(milliseconds: 350),
        reverseCurve: _exitCurve,
        reverseDuration: Duration(milliseconds: 260),
      ),
      builder: (ctx) => _SheetShell(
        title: title,
        showHandle: showHandle,
        padding: padding,
        child: child,
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showHandle;
  final EdgeInsetsGeometry? padding;

  const _SheetShell({
    required this.child,
    this.title,
    this.showHandle = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet.r)),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.2),
            blurRadius: AppElevation.blurLg.r,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Material(
        color: palette.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet.r)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHandle)
                  Container(
                    width: AppSize.sheetHandleW.w,
                    height: AppSize.sheetHandleH.h,
                    margin: EdgeInsets.only(
                        top: AppSpacing.sm.h, bottom: AppSpacing.xs.h),
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                if (title != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.xl.w,
                        AppSpacing.sm.h, AppSpacing.xl.w, 0),
                    child: Row(
                      children: [
                        Expanded(child: Text(title!, style: t.headlineS)),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close_rounded,
                              color: palette.textSecondary,
                              size: AppSize.iconMd.r),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                Flexible(
                  child: Padding(
                    padding: padding ??
                        EdgeInsets.fromLTRB(AppSpacing.xl.w, AppSpacing.md.h,
                            AppSpacing.xl.w, AppSpacing.xl.h),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
