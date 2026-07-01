import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/app_config_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Full-screen maintenance wall. Shown by [RouteGuard] whenever the admin flips
/// `maintenance.enabled`. "Try again" re-fetches the remote config; when
/// maintenance is lifted the gate falls away and the app resumes.
class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await AppConfigService().refresh();
    if (!mounted) return;
    // Rebuild regardless: if maintenance is now off, RouteGuard's notifier
    // rebuild will already have swapped this screen out on the next frame.
    setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final locale = context.watch<LanguageProvider>().currentLocale.languageCode;

    final custom =
        AppConfigService().config.maintenance.message.resolve(locale);
    final message = custom.isNotEmpty
        ? custom
        : l10n.translate('maintenance.default_message');

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
                    Icons.build_rounded,
                    color: primary,
                    size: 44.r,
                  ),
                ),
                SizedBox(height: AppSpacing.lg.h),
                Text(
                  l10n.translate('maintenance.title'),
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
                  label: l10n.translate('maintenance.retry'),
                  icon: Icons.refresh_rounded,
                  loading: _retrying,
                  onPressed: _retry,
                  variant: AppButtonVariant.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
