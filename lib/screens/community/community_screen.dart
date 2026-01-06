import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cookrange/core/widgets/app_image.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/community_service.dart';

import '../../core/models/community_post.dart';
import 'widgets/glass_post_card.dart';
import 'widgets/create_post_card.dart';
import 'widgets/glass_refresher.dart';
import 'post_detail_screen.dart';

import 'package:provider/provider.dart';
import '../../core/widgets/main_header.dart';
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

  void _showFilterSheet(BuildContext context, List<String> filters,
      Map<String, String> filterKeys) {
    final appLoc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = context.read<ThemeProvider>().primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        String tempSelectedFilter = _selectedFilter;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B).withOpacity(0.9)
                        : Colors.white.withOpacity(0.9),
                    border: Border(
                      top: BorderSide(
                        color: isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05),
                        width: 1,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        // Handle bar
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Title
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          child: Text(
                            appLoc.translate("community.filter_title"),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Divider(
                          height: 1,
                          color: isDark
                              ? Colors.white.withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                        ),

                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: filters.map((filter) {
                                final isSelected = tempSelectedFilter == filter;
                                return InkWell(
                                  onTap: () {
                                    setModalState(() {
                                      tempSelectedFilter = filter;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? primaryColor
                                              .withOpacity(isDark ? 0.2 : 0.1)
                                          : Colors.transparent,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? primaryColor.withOpacity(0.2)
                                                : (isDark
                                                    ? Colors.white
                                                        .withOpacity(0.05)
                                                    : Colors.black
                                                        .withOpacity(0.05)),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            _getFilterIcon(filter),
                                            size: 20,
                                            color: isSelected
                                                ? primaryColor
                                                : (isDark
                                                    ? Colors.white
                                                    : const Color(0xFF0F172A)),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            appLoc
                                                .translate(filterKeys[filter]!),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: isSelected
                                                  ? primaryColor
                                                  : (isDark
                                                      ? Colors.white
                                                      : const Color(
                                                          0xFF0F172A)),
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          Icon(Icons.check,
                                              color: primaryColor, size: 20),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                        // Spacer
                        const SizedBox(height: 8),

                        // Save Button
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                _onFilterChanged(tempSelectedFilter);
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                appLoc.translate("common.save"),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Safe Area padding for bottom
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case "Latest Updates":
        return Icons.access_time;
      case "Regional":
        return Icons.location_on;
      case "Global":
        return Icons.public;
      case "Friends Only":
        return Icons.people;
      case "Gym":
        return Icons.fitness_center;
      default:
        return Icons.circle;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                  child: const MainHeader(),
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
                      GestureDetector(
                        onTap: () =>
                            _showFilterSheet(context, _filters, filterKeys),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            children: [
                              Text(
                                appLoc.translate(filterKeys[_selectedFilter]!),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.keyboard_arrow_down,
                                  size: 20,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A)),
                            ],
                          ),
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
                            child: Text(appLoc.translate(
                                'community.action_failed',
                                variables: {
                          'error': snapshot.error.toString()
                        }))));
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
                          child: RepaintBoundary(
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

  Widget _buildNewGroupItem(AppLocalizations appLoc) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  appLoc.translate('community.group_feature_unavailable'))),
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
    final appLoc = AppLocalizations.of(context);
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  appLoc.translate('community.group_feature_unavailable'))),
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
                    color: Colors.grey[300],
                  ),
                  child: ClipOval(
                    child: group.imageUrl.isNotEmpty
                        ? (group.imageUrl.startsWith('http')
                            ? AppImage(
                                imageUrl: group.imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                            : Image.asset(group.imageUrl, fit: BoxFit.cover))
                        : const Icon(Icons.group),
                  ),
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
