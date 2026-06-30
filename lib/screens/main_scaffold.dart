import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'home/home.dart';
import 'community/community_screen.dart';
import 'profile/profile_screen.dart';
import '../core/providers/navigation_provider.dart';
import '../core/providers/user_provider.dart';
import '../core/services/whats_new_service.dart';
import '../core/widgets/quick_actions_sheet.dart';
import '../core/widgets/voice_assistant_overlay.dart';
import '../core/widgets/side_menu.dart';
import '../core/widgets/whats_new_sheet.dart';
import 'profile/widgets/consent_prompt_sheet.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold>
    with SingleTickerProviderStateMixin {
  late AnimationController _menuController;
  NavigationProvider? _navigationProvider;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _navigationProvider = context.read<NavigationProvider>();
      _navigationProvider?.addListener(_handleNavChange);
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) context.read<UserProvider>().refreshUser();
      });
      _maybeShowWhatsNew();
    });
  }

  Future<void> _maybeShowWhatsNew() async {
    if (!mounted) return;
    final should = await WhatsNewService().shouldShow();
    if (!mounted) return;
    // Small delay so the scaffold renders fully before the sheet appears.
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    if (should) {
      // Show "What's New" this launch; the consent nudge waits for next time.
      unawaited(WhatsNewSheetContent.show(context));
    } else {
      // Otherwise surface the one-time privacy/consent nudge.
      unawaited(ConsentPromptSheet.maybeShow(context));
    }
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
  }

  @override
  void dispose() {
    _navigationProvider?.removeListener(_handleNavChange);
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? const Color(0xFF0D1117) : const Color(0xFFFCFBF9);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        final nav = context.read<NavigationProvider>();

        // 1. Close the side menu if open
        if (nav.isMenuOpen) {
          nav.toggleMenu(false);
          return;
        }

        // 2. Return to Home tab from any other tab
        if (nav.currentIndex != NavigationProvider.homeTab) {
          nav.setIndex(NavigationProvider.homeTab);
          return;
        }

        // 3. Exit the app (Android)
        if (Platform.isAndroid) SystemNavigator.pop();
      },
      child: Material(
        color: scaffoldBg,
        child: Stack(
          children: [
            _buildBackgroundGlows(context),

            // ── Main scaffold ────────────────────────────────────────────────
            Scaffold(
              backgroundColor: Colors.transparent,
              extendBody: true,
              body: Builder(
                builder: (context) {
                  final deviceBottom = MediaQuery.viewPaddingOf(context).bottom;
                  const navBarHeight = 72.0;
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(
                      padding: mq.padding
                          .copyWith(bottom: deviceBottom + navBarHeight),
                    ),
                    child: Stack(
                      children: [
                        // Tab screens — IndexedStack keeps all 3 alive so
                        // switching tabs is instant with no rebuild.
                        Selector<NavigationProvider, int>(
                          selector: (_, nav) => nav.currentIndex,
                          builder: (_, index, __) => IndexedStack(
                            index: index,
                            children: const [
                              HomeScreen(),
                              CommunityScreen(),
                              ProfileScreen(),
                            ],
                          ),
                        ),

                        // QuickActionsSheet (navbar) always on top of tabs.
                        const QuickActionsSheet(),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── Voice assistant overlay ──────────────────────────────────────
            Selector<NavigationProvider, bool>(
              selector: (_, nav) => nav.isVoiceAssistantOpen,
              builder: (_, isOpen, __) => isOpen
                  ? const VoiceAssistantOverlay()
                  : const SizedBox.shrink(),
            ),

            // ── Side menu — kept in tree (Offstage) for zero-rebuild opens ──
            AnimatedBuilder(
              animation: _menuController,
              builder: (context, child) => Offstage(
                offstage: _menuController.isDismissed,
                child: child,
              ),
              child: SideMenu(
                navProvider: context.read<NavigationProvider>(),
                animationController: _menuController,
              ),
            ),
          ],
        ),
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
