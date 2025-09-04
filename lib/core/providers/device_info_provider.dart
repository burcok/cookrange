import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class DeviceInfoProvider extends ChangeNotifier {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  String _deviceType = 'unknown';
  String _deviceModel = 'unknown';
  String _deviceOs = 'unknown';
  String _appVersion = 'unknown';
  String _buildNumber = 'unknown';
  final Map<String, String> _permissionStatus = {};

  String get deviceType => _deviceType;
  String get deviceModel => _deviceModel;
  String get deviceOs => _deviceOs;
  String get appVersion => _appVersion;
  String get buildNumber => _buildNumber;
  Map<String, String> get permissionStatus => _permissionStatus;

  // Tüm cihaz bilgilerini içeren map
  Map<String, dynamic> get allDeviceInfo => {
        'deviceType': _deviceType,
        'deviceModel': _deviceModel,
        'deviceOs': _deviceOs,
        'appVersion': _appVersion,
        'buildNumber': _buildNumber,
        'permissionStatus': _permissionStatus,
      };

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

      // Don't await this. Let it run in the background.
      _getPermissionInfo();

      // Notify listeners immediately with the basic info.
      // A second notification will come from _getPermissionInfo when it's done.
      notifyListeners();
    } catch (e) {
      print('Error initializing device info: $e');
    }
  }

  Future<void> _getPermissionInfo() async {
    try {
      // Using a smaller, more common list of permissions to avoid issues
      // with undeclared permissions. This list should be synchronized with
      // the permissions requested in AndroidManifest.xml and Info.plist.
      final permissions = [
        Permission.camera,
        Permission.microphone,
        Permission.storage,
        Permission.location,
        Permission.notification,
        Permission.phone,
      ];

      for (final permission in permissions) {
        try {
          final status = await permission.status;
          _permissionStatus[permission.toString()] = status.toString();
        } catch (e) {
          _permissionStatus[permission.toString()] = 'unknown';
        }
      }
      notifyListeners();
    } catch (e) {
      print('Error getting permission info: $e');
    }
  }
}
