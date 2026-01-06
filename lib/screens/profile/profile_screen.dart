import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:cookrange/core/constants/onboarding_options.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/providers/theme_provider.dart';
import 'package:cookrange/widgets/onboarding_common_widgets.dart';
import 'package:intl/intl.dart';
import '../../core/services/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/friend_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/models/chat_model.dart';
import '../../screens/community/widgets/glass_refresher.dart';
import '../../core/widgets/unified_action_sheet.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? viewUser; // If null, shows local user (Private Mode)
  final String? userId; // Optional ID to fetch user if viewUser is null

  const ProfileScreen({super.key, this.viewUser, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Local state for editing (Private Mode only)
  Map<String, dynamic> _editableData = {};

  bool _isLoading = false;
  UserModel? _fetchedUser;
  bool _isFetchingUser = false;

  // Controllers
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  // Friend Request State (Public Mode only)
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;

  late Stream<List<UserModel>> _friendsStream; // Optimization

  bool get _isPublicMode => widget.viewUser != null || widget.userId != null;

  @override
  void initState() {
    super.initState();
    _friendsStream = FriendService().getFriendsStream(); // Initialize once
    if (widget.viewUser == null && widget.userId != null) {
      _isFetchingUser = true;
      _fetchUser();
    } else if (!_isPublicMode) {
      _initializePrivateData();
    } else {
      _checkFriendshipStatus();
    }
  }

  Future<void> _fetchUser() async {
    // _isFetchingUser is already true if called from initState
    try {
      final user = await FirestoreService().getUserData(widget.userId!);
      if (mounted) {
        setState(() {
          _fetchedUser = user;
          _isFetchingUser = false;
        });
        if (user != null) {
          _checkFriendshipStatus();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFetchingUser = false);
      }
    }
  }

  @override
  void dispose() {
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _initializePrivateData() {
    final user;
    if (widget.viewUser != null) {
      user = widget.viewUser!;
    } else if (_fetchedUser != null) {
      user = _fetchedUser!;
    } else {
      user = context.read<UserProvider>().user;
    }
    if (user != null) {
      _editableData = Map<String, dynamic>.from(user.onboardingData ?? {});

      final personalInfo =
          _editableData['personal_info'] as Map<String, dynamic>? ?? {};
      _genderController.text = personalInfo['gender']?.toString() ?? "";
      _heightController.text = personalInfo['height']?.toString() ?? "";
      _weightController.text = personalInfo['weight']?.toString() ?? "";
      _ageController.text = personalInfo['birth_date']?.toString() ?? "";
    }
  }

  bool _isCheckingFriendship = true;

  Future<void> _checkFriendshipStatus() async {
    final uid = widget.viewUser?.uid ?? widget.userId;
    if (uid == null) return;
    try {
      final status = await FriendService().checkFriendshipStatus(uid);
      if (mounted) {
        setState(() {
          _friendshipStatus = status;
          _isCheckingFriendship = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isCheckingFriendship = false);
    }
  }

  // --- Actions ---

  Future<void> _handleFriendAction() async {
    final targetUid = widget.viewUser?.uid ?? widget.userId;
    if (targetUid == null) return;
    final service = FriendService();

    setState(() => _isLoading = true);
    try {
      if (_friendshipStatus == FriendshipStatus.none) {
        await service.sendFriendRequest(context, targetUid);
      } else if (_friendshipStatus == FriendshipStatus.pending_sent) {
        await service.cancelFriendRequest(targetUid);
      } else if (_friendshipStatus == FriendshipStatus.pending_received) {
        await service.acceptFriendRequest(context, targetUid);
      } else if (_friendshipStatus == FriendshipStatus.friends) {
        // Maybe show unfriend dialog? For now just remove
        await service.removeFriend(targetUid);
      }
      await _checkFriendshipStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).translate(
                'community.action_failed',
                variables: {'error': e.toString()}))));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRejectRequest() async {
    final targetUid = widget.viewUser?.uid ?? widget.userId;
    if (targetUid == null) return;
    setState(() => _isLoading = true);
    try {
      await FriendService().rejectFriendRequest(targetUid);
      await _checkFriendshipStatus();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showPrivateOptions(BuildContext context) {
    showUnifiedActionSheet(
      context: context,
      title: AppLocalizations.of(context).translate('profile.options_title') ??
          "Profile Options",
      actions: [
        ActionSheetItem(
          label: AppLocalizations.of(context).translate('settings.title'),
          icon: Icons.settings,
          onTap: () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const SettingsScreen()));
          },
        ),
        ActionSheetItem(
          label: AppLocalizations.of(context).translate('auth.sign_out'),
          icon: Icons.logout,
          isDestructive: true,
          onTap: () async {
            await AuthService().signOut();
            // Navigation handling usually done by auth state listener
          },
        ),
      ],
    );
  }

  void _showPublicOptions(BuildContext context) {
    showUnifiedActionSheet(
      context: context,
      title: AppLocalizations.of(context).translate('profile.options_title') ??
          "Profile Options",
      actions: [
        /*
        ActionSheetItem(
          label: "Share Profile",
          icon: Icons.share,
          onTap: () {
            // Implement share
          },
        ),
        */
        ActionSheetItem(
          label:
              AppLocalizations.of(context).translate('community.menu.report'),
          icon: Icons.report_gmailerrorred,
          isDestructive: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)
                      .translate('profile.user_reported'))),
            );
          },
        ),
        ActionSheetItem(
          label: AppLocalizations.of(context).translate('profile.block_user'),
          icon: Icons.block,
          isDestructive: true,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(AppLocalizations.of(context)
                      .translate('profile.user_blocked'))),
            );
          },
        ),
      ],
    );
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    if (_isFetchingUser) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_isPublicMode) {
      final user = widget.viewUser ?? _fetchedUser;
      if (user == null) {
        return Scaffold(
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
          body: Center(
              child: Text(AppLocalizations.of(context)
                  .translate('profile.user_not_found'))),
        );
      }
      return _buildScaffold(context, user, true);
    }

    // Private Mode: Listen to provider
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        final user = provider.user;
        if (user == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        return _buildScaffold(context, user, false);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, UserModel user, bool isPublic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFFDFDFD),
      body: Stack(
        children: [
          // Background Blobs
          _buildBlobs(isDark, primaryColor),

          // Main Content
          GlassRefresher(
            onRefresh: () async {
              if (!isPublic) {
                if (context.mounted)
                  await context.read<UserProvider>().refreshUser();
                if (context.mounted)
                  _initializePrivateData(); // Re-sync local state
              } else {
                await _checkFriendshipStatus();
              }
            },
            topPadding: MediaQuery.of(context).padding.top + 80,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + 24,
                      bottom: 100,
                      left: 16,
                      right: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back Button
                          _buildGlassCircleButton(
                              context, Icons.arrow_back, isDark,
                              onTap: () async {
                            if (!isPublic) {
                              if (context.mounted) Navigator.pop(context);
                            } else if (isPublic) {
                              Navigator.pop(context);
                            }
                          }),

                          _buildGlassCircleButton(
                            context,
                            Icons.more_vert,
                            isDark,
                            onTap: () {
                              if (!isPublic) {
                                _showPrivateOptions(context);
                              } else {
                                _showPublicOptions(context);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildOnlineStatus(user, isDark),
                      const SizedBox(height: 20),
                      _buildAvatarSection(user, isDark, isPublic),
                      const SizedBox(height: 24),
                      _buildStatsRow(isDark),
                      const SizedBox(height: 24),

                      // Friends Section (Moved Above Goals)
                      _buildFriendsSection(context, isDark, isPublic),
                      const SizedBox(height: 20),

                      // Personal Info
                      _buildPersonalInfoGrid(context, user, isDark, isPublic),
                      const SizedBox(height: 20),

                      // Goals Section
                      _buildGoalsPanel(context, user, isDark, isPublic),
                      const SizedBox(height: 20),

                      // Lifestyle
                      _buildLifestylePanel(context, user, isDark, isPublic),

                      const SizedBox(height: 20),

                      if (!isPublic) ...[
                        _buildLogoutButton(context, isDark),
                      ]
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildGlassCircleButton(
      BuildContext context, IconData icon, bool isDark,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(10),
            child: Icon(icon,
                color: isDark ? Colors.white : Colors.black, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildBlobs(bool isDark, Color primaryColor) {
    return Stack(children: [
      Positioned(
        top: -150,
        right: -150,
        child: Container(
          width: 500,
          height: 500,
          decoration: BoxDecoration(
            color: isDark
                ? primaryColor.withOpacity(0.1)
                : primaryColor.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent)),
        ),
      ),
      Positioned(
        bottom: -350,
        left: -150,
        child: Container(
          width: 500,
          height: 500,
          decoration: BoxDecoration(
            color: isDark
                ? primaryColor.withOpacity(0.1)
                : Colors.lightBlue.shade100.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(color: Colors.transparent)),
        ),
      ),
    ]);
  }

  Widget _buildAvatarSection(UserModel user, bool isDark, bool isPublic) {
    final localizations = AppLocalizations.of(context);
    final primaryColor = Theme.of(context).primaryColor;
    final displayName = user.displayName ?? "User";
    final photoURL = user.photoURL;

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 112, // 28 * 4 = 112px
              height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
                boxShadow: [
                  BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 15))
                ],
              ),
              child: ClipOval(
                child: photoURL != null
                    ? Image.network(photoURL, fit: BoxFit.cover)
                    : Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toLowerCase()
                              : "u",
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              color: Colors.white),
                        ),
                      ),
              ),
            ),
            if (!isPublic)
              Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[100]!),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 4)
                          ]),
                      child:
                          Icon(Icons.camera_alt, color: primaryColor, size: 14),
                    ),
                  )),
          ],
        ),
        const SizedBox(height: 16),
        Text(displayName,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[900])),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
              (user.onboardingData?['bio'] as String?)?.isNotEmpty == true
                  ? (user.onboardingData!['bio'] as String).substring(
                      0,
                      (user.onboardingData!['bio'] as String).length > 30
                          ? 30
                          : (user.onboardingData!['bio'] as String).length)
                  : localizations.translate('profile.personal_info'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[500])),
        ),
        if (isPublic) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              _buildFriendActionButton(isDark, primaryColor),
              if (_friendshipStatus == FriendshipStatus.friends)
                _buildMessageActionButton(isDark, primaryColor),
            ],
          ),
          const SizedBox(height: 12),
        ]
      ],
    );
  }

  Widget _buildFriendActionButton(bool isDark, Color primaryColor) {
    final localizations = AppLocalizations.of(context);

    // Show loading spinner while checking status to prevent flickering
    if (_isLoading || _isCheckingFriendship)
      return const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2));

    String label = localizations.translate('profile.friend_actions.add');
    IconData icon = Icons.person_add;
    Color color = primaryColor;
    VoidCallback? onTap = _handleFriendAction;

    if (_friendshipStatus == FriendshipStatus.friends) {
      // If already friends, we might not want to show this button here if the user prefers "Message" only,
      // but per requirements, "Message" button comes AFTER "Add Friend" logic resolves.
      // However, the prompt says: "profile screen'de isPublic olduğu zaman zaten arkadaşım olan bir kişi için sayfa ilk açıldığında önce arkadaş ekle butonu geliyor daha sonra mesaj butonu geliyor. Bu yapıyı düzelt."
      // By using _isCheckingFriendship, we avoid showing "Add Friend" initially.

      // If they are friends, we return SizedBox.shrink() because the Message button will be shown next to it
      // OR we show a "Friends" indicator. Let's show "Friends" indicator as before but maybe disabled or different style?
      // Actually, standard pattern: Show "Friends" (checked) button + "Message" button.
      label = localizations.translate('profile.friend_actions.already_friends');
      icon = Icons.check;
      color = Colors.green;
    } else if (_friendshipStatus == FriendshipStatus.pending_sent) {
      label = localizations.translate('profile.friend_actions.sent');
      icon = Icons.access_time;
      color = Colors.grey;
    } else if (_friendshipStatus == FriendshipStatus.pending_received) {
      return Column(
        children: [
          Text(
            localizations.translate('profile.friend_actions.received_text'),
            style: TextStyle(
                fontSize: 16, color: isDark ? Colors.white : Colors.grey[900]),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: Text(
                    localizations.translate('profile.friend_actions.accept')),
                onPressed: _handleFriendAction,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _handleRejectRequest,
                child: Text(
                    localizations.translate('profile.friend_actions.reject')),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, foregroundColor: Colors.white),
              )
            ],
          )
        ],
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildMessageActionButton(bool isDark, Color primaryColor) {
    if (_isLoading)
      return const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2));

    return ElevatedButton.icon(
      onPressed: () async {
        final targetUid = widget.viewUser?.uid ?? widget.userId;
        if (targetUid == null) return;
        final currentUser = context.read<UserProvider>().user;
        if (currentUser == null) return;

        setState(() => _isLoading = true);
        try {
          // Using direct instantiation for consistency
          final chatId = await ChatService()
              .createOrGetPrivateChat(currentUser.uid, targetUid);

          if (!mounted) return;

          // Create a temporary ChatModel to pass to the screen
          // Ideally we should fetch the full chat model, but createOrGetPrivateChat returns ID.
          // We can fetch it or construct a basic one.
          // Let's construct a basic one to avoid another fetch wait,
          // or improved ChatService to return the model.
          // For now, let's navigate and let ChatDetailScreen handle it?
          // ChatDetailScreen expects a ChatModel.

          // Let's fetch the chat model.
          // Since ChatModel is needed, we might need a method to getChatById.
          // ChatService.getUserChats returns a stream.
          // Let's just create a dummy model with the ID, as ChatDetailScreen might largely rely on ID.
          // Checking ChatDetailScreen... it uses widget.chat.id for streams.
          // It also uses widget.chat.participants for title if name is null.

          final chat = ChatModel(
            id: chatId,
            participants: [currentUser.uid, targetUid],
            unreadCounts: {},
            type: ChatType.private,
            updatedAt: DateTime.now(),
            // We can pass the other user's info to handle title correctly
            // if ChatDetailScreen logic expects it or specific user data.
          );

          Navigator.pushNamed(
            context,
            '/chat_detail',
            arguments: chat,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(AppLocalizations.of(context).translate(
                    'community.action_failed',
                    variables: {'error': e.toString()}))),
          );
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
      icon: const Icon(Icons.chat_bubble, size: 18),
      label: Text(
          AppLocalizations.of(context)
              .translate('profile.friend_actions.message'),
          style: TextStyle(color: primaryColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: primaryColor),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final localizations = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem("2",
            "${localizations.translate('profile.stats.posts')} 🚀", isDark),
        const SizedBox(width: 24),
        _buildStatItem("12K",
            "${localizations.translate('profile.stats.scores')} ⭐", isDark),
        const SizedBox(width: 24),
        _buildStatItem(
            "${(widget.viewUser ?? context.read<UserProvider>().user)?.onboardingData?['streak'] ?? 1}",
            "${localizations.translate('profile.stats.streak')} 🔥",
            isDark),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, bool isDark) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black)),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildFriendsSection(
      BuildContext context, bool isDark, bool isPublic) {
    if (isPublic) return const SizedBox.shrink();
    final localizations = AppLocalizations.of(context);

    // If no friends, show "Add Friend" placeholder in place (as requested)
    // If friends exist, show list in modal on click

    return StreamBuilder<List<UserModel>>(
        stream: _friendsStream,
        builder: (context, snapshot) {
          final friends = snapshot.data ?? [];

          return GestureDetector(
            onTap: () => _showFriendsManagerModal(context, isDark, friends),
            child: _buildGlassPanel(
              isDark: isDark,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle(
                          localizations.translate('profile.friends'),
                          Icons.group,
                          isDark),
                      if (friends.isNotEmpty)
                        Container(
                            child: Text("${friends.length}",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[500])))
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (friends.isEmpty)
                    // Show "Add Friend" button logic here if no friends
                    Center(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showFriendsManagerModal(
                                context, isDark, friends),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                              ),
                              child: Icon(Icons.add,
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                              localizations.translate(
                                  'profile.friends_modal.no_friends'),
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: 12))
                        ],
                      ),
                    )
                  else
                    // Preview of friends
                    GestureDetector(
                      onTap: () =>
                          _showFriendsManagerModal(context, isDark, friends),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // We do NOT show the "+" button here if friends exist, as per request: "Arkadaş ekle butonunu oraya (modale) taşı."

                            ...friends.take(5).map((f) => Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Column(children: [
                                    Container(
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: isDark
                                                  ? Colors.grey[700]!
                                                  : Colors.white,
                                              width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.05),
                                                blurRadius: 4)
                                          ]),
                                      child: CircleAvatar(
                                        radius: 24,
                                        backgroundImage: f.photoURL != null
                                            ? NetworkImage(f.photoURL!)
                                            : null,
                                        child: f.photoURL == null
                                            ? Text((f.displayName ?? "U")[0])
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 60,
                                      child: Text(f.displayName ?? "User",
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : Colors.grey[600])),
                                    ),
                                  ]),
                                )),
                            if (friends.length > 5)
                              // "... and more" indicator
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                  child: Text("+${friends.length - 5}",
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black,
                                          fontSize: 12)),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildGoalsPanel(
      BuildContext context, UserModel user, bool isDark, bool isPublic) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    // Custom Goal Styling
    return _buildGlassPanel(
        isDark: isDark,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(
                AppLocalizations.of(context).translate('profile.goals'),
                Icons.flag,
                isDark),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...(user.onboardingData?['primary_goals'] as List<dynamic>? ??
                        [])
                    .map((goal) => _buildGoalChip(
                        goal.toString(),
                        Icons
                            .check_circle_outline, // Generic icon for dynamic goals
                        primaryColor,
                        isDark))
                    .toList(),
                if ((user.onboardingData?['primary_goals'] as List?)?.isEmpty ??
                    true)
                  Text("No goals set",
                      style: TextStyle(
                          color: isDark ? Colors.grey : Colors.grey[600],
                          fontStyle: FontStyle.italic))
              ],
            )
          ],
        ));
  }

  Widget _buildGoalChip(String label, IconData icon, Color color, bool isDark) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.1),
          border: Border.all(
              color: isDark ? color.withOpacity(0.4) : color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isDark ? color.withAlpha(200) : color),
          const SizedBox(width: 4),
          Text(
              OnboardingOptions.primaryGoals.entries
                  .map((e) {
                    return OptionData(
                      label: localizations.translate(e.value['label']),
                      icon: e.value['icon'] as IconData,
                      value: e.key,
                    );
                  })
                  .firstWhere((e) => e.value == label)
                  .label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? color.withAlpha(200) : color)),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoGrid(
      BuildContext context, UserModel user, bool isDark, bool isPublic) {
    final data = user.onboardingData ?? {};
    final personalInfo = data['personal_info'] as Map<String, dynamic>?;

    String getVal(String key) {
      dynamic val;
      if (isPublic) {
        val = personalInfo?[key];
      } else {
        if (key == 'height')
          val = _heightController.text;
        else if (key == 'weight')
          val = _weightController.text;
        else if (key == 'gender')
          val = _genderController.text;
        else if (key == 'age') val = _ageController.text;
      }
      return val?.toString() ?? "--";
    }

    return _buildGlassPanel(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle(
                  AppLocalizations.of(context)
                      .translate('profile.personal_info'),
                  Icons.person,
                  isDark),
            ],
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.8,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _buildInfoCard(
                  AppLocalizations.of(context)
                      .translate('profile.weight.title')
                      .replaceAll('Select Your ', ''),
                  getVal('weight'),
                  "kg",
                  isDark),
              _buildInfoCard(
                  AppLocalizations.of(context)
                      .translate('profile.height.title')
                      .replaceAll('Select Your ', ''),
                  getVal('height'),
                  "cm",
                  isDark),
              _buildInfoCard(
                  AppLocalizations.of(context).translate('profile.age'),
                  _getDisplayAge(getVal('age')),
                  "",
                  isDark),
              _buildInfoCard(
                  AppLocalizations.of(context)
                      .translate('profile.activity_level'),
                  (user.onboardingData?['activity_level'] as String?) ?? "--",
                  "",
                  isDark),
            ],
          )
        ],
      ),
    );
  }

  String _getDisplayAge(String val) {
    if (val.isEmpty) return "--";
    try {
      final dob = DateTime.parse(val);
      return (DateTime.now().difference(dob).inDays ~/ 365).toString();
    } catch (e) {
      return val;
    }
  }

  Widget _buildInfoCard(String label, String value, String unit, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDark
              ? Colors.grey[800]!.withOpacity(0.5)
              : Colors.white.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color:
                  isDark ? Colors.grey[700]! : Colors.white.withOpacity(0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[500])),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.grey[900])),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 4, top: 4),
                  child: Text(unit,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLifestylePanel(
      BuildContext context, UserModel user, bool isDark, bool public) {
    final cookingLevel =
        user.onboardingData?['cooking_level'] as String? ?? "Beginner";
    final equipment =
        user.onboardingData?['kitchen_equipments'] as List<dynamic>? ?? [];
    final dislikedFoods =
        user.onboardingData?['disliked_foods'] as List<dynamic>? ?? [];
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    final localizations = AppLocalizations.of(context);

    double levelValue = 0.3;
    if (cookingLevel.toLowerCase().contains('inter')) levelValue = 0.6;
    if (cookingLevel.toLowerCase().contains('adv') ||
        cookingLevel.toLowerCase().contains('pro') ||
        cookingLevel.toLowerCase().contains('chef')) levelValue = 1.0;

    return _buildGlassPanel(
        isDark: isDark,
        padding:
            EdgeInsets.zero, // Padding handled inside for this specific design
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: _buildSectionTitle(
                  localizations.translate('profile.kitchen_lifestyle.title'),
                  Icons.kitchen,
                  isDark),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "${localizations.translate('profile.kitchen_lifestyle.cooking_level')}: ${OnboardingOptions.cookingLevels.entries.map((e) {
                            return OptionData(
                              label: localizations.translate(e.value['label']),
                              icon: e.value['icon'] as IconData,
                              value: e.key,
                            );
                          }).firstWhere((e) => e.value == cookingLevel).label}",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[500])),
                  const SizedBox(height: 8),

                  // Progress Bar
                  Container(
                    height: 10,
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: isDark ? Colors.grey[700] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(5)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: levelValue,
                      child: Container(
                        decoration: BoxDecoration(
                            color: primaryColor,
                            borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          localizations
                              .translate('profile.kitchen_lifestyle.novice'),
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[400])),
                      Text(
                          localizations
                              .translate('profile.kitchen_lifestyle.expert'),
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                      localizations
                          .translate('profile.kitchen_lifestyle.equipment'),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.grey[500])),
                  const SizedBox(height: 8),
                  if (equipment.isEmpty)
                    Text("No equipment listed",
                        style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontStyle: FontStyle.italic))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: equipment
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.grey[600]!
                                            : Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    localizations.translate(OnboardingOptions
                                            .kitchenEquipment[e.toString()] ??
                                        e.toString()),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[600])),
                              ))
                          .toList(),
                    ),

                  // Disliked Foods Section
                  if (dislikedFoods.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text("Disliked Foods",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey[500])),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dislikedFoods
                          .map((e) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.grey[600]!
                                            : Colors.grey[200]!),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(
                                    OnboardingOptions
                                        .predefinedIngredients.entries
                                        .map((a) {
                                          return OptionData(
                                            label: localizations
                                                .translate(a.value['label']),
                                            icon: a.value['icon'] as IconData,
                                            value: a.key,
                                          );
                                        })
                                        .firstWhere(
                                            (i) => i.value == e.toString())
                                        .label,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[600])),
                              ))
                          .toList(),
                    ),
                  ]
                ],
              ),
            )
          ],
        ));
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: () => AuthService().signOut(),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor:
              isDark ? Colors.grey[800] : Colors.white.withOpacity(0.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: isDark
                      ? Colors.red.withOpacity(0.3)
                      : Colors.red.shade200)),
        ),
        child: Text(
            AppLocalizations.of(context).translate('auth.logout_button'),
            style: const TextStyle(
                color: Colors.red, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    final primaryColor = Theme.of(context).primaryColor;
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20), // Orange icon
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800])),
      ],
    );
  }

  Widget _buildGlassPanel(
      {required Widget child, required bool isDark, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20), // Matches rounded-2xl
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1F2937).withOpacity(0.7) // glass-dark
                  : const Color(0xFFFFFFFF).withOpacity(0.7), // glass-light
              border: Border.all(
                color:
                    isDark ? Colors.grey[700]! : Colors.white.withOpacity(0.6),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2))
              ]),
          child: child,
        ),
      ),
    );
  }

  Widget _buildOnlineStatus(UserModel user, bool isDark) {
    // If viewing another user, use a stream to get real-time status
    // If viewing self (private mode), usually we are online, but let's stick to user.isOnline (which comes from Auth/UserProvider stream anyway)

    // For "viewUser", we passed a snapshot user. We need to listen to their document to get updates without restart.

    if (widget.viewUser == null) {
      // Self: UserProvider already streams this.
      return _buildStatusIndicator(user.isOnline,
          user.lastActiveAt?.toDate() ?? user.lastLoginAt?.toDate(), isDark);
    }

    return StreamBuilder<firestore.DocumentSnapshot>(
        stream: firestore.FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return _buildStatusIndicator(user.isOnline, null, isDark);

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data == null) return _buildStatusIndicator(false, null, isDark);

          final bool isOnlineFlag = data['is_online'] ?? false;
          final firestore.Timestamp? lastActive = data['last_active_at'];
          final firestore.Timestamp? lastLogin = data['last_login_at'];

          final DateTime? lastActiveAt = lastActive?.toDate();

          bool isActuallyOnline = false;
          if (isOnlineFlag) {
            if (lastActiveAt != null) {
              final difference = DateTime.now().difference(lastActiveAt);
              if (difference.inMinutes < 5) {
                isActuallyOnline = true;
              }
            } else {
              isActuallyOnline = false;
            }
          }

          return _buildStatusIndicator(
              isActuallyOnline, lastActiveAt ?? lastLogin?.toDate(), isDark);
        });
  }

  Widget _buildStatusIndicator(
      bool isOnline, DateTime? lastSeenDate, bool isDark) {
    if (isOnline) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(AppLocalizations.of(context).translate('profile.online'),
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.green[300] : Colors.green[700],
                  fontWeight: FontWeight.w500)),
        ],
      );
    } else {
      String lastSeen =
          AppLocalizations.of(context).translate('profile.offline');
      if (lastSeenDate != null) {
        lastSeen = AppLocalizations.of(context)
            .translate('profile.last_seen')
            .replaceAll(
                '{time}', DateFormat('dd MMM, HH:mm').format(lastSeenDate));
      }

      return Text(lastSeen,
          textAlign: TextAlign.end,
          style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
              fontStyle: FontStyle.italic));
    }
  }

  void _showFriendsManagerModal(
      BuildContext context, bool isDark, List<UserModel> friends) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FriendsManagerSheet(
        isDark: isDark,
        friends: friends,
      ),
    );
  }

  // _showFriendSearchDialog is removed as it's now internal to _FriendsManagerSheet
}

