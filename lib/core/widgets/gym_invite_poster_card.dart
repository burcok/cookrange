import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../models/gym_invite_code_model.dart';
import '../models/gym_model.dart';
import '../services/referral_service.dart';
import '../theme/app_dimensions.dart';

/// Printable A4-portrait poster for a gym invite code (Faz 6 §6.1): QR + the
/// raw code + a 3-step instruction + the gym's own logo, exported as a PNG
/// via the OS share sheet (so the owner can AirPrint/save/send it however
/// they like — no in-app print pipeline exists or is needed).
///
/// Deliberately white/black, NOT themed (`AppPalette`/brand color) like
/// [GymShareCard] — this is meant to be printed on paper and re-scanned by a
/// bare camera in whatever lighting a gym noticeboard has, so it fixes on
/// maximum QR contrast rather than the gym's brand color. Mirrors
/// [GymShareCard]'s exact capture approach (offscreen `Overlay` +
/// `RepaintBoundary.toImage` + `Share.shareXFiles`), just a different layout
/// and a different print-shaped size.
class GymInvitePosterCard extends StatelessWidget {
  final GymModel gym;
  final GymInviteCodeModel invite;
  final GlobalKey repaintKey;

  const GymInvitePosterCard({
    super.key,
    required this.gym,
    required this.invite,
    required this.repaintKey,
  });

  // ── Static capture key ──────────────────────────────────────────────────

  static final GlobalKey captureKey = GlobalKey();

  // A4 portrait ratio (210×297mm ≈ 0.707). Captured at pixelRatio 3.0 →
  // ~1800×2547px, ~220dpi at A4 width — print-ready without being an
  // unreasonably large file.
  static const double _width = 600;
  static const double _height = 849;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Captures and shares the poster as a PNG image via the OS share sheet.
  static Future<void> share(
    BuildContext context, {
    required GymModel gym,
    required GymInviteCodeModel invite,
  }) async {
    final l10n = AppLocalizations.of(context);
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: -9999,
        child: GymInvitePosterCard(
          gym: gym,
          invite: invite,
          repaintKey: captureKey,
        ),
      ),
    );
    Overlay.of(context).insert(overlay);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    try {
      final boundary = captureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cookrange_gym_invite_poster.png');
      await file.writeAsBytes(bytes);

      final text = l10n.translate('share.gym_invite_poster_text',
          variables: {'name': gym.name});

      // Subject line deliberately reuses GymShareCard's existing
      // `gym_share_subject` key ("Join {name} on Cookrange") rather than
      // adding a near-duplicate — the poster's body text below is the part
      // that's actually different (mentions scanning the code).
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: l10n.translate('share.gym_share_subject',
            variables: {'name': gym.name}),
      );

      // Best-effort "the owner actually exported this" marker — see
      // ReferralService.markInviteCodePrinted's doc comment. Not awaited (the
      // share sheet shouldn't block on a Firestore round-trip); errors are
      // logged, never silent (R4).
      unawaited(
        ReferralService()
            .markInviteCodePrinted(invite.code)
            .catchError((Object e) {
          debugPrint(
              'GymInvitePosterCard.share: markInviteCodePrinted failed — $e');
        }),
      );
    } catch (e) {
      debugPrint('GymInvitePosterCard.share error: $e');
    } finally {
      overlay.remove();
    }
  }

  // ── Widget tree ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RepaintBoundary(
      key: repaintKey,
      child: Container(
        width: _width,
        height: _height,
        padding: const EdgeInsets.fromLTRB(40, 48, 40, 32),
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            _GymHeader(gym: gym, invite: invite),
            const SizedBox(height: 28),
            Text(
              l10n.translate('gym.invite.poster_headline'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0D1117),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Poppins',
                height: 1.25,
              ),
            ),
            const SizedBox(height: 24),
            _QrBlock(invite: invite),
            const Spacer(),
            _StepsSection(l10n: l10n),
            const SizedBox(height: 20),
            _Footer(l10n: l10n),
          ],
        ),
      ),
    );
  }
}

// ── Gym header (logo + name) ────────────────────────────────────────────────

class _GymHeader extends StatelessWidget {
  final GymModel gym;
  final GymInviteCodeModel invite;
  const _GymHeader({required this.gym, required this.invite});

  @override
  Widget build(BuildContext context) {
    final brand = gym.resolvedBrandColor;
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: brand.withValues(alpha: 0.5), width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - 2),
            // NOT `AppImage` here on purpose: AppImage's CachedNetworkImage
            // always fades in over 300ms, which would still be mid-fade at
            // the 80ms mark this card gets captured at offscreen (see
            // `share()` above) — capturing a near-invisible logo. A bare
            // `Image` on `CachedNetworkImageProvider` still gets the shared
            // disk/memory cache (the logo is almost certainly already warm
            // from the dashboard the owner navigated here from) without that
            // transition, satisfying CLAUDE.md's "AppImage or
            // CachedNetworkImageProvider, never raw Image.network" either way.
            child: gym.logoUrl != null && gym.logoUrl!.isNotEmpty
                ? Image(
                    image: CachedNetworkImageProvider(gym.logoUrl!),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InitialsFallback(name: gym.name, size: 64, bg: brand),
                  )
                : _InitialsFallback(name: gym.name, size: 64, bg: brand),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          gym.name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0D1117),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
          ),
        ),
        if (invite.campaign != null || invite.locationNote != null) ...[
          const SizedBox(height: 2),
          Text(
            invite.displayLabel(),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// ── QR + raw code ───────────────────────────────────────────────────────────

class _QrBlock extends StatelessWidget {
  final GymInviteCodeModel invite;
  const _QrBlock({required this.invite});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
          ),
          // Black-on-white regardless of the gym's brand color or the app's
          // theme — this is printed and re-scanned by a bare camera, so
          // maximum contrast beats brand consistency here.
          child: QrImageView(
            data: invite.inviteUrl,
            size: 260,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(color: Colors.black),
            dataModuleStyle: const QrDataModuleStyle(color: Colors.black),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          invite.code,
          style: const TextStyle(
            color: Color(0xFF0D1117),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}

// ── 3-step instructions ─────────────────────────────────────────────────────

class _StepsSection extends StatelessWidget {
  final AppLocalizations l10n;
  const _StepsSection({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final steps = [
      l10n.translate('gym.invite.step1'),
      l10n.translate('gym.invite.step2'),
      l10n.translate('gym.invite.step3'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF97300),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Poppins',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  steps[i],
                  style: const TextStyle(
                    color: Color(0xFF0D1117),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final AppLocalizations l10n;
  const _Footer({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 1, width: 80, color: const Color(0xFFE5E7EB)),
        const SizedBox(height: 12),
        const Text(
          '🍊 Cookrange',
          style: TextStyle(
            color: Color(0xFF0D1117),
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

// ── Initials fallback (mirrors GymShareCard's — that one is file-private) ──

class _InitialsFallback extends StatelessWidget {
  final String name;
  final double size;
  final Color bg;
  const _InitialsFallback(
      {required this.name, required this.size, required this.bg});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) return list[0][0].toUpperCase();
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: bg.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: bg,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          height: 1.0,
        ),
      ),
    );
  }
}
