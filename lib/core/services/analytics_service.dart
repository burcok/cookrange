import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:hive/hive.dart';
import 'dart:collection';
import 'dart:math';
import 'log_service.dart';

class AnalyticsService {
  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;
  final LogService _log = LogService();
  final String _serviceName = 'AnalyticsService';
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
  late Box<Map> _analyticsBox;

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
      _log.info('Initializing AnalyticsService', service: _serviceName);

      // Check if box is already open and use it, otherwise open it
      if (Hive.isBoxOpen('analytics_cache')) {
        _analyticsBox = Hive.box<Map>('analytics_cache');
        _log.info('Using existing analytics_cache box', service: _serviceName);
      } else {
        try {
          _analyticsBox = await Hive.openBox<Map>('analytics_cache');
          _log.info('Opened new analytics_cache box', service: _serviceName);
        } catch (e) {
          // If box is already open by another instance, get the existing one
          if (Hive.isBoxOpen('analytics_cache')) {
            _analyticsBox = Hive.box<Map>('analytics_cache');
            _log.info('Using existing analytics_cache box after error',
                service: _serviceName);
          } else {
            rethrow;
          }
        }
      }

      // PackageInfo'yu ana thread'de al
      _packageInfo = await PackageInfo.fromPlatform();
      _log.info('Package info loaded', service: _serviceName);

      // Enable analytics collection in background
      if (kReleaseMode) {
        unawaited(_analytics.setAnalyticsCollectionEnabled(true));
        _log.info('Firebase Analytics collection enabled for release mode.',
            service: _serviceName);
      } else {
        unawaited(_analytics.setAnalyticsCollectionEnabled(false));
        _log.info('Firebase Analytics collection disabled for debug mode.',
            service: _serviceName);
      }
      unawaited(
          _analytics.setSessionTimeoutDuration(const Duration(minutes: 30)));
      unawaited(_analytics.resetAnalyticsData());

      // Set user properties and default parameters in parallel
      await Future.wait<void>([
        _setUserProperties(),
        _setDefaultEventParameters(),
      ]);
      _log.info('User properties and default parameters set',
          service: _serviceName);

      // Log app open event in background
      unawaited(_logAppOpenWithRetry());

      // Bekleyen eventleri işle
      unawaited(_processPendingEvents());

      // Batch işleme zamanlayıcısını başlat
      _startBatchTimer();
      _startProcessTimer();

