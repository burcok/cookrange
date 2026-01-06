import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/services/chat_service.dart';
import 'package:cookrange/screens/common/generic_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/chat_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/models/message_model.dart';
import 'widgets/signal_dialog.dart';
import 'widgets/select_friend_sheet.dart';
import 'chat_detail_screen.dart';
import '../../core/services/navigation_provider.dart';
import '../community/widgets/glass_refresher.dart';
import '../../core/widgets/side_menu.dart';
import '../../core/widgets/unified_action_sheet.dart';
import '../../core/providers/theme_provider.dart';

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
  late Animation<double> _fabShareAnimation;
  late Animation<double> _fabSignalAnimation;
  bool _isFabOpen = false;

  // Search State
  bool _isSearchOpen = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  Future<void> _refreshChats() async {
    // Simulate refresh for UI effect since streams update automatically
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

    // Initialize Chat Stream
    final currentUser = context.read<UserProvider>().user;
    if (currentUser != null) {
      _chatStream = ChatService().getUserChatsWithStatus(currentUser.uid);
    } else {
      _chatStream = const Stream.empty();
    }

    // Dump Data
    // _chatStream = Stream.value(_getDumpChats());

    // Defer listener to avoid build conflicts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navProvider = context.read<NavigationProvider>();
      _navProvider?.addListener(_handleNavChange);
    });

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    // Staggered animations for FAB items
    _fabCreateAnimation = CurvedAnimation(
      parent: _fabController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
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
    // Localization helper
    String t(String key) => AppLocalizations.of(context).translate(key);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = context.watch<UserProvider>().user;

    // Filters from translation
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
          // Background Blurs (Fixed Position)
          _buildBackgroundGlows(context),

          // Main Content
          Column(
            children: [
              // Header
              _buildHeader(context, isDark, filters),
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

                            // Filter Logic
                            final allChats = snapshot.data ?? [];
                            final filteredChats = allChats.where((chat) {
                              // Search Filter
                              if (_searchQuery.isNotEmpty) {
                                final name = chat.name?.toLowerCase() ?? "";
                                if (!name
                                    .contains(_searchQuery.toLowerCase())) {
                                  return false;
                                }
                              }

                              if (_selectedFilterIndex == 0) return true; // All
                              if (_selectedFilterIndex == 1)
                                return chat.type == ChatType.gym; // Gym
                              if (_selectedFilterIndex == 2)
                                return chat.type == ChatType.group &&
                                    chat.metadata?['subtype'] == 'nutrition';
                              if (_selectedFilterIndex == 3)
                                return chat.type == ChatType.private;
                              return true;
                            }).toList();

                            if (filteredChats.isEmpty) {
                              return ListView(
                                physics: const BouncingScrollPhysics(
                                    parent:
                                        AlwaysScrollableScrollPhysics()), // Enforce bounce for GlassRefresher
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                children: [
                                  if (_searchQuery.isEmpty)
                                    _buildSupportToast(context),
                                  const SizedBox(height: 32),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(t('chat.no_chats_found'),
                                            style: TextStyle(
                                                color: isDark
                                                    ? Colors.grey
                                                    : Colors.black54)),
                                        // Optional: Add a button to retry or debug
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
                                  parent:
                                      AlwaysScrollableScrollPhysics()), // Enforce bounce for GlassRefresher
                              padding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 100),
                              itemCount:
                                  filteredChats.length + 1, // +1 for Help Card
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  // Don't show help card if searching to focus on results
                                  if (_searchQuery.isNotEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  // Placeholder for commented out support toast
                                  return const SizedBox.shrink();
                                }

                                final chat =
                                    filteredChats[index - 1]; // Offset by 1
                                return Column(
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
                                      child: _buildChatCard(
                                          context,
                                          chat,
                                          isDark,
                                          "current_user_id_placeholder"),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
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
            child: _buildFab(context),
          ),

          // Side Menu Overlay
          AnimatedBuilder(
            animation: _menuController,
            builder: (context, child) {
              return SideMenu(
                navProvider: context.read<NavigationProvider>(),
                animationController: _menuController,
              );
            },
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

  Widget _buildHeader(BuildContext context, bool isDark, List<String> filters) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
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
                      color: isDark ? Colors.white : Colors.black,
                      onPressed: () =>
                          context.read<NavigationProvider>().toggleMenu(true),
                    ),
                    Expanded(
                      child: _isSearchOpen
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context).translate(
                                    'chat.list_title'), // Using title as hint for now "Cookrange Chat" or "Search..."
                                border: InputBorder.none,
                                hintStyle: TextStyle(
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
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
                      color: isDark ? Colors.white : Colors.black,
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
                              ? primaryColor
                              : (isDark ? Colors.white : Colors.black)),
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
      BuildContext context, ChatModel chat, bool isDark) {
    return _buildGlassCard(
      context,
      isDark,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.green.shade100, width: 2),
            ),
            child: const Icon(Icons.restaurant_menu, color: Colors.green),
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
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    ),
                    if (chat.lastMessage != null)
                      Text(
                        _formatTime(
                            context, chat.lastMessage!.timestamp), // Helper
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chat.lastMessage?.text ?? '',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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
      BuildContext context, ChatModel chat, bool isDark) {
    return _buildGlassCard(
      context,
      isDark,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: chat.image != null
                ? CachedNetworkImage(
                    imageUrl: chat.image!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Icon(Icons.group),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  )
                : const Icon(Icons.group),
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
                        color: isDark ? Colors.white : Colors.grey.shade900,
                      ),
                    ),
                    if (chat.lastMessage != null)
                      Text(
                        _formatTime(context, chat.lastMessage!.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  chat.lastMessage?.text ?? '',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
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
      BuildContext context, ChatModel chat, bool isDark) {
    return _buildGlassCard(context, isDark,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(chat.lastMessage?.text ?? 'System Message',
              style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        ));
  }

  Widget _buildGlassCard(BuildContext context, bool isDark,
      {required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey.shade900.withOpacity(0.6)
                : Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white.withOpacity(0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
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
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      AppLocalizations.of(context)
                          .translate('chat.signal_send'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  heroTag: 'fab_signal',
                  onPressed: () async {
                    _toggleFab();
                    showDialog(
                      context: context,
                      builder: (_) => const SignalDialog(),
                    );
                  },
                  backgroundColor: Colors.red,
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
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      AppLocalizations.of(context).translate('chat.meal_share'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
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
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.restaurant_menu, color: Colors.white),
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
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                      AppLocalizations.of(context).translate('chat.new_chat'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
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
                  backgroundColor: const Color.fromARGB(255, 61, 144, 64),
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Color.fromARGB(255, 150, 255, 30)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: _toggleFab,
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).primaryColor
              : Colors.black,
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

  Widget _buildBackgroundGlows(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return RepaintBoundary(
      child: Container(
        color: const Color(0xFFFCFBF9),
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -50,
              child: _glowBlob(
                  300,
                  context
                      .watch<ThemeProvider>()
                      .primaryColor
                      .withValues(alpha: 0.2)),
            ),
            Positioned(
              top: size.height * 0.4,
              left: -100,
              child: _glowBlob(
                  350,
                  context
                      .watch<ThemeProvider>()
                      .primaryColor
                      .withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: 50,
              right: -80,
              child: _glowBlob(
                  320,
                  context
                      .watch<ThemeProvider>()
                      .primaryColor
                      .withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportToast(BuildContext context) {
    return Dismissible(
      key: const Key('support_toast'),
      onDismissed: (direction) {
        // Handle dismiss if needed
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFFFDE8E8), Color(0xFFFDF2F8)], // Light pinkish
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Glass Effect (Lite - Opacity only)
              Container(
                color: Colors.white.withOpacity(0.2),
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
                            color: const Color(0xFFFFF7ED),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Center(
                            child:
                                Icon(Icons.person, color: Colors.orangeAccent),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Text(
                                "!",
                                style: TextStyle(
                                  color: Colors.white,
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
                          const Text(
                            "Caner, destek bekliyor!",
                            style: TextStyle(
                              color: Color(0xFF1F2937),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Bench Press\nMacFit - Peron 3",
                            style: TextStyle(
                              color: const Color(0xFFDC2626).withOpacity(0.8),
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
                          colors: [Color(0xFFF97316), Color(0xFFEA580C)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: const [
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

  // Override to inject custom dump data
  List<ChatModel> _getDumpChats() {
    return [
      ChatModel(
        id: '1',
        name: "Gold's Gym - Beşiktaş",
        type: ChatType.gym,
        updatedAt: DateTime.now(), // Added
        image: null,
        lastMessage: MessageModel(
            id: 'm1',
            senderId: 's1',
            text: 'Etkinlik Günü: Yoga',
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            type: MessageType.text,
            isRead: true),
        unreadCounts: {'sys': 1}, // Simulate unread dot
        participants: ['me', 'gym'],
        metadata: {
          'peopleCount': 14,
          'status_text': '14 Kişi Antrenmanda',
          'event_text': 'Etkinlik Günü: Yoga'
        },
      ),
      ChatModel(
        id: '2',
        name: "Mert Akın",
        type: ChatType.private, // Using private for generic user
        updatedAt: DateTime.now(), // Added
        image: null, // Placeholder will be used or we can use specific image
        lastMessage: MessageModel(
            id: 'm2',
            senderId: 'merta',
            text: 'Akşamki antrenmana pre-workout ...',
            timestamp: DateTime.now().subtract(const Duration(hours: 1)),
            type: MessageType.text,
            isRead: true),
        unreadCounts: {},
        participants: ['me', 'merta'],
        metadata: {'status': '🏋️'},
      ),
      ChatModel(
        id: '3',
        name: "Sağlıklı Tarifler Grubu",
        type: ChatType.group,
        updatedAt: DateTime.now(), // Added
        image: null,
        metadata: {'subtype': 'recipe', 'new_recipes_count': 45},
        lastMessage: MessageModel(
            id: 'm3',
            senderId: 'selin',
            text:
                'Selin: Yulaf ezmeli pancake tarifini denedim, harika oldu! Fotoğrafını attım 👇',
            timestamp: DateTime.now().subtract(const Duration(hours: 2)),
            type: MessageType.text,
            isRead: true),
        unreadCounts: {},
        participants: ['me', 'group1'],
      ),
      ChatModel(
        id: '4',
        name: "Ayşe Yılmaz",
        type: ChatType.private,
        updatedAt: DateTime.now(), // Added
        image:
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&q=80&w=150&h=150',
        lastMessage: MessageModel(
            id: 'm4',
            senderId: 'ayse',
            text: 'Dinlenme günüm bugün, yarın görüşür...',
            timestamp: DateTime.now().subtract(const Duration(days: 1)),
            type: MessageType.text,
            isRead: true),
        unreadCounts: {'me': 1}, // Shows blue dot
        participants: ['me', 'ayse'],
      ),
    ];
  }

  // UPDATED BUILDERS for Glass UI

  // UPDATED BUILDERS for Glass UI

  Widget _buildGymChatCard(BuildContext context, ChatModel chat, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6).withOpacity(0.8), // Light grayish bg
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
                        color: const Color(0xFFD1FAE5),
                        width: 2), // Greenish ring
                    color: Colors.white,
                  ),
                  child: ClipOval(
                    child: chat.image != null
                        ? Image.network(chat.image!, fit: BoxFit.cover)
                        : const Icon(Icons.fitness_center, color: Colors.black),
                  ),
                ),
                // Red dot
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444), // Red
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF111827), // Dark text
                          ),
                        ),
                      ),
                      Text(
                        "10:42", // Hardcoded for dump data match
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Custom Gym Status Rows
                  Row(
                    children: [
                      const Text("🔥", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        chat.metadata?['status_text'] ?? "14 Kişi Antrenmanda",
                        style: const TextStyle(
                          color: Color(0xFF4B5563),
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
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
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

  Widget _buildPrivateChatCard(
      BuildContext context, ChatModel chat, bool isDark, String currentUserId) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6).withOpacity(0.6), // Very light
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
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: chat.image != null
                      ? CachedNetworkImage(
                          imageUrl: chat.image!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Icon(
                            Icons.person,
                            color: Colors.grey,
                            size: 30,
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.error,
                            color: Colors.red,
                            size: 30,
                          ),
                        )
                      : const Icon(Icons.person, color: Colors.grey, size: 30),
                ),
                if (chat.metadata?['is_online'] ?? false) //online check
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        "09:15",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
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
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all,
                          size: 16, color: Color(0xFF3B82F6)), // Blue tick
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

  // Renaming/Overriding for Recipe Card specifically
  Widget _buildRecipeChatCard(
      BuildContext context, ChatModel chat, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5).withOpacity(0.6), // Very light green bg
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
                color: const Color(0xFFD1FAE5), // Light green
                borderRadius: BorderRadius.circular(16), // Rounded squareish
              ),
              child: const Icon(Icons.ramen_dining,
                  color: Color(0xFF059669), size: 28), // Bowl icon
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      Text(
                        "08:30",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
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
                          color: const Color(0xFFFEF3C7), // Light orange/yellow
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFDE68A)), // border
                        ),
                        child: Row(
                          children: [
                            const Text("🥕", style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Text(
                              "${chat.metadata?['new_recipes_count']} Yeni Tarif",
                              style: const TextStyle(
                                  color: Color(0xFFD97706),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "~ Popüler",
                        style: TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chat.lastMessage?.text ?? '',
                    style: TextStyle(
                      color: Colors.grey.shade600,
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

  Widget _buildChatCard(
      BuildContext context, ChatModel chat, bool isDark, String currentUserId) {
    if (chat.metadata?['subtype'] == 'recipe') {
      return _buildRecipeChatCard(context, chat, isDark);
    }
    switch (chat.type) {
      case ChatType.gym:
        return _buildGymChatCard(context, chat, isDark);
      case ChatType.private:
        return _buildPrivateChatCard(context, chat, isDark, currentUserId);
      case ChatType.group:
        if (chat.metadata?['subtype'] == 'nutrition') {
          return _buildNutritionChatCard(context, chat, isDark);
        }
        return _buildGenericGroupChatCard(context, chat, isDark);
      case ChatType.system:
        return _buildSystemChatCard(context, chat, isDark);
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
