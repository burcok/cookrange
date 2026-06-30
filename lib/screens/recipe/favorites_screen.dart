import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/recipe_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/favorite_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'recipe_detail_screen.dart';

/// Standalone favorites screen (accessed via route).
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

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
          l10n.translate('favorites.title'),
          style: AppText.of(context).headlineS,
        ),
        centerTitle: true,
      ),
      body: const FavoritesBody(),
    );
  }
}

/// Embeddable favorites content (used in ExploreScreen tab too).
class FavoritesBody extends StatelessWidget {
  const FavoritesBody({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<List<Recipe>>(
      stream: FavoriteService().getFavoritesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: AppSkeletonList(itemCount: 5),
          );
        }

        final recipes = snapshot.data ?? [];

        if (recipes.isEmpty) {
          return AppEmptyState(
            icon: Icons.bookmark_border_rounded,
            title: l10n.translate('favorites.empty_title'),
            message: l10n.translate('favorites.empty_subtitle'),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 100.h),
          itemCount: recipes.length,
          separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md.h),
          itemBuilder: (context, index) => RepaintBoundary(
            child:
                _FavoriteRecipeCard(recipe: recipes[index], primary: primary),
          ),
        );
      },
    );
  }
}

class _FavoriteRecipeCard extends StatelessWidget {
  final Recipe recipe;
  final Color primary;

  const _FavoriteRecipeCard({required this.recipe, required this.primary});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        AppTransitions.slideUp(RecipeDetailScreen(recipe: recipe)),
      ),
      child: Container(
        height: 120.h,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            Hero(
              tag: 'recipe_image_${recipe.id}',
              child: ClipRRect(
                borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(AppRadius.card.r)),
                child: CachedNetworkImage(
                  imageUrl: recipe.imageUrl ?? '',
                  width: 110.w,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: primary.withValues(alpha: 0.1),
                    child: Icon(Icons.restaurant,
                        color: primary, size: AppSize.iconMd.sp),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: primary.withValues(alpha: 0.1),
                    child: Icon(Icons.restaurant,
                        color: primary, size: AppSize.iconMd.sp),
                  ),
                ),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      recipe.title,
                      style: t.titleL,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSpacing.xs.h),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 14.sp, color: palette.calories),
                        SizedBox(width: 4.w),
                        Text(
                          '${recipe.macros['calories']?.toInt() ?? 0} kcal',
                          style: t.labelS.copyWith(color: palette.calories),
                        ),
                        SizedBox(width: AppSpacing.sm.w),
                        Icon(Icons.access_time_rounded,
                            size: 14.sp, color: palette.textSecondary),
                        SizedBox(width: 4.w),
                        Text(
                          '${recipe.totalTimeMinutes} ${l10n.translate('recipe.minutes')}',
                          style: t.labelS,
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xs.h),
                    // Macro pills
                    Row(
                      children: [
                        _MacroPill(
                            value: recipe.macros['protein']?.toInt() ?? 0,
                            label: 'P',
                            color: palette.protein),
                        SizedBox(width: 4.w),
                        _MacroPill(
                            value: recipe.macros['carbs']?.toInt() ?? 0,
                            label: 'C',
                            color: palette.carbs),
                        SizedBox(width: 4.w),
                        _MacroPill(
                            value: recipe.macros['fat']?.toInt() ?? 0,
                            label: 'F',
                            color: palette.fat),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Remove favorite button
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm.w),
              child: IconButton(
                icon: Icon(Icons.bookmark,
                    color: primary, size: AppSize.iconMd.sp),
                onPressed: () => FavoriteService().toggleFavorite(recipe),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final int value;
  final String label;
  final Color color;

  const _MacroPill(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.xs.r),
      ),
      child: Text(
        '$label: ${value}g',
        style: AppText.of(context)
            .labelS
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
