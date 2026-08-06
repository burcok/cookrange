// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Source of truth: functions/config_schema.json
// Regenerate:       node scripts/gen_config_schema.js
//
// Any change to a setting's default, bounds, or metadata belongs in
// functions/config_schema.json, never in this file directly — a hand-edit here
// will be silently overwritten (and CI's `git diff --exit-code` check on
// these generated files will catch a stale regeneration either way).

library;

/// Which `app_config/{doc}` a setting is read from — see DECISIONS.md ADR-023
/// (placement rule: a setting lives in the most restrictive doc that still
/// contains every one of its readers).
enum ConfigDoc { critical, client, server }

ConfigDoc configDocFromString(String s) => switch (s) {
  'critical' => ConfigDoc.critical,
  'client' => ConfigDoc.client,
  'server' => ConfigDoc.server,
  _ => throw ArgumentError('Unknown ConfigDoc: $s'),
};

/// One schema-declared field descriptor. Drives the schema-generated admin
/// config editor (Faz C) and the read-side bounds clamp (DECISIONS.md ADR-023).
/// Carries no `default` — see kConfigDefaults in app_config_defaults.g.dart.
class ConfigField {
  final String key;
  final String type;
  final ConfigDoc doc;
  final String group;
  final String label;
  final bool sensitive;
  final num? min;
  final num? max;
  final List<String>? enumValues;

  const ConfigField({
    required this.key,
    required this.type,
    required this.doc,
    required this.group,
    required this.label,
    this.sensitive = false,
    this.min,
    this.max,
    this.enumValues,
  });
}

