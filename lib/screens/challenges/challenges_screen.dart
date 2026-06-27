import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/challenge_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/challenge_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'challenge_detail_screen.dart';
import 'widgets/create_challenge_sheet.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  final ChallengeService _service = ChallengeService();
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

  Future<void> _openCreateSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CreateChallengeSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          l10n.translate('challenge.screen_title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: palette.textPrimary,
          ),
        ),
        backgroundColor: palette.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
          color: palette.textPrimary,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: palette.textSecondary,
          indicatorColor: primary,
          tabs: [
            Tab(text: l10n.translate('challenge.tab_active')),
            Tab(text: l10n.translate('challenge.tab_mine')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ChallengeList(
            stream: _service.getActiveChallengesStream(),
            emptyKey: 'challenge.empty_active',
            primary: primary,
          ),
          _ChallengeList(
            stream: _service.getMyChallengesStream(),
            emptyKey: 'challenge.empty_mine',
            primary: primary,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(l10n.translate('challenge.create_btn')),
      ),
    );
  }
}

class _ChallengeList extends StatelessWidget {
  final Stream<List<ChallengeModel>> stream;
  final String emptyKey;
  final Color primary;

  const _ChallengeList({
    required this.stream,
    required this.emptyKey,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return StreamBuilder<List<ChallengeModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text(l10n.translate('challenge.error_loading')));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final challenges = snapshot.data!;
        if (challenges.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 64,
                      color: palette.border),
                  const SizedBox(height: 16),
                  Text(
                    l10n.translate(emptyKey),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 15),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _ChallengeCard(
            challenge: challenges[i],
            primary: primary,
          ),
        );
      },
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final ChallengeModel challenge;
  final Color primary;

  const _ChallengeCard({
    required this.challenge,
    required this.primary,
  });

  IconData get _icon {
    switch (challenge.type) {
      case ChallengeType.steps:
        return Icons.directions_walk;
      case ChallengeType.calories:
        return Icons.local_fire_department;
      case ChallengeType.workoutDays:
        return Icons.fitness_center;
      case ChallengeType.custom:
        return Icons.emoji_events;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChallengeDetailScreen(challengeId: challenge.id),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, size: 20, color: primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: palette.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.translate('challenge.type.${challenge.type.name}'),
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: challenge.isExpired
                        ? palette.textTertiary.withValues(alpha: 0.15)
                        : palette.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    challenge.isExpired
                        ? l10n.translate('challenge.ended')
                        : l10n.translate('challenge.days_left',
                            variables: {'days': '${challenge.daysRemaining}'}),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: challenge.isExpired ? palette.textTertiary : palette.success,
                    ),
                  ),
                ),
              ],
            ),
            if (challenge.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                challenge.description,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.flag_outlined,
                    size: 14,
                    color: palette.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${challenge.goal} ${challenge.unit}',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.group_outlined,
                    size: 14,
                    color: palette.textTertiary),
                const SizedBox(width: 4),
                Text(
                  '${challenge.participantIds.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
