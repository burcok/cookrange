import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/services/admin_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'admin_nav.dart';
import 'admin_sections.dart';

/// The admin landing surface: every section visible at once as a categorized
/// card grid (with live badges) + a drawer for quick jumps. Replaces the old
/// 13-tab scrollable TabBar where you'd lose track of where you were.
class AdminHubScreen extends StatelessWidget {
  const AdminHubScreen({super.key});

  Stream<int>? _badge(AdminService svc, AdminSection s) {
    switch (s.meta.badge) {
      case AdminBadge.openReports:
        return svc.openReportCountStream();
      case AdminBadge.users:
        return svc.userCountStream();
      case AdminBadge.pendingApplications:
        if (s == AdminSection.coachApps) {
          return svc.pendingCoachApplicationsStream().map((l) => l.length);
        }
        return svc.pendingGymApplicationsStream().map((l) => l.length);
      case AdminBadge.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final svc = AdminService();

    return Scaffold(
      backgroundColor: palette.background,
      drawer: const AdminNavDrawer(),
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        // Explicit back button so exiting to the app always works (a Scaffold
        // drawer would otherwise replace the leading with a hamburger).
        leading: Navigator.of(context).canPop() ? const BackButton() : null,
        automaticallyImplyLeading: false,
        title: Text(l10n.translate('admin.hub_title'), style: t.titleL),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded),
              tooltip: l10n.translate('admin.hub_jump'),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 32.h),
        children: [
          for (final cat in AdminCategory.values) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 10.h),
              child: Text(
                l10n.translate(cat.titleKey),
                style: t.labelM.copyWith(
                  color: palette.textSecondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12.h,
              crossAxisSpacing: 12.w,
              childAspectRatio: 1.25,
              children: [
                for (final s in adminSectionsFor(cat))
                  _SectionCard(
                    section: s,
                    badgeStream: _badge(svc, s),
                    onTap: () => AdminNav.open(context, s),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final AdminSection section;
  final Stream<int>? badgeStream;
  final VoidCallback onTap;
  const _SectionCard({
    required this.section,
    required this.badgeStream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final m = section.meta;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.all(12.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color: AppPalette.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(m.icon, color: AppPalette.brand, size: 20.r),
              ),
              const Spacer(),
              if (badgeStream != null)
                StreamBuilder<int>(
                  stream: badgeStream,
                  builder: (_, snap) {
                    final n = snap.data ?? 0;
                    if (n <= 0) return const SizedBox.shrink();
                    return Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: m.badge == AdminBadge.users
                            ? palette.surfaceVariant
                            : palette.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        n > 999 ? '999+' : '$n',
                        style: t.labelS.copyWith(
                          color: m.badge == AdminBadge.users
                              ? palette.textSecondary
                              : palette.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const Spacer(),
          Text(
            l10n.translate(m.titleKey),
            style: t.titleM.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 2.h),
          Text(
            l10n.translate(m.subtitleKey),
            style: t.labelS.copyWith(color: palette.textTertiary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
