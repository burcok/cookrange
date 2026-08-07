import 'dart:async';
import 'dart:io';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../utils/presence_aggregate.dart';
import 'log_service.dart';

/// Chat Upgrade Phase 2 — Realtime Database-backed presence + typing.
///
/// **Why RTDB, and only for this**: Firestore has no disconnect primitive —
/// a killed app (crash, OS force-kill, dead battery) leaves any Firestore
/// field exactly as it was last written, forever. RTDB's `onDisconnect()` is
/// server-side (the RTDB backend itself notices the socket drop and applies
/// the queued write), so it is the only mechanism that can make "the app
/// died" converge to `offline` without a client ever running again. Nothing
/// else about chat moves to RTDB — messages, chats, everything else stays
/// on Firestore. `functions/chat_presence.js`'s `mirrorPresence` copies the
/// AGGREGATE of this device's RTDB state back onto the SAME
/// `users/{uid}.is_online` / `.last_active_at` fields every existing reader
/// (`profile_screen.dart`, `chat_list_screen.dart`, `select_friend_sheet.dart`,
/// `chat_service.dart`) already reads — so this file is the only thing in
/// the client that changes; every downstream reader needs zero edits.
///
/// **Infra dependency (unresolved as of this file landing)**: RTDB is not
/// yet provisioned for this Firebase project — no `database.rules.json`,
/// no `database` block in `firebase.json`, no `firebase_database` in
/// `pubspec.yaml`. Every call below will throw/no-op against a real device
/// until an operator enables Realtime Database in the Firebase console and
/// the sibling changes land (see this phase's report for the exact rules/
/// config/pubspec diffs needed). Written the same way this codebase already
/// treats gym geofencing (needs a physical device to verify) — code is
/// correct against the documented contract, but unverified end-to-end.
///
/// **The one sequencing rule that must never be violated**: for a given
/// device, `onDisconnect().set(offline)` MUST be registered before the
/// corresponding `set(online)` call. If the app crashes between "set
/// online" and "register onDisconnect", that device is a permanent ghost —
/// nothing ever tells RTDB to flip it back. Every write path below (initial
/// connect AND every reconnect, since RTDB drops all `onDisconnect`
/// registrations on every disconnect/reconnect — see [_armConnectionWatcher])
/// registers the disconnect handler first, unconditionally, before writing
/// the online value.
class PresenceService {
  static final PresenceService _instance = PresenceService._internal();
  factory PresenceService() => _instance;
  PresenceService._internal();

  final LogService _log = LogService();
  final Uuid _uuid = const Uuid();
  final String _serviceName = 'PresenceService';

  static const _deviceIdPrefsKey = 'presence_device_id';
  static const _idleTimeout = Duration(minutes: 5);
  static const _heartbeatInterval = Duration(seconds: 120);
  static const _typingStaleAfter = Duration(seconds: 10);

  FirebaseDatabase get _db => FirebaseDatabase.instance;

  bool _initialized = false;
  bool _disposed = false;
  String? _deviceId;
  String? _sessionId;
  String? _currentUid;
  bool _foreground = true;
  bool _connected = false;

  /// What this device's state SHOULD be the moment it's next connected —
  /// applied fresh by [_armConnectionWatcher]'s `.info/connected` handler on
  /// every (re)connect, and updated in place by [goOnline]/[goAway]/
  /// [goOffline] while already connected.
  PresenceState _desiredState = PresenceState.offline;

  StreamSubscription<DatabaseEvent>? _connectionSub;
  Timer? _idleTimer;
  Timer? _heartbeatTimer;
  DateTime? _lastHeartbeatWriteAt;

  DatabaseReference _presenceRef(String uid) =>
      _db.ref('presence/$uid/${_deviceId!}');
  DatabaseReference _privateStateRef(String uid) =>
      _db.ref('private_state/$uid/${_deviceId!}');
  DatabaseReference _typingRef(String chatId, String uid) =>
      _db.ref('typing/$chatId/$uid');

