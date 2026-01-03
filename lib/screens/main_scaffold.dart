import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home/home.dart';
import 'explore/explore_screen.dart';
import 'shopping/shopping_list_screen.dart';
import 'profile/profile_screen.dart';
import '../core/services/navigation_provider.dart';
import '../core/providers/user_provider.dart';
import '../core/widgets/quick_actions_sheet.dart';
import '../core/widgets/voice_assistant_overlay.dart';
import '../core/services/auth_service.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late PageController _pageController;

  final List<Widget> _swipeableScreens = [
    const HomeScreen(),
    const ExploreScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

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
        _pageController.animateToPage(
          nav.currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final currentIndex = navigationProvider.currentIndex;

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
                // Conditionally render body based on index
                if (currentIndex <= 1)
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if (currentIndex == 0) {
                        if (velocity > 300) {
                          // Swipe Right on Home -> Open Menu
                          navigationProvider.toggleMenu(true);
                        } else if (velocity < -300) {
                          // Swipe Left on Home -> Explore (1)
                          navigationProvider.setIndex(1);
                        }
                      } else if (currentIndex == 1) {
                        if (velocity > 300) {
                          // Swipe Right on Explore -> Home (0)
                          navigationProvider.setIndex(0);
                        }
                        // Block swipe left (to Shopping)
                      }
                    },
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        // Sync provider when user swipes
                        if (navigationProvider.currentIndex != index) {
                          navigationProvider.setIndex(index);
                        }
                      },
                      // Setting physics to NeverScrollable allows our GestureDetector to win
                      physics: const NeverScrollableScrollPhysics(),
                      children: _swipeableScreens,
                    ),
                  )
                else if (currentIndex == 2)
                  const ShoppingListScreen()
                else
                  const SizedBox.shrink(),
                // Pass our custom tap handler to the sheet if possible or ensure it uses provider
                const QuickActionsSheet(),
              ],
            ),
          ),

          // 3. Floating UI Layers
          if (navigationProvider.isVoiceAssistantOpen)
            const VoiceAssistantOverlay(),

          if (navigationProvider.isMenuOpen)
            _buildSideMenu(context, navigationProvider),
        ],
      ),
    );
  }

  Widget _buildSideMenu(BuildContext context, NavigationProvider nav) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => nav.toggleMenu(false),
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: -1.0, end: 0.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset:
                    Offset(value * MediaQuery.of(context).size.width * 0.75, 0),
                child: child,
              );
            },
            child: Container(
              width: MediaQuery.of(context).size.width * 0.75,
              height: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Menu",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E3A59),
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
                  _buildMenuItem(Icons.person_outline, "Account", () {
                    nav.toggleMenu(false);
                    // Push Directly
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  }),
                  _buildMenuItem(Icons.history, "History", () {}),
                  _buildMenuItem(Icons.favorite_border, "Favorites", () {}),
                  _buildMenuItem(Icons.help_outline, "Help", () {}),
                  const Spacer(),
                  _buildMenuItem(Icons.logout, "Logout", () async {
                    nav.toggleMenu(false);
                    final navigator = Navigator.of(context);
                    await AuthService().signOut();
                    if (mounted) {
                      await navigator.pushNamedAndRemoveUntil(
                          '/login', (route) => false);
                    }
                  }, isDestructive: true),
                ],
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
                  300, const Color(0xFFF97300).withValues(alpha: 0.2)),
            ),
            Positioned(
              top: size.height * 0.4,
              left: -100,
              child: _glowBlob(
                  350, const Color(0xFFF98E30).withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 50,
              right: -80,
              child: _glowBlob(
                  320, const Color(0xFFF97300).withValues(alpha: 0.15)),
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
