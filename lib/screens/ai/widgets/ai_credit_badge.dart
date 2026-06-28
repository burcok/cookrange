import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/models/ai_credit_model.dart';
import '../../../core/services/ai_credit_service.dart';
import '../../../core/widgets/ds/ds.dart';

/// Compact pill that shows the user's remaining AI credits.
///
/// - Premium: lock-free ∞ badge in primary color.
/// - Free > 5 remaining: bolt icon, info color.
/// - Free 1–5 remaining: warning icon, warning color.
/// - Free 0 remaining: block icon, error color.
///
/// Wrap in a [RepaintBoundary] (already applied internally) so this
/// stream-driven widget never triggers parent repaints.
class AiCreditBadge extends StatelessWidget {
  final String uid;
  final bool isPremium;

  const AiCreditBadge({
    super.key,
    required this.uid,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: isPremium ? _UnlimitedBadge() : _FreeBadge(uid: uid),
    );
  }
}

// ─── Premium variant ─────────────────────────────────────────────────────────

class _UnlimitedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final textTheme = AppText.of(context);
    final color = palette.info;

    return _Pill(
      color: color,
      icon: Icons.all_inclusive_rounded,
      label: 'Unlimited',
      textTheme: textTheme,
    );
  }
}

// ─── Free variant (stream-driven) ────────────────────────────────────────────

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
          return AppSkeletonBox(width: 80.w, height: 24.h);
        }

        final credits = snapshot.data!;
        final remaining = credits.remaining;

        final (Color color, IconData icon, String label) = switch (remaining) {
          0 => (palette.error, Icons.block_rounded, 'Limit reached'),
          <= 5 => (palette.warning, Icons.warning_amber_rounded,
              '$remaining left'),
          _ => (palette.info, Icons.bolt_rounded, '$remaining AI calls left'),
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
