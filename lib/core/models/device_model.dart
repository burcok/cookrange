import 'package:cloud_firestore/cloud_firestore.dart';

/// `users/{uid}/devices/{deviceId}` — one row per installation that has ever
/// logged in. Backs the multi-device session registry that replaced
/// AuthService's old single-session `current_session_id` kickout: instead of
/// forcing every OTHER device out the moment a new one logs in, each device
/// gets its own doc here and is only forced out when ITS OWN doc is flagged
/// `revoked`.
///
/// `revoked`/`revoked_at` are server-write-only — firestore.rules forbids a
/// client from setting them on `create` and excludes them from the `update`
/// allowlist. Only the `revokeDevice` callable (functions/devices.js) may set
/// them, because a bare Firestore flag can't actually invalidate a session;
/// only revoking the underlying Firebase Auth refresh token does that. See
/// [DeviceRegistryService]'s class doc for the full story.
class DeviceModel {
  final String id; // the device id (doc id) — see DeviceIdentityService
  final String platform; // 'iOS' | 'Android' | 'unknown'
  final String model;
  final String appVersion;
  final String osVersion;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;
  final String? pushToken;
  final bool revoked;
  final DateTime? revokedAt;

  const DeviceModel({
    required this.id,
    required this.platform,
    required this.model,
    required this.appVersion,
    required this.osVersion,
    this.createdAt,
    this.lastSeenAt,
    this.pushToken,
    this.revoked = false,
    this.revokedAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json, String id) {
    return DeviceModel(
      id: id,
      platform: json['platform'] as String? ?? 'unknown',
      model: json['model'] as String? ?? 'unknown',
      appVersion: json['app_version'] as String? ?? '',
      osVersion: json['os_version'] as String? ?? '',
      createdAt: json['created_at'] is Timestamp
          ? (json['created_at'] as Timestamp).toDate()
          : null,
      lastSeenAt: json['last_seen_at'] is Timestamp
          ? (json['last_seen_at'] as Timestamp).toDate()
          : null,
      pushToken: json['push_token'] as String?,
      revoked: json['revoked'] as bool? ?? false,
      revokedAt: json['revoked_at'] is Timestamp
          ? (json['revoked_at'] as Timestamp).toDate()
          : null,
    );
  }

  /// NOTE: intentionally symmetric with [fromJson] for completeness/parity
  /// with this codebase's model convention, but [DeviceRegistryService] does
  /// NOT use this for its writes — it hand-builds its update maps so that
  /// `revoked`/`revoked_at` can never accidentally be included in a client
  /// write (see that service's class doc comment).
  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'model': model,
      'app_version': appVersion,
      'os_version': osVersion,
      if (createdAt != null) 'created_at': Timestamp.fromDate(createdAt!),
      if (lastSeenAt != null) 'last_seen_at': Timestamp.fromDate(lastSeenAt!),
      if (pushToken != null) 'push_token': pushToken,
      'revoked': revoked,
      if (revokedAt != null) 'revoked_at': Timestamp.fromDate(revokedAt!),
    };
  }
}
