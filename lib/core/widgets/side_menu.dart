import 'dart:ui';
import 'package:cookrange/screens/chat/chat_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/navigation_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/providers/user_provider.dart';
import '../../screens/profile/profile_screen.dart';
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

  void _handleNavigation(BuildContext context, VoidCallback action) {
    widget.navProvider.toggleMenu(false);
    // Add a small delay for the menu close animation to start
    Future.delayed(const Duration(milliseconds: 150), () {
      action();
    });
  }

  void _navigateToMainTab(int index) {
    _handleNavigation(context, () {
      // Pop until we are at the root (MainScaffold)
      Navigator.of(context).popUntil((route) => route.isFirst);
      widget.navProvider.setIndex(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<UserProvider>().user;

    // Design Colors
    final primaryColor = theme.primaryColor;

    if (widget.animationController.isDismissed) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Dimmed Background with Fade
          FadeTransition(
            opacity: widget.animationController,
            child: GestureDetector(
              onTap: () => widget.navProvider.toggleMenu(false),
              child: Container(
                color: Colors.black.withOpacity(0.4), // Slightly lighter dim
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),

          // 2. Glass Sidebar with Slide
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: widget.animationController,
              curve: Curves.easeOutCubic, // Smoother curve
              reverseCurve: Curves.easeInCubic,
            )),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx < -10) {
                  widget.navProvider.toggleMenu(false);
                }
              },
              // OPTIMIZATION: Use ClipRect instead of ClipRRect as we don't need rounded corners here
              // OPTIMIZATION: Wrapped in RepaintBoundary to cache the rasterized static menu
              child: RepaintBoundary(
                child: ClipRect(
                  child: BackdropFilter(
                    // OPTIMIZATION: Reduced blur sigma from 20 to 5 for better performance
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.80,
                      constraints: const BoxConstraints(maxWidth: 320),
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F172A).withOpacity(0.85)
                            : Colors.white.withOpacity(0.9),
                        border: Border(
                          right: BorderSide(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.white.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            // OPTIMIZATION: Reduced blur radius from 32 to 24
                            blurRadius: 24,
                            offset: const Offset(8, 0),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            // Profile Section
                            _buildProfileSection(
                                context, user, isDark, primaryColor),

                            // Navigation Items
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader("MENÜ"),
                                    _buildMenuItem(
                                      context,
                                      icon: Icons.home_rounded,
                                      label: "Ana Sayfa",
                                      isDark: isDark,
                                      primaryColor: primaryColor,
                                      onTap: () => _navigateToMainTab(0),
                                    ),
                                    _buildMenuItem(
                                      context,
                                      icon: Icons.restaurant_menu_rounded,
                                      label: "Yemek Planı",
                                      isDark: isDark,
                                      primaryColor: primaryColor,
                                      onTap: () {
                                        _handleNavigation(context, () {
                                          // TODO: Implement Meal Plan Screen
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    "Yemek Planı yakında gelecek!")),
                                          );
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 32),
                                    _buildSectionHeader("Sosyal"),
                                    _buildMenuItem(
                                      context,
                                      icon: Icons.chat_bubble_rounded,
                                      label: "Sohbet",
                                      isDark: isDark,
                                      primaryColor: primaryColor,
                                      onTap: () =>
                                          _handleNavigation(context, () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const ChatListScreen()));
                                      }),
                                    ),
                                    _buildMenuItem(
                                      context,
                                      icon: Icons.groups_rounded,
                                      label: "Topluluk",
                                      isDark: isDark,
                                      primaryColor: primaryColor,
                                      onTap: () => _navigateToMainTab(1),
                                    ),
                                    const SizedBox(height: 32),
                                    _buildSectionHeader("HESAP & DİĞER"),
                                    _buildSimpleMenuItem(
                                      context,
                                      icon: Icons.person_rounded,
                                      label: "Hesabım",
                                      isDark: isDark,
                                      onTap: () =>
                                          _handleNavigation(context, () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const ProfileScreen()));
                                      }),
                                    ),
                                    _buildSimpleMenuItem(
                                      context,
                                      icon: Icons.settings_rounded,
                                      label: "Ayarlar",
                                      isDark: isDark,
                                      onTap: () =>
                                          _handleNavigation(context, () {
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    const SettingsScreen()));
                                      }),
                                    ),
                                    _buildSimpleMenuItem(
                                      context,
                                      icon: Icons.help_outline_rounded,
                                      label: "Yardım",
                                      isDark: isDark,
                                      onTap: () {
                                        // TODO: Help
                                      },
                                    ),
                                    _buildSimpleMenuItem(
                                      context,
                                      icon: Icons.info_outline_rounded,
                                      label: "Uygulama Hakkında",
                                      isDark: isDark,
                                      onTap: () {
                                        // TODO: About
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Footer
                            _buildFooter(context, isDark, primaryColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Global Logout Spinner
          if (_isLoggingOut)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(
      BuildContext context, dynamic user, bool isDark, Color primaryColor) {
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName ?? "Unknown";
    final isPro =
        true; // Hardcoded for design as requested, or logic: user?.isPro ?? false

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 32),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow Effect
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                // Avatar
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.white.withOpacity(0.8),
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            // OPTIMIZATION: Resize image in memory to avoid full-res decoding
                            memCacheWidth: 300,
                            placeholder: (context, url) =>
                                Container(color: Colors.grey.shade200),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.person, size: 40),
                          )
                        : Container(
                            color: Colors.grey.shade200,
                            child: Icon(Icons.person,
                                size: 48, color: Colors.grey.shade400),
                          ),
                  ),
                ),
                // Online Indicator
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
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
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 4),
          if (isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Pro Üye",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDark,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          overlayColor:
              MaterialStateProperty.all(primaryColor.withOpacity(0.1)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withOpacity(0.03)
                  : Colors.white.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.03)
                    : Colors.white.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: Colors.grey.shade500, // Inactive color
                ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade200 : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(
        icon,
        size: 22,
        color: Colors.grey.shade400,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.1),
          ),
        ),
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                // Close menu
                widget.navProvider.toggleMenu(false);
                setState(() => _isLoggingOut = true);

                await Future.delayed(const Duration(seconds: 1)); // UX delay

                if (!mounted) return;
                await AuthService().signOut();

                if (mounted) {
                  Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                  setState(() => _isLoggingOut = false);
                }
              },
              borderRadius: BorderRadius.circular(16),
              overlayColor:
                  MaterialStateProperty.all(Colors.red.withOpacity(0.1)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.red.withOpacity(0.1)
                      : Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.red.withOpacity(0.2)
                        : Colors.red.withOpacity(0.1),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Çıkış Yap",
                      style: TextStyle(
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
            "Versiyon 1.0.0",
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}
