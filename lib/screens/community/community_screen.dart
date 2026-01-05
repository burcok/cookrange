import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/community_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/models/community_post.dart';
import 'widgets/glass_post_card.dart';
import 'widgets/create_post_card.dart';
import 'widgets/glass_refresher.dart';
import 'post_detail_screen.dart';

import 'package:provider/provider.dart';
import '../../core/services/navigation_provider.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../../core/providers/theme_provider.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityService _service = CommunityService();
  final ScrollController _scrollController = ScrollController();

  List<CommunityGroup> _groups = [];
  bool _isLoadingGroups = true;

  // Filters (Keep UI for now, logic later)
  final List<String> _filters = [
    "Latest Updates",
    "Regional",
    "Global",
    "Friends Only",
    "Gym"
  ];
  String _selectedFilter = "Latest Updates";

  late Stream<List<CommunityPost>> _postsStream;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _postsStream = _service.getPostsStream();
  }

  Future<void> _loadGroups() async {
    final groups = _service.getGroups();
    if (mounted) {
      setState(() {
        _groups = groups;
        _isLoadingGroups = false;
      });
    }
  }

  Future<void> _refreshData() async {
    _loadGroups();
    // Refresh streams
    setState(() {
      _postsStream = _service.getPostsStream();
    });
    await Future.delayed(const Duration(seconds: 1)); // Reduced delay
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavigationProvider>();
    final appLoc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter Keys for localization map
    final Map<String, String> filterKeys = {
      "Latest Updates": "community.filters.latest",
      "Regional": "community.filters.regional",
      "Global": "community.filters.global",
      "Friends Only": "community.filters.friends",
      "Gym": "community.filters.gym"
    };

    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by main scaffold
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: GlassRefresher(
          onRefresh: _refreshData,
          topPadding: 100, // Adjusted for Community Screen header
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            controller: _scrollController,
            slivers: [
              // Standard Header with Menu and Notifications (like Home)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    24, MediaQuery.of(context).padding.top + 24, 24, 24),
                sliver: SliverToBoxAdapter(
                  child: _buildTopBar(context),
                ),
              ),

              // "Community" Title
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    appLoc.translate("community.title"),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Horizontal Groups List
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: _isLoadingGroups
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _groups.length + 1, // +1 for "New Group"
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildNewGroupItem(appLoc);
                            }
                            final group = _groups[index - 1];
                            return _buildGroupItem(group);
                          },
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Feed Header (Filters)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          // Using "feed" or "title" or "latest"?
                          // The user asked to translate "whats cooking" and "community" and "your feed"
                          // "community.feed" key was added
                          appLoc.translate("community.feed"),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: DropdownButton<String>(
                          // Add dropdown styling if needed for transparency
                          value: _selectedFilter,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          dropdownColor:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          items: _filters.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(appLoc.translate(filterKeys[value] ??
                                  "community.filters.latest")),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            if (newValue != null) _onFilterChanged(newValue);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Create Post Widget
              SliverToBoxAdapter(
                child: CreatePostCard(
                  onPostCreated: () {
                    // Stream updates automatically, but we could scroll to top
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut);
                    }
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              // Posts Feed (StreamBuilder)
              StreamBuilder<List<CommunityPost>>(
                stream: _postsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                        child: Center(
                            child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator())));
                  }

                  if (snapshot.hasError) {
                    // In development/mock or if Firestore rules fail, show error
                    return SliverToBoxAdapter(
                        child: Center(
                            child: Text(
                                "Error loading posts: ${snapshot.error}")));
                  }

                  final posts = snapshot.data ?? [];

                  if (posts.isEmpty) {
                    return SliverToBoxAdapter(
                        child: Center(
                            child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text(
                                    appLoc.translate('community.no_posts')))));
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = posts[index];
                        return Padding(
                          padding: const EdgeInsets.only(
                              bottom: 20, left: 24, right: 24),
                          child: GlassPostCard(
                            post: post,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PostDetailScreen(postId: post.id),
                                ),
                              );
                            },
                            onLike: () async {
                              await _service.likePost(post.id);
                              // The stream will update the UI automatically
                            },
                            onComment: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PostDetailScreen(postId: post.id),
                                ),
                              );
                            },
                            onShare: () {
                              // Implement share logic
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(AppLocalizations.of(context)
                                        .translate('community.menu.share'))),
                              );
                            },
                            onReaction: (emoji) async {
                              await _service.toggleReaction(
                                  postId: post.id, emoji: emoji);
                              // Stream updates automatically
                            },
                          ),
                        );
                      },
                      childCount: posts.length,
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
            IconButton(
              icon: const Icon(Icons.person_outline,
                  size: 28, color: Colors.black),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildNewGroupItem(AppLocalizations appLoc) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('New group feature is not available yet')),
        ),
        // Navigator.of(context).push(
        //   MaterialPageRoute(builder: (_) => const GroupScreen()),
        // ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: context.watch<ThemeProvider>().primaryColor,
                    width: 2),
                color: Colors.transparent,
              ),
              child: Icon(Icons.add,
                  color: context.watch<ThemeProvider>().primaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              appLoc.translate('community.groups.new'), // Keep short
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupItem(CommunityGroup group) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group feature is not available yet')),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: group.imageUrl.isNotEmpty
                        ? DecorationImage(
                            image: group.imageUrl.startsWith('http')
                                ? NetworkImage(group.imageUrl)
                                : AssetImage(group.imageUrl) as ImageProvider,
                            fit: BoxFit.cover)
                        : null,
                    color: Colors.grey[300],
                  ),
                  child:
                      group.imageUrl.isEmpty ? const Icon(Icons.group) : null,
                ),
                if (group.hasUpdate)
                  Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                              color:
                                  context.watch<ThemeProvider>().primaryColor,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2)))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              group.name,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
