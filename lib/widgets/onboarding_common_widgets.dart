import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: appColors.onboardingTitleColor.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Icon(
          Icons.arrow_back,
          color: appColors.onboardingTitleColor,
          size: 24,
        ),
      ),
    );
  }
}
