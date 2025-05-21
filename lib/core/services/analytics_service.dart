import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import 'dart:collection';
import 'dart:math';

class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  late final PackageInfo _packageInfo;
  bool _isInitialized = false;
  bool _isInitializing = false;
  Completer<void>? _initCompleter;
  String? _currentSessionId;

  // Queue ve Batch işlemleri için
  final Queue<AnalyticsEvent> _eventQueue = Queue();
  final List<AnalyticsEvent> _batch = [];
  Timer? _batchTimer;
  Timer? _processTimer;
  static const int _batchSize = 10;
  static const Duration _batchTimeout = Duration(minutes: 1);
  static const Duration _processInterval = Duration(seconds: 30);

  // Hive box için
  late Box<Map<dynamic, Object>> _analyticsBox;

  // Singleton pattern
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // Analytics event names
  static const String _screenViewEvent = 'screen_view';
  static const String _userActionEvent = 'user_action';
  static const String _errorEvent = 'error';
  static const String _performanceEvent = 'performance';
  static const String _featureUsageEvent = 'feature_usage';

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) {
      return _initCompleter?.future;
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      print('AnalyticsService: Starting initialization...');

      // Hive box'ı başlat
      if (Hive.isBoxOpen('analytics_cache')) {
        await Hive.close();
      }
      _analyticsBox =
          await Hive.openBox<Map<dynamic, Object>>('analytics_cache');

      // PackageInfo'yu ana thread'de al
      _packageInfo = await PackageInfo.fromPlatform();
      print('AnalyticsService: Package info loaded');

      // Enable analytics collection in background
      unawaited(_analytics.setAnalyticsCollectionEnabled(true));
      unawaited(
          _analytics.setSessionTimeoutDuration(const Duration(minutes: 30)));
      unawaited(_analytics.resetAnalyticsData());

      // Set user properties and default parameters in parallel
      await Future.wait<void>([
        _setUserProperties(),
        _setDefaultEventParameters(),
      ]);
      print('AnalyticsService: User properties and default parameters set');

      // Log app open event in background
      unawaited(_logAppOpenWithRetry());

      // Bekleyen eventleri işle
      unawaited(_processPendingEvents());

      // Batch işleme zamanlayıcısını başlat
      _startBatchTimer();
      _startProcessTimer();

      _isInitialized = true;
      _initCompleter?.complete();
      print('AnalyticsService: Initialization completed successfully');
    } catch (e, stack) {
      print('AnalyticsService: Error during initialization: $e');
      print('AnalyticsService: Stack trace: $stack');
      _isInitialized = false;
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  void _startBatchTimer() {
    _batchTimer?.cancel();
    _batchTimer = Timer.periodic(_batchTimeout, (_) {
      if (_batch.isNotEmpty) {
        unawaited(_processBatch());
      }
    });
  }

  void _startProcessTimer() {
    _processTimer?.cancel();
    _processTimer = Timer.periodic(_processInterval, (_) {
      unawaited(_processQueue());
    });
  }

  Future<void> _processPendingEvents() async {
    try {
      // Önbellekteki eventleri yükle
      final cachedEvents = _analyticsBox.values.toList();
      for (final event in cachedEvents) {
        _eventQueue.add(AnalyticsEvent.fromMap(event));
      }

      // Kuyruktaki eventleri işle
      await _processQueue();
    } catch (e) {
      print('AnalyticsService: Error processing pending events: $e');
    }
  }

  Future<void> _processQueue() async {
    while (_eventQueue.isNotEmpty) {
      final event = _eventQueue.first;
      try {
        await _sendEventWithRetry(event);
        _eventQueue.removeFirst();
        // Önbellekten sil
        await _removeFromCache(event);
      } catch (e) {
        print('AnalyticsService: Error processing event: $e');
        break;
      }
    }
  }

  Future<void> _processBatch() async {
    if (_batch.isEmpty) return;

    try {
      // Batch'i önbelleğe al
      await _cacheBatch(_batch);

      // Toplu gönderim dene
      await _sendBatchWithRetry(_batch);

      // Başarılı gönderim sonrası önbellekten sil
      await _clearBatchCache(_batch);

      _batch.clear();
    } catch (e) {
      print('AnalyticsService: Error processing batch: $e');
    }
  }

  Future<void> _sendEventWithRetry(AnalyticsEvent event,
      {int maxRetries = 3}) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await _analytics.logEvent(
          name: event.name,
          parameters: event.parameters,
        );
        return;
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          // Son deneme başarısız oldu, kuyruğa ekle
          _eventQueue.add(event);
          await _cacheEvent(event);
          break;
        }
        // Exponential backoff ile bekle
        await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
      }
    }
  }

  Future<void> _sendBatchWithRetry(List<AnalyticsEvent> batch,
      {int maxRetries = 3}) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        for (final event in batch) {
          await _analytics.logEvent(
            name: event.name,
            parameters: event.parameters,
          );
        }
        return;
      } catch (e) {
        retryCount++;
        if (retryCount == maxRetries) {
          // Son deneme başarısız oldu, kuyruğa ekle
          _eventQueue.addAll(batch);
          await _cacheBatch(batch);
          break;
        }
        await Future.delayed(Duration(seconds: pow(2, retryCount).toInt()));
      }
    }
  }

  Future<void> _cacheEvent(AnalyticsEvent event) async {
    try {
      final eventMap = Map<dynamic, Object>.from(event.toMap());
      await _analyticsBox.add(eventMap);
    } catch (e) {
      print('AnalyticsService: Error caching event: $e');
    }
  }

  Future<void> _cacheBatch(List<AnalyticsEvent> batch) async {
    try {
      for (final event in batch) {
        final eventMap = Map<dynamic, Object>.from(event.toMap());
        await _analyticsBox.add(eventMap);
      }
    } catch (e) {
      print('AnalyticsService: Error caching batch: $e');
    }
  }

  Future<void> _removeFromCache(AnalyticsEvent event) async {
    try {
      final keys = _analyticsBox.keys.where((key) {
        final value = _analyticsBox.get(key);
        return value != null &&
            value['name'] == event.name &&
            value['timestamp'] == event.timestamp;
      });

      if (keys.isNotEmpty) {
        await _analyticsBox.delete(keys.first);
      }
    } catch (e) {
      print('AnalyticsService: Error removing from cache: $e');
    }
  }

  Future<void> _clearBatchCache(List<AnalyticsEvent> batch) async {
    try {
      for (final event in batch) {
        await _removeFromCache(event);
      }
    } catch (e) {
      print('AnalyticsService: Error clearing batch cache: $e');
    }
  }

  Future<void> _logAppOpenWithRetry() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      print('AnalyticsService: Error logging app open: $e');
      // App open event'ini kuyruğa ekle
      _eventQueue.add(AnalyticsEvent(
        name: 'app_open',
        parameters: {'timestamp': DateTime.now().toIso8601String()},
      ));
    }
  }

  Future<void> _setUserProperties() async {
    try {
      final deviceData = await _getDeviceInfo();

      final userProperties = {
        'app_version': _packageInfo.version,
        'build_number': _packageInfo.buildNumber,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion.split(' ').first,
        'device_info': deviceData,
        'app_package_name': _packageInfo.packageName,
        'app_installer_store': _packageInfo.installerStore ?? 'unknown',
        'debug_mode': kDebugMode.toString(),
        'build_mode': kReleaseMode ? 'release' : 'debug',
        'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
      };

      // Set user properties in parallel
      await Future.wait<void>(
        userProperties.entries.map((entry) => _analytics.setUserProperty(
              name: entry.key,
              value: entry.value.toString(),
            )),
      );
    } catch (e) {
      print('AnalyticsService: Error setting user properties: $e');
      rethrow;
    }
  }

  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.brand} ${androidInfo.model} (${androidInfo.version.release})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return '${iosInfo.model} (${iosInfo.systemVersion})';
      }
      return 'Unknown Platform';
    } catch (e) {
      print('AnalyticsService: Error getting device info: $e');
      return 'Error getting device info';
    }
  }

  Future<void> _setDefaultEventParameters() async {
    try {
      final deviceData = await _getDeviceInfo();
      await _analytics.setDefaultEventParameters({
        'app_name': 'Cookrange',
        'environment': kReleaseMode ? 'production' : 'development',
        'device_info': deviceData,
        'app_version': _packageInfo.version,
        'build_number': _packageInfo.buildNumber,
        'platform': Platform.operatingSystem,
        'debug_mode': kDebugMode.toString(),
      });
    } catch (e) {
      print('AnalyticsService: Error setting default parameters: $e');
      rethrow;
    }
  }

  // Enhanced event logging methods with lazy initialization and caching
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (kDebugMode) {
        print('AnalyticsService: Logging event: $name');
        if (parameters != null) {
          print('AnalyticsService: Event parameters: $parameters');
        }
      }

      final event = AnalyticsEvent(
        name: name,
        parameters: {
          ...?parameters,
          'session_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'build_mode': kReleaseMode ? 'release' : 'debug',
          'debug_mode': kDebugMode.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Batch'e ekle
      _batch.add(event);

      // Batch boyutu dolduğunda işle
      if (_batch.length >= _batchSize) {
        unawaited(_processBatch());
      }

      if (kDebugMode) {
        print('AnalyticsService: Event added to batch');
      }
    } catch (e) {
      print('AnalyticsService: Error logging event: $e');
      // Hata durumunda direkt kuyruğa ekle
      _eventQueue.add(AnalyticsEvent(
        name: name,
        parameters: parameters ?? {},
      ));
    }
  }

  // Screen view tracking with enhanced parameters and lazy initialization
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? additionalParams,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (kDebugMode) {
        print('AnalyticsService: Logging screen view: $screenName');
      }

      final parameters = {
        'screen_name': screenName,
        'screen_class': screenClass ?? screenName,
        'timestamp': DateTime.now().toIso8601String(),
        ...?additionalParams,
      };

      // Log screen view in background
      unawaited(_analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      ));

      // Log additional screen view event with custom parameters in background
      unawaited(logEvent(
        name: _screenViewEvent,
        parameters: parameters,
      ));

      if (kDebugMode) {
        print('AnalyticsService: Screen view logged successfully');
      }
    } catch (e) {
      print('AnalyticsService: Error logging screen view: $e');
    }
  }

  // User action tracking
  Future<void> logUserAction({
    required String action,
    required String category,
    Map<String, Object>? parameters,
  }) async {
    try {
      final eventParams = {
        'action': action,
        'category': category,
        'timestamp': DateTime.now().toIso8601String(),
        ...?parameters,
      };

      await logEvent(
        name: _userActionEvent,
        parameters: eventParams,
      );
    } catch (e) {
      print('AnalyticsService: Error logging user action: $e');
      rethrow;
    }
  }

  // Error tracking
  Future<void> logError({
    required String errorName,
    required String errorDescription,
    String? errorCode,
    Map<String, Object>? parameters,
  }) async {
    try {
      final eventParams = {
        'error_name': errorName,
        'error_description': errorDescription,
        'error_code': errorCode,
        'timestamp': DateTime.now().toIso8601String(),
        ...?parameters,
      };

      await logEvent(
        name: _errorEvent,
        parameters: Map<String, Object>.from(eventParams),
      );
    } catch (e) {
      print('AnalyticsService: Error logging error event: $e');
      rethrow;
    }
  }

  // Performance tracking
  Future<void> logPerformance({
    required String metricName,
    required num value,
    String? unit,
    Map<String, Object>? parameters,
  }) async {
    try {
      final eventParams = {
        'metric_name': metricName,
        'value': value,
        'unit': unit,
        'timestamp': DateTime.now().toIso8601String(),
        ...?parameters,
      };

      await logEvent(
        name: _performanceEvent,
        parameters: Map<String, Object>.from(eventParams),
      );
    } catch (e) {
      print('AnalyticsService: Error logging performance event: $e');
      rethrow;
    }
  }

  // Feature usage tracking
  Future<void> logFeatureUsage({
    required String featureName,
    required String action,
    Map<String, Object>? parameters,
  }) async {
    try {
      final eventParams = {
        'feature_name': featureName,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        ...?parameters,
      };

      await logEvent(
        name: _featureUsageEvent,
        parameters: eventParams,
      );
    } catch (e) {
      print('AnalyticsService: Error logging feature usage: $e');
      rethrow;
    }
  }

  // Predefined event tracking methods
  Future<void> logLogin({String? method}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      await logUserAction(
        action: 'login',
        category: 'authentication',
        parameters: {'method': method ?? ''},
      );
    } catch (e) {
      print('AnalyticsService: Error logging login: $e');
      rethrow;
    }
  }

  Future<void> logSignUp({String? method}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method ?? '');
      await logUserAction(
        action: 'signup',
        category: 'authentication',
        parameters: {'method': method ?? ''},
      );
    } catch (e) {
      print('AnalyticsService: Error logging sign up: $e');
      rethrow;
    }
  }

  Future<void> logSearch({required String searchTerm}) async {
    try {
      await _analytics.logSearch(searchTerm: searchTerm);
      await logUserAction(
        action: 'search',
        category: 'content',
        parameters: {'search_term': searchTerm},
      );
    } catch (e) {
      print('AnalyticsService: Error logging search: $e');
      rethrow;
    }
  }

  Future<void> logSelectContent({
    required String contentType,
    required String itemId,
  }) async {
    try {
      await _analytics.logSelectContent(
        contentType: contentType,
        itemId: itemId,
      );
      await logUserAction(
        action: 'select_content',
        category: 'content',
        parameters: {
          'content_type': contentType,
          'item_id': itemId,
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging select content: $e');
      rethrow;
    }
  }

  Future<void> logShare({
    required String contentType,
    required String itemId,
    String? method,
  }) async {
    try {
      await _analytics.logShare(
        contentType: contentType,
        itemId: itemId,
        method: method ?? '',
      );
      await logUserAction(
        action: 'share',
        category: 'content',
        parameters: {
          'content_type': contentType,
          'item_id': itemId,
          'method': method ?? '',
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging share: $e');
      rethrow;
    }
  }

  // Lifecycle Events
  Future<void> logAppLifecycleState(String state) async {
    try {
      await logEvent(
        name: 'app_lifecycle',
        parameters: {
          'state': state,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging lifecycle state: $e');
    }
  }

  Future<void> logAppBackground() async {
    await logAppLifecycleState('background');
  }

  Future<void> logAppForeground() async {
    await logAppLifecycleState('foreground');
  }

  Future<void> logAppTerminated() async {
    await logAppLifecycleState('terminated');
  }

  // User Session Management
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      await logEvent(
        name: 'user_identification',
        parameters: {
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error setting user ID: $e');
    }
  }

  Future<void> updateUserProperties(Map<String, String> properties) async {
    try {
      await Future.wait(
        properties.entries.map(
          (entry) => _analytics.setUserProperty(
            name: entry.key,
            value: entry.value,
          ),
        ),
      );
      await logEvent(
        name: 'user_properties_updated',
        parameters: {
          'properties': properties,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error updating user properties: $e');
    }
  }

  Future<void> logSessionStart() async {
    try {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await _analytics.setUserProperty(
        name: 'session_id',
        value: _currentSessionId!,
      );
      await logEvent(
        name: 'session_start',
        parameters: {
          'session_id': _currentSessionId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging session start: $e');
    }
  }

  Future<void> logSessionEnd() async {
    try {
      if (_currentSessionId != null) {
        await logEvent(
          name: 'session_end',
          parameters: {
            'session_id': _currentSessionId ?? '',
            'duration': DateTime.now().millisecondsSinceEpoch -
                int.parse(_currentSessionId!),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
        _currentSessionId = null;
      }
    } catch (e) {
      print('AnalyticsService: Error logging session end: $e');
    }
  }

  // Network Status Tracking
  Future<void> logNetworkStatus({
    required String status,
    required String type,
    int? speed,
  }) async {
    try {
      await logEvent(
        name: 'network_status',
        parameters: {
          'status': status,
          'type': type,
          if (speed != null) 'speed': speed,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging network status: $e');
    }
  }

  Future<void> logConnectionQuality({
    required String quality,
    required int latency,
  }) async {
    try {
      await logEvent(
        name: 'connection_quality',
        parameters: {
          'quality': quality,
          'latency': latency,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging connection quality: $e');
    }
  }

  // Enhanced Error Tracking
  Future<void> logCrash({
    required String errorType,
    required String errorMessage,
    String? stackTrace,
    Map<String, Object>? additionalData,
  }) async {
    try {
      await logEvent(
        name: 'app_crash',
        parameters: {
          'error_type': errorType,
          'error_message': errorMessage,
          if (stackTrace != null) 'stack_trace': stackTrace,
          ...?additionalData,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging crash: $e');
    }
  }

  Future<void> logMemoryUsage({
    required int usedMemory,
    required int totalMemory,
    required String memoryUnit,
  }) async {
    try {
      await logEvent(
        name: 'memory_usage',
        parameters: {
          'used_memory': usedMemory,
          'total_memory': totalMemory,
          'memory_unit': memoryUnit,
          'usage_percentage':
              (usedMemory / totalMemory * 100).toStringAsFixed(2),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging memory usage: $e');
    }
  }

  // User Behavior Analysis
  Future<void> logUserFlow({
    required String flowName,
    required String step,
    required String action,
    Map<String, Object>? parameters,
  }) async {
    try {
      await logEvent(
        name: 'user_flow',
        parameters: {
          'flow_name': flowName,
          'step': step,
          'action': action,
          ...?parameters,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging user flow: $e');
    }
  }

  Future<void> logScreenTime({
    required String screenName,
    required Duration duration,
  }) async {
    try {
      await logEvent(
        name: 'screen_time',
        parameters: {
          'screen_name': screenName,
          'duration_seconds': duration.inSeconds,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging screen time: $e');
    }
  }

  Future<void> logUserInteraction({
    required String interactionType,
    required String target,
    Duration? duration,
    Map<String, Object>? parameters,
  }) async {
    try {
      await logEvent(
        name: 'user_interaction',
        parameters: {
          'interaction_type': interactionType,
          'target': target,
          if (duration != null) 'duration_seconds': duration.inSeconds,
          ...?parameters,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging user interaction: $e');
    }
  }

  // Social Media Events
  Future<void> logSocialShare({
    required String platform,
    required String contentType,
    required String contentId,
    Map<String, Object>? parameters,
  }) async {
    try {
      await logEvent(
        name: 'social_share',
        parameters: {
          'platform': platform,
          'content_type': contentType,
          'content_id': contentId,
          ...?parameters,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging social share: $e');
    }
  }

  Future<void> logSocialLike({
    required String platform,
    required String contentType,
    required String contentId,
    Map<String, Object>? parameters,
  }) async {
    try {
      await logEvent(
        name: 'social_like',
        parameters: {
          'platform': platform,
          'content_type': contentType,
          'content_id': contentId,
          ...?parameters,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging social like: $e');
    }
  }

  // Content Consumption Events
  Future<void> logContentView({
    required String contentType,
    required String contentId,
    Duration? duration,
    Map<String, Object>? parameters,
  }) async {
    try {
      await logEvent(
        name: 'content_view',
        parameters: {
          'content_type': contentType,
          'content_id': contentId,
          if (duration != null) 'duration_seconds': duration.inSeconds,
          ...?parameters,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging content view: $e');
    }
  }

  Future<void> logContentProgress({
    required String contentType,
    required String contentId,
    required double progress,
    Map<String, Object>? parameters,
  }) async {
    try {
      await logEvent(
        name: 'content_progress',
        parameters: {
          'content_type': contentType,
          'content_id': contentId,
          'progress_percentage': progress,
          ...?parameters,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      print('AnalyticsService: Error logging content progress: $e');
    }
  }
}

class AnalyticsEvent {
  final String name;
  final Map<String, Object> parameters;
  final String timestamp;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
  }) : timestamp = DateTime.now().toIso8601String();

  Map<String, Object> toMap() {
    return {
      'name': name,
      'parameters': parameters,
      'timestamp': timestamp,
    };
  }

  factory AnalyticsEvent.fromMap(Map<dynamic, dynamic> map) {
    return AnalyticsEvent(
      name: map['name'] as String,
      parameters: Map<String, Object>.from(
        (map['parameters'] as Map).map(
          (key, value) => MapEntry(key.toString(), value as Object),
        ),
      ),
    );
  }
}
