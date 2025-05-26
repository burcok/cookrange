import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';

class DeviceInfoProvider extends ChangeNotifier {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String _deviceType = 'unknown';
  String _deviceModel = 'unknown';
  String _deviceOs = 'unknown';
  String _appVersion = 'unknown';
  String _buildNumber = 'unknown';

  String get deviceType => _deviceType;
  String get deviceModel => _deviceModel;
  String get deviceOs => _deviceOs;
  String get appVersion => _appVersion;
  String get buildNumber => _buildNumber;

  Future<void> initialize() async {
    try {
      if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceType = 'iOS';
        _deviceModel = iosInfo.model;
        _deviceOs = 'iOS ${iosInfo.systemVersion}';
      } else if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceType = 'Android';
        _deviceModel = androidInfo.model;
        _deviceOs = 'Android ${androidInfo.version.release}';
      }

      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;

      notifyListeners();
    } catch (e) {
      print('Error initializing device info: $e');
    }
  }
}
