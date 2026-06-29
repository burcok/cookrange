import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/ds/ds.dart';
import 'package:provider/provider.dart';
import '../consent_center_screen.dart';

/// A one-time, first-run nudge that points users to the Consent Center to make
/// informed, explicit privacy choices. It does NOT grant any consent itself —
/// consent must be given explicitly per purpose (KVKK/GDPR: no bundled/implied
/// consent). Shown once, gated by SharedPreferences.
class ConsentPromptSheet {
  ConsentPromptSheet._();

  static const _prefKey = 'consent_prompt_seen';

  /// Shows the prompt once (ever). Safe to call on every app launch.
  static Future<void> maybeShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) ?? false) return;
    await prefs.setBool(_prefKey, true);
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    await AppSheet.show<void>(
      context: context,
      title: l10n.translate('consent.prompt_title'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 64.r,
            height: 64.r,
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_rounded, color: primary, size: 32.sp),
          ),
          Text(
            l10n.translate('consent.prompt_body'),
            style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 22.h),
          AppButton(
            label: l10n.translate('consent.prompt_manage'),
            icon: Icons.tune_rounded,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ConsentCenterScreen(),
              ));
            },
          ),
          SizedBox(height: 8.h),
          AppButton(
            label: l10n.translate('consent.prompt_later'),
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
