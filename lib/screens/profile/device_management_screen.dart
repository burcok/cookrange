import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/device_model.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/device_registry_service.dart';
import '../../core/services/log_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Lists every device signed in to the current account
/// (`users/{uid}/devices`, DeviceRegistryService) — the multi-device
/// replacement for AuthService's old single-session kickout. Lets the user
/// identify "this device", sign a single device out, or sign every OTHER
/// device out at once.
class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final LogService _log = LogService();
  final String _serviceName = 'DeviceManagementScreen';

  late Stream<List<DeviceModel>> _devicesStream;
  String? _thisDeviceId;
  bool _actionInFlight = false;

  @override
  void initState() {
    super.initState();
    _devicesStream = _watchDevices();
    unawaited(_loadThisDeviceId());
  }

  Stream<List<DeviceModel>> _watchDevices() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return DeviceRegistryService().watchMyDevices(uid);
  }

  Future<void> _loadThisDeviceId() async {
    final id = await DeviceIdentityService().deviceId;
    if (!mounted) return;
    setState(() => _thisDeviceId = id);
  }

  Future<bool> _confirm(
      {required String title, required String message}) async {
    final l10n = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.translate('common.confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _signOutDevice(DeviceModel device) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title: l10n.translate('profile.devices.sign_out_device_confirm_title'),
      message:
          l10n.translate('profile.devices.sign_out_device_confirm_message'),
    );
    if (!confirmed || !mounted) return;

    setState(() => _actionInFlight = true);
    try {
      if (device.id == _thisDeviceId) {
        // AuthService's own watchThisDeviceRevoked subscription reacts to the
        // resulting `revoked: true` and handles the local sign-out + dialog —
        // nothing else to do here.
        await DeviceRegistryService().signOutThisDevice();
      } else {
        await DeviceRegistryService().signOutDevice(device.id);
        if (!mounted) return;
        AppSnackBar.success(
            context, l10n.translate('profile.devices.success_signed_out'));
      }
    } catch (e, s) {
      _log.error('signOutDevice failed for ${device.id}',
          service: _serviceName, error: e, stackTrace: s);
      if (mounted) {
        AppSnackBar.error(
            context, l10n.translate('profile.devices.error_generic'));
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  Future<void> _signOutAllOthers() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await _confirm(
      title:
          l10n.translate('profile.devices.sign_out_all_others_confirm_title'),
      message:
          l10n.translate('profile.devices.sign_out_all_others_confirm_message'),
    );
    if (!confirmed || !mounted) return;

    setState(() => _actionInFlight = true);
    try {
      await DeviceRegistryService().signOutAllOtherDevices();
      if (!mounted) return;
      AppSnackBar.success(
          context, l10n.translate('profile.devices.success_signed_out_all'));
    } catch (e, s) {
      _log.error('signOutAllOtherDevices failed',
          service: _serviceName, error: e, stackTrace: s);
      if (mounted) {
        AppSnackBar.error(
            context, l10n.translate('profile.devices.error_generic'));
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
  }

  String _formatLastSeen(DateTime? lastSeenAt, AppLocalizations l10n) {
    if (lastSeenAt == null) {
      return l10n.translate('profile.devices.last_seen_now');
    }
    final diff = DateTime.now().difference(lastSeenAt);
    if (diff.inMinutes < 1) {
      return l10n.translate('profile.devices.last_seen_now');
    }
    final String amount;
    if (diff.inMinutes < 60) {
      amount = '${diff.inMinutes} ${l10n.translate('community.time.min')}';
    } else if (diff.inHours < 24) {
      amount = '${diff.inHours} ${l10n.translate('community.time.hour')}';
    } else {
      amount = '${diff.inDays} ${l10n.translate('community.time.day')}';
    }
    return '${l10n.translate('profile.devices.last_seen')} $amount';
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'iOS':
        return Icons.phone_iphone_rounded;
      case 'Android':
        return Icons.phone_android_rounded;
      default:
        return Icons.devices_other_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('profile.devices.title'),
          style: t.headlineS,
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<DeviceModel>>(
        stream: _devicesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: AppSkeletonList(itemCount: 4),
            );
          }

          if (snapshot.hasError) {
            return AppErrorState(
              title: l10n.translate('common.something_wrong'),
              message: l10n.translate('profile.devices.error_generic'),
              retryLabel: l10n.translate('common.retry'),
              onRetry: () => setState(() => _devicesStream = _watchDevices()),
            );
          }

          final devices = snapshot.data ?? [];
          if (devices.isEmpty) {
            return AppEmptyState(
              icon: Icons.devices_other_rounded,
              title: l10n.translate('profile.devices.empty_title'),
              message: l10n.translate('profile.devices.empty_message'),
            );
          }

          final hasOtherDevices = devices.any((d) => d.id != _thisDeviceId);

          return ListView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 100.h),
            children: [
              Text(
                l10n.translate('profile.devices.subtitle'),
                style: t.bodyM.copyWith(color: palette.textSecondary),
              ),
              SizedBox(height: AppSpacing.lg.h),
              if (hasOtherDevices) ...[
                AppButton(
                  label: l10n.translate('profile.devices.sign_out_all_others'),
                  onPressed: _actionInFlight ? null : _signOutAllOthers,
                  variant: AppButtonVariant.destructive,
                  icon: Icons.logout_rounded,
                  loading: _actionInFlight,
                ),
                SizedBox(height: AppSpacing.lg.h),
              ],
              ...devices.map(
                (device) => Padding(
                  padding: EdgeInsets.only(bottom: AppSpacing.md.h),
                  child: RepaintBoundary(
                    child: _DeviceCard(
                      device: device,
                      isThisDevice: device.id == _thisDeviceId,
                      icon: _platformIcon(device.platform),
                      lastSeenLabel: _formatLastSeen(device.lastSeenAt, l10n),
                      actionEnabled: !_actionInFlight,
                      onSignOut: () => _signOutDevice(device),
                      palette: palette,
                      l10n: l10n,
                      t: t,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceModel device;
  final bool isThisDevice;
  final IconData icon;
  final String lastSeenLabel;
  final bool actionEnabled;
  final VoidCallback onSignOut;
  final AppPalette palette;
  final AppLocalizations l10n;
  final AppText t;

  const _DeviceCard({
    required this.device,
    required this.isThisDevice,
    required this.icon,
    required this.lastSeenLabel,
    required this.actionEnabled,
    required this.onSignOut,
    required this.palette,
    required this.l10n,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: isThisDevice
            ? Border.all(color: palette.success.withValues(alpha: 0.4))
            : null,
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color:
                  palette.info.withValues(alpha: palette.isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: palette.info, size: AppSize.iconMd.sp),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        device.model,
                        style: t.titleM,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isThisDevice) ...[
                      SizedBox(width: AppSpacing.xs.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: palette.success
                              .withValues(alpha: palette.isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.xs.r),
                        ),
                        child: Text(
                          l10n.translate('profile.devices.this_device'),
                          style: t.labelS.copyWith(
                              color: palette.success,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  lastSeenLabel,
                  style: t.labelM.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          if (!isThisDevice)
            IconButton(
              icon: Icon(
                Icons.logout_rounded,
                color: actionEnabled ? palette.error : palette.textSecondary,
                size: AppSize.iconSm,
              ),
              tooltip: l10n.translate('profile.devices.sign_out_device'),
              onPressed: actionEnabled ? onSignOut : null,
            )
          else
            TextButton(
              onPressed: actionEnabled ? onSignOut : null,
              child: Text(
                l10n.translate('profile.devices.sign_out_device'),
                style: t.labelM.copyWith(color: palette.error),
              ),
            ),
        ],
      ),
    );
  }
}
