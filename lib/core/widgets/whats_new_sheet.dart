import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../localization/app_localizations.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'ds/app_button.dart';
import 'ds/app_sheet.dart';

/// Shows a branded "What's New" bottom sheet with the 5 latest release highlights.
///
/// Call [WhatsNewSheetContent.show] from a post-frame callback — it fetches the
/// current version from [PackageInfo] before presenting the sheet.
class WhatsNewSheetContent extends StatelessWidget {
  final String version;

  const WhatsNewSheetContent({super.key, required this.version});

  // ── Static entry-point ────────────────────────────────────────────────────

  /// Fetches the current app version then opens the sheet via [AppSheet.show].
  static Future<void> show(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    await AppSheet.show<void>(
      context: context,
      title: AppLocalizations.of(context).translate('whats_new.title'),
      child: WhatsNewSheetContent(version: info.version),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    final items = _changeItems(l10n, palette);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Version chip
        Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
          decoration: BoxDecoration(
            color: palette.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.full.r),
            border: Border.all(color: palette.border),
          ),
          child: Text(
            l10n.translate('whats_new.version',
                variables: {'version': version}),
            style: t.labelS.copyWith(color: palette.textSecondary),
          ),
        ),

        SizedBox(height: AppSpacing.md.h),
        Divider(color: palette.divider, height: 1),
        SizedBox(height: AppSpacing.sm.h),

        // Change items list
        ...items.map((item) => _ChangeItem(item: item)),

        SizedBox(height: AppSpacing.md.h),

        // Got It button
        AppButton(
          label: l10n.translate('whats_new.got_it'),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<_Item> _changeItems(AppLocalizations l10n, AppPalette palette) => [
        _Item(
          icon: Icons.explore_rounded,
          color: palette.info,
          title: l10n.translate('whats_new.item1_title'),
          body: l10n.translate('whats_new.item1_body'),
        ),
        _Item(
          icon: Icons.admin_panel_settings_rounded,
          color: palette.warning,
          title: l10n.translate('whats_new.item2_title'),
          body: l10n.translate('whats_new.item2_body'),
        ),
        _Item(
          icon: Icons.flag_rounded,
          color: palette.error,
          title: l10n.translate('whats_new.item3_title'),
          body: l10n.translate('whats_new.item3_body'),
        ),
        _Item(
          icon: Icons.auto_awesome_rounded,
          color: palette.energy,
          title: l10n.translate('whats_new.item4_title'),
          body: l10n.translate('whats_new.item4_body'),
        ),
        _Item(
          icon: Icons.store_rounded,
          color: palette.success,
          title: l10n.translate('whats_new.item5_title'),
          body: l10n.translate('whats_new.item5_body'),
        ),
      ];
}

// ── Internal data model ───────────────────────────────────────────────────────

class _Item {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Item(
      {required this.icon,
      required this.color,
      required this.title,
      required this.body});
}

// ── Row widget ────────────────────────────────────────────────────────────────

class _ChangeItem extends StatelessWidget {
  final _Item item;
  // ignore: unused_element
  const _ChangeItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored icon badge
          Container(
            width: 36.r,
            height: 36.r,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
            ),
            child: Icon(item.icon, color: item.color, size: AppSize.iconMd.r),
          ),
          SizedBox(width: AppSpacing.sm.w),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: t.labelM.copyWith(
                      fontWeight: FontWeight.w700, color: palette.textPrimary),
                ),
                SizedBox(height: 2.h),
                Text(item.body,
                    style: t.bodyM.copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
