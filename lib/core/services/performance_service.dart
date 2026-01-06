import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:isolate';

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Service to manage performance optimizations and async operations
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Map<String, Timer> _timers = {};
  final Map<String, Completer> _completers = {};

  bool _isLowEndDevice = false;
  bool _isInitialized = false;

  /// Check if the device is considered low-end
  bool get isLowEndDevice => _isLowEndDevice;

  /// Initialize performance service and detect device capabilities
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Simple heuristic: < 4GB RAM or older SDK might be "low end" for heavy blurs
        // Note: totalMemory is in bytes. 4GB = 4 * 1024 * 1024 * 1024 ≈ 4.29e9
        // Many entry level phones have 4GB now, so maybe < 3GB is safe cutoff.
        // However, androidInfo.totalMemory is available since API 16.
        // Let's be conservative: Single core or very low RAM.
        // Realistically, without extensive testing, we can default to false usually,
        // or check if it's a known slow model.
        // For now, let's look at SDK version or processor count if reliable.
        // Actually, just assumed false for high-end, but we want to be safe.
        // Let's check physical memory if available (API 31+ for accurate, but totalMemory exists).

        // safe check for totalMemory presence (it is a standard field in package)
        if (androidInfo.version.sdkInt <= 28) {
          // Android 9 or lower -> Low End strategy
          _isLowEndDevice = true;
        }
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // iPhone 8 or older?
        // utsname.machine e.g. "iPhone10,1"
        // For simplicity, older iOS versions might imply older hardware.
        // Let's assume mostly high end for iOS unless very old.
        _isLowEndDevice = !iosInfo
            .isPhysicalDevice; // Simulator might be slow? actually unrelated.
        // Keeping iOS as high-end by default as optimization is usually better.
      }
    } catch (e) {
      debugPrint('Error detecting device performance: $e');
      _isLowEndDevice = true; // Fallback to safe mode on error
    } finally {
      _isInitialized = true;
      debugPrint('Performance Mode: LowEnd=$_isLowEndDevice');
    }
  }

  /// Helper to get appropriate blur amount (0 for low end)
  double get sigmaBlur => _isLowEndDevice ? 0.0 : 16.0;

  /// Helper to get appropriate opacity for glass
  double get glassOpacity => _isLowEndDevice ? 0.95 : 0.8;

  /// Execute operations in parallel with proper error handling
  static Future<List<T?>> executeInParallel<T>(
    List<Future<T> Function()> operations, {
    bool eagerError = false,
    Duration? timeout,
  }) async {
    try {
      final futures = operations.map((op) => op()).toList();

      if (timeout != null) {
        return await Future.wait(
          futures,
          eagerError: eagerError,
        ).timeout(timeout);
      } else {
        return await Future.wait(
          futures,
          eagerError: eagerError,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Parallel execution error: $e');
      }
      rethrow;
    }
  }

  /// Execute operations with retry mechanism
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(Object)? shouldRetry,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;

        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }

        if (attempts >= maxRetries) {
          rethrow;
        }

        await Future.delayed(delay * attempts);
      }
    }

    throw Exception('Max retries exceeded');
  }

  /// Debounce function calls
  void debounce(String key, VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 300)}) {
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, callback);
  }

  /// Throttle function calls
  void throttle(String key, VoidCallback callback,
      {Duration delay = const Duration(milliseconds: 100)}) {
    if (!_timers.containsKey(key)) {
      _timers[key] = Timer(delay, () {
        callback();
        _timers.remove(key);
      });
    }
  }

  /// Create a singleton operation that prevents multiple simultaneous executions
  Future<T> singletonOperation<T>(
      String key, Future<T> Function() operation) async {
    if (_completers.containsKey(key)) {
      return await _completers[key]!.future as T;
    }

    final completer = Completer<T>();
    _completers[key] = completer;

    try {
      final result = await operation();
      completer.complete(result);
      return result;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _completers.remove(key);
    }
  }

  /// Execute operation in background isolate
  static Future<T> executeInIsolate<T, P>(
    T Function(P) computation,
    P parameter, {
    String? debugName,
  }) async {
    try {
      return await Isolate.run(() => computation(parameter));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Isolate execution error: $e');
      }
      rethrow;
    }
  }

  /// Optimize list operations
  static List<T> optimizeList<T>(
    List<T> list, {
    int? maxLength,
    bool removeDuplicates = false,
  }) {
    var optimizedList = List<T>.from(list);

    if (maxLength != null && optimizedList.length > maxLength) {
      optimizedList = optimizedList.take(maxLength).toList();
    }

    if (removeDuplicates) {
      optimizedList = optimizedList.toSet().toList();
    }

    return optimizedList;
  }

  /// Create optimized stream controller
  static StreamController<T> createOptimizedStreamController<T>({
    bool sync = false,
    VoidCallback? onListen,
    VoidCallback? onCancel,
  }) {
    return StreamController<T>(
      sync: sync,
      onListen: onListen,
      onCancel: onCancel,
    );
  }

  /// Measure execution time
  static Future<T> measureExecutionTime<T>(
    Future<T> Function() operation, {
    String? operationName,
    void Function(Duration)? onComplete,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final result = await operation();
      stopwatch.stop();

      if (kDebugMode && operationName != null) {
        debugPrint('$operationName took ${stopwatch.elapsedMilliseconds}ms');
      }

      onComplete?.call(stopwatch.elapsed);
      return result;
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }

  /// Create optimized FutureBuilder
  static Widget createOptimizedFutureBuilder<T>({
    required Future<T> future,
    required Widget Function(BuildContext, T) builder,
    Widget? loading,
    Widget Function(BuildContext, Object)? error,
    T? initialData,
  }) {
    return FutureBuilder<T>(
      future: future,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return error?.call(context, snapshot.error!) ??
              Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.hasData) {
          return builder(context, snapshot.data!);
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// Create optimized StreamBuilder
  static Widget createOptimizedStreamBuilder<T>({
    required Stream<T> stream,
    required Widget Function(BuildContext, T) builder,
    Widget? loading,
    Widget Function(BuildContext, Object)? error,
    T? initialData,
  }) {
    return StreamBuilder<T>(
      stream: stream,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return loading ?? const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return error?.call(context, snapshot.error!) ??
              Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.hasData) {
          return builder(context, snapshot.data!);
        }

        return const SizedBox.shrink();
      },
    );
  }

  /// Clean up resources
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    for (final completer in _completers.values) {
      if (!completer.isCompleted) {
        completer.completeError('Service disposed');
      }
    }
    _completers.clear();
  }
}

/// Performance monitoring mixin
mixin PerformanceMonitoring {
  final Map<String, Stopwatch> _stopwatches = {};

  void startTimer(String key) {
    _stopwatches[key] = Stopwatch()..start();
  }

  void stopTimer(String key) {
    final stopwatch = _stopwatches[key];
    if (stopwatch != null) {
      stopwatch.stop();
      if (kDebugMode) {
        debugPrint('$key took ${stopwatch.elapsedMilliseconds}ms');
      }
      _stopwatches.remove(key);
    }
  }

  Duration? getTimerDuration(String key) {
    return _stopwatches[key]?.elapsed;
  }
}
