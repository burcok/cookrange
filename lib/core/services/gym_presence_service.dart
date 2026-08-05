import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../localization/app_localizations.dart';
import '../models/gym_model.dart';
import '../widgets/ds/ds.dart';
import '../utils/haversine.dart';
import '../../screens/gym/gym_presence_consent_screen.dart';
import 'auth_service.dart';
import 'firestore_service.dart';
import 'geofence_service.dart';
import 'permission_service.dart';

/// Faz 1 §1.2 — orchestrates the 4-tier fallback chain around the raw
/// [GeofenceService] wrapper: consent + the 3-gym cap + "Always" permission
/// before ever registering a region (tier 1), a foreground one-shot
/// fallback when permission has been downgraded since (tier 2), and a
/// health-check signal for when geofence events seem to have silently
/// stopped arriving (tier 4). Tier 3 — "existing QR/GPS check-in keeps
/// working exactly as before" — needs no code at all: this whole feature is
/// additive, and [GymService.validateQRCheckIn]/[GymService.gpsCheckIn] are
/// untouched by any of Faz 1's work.
class GymPresenceService {
  static final GymPresenceService _instance = GymPresenceService._internal();
  factory GymPresenceService() => _instance;
  GymPresenceService._internal();

  /// iOS's 20-region monitoring cap ÷ headroom for other future geofence
  /// uses — matches the plan's own cap, not `native_geofence`'s (it doesn't
  /// document one itself).
  static const maxTrackedGyms = 3;

  String? get _uid => AuthService().currentUser?.uid;

  /// Call once at app bootstrap (`app_initialization_service.dart`, alongside
  /// the other best-effort `_initXxx` calls). Re-asserts every gym the user
  /// currently has auto-check-in on — geofence registration doesn't survive
  /// a fresh install, and may not survive an app update or an OS-level
  /// clear-out either, so this is what recovers from that silently rather
  /// than leaving tracking quietly dead. No-ops instantly if signed out.
  /// `createGeofence` overwrites by id, so re-registering an already-correct
  /// gym is harmless — this never needs to diff against what's already
  /// registered.
  Future<void> reconcileTrackedGyms() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await GeofenceService.ensureInitialized();
      final prefs = await FirestoreService().getGymPresencePrefs(uid);
      final trackedGymIds = prefs.gymTrackingEnabled.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      if (trackedGymIds.isEmpty) return;

