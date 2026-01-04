import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/friend_service.dart';

import '../../screens/community/widgets/glass_refresher.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel? viewUser; // If null, shows local user (Private Mode)

  const ProfileScreen({super.key, this.viewUser});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Local state for editing (Private Mode only)
  Map<String, dynamic> _editableData = {};

  bool _isLoading = false;

  // Controllers
  final TextEditingController _genderController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  // Friend Request State (Public Mode only)
  FriendshipStatus _friendshipStatus = FriendshipStatus.none;

  late Stream<List<UserModel>> _friendsStream; // Optimization

  bool get _isPublicMode => widget.viewUser != null;

  @override
  void initState() {
    super.initState();
    _friendsStream = FriendService().getFriendsStream(); // Initialize once
    if (!_isPublicMode) {
      _initializePrivateData();
    } else {
      _checkFriendshipStatus();
    }
  }

  @override
  void dispose() {
    _genderController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _initializePrivateData() {
    final user = context.read<UserProvider>().user;
    if (user != null) {
      _editableData = Map<String, dynamic>.from(user.onboardingData ?? {});

      final personalInfo =
          _editableData['personal_info'] as Map<String, dynamic>? ?? {};
      _genderController.text = personalInfo['gender']?.toString() ?? "";
      _heightController.text = personalInfo['height']?.toString() ?? "";
      _weightController.text = personalInfo['weight']?.toString() ?? "";
    }
  }

  Future<void> _checkFriendshipStatus() async {
    if (widget.viewUser?.uid == null) return;
    final status =
        await FriendService().checkFriendshipStatus(widget.viewUser!.uid);
    if (mounted) {
      setState(() => _friendshipStatus = status);
    }
  }

  // --- Actions ---

  Future<void> _handleFriendAction() async {
    final targetUid = widget.viewUser?.uid;
    if (targetUid == null) return;
    final service = FriendService();

    setState(() => _isLoading = true);
    try {
      if (_friendshipStatus == FriendshipStatus.none) {
        await service.sendFriendRequest(targetUid);
      } else if (_friendshipStatus == FriendshipStatus.pending_sent) {
        await service.cancelFriendRequest(targetUid);
      } else if (_friendshipStatus == FriendshipStatus.pending_received) {
        await service.acceptFriendRequest(targetUid);
      } else if (_friendshipStatus == FriendshipStatus.friends) {
        // Maybe show unfriend dialog? For now just remove
        await service.removeFriend(targetUid);
      }
      await _checkFriendshipStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Action failed: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRejectRequest() async {
    final targetUid = widget.viewUser?.uid;
    if (targetUid == null) return;
    setState(() => _isLoading = true);
    try {
      await FriendService().rejectFriendRequest(targetUid);
      await _checkFriendshipStatus();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    if (_isPublicMode) {
      return _buildScaffold(context, widget.viewUser!, true);
    }

    // Private Mode: Listen to provider
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        final user = provider.user;
        if (user == null)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
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

                          // Edit Icon (Only for private)
                          if (!isPublic)
                            _buildGlassCircleButton(context, Icons.settings,
                                isDark, // Changed icon to edit
                                onTap: () {
                              if (context.mounted) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const SettingsScreen()));
                              }
                            }) // Placeholder for edit action if needed, or remove
                          else
                            const SizedBox(width: 40), // Placeholder to balance
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
                : Colors.orange.shade100.withOpacity(0.5),
            shape: BoxShape.circle,
          ),
          child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent)),
        ),
      ),
    ]);
  }

  Widget _buildAvatarSection(UserModel user, bool isDark, bool isPublic) {
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
                  : "Merhaba Cookrange!",
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
              _buildMessageActionButton(isDark, primaryColor),
            ],
          ),
          const SizedBox(height: 12),
        ]
      ],
    );
  }

  Widget _buildFriendActionButton(bool isDark, Color primaryColor) {
    if (_isLoading)
      return const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2));

    String label = "Add Friend";
    IconData icon = Icons.person_add;
    Color color = primaryColor;
    VoidCallback? onTap = _handleFriendAction;

    if (_friendshipStatus == FriendshipStatus.friends) {
      label = "Friends";
      icon = Icons.check;
      color = Colors.green;
    } else if (_friendshipStatus == FriendshipStatus.pending_sent) {
      label = "Request Sent";
      icon = Icons.access_time;
      color = Colors.grey;
    } else if (_friendshipStatus == FriendshipStatus.pending_received) {
      // Special case: Accept/Reject
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.check, size: 16),
            label: const Text("Accept"),
            onPressed: _handleFriendAction,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: _handleRejectRequest,
            child: const Text("Reject"),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
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
      onPressed: () {},
      icon: const Icon(Icons.chat_bubble, size: 18),
      label: Text("Message", style: TextStyle(color: primaryColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: primaryColor),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem("2", "Posts 🚀", isDark),
        const SizedBox(width: 24),
        _buildStatItem("12K", "Scores ⭐", isDark),
        const SizedBox(width: 24),
        _buildStatItem(
            "${(widget.viewUser ?? context.read<UserProvider>().user)?.onboardingData?['streak'] ?? 1}",
            "Streak 🔥",
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

    return StreamBuilder<List<UserModel>>(
        stream: _friendsStream,
        builder: (context, snapshot) {
          final friends = snapshot.data ?? [];
          return _buildGlassPanel(
            isDark: isDark,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle("Friends", Icons.group, isDark),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12)),
                        child: Text("${friends.length}",
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[500])))
                  ],
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Add Button
                      Column(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                _showFriendSearchDialog(context, isDark),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.grey[800]!.withOpacity(0.5)
                                    : Colors.white.withOpacity(0.5),
                                border: Border.all(
                                    color: isDark
                                        ? Colors.grey[600]!
                                        : Colors.grey[300]!,
                                    style: BorderStyle
                                        .solid // Dashed is hard in standard Flutter without external package or custom painter, using solid for now or simulate
                                    ),
                              ),
                              child: Icon(Icons.add, color: Colors.grey[400]),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text("Add",
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey)),
                        ],
                      ),

                      const SizedBox(width: 16),

                      ...friends.map((f) => Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProfileScreen(viewUser: f))),
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
                                            color:
                                                Colors.black.withOpacity(0.05),
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
                            ),
                          )),
                    ],
                  ),
                )
              ],
            ),
          );
        });
  }

  void _showFriendSearchDialog(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FriendSearchSheet(isDark: isDark),
    );
  }

  Widget _buildGoalsPanel(
      BuildContext context, UserModel user, bool isDark, bool isPublic) {
    // Custom Goal Styling
    return _buildGlassPanel(
        isDark: isDark,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle("Goals", Icons.flag, isDark),
                if (!isPublic)
                  const SizedBox.shrink(), // Removed Edit Button as per request
              ],
            ),
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
                        Colors.orange,
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
          Text(label,
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
        else if (key == 'gender') val = _genderController.text;
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
              _buildSectionTitle("Personal Info", Icons.person, isDark),
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
              _buildInfoCard("Weight", getVal('weight'), "kg", isDark),
              _buildInfoCard("Height", getVal('height'), "cm", isDark),
              _buildInfoCard("Age", "26", "", isDark), // Dummy/Static Age
              _buildInfoCard(
                  "Activity Level",
                  (user.onboardingData?['activity_level'] as String?) ?? "--",
                  "",
                  isDark),
            ],
          )
        ],
      ),
    );
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle(
                      "Kitchen & Lifestyle", Icons.kitchen, isDark),
                  Icon(Icons.expand_more, color: Colors.grey[400])
                ],
              ),
            ),
            Divider(
                height: 1, color: isDark ? Colors.grey[800] : Colors.grey[100]),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Cooking Skill Level: $cookingLevel",
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
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Novice",
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[400])),
                      Text("Expert",
                          style:
                              TextStyle(fontSize: 10, color: Colors.grey[400])),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text("Equipment",
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
                                child: Text(e.toString(),
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
                                        ? Colors.red.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.05),
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.red.withOpacity(0.3)
                                            : Colors.red.withOpacity(0.2)),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(e.toString(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.red[200]
                                            : Colors.red[400])),
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
        onPressed: () => context.read<AuthService>().signOut(),
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
        child: const Text("Log Out",
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
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
    if (user.isOnline) {
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
          Text("Online",
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.green[300] : Colors.green[700],
                  fontWeight: FontWeight.w500)),
        ],
      );
    } else {
      String lastSeen = "Offline";
      if (user.lastActiveAt != null) {
        final date = user.lastActiveAt!.toDate();
        lastSeen = "Last seen: ${DateFormat('dd MMM, HH:mm').format(date)}";
      } else if (user.lastLoginAt != null) {
        final date = user.lastLoginAt!.toDate();
        lastSeen = "Last seen: ${DateFormat('dd MMM, HH:mm').format(date)}";
      }

      return Text(lastSeen,
          textAlign: TextAlign.end,
          style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[500],
              fontStyle: FontStyle.italic));
    }
  }
}

