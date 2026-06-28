import 'dart:async' show unawaited;
import 'dart:ui';
import 'package:cookrange/core/widgets/app_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/services/chat_service.dart';
import 'package:cookrange/screens/common/generic_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/chat_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/theme/app_palette.dart';
import 'widgets/signal_dialog.dart';
import 'widgets/select_friend_sheet.dart';
import 'widgets/create_group_chat_sheet.dart';
import 'chat_detail_screen.dart';
import '../../core/providers/navigation_provider.dart';
import '../community/widgets/glass_refresher.dart';
import '../../core/widgets/side_menu.dart';
import '../../core/widgets/unified_action_sheet.dart';
import '../../core/providers/theme_provider.dart';
import 'ai_chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  int _selectedFilterIndex = 0;

  // Power FAB Animation
  late AnimationController _fabController;
  late Animation<double> _fabCreateAnimation;
  late Animation<double> _fabGroupAnimation;
  late Animation<double> _fabShareAnimation;
  late Animation<double> _fabSignalAnimation;
  bool _isFabOpen = false;

  // Search State
  bool _isSearchOpen = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  Future<void> _refreshChats() async {
    await Future.delayed(const Duration(seconds: 1));
    setState(() {});
  }

  // Menu Animation
  late AnimationController _menuController;
  NavigationProvider? _navProvider;

  // Stream state
  late Stream<List<ChatModel>> _chatStream;

  @override
  void initState() {
    super.initState();
    _menuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final currentUser = context.read<UserProvider>().user;
    if (currentUser != null) {
      _chatStream = ChatService().getUserChatsWithStatus(currentUser.uid);
    } else {
      _chatStream = const Stream.empty();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navProvider = context.read<NavigationProvider>();
      _navProvider?.addListener(_handleNavChange);
    });

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _fabCreateAnimation = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
    );
    _fabGroupAnimation = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
    );
    _fabShareAnimation = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    );
    _fabSignalAnimation = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _navProvider?.removeListener(_handleNavChange);
    _menuController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleNavChange() {
    if (!mounted) return;
    final nav = context.read<NavigationProvider>();

    if (nav.isMenuOpen &&
        _menuController.status != AnimationStatus.forward &&
        _menuController.status != AnimationStatus.completed) {
      _menuController.forward();
    } else if (!nav.isMenuOpen &&
        _menuController.status != AnimationStatus.reverse &&
        _menuController.status != AnimationStatus.dismissed) {
      _menuController.reverse();
    }
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
      if (_isFabOpen) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => AppLocalizations.of(context).translate(key);
    final palette = AppPalette.of(context);
    final currentUser = context.watch<UserProvider>().user;

    final List<String> filters = [
      t('chat.filters.all'),
      t('chat.filters.gym'),
      t('chat.filters.nutrition'),
      t('chat.filters.private')
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildBackgroundGlows(context, palette),

          Column(
            children: [
              _buildHeader(context, palette, filters),
              const SizedBox(height: 12),

              Expanded(
                child: GlassRefresher(
                  onRefresh: _refreshChats,
                  topPadding: 10,
                  child: currentUser == null
                      ? const Center(child: CircularProgressIndicator())
                      : StreamBuilder<List<ChatModel>>(
                          stream: _chatStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasError) {
                              return GenericErrorScreen(
                                onRetry: _refreshChats,
                                errorCode:
                                    'CGUC: ${snapshot.error.toString().length > 20 ? snapshot.error.toString().substring(0, 20) : snapshot.error.toString()}',
                              );
                            }

                            final allChats = snapshot.data ?? [];
                            final filteredChats = allChats.where((chat) {
                              if (_searchQuery.isNotEmpty) {
                                final name = chat.name?.toLowerCase() ?? "";
                                if (!name
                                    .contains(_searchQuery.toLowerCase())) {
                                  return false;
                                }
                              }

                              if (_selectedFilterIndex == 0) return true;
                              if (_selectedFilterIndex == 1) {
                                return chat.type == ChatType.gym;
                              }
                              if (_selectedFilterIndex == 2) {
                                return chat.type == ChatType.group &&
                                    chat.metadata?['subtype'] == 'nutrition';
                              }
                              if (_selectedFilterIndex == 3) {
                                return chat.type == ChatType.private;
                              }
                              return true;
                            }).toList();

                            if (filteredChats.isEmpty) {
                              return ListView(
                                physics: const BouncingScrollPhysics(
                                    parent: AlwaysScrollableScrollPhysics()),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                children: [
                                  if (_searchQuery.isEmpty)
                                    _buildSupportToast(context, palette),
                                  const SizedBox(height: 32),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(t('chat.no_chats_found'),
                                            style: TextStyle(
                                                color: palette.textSecondary)),
                                        if (snapshot.hasError)
                                          Text(snapshot.error.toString())
                                      ],
                                    ),
                                  )
                                ],
                              );
                            }

                            return ListView.builder(
                              physics: const BouncingScrollPhysics(
                                  parent: AlwaysScrollableScrollPhysics()),
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount: filteredChats.length + 1,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  if (_searchQuery.isNotEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return _buildAIBanner(context, palette);
                                }

                                final chat = filteredChats[index - 1];
                                return RepaintBoundary(
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => ChatDetailScreen(
                                                chat: chat,
                                              ),
                                            ),
                                          );
                                        },
                                        child: _buildChatCard(context, chat,
                                            palette, currentUser.uid),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
            ],
          ),

          // Floating Action Button Area
          Positioned(
            bottom: 24,
            right: 24,
            child: _buildFab(context, palette),
          ),

          // Side Menu Overlay
          AnimatedBuilder(
            animation: _menuController,
            builder: (context, child) {
              if (_menuController.isDismissed) return const SizedBox.shrink();
              return child!;
            },
            child: SideMenu(
              navProvider: context.read<NavigationProvider>(),
              animationController: _menuController,
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context, List<String> filters) {
    showUnifiedActionSheet(
      context: context,
      title: AppLocalizations.of(context).translate('chat.filter_title'),
      actions: List.generate(filters.length, (index) {
        return ActionSheetItem(
          label: filters[index],
          icon: index == 0
              ? Icons.all_inclusive
              : (index == 1
                  ? Icons.fitness_center
                  : (index == 2 ? Icons.restaurant : Icons.lock)),
          isSelected: _selectedFilterIndex == index,
          onTap: () {
            setState(() {
              _selectedFilterIndex = index;
            });
          },
        );
      }),
    );
  }

  Widget _buildHeader(
      BuildContext context, AppPalette palette, List<String> filters) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24, bottom: 12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, size: 28),
                      color: palette.textPrimary,
                      onPressed: () =>
                          context.read<NavigationProvider>().toggleMenu(true),
                    ),
                    Expanded(
                      child: _isSearchOpen
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)
                                    .translate('chat.list_title'),
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color: palette.textSecondary,
                                ),
                              ),
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                            )
                          : const SizedBox(),
                    ),
                    IconButton(
                      icon: Icon(_isSearchOpen ? Icons.close : Icons.search,
                          size: 28),
                      color: palette.textPrimary,
                      onPressed: () {
                        setState(() {
                          if (_isSearchOpen) {
                            _isSearchOpen = false;
                            _searchQuery = "";
                            _searchController.clear();
                          } else {
                            _isSearchOpen = true;
                          }
                        });
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.tune,
                          size: 28,
                          color: _selectedFilterIndex != 0
                              ? primary
                              : palette.textPrimary),
                      onPressed: () => _showFilterSheet(context, filters),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionChatCard(
      BuildContext context, ChatModel chat, AppPalette palette) {
    return _buildGlassCard(
      context,
      palette,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: palette.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                  color: palette.success.withValues(alpha: 0.2), width: 2),
            ),
            child: Icon(Icons.restaurant_menu, color: palette.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      chat.name ??
                          AppLocalizations.of(context)
                              .translate('chat.filters.nutrition'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (chat.lastMessage != null)
                      Text(
                        _formatTime(context, chat.lastMessage!.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chat.lastMessage?.text ?? '',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericGroupChatCard(
      BuildContext context, ChatModel chat, AppPalette palette) {
    return _buildGlassCard(
      context,
      palette,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            clipBehavior: Clip.antiAlias,
            child: chat.image != null
                ? AppImage(
                    imageUrl: chat.image!,
                    width: 56,
                    height: 56,
                    placeholder: Icon(Icons.group, color: palette.textTertiary),
                    errorWidget: Icon(Icons.error, color: palette.error),
                  )
                : Icon(Icons.group, color: palette.textTertiary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      chat.name ??
                          AppLocalizations.of(context)
                              .translate('chat.filters.gym'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (chat.lastMessage != null)
                      Text(
                        _formatTime(context, chat.lastMessage!.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.textTertiary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chat.lastMessage?.text ?? '',
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemChatCard(
      BuildContext context, ChatModel chat, AppPalette palette) {
    return _buildGlassCard(context, palette,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(chat.lastMessage?.text ?? 'System Message',
              style: TextStyle(color: palette.textPrimary)),
        ));
  }

  Widget _buildGlassCard(BuildContext context, AppPalette palette,
      {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildFab(BuildContext context, AppPalette palette) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_isFabOpen) ...[
          ScaleTransition(
            scale: _fabSignalAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.scrim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      AppLocalizations.of(context)
                          .translate('chat.signal_send'),
                      style: TextStyle(
                          color: palette.textInverse, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_signal',
                  onPressed: () async {
                    _toggleFab();
                    unawaited(showDialog(
                      context: context,
                      builder: (_) => const SignalDialog(),
                    ));
                  },
                  backgroundColor: palette.error,
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: _fabShareAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.scrim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      AppLocalizations.of(context)
                          .translate('chat.meal_share'),
                      style: TextStyle(
                          color: palette.textInverse, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_share',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(AppLocalizations.of(context)
                              .translate('chat.meal_share_soon'))),
                    );
                    _toggleFab();
                  },
                  backgroundColor: palette.warning,
                  child: const Icon(Icons.restaurant_menu, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: _fabGroupAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.scrim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      AppLocalizations.of(context)
                          .translate('chat.new_group'),
                      style: TextStyle(
                          color: palette.textInverse, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_group',
                  onPressed: () {
                    _toggleFab();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CreateGroupChatSheet(),
                    );
                  },
                  backgroundColor: palette.info,
                  child: const Icon(Icons.group_add, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ScaleTransition(
            scale: _fabCreateAnimation,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: palette.scrim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      AppLocalizations.of(context)
                          .translate('chat.new_chat'),
                      style: TextStyle(
                          color: palette.textInverse, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_create',
                  onPressed: () {
                    _toggleFab();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SelectFriendSheet(),
                    );
                  },
                  backgroundColor: palette.success,
                  child: Icon(Icons.chat_bubble_outline,
                      color: palette.textInverse),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: _toggleFab,
          backgroundColor: primary,
          child: AnimatedRotation(
            turns: _isFabOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }

  String _formatTime(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return AppLocalizations.of(context).translate('chat.time.days_ago',
          variables: {'d': difference.inDays.toString()});
    } else if (difference.inHours > 0) {
      return AppLocalizations.of(context).translate('chat.time.hours_ago',
          variables: {'h': difference.inHours.toString()});
    } else if (difference.inMinutes > 0) {
      return AppLocalizations.of(context).translate('chat.time.mins_ago',
          variables: {'m': difference.inMinutes.toString()});
    } else {
      return AppLocalizations.of(context).translate('chat.time.now');
    }
  }

  Widget _buildBackgroundGlows(BuildContext context, AppPalette palette) {
    final size = MediaQuery.of(context).size;
    final primary = context.watch<ThemeProvider>().primaryColor;
    return RepaintBoundary(
      child: Container(
        color: palette.background,
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -50,
              child: _glowBlob(300, primary.withValues(alpha: 0.2)),
            ),
            Positioned(
              top: size.height * 0.4,
              left: -100,
              child: _glowBlob(350, primary.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 50,
              right: -80,
              child: _glowBlob(320, primary.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIBanner(BuildContext context, AppPalette palette) {
    String t(String key) => AppLocalizations.of(context).translate(key);
    final primary = context.read<ThemeProvider>().primaryColor;
    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AIChatScreen())),
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primary, primary.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.smart_toy_outlined,
                  size: 24.sp, color: Colors.white),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('ai_chat.banner_title'),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    t('ai_chat.banner_subtitle'),
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 16.sp, color: Colors.white.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportToast(BuildContext context, AppPalette palette) {
    return Dismissible(
      key: const Key('support_toast'),
      onDismissed: (direction) {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              palette.error.withValues(alpha: 0.12),
              palette.error.withValues(alpha: 0.06),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: palette.error.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              Container(
                color: palette.surface.withValues(alpha: 0.2),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: palette.warning.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: palette.surface, width: 2),
                          ),
                          child: Center(
                            child: Icon(Icons.person,
                                color: palette.warning),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: palette.error,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: palette.surface, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                "!",
                                style: TextStyle(
                                  color: palette.textInverse,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Caner, destek bekliyor!",
                            style: TextStyle(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Bench Press\nMacFit - Peron 3",
                            style: TextStyle(
                              color: palette.error.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppPalette.sunsetB,
                            AppPalette.sunsetC,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppPalette.brand.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Text(
                            "YOLDAYIM",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text("✋", style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGymChatCard(
      BuildContext context, ChatModel chat, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: palette.success.withValues(alpha: 0.3),
                        width: 2),
                    color: palette.surface,
                  ),
                  child: ClipOval(
                    child: chat.image != null
                        ? AppImage(
                            imageUrl: chat.image!,
                            width: 56,
                            height: 56,
                          )
                        : Icon(Icons.fitness_center,
                            color: palette.textPrimary),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: palette.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.name ?? 'Gym Chat',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        "10:42",
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text("🔥", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        chat.metadata?['status_text'] ?? "14 Kişi Antrenmanda",
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text("🗓️", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        chat.metadata?['event_text'] ?? "Etkinlik Günü: Yoga",
                        style: TextStyle(
                          color: palette.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrivateChatCard(BuildContext context, ChatModel chat,
      AppPalette palette, String currentUserId) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: chat.image != null
                      ? AppImage(
                          imageUrl: chat.image!,
                          width: 56,
                          height: 56,
                          placeholder: Icon(
                            Icons.person,
                            color: palette.textTertiary,
                            size: 30,
                          ),
                          errorWidget: Icon(
                            Icons.error,
                            color: palette.error,
                            size: 30,
                          ),
                        )
                      : Icon(Icons.person,
                          color: palette.textTertiary, size: 30),
                ),
                if (chat.metadata?['is_online'] ?? false)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: palette.surface),
                        boxShadow: [
                          BoxShadow(
                              color: palette.shadow.withValues(alpha: 0.1),
                              blurRadius: 4)
                        ],
                      ),
                      alignment: Alignment.center,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat.name ?? 'User',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: palette.textPrimary,
                        ),
                      ),
                      Text(
                        chat.lastMessage != null
                            ? _formatTime(context, chat.lastMessage!.timestamp)
                            : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage?.text ?? '',
                          style: TextStyle(
                            color: palette.textSecondary,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.lastMessage?.senderId == currentUserId) ...[
                        const SizedBox(width: 4),
                        Icon(
                          chat.lastMessage?.isRead == true
                              ? Icons.done_all
                              : Icons.done,
                          size: 16,
                          color: chat.lastMessage?.isRead == true
                              ? palette.info
                              : palette.textTertiary,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeChatCard(
      BuildContext context, ChatModel chat, AppPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.success.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.ramen_dining,
                  color: palette.success, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.name ?? 'Group',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: palette.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        "08:30",
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: palette.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: palette.warning.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Text("🥕",
                                style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              "${chat.metadata?['new_recipes_count']} Yeni Tarif",
                              style: TextStyle(
                                  color: palette.warning,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "~ Popüler",
                        style: TextStyle(
                            color: palette.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat.lastMessage?.text ?? '',
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatCard(BuildContext context, ChatModel chat, AppPalette palette,
      String currentUserId) {
    if (chat.metadata?['subtype'] == 'recipe') {
      return _buildRecipeChatCard(context, chat, palette);
    }
    switch (chat.type) {
      case ChatType.gym:
        return _buildGymChatCard(context, chat, palette);
      case ChatType.private:
        return _buildPrivateChatCard(context, chat, palette, currentUserId);
      case ChatType.group:
        if (chat.metadata?['subtype'] == 'nutrition') {
          return _buildNutritionChatCard(context, chat, palette);
        }
        return _buildGenericGroupChatCard(context, chat, palette);
      case ChatType.system:
        return _buildSystemChatCard(context, chat, palette);
    }
  }

  Widget _glowBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
