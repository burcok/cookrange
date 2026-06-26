import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/leaderboard_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  final LeaderboardService _service = LeaderboardService();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  late TabController _tabController;
  List<LeaderboardEntry>? _friendsEntries;
  bool _friendsLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _friendsEntries == null) {
      _loadFriends();
    }
  }

  Future<void> _loadFriends() async {
    setState(() => _friendsLoading = true);
    final entries = await _service.getFriendsLeaderboard();
    if (mounted) {
      setState(() {
        _friendsEntries = entries;
        _friendsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = context.read<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D1117) : const Color(0xFFFCFBF9),
      appBar: AppBar(
        title: Text(
          l10n.translate('leaderboard.screen_title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        backgroundColor:
            isDark ? const Color(0xFF111827) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
          indicatorColor: primary,
          tabs: [
            Tab(text: l10n.translate('leaderboard.tab_global')),
            Tab(text: l10n.translate('leaderboard.tab_friends')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Global tab — stream
          StreamBuilder<List<LeaderboardEntry>>(
            stream: _service.getGlobalLeaderboardStream(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                    child: Text(l10n.translate('leaderboard.error')));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return _buildList(snap.data!, isDark, primary, l10n);
            },
          ),

          // Friends tab — future-based
          _friendsLoading
              ? const Center(child: CircularProgressIndicator())
              : (_friendsEntries == null
                  ? Center(
                      child: Text(l10n.translate('leaderboard.tab_friends')))
                  : _buildList(
                      _friendsEntries!, isDark, primary, l10n,
                      emptyKey: 'leaderboard.empty_friends')),
        ],
      ),
    );
  }

  Widget _buildList(
    List<LeaderboardEntry> entries,
    bool isDark,
    Color primary,
    AppLocalizations l10n, {
    String? emptyKey,
  }) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.leaderboard_outlined,
                  size: 64,
                  color: isDark ? Colors.white24 : Colors.black12),
              const SizedBox(height: 16),
              Text(
                l10n.translate(emptyKey ?? 'leaderboard.empty'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                    fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final entry = entries[i];
        final isMe = entry.uid == _uid;
        return _LeaderboardRow(
          entry: entry,
          isMe: isMe,
          primary: primary,
          isDark: isDark,
        );
      },
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final Color primary;
  final bool isDark;

  const _LeaderboardRow({
    required this.entry,
    required this.isMe,
    required this.primary,
    required this.isDark,
  });

  String get _rankEmoji {
    switch (entry.rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#${entry.rank}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isMe
            ? primary.withValues(alpha: 0.1)
            : (isDark
                ? const Color(0xFF1F2937)
                : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: isMe
            ? Border.all(color: primary.withValues(alpha: 0.35))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 40,
            child: Text(
              _rankEmoji,
              style: TextStyle(
                fontSize: entry.rank <= 3 ? 22 : 14,
                fontWeight: FontWeight.bold,
                color: entry.rank <= 3
                    ? null
                    : (isDark ? Colors.white54 : Colors.black45),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: entry.photoURL != null
                ? NetworkImage(entry.photoURL!)
                : null,
            backgroundColor:
                isDark ? Colors.white12 : Colors.grey.shade200,
            child: entry.photoURL == null
                ? Text(
                    entry.displayName.isNotEmpty
                        ? entry.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 12),

          // Name
          Expanded(
            child: Text(
              entry.displayName,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
                color: isMe
                    ? primary
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Streak
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              Text(
                '${entry.streak}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isMe
                      ? primary
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
