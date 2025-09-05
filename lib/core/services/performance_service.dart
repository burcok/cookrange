import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:isolate';
import 'log_service.dart';

/// Service to manage performance optimizations and async operations
class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'PerformanceService';

  final Map<String, Timer> _timers = {};
  final Map<String, Completer> _completers = {};

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
  void debounce(String key, VoidCallback callback, {Duration delay = const Duration(milliseconds: 300)}) {
    _timers[key]?.cancel();
    _timers[key] = Timer(delay, callback);
  }

  /// Throttle function calls
  void throttle(String key, VoidCallback callback, {Duration delay = const Duration(milliseconds: 100)}) {
    if (!_timers.containsKey(key)) {
      _timers[key] = Timer(delay, () {
        callback();
        _timers.remove(key);
      });
    }
  }

  /// Create a singleton operation that prevents multiple simultaneous executions
  Future<T> singletonOperation<T>(String key, Future<T> Function() operation) async {
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
  static List<T> optimizeList<T>(List<T> list, {
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
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