      for (final gymId in trackedGymIds) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('gyms')
              .doc(gymId)
              .get();
          if (!doc.exists) continue;
          final gym = GymModel.fromFirestore(doc);
          if (!gym.hasLocation || !gym.geofenceEnabled) continue;
          await GeofenceService.registerGym(
            gymId: gym.id,
            latitude: gym.latitude!,
            longitude: gym.longitude!,
            radiusMeters: gym.checkInRadius,
          );
        } catch (e) {
          debugPrint('GymPresenceService.reconcileTrackedGyms($gymId): $e');
        }
      }
    } catch (e) {
      debugPrint('GymPresenceService.reconcileTrackedGyms: $e');
    }
  }

  // ── Tier 1: enable/disable ──────────────────────────────────────────────

  /// Full opt-in flow for one gym: KVKK consent → 3-gym cap → OS "Always"
  /// permission → geofence region registration → persisted per-gym prefs.
  /// Returns true only if tracking actually ended up enabled.
  Future<bool> enableTrackingForGym(BuildContext context, GymModel gym) async {
    final uid = _uid;
    if (uid == null || !gym.hasLocation) return false;

    final consented = await GymPresenceConsentScreen.request(context);
    if (!consented || !context.mounted) return false;

    final prefs = await FirestoreService().getGymPresencePrefs(uid);
    if (!context.mounted) return false;
    final alreadyOn = prefs.trackingEnabledFor(gym.id);
    if (!alreadyOn) {
      final activeCount =
          prefs.gymTrackingEnabled.values.where((v) => v).length;
      if (activeCount >= maxTrackedGyms) {
        AppSnackBar.warning(
          context,
          AppLocalizations.of(context)
              .translate('gym.auto_checkin_limit_reached'),
        );
        return false;
      }
    }

    final status = await PermissionService().requestLocationAlways(context);
    if (!status.isGranted || !context.mounted) return false;

    try {
      await GeofenceService.registerGym(
        gymId: gym.id,
        latitude: gym.latitude!,
        longitude: gym.longitude!,
        radiusMeters: gym.checkInRadius,
      );
    } catch (e) {
      debugPrint('GymPresenceService.enableTrackingForGym(${gym.id}): $e');
      if (context.mounted) {
        AppSnackBar.error(
          context,
          AppLocalizations.of(context).translate('errors.general'),
        );
      }
      return false;
    }

    await FirestoreService().setGymTrackingEnabled(uid, gym.id, true);
    return true;
  }

  /// Turns tracking back off — removes the OS-level region immediately (no
  /// waiting for a server round-trip) and clears the per-gym prefs flag.
  Future<void> disableTrackingForGym(String gymId) async {
    final uid = _uid;
    await GeofenceService.unregisterGym(gymId);
    if (uid != null) {
      await FirestoreService().setGymTrackingEnabled(uid, gymId, false);
    }
  }

  /// Turns tracking off for every currently-tracked gym at once. Called when
  /// the BROAD `ConsentPurpose.gymPresence` toggle in the Consent Center is
  /// revoked (`consent_center_screen.dart`) — before this existed, that
  /// toggle only flipped the Firestore consent flag (which does stop new
  /// server-side presence events immediately, since `recordPresenceEvent`
  /// re-checks consent on every call) but left the OS-level geofence
  /// region(s) still registered on-device, contradicting the in-app copy's
  /// own promise that revoking clears them — and since `reconcileTrackedGyms`
  /// (called at every app boot) re-registers whatever `gym_tracking_enabled`
  /// still says `true`, a stale flag would keep getting silently re-armed.
  /// Uses [GeofenceService.unregisterAll] (previously dead code — a single
  /// native call to clear every region at once) rather than looping
  /// [GeofenceService.unregisterGym] per gym; the per-gym Firestore flags
  /// still need clearing individually since there's no bulk write for that.
  /// Turning off tracking one gym at a time is still available from that
  /// gym's own screen ([disableTrackingForGym]); this is the broad-toggle
  /// equivalent.
  Future<void> disableTrackingForAllGyms() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final prefs = await FirestoreService().getGymPresencePrefs(uid);
      final trackedGymIds = prefs.gymTrackingEnabled.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();
      if (trackedGymIds.isEmpty) return;

      await GeofenceService.unregisterAll();
      for (final gymId in trackedGymIds) {
        try {
          await FirestoreService().setGymTrackingEnabled(uid, gymId, false);
        } catch (e) {
          debugPrint(
              'GymPresenceService.disableTrackingForAllGyms($gymId): $e');
        }
      }
    } catch (e) {
      debugPrint('GymPresenceService.disableTrackingForAllGyms: $e');
    }
  }

  Future<bool> isTrackingEnabled(String gymId) async {
    final uid = _uid;
    if (uid == null) return false;
    final prefs = await FirestoreService().getGymPresencePrefs(uid);
    return prefs.trackingEnabledFor(gymId);
  }

  // ── Tier 2: foreground fallback (permission quietly downgraded) ─────────

  /// Call from a gym's own screen (it needs a real [BuildContext] to show
  /// the confirmation card) when that screen becomes visible. No-ops
  /// instantly unless tracking is nominally on for [gym] AND the OS
  /// permission has since dropped below "Always" — the common case (real
  /// "Always" still granted) costs one cheap permission-status check and
  /// returns.
  Future<void> checkForegroundFallback(
      BuildContext context, GymModel gym) async {
    if (!gym.hasLocation) return;
    if (!await isTrackingEnabled(gym.id)) return;

    final status = await Permission.locationAlways.status;
    if (status.isGranted) return; // Tier 1 (geofence) is doing its job.

    Position position;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return; // Nothing left to fall back to — tier 3 (manual QR/GPS) applies.
      }
      position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
    } catch (_) {
      return;
    }

    final distanceM = haversineKm(gym.latitude!, gym.longitude!,
            position.latitude, position.longitude) *
        1000;
    if (distanceM > gym.checkInRadius) return;
    if (!context.mounted) return;

    final confirmed = await _showAreYouAtGymCard(context, gym);
    if (confirmed != true) return;

    try {
      await FirebaseFunctions.instance
          .httpsCallable('recordPresenceEvent')
          .call<Map<String, dynamic>>({
        'gymId': gym.id,
        'type': 'dwell',
        'source': 'manual_confirm',
        'clientTimestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('GymPresenceService.checkForegroundFallback: $e');
    }
  }

  Future<bool?> _showAreYouAtGymCard(BuildContext context, GymModel gym) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    return AppSheet.show<bool>(
      context: context,
      title: l10n.translate('gym.are_you_here_title'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.translate('gym.are_you_here_body',
                variables: {'gym': gym.name}),
            style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: l10n.translate('gym.are_you_here_yes'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 8),
          AppButton(
            label: l10n.translate('common.no'),
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }

  // ── Tier 4: silent health check ──────────────────────────────────────────

  /// True if [gymId] has QR check-ins in the last 7 days but no
  /// geofence-sourced presence sessions in the same window, while tracking
  /// is nominally on — a strong signal auto check-in has quietly stopped
  /// firing (OS battery-saver killed it, permission silently revoked by the
  /// platform, etc.) and the member should be nudged to check Settings.
  /// Read-only — computed from data `recordPresenceEvent`/`validateGymCheckin`
  /// already write, no new persisted "last geofence event" field needed.
  Future<bool> needsHealthCheckCard(String gymId) async {
    final uid = _uid;
    if (uid == null) return false;
    if (!await isTrackingEnabled(gymId)) return false;

    final since =
        Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 7)));
    final db = FirebaseFirestore.instance;

    final qrCheckinsFuture = db
        .collection('gyms')
        .doc(gymId)
        .collection('checkins')
        .where('uid', isEqualTo: uid)
        .where('method', isEqualTo: 'qr')
        .where('timestamp', isGreaterThanOrEqualTo: since)
        .limit(1)
        .get();
    final geofenceSessionsFuture = db
        .collection('gyms')
        .doc(gymId)
        .collection('presence_sessions')
        .where('uid', isEqualTo: uid)
        .where('entered_at', isGreaterThanOrEqualTo: since)
        .limit(1)
        .get();

    try {
      final results =
          await Future.wait([qrCheckinsFuture, geofenceSessionsFuture]);
      final hasRecentQrCheckin = results[0].docs.isNotEmpty;
      final hasRecentGeofenceSession = results[1].docs.isNotEmpty;
      return hasRecentQrCheckin && !hasRecentGeofenceSession;
    } catch (e) {
      debugPrint('GymPresenceService.needsHealthCheckCard($gymId): $e');
      return false;
    }
  }
}
