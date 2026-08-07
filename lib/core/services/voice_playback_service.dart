import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'crashlytics_service.dart';

/// Snapshot of the app's single active (or most recently active) voice-note
/// playback. [playingMessageId] is the `MessageModel.id` currently loaded
/// into the shared player, or null once nothing has played yet or [stop] was
/// called. `AppVoicePlayer` only trusts [position]/[duration]/[isPlaying] for
/// the bubble whose own message id matches [playingMessageId] — every other
/// bubble renders itself as paused-at-zero regardless of what this holds.
@immutable
class VoicePlaybackState {
  final String? playingMessageId;
  final Duration position;
  final Duration? duration;
  final double speed;
  final bool isPlaying;

  const VoicePlaybackState({
    this.playingMessageId,
    this.position = Duration.zero,
    this.duration,
    this.speed = 1.0,
    this.isPlaying = false,
  });

  VoicePlaybackState copyWith({
    Duration? position,
    Duration? duration,
    double? speed,
    bool? isPlaying,
  }) {
    return VoicePlaybackState(
      playingMessageId: playingMessageId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      isPlaying: isPlaying ?? this.isPlaying,
    );
  }
}

/// Faz 6 — one `just_audio` player for the whole app. A chat can only ever
/// be listening to one voice note at a time, so a per-bubble player would
/// just mean every OTHER bubble has to reach out and stop it anyway;
/// centralizing playback here means starting note B always stops note A for
/// free, with no bubble needing a reference to any other bubble.
///
/// **Lifecycle — read before wiring this up**: this is an app-wide
/// singleton, not scoped to any screen or widget — it does NOT stop itself
/// when a chat screen closes. The OWNING screen (`ChatDetailScreen`) MUST
/// call [stop] from its own `dispose()`, or a voice note started in a chat
/// keeps audibly playing after the user navigates away. [dispose] (which
/// tears down the underlying player entirely) is deliberately NOT that
/// hook — this singleton is meant to outlive any single screen for the rest
/// of the app's process lifetime; [dispose] exists only for tests/hot-restart
/// cleanup.
class VoicePlaybackService {
  static final VoicePlaybackService _instance =
      VoicePlaybackService._internal();
  factory VoicePlaybackService() => _instance;

  VoicePlaybackService._internal() {
    _positionSub = _player.positionStream.listen((position) {
      _state.value = _state.value.copyWith(position: position);
    });
    _durationSub = _player.durationStream.listen((duration) {
      if (duration != null) {
        _state.value = _state.value.copyWith(duration: duration);
      }
    });
    _playingSub = _player.playingStream.listen((isPlaying) {
      _state.value = _state.value.copyWith(isPlaying: isPlaying);
    });
    // A note that plays to its end should read as "not playing, at the
    // end" without the caller needing an explicit pause/stop call.
    _processingSub = _player.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        _state.value = _state.value.copyWith(
          isPlaying: false,
          position: _state.value.duration ?? Duration.zero,
        );
      }
    });
  }

  /// Speeds `AppVoicePlayer`'s tappable speed control cycles through.
  static const List<double> allowedSpeeds = [1.0, 1.5, 2.0];

  final AudioPlayer _player = AudioPlayer();

  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<Duration?> _durationSub;
  late final StreamSubscription<bool> _playingSub;
  late final StreamSubscription<ProcessingState> _processingSub;

  final ValueNotifier<VoicePlaybackState> _state =
      ValueNotifier(const VoicePlaybackState());

  /// Listen with `ValueListenableBuilder`/`AnimatedBuilder` to re-render only
  /// while a note is loaded; compare `playingMessageId` against your own
  /// message id before trusting position/duration/isPlaying.
  ValueListenable<VoicePlaybackState> get state => _state;

  /// Plays the voice note at [url] belonging to [messageId], stopping
  /// whatever was previously playing first — only one note plays at a time,
  /// app-wide. Resuming the SAME [messageId] after a [pause] continues from
  /// its last position rather than restarting, unless [startPosition] is
  /// given explicitly (e.g. the user tapped a specific point on the
  /// waveform).
  Future<void> play(
    String url, {
    required String messageId,
    Duration? startPosition,
  }) async {
    final isSameNoteStillLoaded = _state.value.playingMessageId == messageId &&
        _player.processingState != ProcessingState.idle;

    try {
      if (!isSameNoteStillLoaded) {
        await _player.stop();
        _state.value = VoicePlaybackState(
          playingMessageId: messageId,
          speed: _state.value.speed, // carry the user's chosen speed over
        );
        final duration = await _player.setUrl(url);
        if (duration != null) {
          _state.value = _state.value.copyWith(duration: duration);
        }
        await _player.setSpeed(_state.value.speed);
      }
      if (startPosition != null) await _player.seek(startPosition);
      await _player.play();
    } catch (e, st) {
      debugPrint('VoicePlaybackService.play error for $messageId: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'VoicePlaybackService.play($messageId)'));
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e, st) {
      debugPrint('VoicePlaybackService.pause error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'VoicePlaybackService.pause'));
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e, st) {
      debugPrint('VoicePlaybackService.seek error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'VoicePlaybackService.seek'));
    }
  }

  /// [speed] must be one of [allowedSpeeds] — enforced with an assert rather
  /// than silently clamping, since every caller in this app is expected to
  /// come from `AppVoicePlayer`'s fixed 1x/1.5x/2x control, never free input.
  Future<void> setSpeed(double speed) async {
    assert(allowedSpeeds.contains(speed),
        'VoicePlaybackService.setSpeed: $speed is not one of $allowedSpeeds');
    try {
      await _player.setSpeed(speed);
      _state.value = _state.value.copyWith(speed: speed);
    } catch (e, st) {
      debugPrint('VoicePlaybackService.setSpeed error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'VoicePlaybackService.setSpeed'));
    }
  }

  /// Cycles 1x -> 1.5x -> 2x -> 1x. Convenience for `AppVoicePlayer`'s
  /// tappable speed chip so it doesn't need its own cycling logic.
  Future<void> cycleSpeed() {
    final i = allowedSpeeds.indexOf(_state.value.speed);
    final next = allowedSpeeds[(i + 1) % allowedSpeeds.length];
    return setSpeed(next);
  }

  /// Stops playback and clears [state] back to its initial value (keeping
  /// the user's last-chosen [VoicePlaybackState.speed] is intentionally NOT
  /// preserved here — a fresh screen/session starts at 1x). Call this from
  /// the owning screen's `dispose()` — see the class doc comment.
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e, st) {
      debugPrint('VoicePlaybackService.stop error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'VoicePlaybackService.stop'));
    } finally {
      _state.value = const VoicePlaybackState();
    }
  }

  /// Tears down the underlying player and its stream subscriptions
  /// entirely. NOT part of the normal per-screen lifecycle — see the class
  /// doc comment for why [stop] (not this) is what `ChatDetailScreen` calls.
  Future<void> dispose() async {
    await _positionSub.cancel();
    await _durationSub.cancel();
    await _playingSub.cancel();
    await _processingSub.cancel();
    await _player.dispose();
  }
}
