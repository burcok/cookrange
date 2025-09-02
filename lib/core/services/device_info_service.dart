import 'package:firebase_analytics/firebase_analytics.dart';
import '../providers/device_info_provider.dart';

class DeviceInfoService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // Singleton pattern
  static final DeviceInfoService _instance = DeviceInfoService._internal();
  factory DeviceInfoService() => _instance;
  DeviceInfoService._internal();

  /// Cihaz bilgilerini Firebase Analytics'e gönder
  Future<void> sendDeviceInfoToAnalytics(DeviceInfoProvider deviceInfo) async {
    try {
      // User properties olarak cihaz bilgilerini ayarla
      await _analytics.setUserProperty(
        name: 'device_type',
        value: deviceInfo.deviceType,
      );

      await _analytics.setUserProperty(
        name: 'device_model',
        value: deviceInfo.deviceModel,
      );

      await _analytics.setUserProperty(
        name: 'device_os',
        value: deviceInfo.deviceOs,
      );

      await _analytics.setUserProperty(
        name: 'app_version',
        value: deviceInfo.appVersion,
      );

      await _analytics.setUserProperty(
        name: 'app_build_number',
        value: deviceInfo.buildNumber,
      );

      // Custom event olarak cihaz bilgilerini gönder
      await _analytics.logEvent(
        name: 'device_info_collected',
        parameters: {
          'device_type': deviceInfo.deviceType,
          'device_model': deviceInfo.deviceModel,
          'device_os': deviceInfo.deviceOs,
          'app_version': deviceInfo.appVersion,
          'build_number': deviceInfo.buildNumber,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      print('Device info sent to Firebase Analytics successfully');
    } catch (e) {
      print('Error sending device info to Firebase Analytics: $e');
    }
  }

  /// Cihaz bilgilerini Firebase Analytics'e gönder (detaylı bilgilerle)
  Future<void> sendDetailedDeviceInfoToAnalytics(
      DeviceInfoProvider deviceInfo) async {
    try {
      // Temel cihaz bilgilerini gönder
      await sendDeviceInfoToAnalytics(deviceInfo);

      // Detaylı cihaz bilgilerini custom event olarak gönder
      final allDeviceInfo = deviceInfo.allDeviceInfo;

      await _analytics.logEvent(
        name: 'detailed_device_info_collected',
        parameters: {
          ...allDeviceInfo,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );

      print('Detailed device info sent to Firebase Analytics successfully');
    } catch (e) {
      print('Error sending detailed device info to Firebase Analytics: $e');
    }
  }

  /// Cihaz bilgilerini Firebase Analytics'e gönder
  Future<void> sendDeviceInfoToFirebase(DeviceInfoProvider deviceInfo,
      {bool detailed = false}) async {
    try {
      if (detailed) {
        await sendDetailedDeviceInfoToAnalytics(deviceInfo);
      } else {
        await sendDeviceInfoToAnalytics(deviceInfo);
      }

      print('Device info sent to Firebase Analytics successfully');
    } catch (e) {
      print('Error sending device info to Firebase Analytics: $e');
    }
  }
}
