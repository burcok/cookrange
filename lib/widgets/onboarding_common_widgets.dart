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

class OnboardingOption extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.15)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : palette.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon!,
                size: 22,
                color: isSelected ? primary : palette.textSecondary,
              ),
              SizedBox(width: 8.w),
            ],
            Text(
              option.label,
              style: t.bodyM.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? primary : palette.textPrimary,
              ),
            ),
            if (isSelected) ...[
              SizedBox(width: 6.w),
              Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: primary,
              ),
            ],
          ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBackButtonPressed != null)
                GestureDetector(
                  onTap: onBackButtonPressed,
                  child: Icon(Icons.arrow_back, size: 24, color: palette.textPrimary),
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
              if (onBackButtonPressed != null) const SizedBox(width: 24),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double progress = (currentStep / totalSteps).clamp(0.0, 1.0);
                    return Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 6.h,
                          decoration: BoxDecoration(
                            color: primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: constraints.maxWidth * progress,
                          height: 6.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: const LinearGradient(
                              colors: [AppPalette.brand, Color(0xFFFF6B6B)],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
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
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: t.bodyM.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: palette.border,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: palette.border,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
