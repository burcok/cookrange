import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../localization/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../theme/app_palette.dart';
import '../../screens/home/food_scan_screen.dart';
import '../../screens/home/barcode_scan_screen.dart';
import '../../screens/home/nutrition_analytics_screen.dart';
import '../../screens/shopping/shopping_list_screen.dart';
import '../../screens/recipe/favorites_screen.dart';

class QuickActionsSheet extends StatefulWidget {
  const QuickActionsSheet({super.key});

  @override
  State<QuickActionsSheet> createState() => _QuickActionsSheetState();
}

class _QuickActionsSheetState extends State<QuickActionsSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  static const double _kExpanded = 0.62;

  // Collapsed fraction: handle (20px) + nav row (52px) + safe-area bottom
  double _collapsed(BuildContext context) {
    final sa = MediaQuery.viewPaddingOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height;
    return ((72.0 + sa + 8.0) / h).clamp(0.11, 0.24);
  }

  static PageRoute<T> _slideUp<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(anim),
          child: child,
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    if (!_controller.isAttached) return;
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _collapse(BuildContext ctx) => _animateTo(_collapsed(ctx));

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = context.watch<ThemeProvider>().primaryColor;
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    final collapsed = _collapsed(context);

    return Listener(
      onPointerUp: (_) {
        if (!_controller.isAttached) return;
        final mid = (collapsed + _kExpanded) / 2;
        _animateTo(_controller.size > mid ? _kExpanded : collapsed);
      },
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: collapsed,
        minChildSize: collapsed,
        maxChildSize: _kExpanded,
        builder: (ctx, sc) => Material(
          color: Colors.transparent,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Glass card ────────────────────────────────────────────────
              Positioned.fill(child: _GlassCard(isDark: isDark)),

              // ── Scrollable content ────────────────────────────────────────
              Positioned.fill(
                child: CustomScrollView(
                  controller: sc,
                  physics: const ClampingScrollPhysics(),
                  slivers: [
                    // Pinned nav bar (handle + Home / Community / Profile)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _NavBarDelegate(
                        isDark: isDark,
                        currentIndex: nav.currentIndex,
                        primary: primary,
                        bottomSafeArea: bottomSafeArea,
                      ),
                    ),
                    // Quick-action tiles (visible only when expanded)
                    SliverToBoxAdapter(
                      child: _QuickActionsGrid(
                        isDark: isDark,
                        // Camera/scanner pages: root navigator (covers navbar).
                        onFullScreen: (page) {
                          _collapse(context);
                          Navigator.of(context).push(_slideUp(page));
                        },
                        // All in-app pages go via root navigator now that the
                        // nested navigator has been removed.
                        onInner: (page) {
                          _collapse(context);
                          Navigator.of(context).push(_slideUp(page));
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ── AI assistant FAB — floats 28 px above sheet top ───────────
              Positioned(
                top: -28,
                left: 0,
                right: 0,
                child: Center(
                  child: _AssistantFAB(nav: nav, primary: primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Glass card background ────────────────────────────────────────────────────

class _GlassCard extends StatelessWidget {
  final bool isDark;
  const _GlassCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0B1120).withValues(alpha: 0.93)
                : Colors.white.withValues(alpha: 0.87),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.52 : 0.10),
                blurRadius: 44,
                offset: const Offset(0, -10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pinned nav-bar delegate ──────────────────────────────────────────────────

class _NavBarDelegate extends SliverPersistentHeaderDelegate {
  // 20 px overhead (handle pill area) + 52 px nav row
  static const double _kBase = 72.0;

  final bool isDark;
  final int currentIndex;
  final Color primary;
  final double bottomSafeArea;

  const _NavBarDelegate({
    required this.isDark,
    required this.currentIndex,
    required this.primary,
    required this.bottomSafeArea,
  });

  @override
  double get minExtent => _kBase + bottomSafeArea;
  @override
  double get maxExtent => _kBase + bottomSafeArea;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final inactive =
        isDark ? const Color(0xFF6B7280) : const Color(0xFFB0B8C8);

    return Column(
      children: [
        // Drag handle
        const SizedBox(height: 11),
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : Colors.grey.shade400.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 5),

        // Nav items – [Home] [80 px FAB gap] [Community] — symmetric
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _NavBtn(
                  tabIndex: NavigationProvider.homeTab,
                  activeIcon: Icons.home_rounded,
                  inactiveIcon: Icons.home_outlined,
                  labelKey: 'menu.home',
                  currentIndex: currentIndex,
                  primary: primary,
                  inactive: inactive,
                ),
              ),
              const SizedBox(width: 80), // centred FAB gap
              Expanded(
                child: _NavBtn(
                  tabIndex: NavigationProvider.communityTab,
                  activeIcon: Icons.groups_rounded,
                  inactiveIcon: Icons.groups_outlined,
                  labelKey: 'menu.community',
                  currentIndex: currentIndex,
                  primary: primary,
                  inactive: inactive,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: bottomSafeArea),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _NavBarDelegate old) =>
      old.currentIndex != currentIndex ||
      old.primary != primary ||
      old.isDark != isDark ||
      old.bottomSafeArea != bottomSafeArea;
}

// ─── Single nav button ────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  final int tabIndex;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String labelKey;
  final int currentIndex;
  final Color primary;
  final Color inactive;

  const _NavBtn({
    required this.tabIndex,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.labelKey,
    required this.currentIndex,
    required this.primary,
    required this.inactive,
  });

  bool get _isActive => tabIndex == currentIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_isActive) {
          HapticFeedback.lightImpact();
          context.read<NavigationProvider>().setIndex(tabIndex);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Active-indicator pill
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            width: _isActive ? 28 : 0,
            height: _isActive ? 3 : 0,
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: primary,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          // Icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _isActive ? activeIcon : inactiveIcon,
              key: ValueKey(_isActive),
              size: 22,
              color: _isActive ? primary : inactive,
            ),
          ),
          const SizedBox(height: 3),
          // Label
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              fontWeight: _isActive ? FontWeight.w700 : FontWeight.w500,
              color: _isActive ? primary : inactive,
              fontFamily: 'Poppins',
            ),
            child: Text(
              AppLocalizations.of(context).translate(labelKey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AI assistant FAB ─────────────────────────────────────────────────────────

class _AssistantFAB extends StatelessWidget {
  final NavigationProvider nav;
  final Color primary;
  const _AssistantFAB({required this.nav, required this.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        nav.toggleVoiceAssistant(true);
      },
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withValues(alpha: 0.72)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.44),
              blurRadius: 26,
              spreadRadius: 2,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: const Icon(
          Icons.graphic_eq_rounded,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }
}

// ─── 3-column quick-action grid ───────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final bool isDark;
  final void Function(Widget page) onFullScreen;
  final void Function(Widget page) onInner;

  const _QuickActionsGrid({
    required this.isDark,
    required this.onFullScreen,
    required this.onInner,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      child: Column(
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              l10n.translate('quick_actions.title').toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.textSecondary.withValues(alpha: 0.65),
                letterSpacing: 1.3,
                fontFamily: 'Poppins',
              ),
            ),
          ),

          // 3 × 2 action grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _ActionTile(
                icon: Icons.restaurant_menu_rounded,
                color: const Color(0xFFFF6B35),
                label: l10n.translate('quick_actions.meal_scanner'),
                isDark: isDark,
                palette: palette,
                onTap: () => onFullScreen(const FoodScanScreen()),
              ),
              _ActionTile(
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFF6366F1),
                label: l10n.translate('quick_actions.barcode_scanner'),
                isDark: isDark,
                palette: palette,
                onTap: () => onFullScreen(const BarcodeScanScreen()),
              ),
              _ActionTile(
                icon: Icons.shopping_basket_rounded,
                color: const Color(0xFF10B981),
                label: l10n.translate('quick_actions.shopping_list'),
                isDark: isDark,
                palette: palette,
                onTap: () => onInner(const ShoppingListScreen()),
              ),
              _ActionTile(
                icon: Icons.bar_chart_rounded,
                color: const Color(0xFFF59E0B),
                label: l10n.translate('quick_actions.nutrition_analytics'),
                isDark: isDark,
                palette: palette,
                onTap: () => onInner(const NutritionAnalyticsScreen()),
              ),
              _ActionTile(
                icon: Icons.favorite_rounded,
                color: const Color(0xFFEC4899),
                label: l10n.translate('quick_actions.favorites'),
                isDark: isDark,
                palette: palette,
                onTap: () => onInner(const FavoritesScreen()),
              ),
              _ActionTile(
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF9CA3AF),
                label: l10n.translate('quick_actions.my_gym'),
                isDark: isDark,
                palette: palette,
                comingSoon: true,
                comingSoonLabel: l10n.translate('quick_actions.coming_soon'),
                onTap: null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Individual action tile (with press-scale animation) ──────────────────────

class _ActionTile extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isDark;
  final AppPalette palette;
  final VoidCallback? onTap;
  final bool comingSoon;
  final String? comingSoonLabel;

  const _ActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.isDark,
    required this.palette,
    required this.onTap,
    this.comingSoon = false,
    this.comingSoonLabel,
  });

  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      lowerBound: 0.94,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.comingSoon;
    return GestureDetector(
      onTapDown: disabled ? null : (_) => _press.reverse(),
      onTapUp: disabled
          ? null
          : (_) async {
              await _press.forward();
              if (widget.onTap != null && mounted) widget.onTap!();
            },
      onTapCancel: disabled ? null : () => _press.forward(),
      child: AnimatedBuilder(
        animation: _press,
        builder: (_, child) =>
            Transform.scale(scale: _press.value, child: child),
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: disabled ? 0.03 : 0.065)
                : Colors.white.withValues(alpha: disabled ? 0.35 : 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: disabled ? 0.04 : 0.09)
                  : Colors.white.withValues(alpha: 0.90),
              width: 1.5,
            ),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(
                          alpha: widget.isDark ? 0.20 : 0.07),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: disabled ? 0.07 : 0.15),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  widget.icon,
                  color: disabled
                      ? widget.color.withValues(alpha: 0.32)
                      : widget.color,
                  size: 26,
                ),
              ),
              const SizedBox(height: 9),
              // Label
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: disabled
                        ? widget.palette.textSecondary.withValues(alpha: 0.38)
                        : widget.palette.textPrimary,
                    fontFamily: 'Poppins',
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (disabled && widget.comingSoonLabel != null) ...[
                const SizedBox(height: 3),
                Text(
                  widget.comingSoonLabel!,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color:
                        widget.palette.textSecondary.withValues(alpha: 0.35),
                    fontFamily: 'Poppins',
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
