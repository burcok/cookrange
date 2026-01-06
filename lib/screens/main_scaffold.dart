import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'home/home.dart';
import 'profile/profile_screen.dart';
import 'community/community_screen.dart';
import '../core/services/navigation_provider.dart';
import '../core/providers/user_provider.dart';
import '../core/widgets/quick_actions_sheet.dart';
import '../core/widgets/voice_assistant_overlay.dart';

import '../core/providers/theme_provider.dart';
import '../core/widgets/side_menu.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _menuController;

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
              return SideMenu(
                navProvider: navigationProvider,
                animationController: _menuController,
              );
            },
          ),
        ],
      ),
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
