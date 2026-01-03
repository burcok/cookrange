import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/navigation_provider.dart';
import '../../constants.dart';
import '../localization/app_localizations.dart';

class QuickActionsSheet extends StatefulWidget {
  const QuickActionsSheet({super.key});

  @override
  State<QuickActionsSheet> createState() => _QuickActionsSheetState();
}

class _QuickActionsSheetState extends State<QuickActionsSheet> {
  final DraggableScrollableController _controller =
      DraggableScrollableController();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();

    return Listener(
      onPointerUp: (event) {
        if (!_controller.isAttached) return;
        final extent = _controller.size;
        final snapPoints = [0.12, 0.35, 0.65];
        double nearest = snapPoints[0];
        double minDistance = (extent - snapPoints[0]).abs();

        for (var point in snapPoints) {
          final distance = (extent - point).abs();
          if (distance < minDistance) {
            minDistance = distance;
            nearest = point;
          }
        }
        _animateToSnap(nearest);
      },
      child: DraggableScrollableSheet(
        controller: _controller,
        initialChildSize: 0.12,
        minChildSize: 0.12,
        maxChildSize: 0.65,
        snap: false,
        builder: (context, scrollController) {
          // REMOVED: ClipRRect here was clipping the overflowing FAB
          return Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Glass Base Layer
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(36)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              Colors.white.withAlpha(160), // Translucent white
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(36)),
                          border: Border.all(
                            color: Colors.white.withAlpha(100),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content Layer
                CustomScrollView(
                  controller: scrollController,
                  clipBehavior: Clip.none, // Vital for the FAB to overflow
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _BottomBarDelegate(
                        height: 115,
                        child: Container(
                          // No background here, using the base glass layer
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildIntegratedBottomBar(context, nav),
                              Center(child: _buildHandle()),
                              const SizedBox(height: 5),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        child: Column(
                          children: [
                            Center(
                              child: Text(
                                AppLocalizations.of(context)
                                    .translate('quick_actions.title'),
                                style: TextStyle(
                                  fontSize:
                                      24, // Optimized scale: using 24 directly or ScreenUtil if available
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2E3A59),
                                  letterSpacing: -0.5,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            _buildActionItem(
                              context,
                              Icons.shopping_basket_outlined,
                              AppLocalizations.of(context)
                                  .translate('quick_actions.shopping_list'),
                              () {
                                nav.setIndex(2);
                                _collapse();
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildActionItem(
                              context,
                              Icons.settings_outlined,
                              AppLocalizations.of(context)
                                  .translate('quick_actions.settings'),
                              () {
                                nav.setIndex(3);
                                _collapse();
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildActionItem(
                              context,
                              Icons.history_outlined,
                              AppLocalizations.of(context)
                                  .translate('quick_actions.history'),
                              () {
                                _collapse();
                              },
                            ),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntegratedBottomBar(
      BuildContext context, NavigationProvider nav) {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNavBarItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: AppLocalizations.of(context)
                      .translate('quick_actions.home'),
                  index: 0,
                  currentIndex: nav.currentIndex,
                  onTap: () {
                    nav.setIndex(0);
                    _collapse();
                  },
                ),
                const SizedBox(width: 140),
                _buildNavBarItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: AppLocalizations.of(context)
                      .translate('quick_actions.community'),
                  index: 1,
                  currentIndex: nav.currentIndex,
                  onTap: () {
                    nav.setIndex(1);
                    _collapse();
                  },
                ),
              ],
            ),
          ),
          Positioned(
            top: -30, // Move FAB exactly where it needs to be
            child: _buildAssistantFAB(nav),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBarItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int currentIndex,
    required VoidCallback onTap,
  }) {
    final isSelected = index == currentIndex;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? primaryColor : Colors.black87,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.black87,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantFAB(NavigationProvider nav) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97300), Color(0xFFF98E30)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97300).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: RawMaterialButton(
        shape: const CircleBorder(),
        onPressed: () {
          if (!nav.isVoiceAssistantOpen) {
            nav.toggleVoiceAssistant(true);
          }
        },
        child: const Icon(Icons.graphic_eq, color: Colors.white, size: 36),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.grey[400]!.withAlpha(100),
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  void _animateToSnap(double extent) {
    if (!_controller.isAttached) return;
    _controller.animateTo(
      extent,
      duration: const Duration(milliseconds: 500),
      curve: const Cubic(0.175, 0.885, 0.32, 1.275),
    );
  }

  void _collapse() => _animateToSnap(0.12);

  Widget _buildActionItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(120),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(100)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF2E3A59), size: 24),
            const SizedBox(width: 20),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E3A59),
                fontFamily: 'Poppins',
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _BottomBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _BottomBarDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _BottomBarDelegate oldDelegate) {
    return true;
  }
}
