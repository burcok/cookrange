import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/dish_model.dart';
import '../../core/models/meal_plan_template_model.dart';
import '../../core/models/plan_offer_model.dart';
import '../../core/models/user_nutrition_profile.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/crashlytics_service.dart';
import '../../core/services/dish_service.dart';
import '../../core/services/plan_offer_service.dart';
import '../../core/utils/plan_nutrition_calculator.dart';
import '../../core/widgets/ds/ds.dart';
import '../meal_plan_templates/widgets/template_allergen_panel.dart';
import '../meal_plan_templates/widgets/template_nutrition_panel.dart';
import 'widgets/offer_day_view.dart';

/// Faz 3 §3.5 — "Önizleme: 28 öğün, besin değerleri, kendi hedefine göre
/// sapma, alerjen kontrolü". The member's own allergen check + nutrition
/// panel are both REUSED exactly as §3.3 built them for a template author's
/// own profile (`TemplateAllergenPanel`/`TemplateNutritionPanel`) — from the
/// viewer's perspective here, "own profile" IS correct: a member previewing
/// an offer sent TO them is checking it against THEIR OWN allergen/goal
/// data, which they fully own and can read (unlike the coach/gym-previews-
/// a-specific-member's-profile case §3.3 deliberately did NOT build).
class PlanOfferPreviewScreen extends StatefulWidget {
  final PlanOffer offer;
  const PlanOfferPreviewScreen({super.key, required this.offer});

  @override
  State<PlanOfferPreviewScreen> createState() => _PlanOfferPreviewScreenState();
}

class _PlanOfferPreviewScreenState extends State<PlanOfferPreviewScreen> {
  late final MealPlanTemplate _template = MealPlanTemplate.fromJson(
      widget.offer.templateSnapshot, widget.offer.templateId);
  late final List<TemplateDay> _sortedDays = [..._template.days]
    ..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

