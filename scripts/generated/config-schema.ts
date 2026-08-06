// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Source of truth: functions/config_schema.json
// Regenerate:       node scripts/gen_config_schema.js
//
// Any change to a setting's default, bounds, or metadata belongs in
// functions/config_schema.json, never in this file directly — a hand-edit here
// will be silently overwritten (and CI's `git diff --exit-code` check on
// these generated files will catch a stale regeneration either way).

export type ConfigDoc = 'critical' | 'client' | 'server';

// Which `app_config/{doc}` a setting is read from — see DECISIONS.md ADR-023
// (placement rule: a setting lives in the most restrictive doc that still
// contains every one of its readers).
export interface ConfigField {
  key: string;
  type: string;
  doc: ConfigDoc;
  group: string;
  label: string;
  sensitive: boolean;
  min?: number;
  max?: number;
  enumValues?: string[];
}

// One schema-declared field descriptor per admin-editable setting — drives
// the config editor's form generation and validation (DECISIONS.md ADR-023).
// Carries no `default`, same deliberate split as kConfigDefaults in
// app_config_defaults.g.dart (the Dart counterpart of this file).
export const configSchema: ConfigField[] = [
  { key: 'ai.allowed_models', type: 'string_list', doc: 'server', group: 'ai_server', label: 'İzin verilen model listesi', sensitive: true },
  { key: 'ai.free_daily_limit', type: 'int', doc: 'client', group: 'ai', label: 'Ücretsiz günlük AI hakkı', sensitive: true, min: 0, max: 100 },
  { key: 'ai.max_messages', type: 'int', doc: 'server', group: 'ai_server', label: 'Maksimum mesaj sayısı (sohbet)', sensitive: false, min: 1, max: 200 },
  { key: 'ai.max_retries', type: 'int', doc: 'client', group: 'ai', label: 'AI çağrısı yeniden deneme sayısı', sensitive: false, min: 0, max: 10 },
  { key: 'ai.max_tokens', type: 'int', doc: 'server', group: 'ai_server', label: 'Maksimum çıktı token (varsayılan)', sensitive: false, min: 256, max: 32000 },
  { key: 'ai.max_tokens_by_type', type: 'map<string,int>', doc: 'server', group: 'ai_server', label: 'Sorgu tipine göre maksimum token', sensitive: false },
  { key: 'ai.max_total_chars', type: 'int', doc: 'server', group: 'ai_server', label: 'Maksimum toplam karakter (payload)', sensitive: false, min: 1000, max: 200000 },
  { key: 'ai.model_by_type', type: 'map<string,string>', doc: 'server', group: 'ai_server', label: 'Sorgu tipine göre model', sensitive: true },
  { key: 'ai.model_pricing', type: 'map<string,object>', doc: 'server', group: 'ai_server', label: 'Model fiyatlandırması (USD/1M token)', sensitive: true },
  { key: 'ai.premium_daily_limit', type: 'int', doc: 'client', group: 'ai', label: 'Premium günlük AI hakkı', sensitive: true, min: 0, max: 500 },
  { key: 'ai.rate_max_in_window', type: 'int', doc: 'server', group: 'ai_server', label: 'Pencere başına maksimum çağrı', sensitive: true, min: 1, max: 1000 },
  { key: 'ai.rate_window_ms', type: 'int', doc: 'server', group: 'ai_server', label: 'AI hız sınırı penceresi (ms)', sensitive: true, min: 1000, max: 3600000 },
  { key: 'ai.retry_delay_s', type: 'int', doc: 'client', group: 'ai', label: 'Yeniden deneme gecikmesi (sn)', sensitive: false, min: 0, max: 30 },
  { key: 'ai.temperature', type: 'double', doc: 'server', group: 'ai_server', label: 'Model sıcaklığı', sensitive: false, min: 0, max: 1 },
  { key: 'ai.text_model', type: 'string', doc: 'client', group: 'ai', label: 'Metin modeli (override)', sensitive: false },
  { key: 'ai.timeout_s', type: 'int', doc: 'client', group: 'ai', label: 'AI istek zaman aşımı (sn)', sensitive: false, min: 10, max: 300 },
  { key: 'ai.vision_model', type: 'string', doc: 'client', group: 'ai', label: 'Görsel modeli (override)', sensitive: false },
  { key: 'announcement.cta_url', type: 'string', doc: 'critical', group: 'announcement', label: 'Duyuru CTA URL', sensitive: false },
  { key: 'announcement.dismissible', type: 'bool', doc: 'critical', group: 'announcement', label: 'Kapatılabilir', sensitive: false },
  { key: 'announcement.enabled', type: 'bool', doc: 'critical', group: 'announcement', label: 'Duyuru aktif', sensitive: false },
  { key: 'announcement.id', type: 'string', doc: 'critical', group: 'announcement', label: 'Duyuru ID (dismiss tracking)', sensitive: false },
  { key: 'announcement.message', type: 'map<string,string>', doc: 'critical', group: 'announcement', label: 'Duyuru mesajı (en/tr)', sensitive: false },
  { key: 'announcement.type', type: 'enum', doc: 'critical', group: 'announcement', label: 'Duyuru tipi', sensitive: false, enumValues: ['info', 'warning', 'success', 'promo'] },
  { key: 'client.check_in_radius_m', type: 'int', doc: 'client', group: 'client_misc', label: 'Salon check-in yarıçapı (m)', sensitive: false, min: 10, max: 1000 },
  { key: 'client.max_dishes_per_prompt', type: 'int', doc: 'client', group: 'client_misc', label: 'Prompt başına maksimum yemek sayısı', sensitive: false, min: 20, max: 500 },
  { key: 'client.min_age_years', type: 'int', doc: 'critical', group: 'compliance', label: 'Minimum yaş (KVKK/GDPR)', sensitive: true, min: 13, max: 21 },
  { key: 'client.referral_pending_code_ttl_days', type: 'int', doc: 'critical', group: 'referral', label: 'Bekleyen referans kodu TTL (gün)', sensitive: false, min: 1, max: 30 },
  { key: 'client.weekly_meal_plan_expiry_days', type: 'int', doc: 'client', group: 'client_misc', label: 'Haftalık plan geçerlilik süresi (gün)', sensitive: false, min: 1, max: 30 },
  { key: 'cost.pricing', type: 'object', doc: 'server', group: 'economy', label: 'Maliyet/gelir varsayımları (admin cost dashboard)', sensitive: true },
  { key: 'economy.gym_commission_try', type: 'map<string,double>', doc: 'server', group: 'economy', label: 'Salon komisyonu (₺, ürün başına)', sensitive: true },
  { key: 'economy.referral_commission_try', type: 'double', doc: 'server', group: 'economy', label: 'Referans komisyonu (₺, sabit)', sensitive: true, min: 0, max: 1000 },
  { key: 'economy.referral_max_uses', type: 'int', doc: 'server', group: 'economy', label: 'Referans kodu maksimum kullanım', sensitive: false, min: 1, max: 1000 },
  { key: 'economy.referral_reward_days', type: 'int', doc: 'server', group: 'economy', label: 'Referans ödülü (gün)', sensitive: true, min: 1, max: 90 },
  { key: 'economy.streak_freeze_grant_amount', type: 'int', doc: 'server', group: 'economy', label: 'Yeni kullanıcı streak dondurma hediyesi', sensitive: false, min: 0, max: 5 },
  { key: 'endpoints.ai_proxy_url', type: 'string', doc: 'client', group: 'ai', label: 'AI proxy URL (override)', sensitive: true },
  { key: 'engagement.contrib_leaderboard_groups_per_run', type: 'int', doc: 'server', group: 'ops_caps', label: 'Canlı katkı panosu — çalıştırma başına grup sayısı', sensitive: false, min: 10, max: 5000 },
  { key: 'engagement.contrib_leaderboard_top_n', type: 'int', doc: 'server', group: 'gamification_server', label: 'Canlı katkı panosu — gösterilen üye sayısı', sensitive: false, min: 1, max: 50 },
  { key: 'engagement.credit_table', type: 'map<string,object>', doc: 'server', group: 'gamification_server', label: 'AI kredi kazanım tablosu', sensitive: true },
  { key: 'engagement.weekly_candidate_buffer', type: 'int', doc: 'server', group: 'ops_caps', label: 'Haftalık aday tampon boyutu', sensitive: false, min: 1, max: 100 },
  { key: 'engagement.weekly_contrib_groups_per_run', type: 'int', doc: 'server', group: 'ops_caps', label: 'Haftalık katkı — çalıştırma başına grup sayısı', sensitive: false, min: 10, max: 5000 },
  { key: 'engagement.weekly_min_active_members', type: 'int', doc: 'server', group: 'gamification_server', label: 'Haftalık grup katkı — minimum aktif üye', sensitive: true, min: 2, max: 50 },
  { key: 'engagement.weekly_top_n', type: 'int', doc: 'server', group: 'gamification_server', label: 'Haftalık kazanan sayısı', sensitive: false, min: 1, max: 20 },
  { key: 'features.chat', type: 'bool', doc: 'critical', group: 'features', label: 'Sohbet', sensitive: false },
  { key: 'features.coach', type: 'bool', doc: 'critical', group: 'features', label: 'Koç ekosistemi', sensitive: true },
  { key: 'features.community', type: 'bool', doc: 'critical', group: 'features', label: 'Topluluk', sensitive: false },
  { key: 'features.fitness_twin', type: 'bool', doc: 'critical', group: 'features', label: 'Fitness ikizi (AI)', sensitive: false },
  { key: 'features.food_scan', type: 'bool', doc: 'critical', group: 'features', label: 'Yemek fotoğrafı tarama', sensitive: false },
  { key: 'features.gym', type: 'bool', doc: 'critical', group: 'features', label: 'Spor salonu ekosistemi', sensitive: true },
  { key: 'features.gym_attribution', type: 'bool', doc: 'critical', group: 'features', label: 'Salon atfetme/komisyon UI', sensitive: false },
  { key: 'features.gym_invite_codes', type: 'bool', doc: 'critical', group: 'features', label: 'Salon davet kodları', sensitive: false },
  { key: 'features.marketplace', type: 'bool', doc: 'critical', group: 'features', label: 'Pazar yeri (genel)', sensitive: true },
  { key: 'features.meal_plan_templates', type: 'bool', doc: 'critical', group: 'features', label: 'Plan şablonları', sensitive: false },
  { key: 'features.nutrition_analytics', type: 'bool', doc: 'critical', group: 'features', label: 'Beslenme analitiği', sensitive: false },
  { key: 'features.photo_analysis', type: 'bool', doc: 'critical', group: 'features', label: 'Fotoğraf analizi (AI)', sensitive: false },
  { key: 'features.programs', type: 'bool', doc: 'critical', group: 'features', label: 'Programlar (pazar yeri)', sensitive: true },
  { key: 'features.referral', type: 'bool', doc: 'critical', group: 'features', label: 'Referans sistemi', sensitive: false },
  { key: 'features.squad', type: 'bool', doc: 'critical', group: 'features', label: 'Squad', sensitive: false },
  { key: 'features.voice_assistant', type: 'bool', doc: 'critical', group: 'features', label: 'Sesli asistan', sensitive: false },
  { key: 'features.weekly_recap', type: 'bool', doc: 'critical', group: 'features', label: 'Haftalık özet', sensitive: false },
  { key: 'gamification.achievement_points', type: 'map<string,int>', doc: 'server', group: 'gamification_server', label: 'Başarım puanları', sensitive: true },
  { key: 'gamification.group_streak_achievement_threshold', type: 'int', doc: 'server', group: 'gamification_server', label: 'Grup streak başarım eşiği (hafta)', sensitive: false, min: 1, max: 52 },
  { key: 'gamification.gym_regular_checkin_threshold', type: 'int', doc: 'server', group: 'gamification_server', label: '\'Düzenli salon üyesi\' check-in eşiği', sensitive: false, min: 1, max: 100 },
  { key: 'gamification.level_curve_coefficient', type: 'int', doc: 'client', group: 'gamification', label: 'Seviye eğrisi katsayısı', sensitive: true, min: 10, max: 200 },
  { key: 'gamification.local_utc_offset_hours', type: 'int', doc: 'server', group: 'gamification_server', label: 'Yerel saat dilimi ofseti (UTC+)', sensitive: false, min: -12, max: 14 },
  { key: 'gamification.max_level', type: 'int', doc: 'client', group: 'gamification', label: 'Maksimum seviye', sensitive: false, min: 50, max: 9999 },
  { key: 'gamification.max_xp_events_per_call', type: 'int', doc: 'server', group: 'gamification_server', label: 'syncProgress çağrısı başına maksimum XP olayı', sensitive: false, min: 1, max: 100 },
  { key: 'gamification.tier_level_floor', type: 'map<string,int>', doc: 'server', group: 'gamification_server', label: 'İtibar kademesi seviye eşikleri', sensitive: true },
  { key: 'gamification.xp_table', type: 'map<string,object>', doc: 'server', group: 'gamification_server', label: 'XP tablosu', sensitive: true },
  { key: 'groups.activity_comments_scan_limit', type: 'int', doc: 'server', group: 'ops_caps', label: 'Aktivite skoru — yorum tarama limiti', sensitive: false, min: 10, max: 5000 },
  { key: 'groups.activity_groups_per_run', type: 'int', doc: 'server', group: 'ops_caps', label: 'Aktivite skoru — çalıştırma başına grup sayısı', sensitive: false, min: 10, max: 5000 },
  { key: 'groups.activity_half_life_hours', type: 'double', doc: 'server', group: 'ops_caps', label: 'Aktivite skoru yarı ömrü (saat)', sensitive: false, min: 1, max: 168 },
  { key: 'groups.activity_signal_limit', type: 'int', doc: 'server', group: 'ops_caps', label: 'Aktivite skoru — sinyal başına tarama limiti', sensitive: false, min: 10, max: 5000 },
  { key: 'groups.activity_window_hours', type: 'int', doc: 'server', group: 'ops_caps', label: 'Aktivite skoru penceresi (saat)', sensitive: false, min: 1, max: 168 },
  { key: 'maintenance.enabled', type: 'bool', doc: 'critical', group: 'maintenance', label: 'Bakım modu', sensitive: true },
  { key: 'maintenance.message', type: 'map<string,string>', doc: 'critical', group: 'maintenance', label: 'Bakım mesajı (en/tr)', sensitive: false },
  { key: 'media.vision_daily_cap', type: 'int', doc: 'server', group: 'ai_server', label: 'Günlük Vision taraması limiti', sensitive: true, min: 10, max: 100000 },
  { key: 'moderation.action_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Moderasyon aksiyonu hız sınırı', sensitive: true },
  { key: 'moderation.appeal_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'İtiraz gönderme hız sınırı', sensitive: true },
  { key: 'moderation.auto_restrict_flag_threshold', type: 'int', doc: 'server', group: 'moderation', label: 'Otomatik kısıtlama bayrak eşiği', sensitive: true, min: 1, max: 50 },
  { key: 'moderation.checkin_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Check-in hız sınırı', sensitive: true },
  { key: 'moderation.comment_min_text_length', type: 'int', doc: 'server', group: 'moderation', label: 'Yorum minimum metin uzunluğu', sensitive: false, min: 0, max: 500 },
  { key: 'moderation.comment_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Yorum oluşturma hız sınırı', sensitive: true },
  { key: 'moderation.concentration_distinct_max', type: 'int', doc: 'server', group: 'moderation', label: 'Yoğunlaşma tespiti — maksimum farklı kaynak', sensitive: true, min: 1, max: 50 },
  { key: 'moderation.concentration_downweight', type: 'double', doc: 'server', group: 'moderation', label: 'Yoğunlaşma ağırlık cezası', sensitive: true, min: 0, max: 1 },
  { key: 'moderation.concentration_window', type: 'int', doc: 'server', group: 'moderation', label: 'Yoğunlaşma tespiti — pencere', sensitive: false, min: 1, max: 200 },
  { key: 'moderation.duplicate_recent_window', type: 'int', doc: 'server', group: 'moderation', label: 'Yinelenen içerik karşılaştırma penceresi', sensitive: false, min: 1, max: 200 },
  { key: 'moderation.duplicate_similarity_threshold', type: 'double', doc: 'server', group: 'moderation', label: 'Yinelenen içerik benzerlik eşiği', sensitive: true, min: 0.5, max: 1 },
  { key: 'moderation.follow_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Takip etme hız sınırı', sensitive: true },
  { key: 'moderation.group_create_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Grup oluşturma hız sınırı', sensitive: true },
  { key: 'moderation.message_min_text_length', type: 'int', doc: 'server', group: 'moderation', label: 'Mesaj minimum metin uzunluğu', sensitive: false, min: 0, max: 500 },
  { key: 'moderation.message_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Sohbet mesajı hız sınırı', sensitive: true },
  { key: 'moderation.min_account_age_ms', type: 'int', doc: 'server', group: 'moderation', label: 'Minimum hesap yaşı (ms)', sensitive: true, min: 0, max: 2592000000 },
  { key: 'moderation.post_min_text_length', type: 'int', doc: 'server', group: 'moderation', label: 'Gönderi minimum metin uzunluğu', sensitive: false, min: 0, max: 500 },
  { key: 'moderation.post_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Gönderi oluşturma hız sınırı', sensitive: true },
  { key: 'moderation.reaction_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Beğeni/tepki hız sınırı', sensitive: true },
  { key: 'moderation.reciprocity_downweight', type: 'double', doc: 'server', group: 'moderation', label: 'Karşılıklılık ağırlık cezası', sensitive: true, min: 0, max: 1 },
  { key: 'moderation.reciprocity_min_pair_sample', type: 'int', doc: 'server', group: 'moderation', label: 'Karşılıklılık eşiği — minimum örnek', sensitive: true, min: 1, max: 100 },
  { key: 'moderation.reciprocity_ratio_threshold', type: 'double', doc: 'server', group: 'moderation', label: 'Karşılıklılık oran eşiği', sensitive: true, min: 0, max: 1 },
  { key: 'moderation.report_rate_limit', type: 'object', doc: 'server', group: 'moderation', label: 'Rapor gönderme hız sınırı', sensitive: true },
  { key: 'presence.max_friends_fanout', type: 'int', doc: 'server', group: 'ops_caps', label: 'Arkadaş bildirimi fan-out limiti', sensitive: false, min: 10, max: 5000 },
  { key: 'presence.notify_log_ttl_days', type: 'int', doc: 'server', group: 'presence', label: 'Bildirim log TTL (gün)', sensitive: false, min: 1, max: 30 },
  { key: 'presence.presence_ttl_ms', type: 'int', doc: 'server', group: 'presence', label: 'Oturum geçerlilik süresi (ms)', sensitive: false, min: 600000, max: 86400000 },
  { key: 'presence.quiet_hours_end', type: 'int', doc: 'server', group: 'presence', label: 'Sessiz saat bitişi (yerel saat)', sensitive: false, min: 0, max: 23 },
  { key: 'presence.quiet_hours_start', type: 'int', doc: 'server', group: 'presence', label: 'Sessiz saat başlangıcı (yerel saat)', sensitive: false, min: 0, max: 23 },
  { key: 'presence.rate_limit_reentry_ms', type: 'int', doc: 'server', group: 'presence', label: 'Yeniden giriş hız sınırı (ms)', sensitive: false, min: 60000, max: 3600000 },
  { key: 'presence.stale_sweep_limit', type: 'int', doc: 'server', group: 'ops_caps', label: 'Eski oturum temizleme limiti', sensitive: false, min: 10, max: 5000 },
  { key: 'presence.timestamp_skew_ms', type: 'int', doc: 'server', group: 'presence', label: 'İzin verilen saat sapması (ms)', sensitive: true, min: 10000, max: 3600000 },
  { key: 'privacy.k_anonymity_threshold', type: 'int', doc: 'client', group: 'privacy', label: 'K-anonimlik eşiği (salon analitiği)', sensitive: true, min: 2, max: 50 },
  { key: 'purchases.products', type: 'map<string,object>', doc: 'server', group: 'economy', label: 'Ürün kataloğu', sensitive: true },
  { key: 'rollout.coach', type: 'int', doc: 'critical', group: 'rollout', label: 'Koç — kademeli açılım %', sensitive: false, min: 0, max: 100 },
  { key: 'rollout.gym', type: 'int', doc: 'critical', group: 'rollout', label: 'Salon — kademeli açılım %', sensitive: false, min: 0, max: 100 },
  { key: 'rollout.programs', type: 'int', doc: 'critical', group: 'rollout', label: 'Programlar — kademeli açılım %', sensitive: false, min: 0, max: 100 },
  { key: 'rollout.squad', type: 'int', doc: 'critical', group: 'rollout', label: 'Squad — kademeli açılım %', sensitive: false, min: 0, max: 100 },
  { key: 'summaries.gen_rate_max_in_window', type: 'int', doc: 'server', group: 'ops_caps', label: 'Pencere başına maksimum özet', sensitive: false, min: 1, max: 10 },
  { key: 'summaries.gen_rate_window_ms', type: 'int', doc: 'server', group: 'ops_caps', label: 'Özet üretim hız penceresi (ms)', sensitive: false, min: 3600000, max: 604800000 },
  { key: 'summaries.max_scope_members_scan', type: 'int', doc: 'server', group: 'ops_caps', label: 'Kapsam üyesi tarama limiti', sensitive: false, min: 10, max: 5000 },
  { key: 'summaries.stale_sweep_limit', type: 'int', doc: 'server', group: 'ops_caps', label: 'Eski özet temizleme limiti', sensitive: false, min: 10, max: 5000 },
  { key: 'summaries.ttl_ms', type: 'int', doc: 'server', group: 'ops_caps', label: 'Özet TTL (ms)', sensitive: false, min: 3600000, max: 2592000000 },
  { key: 'templates.max_message_length', type: 'int', doc: 'server', group: 'ops_caps', label: 'Maksimum mesaj uzunluğu', sensitive: false, min: 10, max: 5000 },
  { key: 'templates.max_recipients_per_call', type: 'int', doc: 'server', group: 'ops_caps', label: 'Çağrı başına maksimum alıcı', sensitive: false, min: 1, max: 1000 },
  { key: 'templates.offer_ttl_days', type: 'int', doc: 'server', group: 'economy', label: 'Plan teklifi geçerlilik süresi (gün)', sensitive: false, min: 1, max: 90 },
  { key: 'version.android_store_url', type: 'string', doc: 'critical', group: 'version', label: 'Play Store URL', sensitive: false },
  { key: 'version.force_update', type: 'bool', doc: 'critical', group: 'version', label: 'Zorunlu güncelleme', sensitive: true },
  { key: 'version.ios_store_url', type: 'string', doc: 'critical', group: 'version', label: 'App Store URL', sensitive: false },
  { key: 'version.latest_android', type: 'string', doc: 'critical', group: 'version', label: 'Android en güncel sürüm', sensitive: false },
  { key: 'version.latest_ios', type: 'string', doc: 'critical', group: 'version', label: 'iOS en güncel sürüm', sensitive: false },
  { key: 'version.min_supported_android', type: 'string', doc: 'critical', group: 'version', label: 'Android minimum desteklenen sürüm', sensitive: false },
  { key: 'version.min_supported_ios', type: 'string', doc: 'critical', group: 'version', label: 'iOS minimum desteklenen sürüm', sensitive: false },
  { key: 'version.update_message', type: 'map<string,string>', doc: 'critical', group: 'version', label: 'Güncelleme mesajı (en/tr)', sensitive: false },
];
