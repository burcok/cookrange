import 'dart:async';
import 'dart:ui';
import 'package:cookrange/screens/chat/ai_chat_screen.dart';
import 'package:cookrange/screens/chat/chat_list_screen.dart';
import 'package:cookrange/screens/discover/discover_hub_screen.dart';
import 'package:cookrange/screens/admin/admin_panel_screen.dart';
import 'package:cookrange/screens/admin/admin_reports_screen.dart';
import '../../core/services/admin_service.dart';
import 'package:cookrange/screens/coach/coach_clients_screen.dart';
import 'package:cookrange/screens/coach/coach_dashboard_screen.dart';
import 'package:cookrange/screens/coach/coach_discovery_screen.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/models/gym_application_model.dart';
import '../../core/services/coach_application_service.dart';
import '../../core/services/gym_application_service.dart';
import 'package:cookrange/screens/gym/gym_analytics_screen.dart';
import 'package:cookrange/screens/gym/gym_dashboard_screen.dart';
import 'package:cookrange/screens/gym/gym_discovery_screen.dart';
import 'package:cookrange/screens/community/streak_squad_screen.dart';
import 'package:cookrange/screens/leaderboard/leaderboard_screen.dart';
import 'package:cookrange/screens/profile/dietary_preferences_screen.dart';
import 'package:cookrange/screens/programs/my_programs_screen.dart';
import 'package:cookrange/screens/programs/program_marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/providers/test_mode_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_provider.dart';
import '../../core/widgets/ds/ds.dart';
import '../../screens/profile/settings_screen.dart';

class SideMenu extends StatefulWidget {
  final NavigationProvider navProvider;
  final AnimationController animationController;

