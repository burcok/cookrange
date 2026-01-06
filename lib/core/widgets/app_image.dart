import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useMemCache;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final BorderRadius? borderRadius;

  const AppImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.useMemCache = true,
    this.memCacheWidth,
    this.memCacheHeight,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget(context, 'Empty URL');
    }

    // "Super App" Optimization: Enforce memory cache limits
    // Default to ~700px width for standard cached images to save RAM.
    // This is huge for preventing OOM on low-end Androids.
    final int? effectiveMemCacheWidth =
        useMemCache ? (memCacheWidth ?? 700) : null;

    final image = CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: effectiveMemCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: (context, url) =>
          placeholder ??
          Container(
            color: Colors.grey.withOpacity(0.1),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildErrorWidget(context, error),
      fadeInDuration: const Duration(milliseconds: 300), // Smooth fade
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildErrorWidget(BuildContext context, Object error) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: Colors.grey.shade400,
          size: (width != null && width! < 40) ? 16 : 24,
        ),
      ),
    );
  }
}
