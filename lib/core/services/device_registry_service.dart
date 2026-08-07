import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/device_model.dart';
import 'device_identity_service.dart';
import 'log_service.dart';

/// Manages `users/{uid}/devices/{deviceId}` — the multi-device session
/// registry that replaces AuthService's old single-session kickout
/// (`current_session_id`: logging in on a second device used to force-sign-out
/// the first). Each installation gets its own doc here; AuthService watches
/// only ITS OWN doc for `revoked` and signs out locally when that flips true.
///
/// IMPORTANT — this service must NEVER write `revoked`/`revoked_at`.
/// firestore.rules forbids both keys outright on `create` and excludes them
/// from the `update` allowlist, so a client write attempt would simply be
/// rejected — but the deeper reason is that a bare Firestore flag can't
/// actually invalidate a session. Only revoking the underlying Firebase Auth
/// refresh token does that, and only a Cloud Function (Admin SDK) can do that.
/// [signOutThisDevice]/[signOutAllOtherDevices]/[signOutDevice] all go through
/// the `revokeDevice` callable (functions/devices.js) for exactly this reason.
class DeviceRegistryService {
  static final DeviceRegistryService _instance =
      DeviceRegistryService._internal();
  factory DeviceRegistryService() => _instance;
  DeviceRegistryService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final LogService _log = LogService();
  final String _serviceName = 'DeviceRegistryService';

  CollectionReference<Map<String, dynamic>> _devicesRef(String uid) =>
      _db.collection('users').doc(uid).collection('devices');

  /// Merge-writes this device's platform/model/app_version/os_version/
  /// push_token/last_seen_at (+ created_at on first write only). Call on
  /// login and on app-resume — safe to call repeatedly, it never regresses
  /// `created_at` and never touches `revoked`/`revoked_at`.
  Future<void> registerOrTouchThisDevice({required String uid}) async {
    try {
      final deviceId = await DeviceIdentityService().deviceId;
      final ctx = await _collectDeviceContext();
      final pushToken = await _fetchPushToken();
      final docRef = _devicesRef(uid).doc(deviceId);

      // Mirrors firestore_service.dart's handleUserLogin idiom: read first so
      // `created_at` is only ever set once, never overwritten by a later
      // touch (a plain merge-set would otherwise stomp it every call).
      final existing = await docRef.get();

      await docRef.set({
        'platform': ctx.platform,
        'model': ctx.model,
        'app_version': ctx.appVersion,
        'os_version': ctx.osVersion,
        'last_seen_at': FieldValue.serverTimestamp(),
        if (pushToken != null) 'push_token': pushToken,
        if (!existing.exists) 'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _log.info('Registered/touched device $deviceId for user $uid',
          service: _serviceName);
    } catch (e, s) {
      _log.error('registerOrTouchThisDevice failed for user $uid',
          service: _serviceName, error: e, stackTrace: s);
    }
  }

  /// True once THIS device's own doc is flagged `revoked` — AuthService signs
  /// out locally the moment this emits `true`. Absorbs stream errors (logged,
  /// not rethrown) so a transient permission/network blip can never crash the
  /// listener that's watching for a forced sign-out.
  Stream<bool> watchThisDeviceRevoked(String uid, String deviceId) {
    return _devicesRef(uid)
        .doc(deviceId)
        .snapshots()
        .map((snap) => snap.data()?['revoked'] == true)
        .handleError((Object e, StackTrace s) {
      _log.error('watchThisDeviceRevoked stream error for $uid/$deviceId',
          service: _serviceName, error: e, stackTrace: s);
    });
  }

  /// Every device on this account, most-recently-active first. Plain
  /// single-field `orderBy` — no composite index needed. Backs the device
  /// management screen.
  Stream<List<DeviceModel>> watchMyDevices(String uid) {
    return _devicesRef(uid)
        .orderBy('last_seen_at', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => DeviceModel.fromJson(d.data(), d.id)).toList())
        .handleError((Object e, StackTrace s) {
      _log.error('watchMyDevices stream error for $uid',
          service: _serviceName, error: e, stackTrace: s);
    });
  }

  /// Revokes THIS install via the `revokeDevice` callable. AuthService's
  /// [watchThisDeviceRevoked] subscription is what actually reacts to this
  /// (local sign-out + dialog) — this call only flips the server-side flag
  /// and revokes the underlying Auth refresh token.
  Future<void> signOutThisDevice() async {
    final deviceId = await DeviceIdentityService().deviceId;
    await signOutDevice(deviceId);
  }

  /// Revokes every OTHER device on this account, sparing this one. See
  /// functions/devices.js's doc comment on `revokeDevice` for the honest
  /// limitation: Firebase Auth's `revokeRefreshTokens` is per-USER, not
  /// per-device, so this can — eventually — also sign THIS device out once
  /// its own token next refreshes.
  Future<void> signOutAllOtherDevices() async {
    final deviceId = await DeviceIdentityService().deviceId;
    try {
      await FirebaseFunctions.instance.httpsCallable('revokeDevice').call({
        'deviceId': deviceId,
        'allOthers': true,
      });
      _log.info('signOutAllOtherDevices: sparing $deviceId',
          service: _serviceName);
    } catch (e, s) {
      _log.error('signOutAllOtherDevices failed (sparing $deviceId)',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
    }
  }

  /// Revokes the named device (which may or may not be this install) via the
  /// `revokeDevice` callable. Backs the per-row "sign out" action on the
  /// device management screen. [targetDeviceId] must be one of the caller's
  /// own devices — the callable scopes this automatically since it only ever
  /// looks under `users/{callerUid}/devices`.
  Future<void> signOutDevice(String targetDeviceId) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('revokeDevice').call({
        'deviceId': targetDeviceId,
        'allOthers': false,
      });
      _log.info('signOutDevice: revoked $targetDeviceId',
          service: _serviceName);
    } catch (e, s) {
      _log.error('signOutDevice failed for $targetDeviceId',
          service: _serviceName, error: e, stackTrace: s);
      rethrow;
    }
  }

  Future<String?> _fetchPushToken() async {
    try {
      return await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
    } catch (e, s) {
      _log.error('Failed to fetch FCM token for device registry',
          service: _serviceName, error: e, stackTrace: s);
      return null;
    }
  }

  Future<_DeviceContext> _collectDeviceContext() async {
    var platform = 'unknown';
    var model = 'unknown';
    try {
      if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        platform = 'iOS';
        model = info.name; // e.g. "iPhone 15 Pro"
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        platform = 'Android';
        model = info.model;
      }
    } catch (e, s) {
      _log.error('Failed reading device_info_plus data',
          service: _serviceName, error: e, stackTrace: s);
    }

    var appVersion = '';
    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = pkg.version;
    } catch (e, s) {
      _log.error('Failed reading package_info_plus data',
          service: _serviceName, error: e, stackTrace: s);
    }

    return _DeviceContext(
      platform: platform,
      model: model,
      appVersion: appVersion,
      osVersion: Platform.operatingSystemVersion,
    );
  }
}

class _DeviceContext {
  final String platform;
  final String model;
  final String appVersion;
  final String osVersion;

  const _DeviceContext({
    required this.platform,
    required this.model,
    required this.appVersion,
    required this.osVersion,
  });
}
