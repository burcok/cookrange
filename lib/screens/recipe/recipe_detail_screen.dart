import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/recipe_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'cooking_mode_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_isScrolled) {
        setState(() => _isScrolled = true);
      } else if (_scrollController.offset <= 200 && _isScrolled) {
        setState(() => _isScrolled = false);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildSliverAppBar(context, themeProvider),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: AppSpacing.xl.h),
                      _buildHeaderInfo(l10n, themeProvider, palette),
                      SizedBox(height: AppSpacing.xl.h),
                      _buildGlassNutritionCard(l10n, themeProvider, palette),
                      SizedBox(height: AppSpacing.xxl.h),
                      _buildDescription(l10n, palette),
                      SizedBox(height: AppSpacing.xxl.h),
                      _buildTabs(l10n, themeProvider, palette),
                      SizedBox(height: AppSpacing.xl.h),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIngredientsList(l10n, themeProvider, palette),
                    _buildInstructionsList(l10n, themeProvider, palette),
                  ],
                ),
              ),
            ],
          ),
          _buildBottomAction(context, l10n, themeProvider, palette),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, ThemeProvider themeProvider) {
    return SliverAppBar(
      expandedHeight: 400.h,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: Padding(
        padding: EdgeInsets.all(8.w),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.all(8.w),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.2),
                child: IconButton(
                  icon: const Icon(Icons.bookmark_border, color: Colors.white),
                  onPressed: () {
                    // TODO: Implement Bookmark
                  },
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'recipe_image_${widget.recipe.id}',
              child: CachedNetworkImage(
                imageUrl: widget.recipe.imageUrl ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: Colors.grey[200]),
                errorWidget: (context, url, error) => Container(
                  color: themeProvider.primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.restaurant,
                      color: themeProvider.primaryColor, size: 50),
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(
      AppLocalizations l10n, ThemeProvider themeProvider, AppPalette palette) {
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.recipe.title,
                style: t.headlineL,
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w, vertical: AppSpacing.xxs.h),
              decoration: BoxDecoration(
                color: themeProvider.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
              child: Text(
                widget.recipe.difficulty.toUpperCase(),
                style: t.labelS.copyWith(
                  color: themeProvider.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppSpacing.xs.h),
        Row(
          children: [
            Icon(Icons.access_time_rounded,
                size: AppSize.iconXs.sp, color: palette.textSecondary),
            SizedBox(width: AppSpacing.xxs.w),
            Text(
              "${widget.recipe.totalTimeMinutes} ${l10n.translate('recipe.minutes')}",
              style: t.bodyM,
            ),
            SizedBox(width: AppSpacing.md.w),
            Icon(Icons.group_outlined,
                size: AppSize.iconXs.sp, color: palette.textSecondary),
            SizedBox(width: AppSpacing.xxs.w),
            Text(
              "${widget.recipe.servings} ${l10n.translate('recipe.servings')}",
              style: t.bodyM,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGlassNutritionCard(
      AppLocalizations l10n, ThemeProvider themeProvider, AppPalette palette) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.xl.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: EdgeInsets.all(AppSpacing.lg.r),
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.xl.r),
            border:
                Border.all(color: palette.border.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroItem(
                l10n.translate('home.calories'),
                "${widget.recipe.macros['calories']?.toInt() ?? 0}",
                "kcal",
                palette.calories,
                palette,
              ),
              _buildVerticalDivider(palette),
              _buildMacroItem(
                l10n.translate('home.macros.protein'),
                "${widget.recipe.macros['protein']?.toInt() ?? 0}",
                "g",
                palette.protein,
                palette,
              ),
              _buildVerticalDivider(palette),
              _buildMacroItem(
                l10n.translate('home.macros.carbs'),
                "${widget.recipe.macros['carbs']?.toInt() ?? 0}",
                "g",
                palette.carbs,
                palette,
              ),
              _buildVerticalDivider(palette),
              _buildMacroItem(
                l10n.translate('home.macros.fat'),
                "${widget.recipe.macros['fat']?.toInt() ?? 0}",
                "g",
                palette.fat,
                palette,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroItem(
      String label, String value, String unit, Color color, AppPalette palette) {
    final t = AppText.of(context);
    return Column(
      children: [
        Text(
          value,
          style: t.headlineS.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          unit,
          style: t.labelS,
        ),
        SizedBox(height: AppSpacing.xxs.h),
        Text(
          label,
          style: t.labelS.copyWith(color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider(AppPalette palette) {
    return Container(
      height: 40.h,
      width: 1,
      color: palette.divider,
    );
  }

  Widget _buildDescription(AppLocalizations l10n, AppPalette palette) {
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('recipe.description'),
          style: t.headlineS,
        ),
        SizedBox(height: AppSpacing.xs.h),
        Text(
          widget.recipe.description,
          style: t.bodyL,
        ),
      ],
    );
  }

  Widget _buildTabs(
      AppLocalizations l10n, ThemeProvider themeProvider, AppPalette palette) {
    final t = AppText.of(context);
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: themeProvider.primaryColor,
          borderRadius: BorderRadius.circular(AppRadius.md.r),
          boxShadow: [
            BoxShadow(
              color: themeProvider.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: palette.textSecondary,
        labelStyle: t.titleM.copyWith(
            color: Colors.white, fontWeight: FontWeight.bold),
        tabs: [
          Tab(text: l10n.translate('recipe.ingredients')),
          Tab(text: l10n.translate('recipe.instructions')),
        ],
      ),
    );
  }

  Widget _buildIngredientsList(
      AppLocalizations l10n, ThemeProvider themeProvider, AppPalette palette) {
    final t = AppText.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${widget.recipe.ingredients.length} ${l10n.translate('recipe.items')}",
                style: t.labelM,
              ),
              TextButton.icon(
                onPressed: () async {
                  final storage = StorageService();
                  for (var ingredient in widget.recipe.ingredients) {
                    await storage.addToShoppingList(ingredient);
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.translate('recipe.added_to_list')),
                        backgroundColor: themeProvider.primaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button)),
                      ),
                    );
                  }
                },
                icon: Icon(Icons.add_shopping_cart,
                    size: AppSize.iconSm, color: themeProvider.primaryColor),
                label: Text(
                  l10n.translate('recipe.add_to_list'),
                  style: t.labelM.copyWith(
                      color: themeProvider.primaryColor,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.only(bottom: 120.h),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: widget.recipe.ingredients.length,
              separatorBuilder: (_, __) => SizedBox(height: AppSpacing.sm.h),
              itemBuilder: (context, index) {
                final ingredient = widget.recipe.ingredients[index];
                return Container(
                  padding: EdgeInsets.all(AppSpacing.md.r),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card.r),
                    boxShadow: [
                      BoxShadow(
                        color: palette.shadow.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: themeProvider.primaryColor
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check,
                            color: themeProvider.primaryColor,
                            size: AppSize.iconSm.sp),
                      ),
                      SizedBox(width: AppSpacing.md.w),
                      Expanded(
                        child: Text(
                          ingredient.name,
                          style: t.titleL,
                        ),
                      ),
                      Text(
                        "${ingredient.amount} ${ingredient.unit}",
                        style: t.labelM,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsList(
      AppLocalizations l10n, ThemeProvider themeProvider, AppPalette palette) {
    final t = AppText.of(context);
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl.w, 0, AppSpacing.xl.w, 120.h),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: widget.recipe.instructions.length,
      separatorBuilder: (_, __) => SizedBox(height: AppSpacing.md.h),
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32.w,
              height: 32.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: themeProvider.primaryColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeProvider.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                "${index + 1}",
                style: t.labelM.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: AppSpacing.md.w),
            Expanded(
              child: Container(
                padding: EdgeInsets.all(AppSpacing.md.r),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card.r),
                  boxShadow: [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  widget.recipe.instructions[index],
                  style: t.bodyL,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomAction(BuildContext context, AppLocalizations l10n,
      ThemeProvider themeProvider, AppPalette palette) {
    final t = AppText.of(context);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(AppSpacing.xl.w, AppSpacing.xl.h,
            AppSpacing.xl.w, MediaQuery.of(context).padding.bottom + 16.h),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xxl.r)),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CookingModeScreen(recipe: widget.recipe),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: themeProvider.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 18.h),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xl.r)),
            elevation: 8,
            shadowColor: themeProvider.primaryColor.withValues(alpha: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.restaurant_menu),
              SizedBox(width: AppSpacing.sm.w),
              Text(
                l10n.translate('recipe.start_cooking'),
                style: t.labelL.copyWith(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
