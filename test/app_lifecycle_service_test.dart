import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cookrange/core/services/app_lifecycle_service.dart';
import 'package:cookrange/core/services/auth_service.dart';
import 'package:cookrange/core/services/firestore_service.dart';
import 'package:cookrange/core/services/log_service.dart';

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

class MockFirestoreService implements FirestoreService {
  int updateLastActiveCount = 0;
  List<bool> onlineStatusUpdates = [];

  @override
  Future<void> updateUserLastActiveTimestamp(String uid) async {
    updateLastActiveCount++;
  }

  @override
  Future<void> updateUserOnlineStatus(String uid, bool online) async {
    onlineStatusUpdates.add(online);
  }

  @override
  Future<void> logUserActivity(String uid, String activity,
      {Map<String, dynamic>? extraData}) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    // Allow other calls (like addLoginHistoryToLogs) to just return null or Future.value()
    if (invocation.memberName == Symbol('addLoginHistoryToLogs')) {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLifecycleService service;
  late MockAuthService mockAuthService;
  late MockFirestoreService mockFirestoreService;
  late MockLogService mockLogService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockFirestoreService = MockFirestoreService();
    mockLogService = MockLogService();

    // Setup initial user
    mockAuthService.setMockUser(MockUser());

    service = AppLifecycleService(
      authService: mockAuthService,
      firestoreService: mockFirestoreService,
      logService: mockLogService,
    );
  });

  tearDown(() {
    service.dispose();
  });

  test('Session pause debounce cancels if resumed quickly', () {
    fakeAsync((async) {
      service.initialize();

      // Initial state: Online
      mockFirestoreService.onlineStatusUpdates.clear(); // Reset

      // 1. Pause Application
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Advance time by 2 seconds (less than 4s debounce)
      async.elapse(const Duration(seconds: 2));

      // Verify nothing happened yet (no session end logic that updates last_active)
      // Note: we can't easily verify internal session logic without side effects
      // But we know 'last_active_at' is updated ONLY on session end or periodic throttle.
      // Reset call count to verify no immediate call
      expect(mockFirestoreService.updateLastActiveCount, 0,
          reason: 'Should not update last active immediately on pause');

      // 2. Resume Application quickly
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Advance time past the original debounce
      async.elapse(const Duration(seconds: 3));

      // Verify session did NOT end (so no updateLastActive from endSession)
      // However, on RESUME, we might update lastActive if throttled.
      // But critical check: 'onlineStatus' should NOT have been set to false.
      expect(mockFirestoreService.onlineStatusUpdates, isEmpty,
          reason: 'Should not set offline if resumed quickly');
    });
  });

  test('Session ends and updates last active after debounce', () {
    fakeAsync((async) {
      service.initialize();
      mockFirestoreService.updateLastActiveCount = 0; // Reset

      // 1. Pause Application
      service.didChangeAppLifecycleState(AppLifecycleState.paused);

      // Advance time by 5 seconds (more than 4s debounce)
      async.elapse(const Duration(seconds: 5));

      // Verify updateLastActive was called (session ended)
      expect(mockFirestoreService.updateLastActiveCount, greaterThan(0),
          reason: 'Should update last active after debounce');

      // Advance time by 2 minutes (offline debounce)
      async.elapse(const Duration(minutes: 2));

      // Verify offline status set
      expect(mockFirestoreService.onlineStatusUpdates, contains(false),
          reason: 'Should set offline after extended pause');
    });
  });

  test('Detached state updates immediately', () {
    fakeAsync((async) {
      service.initialize();
      mockFirestoreService.updateLastActiveCount = 0;
      mockFirestoreService.onlineStatusUpdates.clear();

      // 1. Detach Application
      service.didChangeAppLifecycleState(AppLifecycleState.detached);

      // Flush microtasks to allow async _endSession to complete
      async.flushMicrotasks();

      // Verify immediate update
      expect(mockFirestoreService.updateLastActiveCount, greaterThan(0),
          reason: 'Should update last active immediately on detached');
      expect(mockFirestoreService.onlineStatusUpdates, contains(false),
          reason: 'Should set offline immediately on detached');
    });
  });
}
