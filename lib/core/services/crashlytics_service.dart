import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class CrashlyticsService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  late final PackageInfo _packageInfo;
  bool _isInitialized = false;

  // Singleton pattern
  static final CrashlyticsService _instance = CrashlyticsService._internal();
  factory CrashlyticsService() => _instance;
  CrashlyticsService._internal();

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _packageInfo = await PackageInfo.fromPlatform();

      // Enable Crashlytics collection
      await _crashlytics.setCrashlyticsCollectionEnabled(true);

      await _setCustomKeys();
      _setupErrorHandling();

      _isInitialized = true;
      print('CrashlyticsService: Initialization completed successfully');
    } catch (e, stack) {
      print('CrashlyticsService: Error during initialization: $e');
      print('CrashlyticsService: Stack trace: $stack');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _setCustomKeys() async {
    try {
      final deviceData = await _getDeviceInfo();

      await _crashlytics.setCustomKey('device_info', deviceData);
      await _crashlytics.setCustomKey('app_version', _packageInfo.version);
      await _crashlytics.setCustomKey('build_number', _packageInfo.buildNumber);
      await _crashlytics.setCustomKey('platform', Platform.operatingSystem);
      await _crashlytics.setCustomKey(
          'platform_version', Platform.operatingSystemVersion);
      await _crashlytics.setCustomKey(
          'app_package_name', _packageInfo.packageName);
      await _crashlytics.setCustomKey(
          'app_installer_store', _packageInfo.installerStore ?? 'unknown');
      await _crashlytics.setCustomKey('debug_mode', kDebugMode.toString());
    } catch (e) {
      print('CrashlyticsService: Error setting custom keys: $e');
      rethrow;
    }
  }

  Future<String> _getDeviceInfo() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return '''
        Android ${androidInfo.version.release}
        SDK ${androidInfo.version.sdkInt}
        ${androidInfo.brand} ${androidInfo.model}
        ${androidInfo.device}
        ${androidInfo.product}
        ${androidInfo.hardware}
        ${androidInfo.isPhysicalDevice ? 'Physical Device' : 'Emulator'}
      ''';
    } else if (Platform.isIOS) {
      final iosInfo = await _deviceInfo.iosInfo;
      return '''
        iOS ${iosInfo.systemVersion}
        ${iosInfo.model}
        ${iosInfo.name}
        ${iosInfo.localizedModel}
        ${iosInfo.identifierForVendor}
        ${iosInfo.isPhysicalDevice ? 'Physical Device' : 'Simulator'}
      ''';
    }
    return 'Unknown Platform';
  }

  void _setupErrorHandling() {
    // Flutter hatalarını yakala
    FlutterError.onError = (FlutterErrorDetails details) {
      if (!_isInitialized) return;

      _crashlytics.recordFlutterError(details);
      _crashlytics.log('Error occurred in ${details.library}');
    };

    // Zone hatalarını yakala
    PlatformDispatcher.instance.onError = (error, stack) {
      if (!_isInitialized) return true;

      _crashlytics.recordError(
        error,
        stack,
        reason: 'Uncaught error in main zone',
        fatal: true,
      );
      return true;
    };
  }

  // Custom error logging methods
  Future<void> log(String message) async {
    if (!_isInitialized) return;

    try {
      await _crashlytics.log(message);
    } catch (e) {
      print('CrashlyticsService: Error logging message: $e');
    }
  }

  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!_isInitialized) return;

    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
    } catch (e) {
      print('CrashlyticsService: Error recording error: $e');
    }
  }

  Future<void> setUserIdentifier(String identifier) async {
    if (!_isInitialized) return;

    try {
      await _crashlytics.setUserIdentifier(identifier);
    } catch (e) {
      print('CrashlyticsService: Error setting user identifier: $e');
    }
  }
}