      _isInitialized = true;
      _initCompleter?.complete();
      _log.info('Initialization completed successfully', service: _serviceName);
    } catch (e, stack) {
      _log.error('Error during initialization',
          service: _serviceName, error: e, stackTrace: stack);
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
      _log.error('Error processing pending events',
          service: _serviceName, error: e);
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
        _log.error('Error processing event', service: _serviceName, error: e);
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
      _log.error('Error processing batch', service: _serviceName, error: e);
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
        for (final event in List.from(batch)) {
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
      await _analyticsBox.put(event.timestamp, event.toMap());
      _log.info('Event cached with key: ${event.timestamp}',
          service: _serviceName);
    } catch (e) {
      _log.error('Error caching event', service: _serviceName, error: e);
    }
  }

  Future<void> _cacheBatch(List<AnalyticsEvent> batch) async {
    try {
      for (final event in List.from(batch)) {
        await _cacheEvent(event);
      }
      _log.info('${batch.length} events cached.', service: _serviceName);
    } catch (e) {
      _log.error('Error caching batch', service: _serviceName, error: e);
    }
  }

  Future<void> _removeFromCache(AnalyticsEvent event) async {
    try {
      await _analyticsBox.delete(event.timestamp);
      _log.info('Event with key: ${event.timestamp} removed from cache',
          service: _serviceName);
    } catch (e) {
      _log.error('Error removing from cache', service: _serviceName, error: e);
    }
  }

  Future<void> _clearBatchCache(List<AnalyticsEvent> batch) async {
    try {
      for (final event in List.from(batch)) {
        await _removeFromCache(event);
      }
    } catch (e) {
      _log.error('Error clearing batch cache', service: _serviceName, error: e);
    }
  }

  Future<void> _logAppOpenWithRetry() async {
    try {
      await _analytics.logAppOpen();
    } catch (e) {
      _log.error('Error logging app open', service: _serviceName, error: e);
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
      _log.error('Error setting user properties',
          service: _serviceName, error: e);
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
      _log.error('Error getting device info', service: _serviceName, error: e);
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
      _log.error('Error setting default parameters',
          service: _serviceName, error: e);
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
        _log.info('Logging event: $name', service: _serviceName);
        if (parameters != null) {
          _log.info('Event parameters: $parameters', service: _serviceName);
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
        _log.info('Event added to batch', service: _serviceName);
      }
    } catch (e) {
      _log.error('Error logging event', service: _serviceName, error: e);
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
        _log.info('Logging screen view: $screenName', service: _serviceName);
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
        _log.info('Screen view logged successfully', service: _serviceName);
      }
    } catch (e) {
      _log.error('Error logging screen view', service: _serviceName, error: e);
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
      _log.error('Error logging user action', service: _serviceName, error: e);
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
        if (errorCode != null) 'error_code': errorCode,
        'timestamp': DateTime.now().toIso8601String(),
        ...?parameters,
      };
      // Null value'ları filtrele
      final filteredParams = <String, Object>{};
      eventParams.forEach((key, value) {
        filteredParams[key] = value;
      });
      await logEvent(
        name: _errorEvent,
        parameters: filteredParams,
      );
    } catch (e) {
      _log.error('Error logging error event', service: _serviceName, error: e);
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
      _log.error('Error logging performance event',
          service: _serviceName, error: e);
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
      _log.error('Error logging feature usage',
          service: _serviceName, error: e);
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
      _log.error('Error logging login', service: _serviceName, error: e);
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
      _log.error('Error logging sign up', service: _serviceName, error: e);
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
      _log.error('Error logging search', service: _serviceName, error: e);
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
      _log.error('Error logging select content',
          service: _serviceName, error: e);
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
      _log.error('Error logging share', service: _serviceName, error: e);
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
      _log.error('Error logging lifecycle state',
          service: _serviceName, error: e);
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
      _log.info("Setting user ID: $userId", service: _serviceName);
      await _analytics.setUserId(id: userId);
      await logEvent(
        name: 'user_identification',
        parameters: {
          'user_id': userId ?? '',
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      _log.info("User ID set successfully", service: _serviceName);
    } catch (e, stackTrace) {
      _log.error("Error setting user ID",
          service: _serviceName, error: e, stackTrace: stackTrace);
      // Hata durumunda işlemi tekrar deneme
      try {
        await _analytics.setUserId(id: userId);
      } catch (retryError) {
        _log.error("Error during retry of setting user ID",
            service: _serviceName, error: retryError);
      }
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
      _log.error('Error updating user properties',
          service: _serviceName, error: e);
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
      _log.error('Error logging session start',
          service: _serviceName, error: e);
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
      _log.error('Error logging session end', service: _serviceName, error: e);
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
      _log.error('Error logging network status',
          service: _serviceName, error: e);
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
      _log.error('Error logging connection quality',
          service: _serviceName, error: e);
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
      _log.error('Error logging crash', service: _serviceName, error: e);
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
      _log.error('Error logging memory usage', service: _serviceName, error: e);
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
      _log.error('Error logging user flow', service: _serviceName, error: e);
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
      _log.error('Error logging screen time', service: _serviceName, error: e);
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
      _log.error('Error logging user interaction',
          service: _serviceName, error: e);
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
      _log.error('Error logging social share', service: _serviceName, error: e);
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
      _log.error('Error logging social like', service: _serviceName, error: e);
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
      _log.error('Error logging content view', service: _serviceName, error: e);
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
      _log.error('Error logging content progress',
          service: _serviceName, error: e);
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
