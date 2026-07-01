/// Remote, admin-editable application configuration (`app_config/global`).
///
/// Fetched once per session and cached (see [AppConfigService]). Every field
/// falls back to a safe default so a missing/partial/corrupt doc can NEVER
/// break the app. NO SECRETS live here (the doc is public-read) — only model
/// names, limits, flags, URLs. Money-touching values are ALSO enforced
/// server-side (`aiProxy`); the client copy is advisory.
library;

/// Small helper for a `{en: ..., tr: ...}` localized string map stored in config.
class LocalizedText {
  final Map<String, String> _byLocale;
  const LocalizedText(this._byLocale);

  static LocalizedText fromAny(dynamic v) {
    if (v is Map) {
      return LocalizedText(v.map((k, val) => MapEntry('$k', '$val')));
    }
    if (v is String) return LocalizedText({'en': v, 'tr': v});
    return const LocalizedText({});
  }

  bool get isEmpty => _byLocale.isEmpty;

  /// Resolves for [locale] (e.g. 'tr'), falling back to en → any → ''.
  String resolve(String locale) {
    return _byLocale[locale] ??
        _byLocale['en'] ??
        (_byLocale.isNotEmpty ? _byLocale.values.first : '');
  }
}

int _int(dynamic v, int d) => v is num ? v.toInt() : (int.tryParse('$v') ?? d);
double _dbl(dynamic v, double d) =>
    v is num ? v.toDouble() : (double.tryParse('$v') ?? d);
bool _bool(dynamic v, bool d) =>
    v is bool ? v : (v == null ? d : '$v'.toLowerCase() == 'true');
String _str(dynamic v, String d) => v is String && v.isNotEmpty ? v : d;
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? v.map((k, val) => MapEntry('$k', val)) : const {};

// ─── AI ───────────────────────────────────────────────────────────────────
class AiConfig {
  final String textModel;
  final String visionModel;
  final Map<String, String> modelByType; // e.g. {meal_plan: '...'}
  final int maxTokens;
  final Map<String, int> maxTokensByType;
  final double temperature;
  final int timeoutS;
  final int maxRetries;
  final List<String> allowedModels;
  final int freeDailyLimit;
  final int premiumDailyLimit;
  final bool photoAnalysisEnabled;
  final bool weeklyRecapEnabled;
  final bool fitnessTwinEnabled;

  const AiConfig({
    // Empty by default so a missing/blank config never overrides the client's
    // own valid default model (applyRemoteConfig only applies non-empty values).
    this.textModel = '',
    this.visionModel = '',
    this.modelByType = const {},
    this.maxTokens = 8192,
    this.maxTokensByType = const {},
    this.temperature = 0.7,
    this.timeoutS = 90,
    this.maxRetries = 3,
    this.allowedModels = const [],
    this.freeDailyLimit = 5,
    this.premiumDailyLimit = 50,
    this.photoAnalysisEnabled = true,
    this.weeklyRecapEnabled = true,
    this.fitnessTwinEnabled = true,
  });

  /// The model to use for a given query [type], falling back to [textModel].
  String modelFor(String type) => modelByType[type] ?? textModel;
  int maxTokensFor(String type) => maxTokensByType[type] ?? maxTokens;

  static AiConfig fromMap(Map<String, dynamic> m) {
    const d = AiConfig();
    return AiConfig(
      textModel: _str(m['text_model'], d.textModel),
      visionModel: _str(m['vision_model'], d.visionModel),
      modelByType: _map(m['model_by_type'])
          .map((k, v) => MapEntry(k, '$v')),
      maxTokens: _int(m['max_tokens'], d.maxTokens),
      maxTokensByType: _map(m['max_tokens_by_type'])
          .map((k, v) => MapEntry(k, _int(v, d.maxTokens))),
      temperature: _dbl(m['temperature'], d.temperature),
      timeoutS: _int(m['timeout_s'], d.timeoutS),
      maxRetries: _int(m['max_retries'], d.maxRetries),
      allowedModels: (m['allowed_models'] is List)
          ? List<String>.from((m['allowed_models'] as List).map((e) => '$e'))
          : d.allowedModels,
      freeDailyLimit: _int(m['free_daily_limit'], d.freeDailyLimit),
      premiumDailyLimit: _int(m['premium_daily_limit'], d.premiumDailyLimit),
      photoAnalysisEnabled:
          _bool(m['photo_analysis_enabled'], d.photoAnalysisEnabled),
      weeklyRecapEnabled: _bool(m['weekly_recap_enabled'], d.weeklyRecapEnabled),
      fitnessTwinEnabled: _bool(m['fitness_twin_enabled'], d.fitnessTwinEnabled),
    );
  }
}