class _FriendSearchSheet extends StatefulWidget {
  final bool isDark;
  const _FriendSearchSheet({required this.isDark});

  @override
  State<_FriendSearchSheet> createState() => _FriendSearchSheetState();
}

class _FriendSearchSheetState extends State<_FriendSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<UserModel> _results = [];
  bool _loading = false;
  final FriendService _friendService = FriendService();

  Future<void> _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final results = await _friendService.searchUsers(query);
      // Filter out self
      final myUid = context.read<UserProvider>().user?.uid;
      setState(() {
        _results = results.where((u) => u.uid != myUid).toList();
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Search failed: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendRequest(UserModel user) async {
    try {
      await _friendService.sendFriendRequest(user.uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Request sent to ${user.displayName}")));
        Navigator.pop(context);
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
          Text("Search Friends",
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 20),
          TextField(
            controller: _searchCtrl,
            style:
                TextStyle(color: widget.isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
                hintText: "Enter display name...",
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
                  onPressed: _search,
                )),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const CircularProgressIndicator()
          else
            Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text("No users found",
                            style: TextStyle(
                                color: widget.isDark
                                    ? Colors.grey
                                    : Colors.black54)))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final u = _results[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: u.photoURL != null
                                  ? NetworkImage(u.photoURL!)
                                  : null,
                              child: u.photoURL == null
                                  ? Text((u.displayName ?? "U")[0])
                                  : null,
                            ),
                            title: Text(u.displayName ?? "Unknown",
                                style: TextStyle(
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black)),
                            trailing: IconButton(
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