const List<ConfigField> kConfigSchema = [
  ConfigField(key: 'ai.allowed_models', type: 'string_list', doc: ConfigDoc.server, group: 'ai_server', label: 'İzin verilen model listesi', sensitive: true),
  ConfigField(key: 'ai.free_daily_limit', type: 'int', doc: ConfigDoc.client, group: 'ai', label: 'Ücretsiz günlük AI hakkı', sensitive: true, min: 0, max: 100),
  ConfigField(key: 'ai.max_messages', type: 'int', doc: ConfigDoc.server, group: 'ai_server', label: 'Maksimum mesaj sayısı (sohbet)', min: 1, max: 200),
  ConfigField(key: 'ai.max_retries', type: 'int', doc: ConfigDoc.client, group: 'ai', label: 'AI çağrısı yeniden deneme sayısı', min: 0, max: 10),
  ConfigField(key: 'ai.max_tokens', type: 'int', doc: ConfigDoc.server, group: 'ai_server', label: 'Maksimum çıktı token (varsayılan)', min: 256, max: 32000),
  ConfigField(key: 'ai.max_tokens_by_type', type: 'map<string,int>', doc: ConfigDoc.server, group: 'ai_server', label: 'Sorgu tipine göre maksimum token'),
  ConfigField(key: 'ai.max_total_chars', type: 'int', doc: ConfigDoc.server, group: 'ai_server', label: 'Maksimum toplam karakter (payload)', min: 1000, max: 200000),
  ConfigField(key: 'ai.model_by_type', type: 'map<string,string>', doc: ConfigDoc.server, group: 'ai_server', label: 'Sorgu tipine göre model', sensitive: true),
  ConfigField(key: 'ai.model_pricing', type: 'map<string,object>', doc: ConfigDoc.server, group: 'ai_server', label: 'Model fiyatlandırması (USD/1M token)', sensitive: true),
  ConfigField(key: 'ai.premium_daily_limit', type: 'int', doc: ConfigDoc.client, group: 'ai', label: 'Premium günlük AI hakkı', sensitive: true, min: 0, max: 500),
  ConfigField(key: 'ai.rate_max_in_window', type: 'int', doc: ConfigDoc.server, group: 'ai_server', label: 'Pencere başına maksimum çağrı', sensitive: true, min: 1, max: 1000),
  ConfigField(key: 'ai.rate_window_ms', type: 'int', doc: ConfigDoc.server, group: 'ai_server', label: 'AI hız sınırı penceresi (ms)', sensitive: true, min: 1000, max: 3600000),
  ConfigField(key: 'ai.retry_delay_s', type: 'int', doc: ConfigDoc.client, group: 'ai', label: 'Yeniden deneme gecikmesi (sn)', min: 0, max: 30),
  ConfigField(key: 'ai.temperature', type: 'double', doc: ConfigDoc.server, group: 'ai_server', label: 'Model sıcaklığı', min: 0, max: 1),
  ConfigField(key: 'ai.text_model', type: 'string', doc: ConfigDoc.client, group: 'ai', label: 'Metin modeli (override)'),
  ConfigField(key: 'ai.timeout_s', type: 'int', doc: ConfigDoc.client, group: 'ai', label: 'AI istek zaman aşımı (sn)', min: 10, max: 300),
  ConfigField(key: 'ai.vision_model', type: 'string', doc: ConfigDoc.client, group: 'ai', label: 'Görsel modeli (override)'),
  ConfigField(key: 'announcement.cta_url', type: 'string', doc: ConfigDoc.critical, group: 'announcement', label: 'Duyuru CTA URL'),
  ConfigField(key: 'announcement.dismissible', type: 'bool', doc: ConfigDoc.critical, group: 'announcement', label: 'Kapatılabilir'),
  ConfigField(key: 'announcement.enabled', type: 'bool', doc: ConfigDoc.critical, group: 'announcement', label: 'Duyuru aktif'),
  ConfigField(key: 'announcement.id', type: 'string', doc: ConfigDoc.critical, group: 'announcement', label: 'Duyuru ID (dismiss tracking)'),
  ConfigField(key: 'announcement.message', type: 'map<string,string>', doc: ConfigDoc.critical, group: 'announcement', label: 'Duyuru mesajı (en/tr)'),
  ConfigField(key: 'announcement.type', type: 'enum', doc: ConfigDoc.critical, group: 'announcement', label: 'Duyuru tipi', enumValues: <String>['info', 'warning', 'success', 'promo']),
  ConfigField(key: 'client.check_in_radius_m', type: 'int', doc: ConfigDoc.client, group: 'client_misc', label: 'Salon check-in yarıçapı (m)', min: 10, max: 1000),
  ConfigField(key: 'client.max_dishes_per_prompt', type: 'int', doc: ConfigDoc.client, group: 'client_misc', label: 'Prompt başına maksimum yemek sayısı', min: 20, max: 500),
  ConfigField(key: 'client.min_age_years', type: 'int', doc: ConfigDoc.critical, group: 'compliance', label: 'Minimum yaş (KVKK/GDPR)', sensitive: true, min: 13, max: 21),
  ConfigField(key: 'client.referral_pending_code_ttl_days', type: 'int', doc: ConfigDoc.critical, group: 'referral', label: 'Bekleyen referans kodu TTL (gün)', min: 1, max: 30),
  ConfigField(key: 'client.weekly_meal_plan_expiry_days', type: 'int', doc: ConfigDoc.client, group: 'client_misc', label: 'Haftalık plan geçerlilik süresi (gün)', min: 1, max: 30),
  ConfigField(key: 'cost.pricing', type: 'object', doc: ConfigDoc.server, group: 'economy', label: 'Maliyet/gelir varsayımları (admin cost dashboard)', sensitive: true),
  ConfigField(key: 'economy.gym_commission_try', type: 'map<string,double>', doc: ConfigDoc.server, group: 'economy', label: 'Salon komisyonu (₺, ürün başına)', sensitive: true),
  ConfigField(key: 'economy.referral_commission_try', type: 'double', doc: ConfigDoc.server, group: 'economy', label: 'Referans komisyonu (₺, sabit)', sensitive: true, min: 0, max: 1000),
  ConfigField(key: 'economy.referral_max_uses', type: 'int', doc: ConfigDoc.server, group: 'economy', label: 'Referans kodu maksimum kullanım', min: 1, max: 1000),
  ConfigField(key: 'economy.referral_reward_days', type: 'int', doc: ConfigDoc.server, group: 'economy', label: 'Referans ödülü (gün)', sensitive: true, min: 1, max: 90),
  ConfigField(key: 'economy.streak_freeze_grant_amount', type: 'int', doc: ConfigDoc.server, group: 'economy', label: 'Yeni kullanıcı streak dondurma hediyesi', min: 0, max: 5),
  ConfigField(key: 'endpoints.ai_proxy_url', type: 'string', doc: ConfigDoc.client, group: 'ai', label: 'AI proxy URL (override)', sensitive: true),
  ConfigField(key: 'engagement.contrib_leaderboard_groups_per_run', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Canlı katkı panosu — çalıştırma başına grup sayısı', min: 10, max: 5000),
  ConfigField(key: 'engagement.contrib_leaderboard_top_n', type: 'int', doc: ConfigDoc.server, group: 'gamification_server', label: 'Canlı katkı panosu — gösterilen üye sayısı', min: 1, max: 50),
  ConfigField(key: 'engagement.credit_table', type: 'map<string,object>', doc: ConfigDoc.server, group: 'gamification_server', label: 'AI kredi kazanım tablosu', sensitive: true),
  ConfigField(key: 'engagement.weekly_candidate_buffer', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Haftalık aday tampon boyutu', min: 1, max: 100),
  ConfigField(key: 'engagement.weekly_contrib_groups_per_run', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Haftalık katkı — çalıştırma başına grup sayısı', min: 10, max: 5000),
  ConfigField(key: 'engagement.weekly_min_active_members', type: 'int', doc: ConfigDoc.server, group: 'gamification_server', label: 'Haftalık grup katkı — minimum aktif üye', sensitive: true, min: 2, max: 50),
  ConfigField(key: 'engagement.weekly_top_n', type: 'int', doc: ConfigDoc.server, group: 'gamification_server', label: 'Haftalık kazanan sayısı', min: 1, max: 20),
  ConfigField(key: 'features.chat', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Sohbet'),
  ConfigField(key: 'features.coach', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Koç ekosistemi', sensitive: true),
  ConfigField(key: 'features.community', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Topluluk'),
  ConfigField(key: 'features.fitness_twin', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Fitness ikizi (AI)'),
  ConfigField(key: 'features.food_scan', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Yemek fotoğrafı tarama'),
  ConfigField(key: 'features.gym', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Spor salonu ekosistemi', sensitive: true),
  ConfigField(key: 'features.gym_attribution', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Salon atfetme/komisyon UI'),
  ConfigField(key: 'features.gym_invite_codes', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Salon davet kodları'),
  ConfigField(key: 'features.marketplace', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Pazar yeri (genel)', sensitive: true),
  ConfigField(key: 'features.meal_plan_templates', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Plan şablonları'),
  ConfigField(key: 'features.nutrition_analytics', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Beslenme analitiği'),
  ConfigField(key: 'features.photo_analysis', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Fotoğraf analizi (AI)'),
  ConfigField(key: 'features.programs', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Programlar (pazar yeri)', sensitive: true),
  ConfigField(key: 'features.referral', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Referans sistemi'),
  ConfigField(key: 'features.squad', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Squad'),
  ConfigField(key: 'features.voice_assistant', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Sesli asistan'),
  ConfigField(key: 'features.weekly_recap', type: 'bool', doc: ConfigDoc.critical, group: 'features', label: 'Haftalık özet'),
  ConfigField(key: 'gamification.achievement_points', type: 'map<string,int>', doc: ConfigDoc.server, group: 'gamification_server', label: 'Başarım puanları', sensitive: true),
  ConfigField(key: 'gamification.group_streak_achievement_threshold', type: 'int', doc: ConfigDoc.server, group: 'gamification_server', label: 'Grup streak başarım eşiği (hafta)', min: 1, max: 52),
  ConfigField(key: 'gamification.gym_regular_checkin_threshold', type: 'int', doc: ConfigDoc.server, group: 'gamification_server', label: '\'Düzenli salon üyesi\' check-in eşiği', min: 1, max: 100),
  ConfigField(key: 'gamification.level_curve_coefficient', type: 'int', doc: ConfigDoc.client, group: 'gamification', label: 'Seviye eğrisi katsayısı', sensitive: true, min: 10, max: 200),
  ConfigField(key: 'gamification.local_utc_offset_hours', type: 'int', doc: ConfigDoc.server, group: 'gamification_server', label: 'Yerel saat dilimi ofseti (UTC+)', min: -12, max: 14),
  ConfigField(key: 'gamification.max_level', type: 'int', doc: ConfigDoc.client, group: 'gamification', label: 'Maksimum seviye', min: 50, max: 9999),
  ConfigField(key: 'gamification.max_xp_events_per_call', type: 'int', doc: ConfigDoc.server, group: 'gamification_server', label: 'syncProgress çağrısı başına maksimum XP olayı', min: 1, max: 100),
  ConfigField(key: 'gamification.tier_level_floor', type: 'map<string,int>', doc: ConfigDoc.server, group: 'gamification_server', label: 'İtibar kademesi seviye eşikleri', sensitive: true),
  ConfigField(key: 'gamification.xp_table', type: 'map<string,object>', doc: ConfigDoc.server, group: 'gamification_server', label: 'XP tablosu', sensitive: true),
  ConfigField(key: 'groups.activity_comments_scan_limit', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Aktivite skoru — yorum tarama limiti', min: 10, max: 5000),
  ConfigField(key: 'groups.activity_groups_per_run', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Aktivite skoru — çalıştırma başına grup sayısı', min: 10, max: 5000),
  ConfigField(key: 'groups.activity_half_life_hours', type: 'double', doc: ConfigDoc.server, group: 'ops_caps', label: 'Aktivite skoru yarı ömrü (saat)', min: 1, max: 168),
  ConfigField(key: 'groups.activity_signal_limit', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Aktivite skoru — sinyal başına tarama limiti', min: 10, max: 5000),
  ConfigField(key: 'groups.activity_window_hours', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Aktivite skoru penceresi (saat)', min: 1, max: 168),
  ConfigField(key: 'maintenance.enabled', type: 'bool', doc: ConfigDoc.critical, group: 'maintenance', label: 'Bakım modu', sensitive: true),
  ConfigField(key: 'maintenance.message', type: 'map<string,string>', doc: ConfigDoc.critical, group: 'maintenance', label: 'Bakım mesajı (en/tr)'),
  ConfigField(key: 'media.vision_daily_cap', type: 'int', doc: ConfigDoc.server, group: 'ai_server', label: 'Günlük Vision taraması limiti', sensitive: true, min: 10, max: 100000),
  ConfigField(key: 'moderation.action_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Moderasyon aksiyonu hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.appeal_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'İtiraz gönderme hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.auto_restrict_flag_threshold', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Otomatik kısıtlama bayrak eşiği', sensitive: true, min: 1, max: 50),
  ConfigField(key: 'moderation.checkin_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Check-in hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.comment_min_text_length', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Yorum minimum metin uzunluğu', min: 0, max: 500),
  ConfigField(key: 'moderation.comment_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Yorum oluşturma hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.concentration_distinct_max', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Yoğunlaşma tespiti — maksimum farklı kaynak', sensitive: true, min: 1, max: 50),
  ConfigField(key: 'moderation.concentration_downweight', type: 'double', doc: ConfigDoc.server, group: 'moderation', label: 'Yoğunlaşma ağırlık cezası', sensitive: true, min: 0, max: 1),
  ConfigField(key: 'moderation.concentration_window', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Yoğunlaşma tespiti — pencere', min: 1, max: 200),
  ConfigField(key: 'moderation.duplicate_recent_window', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Yinelenen içerik karşılaştırma penceresi', min: 1, max: 200),
  ConfigField(key: 'moderation.duplicate_similarity_threshold', type: 'double', doc: ConfigDoc.server, group: 'moderation', label: 'Yinelenen içerik benzerlik eşiği', sensitive: true, min: 0.5, max: 1),
  ConfigField(key: 'moderation.follow_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Takip etme hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.group_create_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Grup oluşturma hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.message_min_text_length', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Mesaj minimum metin uzunluğu', min: 0, max: 500),
  ConfigField(key: 'moderation.message_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Sohbet mesajı hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.min_account_age_ms', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Minimum hesap yaşı (ms)', sensitive: true, min: 0, max: 2592000000),
  ConfigField(key: 'moderation.post_min_text_length', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Gönderi minimum metin uzunluğu', min: 0, max: 500),
  ConfigField(key: 'moderation.post_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Gönderi oluşturma hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.reaction_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Beğeni/tepki hız sınırı', sensitive: true),
  ConfigField(key: 'moderation.reciprocity_downweight', type: 'double', doc: ConfigDoc.server, group: 'moderation', label: 'Karşılıklılık ağırlık cezası', sensitive: true, min: 0, max: 1),
  ConfigField(key: 'moderation.reciprocity_min_pair_sample', type: 'int', doc: ConfigDoc.server, group: 'moderation', label: 'Karşılıklılık eşiği — minimum örnek', sensitive: true, min: 1, max: 100),
  ConfigField(key: 'moderation.reciprocity_ratio_threshold', type: 'double', doc: ConfigDoc.server, group: 'moderation', label: 'Karşılıklılık oran eşiği', sensitive: true, min: 0, max: 1),
  ConfigField(key: 'moderation.report_rate_limit', type: 'object', doc: ConfigDoc.server, group: 'moderation', label: 'Rapor gönderme hız sınırı', sensitive: true),
  ConfigField(key: 'presence.max_friends_fanout', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Arkadaş bildirimi fan-out limiti', min: 10, max: 5000),
  ConfigField(key: 'presence.notify_log_ttl_days', type: 'int', doc: ConfigDoc.server, group: 'presence', label: 'Bildirim log TTL (gün)', min: 1, max: 30),
  ConfigField(key: 'presence.presence_ttl_ms', type: 'int', doc: ConfigDoc.server, group: 'presence', label: 'Oturum geçerlilik süresi (ms)', min: 600000, max: 86400000),
  ConfigField(key: 'presence.quiet_hours_end', type: 'int', doc: ConfigDoc.server, group: 'presence', label: 'Sessiz saat bitişi (yerel saat)', min: 0, max: 23),
  ConfigField(key: 'presence.quiet_hours_start', type: 'int', doc: ConfigDoc.server, group: 'presence', label: 'Sessiz saat başlangıcı (yerel saat)', min: 0, max: 23),
  ConfigField(key: 'presence.rate_limit_reentry_ms', type: 'int', doc: ConfigDoc.server, group: 'presence', label: 'Yeniden giriş hız sınırı (ms)', min: 60000, max: 3600000),
  ConfigField(key: 'presence.stale_sweep_limit', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Eski oturum temizleme limiti', min: 10, max: 5000),
  ConfigField(key: 'presence.timestamp_skew_ms', type: 'int', doc: ConfigDoc.server, group: 'presence', label: 'İzin verilen saat sapması (ms)', sensitive: true, min: 10000, max: 3600000),
  ConfigField(key: 'privacy.k_anonymity_threshold', type: 'int', doc: ConfigDoc.client, group: 'privacy', label: 'K-anonimlik eşiği (salon analitiği)', sensitive: true, min: 2, max: 50),
  ConfigField(key: 'purchases.products', type: 'map<string,object>', doc: ConfigDoc.server, group: 'economy', label: 'Ürün kataloğu', sensitive: true),
  ConfigField(key: 'rollout.coach', type: 'int', doc: ConfigDoc.critical, group: 'rollout', label: 'Koç — kademeli açılım %', min: 0, max: 100),
  ConfigField(key: 'rollout.gym', type: 'int', doc: ConfigDoc.critical, group: 'rollout', label: 'Salon — kademeli açılım %', min: 0, max: 100),
  ConfigField(key: 'rollout.programs', type: 'int', doc: ConfigDoc.critical, group: 'rollout', label: 'Programlar — kademeli açılım %', min: 0, max: 100),
  ConfigField(key: 'rollout.squad', type: 'int', doc: ConfigDoc.critical, group: 'rollout', label: 'Squad — kademeli açılım %', min: 0, max: 100),
  ConfigField(key: 'summaries.gen_rate_max_in_window', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Pencere başına maksimum özet', min: 1, max: 10),
  ConfigField(key: 'summaries.gen_rate_window_ms', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Özet üretim hız penceresi (ms)', min: 3600000, max: 604800000),
  ConfigField(key: 'summaries.max_scope_members_scan', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Kapsam üyesi tarama limiti', min: 10, max: 5000),
  ConfigField(key: 'summaries.stale_sweep_limit', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Eski özet temizleme limiti', min: 10, max: 5000),
  ConfigField(key: 'summaries.ttl_ms', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Özet TTL (ms)', min: 3600000, max: 2592000000),
  ConfigField(key: 'templates.max_message_length', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Maksimum mesaj uzunluğu', min: 10, max: 5000),
  ConfigField(key: 'templates.max_recipients_per_call', type: 'int', doc: ConfigDoc.server, group: 'ops_caps', label: 'Çağrı başına maksimum alıcı', min: 1, max: 1000),
  ConfigField(key: 'templates.offer_ttl_days', type: 'int', doc: ConfigDoc.server, group: 'economy', label: 'Plan teklifi geçerlilik süresi (gün)', min: 1, max: 90),
  ConfigField(key: 'version.android_store_url', type: 'string', doc: ConfigDoc.critical, group: 'version', label: 'Play Store URL'),
  ConfigField(key: 'version.force_update', type: 'bool', doc: ConfigDoc.critical, group: 'version', label: 'Zorunlu güncelleme', sensitive: true),
  ConfigField(key: 'version.ios_store_url', type: 'string', doc: ConfigDoc.critical, group: 'version', label: 'App Store URL'),
  ConfigField(key: 'version.latest_android', type: 'string', doc: ConfigDoc.critical, group: 'version', label: 'Android en güncel sürüm'),
  ConfigField(key: 'version.latest_ios', type: 'string', doc: ConfigDoc.critical, group: 'version', label: 'iOS en güncel sürüm'),
  ConfigField(key: 'version.min_supported_android', type: 'string', doc: ConfigDoc.critical, group: 'version', label: 'Android minimum desteklenen sürüm'),
  ConfigField(key: 'version.min_supported_ios', type: 'string', doc: ConfigDoc.critical, group: 'version', label: 'iOS minimum desteklenen sürüm'),
  ConfigField(key: 'version.update_message', type: 'map<string,string>', doc: ConfigDoc.critical, group: 'version', label: 'Güncelleme mesajı (en/tr)'),
];
