import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';

/// Deterministic avatar widget — shows [photoUrl] when available, falls back
/// to a colored circle with the user's initials. Never shows broken images or
/// random placeholder faces.
class AppInitialsAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;
  final bool circle;

  const AppInitialsAvatar({
    super.key,
    this.photoUrl,
    required this.name,
    this.size = AppSize.avatarMd,
    this.circle = true,
  });

  String get _initials {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  // Deterministic hue from name — same name always gets the same color.
  Color _colorFromName() {
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
    final url = photoUrl ?? '';
    final radius = circle ? size / 2 : 0.0;

    if (url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 2).toInt(),
          placeholder: (_, __) => _buildInitialsBox(context),
          errorWidget: (_, __, ___) => _buildInitialsBox(context),
          fadeInDuration: const Duration(milliseconds: 200),
        ),
      );
    }

    return _buildInitialsBox(context);
  }

  Widget _buildInitialsBox(BuildContext context) {
    final fontSize = (size * 0.38).clamp(9.0, 24.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _colorFromName(),
        borderRadius: BorderRadius.circular(circle ? size / 2 : AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
