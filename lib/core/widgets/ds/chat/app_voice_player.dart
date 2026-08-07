import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../localization/app_localizations.dart';
import '../../../services/voice_playback_service.dart';
import '../../../theme/app_dimensions.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_typography.dart';

/// Faz 6 — bubble content for a `MessageType.voice` message: play/pause,
/// static waveform (rendered from the message's own stored [peaks], never
/// decoded live audio — the receiver renders the SENDER's waveform snapshot),
/// elapsed/total time, an unplayed-dot indicator, and a tappable 1x/1.5x/2x
/// speed control.
///
/// **Service coupling — a deliberate exception to "DS widgets take
/// callbacks, never services":** every OTHER bubble in this bar is a static
/// render of `MessageModel` fields, but a voice bubble's play/pause state is
/// inherently a live, cross-bubble singleton concern (only one note plays
/// app-wide, and every other bubble must visually react the instant a
/// different one starts) — threading that through the screen and back down
/// as props to every bubble on every tick would mean the screen rebuilding
/// its entire message list on every position update. `VoicePlaybackService`
/// is a plain Dart singleton (no Firebase/Firestore import), so reading it
/// here via `ValueListenableBuilder` costs nothing architecturally and keeps
/// only the ONE bubble that's actually playing rebuilding. Callbacks are
/// still used for everything this widget can't decide for itself (whether
/// the note counts as "played" is caller/persistence-owned — see
/// [onFirstPlay]).
class AppVoicePlayer extends StatelessWidget {
  final String messageId;
  final String url;
  final int? durationMs;
  final List<int>? peaks;
  final bool isMe;

  /// Whether this note has ever been played before (WhatsApp-style "unheard"
  /// dot). Persistence is the CALLER's job (device-scoped — Hive/
  /// SharedPreferences per `docs/DATABASE.md`'s caching-tier guidance, R3)
  /// — this widget only renders the dot and reports the moment it should be
  /// persisted via [onFirstPlay].
  final bool hasBeenPlayed;

  /// Fires once, the first time THIS note starts playing while
  /// [hasBeenPlayed] was false — the caller's cue to persist that.
  final VoidCallback? onFirstPlay;

  const AppVoicePlayer({
    super.key,
    required this.messageId,
    required this.url,
    this.durationMs,
    this.peaks,
    this.isMe = false,
    this.hasBeenPlayed = false,
    this.onFirstPlay,
  });

  String _formatMs(int ms) {
    final totalSeconds = (ms / 1000).round();
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final theme = Theme.of(context);
    final fallbackDurationMs = durationMs ?? 0;

    return ValueListenableBuilder<VoicePlaybackState>(
      valueListenable: VoicePlaybackService().state,
      builder: (context, playback, _) {
        final isActive = playback.playingMessageId == messageId;
        final playing = isActive && playback.isPlaying;
        final positionMs = isActive ? playback.position.inMilliseconds : 0;
        final totalMs = isActive && playback.duration != null
            ? playback.duration!.inMilliseconds
            : fallbackDurationMs;
        final progress =
            totalMs > 0 ? (positionMs / totalMs).clamp(0.0, 1.0) : 0.0;
        final speed = isActive ? playback.speed : 1.0;

        void togglePlay() {
          HapticFeedback.selectionClick();
          if (playing) {
            VoicePlaybackService().pause();
          } else {
            if (!hasBeenPlayed) onFirstPlay?.call();
            VoicePlaybackService().play(url, messageId: messageId);
          }
        }

        return SizedBox(
          width: 220.w,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Semantics(
                    button: true,
                    label: l10n.translate(playing
                        ? 'chat.voice_player.pause'
                        : 'chat.voice_player.play'),
                    child: _PlayButton(
                        isMe: isMe, playing: playing, onTap: togglePlay),
                  ),
                  if (!hasBeenPlayed)
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 9.r,
                        height: 9.r,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color:
                                  isMe ? Colors.transparent : palette.surface,
                              width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: AppSpacing.xs.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StaticWaveform(
                      peaks: peaks ?? const [],
                      progress: progress,
                      isMe: isMe,
                      onSeek: totalMs > 0
                          ? (ratio) => VoicePlaybackService().seek(
                              Duration(milliseconds: (totalMs * ratio).round()))
                          : null,
                    ),
                    SizedBox(height: 2.h),
                    Row(
                      children: [
                        Text(
                          '${_formatMs(positionMs)} / ${_formatMs(totalMs)}',
                          style: t.labelS.copyWith(
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.75)
                                : palette.textTertiary,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        Semantics(
                          button: true,
                          label:
                              l10n.translate('chat.voice_player.speed_control'),
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              VoicePlaybackService().cycleSpeed();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 6.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : palette.surfaceVariant,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full.r),
                              ),
                              child: Text(
                                speed == speed.roundToDouble()
                                    ? '${speed.round()}x'
                                    : '${speed}x',
                                style: t.labelS.copyWith(
                                  color: isMe
                                      ? Colors.white
                                      : palette.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isMe;
  final bool playing;
  final VoidCallback onTap;

  const _PlayButton(
      {required this.isMe, required this.playing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = isMe
        ? Colors.white.withValues(alpha: 0.2)
        : theme.primaryColor.withValues(alpha: 0.12);
    final fg = isMe ? Colors.white : theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34.r,
        height: 34.r,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: fg, size: 20.r),
      ),
    );
  }
}

class _StaticWaveform extends StatelessWidget {
  final List<int> peaks;
  final double progress; // 0-1, how much of the waveform is "played"
  final bool isMe;
  final ValueChanged<double>? onSeek; // reports a 0-1 tap ratio

  const _StaticWaveform({
    required this.peaks,
    required this.progress,
    required this.isMe,
    this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final playedColor = isMe ? Colors.white : Theme.of(context).primaryColor;
    final unplayedColor = isMe
        ? Colors.white.withValues(alpha: 0.35)
        : palette.textTertiary.withValues(alpha: 0.5);
    // A voice message with no stored peaks (shouldn't happen — the recorder
    // always downsamples one — falls back to a flat placeholder bar rather
    // than rendering nothing).
    final bars = peaks.isEmpty ? List<int>.filled(30, 15) : peaks;

    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onSeek == null
            ? null
            : (details) {
                final ratio = (details.localPosition.dx / constraints.maxWidth)
                    .clamp(0.0, 1.0);
                onSeek!(ratio);
              },
        child: SizedBox(
          height: 22.h,
          width: double.infinity,
          child: Row(
            children: List.generate(bars.length, (i) {
              final playedHere =
                  bars.isEmpty ? false : (i / bars.length) <= progress;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 0.8.w),
                  child: Container(
                    height: (3 + bars[i].clamp(0, 100) / 100 * 18).h,
                    decoration: BoxDecoration(
                      color: playedHere ? playedColor : unplayedColor,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),
              );
            }, growable: false),
          ),
        ),
      );
    });
  }
}
