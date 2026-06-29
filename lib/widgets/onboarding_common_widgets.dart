import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../core/localization/app_localizations.dart';
import '../core/providers/theme_provider.dart';
import '../core/widgets/ds/ds.dart';

class OnboardingBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const OnboardingBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          Icons.arrow_back,
          color: palette.textPrimary,
          size: 24,
        ),
      ),
    );
  }
}

class AnimatedStepIndicator extends StatefulWidget {
  final int currentStep;
  final int totalSteps;
  final int previousStep;
  final Duration animationDuration;

  const AnimatedStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.previousStep,
    this.animationDuration = const Duration(milliseconds: 500),
  });

  @override
  State<AnimatedStepIndicator> createState() => _AnimatedStepIndicatorState();
}

class _AnimatedStepIndicatorState extends State<AnimatedStepIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    // Animasyonu başlat
    _startAnimation();
  }

  @override
  void didUpdateWidget(AnimatedStepIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStep != widget.currentStep) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    final previousProgress = widget.previousStep / widget.totalSteps;
    final currentProgress = widget.currentStep / widget.totalSteps;

    // Negatif değerleri önlemek için clamp kullan
    final beginProgress = previousProgress.clamp(0.0, 1.0);
    final endProgress = currentProgress.clamp(0.0, 1.0);

    _progressAnimation =
        Tween<double>(begin: beginProgress, end: endProgress).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final localizations = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${localizations.translate('onboarding.step')} ${widget.currentStep}/${widget.totalSteps}',
          style: t.titleM.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(99),
          ),
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressAnimation.value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class OptionData {
  final String label;
  final IconData? icon;
  final String value;

  OptionData({required this.label, this.icon, required this.value});
}

class OnboardingSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<OptionData> options;
  final String? selectedValue;
  final Function(String) onSelectionChanged;

  const OnboardingSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValue,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: t.headlineS.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: t.bodyM.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options
              .map(
                (option) => OnboardingOption(
                  option: option,
                  isSelected: selectedValue == option.value,
                  onTap: () => onSelectionChanged(option.value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class OnboardingMultiSelectSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<OptionData> options;
  final List<String> selectedValues;
  final Function(String) onSelectionChanged;

  const OnboardingMultiSelectSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValues,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final localizations = AppLocalizations.of(context);
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: t.headlineS.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: t.bodyM.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 16),
        Text(
          localizations.translate(
            'onboarding.page2.primary_goal.selected_count',
            variables: {'count': selectedValues.length.toString()},
          ),
          style: t.labelS.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options
              .map(
                (option) => OnboardingOption(
                  option: option,
                  isSelected: selectedValues.contains(option.value),
                  onTap: () => onSelectionChanged(option.value),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class OnboardingOption extends StatefulWidget {
  final OptionData option;
  final bool isSelected;
  final VoidCallback onTap;

  const OnboardingOption({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<OnboardingOption> createState() => _OnboardingOptionState();
}

class _OnboardingOptionState extends State<OnboardingOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    return GestureDetector(
      onTap: () {
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppMotion.fast,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? primary.withValues(alpha: 0.12)
                : palette.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: widget.isSelected
                  ? primary
                  : palette.border,
              width: widget.isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.option.icon != null) ...[
                Icon(
                  widget.option.icon!,
                  size: AppSize.iconSm.r,
                  color: widget.isSelected ? primary : palette.textSecondary,
                ),
                SizedBox(width: AppSpacing.xs.w),
              ],
              Text(
                widget.option.label,
                style: t.labelM.copyWith(
                  fontWeight: FontWeight.w600,
                  color: widget.isSelected ? primary : palette.textPrimary,
                ),
              ),
              if (widget.isSelected) ...[
                SizedBox(width: AppSpacing.xxs.w),
                Icon(
                  Icons.check_circle_rounded,
                  size: 15.r,
                  color: primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingContinueButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final ValueNotifier<bool> isLoadingNotifier;

  const OnboardingContinueButton({
    super.key,
    required this.onPressed,
    required this.text,
    required this.isLoadingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: ValueListenableBuilder<bool>(
        valueListenable: isLoadingNotifier,
        builder: (context, isLoading, _) => AppButton(
          label: text,
          onPressed: (onPressed != null && !isLoading) ? onPressed : null,
          loading: isLoading,
        ),
      ),
    );
  }
}

class OnboardingHeader extends StatelessWidget {
  final String title;
  final int currentStep;
  final int totalSteps;
  final int previousStep;
  final VoidCallback? onBackButtonPressed;

  const OnboardingHeader({
    super.key,
    required this.title,
    required this.currentStep,
    required this.totalSteps,
    required this.previousStep,
    this.onBackButtonPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    return Stack(
      children: [
        // Subtle brand glow at top-left
        Positioned(
          top: -40.h,
          left: -40.w,
          child: Container(
            width: 200.r,
            height: 200.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  primary.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xl.w, vertical: AppSpacing.sm.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onBackButtonPressed != null)
                    GestureDetector(
                      onTap: onBackButtonPressed,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        width: 36.r,
                        height: 36.r,
                        decoration: BoxDecoration(
                          color: palette.surfaceVariant.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.border),
                        ),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15.r,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: t.titleL.copyWith(
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  if (onBackButtonPressed != null) SizedBox(width: 36.r),
                ],
              ),
              SizedBox(height: AppSpacing.sm.h),
              Row(
                children: [
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double progress =
                            (currentStep / totalSteps).clamp(0.0, 1.0);
                        return Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 5.h,
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full.r),
                              ),
                            ),
                            AnimatedContainer(
                              duration: AppMotion.normal,
                              curve: AppMotion.standard,
                              width: constraints.maxWidth * progress,
                              height: 5.h,
                              decoration: BoxDecoration(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full.r),
                                gradient: LinearGradient(
                                  colors: [primary, primary.withValues(alpha: 0.7)],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  Text(
                    '$currentStep/$totalSteps',
                    style: t.labelS.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class OnboardingTextInputSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;

  const OnboardingTextInputSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.controller,
    required this.hintText,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: t.headlineS.copyWith(color: palette.textPrimary),
        ),
        SizedBox(height: AppSpacing.xxs.h),
        Text(
          subtitle,
          style: t.bodyM.copyWith(color: palette.textSecondary),
        ),
        SizedBox(height: AppSpacing.md.h),
        AppCard(
          bordered: true,
          elevated: false,
          padding: EdgeInsets.all(AppSpacing.sm.r),
          child: AppTextField(
            controller: controller,
            hintText: hintText,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
