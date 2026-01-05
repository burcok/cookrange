import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'home/home.dart';
import 'profile/profile_screen.dart';
import 'community/community_screen.dart';
import '../core/services/navigation_provider.dart';
import '../core/providers/user_provider.dart';
import '../core/widgets/quick_actions_sheet.dart';
import '../core/widgets/voice_assistant_overlay.dart';
import '../core/services/auth_service.dart';
import '../core/providers/theme_provider.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _menuController;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    // Initialize with correct index
    final nav = context.read<NavigationProvider>();
    _pageController = PageController(initialPage: nav.currentIndex);
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Optimize startup: Defer user loading to avoid blocking the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use efficient listener
      final nav = context.read<NavigationProvider>();
      nav.addListener(_handleNavChange);

      // Load user data in background with slight delay to prioritize UI rendering
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) context.read<UserProvider>().loadUser();
      });
    });
  }

  void _handleNavChange() {
    if (!mounted) return;
    final nav = context.read<NavigationProvider>();

    // Sync Menu Animation
    if (nav.isMenuOpen &&
        _menuController.status != AnimationStatus.forward &&
        _menuController.status != AnimationStatus.completed) {
      _menuController.forward();
    } else if (!nav.isMenuOpen &&
        _menuController.status != AnimationStatus.reverse &&
        _menuController.status != AnimationStatus.dismissed) {
      _menuController.reverse();
    }

    // Handle Profile Navigation (Index 3)
    if (nav.currentIndex == 3) {
      // Reset to Home immediately so bottom bar doesn't get stuck selecting profile
      nav.setIndex(0);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    // Sync PageController only for swipeable pages
    if (nav.currentIndex <= 1 && _pageController.hasClients) {
      if (_pageController.page?.round() != nav.currentIndex) {
        // Only animate if the difference is significant to avoid fighting with user swipe
        if ((_pageController.page! - nav.currentIndex).abs() > 0.1) {
          _pageController.animateToPage(
            nav.currentIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final currentIndex = navigationProvider.currentIndex;

    // Ensure PageController is in sync with provider (fixes hot reload issue)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients &&
          currentIndex <= 1 &&
          _pageController.page?.round() != currentIndex) {
        _pageController.jumpToPage(currentIndex);
      }
    });

    return Material(
      color: const Color(0xFFFCFBF9), // Base background color
      child: Stack(
        children: [
          // 1. Background Blobs
          _buildBackgroundGlows(context),

          // 2. Main content with PageView and Swipe
          Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Conditionally render body based on index
                if (currentIndex <= 1)
                  PageView(
                    controller: _pageController,
                    allowImplicitScrolling: true, // Pre-cache pages
                    physics: const ClampingScrollPhysics(), // Native feel
                    onPageChanged: (index) {
                      // Sync provider when user swipes
                      if (navigationProvider.currentIndex != index) {
                        navigationProvider.setIndex(index);
                      }
                    },
                    children: [
                      const HomeScreen(),
                      const CommunityScreen(),
                    ],
                  ),

                // Pass our custom tap handler to the sheet if possible or ensure it uses provider
                const QuickActionsSheet(),
              ],
            ),
          ),

          // 3. Floating UI Layers
          if (navigationProvider.isVoiceAssistantOpen)
            const VoiceAssistantOverlay(),

          // Menu with AnimationController
          AnimatedBuilder(
            animation: _menuController,
            builder: (context, child) {
              if (_menuController.isDismissed) return const SizedBox.shrink();
              return _buildSideMenu(context, navigationProvider);
            },
          ),

          // 4. Logout Loading Overlay
          if (_isLoggingOut)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: CircularProgressIndicator(
                  color: context.watch<ThemeProvider>().primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSideMenu(BuildContext context, NavigationProvider nav) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dimmed Background - Fade Transition
          FadeTransition(
            opacity: _menuController,
            child: GestureDetector(
              onTap: () => nav.toggleMenu(false),
              onHorizontalDragEnd: (details) {
                if ((details.primaryVelocity ?? 0) < -300) {
                  nav.toggleMenu(false);
                }
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          // Menu Content - Slide Transition
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _menuController,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            )),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                // Check for left swipe
                if (details.delta.dx < -10) {
                  nav.toggleMenu(false);
                }
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.75,
                height: double.infinity,
                color: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context).translate('menu.title'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E3A59),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 32, color: Colors.black),
                          onPressed: () => nav.toggleMenu(false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    _buildMenuItem(Icons.person_outline,
                        AppLocalizations.of(context).translate('menu.account'),
                        () {
                      nav.toggleMenu(false);
                      // Push Directly
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()),
                      );
                    }),
                    _buildMenuItem(
                        Icons.history,
                        AppLocalizations.of(context).translate('menu.history'),
                        () {}),
                    _buildMenuItem(
                        Icons.favorite_border,
                        AppLocalizations.of(context)
                            .translate('menu.favorites'),
                        () {}),
                    _buildMenuItem(
                        Icons.help_outline,
                        AppLocalizations.of(context).translate('menu.help'),
                        () {}),
                    const Spacer(),
                    _buildMenuItem(Icons.logout,
                        AppLocalizations.of(context).translate('menu.logout'),
                        () async {
                      // Close menu first
                      nav.toggleMenu(false);

                      // Show loading state
                      setState(() {
                        _isLoggingOut = true;
                      });

                      // Simulate a small delay for better UX (optional, but requested)
                      await Future.delayed(const Duration(seconds: 2));

                      final navigator = Navigator.of(context);
                      await AuthService().signOut();

                      if (mounted) {
                        setState(() {
                          _isLoggingOut = false;
                        });
                        await navigator.pushNamedAndRemoveUntil(
                            '/login', (route) => false);
                      }
                    }, isDestructive: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap,
      {bool isDestructive = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon,
          color: isDestructive ? Colors.red : const Color(0xFF2E3A59),
          size: 28),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : const Color(0xFF2E3A59),
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildBackgroundGlows(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return RepaintBoundary(
      child: Container(
        color: const Color(0xFFFCFBF9),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -50,
              child: _glowBlob(
                  300,
                  context
                      .watch<ThemeProvider>()
                      .primaryColor
                      .withValues(alpha: 0.2)),
            ),
            Positioned(
              top: size.height * 0.4,
              left: -100,
              child: _glowBlob(
                  350,
                  context
                      .watch<ThemeProvider>()
                      .primaryColor
                      .withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 50,
              right: -80,
              child: _glowBlob(
                  320,
                  context
                      .watch<ThemeProvider>()
                      .primaryColor
                      .withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