  String get _platformName => Platform.isIOS
      ? 'ios'
      : (Platform.isAndroid ? 'android' : Platform.operatingSystem);

  String _wire(PresenceState s) => switch (s) {
        PresenceState.online => 'online',
        PresenceState.away => 'away',
        PresenceState.offline => 'offline',
      };

  /// Idempotent — safe to call more than once (e.g. `AppLifecycleService`
  /// calling it from `initialize()`, defensively, on every cold start).
  /// Loads/creates the persisted per-install [deviceId] and arms the
  /// `.info/connected` watcher. Does NOT require a signed-in user — the
  /// watcher itself checks [_currentUid] before writing anything, so this
  /// is safe to call before login.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await _ensureDeviceId();
    _armConnectionWatcher();
  }

  Future<void> _ensureDeviceId() async {
    if (_deviceId != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceIdPrefsKey);
      if (id == null) {
        id = _uuid.v4();
        await prefs.setString(_deviceIdPrefsKey, id);
      }
      _deviceId = id;
    } catch (e, s) {
      // Fall back to a session-only id rather than failing presence
      // entirely — worst case this device double-counts across app
      // restarts until SharedPreferences recovers.
      _log.error('PresenceService: failed to load/persist device id',
          service: _serviceName, error: e, stackTrace: s);
      _deviceId ??= _uuid.v4();
    }
  }

  /// RTDB clears every `onDisconnect` registration on every disconnect AND
  /// every reconnect — so registration cannot happen once at startup, it
  /// must re-run every single time `.info/connected` flips back to true.
  void _armConnectionWatcher() {
    if (_connectionSub != null) return;
    _connectionSub = _db.ref('.info/connected').onValue.listen((event) async {
      final connected = event.snapshot.value == true;
      _connected = connected;
      if (!connected) {
        _log.info('PresenceService: RTDB connection lost.',
            service: _serviceName);
        return;
      }
      _log.info(
          'PresenceService: RTDB (re)connected — re-registering onDisconnect + presence.',
          service: _serviceName);
      await _registerDevice(_desiredState);
    }, onError: (Object e, StackTrace s) {
      _log.error('PresenceService: .info/connected watcher failed',
          service: _serviceName, error: e, stackTrace: s);
    });
  }

  /// Full (re)registration for the current device: arms `onDisconnect`
  /// FIRST, then writes the live online/away value, then arms +
  /// initializes `private_state`. Runs on every reconnect (not just first
  /// connect) because RTDB drops the disconnect handler on every drop.
  Future<void> _registerDevice(PresenceState state) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      final presenceRef = _presenceRef(uid);
      final offlinePayload = <String, Object?>{
        'state': _wire(PresenceState.offline),
        'platform': _platformName,
        'activity': null,
        'session_id': _sessionId,
        'last_active': ServerValue.timestamp,
        'connected_at': ServerValue.timestamp,
      };
      // Sequencing rule (class header): onDisconnect BEFORE the online set.
      await presenceRef.onDisconnect().set(offlinePayload);
      await presenceRef.set(<String, Object?>{
        'state': _wire(state),
        'platform': _platformName,
        'activity': _foreground ? 'foreground' : 'background',
        'session_id': _sessionId,
        'last_active': ServerValue.timestamp,
        'connected_at': ServerValue.timestamp,
      });

      final privateStateRef = _privateStateRef(uid);
      await privateStateRef.onDisconnect().remove();
      // Faz 2 — no consumer wired yet (chat_detail_screen.dart is out of
      // this phase's scope); this just guarantees the node exists with a
      // stable shape for a later screen to call [updatePrivateState] on.
      await privateStateRef.set(<String, Object?>{
        'current_conversation_id': null,
        'current_screen': null,
      });
    } catch (e, s) {
      _log.error('PresenceService: device registration failed',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Lightweight state flip for an ALREADY-registered, still-connected
  /// device (no need to re-arm `onDisconnect` — its payload is always
  /// "offline" regardless of the live state it's replacing).
  Future<void> _applyState(PresenceState state) async {
    _desiredState = state;
    final uid = _currentUid;
    if (uid == null || !_connected) return;
    try {
      await _presenceRef(uid).update(<String, Object?>{
        'state': _wire(state),
        'activity': _foreground ? 'foreground' : 'background',
        'last_active': ServerValue.timestamp,
      });
    } catch (e, s) {
      _log.error('PresenceService: state update failed',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Call on login, app cold-start (already signed in), and app resume.
  /// Always re-arms the idle timer and (re)starts the heartbeat.
  Future<void> goOnline({required String uid}) async {
    if (_disposed) return;
    await _ensureDeviceId();
    _sessionId ??= _uuid.v4();
    _currentUid = uid;
    _foreground = true;
    _armConnectionWatcher();
    // A first-time register (fresh login/cold-start) needs the full
    // sequenced write; a bare foreground flip while already registered only
    // needs the lightweight path. Both are safe to call — a fresh device
    // has nothing to lose by going through the full path every time
    // goOnline runs, and it's cheap (mirrors _setOnline's previous cost).
    if (_connected) {
      await _registerDevice(PresenceState.online);
    } else {
      _desiredState = PresenceState.online;
    }
    _startHeartbeat();
    _restartIdleTimer();
  }

  /// Backgrounded app = away immediately, regardless of the idle timer —
  /// the task's explicit requirement. `onDisconnect` (not a client debounce)
  /// is what protects against a genuinely killed app.
  Future<void> goAway() async {
    if (_disposed || _currentUid == null) return;
    _foreground = false;
    _idleTimer?.cancel();
    _stopHeartbeat();
    await _applyState(PresenceState.away);
  }

  /// Explicit offline: sign-out or app-detach. Best-effort direct write —
  /// `onDisconnect` remains the authoritative backstop if the process dies
  /// before this completes. Uses the internally-tracked [_currentUid], not
  /// a passed-in value, because by the time auth state flips to signed-out
  /// the caller may no longer have a live `User` to read a uid from.
  Future<void> goOffline() async {
    if (_disposed) return;
    _idleTimer?.cancel();
    _stopHeartbeat();
    final uid = _currentUid;
    _desiredState = PresenceState.offline;
    if (uid != null && _connected) {
      try {
        await _presenceRef(uid).update(<String, Object?>{
          'state': _wire(PresenceState.offline),
          'activity': null,
          'last_active': ServerValue.timestamp,
        });
      } catch (e, s) {
        _log.error('PresenceService: explicit goOffline write failed',
            service: _serviceName, error: e, stackTrace: s);
      }
    }
    _currentUid = null;
  }

  /// Caller-driven idle signal (a tap, a keystroke, a scroll) — this
  /// service does NOT auto-detect activity globally, that's the caller's
  /// job. Resets the 5-minute idle timer and, if this device had gone
  /// `away` purely from being idle while still in the foreground, flips it
  /// back to `online`.
  void reportInteraction() {
    if (_disposed || _currentUid == null) return;
    if (_foreground && _desiredState != PresenceState.online) {
      unawaited(_applyState(PresenceState.online));
    }
    _restartIdleTimer();
  }

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    if (!_foreground || _currentUid == null) return;
    _idleTimer = Timer(_idleTimeout, () {
      _log.info('PresenceService: idle timeout reached, marking away.',
          service: _serviceName);
      unawaited(_applyState(PresenceState.away));
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) => heartbeat());
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Throttled `last_active` ping — a staleness SIGNAL for
  /// `reconcileStalePresence`'s server-side sweep only, never the primary
  /// online/offline mechanism (that's `onDisconnect`). Safe to call more
  /// often than [_heartbeatInterval]; the internal throttle no-ops extra
  /// calls.
  Future<void> heartbeat() async {
    if (_disposed || _currentUid == null || !_foreground || !_connected) {
      return;
    }
    final now = DateTime.now();
    if (_lastHeartbeatWriteAt != null &&
        now.difference(_lastHeartbeatWriteAt!) < _heartbeatInterval) {
      return;
    }
    _lastHeartbeatWriteAt = now;
    try {
      await _presenceRef(_currentUid!)
          .update(<String, Object?>{'last_active': ServerValue.timestamp});
    } catch (e, s) {
      _log.error('PresenceService: heartbeat write failed',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Writes `/typing/{chatId}/{uid}` on true, with `onDisconnect().remove()`
  /// armed at the same time (before the value write — same discipline as
  /// device presence: a kill mid-keystroke must not leave a permanent
  /// "still typing" ghost). Removes the node directly on false. No debounce
  /// here — `chat_detail_screen.dart` already owns its own keystroke
  /// debounce; duplicating it here would just be two timers fighting.
  Future<void> setTyping(String chatId, String uid, bool isTyping) async {
    final ref = _typingRef(chatId, uid);
    try {
      if (isTyping) {
        await ref.onDisconnect().remove();
        await ref.set(<String, Object?>{
          'at': ServerValue.timestamp,
          'device_id': _deviceId,
        });
      } else {
        await ref.onDisconnect().cancel();
        await ref.remove();
      }
    } catch (e, s) {
      _log.error('PresenceService.setTyping failed',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// Live set of uids currently typing in [chatId], derived from
  /// `/typing/{chatId}`. A per-entry `at` older than [_typingStaleAfter] is
  /// treated as gone even if the node is still physically present —
  /// defends against a ghost entry from a disconnect `onDisconnect`
  /// somehow missed (mirrors the spirit, not the mechanism, of the old
  /// Firestore-side staleness hedge this phase's report recommends
  /// deleting from `chat_service.dart`'s `getUserChatsWithStatus`).
  ///
  /// Not wired into any screen by this phase — `chat_detail_screen.dart` is
  /// out of scope here. Its `_buildTypingIndicator` currently reads
  /// `ChatModel.typingUsers`, sourced from the Firestore
  /// `chats/{chatId}.typingUsers` map that `chat_service.dart`'s old
  /// `setTypingStatus` used to write; once that write is removed (report
  /// item 5), that map stops updating and the indicator goes dark unless
  /// `_buildTypingIndicator` is swapped onto THIS stream in the same
  /// change — see the report's explicit callout.
  Stream<Set<String>> typingUsers(String chatId) {
    return _db.ref('typing/$chatId').onValue.map((event) {
      final raw = event.snapshot.value;
      if (raw is! Map) return <String>{};
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final result = <String>{};
      raw.forEach((key, value) {
        if (value is! Map) return;
        final at = value['at'];
        if (at is int && (nowMs - at) < _typingStaleAfter.inMilliseconds) {
          result.add(key.toString());
        }
      });
      return result;
    });
  }

  /// Writes `/private_state/{uid}/{deviceId}` — server/self-only, never
  /// exposed to other users (`database.rules.json`'s `.read: false` even
  /// for the owner). No consumer wired yet in this phase; exposed for a
  /// future screen to suppress a redundant push to a device already
  /// viewing [currentConversationId].
  Future<void> updatePrivateState({
    String? currentConversationId,
    String? currentScreen,
  }) async {
    final uid = _currentUid;
    if (uid == null) return;
    try {
      await _privateStateRef(uid).set(<String, Object?>{
        'current_conversation_id': currentConversationId,
        'current_screen': currentScreen,
      });
    } catch (e, s) {
      _log.error('PresenceService: updatePrivateState failed',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// For completeness/testability — this is a long-lived app singleton in
  /// practice and is not expected to be disposed during a normal app run.
  Future<void> dispose() async {
    _disposed = true;
    _idleTimer?.cancel();
    _stopHeartbeat();
    await _connectionSub?.cancel();
    _connectionSub = null;
  }
}
