import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../constants.dart';

class OnboardingBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const OnboardingBackButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>();
    if (appColors == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Icon(
          Icons.arrow_back,
          color: appColors.onboardingTitleColor,
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

    _progressAnimation = Tween<double>(begin: beginProgress, end: endProgress)
        .animate(
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
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          '${localizations.translate('onboarding.step')} ${widget.currentStep}/${widget.totalSteps}',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onboardingTitleColor,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: const Color.fromRGBO(242, 237, 232, 1),
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
                    color: primaryColor,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onboardingTitleColor,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onboardingTitleColor,
            fontFamily: 'Poppins',
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onboardingTitleColor,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onboardingSubtitleColor,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          localizations.translate(
            'onboarding.page2.primary_goal.selected_count',
            {'count': selectedValues.length.toString()},
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colorScheme.onboardingSubtitleColor,
            fontFamily: 'Poppins',
          ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected
                ? primaryColor.withOpacity(0.2)
                : Colors.grey.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon!,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : colorScheme.onboardingTitleColor,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              option.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : colorScheme.onboardingTitleColor,
                fontFamily: 'Poppins',
              ),
            ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: ValueListenableBuilder<bool>(
        valueListenable: isLoadingNotifier,
        builder: (context, isLoading, child) {
          return ElevatedButton(
            onPressed: onPressed != null && !isLoading ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              disabledBackgroundColor: colorScheme.primaryColorCustom
                  .withOpacity(0.5),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                : Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: Colors.white,
                    ),
                  ),
          );
        },
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBackButtonPressed != null)
                GestureDetector(
                  onTap: onBackButtonPressed,
                  child: const Icon(Icons.arrow_back, size: 24),
                ),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Lexend',
                    color: colorScheme.titleColor,
                  ),
                ),
              ),
              if (onBackButtonPressed != null) const SizedBox(width: 24),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${localizations.translate('onboarding.step')} $currentStep/$totalSteps',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'Poppins',
              color: colorScheme.titleColor,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final double progress = (currentStep / totalSteps).clamp(
                0.0,
                1.0,
              );
              return Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: constraints.maxWidth * progress,
                    height: 8,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ],
              );
            },
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colorScheme.onboardingTitleColor,
            fontFamily: 'Poppins',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onboardingSubtitleColor,
            fontFamily: 'Poppins',
          ),
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
                color: colorScheme.onboardingTitleColor.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: colorScheme.onboardingTitleColor.withOpacity(0.1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
