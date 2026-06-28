import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_model.dart';
import '../../core/services/gym_service.dart';
import '../../core/widgets/ds/ds.dart';

class GymQrScreen extends StatefulWidget {
  final String gymId;
  final String gymName;
  final Color? brandColor;

  const GymQrScreen({
    super.key,
    required this.gymId,
    required this.gymName,
    this.brandColor,
  });

  @override
  State<GymQrScreen> createState() => _GymQrScreenState();
}

class _GymQrScreenState extends State<GymQrScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  StreamSubscription<GymModel>? _gymSub;
  GymModel? _gym;
  bool _loading = true;
  bool _generating = false;
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: AppMotion.emphasized,
    );
    _gymSub = GymService().getGymStream(widget.gymId).listen(
      (gym) {
        if (!mounted) return;
        setState(() {
          _gym = gym;
          _loading = false;
          _updateCountdown(gym);
        });
        if (!_animController.isCompleted) _animController.forward();
      },
      onError: (_) {
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  void _updateCountdown(GymModel gym) {
    _countdownTimer?.cancel();
    if (!gym.qrValid) {
      _remaining = Duration.zero;
      return;
    }
    _remaining = gym.qrTokenExpiresAt!.difference(DateTime.now());
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = gym.qrTokenExpiresAt!.difference(DateTime.now());
        if (_remaining.isNegative) {
          _remaining = Duration.zero;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _gymSub?.cancel();
    _countdownTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _generateToken() async {
    setState(() => _generating = true);
    try {
      await GymService().generateQRToken(widget.gymId);
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String _formatCountdown() {
    if (_remaining.isNegative || _remaining == Duration.zero) return '';
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.gymName,
              style: AppText.of(context).titleM.copyWith(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              l10n.translate('gym.checkin_qr_title'),
              style: AppText.of(context).labelS.copyWith(
                    color: palette.textSecondary,
                  ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: AppSkeletonList(itemCount: 3))
          : FadeTransition(
              opacity: _fadeIn,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: _gym == null
                    ? const AppEmptyState(
                        icon: Icons.qr_code_rounded,
                        title: 'Gym not found',
                        message: 'Could not load gym data.',
                      )
                    : _buildContent(context, palette, primary, l10n),
              ),
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppLocalizations l10n,
  ) {
    final gym = _gym!;
    final hasValidQr = gym.qrValid;

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              if (hasValidQr) ...[
                _buildQrCode(context, palette, primary, gym, l10n),
              ] else ...[
                _buildGeneratePrompt(context, palette, primary, l10n),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildInstructionCard(context, palette, primary, l10n),
      ],
    );
  }

  Widget _buildQrCode(
    BuildContext context,
    AppPalette palette,
    Color primary,
    GymModel gym,
    AppLocalizations l10n,
  ) {
    final qrData = 'cookrange:checkin:${gym.id}:${gym.qrToken}';
    final countdown = _formatCountdown();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: QrImageView(
            data: qrData,
            size: 240,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: primary,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (countdown.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_rounded, size: 16, color: palette.warning),
              const SizedBox(width: 4),
              Text(
                '${l10n.translate('gym.checkin_qr_expires')} $countdown',
                style: AppText.of(context).labelS.copyWith(
                      color: palette.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        AppButton(
          label: l10n.translate('gym.checkin_regenerate_qr'),
          onPressed: _generating ? null : _generateToken,
          size: AppButtonSize.small,
        ),
      ],
    );
  }

  Widget _buildGeneratePrompt(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppLocalizations l10n,
  ) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(Icons.qr_code_rounded, color: primary, size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.translate('gym.checkin_qr_expired'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.translate('gym.checkin_qr_instruction'),
          textAlign: TextAlign.center,
          style: AppText.of(context).bodyM.copyWith(
                color: palette.textSecondary,
              ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: l10n.translate('gym.checkin_generate_qr'),
          onPressed: _generating ? null : _generateToken,
          icon: Icons.qr_code_2_rounded,
        ),
      ],
    );
  }

  Widget _buildInstructionCard(
    BuildContext context,
    AppPalette palette,
    Color primary,
    AppLocalizations l10n,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: palette.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.info_rounded, color: palette.info, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.translate('gym.checkin_qr_instruction'),
              style: AppText.of(context).bodyM.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
