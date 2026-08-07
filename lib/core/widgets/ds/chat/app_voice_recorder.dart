import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_gradients.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';
import '../../../utils/accessibility_utils.dart';

/// Faz 6 — the active-recording bar shown in the composer in place of the
/// text field once recording has started. Callback-only, no Firebase/
/// service imports — matches every other DS chat widget's contract.
///
/// **Gesture ownership — why the drag ISN'T handled inside this widget:**
/// press-and-hold starts on the composer's own mic button
/// (`onLongPressStart`), which is what mounts this bar. Flutter binds a
/// pointer's entire down→move→up sequence to whichever widget was hit-tested
/// at pointer-DOWN — a widget that only enters the tree once recording has
/// already started (this one) can never receive that same pointer's later
/// move/up events, no matter what `GestureDetector` it wraps itself in.
/// So the mic button keeps tracking its own `onLongPressMoveUpdate`/
/// `onLongPressEnd` for the whole gesture and reports the live drag distance
/// down via [dragDx]/[dragDy] on every rebuild; this widget's job is to
/// centralize the cancel/lock THRESHOLD policy (in [didUpdateWidget], purely
/// reacting to those incoming values — the same mechanism
/// `AppTypingIndicator.didUpdateWidget` uses for its own prop-driven
/// animation) and render the chrome. [onLock] and the drag-triggered
/// [onCancel] fire from that reactive check, not from an owned recognizer.
///
/// Once locked, the original pointer is expected to have been released
/// (hands-free recording) — at that point a fresh tap on this widget's own
/// stop/delete buttons is a brand-new pointer-down with no handoff problem,
/// so THOSE two are genuinely widget-owned gestures: the locked layout's
/// send button fires [onRelease] and its delete button fires [onCancel].
class AppVoiceRecorder extends StatefulWidget {
  /// Elapsed recording time — the caller owns the actual timer.
  final Duration elapsed;

  /// Live per-tick amplitude, already normalized 0-100 (e.g. the caller maps
  /// `record`'s `Amplitude.current` dBFS reading through the same formula
  /// `WaveformDownsampler` uses). Purely for the live waveform bar — this
  /// widget never touches the recording package itself.
  final Stream<double>? amplitudeStream;

  /// Live horizontal drag distance in logical pixels, reported by the
  /// caller's own `onLongPressMoveUpdate` (0 = no drag; grows as the user
  /// slides toward cancel). See the class doc comment.
  final double dragDx;

  /// Live vertical drag distance in logical pixels, same source as
  /// [dragDx] (0 = no drag; grows as the user slides up toward lock).
  final double dragDy;

  /// Fires once when [dragDx] crosses [cancelThresholdPx], and again (with
  /// the same meaning) if the user taps the delete button in the locked
  /// layout.
  final VoidCallback? onCancel;

  /// Fires once when [dragDy] crosses [lockThresholdPx].
  final VoidCallback? onLock;

  /// Fires ONLY from the locked layout's send button — a normal release
  /// (finger lifted, under both thresholds) is the caller's own
  /// `onLongPressEnd` to detect and act on directly, since it already knows
  /// that happened without needing this widget to tell it twice.
  final VoidCallback? onRelease;

  const AppVoiceRecorder({
    super.key,
    required this.elapsed,
    this.amplitudeStream,
    this.dragDx = 0,
    this.dragDy = 0,
    this.onCancel,
    this.onLock,
    this.onRelease,
  });

  static const double cancelThresholdPx = 80.0;
  static const double lockThresholdPx = 56.0;

  @override
  State<AppVoiceRecorder> createState() => _AppVoiceRecorderState();
}

class _AppVoiceRecorderState extends State<AppVoiceRecorder>
    with SingleTickerProviderStateMixin {
  static const int _maxBars = 40;

  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: AppMotion.ambient,
  );

  StreamSubscription<double>? _ampSub;
  final List<double> _bars = [];
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _pulseController.repeat(reverse: true);
    _subscribeAmplitude();
  }

  @override
  void didUpdateWidget(covariant AppVoiceRecorder old) {
    super.didUpdateWidget(old);
    if (old.amplitudeStream != widget.amplitudeStream) {
      unawaited(_ampSub?.cancel());
      _subscribeAmplitude();
    }
    _checkThresholds();
  }

  void _subscribeAmplitude() {
    _ampSub = widget.amplitudeStream?.listen((value) {
      if (!mounted) return;
      setState(() {
        _bars.add(value.clamp(0, 100));
        if (_bars.length > _maxBars) _bars.removeAt(0);
      });
    });
  }

  void _checkThresholds() {
    if (_locked) return;
    if (widget.dragDy >= AppVoiceRecorder.lockThresholdPx) {
      setState(() => _locked = true);
      HapticFeedback.mediumImpact();
      widget.onLock?.call();
      return; // locked wins over a simultaneous cancel-range drag
    }
    if (widget.dragDx >= AppVoiceRecorder.cancelThresholdPx) {
      HapticFeedback.mediumImpact();
      widget.onCancel?.call();
    }
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final s = widget.elapsed.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final reduceMotion = AccessibilityUtils.reduceMotion(context);

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(
        color: palette.surfaceVariant.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.xl.r),
        border: Border.all(color: palette.glassStroke, width: 0.5),
      ),
      child: _locked
          ? _LockedRow(
              elapsedLabel: _elapsedLabel,
              bars: _bars,
              onDelete: () {
                HapticFeedback.selectionClick();
                widget.onCancel?.call();
              },
              onSend: () {
                HapticFeedback.mediumImpact();
                widget.onRelease?.call();
              },
            )
          : _ActiveContent(
              elapsedLabel: _elapsedLabel,
              bars: _bars,
              pulseController: _pulseController,
              reduceMotion: reduceMotion,
              cancelProgress:
                  (widget.dragDx / AppVoiceRecorder.cancelThresholdPx)
                      .clamp(0.0, 1.0),
              lockProgress: (widget.dragDy / AppVoiceRecorder.lockThresholdPx)
                  .clamp(0.0, 1.0),
              slideToCancelLabel:
                  l10n.translate('chat.voice_recorder.slide_to_cancel'),
            ),
    );
  }
}

