import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/widgets/ds/ds.dart';

/// Moderation queue for reported community posts.
/// Linked from the side-menu admin_reports item.
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20.r),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('menu.admin_reports'),
          style: t.titleM
              .copyWith(color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: Center(
        child: AppEmptyState(
          icon: Icons.flag_outlined,
          title: l10n.translate('menu.coming_soon'),
          message: '',
        ),
      ),
    );
  }
}
