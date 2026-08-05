import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/community_group_service.dart';
import '../../../core/utils/profile_navigation.dart';
import '../../../core/widgets/ds/ds.dart';

/// Faz 5 §5.3 — "grup katkı sıralaması": the UI consumer that makes §5.2's
/// received-engagement credit source (weekly group contribution) visible,
/// so members can see and chase their rank — the plan's own stated
/// mechanism for why this screen exists at all ("grup kullanımı artar").
/// Reads the fully denormalized `weekly_leaderboard/{weekKey}` summary
/// (`CommunityGroupService.getWeeklyContributionLeaderboardStream`) — never
/// the raw, fully server-only `weekly_contributions` counters.
class GroupLeaderboardScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupLeaderboardScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

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
              groupName,
              style: AppText.of(context).titleM.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              l10n.translate('community.groups.leaderboard_subtitle'),
              style: AppText.of(context).labelS.copyWith(
                    color: palette.textSecondary,
                  ),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<GroupContributionEntry>>(
        stream: CommunityGroupService()
            .getWeeklyContributionLeaderboardStream(groupId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: AppSkeletonList(itemCount: 7),
            );
          }
          if (snap.hasError) {
            return AppErrorState(
              title: l10n.translate('community.groups.leaderboard_empty_title'),
              message: snap.error.toString(),
            );
          }

          final entries = snap.data ?? const <GroupContributionEntry>[];
          if (entries.isEmpty) {
            return AppEmptyState(
              icon: Icons.emoji_events_rounded,
              title: l10n.translate('community.groups.leaderboard_empty_title'),
              message: l10n.translate('community.groups.leaderboard_empty_sub'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            physics: const BouncingScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, i) => _GroupLeaderboardRow(
              entry: entries[i],
              isMe: entries[i].uid == currentUid,
            ),
          );
        },
      ),
    );
  }
}

class _GroupLeaderboardRow extends StatelessWidget {
  final GroupContributionEntry entry;
  final bool isMe;

  const _GroupLeaderboardRow({required this.entry, required this.isMe});

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

  Color _rankColor(AppPalette palette) {
    switch (entry.rank) {
      case 1:
        return palette.calories; // gold
      case 2:
        return palette.textSecondary; // silver
      case 3:
        return palette.warning; // bronze
      default:
        return palette.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => openUserProfile(context, userId: entry.uid),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? primary.withValues(alpha: 0.1) : palette.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              isMe ? Border.all(color: primary.withValues(alpha: 0.35)) : null,
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Text(
                _rankEmoji,
                style: TextStyle(
                  fontSize: entry.rank <= 3 ? 22 : 14,
                  fontWeight: FontWeight.bold,
                  color: entry.rank <= 3
                      ? _rankColor(palette)
                      : palette.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              radius: 20,
              backgroundImage: entry.photoURL != null
                  ? CachedNetworkImageProvider(entry.photoURL!)
                  : null,
              backgroundColor: palette.surfaceVariant,
              child: entry.photoURL == null
                  ? Text(
                      (entry.displayName?.isNotEmpty == true
                              ? entry.displayName![0]
                              : '?')
                          .toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                entry.displayName ?? '?',
                style: TextStyle(
                  fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: isMe ? primary : palette.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isMe
                    ? primary.withValues(alpha: 0.1)
                    : palette.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${entry.score} ${l10n.translate('community.groups.leaderboard_score_label')}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isMe ? primary : palette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