// Unified Friends Manager Modal
class _FriendsManagerSheet extends StatefulWidget {
  final bool isDark;
  final List<UserModel> friends;

  const _FriendsManagerSheet({
    required this.isDark,
    required this.friends,
  });

  @override
  State<_FriendsManagerSheet> createState() => _FriendsManagerSheetState();
}

enum _FriendsSheetMode { list, search }

class _FriendsManagerSheetState extends State<_FriendsManagerSheet> {
  _FriendsSheetMode _mode = _FriendsSheetMode.list;

  // List Mode State
  late List<UserModel> _filteredFriends;
  final TextEditingController _localSearchCtrl = TextEditingController();

  // Search Mode State
  final TextEditingController _globalSearchCtrl = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _searching = false;
  final FriendService _friendService = FriendService();
  Set<String> _friendIds = {};

  @override
  void initState() {
    super.initState();
    _filteredFriends = widget.friends;
    _friendIds = widget.friends.map((u) => u.uid).toSet();
    if (widget.friends.isEmpty) {
      _mode = _FriendsSheetMode.search;
    }
    _localSearchCtrl.addListener(_onLocalSearchChanged);
  }

  @override
  void dispose() {
    _localSearchCtrl.dispose();
    _globalSearchCtrl.dispose();
    super.dispose();
  }

