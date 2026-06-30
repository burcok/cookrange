import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_application_model.dart';
import '../../core/widgets/ds/ds.dart';

/// Shown after submitting a coach application (and from CoachDashboardScreen
/// when the application status is [CoachApplicationStatus.pending]).
class CoachApplicationPendingScreen extends StatelessWidget {
  final bool showBackButton;
  final String? reviewerNotes;
  final CoachApplicationStatus status;

  const CoachApplicationPendingScreen({
    super.key,
    this.showBackButton = true,
    this.reviewerNotes,
    this.status = CoachApplicationStatus.pending,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;

    final isRejected = status == CoachApplicationStatus.rejected;
    final isNeedsMoreInfo = status == CoachApplicationStatus.needsMoreInfo;

    final iconColor = isRejected
        ? palette.error
        : isNeedsMoreInfo
            ? palette.warning
            : primary;

    final icon = isRejected
        ? Icons.cancel_rounded
        : isNeedsMoreInfo
            ? Icons.info_rounded
            : Icons.hourglass_top_rounded;

    final titleKey = isRejected
        ? 'coach.app_rejected_title'
        : isNeedsMoreInfo
            ? 'coach.app_more_info_title'
            : 'coach.app_pending_title';

    final bodyKey = isRejected
        ? 'coach.app_rejected_body'
        : isNeedsMoreInfo
            ? 'coach.app_more_info_body'
            : 'coach.app_pending_body';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: showBackButton
          ? AppBar(
              backgroundColor: palette.background,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: palette.textPrimary, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            )
          : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 48),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.translate(titleKey),
                style: t.headlineM.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.translate(bodyKey),
                style:
                    t.bodyL.copyWith(color: palette.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (reviewerNotes != null && reviewerNotes!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? palette.error.withValues(alpha: 0.08)
                        : palette.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isRejected
                          ? palette.error.withValues(alpha: 0.3)
                          : palette.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('coach.app_reviewer_notes'),
                        style: t.labelM.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isRejected ? palette.error : palette.warning,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(reviewerNotes!,
                          style: t.bodyM.copyWith(color: palette.textPrimary)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 40),
              if (!isRejected && !isNeedsMoreInfo) ...[
                // Pending steps
                _InfoRow(
                  icon: Icons.check_circle_outline,
                  color: palette.success,
                  text: l10n.translate('coach.app_pending_step1'),
                  palette: palette,
                  t: t,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  color: primary,
                  text: l10n.translate('coach.app_pending_step2'),
                  palette: palette,
                  t: t,
                ),
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.notifications_outlined,
                  color: primary,
                  text: l10n.translate('coach.app_pending_step3'),
                  palette: palette,
                  t: t,
                ),
              ],
              if (isRejected) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    label: l10n.translate('coach.app_reapply'),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        AppTransitions.slideUp(
                            const CoachApplicationPendingScreen()),
                      );
                    },
                    variant: AppButtonVariant.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final AppPalette palette;
  final AppText t;

  const _InfoRow({
    required this.icon,
    required this.color,
    required this.text,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Text(text, style: t.bodyM.copyWith(color: palette.textSecondary)),
        ),
      ],
    );
  }
}
