import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_invite_code_model.dart';
import '../../core/models/gym_model.dart';
import '../../core/services/referral_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'gym_invite_code_detail_screen.dart';

/// Gym invite-code management (Faz 6 §6.1) — a gym owner's own list of
/// `referrals/{code}` docs with `type: 'gym'`: "front desk QR", "Coach
/// Ahmet's Instagram code", "March campaign" all distinguishable by their
/// campaign/location label and usage count, plus a "+ New code" sheet to
/// mint another one. Redemption itself (deep link → onboarding) is Faz 6
/// §6.3/§6.4, not built here — these codes just need to be valid and
/// generatable today.
class GymInviteCodesScreen extends StatefulWidget {
  final GymModel gym;

  const GymInviteCodesScreen({super.key, required this.gym});

  @override
  State<GymInviteCodesScreen> createState() => _GymInviteCodesScreenState();
}

class _GymInviteCodesScreenState extends State<GymInviteCodesScreen> {
  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateInviteCodeSheet(gym: widget.gym),
    );
  }

  void _openDetail(GymInviteCodeModel invite) {
    Navigator.of(context).push(
      AppTransitions.slideUp(
        GymInviteCodeDetailScreen(gym: widget.gym, invite: invite),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = widget.gym.resolvedBrandColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('gym.invite.title'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateSheet,
        backgroundColor: primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          l10n.translate('gym.invite.create_btn'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          // Faz 6 §6.5 — funnel summary (signups -> premium conversions)
          // across ALL of this gym's codes combined. Individual codes'
          // usedCount below still shows per-campaign signups; these two
          // gym-level counters (gyms/{id}.attributed_member_count/
          // attributed_premium_count, server-maintained — see GymModel's
          // doc comments) add the "how many of them actually went Premium"
          // half of the funnel that no single code's usedCount can show on
          // its own. "Scans" (before a signup) has no honest count here — a
          // poster is scanned by a bare camera app, outside anything this
          // codebase can observe; see docs/GYM_ECOSYSTEM.md for why that
          // stage is deliberately not shown rather than approximated.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                Expanded(
                  child: _FunnelStatCard(
                    value: '${widget.gym.attributedMemberCount}',
                    label: l10n.translate('gym.invite.funnel_signups'),
                    icon: Icons.person_add_alt_1_rounded,
                    color: primary,
                    palette: palette,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FunnelStatCard(
                    value: '${widget.gym.attributedPremiumCount}',
                    label: l10n.translate('gym.invite.funnel_premium'),
                    icon: Icons.workspace_premium_rounded,
                    color: palette.success,
                    palette: palette,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<GymInviteCodeModel>>(
              stream: ReferralService().gymInviteCodesStream(widget.gym.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: AppSkeletonList(itemCount: 4),
                    ),
                  );
                }
                final codes = snapshot.data!;
                if (codes.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: AppEmptyState(
                        icon: Icons.qr_code_2_rounded,
                        title: l10n.translate('gym.invite.empty_title'),
                        message: l10n.translate('gym.invite.empty_message'),
                        actionLabel: l10n.translate('gym.invite.create_btn'),
                        onAction: _openCreateSheet,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: codes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _InviteCodeTile(
                    invite: codes[i],
                    palette: palette,
                    primary: primary,
                    l10n: l10n,
                    onTap: () => _openDetail(codes[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Funnel stat card (Faz 6 §6.5) ────────────────────────────────────────────

class _FunnelStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final AppPalette palette;

  const _FunnelStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: t.titleM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: t.labelS.copyWith(color: palette.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── List tile ────────────────────────────────────────────────────────────────

class _InviteCodeTile extends StatelessWidget {
  final GymInviteCodeModel invite;
  final AppPalette palette;
  final Color primary;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _InviteCodeTile({
    required this.invite,
    required this.palette,
    required this.primary,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.qr_code_rounded, color: primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.displayLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.of(context).bodyM.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.translate('gym.invite.usage_count',
                      variables: {'count': '${invite.usedCount}'}),
                  style: AppText.of(context).labelS.copyWith(
                        color: palette.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          if (invite.isPrinted) ...[
            Icon(Icons.print_rounded, size: 16, color: palette.textTertiary),
            const SizedBox(width: 8),
          ],
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: palette.textSecondary),
        ],
      ),
    );
  }
}

// ── Create sheet ─────────────────────────────────────────────────────────────

class _CreateInviteCodeSheet extends StatefulWidget {
  final GymModel gym;
  const _CreateInviteCodeSheet({required this.gym});

  @override
  State<_CreateInviteCodeSheet> createState() => _CreateInviteCodeSheetState();
}

class _CreateInviteCodeSheetState extends State<_CreateInviteCodeSheet> {
  final _campaignCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _campaignCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    try {
      final code = await ReferralService().createGymInviteCode(
        gymId: widget.gym.id,
        campaign: _campaignCtrl.text,
        locationNote: _locationCtrl.text,
      );
      if (!mounted) return;

      // Constructed locally rather than re-read from Firestore — every field
      // is already known client-side right after a successful create (R1: no
      // extra round-trip just to display what we just wrote).
      final uid = FirebaseAuth.instance.currentUser?.uid ?? widget.gym.ownerUid;
      final campaign = _campaignCtrl.text.trim();
      final locationNote = _locationCtrl.text.trim();
      final invite = GymInviteCodeModel(
        code: code,
        gymId: widget.gym.id,
        ownerUid: uid,
        campaign: campaign.isEmpty ? null : campaign,
        locationNote: locationNote.isEmpty ? null : locationNote,
        createdAt: DateTime.now(),
        maxUses: ReferralService.gymDefaultMaxUses,
        usedCount: 0,
      );

      Navigator.of(context).pop();
      // Fire-and-forget: this screen doesn't care when the detail screen is
      // later popped, so the push's Future is intentionally not awaited.
      unawaited(
        Navigator.of(context).push(
          AppTransitions.slideUp(
            GymInviteCodeDetailScreen(gym: widget.gym, invite: invite),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      AppSnackBar.error(
        context,
        AppLocalizations.of(context).translate('gym.invite.create_error'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
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
                      l10n.translate('gym.invite.create_sheet_title'),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppTextField(
                    controller: _campaignCtrl,
                    labelText: l10n.translate('gym.invite.field_campaign'),
                    hintText: l10n.translate('gym.invite.field_campaign_hint'),
                    prefixIcon: const Icon(Icons.campaign_rounded),
                    maxLength: 80,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    controller: _locationCtrl,
                    labelText: l10n.translate('gym.invite.field_location_note'),
                    hintText:
                        l10n.translate('gym.invite.field_location_note_hint'),
                    prefixIcon: const Icon(Icons.place_rounded),
                    maxLength: 200,
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: l10n.translate('gym.invite.create_submit'),
                    onPressed: _creating ? null : _create,
                    loading: _creating,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