class _ActiveContent extends StatelessWidget {
  final String elapsedLabel;
  final List<double> bars;
  final AnimationController pulseController;
  final bool reduceMotion;
  final double cancelProgress;
  final double lockProgress;
  final String slideToCancelLabel;

  const _ActiveContent({
    required this.elapsedLabel,
    required this.bars,
    required this.pulseController,
    required this.reduceMotion,
    required this.cancelProgress,
    required this.lockProgress,
    required this.slideToCancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _PulsingDot(
                controller: pulseController, reduceMotion: reduceMotion),
            SizedBox(width: AppSpacing.xxs.w),
            Text(elapsedLabel,
                style: t.labelM.copyWith(
                    color: palette.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()])),
            SizedBox(width: AppSpacing.sm.w),
            Expanded(child: _WaveformBars(bars: bars)),
            SizedBox(width: AppSpacing.sm.w),
            _LockChevron(progress: lockProgress),
          ],
        ),
        SizedBox(height: 2.h),
        Opacity(
          opacity: 1 - cancelProgress,
          child: Transform.translate(
            offset: Offset(-cancelProgress * 24.w, 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chevron_left_rounded,
                    size: AppSize.iconXs.r, color: palette.textTertiary),
                Text(slideToCancelLabel,
                    style: t.labelS.copyWith(color: palette.textTertiary)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedRow extends StatelessWidget {
  final String elapsedLabel;
  final List<double> bars;
  final VoidCallback onDelete;
  final VoidCallback onSend;

  const _LockedRow({
    required this.elapsedLabel,
    required this.bars,
    required this.onDelete,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final t = AppText.of(context);

    return Row(
      children: [
        Semantics(
          button: true,
          label: l10n.translate('chat.voice_recorder.delete'),
          child: IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline_rounded, color: palette.error),
            onPressed: onDelete,
          ),
        ),
        Text(elapsedLabel,
            style: t.labelM.copyWith(
                color: palette.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()])),
        SizedBox(width: AppSpacing.sm.w),
        Expanded(child: _WaveformBars(bars: bars)),
        SizedBox(width: AppSpacing.sm.w),
        Semantics(
          button: true,
          label: l10n.translate('chat.actions.send'),
          child: GestureDetector(
            onTap: onSend,
            child: Container(
              padding: EdgeInsets.all(AppSpacing.xs.r + 2),
              decoration: BoxDecoration(
                gradient: AppGradients.brand(theme.primaryColor),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withValues(alpha: 0.35),
                    blurRadius: 8.r,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.send_rounded,
                  color: Colors.white, size: AppSize.iconSm.r),
            ),
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatelessWidget {
  final AnimationController controller;
  final bool reduceMotion;

  const _PulsingDot({required this.controller, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final dot = Container(
      width: 8.r,
      height: 8.r,
      decoration: BoxDecoration(color: palette.error, shape: BoxShape.circle),
    );
    if (reduceMotion) return dot;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) =>
          Opacity(opacity: 0.4 + controller.value * 0.6, child: child),
      child: dot,
    );
  }
}

class _LockChevron extends StatelessWidget {
  final double progress; // 0-1

  const _LockChevron({required this.progress});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final color = Color.lerp(
        palette.textTertiary, Theme.of(context).primaryColor, progress)!;

    return Transform.translate(
      offset: Offset(0, -progress * 10.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 3.h),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.full.r),
          border: Border.all(color: palette.glassStroke, width: 0.5),
        ),
        child: Icon(Icons.lock_outline_rounded, size: 14.r, color: color),
      ),
    );
  }
}

class _WaveformBars extends StatelessWidget {
  final List<double> bars; // 0-100 each, most recent last

  const _WaveformBars({required this.bars});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).primaryColor;
    // Flat placeholder bars before the first amplitude tick arrives.
    final values = bars.isEmpty ? List<double>.filled(24, 6.0) : bars;

    return SizedBox(
      height: 22.h,
      child: Row(
        children: values
            .map((v) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 1.w),
                    child: Container(
                      height: (4 + v.clamp(0, 100) / 100 * 18).h,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ))
            .toList(growable: false),
      ),
    );
  }
}
