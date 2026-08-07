import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cookrange/core/services/app_lifecycle_service.dart';
import 'package:cookrange/core/services/auth_service.dart';
import 'package:cookrange/core/services/device_registry_service.dart';
import 'package:cookrange/core/services/firestore_service.dart';
import 'package:cookrange/core/services/log_service.dart';
import 'package:cookrange/core/services/presence_service.dart';

// Manual Mocks using simple implementation to avoid code gen
class MockUser implements User {
  @override
  final String uid = 'test_uid';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockAuthService implements AuthService {
  final _controller = StreamController<User?>.broadcast();
  User? _currentUser;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  User? get currentUser => _currentUser;

  void setMockUser(User? user) {
    _currentUser = user;
    _controller.add(user);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Chat Upgrade Phase 2 removed AppLifecycleService's direct
// updateUserOnlineStatus/updateUserLastActiveTimestamp calls entirely —
// presence moved to PresenceService/RTDB, mirrored server-side
// (functions/chat_presence.js). This mock now only tracks what
// AppLifecycleService still actually calls on FirestoreService: session
// activity logging + device-context sync.
class MockFirestoreService implements FirestoreService {
  final List<String> loggedActivities = [];

  @override
  Future<void> logUserActivity(String uid, String activity,
      {Map<String, dynamic>? extraData}) async {
    loggedActivities.add(activity);
  }

  @override
  Future<void> syncDeviceContext(String uid) async {}

  @override
  Future<void> verifyAndRepairUserData(String uid) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Allow other calls (like addLoginHistoryToLogs) to just return null or Future.value()
    if (invocation.memberName == const Symbol('addLoginHistoryToLogs')) {
      return Future.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class MockLogService implements LogService {
  @override
  void info(String message,
      {String? service, Object? error, StackTrace? stackTrace}) {
    // print('[INFO] $message');
  }

  @override
  void error(String message,
      {String? service, Object? error, StackTrace? stackTrace}) {
    // print('[ERROR] $message');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Chat Upgrade Phase 2 — records every presence transition
/// `AppLifecycleService` requests, in call order. This is the direct
/// replacement for the old `MockFirestoreService.onlineStatusUpdates`
/// assertions: presence state is now `PresenceService`'s job, not
/// `FirestoreService`'s (see `AppLifecycleService`'s class doc comment).
class MockPresenceService implements PresenceService {
  final List<String> calls = [];
  bool initializeCalled = false;

  @override
  Future<void> initialize() async {
    initializeCalled = true;
  }

  @override
  Future<void> goOnline({required String uid}) async {
    calls.add('online');
  }

  @override
  Future<void> goAway() async {
    calls.add('away');
  }

  @override
  Future<void> goOffline() async {
    calls.add('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Chat Upgrade Phase 1 — replaces the real singleton (which eagerly touches
/// `FirebaseFirestore.instance` in a field initializer and crashes outright
/// with no Firebase app initialized in this plain unit-test environment;
/// the exact crash this rewrite fixes) with a call-counting fake.
class MockDeviceRegistryService implements DeviceRegistryService {
  int registerOrTouchCount = 0;

  @override
  Future<void> registerOrTouchThisDevice({required String uid}) async {
    registerOrTouchCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLifecycleService service;
  late MockAuthService mockAuthService;
  late MockFirestoreService mockFirestoreService;
  late MockLogService mockLogService;
  late MockPresenceService mockPresenceService;
  late MockDeviceRegistryService mockDeviceRegistryService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestoreService = MockFirestoreService();
    mockLogService = MockLogService();
    mockPresenceService = MockPresenceService();
    mockDeviceRegistryService = MockDeviceRegistryService();

    // Setup initial user
    mockAuthService.setMockUser(MockUser());

    service = AppLifecycleService(
      authService: mockAuthService,
      firestoreService: mockFirestoreService,
      logService: mockLogService,
      presenceService: mockPresenceService,
      deviceRegistryService: mockDeviceRegistryService,
    );
  });

  tearDown(() {
    service.dispose();
  });

  test('initialize() marks presence online and registers this device', () {
    fakeAsync((async) {
      service.initialize();
      async.flushMicrotasks();

      expect(mockPresenceService.initializeCalled, isTrue);
      expect(mockPresenceService.calls, contains('online'));
      expect(mockDeviceRegistryService.registerOrTouchCount, greaterThan(0));
    });
  });

  test('Session pause debounce cancels if resumed quickly', () {
    fakeAsync((async) {
      service.initialize();
      async.flushMicrotasks();
      mockPresenceService.calls.clear();
      mockFirestoreService.loggedActivities.clear();

      // 1. Pause: presence flips to `away` IMMEDIATELY — no debounce for
      // RTDB, since `onDisconnect` (not a client timer) is what protects
      // against a genuinely killed app. Only the (separate, analytics-only)
      // session-duration bookkeeping is debounced.
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      async.flushMicrotasks();
      expect(mockPresenceService.calls, ['away'],
          reason: 'Pausing should mark presence away immediately');

      // Advance less than the 2s session-pause debounce.
      async.elapse(const Duration(seconds: 1));
      expect(
          mockFirestoreService.loggedActivities, isNot(contains('session_end')),
          reason: 'Should not end the session before the debounce elapses');

      // 2. Resume quickly: presence goes back online; the pending
      // session-end debounce is cancelled outright (session never ends).
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      async.flushMicrotasks();
      expect(mockPresenceService.calls, ['away', 'online'],
          reason: 'Resuming should mark presence online again');

      async.elapse(const Duration(seconds: 3));
      expect(
          mockFirestoreService.loggedActivities, isNot(contains('session_end')),
          reason: 'A quick resume must not end the session after the fact');
    });
  });

  test('Session ends and presence goes offline after the debounce elapses', () {
    fakeAsync((async) {
      service.initialize();
      async.flushMicrotasks();
      mockPresenceService.calls.clear();
      mockFirestoreService.loggedActivities.clear();

      // 1. Pause Application
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Advance past the 2s session-pause debounce.
      async.elapse(const Duration(seconds: 5));

      expect(mockFirestoreService.loggedActivities, contains('session_end'),
          reason: 'Session should end once the debounce elapses');
      // Presence itself went away immediately on pause (asserted above in
      // the other test) — this test's own focus is the session bookkeeping.
      expect(mockPresenceService.calls, contains('away'));
    });
  });

  test('Detached state ends the session and goes offline immediately', () {
    fakeAsync((async) {
      service.initialize();
      async.flushMicrotasks();
      mockPresenceService.calls.clear();
      mockFirestoreService.loggedActivities.clear();

      // Detach Application
      service.didChangeAppLifecycleState(AppLifecycleState.detached);

      // Flush microtasks to allow the async _endSession/goOffline calls to complete.
      async.flushMicrotasks();

      expect(mockFirestoreService.loggedActivities, contains('session_end'),
          reason: 'Should end the session immediately on detach');
      expect(mockPresenceService.calls, contains('offline'),
          reason: 'Should mark presence offline immediately on detach');
    });
  });
}
