import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../widgets/ds/ds.dart';
import 'push_notification_service.dart';

/// Just-in-time permission priming and request.
///
/// Shows a branded [PermissionPrimer] rationale sheet BEFORE the OS dialog,
/// handles granted / denied / permanentlyDenied states, and routes to Settings
/// when re-request is no longer possible. One singleton for the whole app.
class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static const _notifPrimedKey = 'permission_notification_primed';

  // ── Camera ────────────────────────────────────────────────────────────────

  Future<bool> requestCamera(BuildContext context) async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      if (context.mounted) _showSettingsSheet(context, _PermType.camera);
      return false;
    }
    if (!context.mounted) return false;
    final proceed = await _showPrimer(context, type: _PermType.camera);
    if (!proceed) return false;
    final result = await Permission.camera.request();
    if (!result.isGranted && context.mounted && result.isPermanentlyDenied) {
      _showSettingsSheet(context, _PermType.camera);
    }
    return result.isGranted;
  }

  // ── Photos ────────────────────────────────────────────────────────────────

  Future<bool> requestPhotos(BuildContext context) async {
    final perm = _photoPermission;
    final status = await perm.status;
    if (status.isGranted || status.isLimited) return true;
    if (status.isPermanentlyDenied) {
      if (context.mounted) _showSettingsSheet(context, _PermType.photos);
      return false;
    }
    if (!context.mounted) return false;
    final proceed = await _showPrimer(context, type: _PermType.photos);
    if (!proceed) return false;
    final result = await perm.request();
    if (!result.isGranted &&
        !result.isLimited &&
        context.mounted &&
        result.isPermanentlyDenied) {
      _showSettingsSheet(context, _PermType.photos);
    }
    return result.isGranted || result.isLimited;
  }

  // ── Location (primer only — Geolocator handles the actual OS request) ─────

  /// Shows the location rationale primer. Call this before invoking Geolocator.
  /// Returns true if the user wants to proceed; false if they tapped "Not Now".
  Future<bool> showLocationPrimer(BuildContext context) async {
    if (!context.mounted) return false;
    return _showPrimer(context, type: _PermType.location);
  }

  // ── Notifications ──────────────────────────────────────────────────────────

  /// Shows notification rationale primer (once only), then requests permission.
  Future<bool> requestNotifications(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyPrimed = prefs.getBool(_notifPrimedKey) ?? false;

    final status = await Permission.notification.status;
    if (status.isGranted) {
      await prefs.setBool(_notifPrimedKey, true);
      return true;
    }
    if (alreadyPrimed || status.isPermanentlyDenied) {
      // Don't re-show primer; just attempt the request (OS will decide)
      await PushNotificationService().requestPermission();
      return (await Permission.notification.status).isGranted;
    }
    if (!context.mounted) return false;
    final proceed = await _showPrimer(context, type: _PermType.notifications);
    await prefs.setBool(_notifPrimedKey, true);
    if (!proceed) return false;
    await PushNotificationService().requestPermission();
    return (await Permission.notification.status).isGranted;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Permission get _photoPermission {
    if (Platform.isAndroid) return Permission.photos;
    return Permission.photos;
  }

  Future<bool> _showPrimer(
    BuildContext context, {
    required _PermType type,
  }) async {
    final l10n = AppLocalizations.of(context);
    return PermissionPrimer.show(
      context,
      icon: type.icon,
      iconColor: type.color(context),
      title: l10n.translate(type.titleKey),
      rationale: l10n.translate(type.rationaleKey),
      allowLabel: l10n.translate('permission.allow'),
      notNowLabel: l10n.translate('permission.not_now'),
    );
  }

  void _showSettingsSheet(BuildContext context, _PermType type) {
    final l10n = AppLocalizations.of(context);
    AppSheet.show<void>(
      context: context,
      child: _SettingsContent(
        icon: type.icon,
        iconColor: type.color(context),
        title: l10n.translate('permission.denied.title'),
        message: l10n.translate('permission.denied.message'),
        settingsLabel: l10n.translate('permission.open_settings'),
        cancelLabel: l10n.translate('common.cancel'),
      ),
    );
  }
}

// ── Enum helpers ────────────────────────────────────────────────────────────

enum _PermType { camera, photos, location, notifications }

extension _PermTypeExt on _PermType {
  IconData get icon => switch (this) {
        _PermType.camera => Icons.camera_alt_rounded,
        _PermType.photos => Icons.photo_library_rounded,
        _PermType.location => Icons.location_on_rounded,
        _PermType.notifications => Icons.notifications_rounded,
      };

  Color color(BuildContext context) => switch (this) {
        _PermType.camera => AppPalette.of(context).info,
        _PermType.photos => AppPalette.of(context).success,
        _PermType.location => AppPalette.of(context).warning,
        _PermType.notifications => Theme.of(context).primaryColor,
      };

  String get titleKey => switch (this) {
        _PermType.camera => 'permission.camera.title',
        _PermType.photos => 'permission.photos.title',
        _PermType.location => 'permission.location.title',
        _PermType.notifications => 'permission.notifications.title',
      };

  String get rationaleKey => switch (this) {
        _PermType.camera => 'permission.camera.rationale',
        _PermType.photos => 'permission.photos.rationale',
        _PermType.location => 'permission.location.rationale',
        _PermType.notifications => 'permission.notifications.rationale',
      };
}

// ── Settings redirect sheet content ─────────────────────────────────────────

class _SettingsContent extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String settingsLabel;
  final String cancelLabel;

  const _SettingsContent({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.settingsLabel,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: t.headlineS.copyWith(fontWeight: FontWeight.w800),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: t.bodyM.copyWith(color: palette.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: settingsLabel,
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            cancelLabel,
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}
