import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';

/// Faz 2 §2.2 — sticky pinned-message banner, sits right under the app bar.
/// Any participant may unpin (mirrors the rule: pinning is an any-participant
/// chat-meta write, not sender-only) so [onUnpin] is always offered.
class AppPinnedBanner extends StatelessWidget {
  final String senderLabel;
  final String previewText;
  final IconData? kindIcon;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  const AppPinnedBanner({
    super.key,
    required this.senderLabel,
    required this.previewText,
    this.kindIcon,
    required this.onTap,
    required this.onUnpin,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = Theme.of(context).primaryColor;

    return Material(
      color: palette.surface.withValues(alpha: 0.96),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: palette.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.push_pin_rounded,
                  size: AppSize.iconSm.r, color: accent),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.translate('chat.pinned.label'),
                      style: t.labelS
                          .copyWith(color: accent, fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        if (kindIcon != null) ...[
                          Icon(kindIcon,
                              size: 12.r, color: palette.textTertiary),
                          SizedBox(width: 4.w),
                        ],
                        Expanded(
                          child: Text(
                            '$senderLabel: $previewText',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyM.copyWith(color: palette.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.xs.w),
              Semantics(
                button: true,
                label: l10n.translate('chat.pinned.unpin'),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onUnpin();
                  },
                  child: Icon(Icons.close_rounded,
                      size: AppSize.iconSm.r, color: palette.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
