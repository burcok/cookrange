import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'home/home.dart';
import 'community/community_screen.dart';
import '../core/providers/navigation_provider.dart';
import '../core/providers/user_provider.dart';
import '../core/widgets/quick_actions_sheet.dart';
import '../core/widgets/voice_assistant_overlay.dart';
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
    final nav = context.read<NavigationProvider>();
    _pageController = PageController(initialPage: nav.currentIndex);
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      nav.addListener(_handleNavChange);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) context.read<UserProvider>().refreshUser();
      });
    });
  }

  void _handleNavChange() {
    if (!mounted) return;
    final nav = context.read<NavigationProvider>();

    if (nav.isMenuOpen &&
        _menuController.status != AnimationStatus.forward &&
        _menuController.status != AnimationStatus.completed) {
      _menuController.forward();
    } else if (!nav.isMenuOpen &&
        _menuController.status != AnimationStatus.reverse &&
        _menuController.status != AnimationStatus.dismissed) {
      _menuController.reverse();
    }

    if (nav.currentIndex <= 1 && _pageController.hasClients) {
      if ((_pageController.page! - nav.currentIndex).abs() > 0.1) {
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
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFFCFBF9);

    return Material(
      color: scaffoldBg,
      child: Stack(
        children: [
          // Background blobs — rebuilt only when Theme changes (no nav subscription)
          _buildBackgroundGlows(context),

          // Scaffold is static — no NavigationProvider.watch here
          Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Only rebuilds when currentIndex crosses the <=1 boundary
                Selector<NavigationProvider, bool>(
                  selector: (_, nav) => nav.currentIndex <= 1,
                  builder: (context, showPageView, _) {
                    if (!showPageView) return const SizedBox.shrink();
                    return PageView(
                      controller: _pageController,
                      allowImplicitScrolling: true,
                      physics: const ClampingScrollPhysics(),
                      onPageChanged: (index) {
                        context.read<NavigationProvider>().setIndex(index);
                      },
                      children: const [
                        HomeScreen(),
                        CommunityScreen(),
                      ],
                    );
                  },
                ),
                const QuickActionsSheet(),
              ],
            ),
          ),

          // Voice assistant — only rebuilds when visibility changes
          Selector<NavigationProvider, bool>(
            selector: (_, nav) => nav.isVoiceAssistantOpen,
            builder: (_, isOpen, __) =>
                isOpen ? const VoiceAssistantOverlay() : const SizedBox.shrink(),
          ),

          // Menu — driven by AnimationController; no nav watch in parent needed
          AnimatedBuilder(
            animation: _menuController,
            builder: (context, child) {
              if (_menuController.isDismissed) return const SizedBox.shrink();
              return child!;
            },
            child: SideMenu(
              navProvider: context.read<NavigationProvider>(),
              animationController: _menuController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: ExcludeSemantics(
      child: Container(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFFCFBF9),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -50,
              child: _glowBlob(300, primary.withValues(alpha: 0.2)),
            ),
            Positioned(
              top: size.height * 0.4,
              left: -100,
              child: _glowBlob(350, primary.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 50,
              right: -80,
              child: _glowBlob(320, primary.withValues(alpha: 0.15)),
            ),
          ],
        ),
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
