import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/friend_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/models/chat_model.dart';
import '../chat_detail_screen.dart';

class SelectFriendSheet extends StatefulWidget {
  const SelectFriendSheet({super.key});

  @override
  State<SelectFriendSheet> createState() => _SelectFriendSheetState();
}

class _SelectFriendSheetState extends State<SelectFriendSheet> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService(); // Assuming it's available
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                AppLocalizations.of(context).translate('chat.new_chat'),
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)
                  .translate('chat.search_friend_hint'),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.toLowerCase()),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _friendService.getFriendsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final friends = snapshot.data ?? [];

                if (friends.isEmpty) {
                  return Center(
                      child: Text(AppLocalizations.of(context)
                          .translate('chat.no_friends')));
                }

                final filteredFriends = friends.where((friend) {
                  final name = friend.displayName?.toLowerCase() ?? "";
                  return name.contains(_searchQuery);
                }).toList();

                if (filteredFriends.isEmpty) {
                  return Center(
                      child: Text(AppLocalizations.of(context)
                          .translate('chat.no_results')));
                }

                return ListView.builder(
                  itemCount: filteredFriends.length,
                  itemBuilder: (context, index) {
                    final friend = filteredFriends[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: friend.photoURL != null
                            ? NetworkImage(friend.photoURL!)
                            : null,
                        child: friend.photoURL == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(friend.displayName ??
                          AppLocalizations.of(context)
                              .translate('chat.unnamed_user')),
                      subtitle: Text(friend.isOnline
                          ? AppLocalizations.of(context)
                              .translate('chat.online')
                          : AppLocalizations.of(context)
                              .translate('chat.offline')),
                      trailing: const Icon(Icons.chat_bubble_outline,
                          color: Colors.blue),
                      onTap: () async {
                        // Create 1:1 chat logic here
                        // We need current user ID, assuming FriendService access it or we pass it
                        final currentUserId = _friendService.currentUserId;
                        if (currentUserId != null) {
                          // Navigate to chat
                          // We need to create/get chat ID first
                          final chatId =
                              await _chatService.createOrGetPrivateChat(
                                  currentUserId, friend.uid);

                          if (mounted) {
                            Navigator.pop(context); // Close sheet

                            // Construct a ChatModel to pass
                            final chat = ChatModel(
                              id: chatId,
                              participants: [currentUserId, friend.uid],
                              type: ChatType.private,
                              unreadCounts: {}, // Empty initially
                              updatedAt: DateTime.now(),
                              name: friend.displayName,
                              image: friend.photoURL,
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(chat: chat),
                              ),
                            );
                          }
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
