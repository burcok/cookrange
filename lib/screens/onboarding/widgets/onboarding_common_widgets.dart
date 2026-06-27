import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/widgets/ds/ds.dart';

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

    if (widget.onNext != null) {
      widget.onNext!();
    }

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
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final localizations = AppLocalizations.of(context);
    final t = AppText.of(context);
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
                          _progressAnimation.value, primary),
                    ),
                  ),
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                    child: isLastStep
                        ? Text(
                            localizations.translate('onboarding.get_started'),
                            textAlign: TextAlign.center,
                            style: t.labelL.copyWith(
                              fontWeight: FontWeight.w600,
                              color: palette.textInverse,
                            ),
                          )
                        : Icon(Icons.arrow_forward,
                            color: palette.textInverse, size: 28),
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
  final Color primary;
  _ProgressCirclePainterV2(this.progress, this.primary);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPaint = Paint()
      ..color = primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final Paint fgPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;

    canvas.drawCircle(center, radius, bgPaint);

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
  bool shouldRepaint(covariant _ProgressCirclePainterV2 oldDelegate) => true;
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
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final t = AppText.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primary, width: 1.2),
        ),
        child: Row(
          children: [
            Text(label,
                style: t.bodyL.copyWith(color: palette.textPrimary)),
            const Spacer(),
            Text(value,
                style: t.bodyL.copyWith(color: palette.textTertiary)),
            if (isDate)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Icon(Icons.calendar_today, size: 18, color: primary),
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
    final palette = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: palette.textSecondary, size: 24),
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
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return TextButton(
      onPressed: onSkip,
      child: Text(
        localizations.translate('onboarding.skip'),
        style: t.titleM.copyWith(
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
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
    final palette = AppPalette.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;
    final t = AppText.of(context);

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
                        color: palette.textPrimary,
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
                    style: t.headlineS.copyWith(color: palette.textPrimary),
                  ),
                ),
              ),

              if (showBackButton)
                const SizedBox(width: 48)
              else
                const SizedBox.shrink(),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 16),
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
                          ? primary
                          : palette.textPrimary.withValues(alpha: 0.3),
                      border: isCurrent
                          ? Border.all(color: primary, width: 2)
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
