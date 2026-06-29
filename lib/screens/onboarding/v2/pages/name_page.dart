import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/providers/onboarding_provider.dart';
import '../../../../core/widgets/ds/ds.dart';
import '../onboarding_scaffold.dart';

/// Onboarding page 1 — collects the user's first name, used everywhere after
/// for personalization and persisted as the account `displayName` at sign-up.
class OnboardingNamePage extends StatefulWidget {
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const OnboardingNamePage({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<OnboardingNamePage> createState() => _OnboardingNamePageState();
}

class _OnboardingNamePageState extends State<OnboardingNamePage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<OnboardingProvider>().firstName ?? '',
    );
    // Logged-in completion hydrates the provider one frame after this page
    // mounts; adopt the prefilled name if the user hasn't typed anything yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final name = context.read<OnboardingProvider>().firstName;
      if (name != null && name.isNotEmpty && _controller.text.isEmpty) {
        setState(() => _controller.text = name);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_valid) return;
    context.read<OnboardingProvider>().setFirstName(_controller.text);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return OnboardingScaffold(
      progress: (widget.step + 1) / widget.totalSteps,
      onBack: widget.onBack,
      onContinue: _valid ? _submit : null,
      continueLabel: l10n.translate('onboarding.continue'),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppSpacing.xxl.h),
            Text(
              l10n.translate('onboarding.v2.name.title'),
              style: t.displayM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              l10n.translate('onboarding.v2.name.subtitle'),
              style: t.bodyL.copyWith(color: palette.textSecondary, height: 1.5),
            ),
            SizedBox(height: AppSpacing.xxl.h),
            AppCard(
              bordered: true,
              elevated: false,
              padding: EdgeInsets.all(AppSpacing.md.r),
              child: AppTextField(
                controller: _controller,
                hintText: l10n.translate('onboarding.v2.name.hint'),
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.givenName],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                prefixIcon: Icon(
                  Icons.person_outline_rounded,
                  color: palette.textTertiary,
                  size: AppSize.iconMd.r,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
