import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/ai_credit_model.dart';
import '../../../core/services/ai_credit_service.dart';
import '../../../core/widgets/ds/ds.dart';
import 'ai_credits_sheet.dart';

/// Compact pill that shows the user's remaining daily AI credits.
/// Tapping it opens [AiCreditsSheet] with usage details + upgrade CTA.
///
/// Wrap in a [RepaintBoundary] (applied internally) so this stream-driven
/// widget never triggers parent repaints.
class AiCreditBadge extends StatelessWidget {
  final String uid;
  final bool isPremium;

  const AiCreditBadge({
    super.key,
    required this.uid,
    required this.isPremium,
  });

  void _onTap(BuildContext context) {
    AiCreditsSheet.show(context, uid: uid, isPremium: isPremium);
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => _onTap(context),
        behavior: HitTestBehavior.opaque,
        child: isPremium
            ? _UnlimitedBadge(uid: uid, isPremium: isPremium)
            : _FreeBadge(uid: uid),
      ),
    );
  }
}

// ─── Premium variant ──────────────────────────────────────────────────────────

class _UnlimitedBadge extends StatelessWidget {
  final String uid;
  final bool isPremium;
  const _UnlimitedBadge({required this.uid, required this.isPremium});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);

    return StreamBuilder<AiCreditModel>(
      stream: AiCreditService().getCreditsStream(uid, isPremium: isPremium),
      builder: (context, snapshot) {
        final credits = snapshot.data;
        final remaining = credits?.remaining ?? AiCreditModel.premiumDailyLimit;

        return _Pill(
          color: palette.success,
          icon: Icons.workspace_premium_rounded,
          label: '$remaining',
          textTheme: textTheme,
        );
      },
    );
  }
}

// ─── Free variant (stream-driven) ─────────────────────────────────────────────

class _FreeBadge extends StatelessWidget {
  final String uid;
  const _FreeBadge({required this.uid});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);

    return StreamBuilder<AiCreditModel>(
      stream: AiCreditService().getCreditsStream(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return AppSkeletonBox(width: 70.w, height: 24.h);
        }

        final credits = snapshot.data!;
        final remaining = credits.remaining;

        final (Color color, IconData icon, String label) = switch (remaining) {
          0 => (palette.error, Icons.block_rounded, '0'),
          1 => (palette.warning, Icons.warning_amber_rounded, '1'),
          _ => (palette.info, Icons.bolt_rounded, '$remaining'),
        };

        return _Pill(
          color: color,
          icon: icon,
          label: label,
          textTheme: textTheme,
        );
      },
    );
  }
}

// ─── Shared pill shell ────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final AppText textTheme;

  const _Pill({
    required this.color,
    required this.icon,
    required this.label,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13.r),
          SizedBox(width: 3.w),
          Text(
            label,
            style: textTheme.labelS.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
