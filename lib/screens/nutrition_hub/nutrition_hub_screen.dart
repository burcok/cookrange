import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/dish_model.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/dish_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../home/nutrition_analytics_screen.dart';
import '../recipe/favorites_screen.dart';
import '../recipe/recipe_detail_screen.dart';

/// Unified Foods & Nutrition hub: browse the full dish catalog, view saved
/// favorites, and see weekly nutrition insights — all in one place.
class NutritionHubScreen extends StatefulWidget {
  /// 0 = Browse, 1 = Favorites, 2 = Insights.
  final int initialTab;

  const NutritionHubScreen({super.key, this.initialTab = 0});

  @override
  State<NutritionHubScreen> createState() => _NutritionHubScreenState();
}

class _NutritionHubScreenState extends State<NutritionHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final l10n = AppLocalizations.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('nutrition_hub.title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: palette.textTertiary,
          indicatorColor: primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: t.labelL.copyWith(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: l10n.translate('nutrition_hub.tab_browse')),
            Tab(text: l10n.translate('nutrition_hub.tab_favorites')),
            Tab(text: l10n.translate('nutrition_hub.tab_analytics')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BrowseFoodsTab(),
          FavoritesBody(),
          NutritionAnalyticsScreen(showChrome: false),
        ],
      ),
    );
  }
}

// ── Browse Foods tab ──────────────────────────────────────────────────────────

class _BrowseFoodsTab extends StatefulWidget {
  const _BrowseFoodsTab();

  @override
  State<_BrowseFoodsTab> createState() => _BrowseFoodsTabState();
}

class _BrowseFoodsTabState extends State<_BrowseFoodsTab>
    with AutomaticKeepAliveClientMixin {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String _category = 'all';

  // (category key, localization key) — keys match DishModel.category values.
  static const _categories = <(String, String)>[
    ('all', 'nutrition_hub.cat_all'),
    ('chicken', 'nutrition_hub.cat_chicken'),
    ('red_meat', 'nutrition_hub.cat_red_meat'),
    ('fish', 'nutrition_hub.cat_fish'),
    ('breakfast', 'nutrition_hub.cat_breakfast'),
    ('vegetarian', 'nutrition_hub.cat_vegetarian'),
    ('vegan', 'nutrition_hub.cat_vegan'),
    ('diet', 'nutrition_hub.cat_diet'),
    ('sport', 'nutrition_hub.cat_sport'),
    ('turkish_classic', 'nutrition_hub.cat_turkish_classic'),
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim().toLowerCase());
    });
  }

  IconData _iconFor(String cat) {
    switch (cat) {
      case 'chicken':
        return Icons.egg_alt_rounded;
      case 'red_meat':
        return Icons.kebab_dining_rounded;
      case 'fish':
        return Icons.set_meal_rounded;
      case 'breakfast':
        return Icons.bakery_dining_rounded;
      case 'vegetarian':
        return Icons.eco_rounded;
      case 'vegan':
        return Icons.spa_rounded;
      case 'diet':
        return Icons.monitor_weight_rounded;
      case 'sport':
        return Icons.fitness_center_rounded;
      case 'turkish_classic':
        return Icons.restaurant_rounded;
      default:
        return Icons.apps_rounded;
    }
  }

  bool _matches(DishModel d) {
    if (_category != 'all' && d.category != _category) return false;
    if (_query.isEmpty) return true;
    return d.name.toLowerCase().contains(_query) ||
        d.nameEn.toLowerCase().contains(_query) ||
        d.tags.any((t) => t.toLowerCase().contains(_query));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
          child: AppTextField(
            controller: _searchCtrl,
            hintText: l10n.translate('nutrition_hub.search_hint'),
            prefixIcon: const Icon(Icons.search_rounded),
            onChanged: _onQueryChanged,
            textInputAction: TextInputAction.search,
          ),
        ),
        AppFilterBar(
          children: _categories
              .map((c) => AppFilterPill(
                    label: l10n.translate(c.$2),
                    icon: _iconFor(c.$1),
                    active: _category == c.$1,
                    onTap: () => setState(() => _category = c.$1),
                  ))
              .toList(),
        ),
        SizedBox(height: 8.h),
        Expanded(
          child: StreamBuilder<List<DishModel>>(
            stream: DishService().getAllDishesStream(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AppSkeletonList();
              }
              final all = snap.data ?? const <DishModel>[];
              final dishes = all.where(_matches).toList();
              if (dishes.isEmpty) {
                return AppEmptyState(
                  icon: Icons.restaurant_menu_rounded,
                  title: l10n.translate('nutrition_hub.empty_title'),
                  message: l10n.translate('nutrition_hub.empty_msg'),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 100.h),
                physics: const BouncingScrollPhysics(),
                itemCount: dishes.length,
                separatorBuilder: (_, __) => SizedBox(height: 10.h),
                itemBuilder: (ctx, i) => RepaintBoundary(
                  child: _DishCard(dish: dishes[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DishCard extends StatelessWidget {
  final DishModel dish;
  const _DishCard({required this.dish});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;
    final isEn =
        context.read<LanguageProvider>().currentLocale.languageCode == 'en';
    final title = (isEn && dish.nameEn.isNotEmpty) ? dish.nameEn : dish.name;

    return AppCard(
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.of(context).push(
        AppTransitions.slideRight(RecipeDetailScreen(recipe: dish.toRecipe())),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm.r),
            child: SizedBox(
              width: 64.r,
              height: 64.r,
              child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: dish.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Container(color: palette.surfaceVariant),
                      errorWidget: (_, __, ___) =>
                          _placeholder(palette, primary),
                    )
                  : _placeholder(palette, primary),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.bodyM.copyWith(
                      color: palette.textPrimary, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 3.h),
                Row(
                  children: [
                    Icon(Icons.local_fire_department_rounded,
                        size: 13.r, color: palette.calories),
                    SizedBox(width: 3.w),
                    Text('${dish.calories.round()} kcal',
                        style: t.labelS.copyWith(color: palette.textSecondary)),
                    SizedBox(width: 10.w),
                    Icon(Icons.schedule_rounded,
                        size: 13.r, color: palette.textTertiary),
                    SizedBox(width: 3.w),
                    Flexible(
                      child: Text(
                        '${dish.prepTimeMinutes + dish.cookTimeMinutes} min',
                        style:
                            t.labelS.copyWith(color: palette.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5.h),
                Row(
                  children: [
                    _MacroDot(
                        label: 'P ${dish.protein.round()}',
                        color: palette.protein),
                    SizedBox(width: 8.w),
                    _MacroDot(
                        label: 'C ${dish.carbs.round()}', color: palette.carbs),
                    SizedBox(width: 8.w),
                    _MacroDot(
                        label: 'F ${dish.fat.round()}', color: palette.fat),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
        ],
      ),
    );
  }

  Widget _placeholder(AppPalette palette, Color primary) {
    return Container(
      color: primary.withValues(alpha: 0.1),
      child: Icon(Icons.restaurant_rounded, color: primary, size: 26.r),
    );
  }
}

class _MacroDot extends StatelessWidget {
  final String label;
  final Color color;
  const _MacroDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7.r,
          height: 7.r,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(label,
            style: t.labelS.copyWith(
                color: color, fontWeight: FontWeight.w600, fontSize: 11.sp)),
      ],
    );
  }
}