  bool _catalogLoading = true;
  Map<String, DishModel> _dishCatalog = const {};
  int _activeDayIndex = 0;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final dishes = await DishService().getAllDishes();
    if (!mounted) return;
    setState(() {
      _dishCatalog = {for (final d in dishes) d.id: d};
      _catalogLoading = false;
    });
  }

  Future<void> _accept(String uid) async {
    final user = context.read<UserProvider>().user;
    if (user == null || _acting) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _acting = true);
    try {
      await PlanOfferService().acceptOffer(user: user, offer: widget.offer);
      if (!mounted) return;
      AppSnackBar.success(
          context, l10n.translate('plan_offer.preview.accept_success'));
      Navigator.of(context).pop();
    } catch (e, st) {
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'PlanOfferPreviewScreen._accept'));
      if (!mounted) return;
      setState(() => _acting = false);
      AppSnackBar.error(
          context, l10n.translate('plan_offer.preview.accept_error'));
    }
  }

  Future<void> _declineFlow(String uid) async {
    final l10n = AppLocalizations.of(context);
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _DeclineReasonDialog(l10n: l10n),
    );
    if (reason == null || _acting) return; // dialog cancelled
    setState(() => _acting = true);
    try {
      await PlanOfferService()
          .declineOffer(uid: uid, offerId: widget.offer.id, reason: reason);
      if (!mounted) return;
      AppSnackBar.success(
          context, l10n.translate('plan_offer.preview.decline_success'));
      Navigator.of(context).pop();
    } catch (e, st) {
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'PlanOfferPreviewScreen._decline'));
      if (!mounted) return;
      setState(() => _acting = false);
      AppSnackBar.error(
          context, l10n.translate('plan_offer.preview.decline_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final user = context.watch<UserProvider>().user;
    final offer = widget.offer;
    final uid = user?.uid ?? '';

    if (_catalogLoading) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(title: Text(l10n.translate('plan_offer.preview.title'))),
        body: const AppSkeletonList(itemCount: 4),
      );
    }

    final week = PlanNutritionCalculator.calculateWeek(
        _sortedDays.map((d) => d.meals).toList(), _dishCatalog);
    final target = PlanOfferService.computeMemberTarget(
        user?.profile ?? UserNutritionProfile.empty);
    final totalMeals = _sortedDays.fold<int>(0, (s, d) => s + d.meals.length);
    final canRespond = offer.isPending && !offer.isExpired;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(title: Text(l10n.translate('plan_offer.preview.title'))),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xl.h),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 18.r, color: Theme.of(context).primaryColor),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _template.name.isEmpty
                            ? l10n
                                .translate('template_builder.library.untitled')
                            : _template.name,
                        style: t.titleL,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  l10n.translate('plan_offer.preview.from_line', variables: {
                    'name': offer.fromName,
                  }),
                  style: t.labelM.copyWith(color: palette.textSecondary),
                ),
                if ((offer.message ?? '').isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm.r),
                    decoration: BoxDecoration(
                      color: palette.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    ),
                    child: Text('"${offer.message}"',
                        style: t.bodyM.copyWith(fontStyle: FontStyle.italic)),
                  ),
                ],
                SizedBox(height: 8.h),
                Text(
                  l10n.translate('plan_offer.preview.meal_count', variables: {
                    'days': '${_sortedDays.length}',
                    'meals': '$totalMeals',
                  }),
                  style: t.labelS.copyWith(color: palette.textTertiary),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          if (!canRespond)
            _StatusBanner(offer: offer, l10n: l10n, palette: palette, t: t),
          if (!canRespond) SizedBox(height: AppSpacing.lg.h),
          TemplateNutritionPanel(
            dayTotals: week.perDay[_activeDayIndex],
            weekAverageTotals: week.average,
            targetCalories: target.calories,
            targetMacros: target.macros,
          ),
          SizedBox(height: AppSpacing.lg.h),
          TemplateAllergenPanel(
            days: _template.days,
            dishCatalog: _dishCatalog,
            ownProfile: user?.profile ?? UserNutritionProfile.empty,
            ownLabel: l10n.translate('common.you'),
          ),
          SizedBox(height: AppSpacing.lg.h),
          AppFilterBar(
            children: List.generate(
              _sortedDays.length,
              (i) => AppFilterPill(
                label: l10n.translate('template_builder.editor.day_label',
                    variables: {'n': '${i + 1}'}),
                active: _activeDayIndex == i,
                onTap: () => setState(() => _activeDayIndex = i),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          OfferDayView(
            meals: _sortedDays[_activeDayIndex].meals,
            dishCatalog: _dishCatalog,
          ),
          if (canRespond) ...[
            SizedBox(height: AppSpacing.xl.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: l10n.translate('plan_offer.preview.decline_btn'),
                    variant: AppButtonVariant.tonal,
                    onPressed: _acting ? null : () => _declineFlow(uid),
                  ),
                ),
                SizedBox(width: AppSpacing.md.w),
                Expanded(
                  child: AppButton(
                    label: l10n.translate('plan_offer.preview.accept_btn'),
                    loading: _acting,
                    onPressed: _acting ? null : () => _accept(uid),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final PlanOffer offer;
  final AppLocalizations l10n;
  final AppPalette palette;
  final AppText t;

  const _StatusBanner({
    required this.offer,
    required this.l10n,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, key) = switch (offer.status) {
      'accepted' => (
          Icons.check_circle_rounded,
          palette.success,
          'plan_offer.preview.status_accepted'
        ),
      'declined' => (
          Icons.cancel_rounded,
          palette.textSecondary,
          'plan_offer.preview.status_declined'
        ),
      _ => (
          Icons.schedule_rounded,
          palette.warning,
          'plan_offer.preview.status_expired'
        ),
    };
    final dateStr = offer.respondedAt != null
        ? DateFormat('dd.MM.yyyy').format(offer.respondedAt!)
        : DateFormat('dd.MM.yyyy').format(offer.expiresAt);

    return Container(
      padding: EdgeInsets.all(AppSpacing.sm.r),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16.r, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              l10n.translate(key, variables: {'date': dateStr}),
              style:
                  t.labelM.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeclineReasonDialog extends StatefulWidget {
  final AppLocalizations l10n;
  const _DeclineReasonDialog({required this.l10n});

  @override
  State<_DeclineReasonDialog> createState() => _DeclineReasonDialogState();
}

class _DeclineReasonDialogState extends State<_DeclineReasonDialog> {
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.translate('plan_offer.preview.decline_dialog_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('plan_offer.preview.decline_dialog_body')),
          const SizedBox(height: 12),
          AppTextField(
            controller: _reasonCtrl,
            hintText: l10n.translate('plan_offer.preview.decline_reason_hint'),
            maxLines: 3,
            minLines: 2,
            maxLength: 300,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.translate('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_reasonCtrl.text.trim()),
          child: Text(
            l10n.translate('plan_offer.preview.decline_btn'),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
