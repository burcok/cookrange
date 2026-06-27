import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/challenge_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/challenge_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/sharing_service.dart';
import '../../core/widgets/ds/ds.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  final ChallengeService _service = ChallengeService();
  final FirestoreService _firestoreService = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isJoining = false;

  Future<void> _joinOrLeave(ChallengeModel challenge) async {
    setState(() => _isJoining = true);
    try {
      final isParticipant = challenge.participantIds.contains(_uid);
      if (isParticipant) {
        await _service.leaveChallenge(challenge.id);
      } else {
        await _service.joinChallenge(challenge.id);
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _showUpdateProgressSheet(ChallengeModel challenge) async {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final ctrl = TextEditingController(
      text: '${challenge.progressOf(_uid)}',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('challenge.update_progress'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.translate('challenge.progress_hint'),
                  hintStyle: TextStyle(color: palette.textTertiary),
                  suffixText: challenge.unit,
                  filled: true,
                  fillColor: palette.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final val = int.tryParse(ctrl.text) ?? 0;
                    await _service.updateProgress(challenge.id, val);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Text(l10n.translate('challenge.save_progress')),
                ),
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      body: StreamBuilder<ChallengeModel>(
        stream: _service.getChallengeStream(widget.challengeId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text(l10n.translate('challenge.error_loading')));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final challenge = snapshot.data!;
          final isParticipant = challenge.participantIds.contains(_uid);
          final myProgress = challenge.progressOf(_uid);
          final progressPct = challenge.progressPercent(_uid);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: palette.surface,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                actions: [
                  Builder(
                    builder: (buttonContext) => IconButton(
                      icon: Icon(Icons.share_outlined,
                          color: palette.textSecondary, size: 20),
                      onPressed: () {
                        final box = buttonContext.findRenderObject() as RenderBox?;
                        final rect = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
                        SharingService().shareChallenge(
                          buttonContext,
                          name: challenge.title,
                          challengeId: challenge.id,
                          goal: '${challenge.goal} ${challenge.unit}',
                          sharePositionOrigin: rect,
                        );
                      },
                      tooltip: 'Share Challenge',
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    challenge.title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          primary.withValues(alpha: 0.8),
                          primary.withValues(alpha: 0.4),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _typeIcon(challenge.type),
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status chips
                      Row(
                        children: [
                          _chip(
                            icon: _typeIcon(challenge.type),
                            label: l10n.translate(
                                'challenge.type.${challenge.type.name}'),
                            color: primary,
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            icon: challenge.isExpired
                                ? Icons.check_circle
                                : Icons.timer,
                            label: challenge.isExpired
                                ? l10n.translate('challenge.ended')
                                : l10n.translate('challenge.days_left',
                                    variables: {
                                      'days': '${challenge.daysRemaining}'
                                    }),
                            color: challenge.isExpired
                                ? palette.textTertiary
                                : palette.success,
                          ),
                          const SizedBox(width: 8),
                          _chip(
                            icon: Icons.group,
                            label: '${challenge.participantIds.length}',
                            color: palette.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Description
                      if (challenge.description.isNotEmpty) ...[
                        Text(
                          challenge.description,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // My progress (if participant)
                      if (isParticipant) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('challenge.my_progress'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: palette.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progressPct,
                                        backgroundColor: palette.border,
                                        valueColor:
                                            AlwaysStoppedAnimation(primary),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$myProgress / ${challenge.goal} ${challenge.unit}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (!challenge.isExpired) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () =>
                                        _showUpdateProgressSheet(challenge),
                                    icon: const Icon(Icons.edit, size: 16),
                                    label: Text(
                                        l10n.translate('challenge.update_progress')),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primary,
                                      side: BorderSide(color: primary),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Participants leaderboard
                      Text(
                        l10n.translate('challenge.leaderboard'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...challenge.participantIds
                          .map((uid) => _ParticipantRow(
                                uid: uid,
                                challenge: challenge,
                                isMe: uid == _uid,
                                primary: primary,
                                firestoreService: _firestoreService,
                              ))
                          ,
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: StreamBuilder<ChallengeModel>(
        stream: _service.getChallengeStream(widget.challengeId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          final challenge = snapshot.data!;
          if (challenge.isExpired) return const SizedBox.shrink();

          final isParticipant = challenge.participantIds.contains(_uid);
          final isCreator = challenge.createdBy == _uid;

          if (isCreator && !isParticipant) return const SizedBox.shrink();

          final palette = AppPalette.of(context);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: ElevatedButton.icon(
                onPressed:
                    _isJoining ? null : () => _joinOrLeave(challenge),
                icon: Icon(isParticipant ? Icons.exit_to_app : Icons.add,
                    size: 18),
                label: Text(
                  isParticipant
                      ? l10n.translate('challenge.leave')
                      : l10n.translate('challenge.join'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isParticipant
                      ? palette.surfaceVariant
                      : primary,
                  foregroundColor: isParticipant
                      ? palette.textSecondary
                      : Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _chip({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  IconData _typeIcon(ChallengeType type) {
    switch (type) {
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
}

class _ParticipantRow extends StatelessWidget {
  final String uid;
  final ChallengeModel challenge;
  final bool isMe;
  final Color primary;
  final FirestoreService firestoreService;

  const _ParticipantRow({
    required this.uid,
    required this.challenge,
    required this.isMe,
    required this.primary,
    required this.firestoreService,
  });

  @override
  Widget build(BuildContext context) {
    final progress = challenge.progressOf(uid);
    final pct = challenge.progressPercent(uid);
    final palette = AppPalette.of(context);

    return FutureBuilder(
      future: firestoreService.getUserData(uid),
      builder: (context, snapshot) {
        final name = snapshot.data?.displayName ?? '...';
        final photo = snapshot.data?.photoURL;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe
                ? primary.withValues(alpha: 0.08)
                : palette.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
            border: isMe
                ? Border.all(color: primary.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style:
                            const TextStyle(fontWeight: FontWeight.bold))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: palette.border,
                        valueColor: AlwaysStoppedAnimation(
                            isMe ? primary : palette.energy),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isMe ? primary : palette.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
