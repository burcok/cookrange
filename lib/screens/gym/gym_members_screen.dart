import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_member_model.dart';
import '../../core/services/gym_service.dart';
import '../../core/utils/profile_navigation.dart';
import '../../core/widgets/ds/ds.dart';

/// Member management screen — gym owner view.
class GymMembersScreen extends StatefulWidget {
  final String gymId;
  final Color? brandColor;

  const GymMembersScreen({super.key, required this.gymId, this.brandColor});

  @override
  State<GymMembersScreen> createState() => _GymMembersScreenState();
}

class _GymMembersScreenState extends State<GymMembersScreen> {
  final _searchCtrl = TextEditingController();
  StreamSubscription<List<GymMemberModel>>? _sub;
  List<GymMemberModel> _allMembers = [];
  List<GymMemberModel> _filtered = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _sub = GymService().getMembersStream(widget.gymId).listen((members) {
      if (!mounted) return;
      setState(() {
        _allMembers = members;
        _applyFilter();
        _loading = false;
      });
    }, onError: (e) {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filtered = List.from(_allMembers);
      return;
    }
    final lower = _query.toLowerCase();
    _filtered = _allMembers
        .where((m) =>
            (m.displayName?.toLowerCase().contains(lower) ?? false) ||
            m.uid.contains(lower))
        .toList();
  }

  void _onQueryChanged(String v) {
    setState(() {
      _query = v;
      _applyFilter();
    });
  }

  Future<void> _removeMember(GymMemberModel member) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('gym.remove_member_title')),
        content: Text(l10n.translate('gym.remove_member_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.translate('gym.remove_btn'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await GymService().removeMember(widget.gymId, member.uid);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        l10n.translate('gym.remove_member_success'),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        l10n.translate('gym.remove_member_error'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = widget.brandColor ?? Theme.of(context).primaryColor;
    final activeToday = _allMembers.where((m) => m.isActiveToday).length;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('gym.members_title'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_allMembers.length}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats row
          if (!_loading && _allMembers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _StatChip(
                    icon: Icons.people_rounded,
                    label: '${_allMembers.length} total',
                    color: primary,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.check_circle_rounded,
                    label:
                        '$activeToday ${l10n.translate('gym.stat_active_today')}',
                    color: palette.success,
                  ),
                ],
              ),
            ),

          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: AppTextField(
              controller: _searchCtrl,
              hintText: l10n.translate('gym.members_search_hint'),
              prefixIcon: const Icon(Icons.search_rounded),
              onChanged: _onQueryChanged,
            ),
          ),

          // List
          Expanded(
            child: _loading
                ? const AppSkeletonList(itemCount: 8)
                : _filtered.isEmpty
                    ? AppEmptyState(
                        icon: Icons.person_search_rounded,
                        title: l10n.translate('gym.members_empty_title'),
                        message: l10n.translate('gym.members_empty_sub'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) => _MemberTile(
                          member: _filtered[i],
                          onTap: () => openUserProfile(
                            context,
                            userId: _filtered[i].uid,
                          ),
                          onRemove: () => _removeMember(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Member tile ───────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final GymMemberModel member;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _MemberTile({
    required this.member,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(member.uid),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          onRemove();
          return false; // actual removal is handled in onRemove
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: palette.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child:
              Icon(Icons.person_remove_rounded, color: palette.error, size: 22),
        ),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: primary.withValues(alpha: 0.12),
                    backgroundImage: member.photoURL != null
                        ? NetworkImage(member.photoURL!)
                        : null,
                    child: member.photoURL == null
                        ? Text(
                            (member.displayName ?? '?')[0].toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          )
                        : null,
                  ),
                  if (member.isActiveToday)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: palette.success,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: palette.surface, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.displayName ??
                          l10n.translate('gym.member_no_name'),
                      style: AppText.of(context).bodyM.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _joinedLabel(member.joinedAt, l10n),
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Tier badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: member.tier == GymMemberTier.premium
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  member.tier == GymMemberTier.premium ? 'Premium' : 'Standard',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: member.tier == GymMemberTier.premium
                        ? const Color(0xFFF59E0B)
                        : palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _joinedLabel(DateTime joinedAt, AppLocalizations l10n) {
    final days = DateTime.now().difference(joinedAt).inDays;
    if (days == 0) return l10n.translate('gym.joined_today');
    if (days < 30) return '$days d';
    if (days < 365) return '${days ~/ 30} mo';
    return '${days ~/ 365} yr';
  }
}
