import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/app_config_service.dart';
import '../../core/utils/safe_url_launcher.dart';
import '../../core/utils/version_gate.dart';
import '../../core/widgets/ds/ds.dart';

/// Full-screen, NON-DISMISSIBLE hard update gate. Shown by [RouteGuard] when the
/// running build is below the platform minimum supported version and the admin
/// has flipped `force_update` on. The only way forward is the store.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _openStore(BuildContext context) async {
    final config = AppConfigService().config;
    final url = VersionGate.storeUrl(config);
    if (url.isEmpty) return;
    await safeLaunchUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final locale = context.watch<LanguageProvider>().currentLocale.languageCode;
    final config = AppConfigService().config;

    final custom = config.version.updateMessage.resolve(locale);
    final message =
        custom.isNotEmpty ? custom : l10n.translate('update.force_message');

    // Block Android back button — this gate must not be escapable.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl.r),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96.r,
                  height: 96.r,
                  decoration: BoxDecoration(
                    color: primary.withValues(
                        alpha: palette.isDark ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.system_update_rounded,
                    color: primary,
                    size: 44.r,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  l10n.translate('update.force_title'),
                  textAlign: TextAlign.center,
                  style: t.headlineS,
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: t.bodyM.copyWith(color: palette.textSecondary),
                ),
                SizedBox(height: AppSpacing.xxl.h),
                AppButton(
                  label: l10n.translate('update.update_button'),
                  icon: Icons.open_in_new_rounded,
                  onPressed: () => _openStore(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
