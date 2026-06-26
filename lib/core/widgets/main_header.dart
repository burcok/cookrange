import 'package:cookrange/screens/chat/chat_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/chat_service.dart';
import '../../screens/notifications/notification_screen.dart';

class MainHeader extends StatelessWidget {
  const MainHeader({super.key});

  static PageRoute<void> _slideUpRoute(Widget page) {
    return PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 280),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.menu, size: 28, color: iconColor),
          onPressed: () => context.read<NavigationProvider>().toggleMenu(true),
        ),
        Row(
          children: [
            StreamBuilder<int>(
              stream: NotificationService().getUnreadCountStream(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined,
                          size: 28, color: iconColor),
                      onPressed: () => Navigator.of(context).push(
                        _slideUpRoute(const NotificationScreen()),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _badge(unreadCount),
                      ),
                  ],
                );
              },
            ),
            StreamBuilder<int>(
              stream: ChatService().getUnreadMessageCountStream(
                  FirebaseAuth.instance.currentUser?.uid ?? ''),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                return Stack(
                  children: [
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline,
                          size: 28, color: iconColor),
                      onPressed: () => Navigator.of(context).push(
                        _slideUpRoute(const ChatListScreen()),
                      ),
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: _badge(unreadCount),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _badge(int count) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: count > 9 ? '9' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (count > 9)
              const TextSpan(
                text: '+',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
