import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

class OnboardingNextButton extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  const OnboardingNextButton({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
  });

  @override
  State<OnboardingNextButton> createState() => _OnboardingNextButtonState();
}

class _OnboardingNextButtonState extends State<OnboardingNextButton>
    with TickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;
  final bool _isButtonEnabled = true;
  late double _currentProgress;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.previousStep * 0.25;
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressAnimation = Tween<double>(
      begin: _currentProgress,
      end: widget.step * 0.25,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _progressController.forward();
  }

  @override
  void didUpdateWidget(OnboardingNextButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.previousStep != oldWidget.previousStep ||
        widget.step != oldWidget.step) {
      final newProgress = widget.step * 0.25;

      _progressAnimation = Tween<double>(
        begin: widget.previousStep * 0.25,
        end: newProgress,
      ).animate(CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ));

      _currentProgress = newProgress;
      _progressController.forward(from: 0.0);
    }
  }

  Future<void> _handleTap() async {
    if (!_isButtonEnabled) return;

    // Call onNext immediately without disabling the button
    if (widget.onNext != null) {
      widget.onNext!();
    }

    // Run animations in background without blocking the button
    try {
      await _tapController.forward();
      await _tapController.reverse();
    } catch (e) {
      // Ignore animation errors
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context);
    final isLastStep = widget.step == 5;

    return Center(
      child: GestureDetector(
        onTap: _isButtonEnabled ? _handleTap : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_scaleAnim, _progressAnimation]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnim.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 124,
                    height: 124,
                    child: CustomPaint(
                      painter: _ProgressCirclePainterV2(
                          _progressAnimation.value, colorScheme),
                    ),
                  ),
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: colorScheme.onboardingNextButtonColor,
                      shape: BoxShape.circle,
                    ),
                    child: isLastStep
                        ? Text(
                            localizations.translate('onboarding.get_started'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.backgroundColor2,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          )
                        : Icon(Icons.arrow_forward,
                            color: colorScheme.backgroundColor2, size: 28),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressCirclePainterV2 extends CustomPainter {
  final double progress;
  final ColorScheme colorScheme;
  _ProgressCirclePainterV2(this.progress, this.colorScheme);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPaint = Paint()
      ..color =
          colorScheme.onboardingNextButtonBorderColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final Paint fgPaint = Paint()
      ..color = colorScheme.onboardingNextButtonColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;

    // Draw background circle
    canvas.drawCircle(center, radius, bgPaint);

    // Draw progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(
        rect,
        -1.5708, // -90 degrees in radians
        6.2832 * progress, // 360 degrees * progress
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressCirclePainterV2 oldDelegate) {
    // Always repaint to ensure smooth animation
    return true;
  }
}

class ProfileInput extends StatelessWidget {
  final String label;
  final String value;
  final bool isDate;
  final VoidCallback? onTap;
  const ProfileInput({
    super.key,
    required this.label,
    required this.value,
    this.isDate = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor, width: 1.2),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 16,
                    color: secondaryColor,
                    fontFamily: 'Poppins')),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFFB0B0B0),
                    fontFamily: 'Poppins')),
            if (isDate)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child:
                    Icon(Icons.calendar_today, size: 18, color: primaryColor),
              ),
          ],
        ),
      ),
    );
  }
}

class OnboardingCardInput extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const OnboardingCardInput({
    super.key,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.onboardingOptionBgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onboardingOptionTextColor, size: 24),
          const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class OnboardingSkipButton extends StatelessWidget {
  final VoidCallback? onSkip;

  const OnboardingSkipButton({
    super.key,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return TextButton(
      onPressed: onSkip,
      child: Text(
        localizations.translate('onboarding.skip'),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onboardingOptionTextColor,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFamily: 'Poppins',
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
  final bool showProgress;

  const OnboardingHeader({
    super.key,
    required this.headerText,
    required this.currentStep,
    required this.totalSteps,
    required this.previousStep,
    this.onBackPressed,
    this.showBackButton = true,
    this.padding,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
      child: Column(
        children: [
          // Top row with back button and title
          Row(
            children: [
              if (showBackButton && onBackPressed != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: onBackPressed,
                    child: SizedBox(
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
                      fontFamily: 'Poppins',
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
          if (showProgress) ...[
            const SizedBox(height: 16),
            // Progress section - simplified for now
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(totalSteps, (index) {
                  final isActive = index < currentStep;
                  final isCurrent = index == currentStep - 1;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? colorScheme.primaryColorCustom
                          : colorScheme.onboardingTitleColor.withOpacity(0.3),
                      border: isCurrent
                          ? Border.all(
                              color: colorScheme.primaryColorCustom, width: 2)
                          : null,
                    ),
                  );
                }),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
