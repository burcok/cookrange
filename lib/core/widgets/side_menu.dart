import 'dart:async';
import 'dart:ui';
import 'package:cookrange/screens/chat/ai_chat_screen.dart';
import 'package:cookrange/screens/chat/chat_list_screen.dart';
import 'package:cookrange/screens/challenges/challenges_screen.dart';
import 'package:cookrange/screens/coach/coach_clients_screen.dart';
import 'package:cookrange/screens/coach/coach_dashboard_screen.dart';
import 'package:cookrange/screens/coach/coach_discovery_screen.dart';
import 'package:cookrange/screens/gym/gym_dashboard_screen.dart';
import 'package:cookrange/screens/gym/gym_discovery_screen.dart';
import 'package:cookrange/screens/leaderboard/leaderboard_screen.dart';
import 'package:cookrange/screens/profile/dietary_preferences_screen.dart';
import 'package:cookrange/screens/programs/program_marketplace_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/navigation_provider.dart';
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
    widget.animationController.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  void didUpdateWidget(SideMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationController != widget.animationController) {
      oldWidget.animationController
          .removeStatusListener(_onAnimationStatusChanged);
      widget.animationController.addStatusListener(_onAnimationStatusChanged);
      _shouldBlur = widget.animationController.isCompleted;
    }
  }

  @override
  void dispose() {
    widget.animationController.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    final newShouldBlur = status == AnimationStatus.completed;
    if (newShouldBlur != _shouldBlur) {
      setState(() => _shouldBlur = newShouldBlur);
    }
  }

  void _close() {
    // Remove BackdropFilter immediately so the slide-out animation
    // doesn't carry the expensive blur compositing layer.
    if (_shouldBlur) setState(() => _shouldBlur = false);
    widget.navProvider.toggleMenu(false);
  }

  void _navigateToMainTab(int index) {
    _close();
    widget.navProvider.setIndex(index);
  }

  void _push(Widget screen) {
    _close();
    if (!mounted) return;
    Navigator.of(context).push(AppTransitions.slideRight(screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final user = context.watch<UserProvider>().user;
    final l10n = AppLocalizations.of(context);

    final menuContent = Container(
      width: MediaQuery.of(context).size.width * 0.80,
      constraints: const BoxConstraints(maxWidth: 320),
      height: double.infinity,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.92),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.6),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 32,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            _buildProfileSection(context, user, isDark, primary, palette),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── PAGES ───────────────────────────────────────────
                    _sectionHeader(l10n.translate('menu.section_pages'), palette),
                    _menuItem(
                      icon: Icons.home_rounded,
                      label: l10n.translate('menu.home'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _navigateToMainTab(NavigationProvider.homeTab),
                    ),
                    _menuItem(
                      icon: Icons.groups_rounded,
                      label: l10n.translate('menu.community'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () =>
                          _navigateToMainTab(NavigationProvider.communityTab),
                    ),

                    const SizedBox(height: 28),

                    // ── SOCIAL ──────────────────────────────────────────
                    _sectionHeader(l10n.translate('menu.section_social'), palette),
                    _menuItem(
                      icon: Icons.chat_bubble_rounded,
                      label: l10n.translate('menu.chats'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _push(const ChatListScreen()),
                    ),
                    _menuItem(
                      icon: Icons.auto_awesome_rounded,
                      label: l10n.translate('menu.ai_chat'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _push(const AIChatScreen()),
                    ),
                    _menuItem(
                      icon: Icons.emoji_events_rounded,
                      label: l10n.translate('menu.challenges'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _push(const ChallengesScreen()),
                    ),
                    _menuItem(
                      icon: Icons.leaderboard_rounded,
                      label: l10n.translate('menu.leaderboard'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _push(const LeaderboardScreen()),
                    ),
                    _menuItem(
                      icon: Icons.store_rounded,
                      iconColor: palette.info,
                      label: l10n.translate('menu.program_marketplace'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _push(const ProgramMarketplaceScreen()),
                    ),
                    _menuItem(
                      icon: Icons.fitness_center_rounded,
                      iconColor: const Color(0xFF10B981),
                      label: l10n.translate('menu.find_gym'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _push(const GymDiscoveryScreen()),
                    ),
                    _menuItem(
                      icon: Icons.sports_rounded,
                      iconColor: const Color(0xFF6366F1),
                      label: l10n.translate('menu.find_coach'),
                      isDark: isDark,
                      primary: primary,
                      palette: palette,
                      onTap: () => _push(const CoachDiscoveryScreen()),
                    ),

                    const SizedBox(height: 28),

                    // ── ROLE-BASED SECTION ───────────────────────────────
                    if (user != null)
                      _buildRoleSection(
                          context, user, isDark, primary, palette, l10n),

                    const SizedBox(height: 28),

                    // ── ACCOUNT & MORE ───────────────────────────────────
                    _sectionHeader(
                        l10n.translate('menu.section_account'), palette),
                    _simpleItem(
                      icon: Icons.manage_accounts_rounded,
                      label: l10n.translate('menu.dietary_preferences'),
                      isDark: isDark,
                      palette: palette,
                      onTap: () => _push(const DietaryPreferencesScreen()),
                    ),
                    _simpleItem(
                      icon: Icons.settings_rounded,
                      label: l10n.translate('menu.settings'),
                      isDark: isDark,
                      palette: palette,
                      onTap: () => _push(const SettingsScreen()),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(context, isDark, primary, palette),
          ],
        ),
      ),
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
                color: Colors.black.withValues(alpha: 0.42),
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
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            )),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx < -10) _close();
              },
              child: RepaintBoundary(
                child: ClipRect(
                  child: _shouldBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                          child: menuContent,
                        )
                      : menuContent,
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

  // ── Profile section ────────────────────────────────────────────────────────

  Widget _buildProfileSection(BuildContext context, dynamic user, bool isDark,
      Color primary, AppPalette palette) {
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? 'User';

    return GestureDetector(
      onTap: () => _navigateToMainTab(2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 44, 28, 28),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
            ),
          ),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.4),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            cacheWidth: 240,
                            errorBuilder: (_, __, ___) =>
                                _avatarPlaceholder(primary),
                          )
                        : _avatarPlaceholder(primary),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: palette.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pro',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: palette.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder(Color primary) {
    return Container(
      color: primary.withValues(alpha: 0.15),
      child: Icon(Icons.person_rounded, size: 30, color: primary),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: palette.textSecondary.withValues(alpha: 0.6),
          letterSpacing: 1.3,
        ),
      ),
    );
  }

  // ── Menu item (with colored icon support + coming soon) ────────────────────

  Widget _menuItem({
    required IconData icon,
    Color? iconColor,
    required String label,
    required bool isDark,
    required Color primary,
    required AppPalette palette,
    required VoidCallback? onTap,
    bool comingSoon = false,
  }) {
    final effectiveIconColor = iconColor ??
        (isDark ? Colors.grey.shade400 : Colors.grey.shade500);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: comingSoon ? null : onTap,
          overlayColor:
              WidgetStateProperty.all(primary.withValues(alpha: 0.08)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: effectiveIconColor.withValues(
                        alpha: comingSoon ? 0.06 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: comingSoon
                        ? effectiveIconColor.withValues(alpha: 0.35)
                        : effectiveIconColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: comingSoon
                          ? palette.textSecondary.withValues(alpha: 0.4)
                          : palette.textPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                if (comingSoon)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppLocalizations.of(context)
                          .translate('menu.coming_soon'),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: palette.textSecondary.withValues(alpha: 0.5),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Simple item (settings / preferences — lighter style) ──────────────────

  Widget _simpleItem({
    required IconData icon,
    required String label,
    required bool isDark,
    required AppPalette palette,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Icon(
          icon,
          size: 22,
          color: palette.textSecondary.withValues(alpha: 0.6),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: palette.textSecondary.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  // ── Role-based section ─────────────────────────────────────────────────────

  Widget _buildRoleSection(
    BuildContext context,
    UserModel user,
    bool isDark,
    Color primary,
    AppPalette palette,
    AppLocalizations l10n,
  ) {
    switch (user.userRole) {
      case UserRole.gymOwner:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                l10n.translate('menu.section_gym_management'), palette),
            _menuItem(
              icon: Icons.dashboard_rounded,
              iconColor: primary,
              label: l10n.translate('menu.gym_dashboard'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              onTap: () => _push(const GymDashboardScreen()),
            ),
            _menuItem(
              icon: Icons.search_rounded,
              iconColor: const Color(0xFF10B981),
              label: l10n.translate('menu.gym_discover'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              onTap: () => _push(const GymDiscoveryScreen()),
            ),
            _menuItem(
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFFF59E0B),
              label: l10n.translate('menu.gym_analytics'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              comingSoon: true,
              onTap: null,
            ),
          ],
        );

      case UserRole.coach:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                l10n.translate('menu.section_my_clients'), palette),
            _menuItem(
              icon: Icons.people_alt_rounded,
              iconColor: const Color(0xFF6366F1),
              label: l10n.translate('menu.my_clients'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              onTap: () => _push(const CoachClientsScreen()),
            ),
            _menuItem(
              icon: Icons.insights_rounded,
              iconColor: const Color(0xFF10B981),
              label: l10n.translate('menu.coach_dashboard'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              onTap: () => _push(const CoachDashboardScreen()),
            ),
          ],
        );

      case UserRole.admin:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(
                l10n.translate('menu.section_admin'), palette),
            _menuItem(
              icon: Icons.admin_panel_settings_rounded,
              iconColor: const Color(0xFFEC4899),
              label: l10n.translate('menu.admin_users'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              comingSoon: true,
              onTap: null,
            ),
            _menuItem(
              icon: Icons.flag_rounded,
              iconColor: palette.error,
              label: l10n.translate('menu.admin_reports'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              comingSoon: true,
              onTap: null,
            ),
          ],
        );

      case UserRole.consumer:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader(l10n.translate('menu.section_grow'), palette),
            _menuItem(
              icon: Icons.add_business_rounded,
              iconColor: primary,
              label: l10n.translate('menu.register_gym'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              onTap: () => _push(const GymDashboardScreen()),
            ),
            _menuItem(
              icon: Icons.sports_rounded,
              iconColor: const Color(0xFF6366F1),
              label: l10n.translate('menu.become_coach'),
              isDark: isDark,
              primary: primary,
              palette: palette,
              onTap: () => _push(const CoachDashboardScreen()),
            ),
          ],
        );
    }
  }

  // ── Footer ─────────────────────────────────────────────────────────────────

  Widget _buildFooter(BuildContext context, bool isDark, Color primary,
      AppPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: isDark
                ? Colors.red.withValues(alpha: 0.08)
                : Colors.red.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: isDark
                    ? Colors.red.withValues(alpha: 0.18)
                    : Colors.red.withValues(alpha: 0.12),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () async {
                _close();
                setState(() => _isLoggingOut = true);
                await Future.delayed(const Duration(milliseconds: 800));
                if (!mounted) return;
                await AuthService().signOut();
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                unawaited(Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (route) => false));
                setState(() => _isLoggingOut = false);
              },
              overlayColor:
                  WidgetStateProperty.all(Colors.red.withValues(alpha: 0.1)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).translate('menu.logout'),
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'v1.0.0',
            style: TextStyle(
              fontSize: 10,
              color: palette.textSecondary.withValues(alpha: 0.35),
            ),
          ),
        ],
      ),
    );
  }
}
