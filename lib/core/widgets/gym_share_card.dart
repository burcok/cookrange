import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../models/gym_model.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_palette.dart';

/// Shareable 350×500 gym profile card.
///
/// Render offscreen (in an `Offstage` or overlay), then call [GymShareCard.share].
/// Uses a mesh-glow glassmorphism background with the gym's brand color blobs
/// over a dark semi-opaque base.
class GymShareCard extends StatelessWidget {
  final GymModel gym;
  final GlobalKey repaintKey;

  const GymShareCard({
    super.key,
    required this.gym,
    required this.repaintKey,
  });

  // ── Static capture key ──────────────────────────────────────────────────────

  static final GlobalKey captureKey = GlobalKey();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Captures and shares the card as a PNG image.
  static Future<void> share(
    BuildContext context,
    GymModel gym,
  ) async {
    final l10n = AppLocalizations.of(context);
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: -9999,
        child: GymShareCard(
          gym: gym,
          repaintKey: captureKey,
        ),
      ),
    );
    Overlay.of(context).insert(overlay);

    await Future<void>.delayed(const Duration(milliseconds: 80));

    try {
      final boundary =
          captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/cookrange_gym_card.png');
      await file.writeAsBytes(bytes);

      final text = l10n.translate('share.gym_share_text',
          variables: {'name': gym.name});

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: l10n.translate('share.gym_share_subject',
            variables: {'name': gym.name}),
      );
    } catch (e) {
      debugPrint('GymShareCard.share error: $e');
    } finally {
      overlay.remove();
    }
  }

  // ── Widget tree ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brandColor = gym.resolvedBrandColor;

    return RepaintBoundary(
      key: repaintKey,
      child: SizedBox(
        width: 350,
        height: 500,
        child: Stack(
          children: [
            // Dark base
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1117),
                  borderRadius:
                      BorderRadius.all(Radius.circular(AppRadius.card)),
                ),
              ),
            ),
            // Gradient blob — top-right (brand color)
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      brandColor.withValues(alpha: 0.28),
                      brandColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Gradient blob — bottom-left (energy teal)
            Positioned(
              bottom: -40,
              left: -30,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.energyDark.withValues(alpha: 0.18),
                      AppPalette.energyDark.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Card border glow
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.all(Radius.circular(AppRadius.card)),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LogoSection(gym: gym, brandColor: brandColor),
                  const SizedBox(height: 20),
                  if (gym.tags.isNotEmpty)
                    _TagsRow(tags: gym.tags, brandColor: brandColor),
                  const SizedBox(height: 20),
                  _StatsRow(gym: gym, brandColor: brandColor),
                  const Spacer(),
                  _CtaBar(gym: gym, brandColor: brandColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo + name section ───────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  final GymModel gym;
  final Color brandColor;
  const _LogoSection({required this.gym, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo ring
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: brandColor.withValues(alpha: 0.55),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: brandColor.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md - 2),
            child: gym.logoUrl != null && gym.logoUrl!.isNotEmpty
                ? Image.network(
                    gym.logoUrl!,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    cacheWidth: 252,
                    errorBuilder: (_, __, ___) =>
                        _InitialsFallback(name: gym.name, size: 84, bg: brandColor),
                  )
                : _InitialsFallback(name: gym.name, size: 84, bg: brandColor),
          ),
        ),
        const SizedBox(height: 12),
        // Name + verified badge
        Row(
          children: [
            Flexible(
              child: Text(
                gym.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Poppins',
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (gym.isVerified) ...[
              const SizedBox(width: 6),
              _VerifiedBadge(brandColor: brandColor),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // Location
        if (gym.locationDisplay.isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 12, color: Color(0xFF9AA3B0)),
              const SizedBox(width: 3),
              Text(
                gym.locationDisplay,
                style: const TextStyle(
                  color: Color(0xFF9AA3B0),
                  fontSize: 12,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Verified badge ─────────────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  final Color brandColor;
  const _VerifiedBadge({required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandColor, brandColor.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 11, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'Verified',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tags row ──────────────────────────────────────────────────────────────────

class _TagsRow extends StatelessWidget {
  final List<String> tags;
  final Color brandColor;
  const _TagsRow({required this.tags, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final visible = tags.take(4).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: visible
          .map(
            (t) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: brandColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: brandColor.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                t,
                style: TextStyle(
                  color: brandColor.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final GymModel gym;
  final Color brandColor;
  const _StatsRow({required this.gym, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            icon: Icons.people_rounded,
            value: '${gym.memberCount}',
            label: 'Members',
            accent: brandColor,
          ),
          _VertDivider(),
          _Stat(
            icon: Icons.workspace_premium_rounded,
            value: gym.subscriptionTier.displayName,
            label: 'Tier',
            accent: AppPalette.energyDark,
          ),
          _VertDivider(),
          _Stat(
            icon: Icons.public_rounded,
            value: gym.isPublic ? 'Public' : 'Private',
            label: 'Access',
            accent: const Color(0xFF60A5FA),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color accent;
  const _Stat(
      {required this.icon,
      required this.value,
      required this.label,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
            height: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

// ── CTA bar ───────────────────────────────────────────────────────────────────

class _CtaBar extends StatelessWidget {
  final GymModel gym;
  final Color brandColor;
  const _CtaBar({required this.gym, required this.brandColor});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 58,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [brandColor, brandColor.withValues(alpha: 0.75)],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.card),
          bottomRight: Radius.circular(AppRadius.card),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              l10n.translate('share.gym_card_cta'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Text(
            '🍊 Cookrange',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(width: 20),
        ],
      ),
    );
  }
}

// ── Initials fallback ─────────────────────────────────────────────────────────

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
      color: bg.withValues(alpha: 0.25),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
          height: 1.0,
        ),
      ),
    );
  }
}
