import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/consent_model.dart';
import '../../core/services/consent_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../legal/legal_screen.dart';

/// Faz 1 §1.3 — the non-skippable, explicit opt-in screen for background
/// gym-presence detection (`ConsentPurpose.gymPresence`). Distinct from a
/// bare Consent Center toggle: this is a special-category purpose (location
/// + implicit fitness-attendance context), so it gets its own full
/// explanation before any consent is recorded, covering — in order — what
/// it does, what's stored, what's never stored, who can see it, the legal
/// basis, and how to turn it off. Returns `true` if the user granted
/// consent (and it has already been persisted via [ConsentService]),
/// `false` otherwise (declined or backed out — nothing is recorded).
///
/// Callers (gym detail "enable auto check-in" toggle, Consent Center, the
/// future Faz 1.2 background-geofence bootstrap) should call
/// [GymPresenceConsentScreen.request] rather than pushing this route
/// directly — it short-circuits if consent is already granted and current.
class GymPresenceConsentScreen extends StatelessWidget {
  const GymPresenceConsentScreen({super.key});

  /// Ensures the user has current, granted consent for gym presence
  /// detection, showing this screen only if needed. Returns true iff
  /// consent is granted by the end of the call (already-granted counts).
  static Future<bool> request(BuildContext context) async {
    final already =
        await ConsentService().hasConsent(ConsentPurpose.gymPresence);
    if (already) return true;
    if (!context.mounted) return false;
    final granted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GymPresenceConsentScreen()),
    );
    return granted ?? false;
  }

  Future<void> _decide(BuildContext context, bool grant) async {
    unawaited(HapticFeedback.selectionClick());
    await ConsentService().setConsent(ConsentPurpose.gymPresence, grant);
    if (context.mounted) Navigator.of(context).pop(grant);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // Backing out (system back / swipe) is a decline, not a no-op —
        // this screen must never leave the purpose in limbo.
        if (!didPop) Navigator.of(context).pop(false);
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 24.h),
                  children: [
                    Container(
                      width: 64.r,
                      height: 64.r,
                      decoration: BoxDecoration(
                        color: palette.info.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.location_on_rounded,
                          color: palette.info, size: 30.sp),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      l10n.translate('gym_presence_consent.title'),
                      style: t.headlineS.copyWith(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      l10n.translate('gym_presence_consent.intro'),
                      style: t.bodyM
                          .copyWith(color: palette.textSecondary, height: 1.5),
                    ),
                    SizedBox(height: 24.h),
                    _Point(
                      icon: Icons.check_circle_outline_rounded,
                      color: palette.success,
                      title: l10n.translate('gym_presence_consent.what_title'),
                      body: l10n.translate('gym_presence_consent.what_body'),
                    ),
                    _Point(
                      icon: Icons.save_outlined,
                      color: palette.info,
                      title:
                          l10n.translate('gym_presence_consent.stored_title'),
                      body: l10n.translate('gym_presence_consent.stored_body'),
                    ),
                    _Point(
                      icon: Icons.block_outlined,
                      color: palette.error,
                      title: l10n
                          .translate('gym_presence_consent.not_stored_title'),
                      body: l10n
                          .translate('gym_presence_consent.not_stored_body'),
                    ),
                    _Point(
                      icon: Icons.visibility_outlined,
                      color: palette.warning,
                      title: l10n.translate('gym_presence_consent.who_title'),
                      body: l10n.translate('gym_presence_consent.who_body'),
                    ),
                    _Point(
                      icon: Icons.gavel_rounded,
                      color: palette.textSecondary,
                      title: l10n.translate('gym_presence_consent.legal_title'),
                      body: l10n.translate('gym_presence_consent.legal_body'),
                    ),
                    _Point(
                      icon: Icons.toggle_off_outlined,
                      color: palette.textSecondary,
                      title:
                          l10n.translate('gym_presence_consent.revoke_title'),
                      body: l10n.translate('gym_presence_consent.revoke_body'),
                      isLast: true,
                    ),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LegalScreen(
                              type: LegalDocumentType.kvkkClarification),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 16.sp, color: palette.info),
                          SizedBox(width: 6.w),
                          Text(
                            l10n.translate('gym_presence_consent.read_kvkk'),
                            style: t.labelM.copyWith(
                                color: palette.info,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 12.h),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: l10n.translate('gym_presence_consent.allow'),
                        onPressed: () => _decide(context, true),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        label: l10n.translate('gym_presence_consent.decline'),
                        variant: AppButtonVariant.ghost,
                        onPressed: () => _decide(context, false),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool isLast;

  const _Point({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 18.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.r,
            height: 32.r,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: t.titleM.copyWith(fontWeight: FontWeight.w700)),
                SizedBox(height: 4.h),
                Text(
                  body,
                  style: t.bodyM
                      .copyWith(color: palette.textSecondary, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
