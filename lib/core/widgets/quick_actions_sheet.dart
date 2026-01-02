import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/navigation_provider.dart';
import '../../constants.dart';

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

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.65,
      snap: true,
      snapSizes: const [0.12, 0.35, 0.65],
      builder: (context, scrollController) {
        return Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.none,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(36)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: CustomScrollView(
              controller: scrollController,
              clipBehavior: Clip.none,
              slivers: [
                // Pinned Bottom Bar + FAB
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _BottomBarDelegate(
                    height: 135,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(36)),
                      ),
                      child: Column(
                        children: [
                          _buildIntegratedBottomBar(context, nav),
                          const SizedBox(height: 10),
                          Center(child: _buildHandle()),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
                // Scrollable Actions Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        Center(
                          child: Text(
                            "Quick Actions",
                            style: TextStyle(
                              fontSize: _scale(context, 24),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2E3A59),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildActionItem(
                          context,
                          Icons.shopping_basket_outlined,
                          "Shopping List",
                          () {
                            nav.setIndex(2);
                            _collapse();
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildActionItem(
                          context,
                          Icons.settings_outlined,
                          "Settings",
                          () {
                            nav.setIndex(3);
                            _collapse();
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildActionItem(
                          context,
                          Icons.history_outlined,
                          "History",
                          () {
                            _collapse();
                          },
                        ),
                        const SizedBox(
                            height: 100), // Padding for scroll bottom
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIntegratedBottomBar(
      BuildContext context, NavigationProvider nav) {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Navigation Items Row
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildNavBarItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                  currentIndex: nav.currentIndex,
                  onTap: () {
                    nav.setIndex(0);
                    _collapse();
                  },
                ),
                const SizedBox(width: 140), // More breathing room
                _buildNavBarItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Community',
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

          // FAB positioned in the middle
          Positioned(
            top: -20, // Floating look relative to the sheet top
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
            color: isSelected ? primaryColor : Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.grey[400],
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
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  double _scale(BuildContext context, double value) {
    return value * (MediaQuery.of(context).size.width / 390.0);
  }

  void _collapse() {
    _controller.animateTo(0.12,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic);
  }

  Widget _buildActionItem(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F1F1)),
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
            Icon(icon, color: const Color(0xFF2E3A59), size: 28),
            const SizedBox(width: 20),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E3A59),
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
