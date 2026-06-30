import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/services/gym_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/widgets/ds/ds.dart';

class GymCheckInScreen extends StatefulWidget {
  final String gymId;
  final String gymName;
  final double? gymLat;
  final double? gymLng;
  final int checkInRadius;
  final Color? brandColor;

  const GymCheckInScreen({
    super.key,
    required this.gymId,
    required this.gymName,
    this.gymLat,
    this.gymLng,
    this.checkInRadius = 100,
    this.brandColor,
  });

  @override
  State<GymCheckInScreen> createState() => _GymCheckInScreenState();
}

class _GymCheckInScreenState extends State<GymCheckInScreen> {
  bool _gpsLoading = false;
  bool _success = false;

  bool get _hasGpsSetup => widget.gymLat != null && widget.gymLng != null;

  Future<void> _handleQrTap() async {
    final granted = await PermissionService().requestCamera(context);
    if (!mounted || !granted) return;
    final result = await Navigator.of(context).push<bool>(
      AppTransitions.slideUp(
        _QrScannerPage(gymId: widget.gymId),
      ),
    );
    if (result == true && mounted) {
      setState(() => _success = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  Future<void> _handleGpsTap() async {
    if (!_hasGpsSetup) return;
    // Show branded location primer before the OS dialog
    final currentPerm = await Geolocator.checkPermission();
    if (!mounted) return;
    if (currentPerm == LocationPermission.denied ||
        currentPerm == LocationPermission.unableToDetermine) {
      final proceed = await PermissionService().showLocationPrimer(context);
      if (!mounted || !proceed) return;
    }
    setState(() => _gpsLoading = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          _showSettingsDialog(l10n);
        }
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) {
          AppSnackBar.error(
              context,
              AppLocalizations.of(context)
                  .translate('gym.checkin_permission_denied'));
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      await GymService().gpsCheckIn(
        widget.gymId,
        widget.gymLat!,
        widget.gymLng!,
        pos.latitude,
        pos.longitude,
        widget.checkInRadius,
      );

      if (mounted) {
        setState(() => _success = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final msg = e.toString().contains('Too far')
            ? l10n.translate('gym.checkin_gps_too_far')
            : l10n.translate('gym.checkin_gps_error');
        AppSnackBar.error(context, msg);
      }
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  void _showSettingsDialog(AppLocalizations l10n) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.translate('gym.checkin_permission_denied')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Geolocator.openAppSettings();
            },
            child: Text(l10n.translate('gym.checkin_permission_settings')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final primary = widget.brandColor ?? Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('gym.checkin_title'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
              ),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              children: [
                _OptionCard(
                  icon: Icons.qr_code_scanner_rounded,
                  color: primary,
                  title: l10n.translate('gym.checkin_scan_qr'),
                  subtitle: l10n.translate('gym.checkin_scan_qr_sub'),
                  palette: palette,
                  onTap: _handleQrTap,
                ),
                const SizedBox(height: 12),
                _OptionCard(
                  icon: Icons.location_on_rounded,
                  color: palette.success,
                  title: l10n.translate('gym.checkin_gps'),
                  subtitle: _hasGpsSetup
                      ? l10n.translate('gym.checkin_gps_sub')
                      : l10n.translate('gym.checkin_gps_no_location'),
                  palette: palette,
                  loading: _gpsLoading,
                  disabled: !_hasGpsSetup,
                  onTap: _hasGpsSetup ? _handleGpsTap : null,
                ),
              ],
            ),
          ),
          if (_success) _SuccessOverlay(palette: palette),
        ],
      ),
    );
  }
}

// ── Option Card ───────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final AppPalette palette;
  final bool loading;
  final bool disabled;
  final VoidCallback? onTap;

  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.palette,
    this.loading = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = disabled ? palette.textTertiary : color;
    return AppCard(
      onTap: disabled ? null : onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: effectiveColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: loading
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: effectiveColor,
                    ),
                  )
                : Icon(icon, color: effectiveColor, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppText.of(context).titleM.copyWith(
                        color: disabled
                            ? palette.textTertiary
                            : palette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppText.of(context).bodyM.copyWith(
                        color: palette.textSecondary,
                        fontSize: 13,
                      ),
                ),
              ],
            ),
          ),
          if (!disabled)
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: palette.textSecondary),
        ],
      ),
    );
  }
}

// ── QR Scanner Page ────────────────────────────────────────────────────────────

class _QrScannerPage extends StatefulWidget {
  final String gymId;
  const _QrScannerPage({required this.gymId});

  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  late MobileScannerController _controller;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;
    final raw = barcode.rawValue;
    if (raw == null) return;

    // Expected format: cookrange:checkin:{gymId}:{token}
    final parts = raw.split(':');
    if (parts.length != 4 ||
        parts[0] != 'cookrange' ||
        parts[1] != 'checkin' ||
        parts[2] != widget.gymId) {
      if (mounted) {
        AppSnackBar.error(context,
            AppLocalizations.of(context).translate('gym.checkin_invalid_qr'));
      }
      return;
    }

    setState(() => _processing = true);
    try {
      await GymService().validateQRCheckIn(widget.gymId, parts[3]);
      if (mounted) {
        setState(() => _processing = false);
        _showSuccess();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _processing = false);
        AppSnackBar.error(context,
            AppLocalizations.of(context).translate('gym.checkin_invalid_qr'));
      }
    }
  }

  void _showSuccess() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SuccessDialog(),
    ).then((_) {
      if (mounted) Navigator.of(context).pop(true);
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('gym.checkin_scan_qr'),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scanning frame overlay
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(
                  color: palette.success,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          // Corner accents
          Center(
            child: SizedBox(
              width: 240,
              height: 240,
              child:
                  CustomPaint(painter: _CornerPainter(color: palette.success)),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const len = 24.0;
    const r = 12.0;

    // Top-left
    canvas.drawLine(const Offset(r, 0), const Offset(r + len, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, r + len), paint);
    // Top-right
    canvas.drawLine(
        Offset(size.width - r, 0), Offset(size.width - r - len, 0), paint);
    canvas.drawLine(Offset(size.width, r), Offset(size.width, r + len), paint);
    // Bottom-left
    canvas.drawLine(
        Offset(r, size.height), Offset(r + len, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height - r), Offset(0, size.height - r - len), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - r, size.height),
        Offset(size.width - r - len, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - r),
        Offset(size.width, size.height - r - len), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

// ── Success Dialog ────────────────────────────────────────────────────────────

class _SuccessDialog extends StatelessWidget {
  const _SuccessDialog();

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: palette.success, size: 64),
            const SizedBox(height: 16),
            Text(
              l10n.translate('gym.checkin_success_title'),
              style: AppText.of(context).headlineS.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('gym.checkin_success_sub'),
              style: AppText.of(context).bodyM.copyWith(
                    color: palette.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Success Overlay ────────────────────────────────────────────────────────────

class _SuccessOverlay extends StatelessWidget {
  final AppPalette palette;
  const _SuccessOverlay({required this.palette});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AnimatedOpacity(
      opacity: 1.0,
      duration: AppMotion.normal,
      child: Container(
        color: palette.background.withValues(alpha: 0.92),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: palette.success, size: 80),
              const SizedBox(height: 20),
              Text(
                l10n.translate('gym.checkin_success_title'),
                style: AppText.of(context).headlineS.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.translate('gym.checkin_success_sub'),
                style: AppText.of(context).bodyM.copyWith(
                      color: palette.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
