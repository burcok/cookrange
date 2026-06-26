import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'log_service.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'RemoteConfigService';

  FirebaseRemoteConfig get _rc => FirebaseRemoteConfig.instance;

  static const _defaults = <String, dynamic>{
    'maintenance_mode': false,
    'min_version': '1.0.0',
    'ai_model': 'deepseek/deepseek-r1t-chimera:free',
    'max_meal_retries': 3,
    'feature_voice_assistant': false,
    'feature_nutrition_analytics': false,
    // Set to the deployed Cloud Function URL to move the AI key off-device.
    // Empty string = fall back to direct OpenRouter with the local .env key.
    'ai_proxy_url': '',
  };

  Future<void> initialize() async {
    try {
      await _rc.setDefaults(_defaults);
      await _rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      await _rc.fetchAndActivate();
      _log.info('Remote Config initialized', service: _serviceName);
    } catch (e) {
      _log.warning(
        'Remote Config fetch failed — using defaults',
        service: _serviceName,
      );
    }
  }

  bool getBool(String key) => _rc.getBool(key);
  String getString(String key) => _rc.getString(key);
  int getInt(String key) => _rc.getInt(key);
  double getDouble(String key) => _rc.getDouble(key);

  bool get maintenanceMode => getBool('maintenance_mode');
  String get minVersion => getString('min_version');
  String get aiModel => getString('ai_model');
  int get maxMealRetries => getInt('max_meal_retries');
  bool get featureVoiceAssistant => getBool('feature_voice_assistant');
  bool get featureNutritionAnalytics => getBool('feature_nutrition_analytics');
  String get aiProxyUrl => getString('ai_proxy_url');
}
