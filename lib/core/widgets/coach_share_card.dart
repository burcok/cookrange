import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../localization/app_localizations.dart';
import '../models/coach_profile_model.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_palette.dart';

/// Shareable 350×500 coach profile card.
///
/// Render offscreen (in an `Offstage` or overlay), then call [CoachShareCard.share].
/// Uses a mesh-glow glassmorphism background (brand + energy gradient blobs)
/// over a dark semi-opaque base — matches the Cookrange flagship design language.
class CoachShareCard extends StatelessWidget {
  final CoachProfileModel coach;
  final GlobalKey repaintKey;

  const CoachShareCard({
    super.key,
    required this.coach,
    required this.repaintKey,
  });

  // ── Static capture key ──────────────────────────────────────────────────────

  static final GlobalKey captureKey = GlobalKey();

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Captures and shares the card as a PNG image.
  static Future<void> share(
    BuildContext context,
    CoachProfileModel coach,
  ) async {
    final l10n = AppLocalizations.of(context);
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -9999,
        top: -9999,
        child: CoachShareCard(
          coach: coach,
          repaintKey: captureKey,
        ),
      ),
    );
    Overlay.of(context).insert(overlay);

    // Wait one frame so the widget is laid out and painted.
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
      final file = File('${dir.path}/cookrange_coach_card.png');
      await file.writeAsBytes(bytes);

      final text = l10n.translate('share.coach_share_text',
          variables: {'name': coach.displayName});

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: l10n.translate('share.coach_share_subject',
            variables: {'name': coach.displayName}),
      );
    } catch (e) {
      debugPrint('CoachShareCard.share error: $e');
    } finally {
      overlay.remove();
    }
  }

  // ── Widget tree ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
            // Gradient blob — top-left (brand orange)
            Positioned(
              top: -60,
              left: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.brand.withValues(alpha: 0.30),
                      AppPalette.brand.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Gradient blob — bottom-right (energy teal)
            Positioned(
              bottom: -50,
              right: -30,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.energyDark.withValues(alpha: 0.22),
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
                  _AvatarSection(coach: coach),
                  const SizedBox(height: 20),
                  if (coach.specializations.isNotEmpty)
                    _SpecializationsRow(specs: coach.specializations),
                  const SizedBox(height: 20),
                  _StatsRow(coach: coach),
                  const Spacer(),
                  _CtaBar(coach: coach),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Avatar + name section ─────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final CoachProfileModel coach;
  const _AvatarSection({required this.coach});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar ring
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppPalette.brand.withValues(alpha: 0.6),
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.brand.withValues(alpha: 0.30),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: coach.photoURL != null && coach.photoURL!.isNotEmpty
                ? Image.network(
                    coach.photoURL!,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                    cacheWidth: 252,
                    errorBuilder: (_, __, ___) =>
                        _InitialsFallback(name: coach.displayName, size: 84),
                  )
                : _InitialsFallback(name: coach.displayName, size: 84),
          ),
        ),
        const SizedBox(height: 12),
        // Name + verified badge
        Row(
          children: [
            Flexible(
              child: Text(
                coach.displayName,
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
            if (coach.isVerified) ...[
              const SizedBox(width: 6),
              const _VerifiedBadge(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        // City / district
        if (_locationText(coach).isNotEmpty)
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  size: 12, color: Color(0xFF9AA3B0)),
              const SizedBox(width: 3),
              Text(
                _locationText(coach),
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

  String _locationText(CoachProfileModel c) {
    final parts =
        [c.district, c.city].where((p) => p != null && p.isNotEmpty).toList();
    return parts.join(', ');
  }
}

// ── Verified badge ─────────────────────────────────────────────────────────────

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppPalette.sunsetA, AppPalette.sunsetC],
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

// ── Specialization chips ──────────────────────────────────────────────────────

class _SpecializationsRow extends StatelessWidget {
  final List<String> specs;
  const _SpecializationsRow({required this.specs});

  @override
  Widget build(BuildContext context) {
    final visible = specs.take(4).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: visible
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppPalette.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: AppPalette.brand.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                s,
                style: TextStyle(
                  color: AppPalette.brand.withValues(alpha: 0.95),
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
  final CoachProfileModel coach;
  const _StatsRow({required this.coach});

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
            icon: Icons.people_alt_rounded,
            value: '${coach.clientCount}',
            label: 'Clients',
          ),
          _VertDivider(),
          _RatingStat(rating: coach.avgRating),
          _VertDivider(),
          _Stat(
            icon: Icons.star_rounded,
            value: '${coach.ratingCount}',
            label: 'Reviews',
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
  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppPalette.brandSoft),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
            height: 1,
          ),
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

class _RatingStat extends StatelessWidget {
  final double rating;
  const _RatingStat({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final filled = i < rating.round();
            return Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: 13,
              color: filled
                  ? AppPalette.brand
                  : Colors.white.withValues(alpha: 0.25),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            fontFamily: 'Poppins',
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Rating',
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
  final CoachProfileModel coach;
  const _CtaBar({required this.coach});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppPalette.sunsetA, AppPalette.sunsetB, AppPalette.sunsetC],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadius.card),
          bottomRight: Radius.circular(AppRadius.card),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              l10n.translate('share.coach_card_cta'),
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

// ── Initials fallback (no cached_network_image inside RepaintBoundary capture) ──

class _InitialsFallback extends StatelessWidget {
  final String name;
  final double size;
  const _InitialsFallback({required this.name, required this.size});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '?';
    if (list.length == 1) return list[0][0].toUpperCase();
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }

  Color get _bg {
    const palette = [
      Color(0xFFEF5350),
      Color(0xFFEC407A),
      Color(0xFFAB47BC),
      Color(0xFF7E57C2),
      Color(0xFF42A5F5),
      Color(0xFF26C6DA),
      Color(0xFF26A69A),
      Color(0xFF66BB6A),
      Color(0xFFFFA726),
      Color(0xFFFF7043),
    ];
    if (name.isEmpty) return palette[0];
    final hash = name.codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[hash % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: _bg,
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
