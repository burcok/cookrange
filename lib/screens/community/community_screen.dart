import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cookrange/core/widgets/app_image.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/community_service.dart';
import '../../core/services/follow_service.dart';
import '../../core/services/friend_service.dart';

import '../../core/models/community_post.dart';
import 'community_topics.dart';
import 'groups/groups_discovery_screen.dart';
import 'widgets/glass_post_card.dart';
import 'widgets/create_post_card.dart';
import 'widgets/glass_refresher.dart';
import 'widgets/weekly_highlights_card.dart';
import 'post_detail_screen.dart';

import 'package:provider/provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/widgets/main_header.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/sharing_service.dart';
import '../../core/widgets/ds/ds.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with AutomaticKeepAliveClientMixin {
  final CommunityService _service = CommunityService();
  final FriendService _friendService = FriendService();
  final ScrollController _scrollController = ScrollController();

  List<CommunityGroup> _groups = [];
  bool _isLoadingGroups = true;

  final List<String> _filters = [
    "Latest Updates",
    "Global",
    "Friends Only",
    "Following",
    "Gym",
    "Saved",
  ];
  String _selectedFilter = "Latest Updates";

  // Cached friend IDs for the Friends Only filter (reused by load-more)
  List<String> _cachedFriendIds = [];

  // Cached following IDs for the Following filter (reused by load-more)
  List<String> _cachedFollowingIds = [];

  // Topic filter — null means "All Topics"
  String? _selectedTopic;

  late Stream<List<CommunityPost>> _postsStream;
  List<CommunityPost> _additionalPosts = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
    _postsStream = _service.getPostsStream();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 320) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMorePosts) return;
    setState(() => _isLoadingMore = true);
    try {
      final result = await _service.fetchPostsPage(
        startAfter: _lastDoc,
        authorIds: _selectedFilter == 'Friends Only'
            ? _cachedFriendIds
            : _selectedFilter == 'Following'
                ? _cachedFollowingIds
                : null,
        gymOnly: _selectedFilter == 'Gym',
        topic: (_selectedFilter == 'Global' || _selectedFilter == 'Following' ||
                _selectedFilter == 'Latest Updates')
            ? _selectedTopic
            : null,
      );
      if (mounted) {
        setState(() {
          _additionalPosts.addAll(result.posts);
          _lastDoc = result.lastDoc;
          _hasMorePosts = result.posts.length == 20;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
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
    unawaited(_loadGroups());
    setState(() {
      _postsStream = _service.getPostsStream();
      _additionalPosts = [];
      _lastDoc = null;
      _hasMorePosts = true;
    });
    await Future.delayed(const Duration(seconds: 1));
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
    _applyFilter(filter);
  }

  Future<void> _applyFilter(String filter) async {
    switch (filter) {
      case 'Friends Only':
        final ids = await _friendService.getFriendIds();
        _cachedFriendIds = ids;
        if (!mounted) return;
        setState(() {
          _selectedTopic = null; // topic filter not available for Friends
          _additionalPosts = [];
          _lastDoc = null;
          _hasMorePosts = true;
          _postsStream = ids.isEmpty
              ? Stream.value([])
              : _service.getPostsStream(authorIds: ids.take(30).toList());
        });
        break;
      case 'Gym':
        if (!mounted) return;
        setState(() {
          _selectedTopic = null; // topic filter not available for Gym
          _additionalPosts = [];
          _lastDoc = null;
          _hasMorePosts = true;
          _postsStream = _service.getPostsStream(gymOnly: true);
        });
        break;
      case 'Following':
        final uid = context.read<UserProvider>().user?.uid;
        final ids = uid != null ? await FollowService().getFollowingIds(uid) : <String>[];
        _cachedFollowingIds = ids;
        if (!mounted) return;
        setState(() {
          _cachedFriendIds = [];
          _additionalPosts = [];
          _lastDoc = null;
          _hasMorePosts = ids.isNotEmpty;
          _postsStream = ids.isEmpty
              ? Stream.value([])
              : _service.getPostsStream(
                  authorIds: ids.take(10).toList(),
                  topic: _selectedTopic,
                );
        });
        break;
      case 'Saved':
        if (!mounted) return;
        setState(() {
          _cachedFriendIds = [];
          _cachedFollowingIds = [];
          _selectedTopic = null; // topic filter not available for Saved
          _additionalPosts = [];
          _lastDoc = null;
          _hasMorePosts = false;
          _postsStream = _service.getSavedPostsStream();
        });
        break;
      default: // 'Latest Updates' or 'Global'
        if (!mounted) return;
        setState(() {
          _cachedFriendIds = [];
          _cachedFollowingIds = [];
          _additionalPosts = [];
          _lastDoc = null;
          _hasMorePosts = true;
          _postsStream = _service.getPostsStream(topic: _selectedTopic);
        });
    }
  }

  void _onTopicSelected(String? topic) {
    setState(() {
      _selectedTopic = topic;
      _additionalPosts = [];
      _lastDoc = null;
      _hasMorePosts = true;
    });
    // Re-apply current filter with the updated topic
    _applyFilter(_selectedFilter);
  }


  IconData _getFilterIcon(String filter) {
    switch (filter) {
      case "Latest Updates":
        return Icons.access_time;
      case "Global":
        return Icons.public;
      case "Friends Only":
        return Icons.people;
      case "Following":
        return Icons.person_search_rounded;
      case "Gym":
        return Icons.fitness_center;
      case "Saved":
        return Icons.bookmark_rounded;
      default:
        return Icons.circle;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final appLoc = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);

    final Map<String, String> filterKeys = {
      "Latest Updates": "community.filters.latest",
      "Global": "community.filters.global",
      "Friends Only": "community.filters.friends",
      "Following": "community.filter_following",
      "Gym": "community.filters.gym",
      "Saved": "community.filters.saved",
    };

    return Scaffold(
      backgroundColor: Colors.transparent, // Handled by main scaffold
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: GlassRefresher(
          onRefresh: _refreshData,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            controller: _scrollController,
            slivers: [
              // Standard Header with Menu and Notifications (like Home)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl, MediaQuery.of(context).padding.top + AppSpacing.xl, AppSpacing.xl, AppSpacing.xl),
                sliver: const SliverToBoxAdapter(
                  child: MainHeader(),
                ),
              ),

              // "Community" Title
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    appLoc.translate("community.title"),
                    style: textStyles.displayM.copyWith(letterSpacing: -1),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

              // Horizontal Groups List
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: _isLoadingGroups
                      ? Center(
                          child: CircularProgressIndicator(
                              color: context.watch<ThemeProvider>().primaryColor))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: _groups.length + 1, // +1 for "New Group"
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return _buildNewGroupItem(appLoc);
                            }
                            final group = _groups[index - 1];
                            return RepaintBoundary(child: _buildGroupItem(group));
                          },
                        ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),

              // Weekly Highlights — shown only in the unfiltered Global view
              if (_selectedFilter == 'Global' && _selectedTopic == null)
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: WeeklyHighlightsCard(),
                  ),
                ),

              // Feed Header
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    appLoc.translate("community.feed"),
                    style: textStyles.headlineM,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

              // Inline feed-filter pills (canonical app-wide filter bar).
              SliverToBoxAdapter(
                child: AppFilterBar(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  children: _filters
                      .map((f) => AppFilterPill(
                            label: appLoc.translate(filterKeys[f]!),
                            icon: _getFilterIcon(f),
                            active: _selectedFilter == f,
                            onTap: () => _onFilterChanged(f),
                          ))
                      .toList(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),

              // Topic filter row — shown only for Global, Latest Updates, Following
              if (_selectedFilter == 'Global' ||
                  _selectedFilter == 'Latest Updates' ||
                  _selectedFilter == 'Following')
                SliverToBoxAdapter(
                  child: _TopicFilterRow(
                    selectedTopic: _selectedTopic,
                    onTopicSelected: _onTopicSelected,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

              // Create Post Widget
              SliverToBoxAdapter(
                child: CreatePostCard(
                  onPostCreated: () {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(0,
                          duration: AppMotion.slow,
                          curve: Curves.easeOut);
                    }
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
              // Posts Feed (StreamBuilder)
              StreamBuilder<List<CommunityPost>>(
                stream: _postsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                        child: Center(
                            child: Padding(
                                padding: EdgeInsets.all(AppSpacing.lg),
                                child: CircularProgressIndicator())));
                  }

                  if (snapshot.hasError) {
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
                    final emptyKey = _selectedTopic != null
                        ? 'community.topic_empty'
                        : _selectedFilter == 'Friends Only'
                            ? 'community.filters.no_friends_posts'
                            : _selectedFilter == 'Following'
                                ? 'community.following_empty'
                                : _selectedFilter == 'Gym'
                                    ? 'community.filters.no_gym_posts'
                                    : _selectedFilter == 'Saved'
                                        ? 'community.filters.no_saved_posts'
                                        : 'community.no_posts';
                    final emptyIcon = _selectedTopic != null
                        ? Icons.local_fire_department_outlined
                        : _selectedFilter == 'Friends Only'
                            ? Icons.people_outline
                            : _selectedFilter == 'Following'
                                ? Icons.person_search_rounded
                                : _selectedFilter == 'Gym'
                                    ? Icons.fitness_center
                                    : _selectedFilter == 'Saved'
                                        ? Icons.bookmark_border_rounded
                                        : Icons.article_outlined;
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxxl),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(emptyIcon, size: 48, color: palette.textTertiary),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              appLoc.translate(emptyKey),
                              textAlign: TextAlign.center,
                              style: textStyles.bodyM,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = posts[index];
                        return Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg, left: AppSpacing.xl, right: AppSpacing.xl),
                          child: RepaintBoundary(
                            child: GlassPostCard(
                              post: post,
                              onTap: () => Navigator.push(context,
                                  AppTransitions.slideUp(PostDetailScreen(postId: post.id))),
                              onLike: () async {
                                await _service.likePost(post.id);
                              },
                              onComment: () => Navigator.push(context,
                                  AppTransitions.slideUp(PostDetailScreen(postId: post.id))),
                              onShare: () {
                                final box = context.findRenderObject() as RenderBox?;
                                final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
                                SharingService().sharePost(
                                  context,
                                  caption: post.content,
                                  authorName: post.author.name,
                                  sharePositionOrigin: rect,
                                );
                              },
                              onReaction: (emoji) async {
                                await _service.toggleReaction(
                                    postId: post.id, emoji: emoji);
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

              // Additional paginated posts
              if (_additionalPosts.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final post = _additionalPosts[index];
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppSpacing.lg, left: AppSpacing.xl, right: AppSpacing.xl),
                          child: GlassPostCard(
                            post: post,
                            onTap: () => Navigator.push(context,
                                AppTransitions.slideUp(PostDetailScreen(postId: post.id))),
                            onLike: () => _service.likePost(post.id),
                            onComment: () => Navigator.push(context,
                                AppTransitions.slideUp(PostDetailScreen(postId: post.id))),
                            onShare: () {},
                            onReaction: (emoji) =>
                                _service.toggleReaction(postId: post.id, emoji: emoji),
                          ),
                        ),
                      );
                    },
                    childCount: _additionalPosts.length,
                  ),
                ),

              // Pagination footer: skeleton while loading, end-state when done
              SliverToBoxAdapter(
                child: _buildPaginationFooter(
                    appLoc, palette, textStyles),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(AppLocalizations appLoc, AppPalette palette,
      AppText textStyles) {
    if (_isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.xs, AppSpacing.lg, AppSpacing.sm),
        child: Column(
          children: List.generate(
            2,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppSkeletonBox(height: 88, width: double.infinity),
            ),
          ),
        ),
      );
    }

    if (!_hasMorePosts && _additionalPosts.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                color: palette.textTertiary, size: 28),
            const SizedBox(height: 6),
            Text(
              appLoc.translate('community.all_posts_loaded'),
              style: textStyles.labelM.copyWith(color: palette.textTertiary),
            ),
          ],
        ),
      );
    }

    return const SizedBox(height: AppSpacing.md);
  }

  Widget _buildNewGroupItem(AppLocalizations appLoc) {
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final textStyles = AppText.of(context);
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          AppTransitions.slideRight(const GroupsDiscoveryScreen()),
        ),
        child: Column(
          children: [
            Container(
              width: AppSize.avatarLg,
              height: AppSize.avatarLg,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primaryColor, width: 2),
                color: Colors.transparent,
              ),
              child: Icon(Icons.add, color: primaryColor),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              appLoc.translate('community.groups.new'),
              style: textStyles.labelS,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupItem(CommunityGroup group) {
    final palette = AppPalette.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;
    final textStyles = AppText.of(context);
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: AppSpacing.md),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          AppTransitions.slideRight(const GroupsDiscoveryScreen()),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: AppSize.avatarLg,
                  height: AppSize.avatarLg,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.surfaceVariant,
                  ),
                  child: ClipOval(
                    child: group.imageUrl.isNotEmpty
                        ? (group.imageUrl.startsWith('http')
                            ? AppImage(
                                imageUrl: group.imageUrl,
                                width: AppSize.avatarLg,
                                height: AppSize.avatarLg,
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
                              color: primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: palette.surface, width: 2)))),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              group.name,
              style: textStyles.labelS,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Topic filter chip row ────────────────────────────────────────────────────

class _TopicFilterRow extends StatelessWidget {
  final String? selectedTopic;
  final ValueChanged<String?> onTopicSelected;

  const _TopicFilterRow({
    required this.selectedTopic,
    required this.onTopicSelected,
  });

  @override
  Widget build(BuildContext context) {
    final appLoc = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return AppFilterBar(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      children: [
        AppFilterPill(
          label: appLoc.translate('community.topic_all'),
          icon: Icons.tag_rounded,
          active: selectedTopic == null,
          accent: palette.textSecondary,
          onTap: () => onTopicSelected(null),
        ),
        ...CommunityTopics.all.map((topic) {
          final color = CommunityTopics.colorFor(topic, palette);
          return AppFilterPill(
            label: appLoc.translate(CommunityTopics.labelKeyFor(topic)),
            icon: Icons.label_outline_rounded,
            active: selectedTopic == topic,
            accent: color,
            onTap: () =>
                onTopicSelected(selectedTopic == topic ? null : topic),
          );
        }),
      ],
    );
  }
}
