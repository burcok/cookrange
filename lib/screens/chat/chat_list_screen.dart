import 'dart:async' show unawaited;
import 'dart:ui';
import 'package:cookrange/core/widgets/app_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/services/chat_service.dart';
import 'package:cookrange/screens/common/generic_error_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import '../../core/models/chat_model.dart';
import '../../core/models/chat_prefs_model.dart';
import '../../core/models/message_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/utils/chat_list_filter.dart';
import 'widgets/signal_dialog.dart';
import 'widgets/select_friend_sheet.dart';
import 'widgets/create_group_chat_sheet.dart';
import 'chat_detail_screen.dart';
import '../community/widgets/glass_refresher.dart';
import '../../core/widgets/unified_action_sheet.dart';
import '../../core/providers/theme_provider.dart';
import 'ai_chat_screen.dart';
import '../../core/widgets/ds/ds.dart';
import '../community/user_search_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  // Faz 2 §2.4 — segmented filter (Tümü/Gruplar/Salon/DM) + independent
  // unread toggle. Replaces the old single-select bottom-sheet filter
  // (`_showFilterSheet`, removed) with an always-visible `AppFilterBar` —
  // more discoverable for a 4-way content filter than a hidden sheet (R7).
  ChatListSegment _segment = ChatListSegment.all;
  bool _unreadOnly = false;

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

  // Stream state
  late Stream<List<ChatModel>> _chatStream;
  late Stream<ChatPrefsModel> _chatPrefsStream;

  @override
  void initState() {
    super.initState();

    final currentUser = context.read<UserProvider>().user;
    if (currentUser != null) {
      _chatStream = ChatService().getUserChatsWithStatus(currentUser.uid);
      _chatPrefsStream = ChatService().getChatPrefsStream(currentUser.uid);
    } else {
      _chatStream = const Stream.empty();
      _chatPrefsStream = const Stream.empty();
    }

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
    _fabController.dispose();
    _searchController.dispose();
    super.dispose();
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildBackgroundGlows(context, palette),

          Column(
            children: [
              _buildHeader(context, palette),
              const SizedBox(height: 12),
              _buildFilterBar(context, t),
              const SizedBox(height: 10),
              Expanded(
                child: GlassRefresher(
                  onRefresh: _refreshChats,
                  topPadding: 10,
                  child: currentUser == null
                      ? const Center(child: CircularProgressIndicator())
                      // Faz 2 §2.4 — two independent streams (chat list +
                      // per-user chat_prefs), nested rather than hand-merged:
                      // `chat_prefs` is a single document, not a per-item
                      // collection like the online-status merge
                      // `getUserChatsWithStatus` already needs internally.
                      : StreamBuilder<ChatPrefsModel>(
                          stream: _chatPrefsStream,
                          builder: (context, prefsSnapshot) {
                            final prefs =
                                prefsSnapshot.data ?? ChatPrefsModel.empty;
                            return StreamBuilder<List<ChatModel>>(
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
                                final archivedCount = ChatListFilter.apply(
                                  chats: allChats,
                                  prefs: prefs,
                                  currentUserId: currentUser.uid,
                                  archivedOnly: true,
                                ).length;
                                final filteredChats = ChatListFilter.apply(
                                  chats: allChats,
                                  prefs: prefs,
                                  currentUserId: currentUser.uid,
                                  segment: _segment,
                                  unreadOnly: _unreadOnly,
                                  searchQuery: _searchQuery,
                                );

                                // Optional leading rows (AI banner, then the
                                // "Archived (N)" entry point) — both skipped
                                // while searching, mirroring the AI banner's
                                // pre-existing search behavior.
                                final leadingItems = <Widget>[
                                  if (_searchQuery.isEmpty)
                                    _buildAIBanner(context, palette),
                                  if (_searchQuery.isEmpty && archivedCount > 0)
                                    _buildArchivedRow(
                                      context,
                                      palette,
                                      archivedCount,
                                      allChats,
                                      prefs,
                                      currentUser.uid,
                                    ),
                                ];

                                if (filteredChats.isEmpty) {
                                  return ListView(
                                    physics: const BouncingScrollPhysics(
                                        parent:
                                            AlwaysScrollableScrollPhysics()),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 100),
                                    children: [
                                      const SizedBox(height: 32),
                                      ...leadingItems,
                                      _buildEmptyStateWithGlow(
                                          context, palette, t,
                                          unreadOnly: _unreadOnly),
                                    ],
                                  );
                                }

                                return ListView.builder(
                                  physics: const BouncingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics()),
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                  itemCount: filteredChats.length +
                                      leadingItems.length,
                                  itemBuilder: (context, index) {
                                    if (index < leadingItems.length) {
                                      return leadingItems[index];
                                    }

                                    final chat = filteredChats[
                                        index - leadingItems.length];
                                    return RepaintBoundary(
                                      child: Column(
                                        children: [
                                          _buildSwipeableChatCard(
                                            context,
                                            chat,
                                            palette,
                                            currentUser.uid,
                                            prefs,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    );
                                  },
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
        ],
      ),
    );
  }

  /// Faz 2 §2.4 — segmented content filter (Tümü/Gruplar/Salon/DM) + an
  /// independent "Unread" toggle, in the app's canonical horizontal
  /// filter-bar component (`AppFilterBar`/`AppFilterPill` — already the
  /// established pattern for gym/coach discovery, program marketplace,
  /// community feed, and group discovery; see that widget's doc comment).
  /// Replaces the old hidden bottom-sheet single-select (`_showFilterSheet`,
  /// removed) — a top-level content filter this central to the screen reads
  /// better always-visible than behind an extra tap (R7).
  Widget _buildFilterBar(BuildContext context, String Function(String) t) {
    return AppFilterBar(
      children: [
        AppFilterPill(
          label: t('chat.filters.all'),
          active: _segment == ChatListSegment.all,
          onTap: () => setState(() => _segment = ChatListSegment.all),
        ),
        AppFilterPill(
          label: t('chat.filters.groups'),
          icon: Icons.groups_rounded,
          active: _segment == ChatListSegment.groups,
          onTap: () => setState(() => _segment = ChatListSegment.groups),
        ),
        AppFilterPill(
          label: t('chat.filters.gym'),
          icon: Icons.fitness_center_rounded,
          active: _segment == ChatListSegment.gym,
          onTap: () => setState(() => _segment = ChatListSegment.gym),
        ),
        AppFilterPill(
          label: t('chat.filters.private'),
          icon: Icons.person_rounded,
          active: _segment == ChatListSegment.dm,
          onTap: () => setState(() => _segment = ChatListSegment.dm),
        ),
        const AppFilterDivider(),
        AppFilterPill(
          label: t('chat.unread_filter'),
          icon: Icons.mark_chat_unread_rounded,
          active: _unreadOnly,
          onTap: () => setState(() => _unreadOnly = !_unreadOnly),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, AppPalette palette) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding:
              EdgeInsets.only(top: MediaQuery.of(context).padding.top + 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Back button
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20, color: palette.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                    // Title or search field
                    Expanded(
                      child: _isSearchOpen
                          ? TextField(
                              controller: _searchController,
                              autofocus: true,
                              decoration: InputDecoration(
                                hintText: AppLocalizations.of(context)
                                    .translate('chat.list_title'),
                                border: InputBorder.none,
                                hintStyle:
                                    TextStyle(color: palette.textSecondary),
                              ),
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                            )
                          : Text(
                              AppLocalizations.of(context)
                                  .translate('chat.list_title'),
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                fontFamily: 'Poppins',
                              ),
                            ),
                    ),
                    // Search toggle
                    IconButton(
                      icon: Icon(_isSearchOpen ? Icons.close : Icons.search,
                          size: 24, color: palette.textPrimary),
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
                  ],
                ),
              ),
              // 2px brand gradient accent line at the bottom of the AppBar
              Container(
                height: 2,
                margin: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primary.withValues(alpha: 0.0),
                      primary,
                      AppPalette.energyLight,
                      primary.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Faz 2 §2.4 — "Archived (N)" entry point, shown above the list (below the
  /// AI banner) only while there's at least one archived chat and the user
  /// isn't searching. Opens a snapshot sheet of the archived set; unlike the
  /// main list this is a one-shot filter over the already-loaded [allChats]
  /// (not independently re-subscribed), matching the scope of a folder you
  /// dip into rather than a primary live surface.
  Widget _buildArchivedRow(
    BuildContext context,
    AppPalette palette,
    int count,
    List<ChatModel> allChats,
    ChatPrefsModel prefs,
    String currentUserId,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () =>
            _showArchivedChatsSheet(context, allChats, prefs, currentUserId),
        child: AppGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.archive_rounded,
                  color: palette.textSecondary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).translate(
                      'chat.archived_row.title',
                      variables: {'count': '$count'}),
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: palette.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showArchivedChatsSheet(
    BuildContext context,
    List<ChatModel> allChats,
    ChatPrefsModel prefs,
    String currentUserId,
  ) {
    final archived = ChatListFilter.apply(
      chats: allChats,
      prefs: prefs,
      currentUserId: currentUserId,
      archivedOnly: true,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final palette = AppPalette.of(sheetContext);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
              ),
              decoration:
                  BoxDecoration(color: palette.surface.withValues(alpha: 0.96)),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        AppLocalizations.of(sheetContext)
                            .translate('chat.archived_sheet.title'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Flexible(
                      child: archived.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 32),
                              child: Text(
                                AppLocalizations.of(sheetContext)
                                    .translate('chat.archived_sheet.empty'),
                                style: TextStyle(color: palette.textSecondary),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: archived.length,
                              itemBuilder: (itemContext, index) {
                                final chat = archived[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            Navigator.pop(sheetContext);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ChatDetailScreen(
                                                        chat: chat),
                                              ),
                                            );
                                          },
                                          child: _buildChatCard(
                                            itemContext,
                                            chat,
                                            palette,
                                            currentUserId,
                                            isPinned: prefs.isPinned(chat.id),
                                            isMuted: prefs.isMuted(chat.id),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.unarchive_rounded,
                                            color: palette.info),
                                        onPressed: () => _toggleArchive(context,
                                            chat.id, currentUserId, true),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Long-press context menu — full pin/archive/mute/delete coverage,
  /// mirroring the message bubble's `AppMessageContextMenu` long-press
  /// pattern (Faz 2 §2.2) and reusing this app's generic
  /// `showUnifiedActionSheet`/`ActionSheetItem` (the same component this
  /// screen already used for its old filter sheet).
  void _showChatActionsSheet(BuildContext context, ChatModel chat,
      ChatPrefsModel prefs, String currentUserId) {
    final l10n = AppLocalizations.of(context);
    final isPinned = prefs.isPinned(chat.id);
    final isArchived = prefs.isArchived(chat.id);
    final isMuted = prefs.isMuted(chat.id);

    showUnifiedActionSheet(
      context: context,
      title: chat.name,
      cancelLabel: l10n.translate('common.cancel'),
      actions: [
        ActionSheetItem(
          label: l10n.translate(
              isPinned ? 'chat.list_actions.unpin' : 'chat.list_actions.pin'),
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          isSelected: isPinned,
          onTap: () => _togglePin(context, chat.id, currentUserId, isPinned),
        ),
        ActionSheetItem(
          label: l10n.translate(isArchived
              ? 'chat.list_actions.unarchive'
              : 'chat.list_actions.archive'),
          icon: isArchived ? Icons.unarchive_rounded : Icons.archive_outlined,
          onTap: () =>
              _toggleArchive(context, chat.id, currentUserId, isArchived),
        ),
        ActionSheetItem(
          label: l10n.translate(
              isMuted ? 'chat.list_actions.unmute' : 'chat.list_actions.mute'),
          icon: isMuted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          isSelected: isMuted,
          onTap: () => _toggleMute(context, chat.id, currentUserId, isMuted),
        ),
        ActionSheetItem(
          label: l10n.translate('chat.list_actions.delete'),
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          onTap: () => _confirmDeleteChat(context, chat, currentUserId),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteChat(
      BuildContext context, ChatModel chat, String currentUserId) async {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(l10n.translate('chat.delete_chat_confirm.title'),
            style: AppText.of(context)
                .titleM
                .copyWith(color: palette.textPrimary)),
        content: Text(
          l10n.translate('chat.delete_chat_confirm.message'),
          style:
              AppText.of(context).bodyM.copyWith(color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.translate('common.delete'),
                style: TextStyle(color: palette.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    unawaited(HapticFeedback.mediumImpact());
    try {
      await ChatService().deleteChatForMe(currentUserId, chat.id);
      if (!context.mounted) return;
      AppSnackBar.success(context, l10n.translate('chat.toast.deleted'));
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, l10n.translate('common.something_wrong'));
    }
  }

  Future<void> _togglePin(BuildContext context, String chatId,
      String currentUserId, bool currentlyPinned) async {
    unawaited(HapticFeedback.selectionClick());
    try {
      if (currentlyPinned) {
        await ChatService().unpinChat(currentUserId, chatId);
      } else {
        await ChatService().pinChat(currentUserId, chatId);
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context,
          AppLocalizations.of(context).translate('common.something_wrong'));
    }
  }

  Future<void> _toggleMute(BuildContext context, String chatId,
      String currentUserId, bool currentlyMuted) async {
    unawaited(HapticFeedback.selectionClick());
    try {
      if (currentlyMuted) {
        await ChatService().unmuteChat(currentUserId, chatId);
      } else {
        await ChatService().muteChat(currentUserId, chatId);
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context,
          AppLocalizations.of(context).translate('common.something_wrong'));
    }
  }

  /// Also the swipe-to-archive handler (`_buildSwipeableChatCard`'s
  /// `confirmDismiss`), so this stays snackbar-only feedback (no haptic) —
  /// the swipe gesture itself already provides tactile confirmation via
  /// `Dismissible`'s own drag/settle motion.
  Future<void> _toggleArchive(BuildContext context, String chatId,
      String currentUserId, bool currentlyArchived) async {
    final l10n = AppLocalizations.of(context);
    try {
      if (currentlyArchived) {
        await ChatService().unarchiveChat(currentUserId, chatId);
        if (!context.mounted) return;
        AppSnackBar.info(context, l10n.translate('chat.toast.unarchived'));
      } else {
        await ChatService().archiveChat(currentUserId, chatId);
        if (!context.mounted) return;
        AppSnackBar.success(context, l10n.translate('chat.toast.archived'));
      }
    } catch (e) {
      if (!context.mounted) return;
      AppSnackBar.error(context, l10n.translate('common.something_wrong'));
    }
  }

  /// Faz 2 §2.4 swipe action. `DismissDirection.endToStart` matches this
  /// app's own established direction (`notification_screen.dart`,
  /// `shopping_list_screen.dart`, `gym_members_screen.dart` all swipe
  /// right-to-left). Archive (not delete) is the swipe action — reversible
  /// and low-regret, so `confirmDismiss` does the toggle and returns `false`
  /// to snap back rather than remove the tile, exactly the pattern
  /// `gym_members_screen.dart`'s `_MemberTile` already uses for its own
  /// non-destructive swipe. Pin/Mute/Delete live one long-press away
  /// (`_showChatActionsSheet`) — Dismissible only has two directions, and the
  /// one truly destructive action (delete) deliberately requires the extra
  /// deliberate step of opening that menu, not a stray swipe.
  Widget _buildSwipeableChatCard(
    BuildContext context,
    ChatModel chat,
    AppPalette palette,
    String currentUserId,
    ChatPrefsModel prefs,
  ) {
    final isArchived = prefs.isArchived(chat.id);
    final isPinned = prefs.isPinned(chat.id);
    final isMuted = prefs.isMuted(chat.id);

    return Dismissible(
      key: ValueKey('chat_list_${chat.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _toggleArchive(context, chat.id, currentUserId, isArchived);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: (isArchived ? palette.info : palette.warning)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
          color: isArchived ? palette.info : palette.warning,
          size: 22,
        ),
      ),
      child: GestureDetector(
        onTap: () async {
          // Faz 5 §5.4 — Entitlements.groupChat, corrected to `true` (see
          // that getter's doc comment in subscription_model.dart): group
          // chat has been a free, core feature since Faz 2 (K5/K8), so
          // this never blocks anyone — it's the single, real entry point
          // for the group-chat-specific piece of that getter, distinct
          // from a plain DM (`chat.groupId == null` skips it entirely).
          if (chat.groupId != null &&
              !await FeatureGateService().check(context, (e) => e.groupChat)) {
            return;
          }
          if (!context.mounted) return;
          unawaited(Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ChatDetailScreen(chat: chat)),
          ));
        },
        onLongPress: () {
          unawaited(HapticFeedback.selectionClick());
          _showChatActionsSheet(context, chat, prefs, currentUserId);
        },
        child: _buildChatCard(
          context,
          chat,
          palette,
          currentUserId,
          isPinned: isPinned,
          isMuted: isMuted,
        ),
      ),
    );
  }

  /// Faz 2 §2.1: `lastMessage.body` is empty for image messages (media now
  /// lives in attachments[], never stuffed into body — unlike the old
  /// model) — show a friendly label instead of a blank preview.
  String _lastMessagePreview(BuildContext context, MessageModel? lastMessage) {
    if (lastMessage == null) return '';
    if (lastMessage.type == MessageType.image && lastMessage.body.isEmpty) {
      return AppLocalizations.of(context).translate('chat.preview.photo');
    }
    return lastMessage.body;
  }

  Widget _buildGenericGroupChatCard(
    BuildContext context,
    ChatModel chat,
    AppPalette palette,
    String currentUserId, {
    required bool isPinned,
    required bool isMuted,
  }) {
    final unread = chat.unreadCounts[currentUserId] ?? 0;
    return AppGlassCard(
      padding: const EdgeInsets.all(12),
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
                    Expanded(
                      child: Text(
                        chat.name ??
                            AppLocalizations.of(context)
                                .translate('chat.filters.gym'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMuted) ...[
                          Icon(Icons.notifications_off_rounded,
                              size: 12, color: palette.textTertiary),
                          const SizedBox(width: 4),
                        ],
                        if (isPinned) ...[
                          Icon(Icons.push_pin_rounded,
                              size: 12, color: palette.textTertiary),
                          const SizedBox(width: 4),
                        ],
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
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _lastMessagePreview(context, chat.lastMessage),
                  style: TextStyle(color: palette.textSecondary, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            _buildUnreadBadge(unread),
          ],
        ],
      ),
    );
  }

  /// Brand-gradient unread badge — not a plain colored dot.
  Widget _buildUnreadBadge(int count) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.sunsetB, AppPalette.sunsetC],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
            color: AppPalette.brand.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ),
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
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
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
                      AppLocalizations.of(context).translate('chat.new_group'),
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
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
                  backgroundColor: palette.success,
                  child: const Icon(Icons.chat_bubble_outline,
                      color: Colors.white),
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
    // Resolve energy color from theme
    final energyColor = palette.energy;
    return IgnorePointer(
      child: RepaintBoundary(
        child: Container(
          color: palette.background,
          child: Stack(
            children: [
              // Top-right: brand glow
              Positioned(
                top: -60,
                right: -80,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primary.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
              // Bottom-left: energy glow
              Positioned(
                bottom: size.height * 0.15,
                left: -80,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                  child: Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: energyColor.withValues(alpha: 0.05),
                    ),
                  ),
                ),
              ),
            ],
          ),
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

  // Faz 0 §0.7: removed _buildSupportToast — a fully fabricated card (fake
  // person "Caner", fake gym "MacFit - Peron 3", a "YOLDAYIM" button with no
  // onTap at all) shown unconditionally whenever the chat list was empty.
  // Zero backing data (git blame: rode in on an unrelated localization
  // commit and was never wired up or cleaned up). _buildEmptyStateWithGlow
  // right below it is the real, honest empty state and now stands alone.

  Widget _buildGymChatCard(
    BuildContext context,
    ChatModel chat,
    AppPalette palette,
    String currentUserId, {
    required bool isPinned,
    required bool isMuted,
  }) {
    final unread = chat.unreadCounts[currentUserId] ?? 0;
    return AppGlassCard(
      padding: const EdgeInsets.all(16),
      radius: 24,
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
                      color: palette.success.withValues(alpha: 0.3), width: 2),
                  color: palette.surface,
                ),
                child: ClipOval(
                  child: chat.image != null
                      ? AppImage(
                          imageUrl: chat.image!,
                          width: 56,
                          height: 56,
                        )
                      : Icon(Icons.fitness_center, color: palette.textPrimary),
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
                        chat.name ??
                            AppLocalizations.of(context)
                                .translate('chat.unnamed_user'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMuted) ...[
                          Icon(Icons.notifications_off_rounded,
                              size: 13, color: palette.textTertiary),
                          const SizedBox(width: 4),
                        ],
                        if (isPinned) ...[
                          Icon(Icons.push_pin_rounded,
                              size: 13, color: palette.textTertiary),
                          const SizedBox(width: 4),
                        ],
                        if (chat.lastMessage != null)
                          Text(
                            _formatTime(context, chat.lastMessage!.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textTertiary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                // Faz 0 §0.7: status_text/event_text are never written by
                // any code path today (checked functions/ and lib/) — the
                // old fallbacks ("14 Kişi Antrenmanda" / "Etkinlik Günü:
                // Yoga") rendered on literally every gym chat, unconditional
                // and fake. Only shown now when a real value exists.
                if (chat.metadata?['status_text'] != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text("🔥", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        chat.metadata!['status_text'] as String,
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (chat.metadata?['event_text'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text("🗓️", style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Text(
                        chat.metadata!['event_text'] as String,
                        style: TextStyle(
                          color: palette.textTertiary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            _buildUnreadBadge(unread),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivateChatCard(
    BuildContext context,
    ChatModel chat,
    AppPalette palette,
    String currentUserId, {
    required bool isPinned,
    required bool isMuted,
  }) {
    final unread = chat.unreadCounts[currentUserId] ?? 0;
    // Faz 2 §2.1: read state is per-uid now (message_model.dart's
    // isReadBy) — for this 1:1 card that's "has the other participant read
    // my last message", i.e. the same thing the old single isRead bool
    // approximated for a private chat.
    final otherUserId = chat.participants
        .firstWhere((p) => p != currentUserId, orElse: () => '');
    return AppGlassCard(
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
                    : Icon(Icons.person, color: palette.textTertiary, size: 30),
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
                    Expanded(
                      child: Text(
                        chat.name ??
                            AppLocalizations.of(context)
                                .translate('chat.unnamed_user'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: palette.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isMuted) ...[
                          Icon(Icons.notifications_off_rounded,
                              size: 13, color: palette.textTertiary),
                          const SizedBox(width: 4),
                        ],
                        if (isPinned) ...[
                          Icon(Icons.push_pin_rounded,
                              size: 13, color: palette.textTertiary),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          chat.lastMessage != null
                              ? _formatTime(
                                  context, chat.lastMessage!.timestamp)
                              : '',
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _lastMessagePreview(context, chat.lastMessage),
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
                        chat.lastMessage?.isReadBy(otherUserId) == true
                            ? Icons.done_all
                            : Icons.done,
                        size: 16,
                        color: chat.lastMessage?.isReadBy(otherUserId) == true
                            ? palette.info
                            : palette.textTertiary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 8),
            _buildUnreadBadge(unread),
          ],
        ],
      ),
    );
  }

  // Faz 2 §2.3 audit: the 'recipe'/'nutrition' `metadata['subtype']`
  // branches and the ChatType.system case below were removed here — grepping
  // every writer in lib/ and functions/ confirmed zero code ever produces
  // either subtype value or that enum value, so these branches never fired
  // (dead since whenever they were written). ChatType.gym stays and is now
  // real — see CommunityGroupService.createGroup / AdminService.
  // approveGymApplication.
  Widget _buildChatCard(
    BuildContext context,
    ChatModel chat,
    AppPalette palette,
    String currentUserId, {
    required bool isPinned,
    required bool isMuted,
  }) {
    switch (chat.type) {
      case ChatType.gym:
        return _buildGymChatCard(context, chat, palette, currentUserId,
            isPinned: isPinned, isMuted: isMuted);
      case ChatType.private:
        return _buildPrivateChatCard(context, chat, palette, currentUserId,
            isPinned: isPinned, isMuted: isMuted);
      case ChatType.group:
        return _buildGenericGroupChatCard(context, chat, palette, currentUserId,
            isPinned: isPinned, isMuted: isMuted);
    }
  }

  /// Empty state with a brand-glow halo behind the icon. Faz 2 §2.4:
  /// [unreadOnly] swaps in an honest "no unread chats" message with no
  /// "Find Friends" CTA — that action fixes an empty CONTACT list, not an
  /// active unread filter with nothing to show.
  Widget _buildEmptyStateWithGlow(
      BuildContext context, AppPalette palette, String Function(String) t,
      {bool unreadOnly = false}) {
    final primary = context.read<ThemeProvider>().primaryColor;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Brand glow behind icon
        Positioned(
          top: 0,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.18),
                  primary.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        AppEmptyState(
          icon: Icons.chat_bubble_outline_rounded,
          title: t(unreadOnly ? 'chat.no_unread_chats' : 'chat.no_chats_found'),
          message: '',
          actionLabel: unreadOnly ? null : t('chat.find_friends_cta'),
          onAction: unreadOnly
              ? null
              : () => Navigator.of(context).push(
                    AppTransitions.slideRight(
                      const UserSearchScreen(),
                    ),
                  ),
        ),
      ],
    );
  }
}
