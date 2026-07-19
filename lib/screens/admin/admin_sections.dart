import 'package:flutter/material.dart';

/// Single source of truth for the admin surface. Every admin capability is one
/// [AdminSection]; the hub (grid + drawer) and the per-section screens both read
/// this registry, so adding/removing a section is a one-line change here.
enum AdminCategory { moderation, people, growth, content, insights, system }

extension AdminCategoryX on AdminCategory {
  /// i18n key for the category header.
  String get titleKey {
    switch (this) {
      case AdminCategory.moderation:
        return 'admin.cat_moderation';
      case AdminCategory.people:
        return 'admin.cat_people';
      case AdminCategory.growth:
        return 'admin.cat_growth';
      case AdminCategory.content:
        return 'admin.cat_content';
      case AdminCategory.insights:
        return 'admin.cat_insights';
      case AdminCategory.system:
        return 'admin.cat_system';
    }
  }
}

/// How a section badge is counted (live). `none` = no badge.
enum AdminBadge { none, pendingApplications, openReports, users }

/// A section rendered either as its own standalone screen (`standalone: true`)
/// or as a single-section view inside the (refactored) admin panel.
enum AdminSection {
  // Moderation
  coachApps,
  gymApps,
  programs,
  reports,
  privacy,
  // People
  users,
  abuse,
  // Growth
  broadcasts,
  credits,
  // Content
  dishes,
  // Insights
  analytics,
  cost,
  // System
  appConfig,
  audit,
  history,
}

class AdminSectionMeta {
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final AdminCategory category;
  final AdminBadge badge;

  /// True → opens its own screen; false → rendered by AdminPanelScreen(section:).
  final bool standalone;

  const AdminSectionMeta({
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.category,
    this.badge = AdminBadge.none,
    this.standalone = false,
  });
}

extension AdminSectionX on AdminSection {
  AdminSectionMeta get meta {
    switch (this) {
      case AdminSection.coachApps:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_coaches',
          subtitleKey: 'admin.section_coaches_sub',
          icon: Icons.school_rounded,
          category: AdminCategory.moderation,
          badge: AdminBadge.pendingApplications,
        );
      case AdminSection.gymApps:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_gyms',
          subtitleKey: 'admin.section_gyms_sub',
          icon: Icons.business_rounded,
          category: AdminCategory.moderation,
          badge: AdminBadge.pendingApplications,
        );
      case AdminSection.programs:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_programs',
          subtitleKey: 'admin.section_programs_sub',
          icon: Icons.library_books_rounded,
          category: AdminCategory.moderation,
        );
      case AdminSection.reports:
        return const AdminSectionMeta(
          titleKey: 'admin.section_reports',
          subtitleKey: 'admin.section_reports_sub',
          icon: Icons.flag_rounded,
          category: AdminCategory.moderation,
          badge: AdminBadge.openReports,
          standalone: true,
        );
      case AdminSection.privacy:
        return const AdminSectionMeta(
          titleKey: 'admin.section_privacy',
          subtitleKey: 'admin.section_privacy_sub',
          icon: Icons.privacy_tip_rounded,
          category: AdminCategory.moderation,
          standalone: true,
        );
      case AdminSection.users:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_users',
          subtitleKey: 'admin.section_users_sub',
          icon: Icons.people_alt_rounded,
          category: AdminCategory.people,
          badge: AdminBadge.users,
          standalone: true,
        );
      case AdminSection.abuse:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_abuse',
          subtitleKey: 'admin.section_abuse_sub',
          icon: Icons.shield_moon_rounded,
          category: AdminCategory.people,
        );
      case AdminSection.broadcasts:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_broadcasts',
          subtitleKey: 'admin.section_broadcasts_sub',
          icon: Icons.campaign_rounded,
          category: AdminCategory.growth,
        );
      case AdminSection.credits:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_credits',
          subtitleKey: 'admin.section_credits_sub',
          icon: Icons.bolt_rounded,
          category: AdminCategory.growth,
        );
      case AdminSection.dishes:
        return const AdminSectionMeta(
          titleKey: 'admin.section_dishes',
          subtitleKey: 'admin.section_dishes_sub',
          icon: Icons.restaurant_menu_rounded,
          category: AdminCategory.content,
          standalone: true,
        );
      case AdminSection.analytics:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_analytics',
          subtitleKey: 'admin.section_analytics_sub',
          icon: Icons.insights_rounded,
          category: AdminCategory.insights,
        );
      case AdminSection.cost:
        return const AdminSectionMeta(
          titleKey: 'admin.cost_title',
          subtitleKey: 'admin.section_cost_sub',
          icon: Icons.payments_rounded,
          category: AdminCategory.insights,
          standalone: true,
        );
      case AdminSection.appConfig:
        return const AdminSectionMeta(
          titleKey: 'admin.appconfig.title',
          subtitleKey: 'admin.section_appconfig_sub',
          icon: Icons.tune_rounded,
          category: AdminCategory.system,
          standalone: true,
        );
      case AdminSection.audit:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_audit',
          subtitleKey: 'admin.section_audit_sub',
          icon: Icons.security_rounded,
          category: AdminCategory.system,
        );
      case AdminSection.history:
        return const AdminSectionMeta(
          titleKey: 'admin.tab_history',
          subtitleKey: 'admin.section_history_sub',
          icon: Icons.history_rounded,
          category: AdminCategory.system,
        );
    }
  }
}

/// Ordered sections for a category (drives the hub grid + drawer).
List<AdminSection> adminSectionsFor(AdminCategory c) =>
    AdminSection.values.where((s) => s.meta.category == c).toList();
