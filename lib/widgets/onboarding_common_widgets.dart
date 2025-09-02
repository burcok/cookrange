import 'package:flutter/material.dart';
import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../constants.dart';

class OnboardingBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const OnboardingBackButton({
    Key? key,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = Theme.of(context).extension<AppColors>();
    if (appColors == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    Key? key,
    required this.currentStep,
    required this.totalSteps,
    required this.previousStep,
    this.animationDuration = const Duration(milliseconds: 500),
  }) : super(key: key);

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

    _progressAnimation = Tween<double>(
      begin: beginProgress,
      end: endProgress,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

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
            fontFamily: 'Lexend',
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

  OptionData({
    required this.label,
    this.icon,
    required this.value,
  });
}

class OnboardingSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<OptionData> options;
  final String? selectedValue;
  final Function(String) onSelectionChanged;

  const OnboardingSection({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValue,
    required this.onSelectionChanged,
  }) : super(key: key);

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
            fontFamily: 'Lexend',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onboardingTitleColor,
            fontFamily: 'Lexend',
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options
              .map((option) => OnboardingOption(
                    option: option,
                    isSelected: selectedValue == option.value,
                    onTap: () => onSelectionChanged(option.value),
                  ))
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
    Key? key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selectedValues,
    required this.onSelectionChanged,
  }) : super(key: key);

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
            fontFamily: 'Lexend',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: colorScheme.onboardingSubtitleColor,
            fontFamily: 'Lexend',
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${selectedValues.length}/3 seçildi',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: colorScheme.onboardingSubtitleColor,
            fontFamily: 'Lexend',
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: options
              .map((option) => OnboardingOption(
                    option: option,
                    isSelected: selectedValues.contains(option.value),
                    onTap: () => onSelectionChanged(option.value),
                  ))
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
    Key? key,
    required this.option,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:
              isSelected ? primaryColor : colorScheme.onboardingOptionBgColor,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isSelected
                ? colorScheme.onboardingOptionBgColor.withOpacity(0.2)
                : colorScheme.onboardingTitleColor.withOpacity(0.2),
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
                fontFamily: 'Lexend',
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

  const OnboardingContinueButton({
    Key? key,
    required this.onPressed,
    required this.text,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            elevation: 0,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              fontFamily: 'Lexend',
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingHeader extends StatelessWidget {
  final String headerText;
  final int currentStep;
  final int totalSteps;
  final int previousStep;
  final VoidCallback? onBackPressed;
  final bool showBackButton;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? progressPadding;
  final VoidCallback? onBackButtonPressed;

  const OnboardingHeader({
    Key? key,
    required this.headerText,
    required this.currentStep,
    required this.totalSteps,
    required this.previousStep,
    this.onBackPressed,
    this.showBackButton = true,
    this.padding,
    this.progressPadding,
    this.onBackButtonPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localizations = AppLocalizations.of(context);

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
      child: Column(
        children: [
          // Top row with back button and title
          Row(
            children: [
              if (showBackButton &&
                  (onBackPressed != null || onBackButtonPressed != null))
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: onBackButtonPressed ?? onBackPressed,
                    child: Container(
                      width: 48,
                      height: 48,
                      child: Icon(
                        Icons.arrow_back,
                        color: colorScheme.onboardingTitleColor,
                        size: 24,
                      ),
                    ),
                  ),
                )
              else if (showBackButton)
                const SizedBox(width: 48)
              else
                const SizedBox.shrink(),

              Expanded(
                child: Center(
                  child: Text(
                    headerText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onboardingTitleColor,
                      fontFamily: 'Lexend',
                    ),
                  ),
                ),
              ),

              // Balance the layout
              if (showBackButton)
                const SizedBox(width: 48)
              else
                const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 16),

          // Progress section
          Container(
            padding:
                progressPadding ?? const EdgeInsets.symmetric(horizontal: 12),
            child: AnimatedStepIndicator(
              currentStep: currentStep,
              totalSteps: totalSteps,
              previousStep: previousStep,
            ),
          ),
        ],
      ),
    );
  }
}
