import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:convert';
import 'dart:io';
import '../providers/device_info_provider.dart';

class LogService {
  static final Logger _logger = Logger('CookrangeApp');

  // Singleton pattern for consistent access
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  String? _cachedIp;
  DateTime? _lastIpFetchTime;
  Map<String, dynamic>? _cachedDeviceInfo;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  void setup() {
    // Configure logging levels based on build mode
    Logger.root.level = kDebugMode ? Level.ALL : Level.WARNING;

    Logger.root.onRecord.listen((record) {
      // Only log in debug mode or for important messages
      if (kDebugMode || record.level >= Level.WARNING) {
        debugPrint(
            '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');

        // Include error and stack trace if present
        if (record.error != null) {
          debugPrint('Error: ${record.error}');
        }
        if (record.stackTrace != null) {
          debugPrint('Stack Trace: ${record.stackTrace}');
        }
      }
    });
  }

  /// Logs a user activity to Firestore `logs` collection.
  Future<void> logActivity(String eventType, Map<String, dynamic> data) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final systemContext = await getSystemContext();

      final activityItem = {
        'id': _firestore.collection('logs').doc().id,
        'event_type': eventType,
        'timestamp': FieldValue.serverTimestamp(),
        'user_id': user.uid,
        'user_email': user.email,
        ...systemContext,
        ...data,
      };

      final logsDocRef = _firestore.collection('logs').doc(user.uid);
      final logsDoc = await logsDocRef.get();

      if (!logsDoc.exists) {
        await logsDocRef.set({
          'login_history': [],
          'user_activity': [activityItem],
          'last_updated': FieldValue.serverTimestamp(),
        });
      } else {
        await logsDocRef.update({
          'user_activity': FieldValue.arrayUnion([activityItem]),
          'last_updated': FieldValue.serverTimestamp(),
        });
      }

      info('Logged activity: $eventType', service: 'ActivityLog');
    } catch (e, stack) {
      error('Failed to log activity',
          service: 'ActivityLog', error: e, stackTrace: stack);
    }
  }

  Future<Map<String, dynamic>> getSystemContext() async {
    try {
      // Get/Cache Device Info
      if (_cachedDeviceInfo == null) {
        final deviceProvider = DeviceInfoProvider();
        await deviceProvider.initialize();
        _cachedDeviceInfo = {
          'device_model': deviceProvider.deviceModel,
          'device_brand': deviceProvider.deviceBrand,
          'device_type': deviceProvider.deviceType,
          'device_os': deviceProvider.deviceOs,
          'os_version': deviceProvider.osVersion,
          'app_version': deviceProvider.appVersion,
          'build_number': deviceProvider.buildNumber,
          'manufacturer': deviceProvider.manufacturer,
          'is_physical_device': deviceProvider.isPhysicalDevice,
        };
      }

      final ip = await _getIpAddress();
      final connectivity = await Connectivity().checkConnectivity();

      return {
        ...?_cachedDeviceInfo,
        'ip_address': ip,
        'connectivity': connectivity.map((e) => e.name).toList(),
        'timezone': DateTime.now().timeZoneName,
        'locale': Platform.localeName,
        'timestamp_ms': DateTime.now().millisecondsSinceEpoch,
      };
    } catch (e) {
      return {'error_getting_context': e.toString()};
    }
  }

  Future<String> _getIpAddress() async {
    if (_cachedIp != null &&
        _lastIpFetchTime != null &&
        DateTime.now().difference(_lastIpFetchTime!) <
            const Duration(hours: 4)) {
      return _cachedIp!;
    }

    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _cachedIp = data['ip'];
        _lastIpFetchTime = DateTime.now();
        return _cachedIp ?? "0.0.0.0";
      }
    } catch (_) {}
    return "0.0.0.0";
  }

  void info(String message, {String? service}) {
    _logger.info('${_formatService(service)}$message');
  }

  void warning(String message, {String? service, Object? error}) {
    _logger.warning('${_formatService(service)}$message', error);
  }

  void error(String message,
      {String? service, Object? error, StackTrace? stackTrace}) {
    _logger.severe('${_formatService(service)}$message', error, stackTrace);
  }

  String _formatService(String? service) {
    return service != null ? '[$service] ' : '';
  }
}
