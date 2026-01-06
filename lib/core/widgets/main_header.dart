import 'package:cookrange/screens/chat/chat_list_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/navigation_provider.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/chat_service.dart';
import '../../screens/notifications/notification_screen.dart';

class MainHeader extends StatelessWidget {
  const MainHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.menu, size: 28, color: Colors.black),
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
                        icon: const Icon(Icons.notifications_outlined,
                            size: 28, color: Colors.black),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const NotificationScreen()),
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        unreadCount > 9 ? '9' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (unreadCount > 9)
                                    const TextSpan(
                                      text: '+',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 7, // Smaller plus sign
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
            StreamBuilder<int>(
                stream: ChatService().getUnreadMessageCountStream(
                    FirebaseAuth.instance.currentUser?.uid ?? ''),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline,
                            size: 28, color: Colors.black),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ChatListScreen()),
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        unreadCount > 9 ? '9' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (unreadCount > 9)
                                    const TextSpan(
                                      text: '+',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 7, // Smaller plus sign
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
          ],
        )
      ],
    );
  }
}
