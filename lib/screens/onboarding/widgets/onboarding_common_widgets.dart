import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';

class OnboardingNextButton extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  const OnboardingNextButton({
    Key? key,
    required this.step,
    required this.previousStep,
    this.onNext,
  }) : super(key: key);

  @override
  State<OnboardingNextButton> createState() => _OnboardingNextButtonState();
}

class _OnboardingNextButtonState extends State<OnboardingNextButton>
    with TickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;
  bool _isButtonEnabled = true;
  late double _currentProgress;
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _currentProgress = widget.step / 4.0;
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _tapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.0,
      upperBound: 1.0,
    );

    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
        CurvedAnimation(parent: _tapController, curve: Curves.easeInOut));

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _progressAnimation = Tween<double>(
      begin: _currentProgress,
      end: _currentProgress,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(OnboardingNextButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step) {
      final newProgress = widget.step / 4.0;
      _progressAnimation = Tween<double>(
        begin: _currentProgress,
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

    setState(() {
      _isButtonEnabled = false;
    });

    await _tapController.forward();
    await _tapController.reverse();

    if (widget.onNext != null) {
      widget.onNext!();
    }

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _isButtonEnabled = true;
      });
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
    final isLastStep = widget.step == 4;

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
      ..color = colorScheme.onboardingNextButtonBorderColor.withOpacity(0.18)
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
    Key? key,
    required this.icon,
    required this.child,
  }) : super(key: key);

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
    Key? key,
    this.onSkip,
  }) : super(key: key);

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
