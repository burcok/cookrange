import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/services/referral_service.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';
import '../widgets/onboarding_widgets.dart';

/// Page 14 — referral code (Faz 6 §6.3/§6.4). Never a hard blocker: "Continue"
/// is always enabled, empty is a valid answer, and any verification failure
/// just falls back to that same empty/skippable state.
///
/// Two ways a code gets here:
///  - Deep link (`DeepLinkService._handleInvite`): already sitting in
///    [OnboardingProvider.referralCode] by the time this page mounts, or
///    recoverable from [ReferralService.loadPendingCode] if the app was
///    killed and onboarding restarted since (Faz 6 §6.3's on-device, 7-day-TTL
///    persistence — in-memory provider state does not survive a kill).
///  - Typed, or pasted via the explicit clipboard offer (K7 — never read
///    silently; iOS itself surfaces a system paste notice when we do).
///
/// Either way, [ReferralService.previewCode] (no auth required) is what
/// decides "verified, {gym}" vs. a soft, non-blocking "couldn't verify" —
/// actual redemption only ever happens post-signup, via `applyReferral` at
/// `OnboardingCompletion.finalizeAndRoute`.
class OnboardingReferralPage extends StatefulWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingReferralPage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingReferralPage> createState() => _OnboardingReferralPageState();
}

class _OnboardingReferralPageState extends State<OnboardingReferralPage> {
  late final TextEditingController _controller;
  Timer? _debounce;

  bool _checking = false;
  String? _error;

  /// Set only while [_verifiedNote] describes the code CURRENTLY in
  /// [_controller] — cleared the instant the text changes so a stale
  /// verified badge can never sit next to edited text.
  String? _verifiedNote;

  @override
  void initState() {
    super.initState();
    final ob = context.read<OnboardingProvider>();
    _controller = TextEditingController(text: ob.referralCode ?? '');

    if (ob.referralCode != null) {
      final code = ob.referralCode!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _validate(code);
      });
    } else {
      // Fresh OnboardingProvider (e.g. the app was killed mid-onboarding and
      // the flow restarted) — fall back to the on-device pending code.
      unawaited(_hydrateFromPendingStore());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _hydrateFromPendingStore() async {
    final code = await ReferralService().loadPendingCode();
    // Also bail if the user already started typing their own code while this
    // (SharedPreferences) read was in flight — never clobber live input.
    if (code == null || !mounted || _controller.text.isNotEmpty) return;
    context.read<OnboardingProvider>().setReferralCode(code);
    setState(() => _controller.text = code);
    await _validate(code);
  }

  void _onChanged(String raw) {
    setState(() => _verifiedNote = null);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final code = raw.trim().toUpperCase();
      if (code.isEmpty) {
        setState(() {
          _checking = false;
          _error = null;
        });
        return;
      }
      _validate(code);
    });
  }

  Future<void> _validate(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.length < 4) {
      if (mounted) setState(() => _error = null);
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
    });

    final preview = await ReferralService().previewCode(code);
    if (!mounted) return;
    // The field may have changed while this was in flight — a stale result
    // must never paint over what the user is looking at now.
    if (_controller.text.trim().toUpperCase() != code) return;

    final l10n = AppLocalizations.of(context);
    setState(() {
      _checking = false;
      if (preview == null || !preview.valid) {
        _error = l10n.translate('onboarding.v2.referral.invalid_note');
        _verifiedNote = null;
      } else {
        _error = null;
        _verifiedNote = (preview.type == 'gym' &&
                preview.gymName != null &&
                preview.gymName!.isNotEmpty)
            ? l10n.translate('onboarding.v2.referral.verified_gym',
                variables: {'gym': preview.gymName!})
            : l10n.translate('onboarding.v2.referral.verified_generic');
      }
    });
  }

  Future<void> _pasteFromClipboard() async {
    unawaited(HapticFeedback.selectionClick());
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim() ?? '';
    if (!mounted) return;

    if (pasted.isEmpty) {
      AppSnackBar.info(
        context,
        AppLocalizations.of(context)
            .translate('onboarding.v2.referral.paste_empty'),
      );
      return;
    }

    final code = _extractCode(pasted);
    _debounce?.cancel();
    setState(() {
      _controller.text = code;
      _controller.selection = TextSelection.collapsed(offset: code.length);
      _verifiedNote = null;
    });
    await _validate(code);
  }

  /// A pasted value may be the bare code ("AB3X9K") or the full shared link
  /// ("https://cookrangeapp.com/invite/AB3X9K") — `GymInviteCodeDetailScreen._copyLink`
  /// (Faz 6 §6.1, this same app) copies the FULL `inviteUrl` to the
  /// clipboard, not the bare code, and a code forwarded via chat could carry
  /// either form. Falls back to the trimmed input itself when it isn't a URL.
  String _extractCode(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last.trim().toUpperCase();
    }
    return raw.toUpperCase();
  }

  void _submit() {
    final code = _controller.text.trim();
    context
        .read<OnboardingProvider>()
        .setReferralCode(code.isEmpty ? null : code);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return OnboardingScaffold(
      progress: (widget.step + 1) / widget.totalSteps,
      onBack: widget.onBack,
      onContinue: _submit,
      continueLabel: l10n.translate('onboarding.continue'),
      child: ListView(
        padding: EdgeInsets.only(top: AppSpacing.lg.h, bottom: AppSpacing.xl.h),
        children: [
          OnboardingSectionLabel(
            title: l10n.translate('onboarding.v2.referral.title'),
            subtitle: l10n.translate('onboarding.v2.referral.subtitle'),
          ),
          SizedBox(height: AppSpacing.xl.h),
          AppCard(
            bordered: true,
            elevated: false,
            padding: EdgeInsets.all(AppSpacing.md.r),
            child: AppTextField(
              controller: _controller,
              hintText: l10n.translate('onboarding.v2.referral.hint'),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
              onChanged: _onChanged,
              onSubmitted: (_) => _submit(),
              errorText: _error,
              prefixIcon: Icon(
                Icons.confirmation_number_outlined,
                color: palette.textTertiary,
                size: AppSize.iconMd.r,
              ),
              suffixIcon: _checking
                  ? Padding(
                      padding: EdgeInsets.all(AppSpacing.sm.r),
                      child: SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.textTertiary,
                        ),
                      ),
                    )
                  : (_verifiedNote != null
                      ? Icon(Icons.check_circle_rounded,
                          color: palette.success, size: AppSize.iconMd.r)
                      : null),
            ),
          ),
          if (_verifiedNote != null) ...[
            SizedBox(height: AppSpacing.md.h),
            OnboardingInfoNote(
              text: _verifiedNote!,
              icon: Icons.verified_rounded,
              color: palette.success,
            ),
          ],
          if (_controller.text.trim().isEmpty && _error == null) ...[
            SizedBox(height: AppSpacing.md.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _pasteFromClipboard,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_paste_rounded,
                        size: AppSize.iconSm.r, color: palette.textSecondary),
                    SizedBox(width: AppSpacing.xs.w),
                    Text(
                      l10n.translate('onboarding.v2.referral.paste_button'),
                      style: AppText.of(context).labelL.copyWith(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
