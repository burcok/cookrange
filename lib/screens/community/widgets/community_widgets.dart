import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/app_dimensions.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool enableBlur;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 16.0,
    this.opacity = 0.6,
    this.color = Colors.white,
    this.borderRadius,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.border,
    this.boxShadow,
    this.enableBlur = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    if (!enableBlur) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color.withValues(
              alpha: opacity + 0.2 > 1.0 ? 1.0 : opacity + 0.2),
          borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
          border: border ?? Border.all(color: palette.border),
          boxShadow: boxShadow,
        ),
        child: child,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: boxShadow,
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              border: border ?? Border.all(color: palette.border),
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
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: AppSize.avatarLg,
            height: AppSize.avatarLg,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: isNew || hasUpdate
                  ? Border.all(color: primaryColor, width: 2)
                  : Border.all(color: Colors.transparent, width: 2),
            ),
            padding: const EdgeInsets.all(2),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isNew
                    ? primaryColor.withValues(alpha: 0.12)
                    : palette.surface,
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
                          color: primaryColor, size: 30),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            style: textStyles.labelS,
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
    final palette = AppPalette.of(context);
    final textStyles = AppText.of(context);
    final primaryColor = context.watch<ThemeProvider>().primaryColor;

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<T>(
        onSelected: onChanged,
        offset: const Offset(0, 32),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        elevation: 4,
        surfaceTintColor: Colors.transparent,
        tooltip: '',
        itemBuilder: (context) {
          return items.map((T item) {
            final isSelected = item == value;
            return PopupMenuItem<T>(
              value: item,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      itemBuilder(item),
                      style: textStyles.titleM.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? primaryColor : palette.textPrimary,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_rounded,
                        size: AppSize.iconSm, color: primaryColor)
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                itemBuilder(value),
                style: textStyles.titleM,
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: AppSize.iconMd,
                color: primaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