  // --- List Mode Logic ---

  void _onLocalSearchChanged() {
    final query = _localSearchCtrl.text.toLowerCase();
    setState(() {
      _filteredFriends = widget.friends.where((f) {
        final name = f.displayName?.toLowerCase() ?? "";
        return name.contains(query);
      }).toList();
    });
  }

  Future<void> _unfriend(UserModel user) async {
    try {
      await FriendService().removeFriend(user.uid);
      if (mounted) Navigator.pop(context); // Close for simplicity/refresh
    } catch (e) {
      debugPrint("Error unfriending: $e");
    }
  }

  // --- Search Mode Logic ---

  Future<void> _performGlobalSearch() async {
    final query = _globalSearchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await _friendService.searchUsers(query);
      final myUid = context.read<UserProvider>().user?.uid;

      // Update friend IDs to be sure we have latest status
      // (Optimally we should stream this but for now standard check is fine)
      // Actually we have widget.friends passed in.

      setState(() {
        _searchResults = results.where((u) => u.uid != myUid).toList();
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Search failed: $e")));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _sendRequest(UserModel user) async {
    try {
      await _friendService.sendFriendRequest(context, user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Request sent to ${user.displayName}")));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          if (_mode == _FriendsSheetMode.list)
            _buildListView()
          else
            _buildSearchView(),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Expanded(
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  AppLocalizations.of(context)
                      .translate('profile.friends_modal.title'),
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black)),
              IconButton(
                onPressed: () {
                  setState(() {
                    _mode = _FriendsSheetMode.search;
                    // Reset search state
                    _searchResults.clear();
                    _globalSearchCtrl.clear();
                  });
                },
                icon: Icon(Icons.person_add,
                    color: Theme.of(context).primaryColor),
              )
            ],
          ),
          const SizedBox(height: 20),

          // Local Search Field
          TextField(
              controller: _localSearchCtrl,
              style:
                  TextStyle(color: widget.isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)
                    .translate('profile.friends_modal.search_hint'),
                hintStyle: TextStyle(
                    color: widget.isDark ? Colors.grey : Colors.black54),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: widget.isDark ? Colors.white10 : Colors.grey[200],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              )),
          const SizedBox(height: 20),

          Expanded(
            child: ListView.builder(
              itemCount: _filteredFriends.length,
              itemBuilder: (context, index) {
                final friend = _filteredFriends[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: friend.photoURL != null
                        ? NetworkImage(friend.photoURL!)
                        : null,
                    child: friend.photoURL == null
                        ? Text((friend.displayName ?? "U")[0])
                        : null,
                  ),
                  title: Text(friend.displayName ?? "User",
                      style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black)),
                  trailing: PopupMenuButton(
                    icon: const Icon(Icons.more_vert),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'unfriend',
                        child: Text(AppLocalizations.of(context)
                            .translate('profile.friends_modal.unfriend')),
                      )
                    ],
                    onSelected: (val) {
                      if (val == 'unfriend') {
                        _unfriend(friend);
                      }
                    },
                  ),
                  onTap: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProfileScreen(viewUser: friend)));
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSearchView() {
    final localizations = AppLocalizations.of(context);
    return Expanded(
      child: Column(
        children: [
          // Header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _mode = _FriendsSheetMode.list),
                color: widget.isDark ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 8),
              Text(
                  localizations
                      .translate('profile.friend_actions.add'), // "Add Friend"
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black)),
            ],
          ),
          const SizedBox(height: 20),

          // Global Search Field
          TextField(
              controller: _globalSearchCtrl,
              style:
                  TextStyle(color: widget.isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                  hintText: localizations.translate('profile.search.hint'),
                  hintStyle: TextStyle(
                      color: widget.isDark ? Colors.grey : Colors.black54),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: widget.isDark ? Colors.white10 : Colors.grey[200],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _globalSearchCtrl.text.isNotEmpty &&
                            _globalSearchCtrl.text.length >= 3
                        ? _performGlobalSearch
                        : null,
                    autofocus: true,
                  )),
              onSubmitted: (_) => {
                    if (_globalSearchCtrl.text.isNotEmpty &&
                        _globalSearchCtrl.text.length >= 3)
                      _performGlobalSearch()
                  }),
          const SizedBox(height: 20),

          if (_searching)
            const CircularProgressIndicator()
          else
            Expanded(
                child: _searchResults.isEmpty
                    ? Center(
                        child: Text(
                            localizations
                                .translate('profile.search.no_results'),
                            style: TextStyle(
                                color: widget.isDark
                                    ? Colors.grey
                                    : Colors.black54)))
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (ctx, i) {
                          final u = _searchResults[i];
                          final isFriend = _friendIds.contains(u.uid);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: u.photoURL != null
                                  ? NetworkImage(u.photoURL!)
                                  : null,
                              child: u.photoURL == null
                                  ? Text((u.displayName ?? "U")[0])
                                  : null,
                            ),
                            title: Text(u.displayName ?? "User",
                                style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black)),
                            trailing: isFriend
                                ? Icon(Icons.check, color: Colors.green)
                                : IconButton(
                                    icon: const Icon(Icons.person_add,
                                        color: Color(0xFFF44075)),
                                    onPressed: () => _sendRequest(u),
                                  ),
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(viewUser: u)));
                            },
                          );
                        },
                      ))
        ],
      ),
    );
  }
}
