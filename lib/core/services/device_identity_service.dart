import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

import 'log_service.dart';

/// Mints and persists a stable per-install device id, used to key
/// `users/{uid}/devices/{deviceId}` (see [DeviceRegistryService]).
///
/// Persisted in `flutter_secure_storage` (iOS Keychain / Android
/// Keystore-backed EncryptedSharedPreferences) rather than SharedPreferences.
/// iOS Keychain items survive an app deletion, so a reinstall keeps the same
/// device id there. Android's Keystore-backed encrypted prefs do NOT survive
/// an uninstall, so a reinstalled Android device mints a fresh id — that's
/// fine, not a correctness issue: the OLD `devices/{id}` doc just becomes an
/// orphaned row that a later phase's server-side staleness prune cleans up;
/// nothing about this device's own session depends on the old id staying
/// valid.
class DeviceIdentityService {
  static final DeviceIdentityService _instance =
      DeviceIdentityService._internal();
  factory DeviceIdentityService() => _instance;
  DeviceIdentityService._internal();

  final LogService _log = LogService();
  final String _serviceName = 'DeviceIdentityService';

  static const String _deviceIdKey = 'cookrange_device_id_v1';
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String? _cachedId;

  /// This install's stable device id — minted and persisted on first call,
  /// the same value on every subsequent call (in-memory cached after the
  /// first read so repeat calls don't hit secure storage).
  Future<String> get deviceId async {
    final cached = _cachedId;
    if (cached != null) return cached;

    try {
      String? id = await _secureStorage.read(key: _deviceIdKey);
      if (id == null || id.isEmpty) {
        id = const Uuid().v4();
        await _secureStorage.write(key: _deviceIdKey, value: id);
        _log.info('Minted new device id', service: _serviceName);
      }
      _cachedId = id;
      return id;
    } catch (e, s) {
      // Fail-soft: secure storage being unavailable must never block login.
      // Mint an ephemeral (unpersisted) id so the caller still gets a usable
      // value for this session — worst case this install re-registers as a
      // "new device" next launch, which is a cosmetic annoyance, not a
      // correctness or security problem.
      _log.error(
          'Failed to read/persist device id; using an ephemeral one for this session',
          service: _serviceName,
          error: e,
          stackTrace: s);
      final ephemeral = const Uuid().v4();
      _cachedId = ephemeral;
      return ephemeral;
    }
  }
}
