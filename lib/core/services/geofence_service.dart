import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:native_geofence/native_geofence.dart';

import '../../firebase_options.dart';

/// Faz 1 §1.2 — thin wrapper around `native_geofence`: one region per
/// tracked gym (capped at 3 by [GymPresenceService]), and the client half of
/// the enter/dwell/exit protocol `functions/presence.js` (Faz 1 §1.5)
/// validates server-side. No raw coordinates are ever read out of a
/// callback here, let alone sent anywhere — see the doc comment on
/// [geofenceTriggered] below for why that's actually guaranteed, not just
/// a promise.
///
/// **Platform gap, and why there's no Dart `Timer` anywhere in this file:**
/// Android's native geofencing keeps this alive via a real foreground
/// service (`NativeGeofenceForegroundService`, declared in the manifest) —
/// its own OS-level `loiteringDelay` timer is what confirms dwell, so
/// registering `{enter, exit, dwell}` there is fully reliable. iOS has no
/// such thing: `native_geofence` refuses to even register a bare `{dwell}`
/// trigger on iOS (it throws), and more fundamentally, iOS wakes a
/// suspended/killed app for only a few seconds to run this callback — an
/// in-memory Dart `Timer` set here would almost certainly never fire, since
/// the process is suspended again long before 5 minutes pass. Rather than
/// ship a timer that quietly never fires (worse than no timer — it creates
/// false confidence), iOS registers only `{enter, exit}` and treats a real
/// `enter` as an immediate `dwell` call. The only real cost is that someone
/// who steps in and immediately leaves gets a very short session on iOS
/// specifically (closed moments later by the matching `exit`) — an honest,
/// documented simplification, not silently broken behavior. Likewise,
/// neither platform runs a client-side exit-debounce timer for the same
/// reason; `recordPresenceEvent`'s own 10-minute same-gym re-entry rate
/// limit (`functions/presence.js`) is what actually absorbs doorway GPS
/// flutter, since that check lives on the server and doesn't depend on any
/// process surviving in the background.
class GeofenceService {
  static const _regionIdPrefix = 'gym_';
  static const _androidLoiteringDelay = Duration(minutes: 5);

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await NativeGeofenceManager.instance.initialize();
    _initialized = true;
  }

  static String regionIdFor(String gymId) => '$_regionIdPrefix$gymId';

  static String gymIdFromRegionId(String regionId) =>
      regionId.startsWith(_regionIdPrefix)
          ? regionId.substring(_regionIdPrefix.length)
          : regionId;

  /// Registers (or replaces, if [gymId] is already registered) a geofence
  /// region for one gym. Caller (`GymPresenceService`) is responsible for
  /// the 3-gym cap, consent, and permission checks — this is the mechanical
  /// layer only.
  static Future<void> registerGym({
    required String gymId,
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    await ensureInitialized();
    final triggers = Platform.isIOS
        ? {GeofenceEvent.enter, GeofenceEvent.exit}
        : {GeofenceEvent.enter, GeofenceEvent.exit, GeofenceEvent.dwell};
    await NativeGeofenceManager.instance.createGeofence(
      Geofence(
        id: regionIdFor(gymId),
        location: Location(latitude: latitude, longitude: longitude),
        radiusMeters: radiusMeters.toDouble(),
        triggers: triggers,
        iosSettings: const IosGeofenceSettings(initialTrigger: false),
        androidSettings: const AndroidGeofenceSettings(
          initialTriggers: {},
          loiteringDelay: _androidLoiteringDelay,
        ),
      ),
      geofenceTriggered,
    );
  }

  static Future<void> unregisterGym(String gymId) async {
    await ensureInitialized();
    try {
      await NativeGeofenceManager.instance
          .removeGeofenceById(regionIdFor(gymId));
    } on NativeGeofenceException catch (e) {
      // Already gone (e.g. geofenceNotFound) — nothing left to clean up.
      debugPrint('GeofenceService.unregisterGym($gymId): $e');
    }
  }

  static Future<void> unregisterAll() async {
    await ensureInitialized();
    await NativeGeofenceManager.instance.removeAllGeofences();
  }

  /// Gym ids (not raw region ids) currently registered with the OS.
  static Future<List<String>> registeredGymIds() async {
    await ensureInitialized();
    final ids = await NativeGeofenceManager.instance.getRegisteredGeofenceIds();
    return ids.map(gymIdFromRegionId).toList();
  }
}

/// The single background+foreground geofence callback — MUST be a
/// top-level function (native_geofence looks it up by handle, not by
/// reference, so it cannot be a method or closure).
///
/// [params.location] — where the OS thinks the device was when the event
/// fired — is deliberately never read here. It's Android-only and
/// frequently null even there (iOS never provides it at all — see
/// `native_geofence`'s own [GeofenceCallbackParams] doc comment); more to
/// the point, forwarding it anywhere would violate the one property the
/// audit specifically praised this codebase for (`CheckInModel` never
/// carrying coordinates) — so this function simply never touches that
/// field, by construction, not by a check that could be forgotten.
@pragma('vm:entry-point')
Future<void> geofenceTriggered(GeofenceCallbackParams params) async {
  // This runs in native_geofence's own background isolate when the app is
  // backgrounded or fully killed — none of main()'s state exists here, so
  // Firebase needs re-initializing. Firebase.apps.isEmpty guards the case
  // where this fires while the app's normal engine (and Firebase) is
  // already up.
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint('geofenceTriggered: Firebase init failed: $e');
    return;
  }

  for (final geofence in params.geofences) {
    final gymId = GeofenceService.gymIdFromRegionId(geofence.id);
    final type = switch (params.event) {
      GeofenceEvent.enter =>
        // iOS has no native dwell — treat enter as an immediate dwell
        // there (see the platform-gap doc comment on GeofenceService).
        // Android's real enter is just logged; its native loiteringDelay
        // timer is what will separately deliver GeofenceEvent.dwell.
        Platform.isIOS ? 'dwell' : 'enter',
      GeofenceEvent.dwell => 'dwell',
      GeofenceEvent.exit => 'exit',
    };
    await _recordEvent(gymId, type);
  }
}

Future<void> _recordEvent(String gymId, String type) async {
  try {
    await FirebaseFunctions.instance
        .httpsCallable('recordPresenceEvent')
        .call<Map<String, dynamic>>({
      'gymId': gymId,
      'type': type,
      'clientTimestamp': DateTime.now().toIso8601String(),
    });
    debugPrint('geofenceTriggered: recordPresenceEvent($gymId, $type) ok');
  } catch (e) {
    debugPrint(
        'geofenceTriggered: recordPresenceEvent($gymId, $type) failed: $e');
  }
}
