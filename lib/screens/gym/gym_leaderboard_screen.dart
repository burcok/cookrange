import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_war_model.dart';
import '../../core/models/leaderboard_entry_model.dart';
import '../../core/services/gym_leaderboard_service.dart';
import '../../core/services/gym_service.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/ds/ds.dart';

class GymLeaderboardScreen extends StatefulWidget {
  final String gymId;
  final String gymName;
  final bool isOwner;
  final Color? brandColor;

  const GymLeaderboardScreen({
    super.key,
    required this.gymId,
    required this.gymName,
    this.isOwner = false,
    this.brandColor,
  });

  @override
  State<GymLeaderboardScreen> createState() => _GymLeaderboardScreenState();
}

class _GymLeaderboardScreenState extends State<GymLeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openWarCreation() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WarCreationSheet(
        gymId: widget.gymId,
        gymName: widget.gymName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = widget.brandColor ?? Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.gymName,
              style: AppText.of(context).titleM.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              l10n.translate('gym.leaderboard_title'),
              style: AppText.of(context).labelS.copyWith(
                    color: palette.textSecondary,
                  ),
            ),
          ],
        ),
        actions: [
          if (widget.isOwner)
            IconButton(
              icon: Icon(Icons.add_rounded, color: palette.textSecondary),
              tooltip: l10n.translate('gym.war_start_btn'),
              onPressed: () {
                HapticFeedback.lightImpact();
                _openWarCreation();
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: primary,
          indicatorWeight: 3.0,
          labelStyle: AppText.of(context)
              .bodyM
              .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle:
              AppText.of(context).bodyM.copyWith(fontSize: 13),
          tabs: [
            Tab(text: l10n.translate('gym.leaderboard_tab_leaders')),
            Tab(text: l10n.translate('gym.leaderboard_tab_wars')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeaderboardTab(gymId: widget.gymId),
          _WarsTab(
            gymId: widget.gymId,
            gymName: widget.gymName,
            isOwner: widget.isOwner,
            onStartWar: _openWarCreation,
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard Tab ───────────────────────────────────────────────────────────

class _LeaderboardTab extends StatelessWidget {
  final String gymId;

  const _LeaderboardTab({required this.gymId});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<List<LeaderboardEntryModel>>(
      stream: GymLeaderboardService().getWeeklyLeaderboardStream(gymId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: AppSkeletonList(itemCount: 7),
          );
        }

        final entries = snap.data ?? [];

        if (entries.isEmpty) {
          return AppEmptyState(
            icon: Icons.emoji_events_rounded,
            title: l10n.translate('gym.leaderboard_empty_title'),
            message: l10n.translate('gym.leaderboard_empty_sub'),
          );
        }

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _WeekHeader(palette: palette, l10n: l10n),
            ),
            if (entries.isNotEmpty)
              SliverToBoxAdapter(
                child: _PodiumSection(
                  entries: entries.take(3).toList(),
                  currentUid: currentUid,
                  l10n: l10n,
                ),
              ),
            if (entries.length > 3)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final entry = entries[i + 3];
                    return _LeaderboardTile(
                      entry: entry,
                      isCurrentUser: entry.uid == currentUid,
                    );
                  },
                  childCount: entries.length - 3,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }
}

class _WeekHeader extends StatelessWidget {
  final AppPalette palette;
  final AppLocalizations l10n;

  const _WeekHeader({required this.palette, required this.l10n});

  String _weekLabel() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[monday.month]} ${monday.day} – ${months[sunday.month]} ${sunday.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            l10n.translate('gym.leaderboard_this_week').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: palette.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '· ${_weekLabel()}',
            style: TextStyle(
              fontSize: 11,
              color: palette.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _PodiumSection extends StatefulWidget {
  final List<LeaderboardEntryModel> entries; // up to 3
  final String? currentUid;
  final AppLocalizations l10n;

  const _PodiumSection({
    required this.entries,
    required this.currentUid,
    required this.l10n,
  });

  @override
  State<_PodiumSection> createState() => _PodiumSectionState();
}

class _PodiumSectionState extends State<_PodiumSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fade = CurvedAnimation(parent: _controller, curve: AppMotion.emphasized);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _controller, curve: AppMotion.emphasized));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;

    // Reorder: 2nd, 1st, 3rd for podium visual
    final e = widget.entries;
    final first = e.isNotEmpty ? e[0] : null;
    final second = e.length > 1 ? e[1] : null;
    final third = e.length > 2 ? e[2] : null;

    const goldColor = Color(0xFFFFD700);
    const silverColor = Color(0xFFC0C0C0);
    const bronzeColor = Color(0xFFCD7F32);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: palette.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (second != null)
                _PodiumColumn(
                  entry: second,
                  medalColor: silverColor,
                  barHeight: 60,
                  isCurrentUser: second.uid == widget.currentUid,
                  primary: primary,
                  palette: palette,
                  l10n: widget.l10n,
                )
              else
                const SizedBox(width: 80),
              if (first != null)
                _PodiumColumn(
                  entry: first,
                  medalColor: goldColor,
                  barHeight: 80,
                  isCurrentUser: first.uid == widget.currentUid,
                  primary: primary,
                  palette: palette,
                  l10n: widget.l10n,
                ),
              if (third != null)
                _PodiumColumn(
                  entry: third,
                  medalColor: bronzeColor,
                  barHeight: 44,
                  isCurrentUser: third.uid == widget.currentUid,
                  primary: primary,
                  palette: palette,
                  l10n: widget.l10n,
                )
              else
                const SizedBox(width: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final LeaderboardEntryModel entry;
  final Color medalColor;
  final double barHeight;
  final bool isCurrentUser;
  final Color primary;
  final AppPalette palette;
  final AppLocalizations l10n;

  const _PodiumColumn({
    required this.entry,
    required this.medalColor,
    required this.barHeight,
    required this.isCurrentUser,
    required this.primary,
    required this.palette,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final name = isCurrentUser
        ? l10n.translate('gym.leaderboard_you')
        : (entry.displayName ?? '—');

    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: entry.rank == 1 ? 28 : 22,
                backgroundColor: isCurrentUser
                    ? primary.withValues(alpha: 0.2)
                    : palette.surfaceVariant,
                backgroundImage: entry.photoURL != null
                    ? CachedNetworkImageProvider(entry.photoURL!)
                    : null,
                child: entry.photoURL == null
                    ? Text(
                        (entry.displayName?.isNotEmpty == true
                                ? entry.displayName![0]
                                : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:
                              isCurrentUser ? primary : palette.textSecondary,
                          fontSize: entry.rank == 1 ? 18 : 14,
                        ),
                      )
                    : null,
              ),
              // Medal badge
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.surface, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    '${entry.rank}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppText.of(context).labelS.copyWith(
                  color: isCurrentUser ? primary : palette.textPrimary,
                  fontWeight: isCurrentUser ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 4),
          // Count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${entry.checkInCount}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: medalColor == const Color(0xFFFFD700)
                    ? const Color(0xFFB8860B)
                    : medalColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Bar
          AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.emphasized,
            height: barHeight,
            width: entry.rank == 1 ? 36 : 28,
            decoration: BoxDecoration(
              color: medalColor.withValues(alpha: 0.7),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Leaderboard Tile (rank 4+) ────────────────────────────────────────────────

class _LeaderboardTile extends StatelessWidget {
  final LeaderboardEntryModel entry;
  final bool isCurrentUser;

  const _LeaderboardTile({
    required this.entry,
    required this.isCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => openUserProfile(context, userId: entry.uid),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isCurrentUser ? primary.withValues(alpha: 0.07) : palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isCurrentUser
                ? primary.withValues(alpha: 0.2)
                : palette.border.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 28,
              child: Text(
                '${entry.rank}',
                style: AppText.of(context).bodyM.copyWith(
                      color: palette.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 10),
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: isCurrentUser
                  ? primary.withValues(alpha: 0.15)
                  : palette.surfaceVariant,
              backgroundImage: entry.photoURL != null
                  ? CachedNetworkImageProvider(entry.photoURL!)
                  : null,
              child: entry.photoURL == null
                  ? Text(
                      (entry.displayName?.isNotEmpty == true
                              ? entry.displayName![0]
                              : '?')
                          .toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isCurrentUser ? primary : palette.textSecondary,
                        fontSize: 13,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            // Name
            Expanded(
              child: Text(
                isCurrentUser
                    ? l10n.translate('gym.leaderboard_you')
                    : (entry.displayName ?? '—'),
                style: AppText.of(context).bodyM.copyWith(
                      color: isCurrentUser ? primary : palette.textPrimary,
                      fontWeight:
                          isCurrentUser ? FontWeight.w700 : FontWeight.w500,
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Check-in count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? primary.withValues(alpha: 0.1)
                    : palette.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${entry.checkInCount} ${l10n.translate('gym.leaderboard_checkins_label')}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isCurrentUser ? primary : palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Wars Tab ──────────────────────────────────────────────────────────────────

class _WarsTab extends StatefulWidget {
  final String gymId;
  final String gymName;
  final bool isOwner;
  final VoidCallback onStartWar;

  const _WarsTab({
    required this.gymId,
    required this.gymName,
    required this.isOwner,
    required this.onStartWar,
  });

  @override
  State<_WarsTab> createState() => _WarsTabState();
}

class _WarsTabState extends State<_WarsTab> {
  List<GymWarModel>? _wars;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWars();
  }

  Future<void> _loadWars() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final wars = await GymLeaderboardService().getActiveWars(widget.gymId);
      if (!mounted) return;
      setState(() {
        _wars = wars;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: AppSkeletonList(itemCount: 3),
      );
    }

    if (_error != null) {
      return AppEmptyState(
        icon: Icons.warning_amber_rounded,
        title: l10n.translate('gym.leaderboard.error.load_wars'),
        message: _error,
        actionLabel: 'Retry',
        onAction: _loadWars,
      );
    }

    final wars = _wars ?? [];

    if (wars.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppEmptyState(
                icon: Icons.military_tech_rounded,
                title: l10n.translate('gym.war_no_active_title'),
                message: l10n.translate('gym.war_no_active_sub'),
              ),
              if (widget.isOwner) ...[
                const SizedBox(height: 24),
                AppButton(
                  label: l10n.translate('gym.war_start_btn'),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onStartWar();
                  },
                  icon: Icons.sports_martial_arts_rounded,
                  size: AppButtonSize.medium,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWars,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        physics: const BouncingScrollPhysics(),
        itemCount: wars.length,
        itemBuilder: (context, i) => _WarCard(
          war: wars[i],
          myGymId: widget.gymId,
        ),
      ),
    );
  }
}

// ── War Card ──────────────────────────────────────────────────────────────────

class _WarCard extends StatefulWidget {
  final GymWarModel war;
  final String myGymId;

  const _WarCard({required this.war, required this.myGymId});

  @override
  State<_WarCard> createState() => _WarCardState();
}

class _WarCardState extends State<_WarCard> {
  int? _scoreA;
  int? _scoreB;
  bool _loadingScores = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    try {
      final results = await Future.wait([
        GymLeaderboardService().getWarScore(widget.war, widget.war.gymAId),
        GymLeaderboardService().getWarScore(widget.war, widget.war.gymBId),
      ]);
      if (!mounted) return;
      setState(() {
        _scoreA = results[0];
        _scoreB = results[1];
        _loadingScores = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingScores = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);
    final war = widget.war;

    final total = (_scoreA ?? 0) + (_scoreB ?? 0);
    final ratioA = total == 0 ? 0.5 : (_scoreA ?? 0) / total;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: days remaining / ended
          Row(
            children: [
              Icon(
                Icons.sports_martial_arts_rounded,
                color: primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                war.hasEnded
                    ? l10n.translate('gym.war_ended')
                    : '${war.daysRemaining} ${l10n.translate('gym.war_days_remaining')}',
                style: AppText.of(context).labelS.copyWith(
                      color: war.hasEnded ? palette.textTertiary : primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  war.metric.displayLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Gym names + scores
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      war.gymAName,
                      style: AppText.of(context).bodyM.copyWith(
                            color: widget.myGymId == war.gymAId
                                ? primary
                                : palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loadingScores ? '—' : '${_scoreA ?? 0}',
                      style: AppText.of(context).headlineS.copyWith(
                            color: widget.myGymId == war.gymAId
                                ? primary
                                : palette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: palette.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      war.gymBName,
                      style: AppText.of(context).bodyM.copyWith(
                            color: widget.myGymId == war.gymBId
                                ? primary
                                : palette.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _loadingScores ? '—' : '${_scoreB ?? 0}',
                      style: AppText.of(context).headlineS.copyWith(
                            color: widget.myGymId == war.gymBId
                                ? primary
                                : palette.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          if (!_loadingScores && total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    flex: (ratioA * 100).round().clamp(1, 99),
                    child: Container(height: 6, color: primary),
                  ),
                  Expanded(
                    flex: ((1 - ratioA) * 100).round().clamp(1, 99),
                    child: Container(
                        height: 6,
                        color: palette.border.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

// ── War Creation Sheet ────────────────────────────────────────────────────────

class _WarCreationSheet extends StatefulWidget {
  final String gymId;
  final String gymName;

  const _WarCreationSheet({required this.gymId, required this.gymName});

  @override
  State<_WarCreationSheet> createState() => _WarCreationSheetState();
}

class _WarCreationSheetState extends State<_WarCreationSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<dynamic> _results = []; // List<GymModel>
  bool _searching = false;
  dynamic _selectedGym; // GymModel
  int _durationDays = 7;
  bool _creating = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(query));
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final results = await GymService().searchGyms(query);
      if (!mounted) return;
      setState(() {
        _results = results.where((g) => g.id != widget.gymId).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _startWar() async {
    if (_selectedGym == null) return;
    setState(() => _creating = true);

    try {
      await GymLeaderboardService().createWar(
        gymAId: widget.gymId,
        gymAName: widget.gymName,
        opponentGymId: _selectedGym!.id,
        opponentGymName: _selectedGym!.name,
        durationDays: _durationDays,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.success(
          context, AppLocalizations.of(context).translate('gym.war_created'));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      AppSnackBar.error(context,
          AppLocalizations.of(context).translate('gym.war_create_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.translate('gym.war_create_title'),
                      style: AppText.of(context).titleM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: palette.textSecondary, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Content
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
                    AppTextField(
                      hintText: l10n.translate('gym.war_create_search_hint'),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 12),

                    // Search results / selected gym
                    if (_selectedGym != null) ...[
                      _SelectedGymTile(
                        gym: _selectedGym!,
                        primary: primary,
                        palette: palette,
                        onClear: () => setState(() => _selectedGym = null),
                      ),
                    ] else if (_searching) ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ] else if (_results.isNotEmpty) ...[
                      ..._results.take(5).map(
                            (gym) => _GymSearchTile(
                              gym: gym,
                              primary: primary,
                              palette: palette,
                              onTap: () => setState(() => _selectedGym = gym),
                            ),
                          ),
                    ],

                    const SizedBox(height: 20),

                    // Duration selector
                    Text(
                      l10n.translate('gym.war_create_duration'),
                      style: AppText.of(context).bodyM.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [7, 14, 30].map((days) {
                        final selected = _durationDays == days;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _durationDays = days),
                            child: AnimatedContainer(
                              duration: AppMotion.normal,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    selected ? primary : palette.surfaceVariant,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                                border: Border.all(
                                  color: selected ? primary : palette.border,
                                ),
                              ),
                              child: Text(
                                '$days ${l10n.translate('gym.war_create_days')}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? Colors.white
                                      : palette.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Start War button
                    AppButton(
                      label: l10n.translate('gym.war_create_btn'),
                      onPressed: _selectedGym != null && !_creating
                          ? () {
                              HapticFeedback.mediumImpact();
                              _startWar();
                            }
                          : null,
                      icon: Icons.sports_martial_arts_rounded,
                      loading: _creating,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedGymTile extends StatelessWidget {
  final dynamic gym;
  final Color primary;
  final AppPalette palette;
  final VoidCallback onClear;

  const _SelectedGymTile({
    required this.gym,
    required this.primary,
    required this.palette,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.fitness_center_rounded, color: primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gym.name as String,
                  style: AppText.of(context).bodyM.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if ((gym.city as String?)?.isNotEmpty == true)
                  Text(
                    gym.city as String,
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: primary, size: 18),
            onPressed: onClear,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _GymSearchTile extends StatelessWidget {
  final dynamic gym;
  final Color primary;
  final AppPalette palette;
  final VoidCallback onTap;

  const _GymSearchTile({
    required this.gym,
    required this.primary,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: palette.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  ((gym.name as String).isNotEmpty
                          ? (gym.name as String)[0]
                          : '?')
                      .toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    gym.name as String,
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((gym.city as String?)?.isNotEmpty == true)
                    Text(
                      gym.city as String,
                      style: AppText.of(context).labelS.copyWith(
                            color: palette.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: palette.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
