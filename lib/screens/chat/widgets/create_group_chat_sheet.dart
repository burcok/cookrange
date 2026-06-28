import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/friend_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../chat_detail_screen.dart';

class CreateGroupChatSheet extends StatefulWidget {
  const CreateGroupChatSheet({super.key});

  @override
  State<CreateGroupChatSheet> createState() => _CreateGroupChatSheetState();
}

class _CreateGroupChatSheetState extends State<CreateGroupChatSheet> {
  final FriendService _friendService = FriendService();
  final ChatService _chatService = ChatService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _friendsSubscription;

  List<UserModel> _friends = [];
  List<UserModel> _filteredFriends = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  bool _isCreating = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
        _filteredFriends = _friends
            .where((f) =>
                (f.displayName ?? '').toLowerCase().contains(_searchQuery))
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    _friendsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    _friendsSubscription = _friendService.getFriendsStream().listen((friends) {
      if (mounted) {
        setState(() {
          _friends = friends;
          _filteredFriends = friends
              .where((f) =>
                  (f.displayName ?? '').toLowerCase().contains(_searchQuery))
              .toList();
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _createGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedIds.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final chat = await _chatService.createGroupChat(
        name: name,
        participantIds: _selectedIds.toList(),
      );
      if (mounted) {
        Navigator.pop(context);
        unawaited(Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final appText = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    final canCreate = _nameController.text.trim().isNotEmpty &&
        _selectedIds.isNotEmpty &&
        !_isCreating;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Material(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.translate('chat.group.create_title'),
                      style: appText.headlineS.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_selectedIds.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        l10n.translate('chat.group.selected_count',
                            variables: {'count': '${_selectedIds.length}'}),
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primary),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _nameController,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.translate('chat.group.name_hint'),
                  hintStyle: TextStyle(color: palette.textTertiary),
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Friend list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _friends.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              l10n.translate('chat.group.no_friends'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: palette.textSecondary),
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, i) {
                            final friend = _filteredFriends[i];
                            final isSelected =
                                _selectedIds.contains(friend.uid);
                            return CheckboxListTile(
                              value: isSelected,
                              onChanged: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedIds.remove(friend.uid);
                                  } else {
                                    _selectedIds.add(friend.uid);
                                  }
                                });
                              },
                              activeColor: primary,
                              secondary: CircleAvatar(
                                radius: 20,
                                backgroundImage: friend.photoURL != null
                                    ? NetworkImage(friend.photoURL!)
                                    : null,
                                child: friend.photoURL == null
                                    ? Text(
                                        (friend.displayName ?? '?')
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              title: Text(
                                friend.displayName ??
                                    l10n.translate('chat.unnamed_user'),
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // Action
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canCreate ? _createGroup : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: palette.border,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          l10n.translate('chat.group.create_btn'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
