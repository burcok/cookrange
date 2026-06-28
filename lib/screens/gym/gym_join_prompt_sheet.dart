import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/gym_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Shown when a non-member scans a gym's check-in QR code via deep link.
/// Lets the user join the gym and immediately records the QR check-in.
class GymJoinPromptSheet extends StatefulWidget {
  final String gymId;
  final String gymName;
  final String uid;
  final String qrToken;

  const GymJoinPromptSheet({
    super.key,
    required this.gymId,
    required this.gymName,
    required this.uid,
    required this.qrToken,
  });

  static Future<void> show(
    BuildContext context, {
    required String gymId,
    required String gymName,
    required String uid,
    required String qrToken,
  }) {
    final l10n = AppLocalizations.of(context);
    return AppSheet.show<void>(
      context: context,
      title: l10n
          .translate('gym.join_prompt_title')
          .replaceAll('{gym}', gymName),
      child: GymJoinPromptSheet(
        gymId: gymId,
        gymName: gymName,
        uid: uid,
        qrToken: qrToken,
      ),
    );
  }

  @override
  State<GymJoinPromptSheet> createState() => _GymJoinPromptSheetState();
}

class _GymJoinPromptSheetState extends State<GymJoinPromptSheet> {
  bool _loading = false;

  Future<void> _joinAndCheckIn() async {
    setState(() => _loading = true);
    final l10n = AppLocalizations.of(context);
    try {
      await GymService().joinGym(widget.gymId);
      await GymService().validateQRCheckIn(widget.gymId, widget.qrToken);

      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackBar.success(
        context,
        l10n
            .translate('gym.join_success')
            .replaceAll('{gym}', widget.gymName),
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 64.w,
            height: 64.w,
            decoration: BoxDecoration(
              color: palette.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.fitness_center_rounded,
              color: palette.success,
              size: 32.r,
            ),
          ),
        ),
        SizedBox(height: AppSpacing.md.h),
        Text(
          l10n.translate('gym.join_prompt_body'),
          textAlign: TextAlign.center,
          style: t.bodyM.copyWith(
            color: palette.textSecondary,
            height: 1.5,
          ),
        ),
        SizedBox(height: AppSpacing.xl.h),
        AppButton(
          label: l10n.translate('gym.join_prompt_cta'),
          onPressed: _loading ? null : _joinAndCheckIn,
          loading: _loading,
          icon: Icons.qr_code_scanner_rounded,
        ),
        SizedBox(height: AppSpacing.sm.h),
        AppButton(
          label: l10n.translate('common.cancel'),
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          variant: AppButtonVariant.ghost,
        ),
      ],
    );
  }
}
