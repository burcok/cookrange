import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_config_model.dart';
import '../providers/language_provider.dart';
import '../services/app_config_service.dart';
import '../utils/safe_url_launcher.dart';
import 'ds/ds.dart';

/// Thin, reactive announcement strip driven by the remote [AppConfig].
///
/// - Reacts live to config refreshes via [AppConfigService.notifier].
/// - Color reflects `announcement.type` (info / warning / success).
/// - Dismissible announcements remember the dismissal per-id in SharedPrefs
///   (`announcement_dismissed_<id>`) so they don't reappear.
/// - A `ctaUrl` makes the whole banner tappable (safe-launched).
///
/// Renders `SizedBox.shrink()` when there's nothing to show — safe to drop at
/// the top of any Scaffold body.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  /// Ids the user dismissed (loaded from prefs, plus this session's dismissals).
  final Set<String> _dismissed = {};
  bool _prefsLoaded = false;

  static const _prefix = 'announcement_dismissed_';

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_prefix));
      for (final k in keys) {
        if (prefs.getBool(k) == true) {
          _dismissed.add(k.substring(_prefix.length));
        }
      }
    } catch (_) {
      // Fail-open: if prefs can't load, we just show the banner.
    }
    if (mounted) setState(() => _prefsLoaded = true);
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissed.add(id));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix$id', true);
    } catch (_) {}
  }

  Color _accent(AppPalette palette, String type) {
    switch (type) {
      case 'warning':
        return palette.warning;
      case 'success':
        return palette.success;
      case 'info':
      default:
        return palette.info;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'success':
        return Icons.check_circle_outline_rounded;
      case 'info':
      default:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_prefsLoaded) return const SizedBox.shrink();

    return ValueListenableBuilder<AppConfig>(
      valueListenable: AppConfigService().notifier,
      builder: (context, config, _) {
        final a = config.announcement;
        if (!a.enabled) return const SizedBox.shrink();
        if (a.dismissible && a.id.isNotEmpty && _dismissed.contains(a.id)) {
          return const SizedBox.shrink();
        }

        final locale =
            context.watch<LanguageProvider>().currentLocale.languageCode;
        final text = a.message.resolve(locale);
        if (text.isEmpty) return const SizedBox.shrink();

        final palette = AppPalette.of(context);
        final t = AppText.of(context);
        final accent = _accent(palette, a.type);
        final hasCta = a.ctaUrl.isNotEmpty;

        final banner = Container(
          margin: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.sm.h),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: palette.isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
                color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(_icon(a.type), color: accent, size: 20.r),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Text(
                  text,
                  style: t.labelM.copyWith(color: palette.textPrimary),
                ),
              ),
              if (hasCta) ...[
                SizedBox(width: AppSpacing.xs.w),
                Icon(Icons.chevron_right_rounded,
                    color: accent, size: 20.r),
              ],
              if (a.dismissible) ...[
                SizedBox(width: AppSpacing.xs.w),
                GestureDetector(
                  onTap: () => _dismiss(a.id),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xs.r),
                    child: Icon(Icons.close_rounded,
                        color: palette.textSecondary, size: 18.r),
                  ),
                ),
              ],
            ],
          ),
        );

        if (!hasCta) return banner;

        return GestureDetector(
          onTap: () => safeLaunchUrl(a.ctaUrl),
          behavior: HitTestBehavior.opaque,
          child: banner,
        );
      },
    );
  }
}
