import 'package:firebase_performance/firebase_performance.dart';
import 'log_service.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'PerformanceService';

  FirebasePerformance get _perf => FirebasePerformance.instance;

  Future<void> initialize() async {
    try {
      await _perf.setPerformanceCollectionEnabled(true);
      _log.info('Firebase Performance initialized', service: _serviceName);
    } catch (e) {
      _log.warning('Firebase Performance init failed', service: _serviceName);
    }
  }

  /// Start a named custom trace. Call [Trace.stop] when done.
  Future<Trace?> startTrace(String name) async {
    try {
      final trace = _perf.newTrace(name);
      await trace.start();
      return trace;
    } catch (e) {
      _log.warning('Could not start trace "$name"', service: _serviceName);
      return null;
    }
  }

  /// Convenience wrapper: runs [fn], records its duration under [traceName].
  Future<T> trace<T>(String traceName, Future<T> Function() fn) async {
    Trace? t;
    try {
      t = await startTrace(traceName);
      final result = await fn();
      return result;
    } finally {
      try {
        await t?.stop();
      } catch (_) {}
    }
  }

  /// Create an HTTP metric for manual tracking.
  HttpMetric newHttpMetric(String url, HttpMethod method) =>
      _perf.newHttpMetric(url, method);
}