// ─── Version / update ───────────────────────────────────────────────────────
class VersionConfig {
  final String minSupportedAndroid;
  final String minSupportedIos;
  final String latestAndroid;
  final String latestIos;
  final bool forceUpdate;
  final LocalizedText updateMessage;
  final String androidStoreUrl;
  final String iosStoreUrl;

  const VersionConfig({
    this.minSupportedAndroid = '0.0.0',
    this.minSupportedIos = '0.0.0',
    this.latestAndroid = '0.0.0',
    this.latestIos = '0.0.0',
    this.forceUpdate = false,
    this.updateMessage = const LocalizedText({}),
    this.androidStoreUrl = '',
    this.iosStoreUrl = '',
  });

  static VersionConfig fromMap(Map<String, dynamic> m) {
    const d = VersionConfig();
    return VersionConfig(
      minSupportedAndroid: _str(m['min_supported_android'], d.minSupportedAndroid),
      minSupportedIos: _str(m['min_supported_ios'], d.minSupportedIos),
      latestAndroid: _str(m['latest_android'], d.latestAndroid),
      latestIos: _str(m['latest_ios'], d.latestIos),
      forceUpdate: _bool(m['force_update'], d.forceUpdate),
      updateMessage: LocalizedText.fromAny(m['update_message']),
      androidStoreUrl: _str(m['android_store_url'], d.androidStoreUrl),
      iosStoreUrl: _str(m['ios_store_url'], d.iosStoreUrl),
    );
  }
}

// ─── Maintenance ─────────────────────────────────────────────────────────────
class MaintenanceConfig {
  final bool enabled;
  final LocalizedText message;
  const MaintenanceConfig(
      {this.enabled = false, this.message = const LocalizedText({})});

  static MaintenanceConfig fromMap(Map<String, dynamic> m) => MaintenanceConfig(
        enabled: _bool(m['enabled'], false),
        message: LocalizedText.fromAny(m['message']),
      );
}

// ─── Announcement banner ──────────────────────────────────────────────────────
class AnnouncementConfig {
  final bool enabled;
  final String id; // used to remember "dismissed"
  final LocalizedText message;
  final String type; // info | warning | success
  final String ctaUrl;
  final bool dismissible;

  const AnnouncementConfig({
    this.enabled = false,
    this.id = '',
    this.message = const LocalizedText({}),
    this.type = 'info',
    this.ctaUrl = '',
    this.dismissible = true,
  });

  static AnnouncementConfig fromMap(Map<String, dynamic> m) => AnnouncementConfig(
        enabled: _bool(m['enabled'], false),
        id: _str(m['id'], ''),
        message: LocalizedText.fromAny(m['message']),
        type: _str(m['type'], 'info'),
        ctaUrl: _str(m['cta_url'], ''),
        dismissible: _bool(m['dismissible'], true),
      );
}

// ─── Root ──────────────────────────────────────────────────────────────────
class AppConfig {
  final int configVersion;
  final AiConfig ai;
  final VersionConfig version;
  final MaintenanceConfig maintenance;
  final AnnouncementConfig announcement;
  final Map<String, bool> features; // kill-switches
  final Map<String, int> rollout; // 0..100 per feature
  final Map<String, int> limits;
  final String aiProxyUrl;
  final DateTime? fetchedAt;

  const AppConfig({
    this.configVersion = 1,
    this.ai = const AiConfig(),
    this.version = const VersionConfig(),
    this.maintenance = const MaintenanceConfig(),
    this.announcement = const AnnouncementConfig(),
    this.features = const {},
    this.rollout = const {},
    this.limits = const {},
    this.aiProxyUrl = '',
    this.fetchedAt,
  });

  /// A feature is enabled unless explicitly disabled (default-on, fail-safe).
  bool isFeatureEnabled(String key) => features[key] ?? true;

  int limit(String key, int fallback) => limits[key] ?? fallback;

  static AppConfig fromMap(Map<String, dynamic> m, {DateTime? fetchedAt}) {
    return AppConfig(
      configVersion: _int(m['config_version'], 1),
      ai: AiConfig.fromMap(_map(m['ai'])),
      version: VersionConfig.fromMap(_map(m['version'])),
      maintenance: MaintenanceConfig.fromMap(_map(m['maintenance'])),
      announcement: AnnouncementConfig.fromMap(_map(m['announcement'])),
      features: _map(m['features']).map((k, v) => MapEntry(k, _bool(v, true))),
      rollout: _map(m['rollout']).map((k, v) => MapEntry(k, _int(v, 100))),
      limits: _map(m['limits']).map((k, v) => MapEntry(k, _int(v, 0))),
      aiProxyUrl: _str(_map(m['endpoints'])['ai_proxy_url'], ''),
      fetchedAt: fetchedAt,
    );
  }
}
