import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Border? border;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.opacity = 0.6, // bg-white/60
    this.color = Colors.white,
    this.borderRadius,
    this.padding = const EdgeInsets.all(20),
    this.border,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:
            Colors.transparent, // Important for shadow to look right with glass
        boxShadow: boxShadow,
        borderRadius: borderRadius ?? BorderRadius.circular(24),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withOpacity(opacity),
              border: border ??
                  Border.all(
                    color: Colors.white.withOpacity(0.5),
                    width: 1.0,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class StoryCircle extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool isNew;
  final bool hasUpdate;
  final VoidCallback onTap;

  const StoryCircle({
    super.key,
    required this.label,
    this.imageUrl,
    this.isNew = false,
    this.hasUpdate = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // If hasUpdate, show colored border
              border: isNew || hasUpdate
                  ? Border.all(
                      color: context.watch<ThemeProvider>().primaryColor,
                      width: 2) // Primary Color
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            padding:
                const EdgeInsets.all(2), // Spacing between border and image
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isNew ? const Color(0xFFFFF7ED) : Colors.white, // Orange-50
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: isNew
                  ? Center(
                      child: Icon(Icons.add_rounded,
                          color: context.watch<ThemeProvider>().primaryColor,
                          size: 30),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class MinimalCustomDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T> onChanged;
  final String Function(T) itemBuilder;

  const MinimalCustomDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<T>(
        onSelected: onChanged,
        offset: const Offset(0, 32), // Slightly lower to not cover the button
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        surfaceTintColor: Colors.transparent, // Remove M3 tint
        tooltip: '',
        itemBuilder: (context) {
          return items.map((T item) {
            final isSelected = item == value;
            return PopupMenuItem<T>(
              value: item,
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      itemBuilder(item),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? context.watch<ThemeProvider>().primaryColor
                            : (isDark ? Colors.white : const Color(0xFF2E3A59)),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded,
                        size: 18,
                        color: context.watch<ThemeProvider>().primaryColor)
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                itemBuilder(value),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF2E3A59),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: context.watch<ThemeProvider>().primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
