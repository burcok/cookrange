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

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUser();
    });
  }

  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const ShoppingListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.watch<NavigationProvider>();
    final currentIndex = navigationProvider.currentIndex;

    return Stack(
      children: [
        // Background Blobs
        _buildBackgroundGlows(context),

        Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent, // Allow blooms to show through
          body: IndexedStack(
            index: currentIndex,
            children: _screens,
          ),
        ),
        const QuickActionsSheet(),
        if (navigationProvider.isVoiceAssistantOpen)
          const VoiceAssistantOverlay(),
        if (navigationProvider.isMenuOpen)
          _buildSideMenu(context, navigationProvider),
      ],
    );
  }

  Widget _buildSideMenu(BuildContext context, NavigationProvider nav) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent background
          GestureDetector(
            onTap: () => nav.toggleMenu(false),
            child: Container(
              color: Colors.black.withAlpha(120),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          // White Menu
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
                    nav.setIndex(3);
                  }),
                  _buildMenuItem(Icons.history, "History", () {}),
                  _buildMenuItem(Icons.favorite_border, "Favorites", () {}),
                  _buildMenuItem(Icons.help_outline, "Help", () {}),
                  const Spacer(),
                  _buildMenuItem(Icons.logout, "Logout", () {},
                      isDestructive: true),
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
    return Container(
      color: const Color(0xFFFCFBF9), // Base background color
      child: Stack(
        children: [
          // Top right blob
          Positioned(
            top: -100,
            right: -50,
            child: _glowBlob(300, const Color(0xFFF97300).withAlpha(60)),
          ),
          // Middle left blob
          Positioned(
            top: size.height * 0.4,
            left: -100,
            child: _glowBlob(350, const Color(0xFFF98E30).withAlpha(55)),
          ),
          // Bottom right blob
          Positioned(
            bottom: 50,
            right: -80,
            child: _glowBlob(320, const Color(0xFFF97300).withAlpha(50)),
          ),
        ],
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
          colors: [color, color.withAlpha(0)],
        ),
      ),
    );
  }

  // Unused methods removed as they are now integrated into QuickActionsSheet
}
