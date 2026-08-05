import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_invite_code_model.dart';
import '../../core/models/gym_model.dart';
import '../../core/widgets/gym_invite_poster_card.dart';
import '../../core/widgets/ds/ds.dart';

/// A single gym invite code (Faz 6 §6.1): QR for in-app viewing/scanning +
/// the raw code (copyable, manual-entry fallback) + printable poster export.
///
/// The QR here is themed (brand color, like `GymQrScreen`'s check-in QR) —
/// it's fine on-screen contrast. The EXPORTED poster is deliberately
/// black-on-white regardless of theme (see `GymInvitePosterCard`'s doc
/// comment) since that one gets printed and re-scanned off paper.
class GymInviteCodeDetailScreen extends StatefulWidget {
  final GymModel gym;
  final GymInviteCodeModel invite;

  const GymInviteCodeDetailScreen({
    super.key,
    required this.gym,
    required this.invite,
  });

  @override
  State<GymInviteCodeDetailScreen> createState() =>
      _GymInviteCodeDetailScreenState();
}

class _GymInviteCodeDetailScreenState extends State<GymInviteCodeDetailScreen> {
  bool _exporting = false;

  Future<void> _exportPoster() async {
    setState(() => _exporting = true);
    try {
      await GymInvitePosterCard.share(context,
          gym: widget.gym, invite: widget.invite);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: widget.invite.inviteUrl));
    if (!mounted) return;
    AppSnackBar.success(
      context,
      AppLocalizations.of(context).translate('gym.invite.link_copied'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = widget.gym.resolvedBrandColor;
    final l10n = AppLocalizations.of(context);
    final invite = widget.invite;

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
          l10n.translate('gym.invite.detail_title'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          children: [
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  if (invite.campaign != null ||
                      invite.locationNote != null) ...[
                    Text(
                      invite.displayLabel(),
                      textAlign: TextAlign.center,
                      style: AppText.of(context).bodyM.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: invite.inviteUrl,
                      size: 220,
                      eyeStyle: QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: primary,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _copyLink,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            invite.code,
                            style: AppText.of(context).titleL.copyWith(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_rounded,
                              size: 18, color: palette.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.translate('gym.invite.usage_count',
                        variables: {'count': '${invite.usedCount}'}),
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppButton(
              label: l10n.translate('gym.invite.poster_export_btn'),
              onPressed: _exporting ? null : _exportPoster,
              loading: _exporting,
              icon: Icons.ios_share_rounded,
            ),
            const SizedBox(height: 16),
            _InstructionCard(l10n: l10n, palette: palette),
          ],
        ),
      ),
    );
  }
}

class _InstructionCard extends StatelessWidget {
  final AppLocalizations l10n;
  final AppPalette palette;
  const _InstructionCard({required this.l10n, required this.palette});

  @override
  Widget build(BuildContext context) {
    final steps = [
      l10n.translate('gym.invite.step1'),
      l10n.translate('gym.invite.step2'),
      l10n.translate('gym.invite.step3'),
    ];
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.info.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.info,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    steps[i],
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textSecondary,
                          height: 1.3,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
