import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/widgets/ds/ds.dart';
import 'admin_sections.dart';
import 'admin_panel_screen.dart';
import 'admin_app_config_screen.dart';
import 'admin_cost_analytics_screen.dart';
import 'admin_dishes_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_privacy_requests_screen.dart';
import 'admin_user_management_screen.dart';

/// Central router for the admin surface. Maps an [AdminSection] to its screen
/// (standalone screens for the self-contained ones; a single-section
/// [AdminPanelScreen] for the panel-hosted ones) and owns the shared nav drawer.
class AdminNav {
  const AdminNav._();

  static Widget screenFor(AdminSection section) {
    if (section.meta.standalone) {
      switch (section) {
        case AdminSection.appConfig:
          return const AdminAppConfigScreen();
        case AdminSection.cost:
          return const AdminCostAnalyticsScreen();
        case AdminSection.dishes:
          return const AdminDishesScreen();
        case AdminSection.reports:
          return const AdminReportsScreen();
        case AdminSection.privacy:
          return const AdminPrivacyRequestsScreen();
        case AdminSection.users:
          return const AdminUserManagementScreen();
        default:
          break;
      }
    }
    // Panel-hosted sections render as a single-section admin panel view.
    return AdminPanelScreen(initialSection: section);
  }

  /// Navigates to [section], replacing the current admin route so the back
  /// button always returns to the hub (never stacks section on section).
  static void open(BuildContext context, AdminSection section) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screenFor(section)),
    );
  }
}

/// Shared drawer listing every section grouped by category — the "jump to any
/// section without losing your place" control, available on the hub and inside
/// every section screen.
class AdminNavDrawer extends StatelessWidget {
  final AdminSection? current;
  const AdminNavDrawer({super.key, this.current});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Drawer(
      backgroundColor: palette.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.admin_panel_settings_rounded,
                      color: AppPalette.brand),
                  const SizedBox(width: 10),
                  Text(l10n.translate('admin.hub_title'),
                      style: t.titleM.copyWith(color: palette.textPrimary)),
                ],
              ),
            ),
            Divider(color: palette.border, height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final cat in AdminCategory.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Text(
                        l10n.translate(cat.titleKey).toUpperCase(),
                        style: t.labelS.copyWith(
                          color: palette.textTertiary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    for (final s in adminSectionsFor(cat))
                      _DrawerTile(
                        section: s,
                        selected: s == current,
                        onTap: () {
                          Navigator.of(context).pop(); // close drawer
                          if (s == current) return;
                          AdminNav.open(context, s);
                        },
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final AdminSection section;
  final bool selected;
  final VoidCallback onTap;
  const _DrawerTile({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final m = section.meta;
    return ListTile(
      dense: true,
      leading: Icon(m.icon,
          size: 20,
          color: selected ? AppPalette.brand : palette.textSecondary),
      title: Text(
        l10n.translate(m.titleKey),
        style: t.bodyM.copyWith(
          color: selected ? AppPalette.brand : palette.textPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      selected: selected,
      selectedTileColor: AppPalette.brand.withValues(alpha: 0.08),
      onTap: onTap,
    );
  }
}
