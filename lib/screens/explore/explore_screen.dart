import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/recipe_generation_service.dart';
import '../../core/widgets/ds/ds.dart';
import '../ai/widgets/ai_credits_sheet.dart';
import '../recipe/recipe_detail_screen.dart';
import '../recipe/favorites_screen.dart' show FavoritesBody;

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'all';

  final RecipeGenerationService _recipeService = RecipeGenerationService();

  static const _cookTimes = ['all', 'quick', 'medium', 'slow'];
  static const _difficulties = ['all', 'easy', 'medium', 'hard'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Credit gate — capture user/locale synchronously before any await
    final userProv = context.read<UserProvider>();
    final locale =
        context.read<LanguageProvider>().currentLocale.languageCode;
    final uid = userProv.user?.uid;
    final isPremium = userProv.user?.subscriptionTier.isPremiumOrAbove ?? false;
    if (uid != null) {
      final canUse = await AiCreditService().checkAndConsume(uid, isPremium);
      if (!canUse) {
        if (!mounted) return;
        unawaited(AiCreditsSheet.show(context, uid: uid, isPremium: isPremium));
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = context.read<UserProvider>().user?.profile;
      final recipe = await _recipeService.generateRecipe(
        ingredients: [query],
        targetCalories: 500,
        dietaryRestrictions: [
          ...(profile?.dietaryRestrictionIds ?? []),
          ...(profile?.allergyIds ?? []),
        ],
        avoidIngredients: profile?.avoidIngredients ?? [],
        maxTotalMinutes: _cookTimeMinutes(_selectedFilter),
        difficulty: _filterDifficulty(_selectedFilter),
        locale: locale,
      );

      if (recipe != null) {
        if (mounted) {
          unawaited(Navigator.push(
            context,
            AppTransitions.slideUp(RecipeDetailScreen(recipe: recipe)),
          ));
        }
      } else {
        if (mounted) {
          setState(() => _error =
              AppLocalizations.of(context).translate('explore.generate_error'));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.translate('explore.title'), style: t.headlineL),
                        SizedBox(height: 4.h),
                        Text(l10n.translate('explore.subtitle'),
                            style: t.bodyM),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),

            // Tab bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Container(
                height: 44.h,
                decoration: BoxDecoration(
                  color: palette.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.lg.r),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(AppRadius.md.r),
                    boxShadow: [
                      BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: palette.textSecondary,
                  labelStyle: t.labelL.copyWith(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: l10n.translate('explore.tab_discover')),
                    Tab(text: l10n.translate('explore.tab_favorites')),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDiscoverTab(context, palette, primary, l10n, t),
                  const FavoritesBody(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoverTab(BuildContext context, AppPalette palette,
      Color primary, AppLocalizations l10n, AppText t) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 100.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          AppTextField(
            controller: _searchController,
            hintText: l10n.translate('explore.search_hint'),
            prefixIcon: Icon(Icons.search_rounded, color: primary),
            suffixIcon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: primary))
                : IconButton(
                    icon: Icon(Icons.arrow_forward_rounded, color: primary),
                    onPressed: _handleSearch,
                  ),
            onSubmitted: (_) => _handleSearch(),
          ),
          if (_error != null) ...[
            SizedBox(height: 8.h),
            Text(_error!, style: t.labelS.copyWith(color: palette.error)),
          ],
          SizedBox(height: AppSpacing.xl.h),

          // Suggestion chips
          Text(l10n.translate('explore.try_searching'), style: t.titleM),
          SizedBox(height: AppSpacing.sm.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              'explore.suggestion.pasta',
              'explore.suggestion.chicken',
              'explore.suggestion.vegan',
              'explore.suggestion.breakfast',
              'explore.suggestion.salad',
              'explore.suggestion.smoothie',
            ]
                .map((key) => _suggestionChip(l10n.translate(key), palette, primary))
                .toList(),
          ),

          SizedBox(height: AppSpacing.xl.h),

          // Cook-time filters
          Text(l10n.translate('explore.filter_by_time'), style: t.titleM),
          SizedBox(height: AppSpacing.sm.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _cookTimes.map((f) {
                final selected = _selectedFilter == 'time_$f' || (f == 'all' && _selectedFilter == 'all');
                return Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: GestureDetector(
                    onTap: () => setState(
                        () => _selectedFilter = f == 'all' ? 'all' : 'time_$f'),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 16.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: selected
                            ? primary
                            : palette.surfaceVariant,
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: selected ? primary : palette.border,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: primary.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2))
                              ]
                            : [],
                      ),
                      child: Text(
                        l10n.translate('explore.time_filter.$f'),
                        style: t.labelM.copyWith(
                          color:
                              selected ? Colors.white : palette.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          SizedBox(height: AppSpacing.xl.h),

          // Quick-access difficulty row
          Text(l10n.translate('explore.difficulty_label'), style: t.titleM),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            children: _difficulties.map((d) {
              final label = l10n.translate('explore.difficulty.$d');
              final isAll = d == 'all';
              Color diffColor = isAll ? primary : _difficultyColor(d, palette);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: d == 'hard' ? 0 : 8.w),
                  child: GestureDetector(
                    onTap: () => setState(() =>
                        _selectedFilter = d == 'all' ? 'all' : 'diff_$d'),
                    child: _DifficultyCard(
                      label: label,
                      color: diffColor,
                      isSelected: _selectedFilter == (d == 'all' ? 'all' : 'diff_$d'),
                      palette: palette,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int? _cookTimeMinutes(String filter) {
    switch (filter) {
      case 'time_quick': return 20;
      case 'time_medium': return 45;
      default: return null;
    }
  }

  String? _filterDifficulty(String filter) {
    switch (filter) {
      case 'diff_easy': return 'Easy';
      case 'diff_medium': return 'Medium';
      case 'diff_hard': return 'Hard';
      default: return null;
    }
  }

  Color _difficultyColor(String diff, AppPalette palette) {
    switch (diff) {
      case 'easy':
        return palette.success;
      case 'medium':
        return palette.warning;
      case 'hard':
        return palette.error;
      default:
        return palette.textSecondary;
    }
  }

  Widget _suggestionChip(String label, AppPalette palette, Color primary) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _handleSearch();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: primary.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: AppText.of(context)
              .labelM
              .copyWith(color: primary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _DifficultyCard extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final AppPalette palette;

  const _DifficultyCard({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        color: isSelected ? color : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          label,
          style: AppText.of(context).labelM.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ),
    );
  }
}
