import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'ds/ds.dart';

class SponsorBadge extends StatelessWidget {
  final String sponsorName;
  final String? sponsorLogoUrl;

  const SponsorBadge({
    super.key,
    required this.sponsorName,
    this.sponsorLogoUrl,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.warning.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sponsorLogoUrl != null && sponsorLogoUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: Image.network(
                sponsorLogoUrl!,
                width: 14.r,
                height: 14.r,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.star_rounded,
                  size: 12.r,
                  color: palette.warning,
                ),
              ),
            ),
            SizedBox(width: 4.w),
          ] else ...[
            Icon(Icons.star_rounded, size: 12.r, color: palette.warning),
            SizedBox(width: 4.w),
          ],
          Text(
            'Sponsored by $sponsorName',
            style: t.overline.copyWith(
              color: palette.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
