import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';
import 'app_button.dart';
import 'app_sheet.dart';

/// Cookrange Design System — branded permission rationale sheet.
///
/// Shows BEFORE the OS permission dialog so the user understands why the app
/// needs the permission. Returns true if the user tapped Allow, false otherwise.
/// Use [PermissionService] to handle the full flow (check → primer → OS request).
class PermissionPrimer {
  PermissionPrimer._();

  static Future<bool> show(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String rationale,
    required String allowLabel,
    required String notNowLabel,
  }) async {
    final result = await AppSheet.show<bool>(
      context: context,
      child: _PrimerBody(
        icon: icon,
        iconColor: iconColor,
        title: title,
        rationale: rationale,
        allowLabel: allowLabel,
        notNowLabel: notNowLabel,
      ),
    );
    return result ?? false;
  }
}

class _PrimerBody extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String rationale;
  final String allowLabel;
  final String notNowLabel;

  const _PrimerBody({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.rationale,
    required this.allowLabel,
    required this.notNowLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 36),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          style: t.headlineS.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          rationale,
          style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: allowLabel,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: notNowLabel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
      ],
    );
  }
}