  const SideMenu({
    super.key,
    required this.navProvider,
    required this.animationController,
  });

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> {
  bool _isLoggingOut = false;
  bool _shouldBlur = false;

  @override
  void initState() {
    super.initState();
    _shouldBlur = widget.animationController.isCompleted;
    widget.animationController.addStatusListener(_onAnimStatus);
  }

  @override
  void didUpdateWidget(SideMenu old) {
    super.didUpdateWidget(old);
    if (old.animationController != widget.animationController) {
      old.animationController.removeStatusListener(_onAnimStatus);
      widget.animationController.addStatusListener(_onAnimStatus);
      _shouldBlur = widget.animationController.isCompleted;
    }
  }

  @override
  void dispose() {
    widget.animationController.removeStatusListener(_onAnimStatus);
    super.dispose();
  }

  void _onAnimStatus(AnimationStatus s) {
    final blur = s == AnimationStatus.completed;
    if (blur != _shouldBlur) setState(() => _shouldBlur = blur);
  }

  void _close() {
    if (_shouldBlur) setState(() => _shouldBlur = false);
    widget.navProvider.toggleMenu(false);
  }

  void _tab(int index) {
    _close();
    widget.navProvider.setIndex(index);
  }

  void _push(Widget screen) {
    _close();
    if (!mounted) return;
    Navigator.of(context).push(AppTransitions.slideRight(screen));
  }

  Future<void> _handleLogout() async {
    _close();
    setState(() => _isLoggingOut = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    await AuthService().signOut();
    if (!mounted) return;
    // ignore: use_build_context_synchronously
    unawaited(Navigator.of(context)
        .pushNamedAndRemoveUntil('/login', (route) => false));
    if (mounted) setState(() => _isLoggingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = palette.isDark;
    final primary = Theme.of(context).primaryColor;
    final user = context.watch<UserProvider>().user;
    final l10n = AppLocalizations.of(context);

    final panel = _SidePanel(
      palette: palette,
      isDark: isDark,
      primary: primary,
      user: user,
      l10n: l10n,
      onTab: _tab,
      onPush: _push,
      onLogout: _handleLogout,
      isLoggingOut: _isLoggingOut,
    );

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          FadeTransition(
            opacity: widget.animationController,
            child: GestureDetector(
              onTap: _close,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: widget.animationController,
              curve: const Cubic(0.2, 0.0, 0.0, 1.0),
              reverseCurve: const Cubic(0.5, 0.0, 1.0, 1.0),
            )),
            child: GestureDetector(
              onHorizontalDragUpdate: (d) {
                if (d.delta.dx < -12) _close();
              },
              child: RepaintBoundary(
                child: ClipRect(
                  child: _shouldBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: panel,
                        )
                      : panel,
                ),
              ),
            ),
          ),
          if (_isLoggingOut)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Side Panel
// ─────────────────────────────────────────────────────────────────────────────

class _SidePanel extends StatelessWidget {
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final UserModel? user;
  final AppLocalizations l10n;
  final void Function(int) onTab;
  final void Function(Widget) onPush;
  final VoidCallback onLogout;
  final bool isLoggingOut;

  const _SidePanel({
    required this.palette,
    required this.isDark,
    required this.primary,
    required this.user,
    required this.l10n,
    required this.onTab,
    required this.onPush,
    required this.onLogout,
    required this.isLoggingOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.82,
      constraints: const BoxConstraints(maxWidth: 330),
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0B1120).withValues(alpha: 0.94)
            : Colors.white.withValues(alpha: 0.92),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 48,
            offset: const Offset(12, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _ProfileHeader(user: user, palette: palette, isDark: isDark, primary: primary, onTap: () => onTab(2)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── MAIN ────────────────────────────────────────────
                    _SectionLabel(l10n.translate('menu.section_pages')),
                    _NavTile(icon: Icons.home_rounded, label: l10n.translate('menu.home'), onTap: () => onTab(NavigationProvider.homeTab), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.groups_rounded, label: l10n.translate('menu.community'), onTap: () => onTab(NavigationProvider.communityTab), palette: palette, isDark: isDark, primary: primary),

                    const SizedBox(height: 18),

                    // ── SOCIAL ──────────────────────────────────────────
                    _SectionLabel(l10n.translate('menu.section_social')),
                    _NavTile(icon: Icons.explore_rounded, label: l10n.translate('menu.discover'), onTap: () => onPush(const DiscoverHubScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.chat_bubble_rounded, label: l10n.translate('menu.chats'), onTap: () => onPush(const ChatListScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.auto_awesome_rounded, label: l10n.translate('menu.ai_chat'), onTap: () => onPush(const AIChatScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.leaderboard_rounded, label: l10n.translate('menu.leaderboard'), onTap: () => onPush(const LeaderboardScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.groups_2_rounded, label: l10n.translate('squad.title'), onTap: () => onPush(const StreakSquadScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.library_books_rounded, label: l10n.translate('program.my_programs'), onTap: () => onPush(const MyProgramsScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.store_rounded, label: l10n.translate('menu.program_marketplace'), onTap: () => onPush(const ProgramMarketplaceScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.fitness_center_rounded, label: l10n.translate('menu.find_gym'), onTap: () => onPush(const GymDiscoveryScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.sports_rounded, label: l10n.translate('menu.find_coach'), onTap: () => onPush(const CoachDiscoveryScreen()), palette: palette, isDark: isDark, primary: primary),

                    const SizedBox(height: 18),

                    // ── ROLE CARD ────────────────────────────────────────
                    if (user != null)
                      _buildRoleCard(context, user!, l10n),

                    const SizedBox(height: 18),

                    // ── ACCOUNT ──────────────────────────────────────────
                    _SectionLabel(l10n.translate('menu.section_account')),
                    _NavTile(icon: Icons.restaurant_menu_rounded, label: l10n.translate('menu.dietary_preferences'), onTap: () => onPush(const DietaryPreferencesScreen()), palette: palette, isDark: isDark, primary: primary),
                    _NavTile(icon: Icons.settings_rounded, label: l10n.translate('menu.settings'), onTap: () => onPush(const SettingsScreen()), palette: palette, isDark: isDark, primary: primary),

                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
            _LogoutFooter(palette: palette, isDark: isDark, onLogout: onLogout, isLoggingOut: isLoggingOut, l10n: l10n),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, UserModel user, AppLocalizations l10n) {
    final cards = <Widget>[];

    if (user.hasRole(UserRole.admin)) {
      cards.add(_AdminCard(l10n: l10n, palette: palette, isDark: isDark, primary: primary, onPush: onPush));
    }
    if (user.hasRole(UserRole.gymOwner)) {
      cards.add(_GymCard(l10n: l10n, palette: palette, isDark: isDark, primary: primary, onPush: onPush));
    }
    if (user.hasRole(UserRole.coach)) {
      cards.add(_CoachCard(l10n: l10n, palette: palette, isDark: isDark, primary: primary, onPush: onPush));
    }

    if (cards.isEmpty) {
      return _ConsumerCard(uid: user.uid, l10n: l10n, palette: palette, isDark: isDark, primary: primary, onPush: onPush);
    }
    if (cards.length == 1) return cards.first;

    return Column(
      children: cards
          .expand((c) => [c, const SizedBox(height: 12)])
          .take(cards.length * 2 - 1)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Role Cards
// ─────────────────────────────────────────────────────────────────────────────

class _AdminCard extends StatelessWidget {
  final AppLocalizations l10n;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final void Function(Widget) onPush;

  const _AdminCard({required this.l10n, required this.palette, required this.isDark, required this.primary, required this.onPush});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFEC4899);
    return _RoleGlassCard(
      headerIcon: Icons.admin_panel_settings_rounded,
      headerLabel: l10n.translate('menu.section_admin'),
      accentColor: accent,
      palette: palette,
      isDark: isDark,
      children: [
        StreamBuilder<int>(
          stream: AdminService().pendingCountStream(),
          builder: (context, snap) {
            final count = snap.data ?? 0;
            return _CardTile(
              icon: Icons.manage_accounts_rounded,
              label: l10n.translate('menu.admin_users'),
              palette: palette,
              isDark: isDark,
              primary: primary,
              onTap: () => onPush(const AdminPanelScreen()),
              badge: count > 0 ? '$count' : null,
            );
          },
        ),
        _CardTile(
          icon: Icons.flag_rounded,
          label: l10n.translate('menu.admin_reports'),
          palette: palette,
          isDark: isDark,
          primary: primary,
          onTap: () => onPush(const AdminReportsScreen()),
        ),
        _CardDivider(palette: palette, isDark: isDark),
        // Test mode toggle
        Consumer<TestModeProvider>(
          builder: (context, testMode, _) => _ToggleTile(
            icon: Icons.science_rounded,
            label: 'Test Mode',
            subtitle: testMode.isActive ? 'Active — mock data' : 'Off',
            value: testMode.isActive,
            palette: palette,
            isDark: isDark,
            accentColor: accent,
            onChanged: (_) {
              HapticFeedback.selectionClick();
              testMode.toggle();
            },
          ),
        ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  final AppLocalizations l10n;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final void Function(Widget) onPush;

  const _CoachCard({required this.l10n, required this.palette, required this.isDark, required this.primary, required this.onPush});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6366F1);
    return _RoleGlassCard(
      headerIcon: Icons.sports_rounded,
      headerLabel: l10n.translate('menu.section_my_clients'),
      accentColor: accent,
      palette: palette,
      isDark: isDark,
      children: [
        _CardTile(
          icon: Icons.dashboard_rounded,
          label: l10n.translate('menu.my_coaching'),
          palette: palette,
          isDark: isDark,
          primary: primary,
          onTap: () => onPush(const CoachDashboardScreen()),
        ),
        _CardTile(
          icon: Icons.people_alt_rounded,
          label: l10n.translate('menu.my_clients'),
          palette: palette,
          isDark: isDark,
          primary: primary,
          onTap: () => onPush(const CoachClientsScreen()),
        ),
      ],
    );
  }
}

class _GymCard extends StatelessWidget {
  final AppLocalizations l10n;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final void Function(Widget) onPush;

  const _GymCard({required this.l10n, required this.palette, required this.isDark, required this.primary, required this.onPush});

  @override
  Widget build(BuildContext context) {
    return _RoleGlassCard(
      headerIcon: Icons.fitness_center_rounded,
      headerLabel: l10n.translate('menu.section_gym_management'),
      accentColor: primary,
      palette: palette,
      isDark: isDark,
      children: [
        _CardTile(
          icon: Icons.dashboard_rounded,
          label: l10n.translate('menu.gym_dashboard'),
          palette: palette,
          isDark: isDark,
          primary: primary,
          onTap: () => onPush(const GymDashboardScreen()),
        ),
        _CardTile(
          icon: Icons.search_rounded,
          label: l10n.translate('menu.gym_discover'),
          palette: palette,
          isDark: isDark,
          primary: primary,
          onTap: () => onPush(const GymDiscoveryScreen()),
        ),
        _CardTile(
          icon: Icons.bar_chart_rounded,
          label: l10n.translate('menu.gym_analytics'),
          palette: palette,
          isDark: isDark,
          primary: primary,
          onTap: () => onPush(const GymAnalyticsScreen()),
        ),
      ],
    );
  }
}

class _ConsumerCard extends StatelessWidget {
  final String uid;
  final AppLocalizations l10n;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final void Function(Widget) onPush;

  const _ConsumerCard({required this.uid, required this.l10n, required this.palette, required this.isDark, required this.primary, required this.onPush});

  @override
  Widget build(BuildContext context) {
    return _RoleGlassCard(
      headerIcon: Icons.rocket_launch_rounded,
      headerLabel: l10n.translate('menu.section_grow'),
      accentColor: primary,
      palette: palette,
      isDark: isDark,
      children: [
        StreamBuilder<GymApplicationModel?>(
          stream: GymApplicationService().getMyApplicationStream(uid),
          builder: (context, snap) {
            final app = snap.data;
            final isPending = app?.status == GymApplicationStatus.pending;
            final isRejected = app?.status == GymApplicationStatus.rejected;
            return _CardTile(
              icon: isPending ? Icons.hourglass_top_rounded : isRejected ? Icons.cancel_outlined : Icons.add_business_rounded,
              label: isPending ? l10n.translate('menu.gym_app_pending') : isRejected ? l10n.translate('menu.gym_app_rejected') : l10n.translate('menu.register_gym'),
              palette: palette,
              isDark: isDark,
              primary: primary,
              onTap: () => onPush(const GymDashboardScreen()),
              statusColor: isPending ? palette.warning : isRejected ? palette.error : null,
            );
          },
        ),
        StreamBuilder<CoachApplicationModel?>(
          stream: CoachApplicationService().getMyApplicationStream(uid),
          builder: (context, snap) {
            final app = snap.data;
            final isPending = app != null && (app.isPending || app.status == CoachApplicationStatus.needsMoreInfo);
            final isRejected = app != null && app.isRejected;
            return _CardTile(
              icon: isPending ? Icons.hourglass_top_rounded : isRejected ? Icons.cancel_outlined : Icons.sports_rounded,
              label: isPending ? l10n.translate('menu.coach_app_pending') : isRejected ? l10n.translate('menu.coach_app_rejected') : l10n.translate('menu.become_coach'),
              palette: palette,
              isDark: isDark,
              primary: primary,
              onTap: () => onPush(const CoachDashboardScreen()),
              statusColor: isPending ? palette.warning : isRejected ? palette.error : null,
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Role Card Container
// ─────────────────────────────────────────────────────────────────────────────

class _RoleGlassCard extends StatelessWidget {
  final IconData headerIcon;
  final String headerLabel;
  final Color accentColor;
  final AppPalette palette;
  final bool isDark;
  final List<Widget> children;

  const _RoleGlassCard({
    required this.headerIcon,
    required this.headerLabel,
    required this.accentColor,
    required this.palette,
    required this.isDark,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accentColor.withValues(alpha: isDark ? 0.25 : 0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(headerIcon, size: 15, color: accentColor),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      headerLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Divider(height: 1, color: accentColor.withValues(alpha: isDark ? 0.12 : 0.1)),
              // Items
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Column(children: children),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tile variants
// ─────────────────────────────────────────────────────────────────────────────

/// Standard navigation tile — used outside role cards.
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final AppPalette palette;
  final bool isDark;
  final Color primary;

  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.palette,
    required this.isDark,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        overlayColor: WidgetStateProperty.all(
            palette.textSecondary.withValues(alpha: 0.06)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Icon(
                  icon,
                  size: 20,
                  color: palette.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile inside a role card — slightly denser.
class _CardTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final String? badge;
  final Color? statusColor;

  const _CardTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.palette,
    required this.isDark,
    required this.primary,
    this.badge,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = statusColor ?? palette.textSecondary.withValues(alpha: 0.65);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        overlayColor: WidgetStateProperty.all(
            primary.withValues(alpha: 0.07)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.error,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Toggle row — for test mode and similar switches inside role cards.
class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final AppPalette palette;
  final bool isDark;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.palette,
    required this.isDark,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: value
                ? accentColor
                : palette.textSecondary.withValues(alpha: 0.55),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: value
                        ? accentColor.withValues(alpha: 0.7)
                        : palette.textSecondary.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.82,
            child: Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: accentColor,
              activeTrackColor: accentColor.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle divider inside role cards.
class _CardDivider extends StatelessWidget {
  final AppPalette palette;
  final bool isDark;
  const _CardDivider({required this.palette, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Divider(
        height: 1,
        color: palette.border.withValues(alpha: 0.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 4, top: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: palette.textSecondary.withValues(alpha: 0.4),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final UserModel? user;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final VoidCallback onTap;

  const _ProfileHeader({
    required this.user,
    required this.palette,
    required this.isDark,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'User';
    final photoUrl = user?.photoURL;
    final l10n = AppLocalizations.of(context);

    // Show all roles; fall back to consumer chip when no non-consumer roles exist.
    final roles = (user?.userRoles.isNotEmpty == true)
        ? user!.userRoles
        : [UserRole.consumer];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 38, 18, 18),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.35),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.15),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(photoUrl, fit: BoxFit.cover, cacheWidth: 208,
                            errorBuilder: (_, __, ___) => _avatarFallback())
                        : _avatarFallback(),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0B1120) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: roles.map((role) {
                      final (roleName, roleColor) = _roleInfo(role, l10n);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: isDark ? 0.15 : 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: roleColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          roleName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: roleColor,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: palette.textSecondary.withValues(alpha: 0.4), size: 13),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() => Container(
        color: primary.withValues(alpha: 0.1),
        child: Icon(Icons.person_rounded, size: 26, color: primary.withValues(alpha: 0.7)),
      );

  (String, Color) _roleInfo(UserRole role, AppLocalizations l10n) {
    switch (role) {
      case UserRole.admin:
        return (l10n.translate('role.admin'), const Color(0xFFEC4899));
      case UserRole.coach:
        return (l10n.translate('role.coach'), const Color(0xFF6366F1));
      case UserRole.gymOwner:
        return (l10n.translate('role.gym_owner'), primary);
      case UserRole.consumer:
        return (l10n.translate('role.consumer'), palette.textSecondary);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logout footer
// ─────────────────────────────────────────────────────────────────────────────

class _LogoutFooter extends StatelessWidget {
  final AppPalette palette;
  final bool isDark;
  final VoidCallback onLogout;
  final bool isLoggingOut;
  final AppLocalizations l10n;

  const _LogoutFooter({
    required this.palette,
    required this.isDark,
    required this.onLogout,
    required this.isLoggingOut,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: isLoggingOut ? null : onLogout,
              borderRadius: BorderRadius.circular(12),
              overlayColor: WidgetStateProperty.all(
                  Colors.red.withValues(alpha: 0.08)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoggingOut)
                      const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red),
                      )
                    else
                      Icon(Icons.logout_rounded,
                          color: palette.error, size: 17),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('menu.logout'),
                      style: TextStyle(
                        color: palette.error,
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 9.5,
              color: palette.textSecondary.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}
