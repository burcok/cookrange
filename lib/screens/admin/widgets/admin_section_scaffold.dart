import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/ds/ds.dart';
import '../admin_nav.dart';
import '../admin_sections.dart';

/// Consistent chrome for every admin section screen: DS background, a titled
/// app bar, an optional actions slot, and the shared cross-section nav drawer
/// so you can jump anywhere without losing your place.
class AdminSectionScaffold extends StatelessWidget {
  final AdminSection section;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const AdminSectionScaffold({
    super.key,
    required this.section,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Scaffold(
      backgroundColor: palette.background,
      drawer: AdminNavDrawer(current: section),
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        // Explicit back (drawer would otherwise hijack the leading slot); the
        // cross-section drawer is reachable via the trailing menu button.
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        automaticallyImplyLeading: false,
        title: Text(l10n.translate(section.meta.titleKey), style: t.titleL),
        actions: [
          ...?actions,
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: l10n.translate('admin.hub_jump'),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      body: body,
    );
  }
}
