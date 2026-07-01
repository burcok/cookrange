import 'dart:async' show unawaited;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/friend_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/models/chat_model.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../chat_detail_screen.dart';

class SelectFriendSheet extends StatefulWidget {
  const SelectFriendSheet({super.key});

  @override
  State<SelectFriendSheet> createState() => _SelectFriendSheetState();
}

class _SelectFriendSheetState extends State<SelectFriendSheet> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final appText = AppText.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Material(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    AppLocalizations.of(context).translate('chat.new_chat'),
                    style: appText.headlineS.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: palette.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)
                      .translate('chat.search_friend_hint'),
                  hintStyle: TextStyle(color: palette.textTertiary),
                  prefixIcon: Icon(Icons.search, color: palette.textTertiary),
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
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
                          child: Text(
                              AppLocalizations.of(context)
                                  .translate('chat.no_friends'),
                              style: TextStyle(color: palette.textSecondary)));
                    }

                    final filteredFriends = friends.where((friend) {
                      final name = friend.displayName?.toLowerCase() ?? "";
                      return name.contains(_searchQuery);
                    }).toList();

                    if (filteredFriends.isEmpty) {
                      return Center(
                          child: Text(
                              AppLocalizations.of(context)
                                  .translate('chat.no_results'),
                              style: TextStyle(color: palette.textSecondary)));
                    }

                    return ListView.builder(
                      itemCount: filteredFriends.length,
                      itemBuilder: (context, index) {
                        final friend = filteredFriends[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: friend.photoURL != null
                                  ? CachedNetworkImageProvider(friend.photoURL!)
                                  : null,
                              backgroundColor: palette.surfaceVariant,
                              child: friend.photoURL == null
                                  ? Icon(Icons.person,
                                      color: palette.textTertiary)
                                  : null,
                            ),
                            title: Text(
                              friend.displayName ??
                                  AppLocalizations.of(context)
                                      .translate('chat.unnamed_user'),
                              style: TextStyle(color: palette.textPrimary),
                            ),
                            subtitle: Text(
                              friend.isOnline
                                  ? AppLocalizations.of(context)
                                      .translate('chat.online')
                                  : AppLocalizations.of(context)
                                      .translate('chat.offline'),
                              style: TextStyle(
                                color: friend.isOnline
                                    ? palette.success
                                    : palette.textTertiary,
                              ),
                            ),
                            trailing: Icon(Icons.chat_bubble_outline,
                                color: palette.info),
                            onTap: () async {
                              final currentUserId =
                                  _friendService.currentUserId;
                              if (currentUserId != null) {
                                final nav = Navigator.of(context);
                                final chatId =
                                    await _chatService.createOrGetPrivateChat(
                                        currentUserId, friend.uid);

                                if (mounted) {
                                  nav.pop();

                                  final chat = ChatModel(
                                    id: chatId,
                                    participants: [currentUserId, friend.uid],
                                    type: ChatType.private,
                                    unreadCounts: {},
                                    updatedAt: DateTime.now(),
                                    name: friend.displayName,
                                    image: friend.photoURL,
                                  );

                                  unawaited(nav.push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChatDetailScreen(chat: chat),
                                    ),
                                  ));
                                }
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
