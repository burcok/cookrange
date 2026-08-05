import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/models/dish_model.dart';
import '../../core/models/meal_entry_model.dart';
import '../../core/models/meal_plan_template_model.dart';
import '../../core/models/user_nutrition_profile.dart';
import '../../core/providers/language_provider.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/ai/ai_service.dart';
import '../../core/services/ai_credit_service.dart';
import '../../core/services/crashlytics_service.dart';
import '../../core/services/dish_service.dart';
import '../../core/services/feature_gate_service.dart';
import '../../core/services/meal_plan_template_service.dart';
import '../../core/utils/plan_nutrition_calculator.dart';
import '../../core/widgets/ds/ds.dart';
import '../ai/widgets/ai_credits_sheet.dart';
import 'widgets/template_allergen_panel.dart';
import 'widgets/template_day_editor.dart';
import 'widgets/template_nutrition_panel.dart';
import 'widgets/template_source_picker_sheet.dart';

enum _Mode { pickPath, aiForm, editing }

/// Faz 3 §3.3 — "Şablon oluşturucu": ONE screen, three creation paths that
/// all converge into the same live-editing UI.
///
/// - [existing] == null → shows the 3-path picker first (AI-generate / from
///   scratch / fork existing); whichever the author picks seeds [_days] and
///   the screen drops into the shared editor.
/// - [existing] != null → skips the picker, opens straight into the editor
///   (the library's "edit this template" entry point).
///
/// [authorType]/[gymId] are only consulted when [existing] is null (a brand
/// new template's authorship can't be inferred from anywhere else); once a
/// template exists, `author_uid`/`author_type`/`gym_id` are immutable
/// (`firestore.rules` has no client update path for them), so editing always
/// carries them over from [existing] instead.
class MealPlanTemplateCreatorScreen extends StatefulWidget {
  final MealPlanTemplate? existing;
  final String authorType;
  final String? gymId;

  const MealPlanTemplateCreatorScreen({
    super.key,
    this.existing,
    this.authorType = 'coach',
    this.gymId,
  });

  @override
  State<MealPlanTemplateCreatorScreen> createState() =>
      _MealPlanTemplateCreatorScreenState();
}

class _MealPlanTemplateCreatorScreenState
    extends State<MealPlanTemplateCreatorScreen> {
  static const _goalOptions = [
    'lose_weight',
    'gain_weight',
    'maintain_weight',
    'build_muscle',
  ];
  static const _allergyOptions = [
    'gluten',
    'dairy',
    'nuts',
    'egg',
    'shellfish',
    'fish',
    'soy',
    'sesame',
  ];
  static const _restrictionOptions = [
    'vegetarian',
    'vegan',
    'low_carb',
    'high_protein',
    'keto',
    'paleo',
  ];

  late _Mode _mode;
  MealPlanTemplate? _original;

  bool _catalogLoading = true;
  List<DishModel> _allDishes = const [];
  Map<String, DishModel> _dishCatalog = const {};

  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _calorieCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _carbsCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _tagInputCtrl = TextEditingController();

  String _goal = 'maintain_weight';
  List<String> _tags = [];
  List<TemplateDay> _days =
      List.generate(7, (i) => TemplateDay(dayIndex: i, meals: const []));
  bool _isPublic = false;
  String _shareScope = 'private';
  int _activeDayIndex = 0;
  bool _saving = false;
  List<MealEntryClipboard>? _clipboardDay;

  String _aiGoal = 'maintain_weight';
  final _aiCalorieCtrl = TextEditingController(text: '2000');
  final Set<String> _aiAllergyIds = {};
  final Set<String> _aiRestrictionIds = {};
  bool _generating = false;

  String get _authorUid =>
      widget.existing?.authorUid ??
      FirebaseAuth.instance.currentUser?.uid ??
      '';
  String get _authorType => widget.existing?.authorType ?? widget.authorType;
  String? get _gymId => widget.existing?.gymId ?? widget.gymId;
  double get _parsedCalorieTarget => double.tryParse(_calorieCtrl.text) ?? 0;
  Map<String, double> get _parsedTargetMacros => {
        'protein': double.tryParse(_proteinCtrl.text) ?? 0,
        'carbs': double.tryParse(_carbsCtrl.text) ?? 0,
        'fat': double.tryParse(_fatCtrl.text) ?? 0,
      };

  @override
  void initState() {
    super.initState();
    _mode = widget.existing != null ? _Mode.editing : _Mode.pickPath;
    if (widget.existing != null) {
      _original = widget.existing;
      _loadIntoEditor(widget.existing!);
    }
    _loadCatalog();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _calorieCtrl.dispose();
    _proteinCtrl.dispose();
    _carbsCtrl.dispose();
    _fatCtrl.dispose();
    _tagInputCtrl.dispose();
    _aiCalorieCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    final dishes = await DishService().getAllDishes();
    if (!mounted) return;
    setState(() {
      _allDishes = dishes;
      _dishCatalog = {for (final d in dishes) d.id: d};
      _catalogLoading = false;
    });
  }

  List<TemplateDay> _normalizeDays(List<TemplateDay> raw) {
    final byIndex = {for (final d in raw) d.dayIndex: d};
    return List.generate(
        7, (i) => byIndex[i] ?? TemplateDay(dayIndex: i, meals: const []));
  }

  /// Populates every editable field from [tpl]. Deliberately does NOT touch
  /// [_original] — callers decide that separately, since it means different
  /// things per path: the source of truth to diff/update against for an
  /// existing or just-forked (already-persisted) template, vs. `null` for an
  /// AI draft that hasn't been saved yet (see call sites).
  void _loadIntoEditor(MealPlanTemplate tpl) {
    _nameCtrl.text = tpl.name;
    _descriptionCtrl.text = tpl.description;
    _calorieCtrl.text =
        tpl.targetCalories > 0 ? tpl.targetCalories.round().toString() : '';
    _proteinCtrl.text = (tpl.targetMacros['protein'] ?? 0) > 0
        ? tpl.targetMacros['protein']!.round().toString()
        : '';
    _carbsCtrl.text = (tpl.targetMacros['carbs'] ?? 0) > 0
        ? tpl.targetMacros['carbs']!.round().toString()
        : '';
    _fatCtrl.text = (tpl.targetMacros['fat'] ?? 0) > 0
        ? tpl.targetMacros['fat']!.round().toString()
        : '';
    _goal = tpl.goal.isEmpty ? _goal : tpl.goal;
    _tags = List.of(tpl.tags);
    _days = _normalizeDays(tpl.days);
    _isPublic = tpl.isPublic;
    _shareScope = tpl.shareScope;
  }

  // ─── Path 2: from scratch ────────────────────────────────────────────────

  void _startFromScratch() {
    setState(() {
      _days =
          List.generate(7, (i) => TemplateDay(dayIndex: i, meals: const []));
      _mode = _Mode.editing;
    });
  }

  // ─── Path 3: fork existing ───────────────────────────────────────────────

  Future<void> _startFromFork() async {
    final l10n = AppLocalizations.of(context);
    final source = await TemplateSourcePickerSheet.show(
      context,
      currentUid: _authorUid,
      authorType: _authorType,
      gymId: _gymId,
    );
    if (source == null || !mounted) return;

    setState(() => _saving = true);
    try {
      final forked = await MealPlanTemplateService().forkTemplate(
        source,
        authorUid: _authorUid,
        authorType: _authorType,
        gymId: _gymId,
        nameOverride:
            '${source.name} ${l10n.translate('template_builder.library.copy_suffix')}'
                .trim(),
      );
      if (!mounted) return;
      _original =
          forked; // already persisted by forkTemplate — next save UPDATEs it
      _loadIntoEditor(forked);
      setState(() {
        _mode = _Mode.editing;
        _saving = false;
      });
    } catch (e, stack) {
      unawaited(CrashlyticsService().recordError(e, stack,
          reason: 'TemplateCreator._startFromFork source=${source.id}'));
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(
          context, l10n.translate('template_builder.editor.save_error'));
    }
  }

  // ─── Path 1: AI generate ─────────────────────────────────────────────────

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<UserProvider>().user;
    if (user == null) return;

    // Faz 5 §5.4 — Entitlements.weeklyMealPlanGenerations tier-existence
    // check. Like dailyAIChatMessages (see AIChatScreen._sendMessage), the
    // REAL per-day throttle on this AI call is the unified `ai_credits`
    // check just below — this getter (2/10/999 by tier) is a separate,
    // never-wired allowance that predates it and is not enforced as a
    // second, competing quota here. This is the single, honest entry point
    // for "is this tier even allowed to AI-generate a template at all" — a
    // no-op today, wired for real so it's not dead scaffolding.
    if (!await FeatureGateService()
        .check(context, (e) => e.weeklyMealPlanGenerations > 0)) {
      return;
    }
    if (!mounted) return;

    final calorieTarget = double.tryParse(_aiCalorieCtrl.text);
    if (calorieTarget == null || calorieTarget <= 0) {
      AppSnackBar.warning(
          context, l10n.translate('template_builder.ai_form.calorie_required'));
      return;
    }

    final isPremium = user.subscriptionTier.isPremiumOrAbove;
    final canUse = await AiCreditService().checkAndConsume(user.uid, isPremium);
    if (!canUse) {
      if (mounted) {
        unawaited(
            AiCreditsSheet.show(context, uid: user.uid, isPremium: isPremium));
      }
      return;
    }

    if (!mounted) return;
    setState(() => _generating = true);
    final locale = context.read<LanguageProvider>().currentLocale.languageCode;

    try {
      final draft = await MealPlanTemplateService().generateDraftFromAI(
        authorUid: _authorUid,
        authorType: _authorType,
        gymId: _gymId,
        goal: _aiGoal,
        dailyCalorieTarget: calorieTarget,
        dietaryRestrictionIds: _aiRestrictionIds.toList(),
        allergyIds: _aiAllergyIds.toList(),
        locale: locale,
      );
      if (!mounted) return;
      _original = null; // not persisted yet — first Save creates it
      _loadIntoEditor(draft);
      setState(() {
        _mode = _Mode.editing;
        _generating = false;
      });
    } on AIQuotaExceededException {
      unawaited(AiCreditService().rollbackCredit(user.uid));
      if (!mounted) return;
      setState(() => _generating = false);
      unawaited(
          AiCreditsSheet.show(context, uid: user.uid, isPremium: isPremium));
    } catch (e, stack) {
      unawaited(AiCreditService().rollbackCredit(user.uid));
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'TemplateCreator._generate'));
      if (!mounted) return;
      setState(() => _generating = false);
      AppSnackBar.error(
          context, l10n.translate('template_builder.ai_form.error'));
    }
  }

  // ─── Day tab actions: copy/paste day or whole week ───────────────────────

  void _handleDayMenuAction(String action) {
    switch (action) {
      case 'copy':
        setState(() {
          _clipboardDay =
              _days[_activeDayIndex].meals.map(MealEntryClipboard.of).toList();
        });
        AppSnackBar.info(
            context,
            AppLocalizations.of(context)
                .translate('template_builder.editor.day_copied'));
        break;
      case 'paste':
        if (_clipboardDay == null) return;
        setState(() {
          final pasted = _clipboardDay!.map((c) => c.toEntry()).toList();
          _days = [
            for (final d in _days)
              d.dayIndex == _activeDayIndex ? d.copyWith(meals: pasted) : d,
          ];
        });
        break;
      case 'paste_all':
        if (_clipboardDay == null) return;
        setState(() {
          _days = [
            for (final d in _days)
              d.copyWith(
                  meals: _clipboardDay!.map((c) => c.toEntry()).toList()),
          ];
        });
        break;
    }
  }

  // ─── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (_nameCtrl.text.trim().isEmpty) {
      AppSnackBar.warning(
          context, l10n.translate('template_builder.editor.name_required'));
      return;
    }

    final now = DateTime.now();
    final draft = MealPlanTemplate(
      id: _original?.id ?? '',
      authorUid: _authorUid,
      authorType: _authorType,
      gymId: _shareScope == 'gym' ? _gymId : null,
      name: _nameCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      goal: _goal,
      targetCalories: _parsedCalorieTarget,
      targetMacros: _parsedTargetMacros,
      tags: _tags,
      days: _days,
      version: _original?.version ?? 1,
      parentTemplateId: _original?.parentTemplateId,
      isPublic: _isPublic,
      shareScope: _shareScope,
      usageCount: _original?.usageCount ?? 0,
      createdAt: _original?.createdAt ?? now,
      updatedAt: now,
    );

    setState(() => _saving = true);
    try {
      final saved = _original == null
          ? await MealPlanTemplateService().createTemplate(draft)
          : await MealPlanTemplateService()
              .saveEdits(original: _original!, edited: draft);
      if (!mounted) return;
      setState(() {
        _original = saved;
        _saving = false;
      });
      AppSnackBar.success(
          context, l10n.translate('template_builder.editor.saved'));
      Navigator.of(context).pop(saved);
    } catch (e, stack) {
      unawaited(CrashlyticsService()
          .recordError(e, stack, reason: 'TemplateCreator._save'));
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackBar.error(
          context, l10n.translate('template_builder.editor.save_error'));
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: Text(
          _mode == _Mode.editing && _nameCtrl.text.trim().isNotEmpty
              ? _nameCtrl.text.trim()
              : l10n.translate('template_builder.title_new'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // `aiForm` is only ever reached from the path picker (existing ==
        // null in every case that leads here), so this back arrow always has
        // a picker to return to.
        leading: _mode == _Mode.aiForm
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() => _mode = _Mode.pickPath),
              )
            : null,
        actions: [
          if (_mode == _Mode.editing)
            Padding(
              padding: EdgeInsets.only(right: AppSpacing.md.w),
              child: TextButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? SizedBox(
                        width: 18.r,
                        height: 18.r,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.translate('common.save'),
                        style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
      body: _catalogLoading
          ? Padding(
              padding: EdgeInsets.all(AppSpacing.lg.r),
              child: const AppSkeletonList(itemCount: 3, itemHeight: 96),
            )
          : switch (_mode) {
              _Mode.pickPath => _buildPathPicker(context),
              _Mode.aiForm => _buildAiForm(context),
              _Mode.editing => _buildEditor(context),
            },
    );
  }

  Widget _buildPathPicker(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      children: [
        Text(l10n.translate('template_builder.path_picker.heading'),
            style: t.headlineS),
        SizedBox(height: 4.h),
        Text(l10n.translate('template_builder.path_picker.subheading'),
            style: t.bodyM.copyWith(color: palette.textSecondary)),
        SizedBox(height: AppSpacing.lg.h),
        _PathCard(
          icon: Icons.auto_awesome_rounded,
          accent: const Color(0xFF8B5CF6),
          title: l10n.translate('template_builder.path_picker.ai_title'),
          description:
              l10n.translate('template_builder.path_picker.ai_description'),
          onTap: () => setState(() => _mode = _Mode.aiForm),
        ),
        SizedBox(height: AppSpacing.md.h),
        _PathCard(
          icon: Icons.grid_view_rounded,
          accent: const Color(0xFF10B981),
          title: l10n.translate('template_builder.path_picker.scratch_title'),
          description: l10n
              .translate('template_builder.path_picker.scratch_description'),
          onTap: _startFromScratch,
        ),
        SizedBox(height: AppSpacing.md.h),
        _PathCard(
          icon: Icons.fork_right_rounded,
          accent: const Color(0xFF3B82F6),
          title: l10n.translate('template_builder.path_picker.fork_title'),
          description:
              l10n.translate('template_builder.path_picker.fork_description'),
          onTap: _saving ? null : _startFromFork,
        ),
      ],
    );
  }

  Widget _buildAiForm(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('template_builder.ai_form.heading'),
              style: t.headlineS),
          SizedBox(height: AppSpacing.lg.h),
          Text(l10n.translate('template_builder.ai_form.goal_label'),
              style: t.labelL),
          SizedBox(height: 8.h),
          AppChipPicker<String>(
            options: _goalOptions
                .map((g) => AppChipOption(
                    value: g,
                    label: l10n.translate('template_builder.goal.$g')))
                .toList(),
            selected: {_aiGoal},
            onToggle: (v) => setState(() => _aiGoal = v),
          ),
          SizedBox(height: AppSpacing.lg.h),
          AppTextField(
            controller: _aiCalorieCtrl,
            labelText: l10n.translate('template_builder.ai_form.calorie_label'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            suffixText: 'kcal',
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(l10n.translate('template_builder.ai_form.allergy_label'),
              style: t.labelL),
          SizedBox(height: 4.h),
          Text(l10n.translate('template_builder.ai_form.allergy_hint'),
              style: t.labelS
                  .copyWith(color: AppPalette.of(context).textTertiary)),
          SizedBox(height: 8.h),
          AppChipPicker<String>(
            options: _allergyOptions
                .map((a) => AppChipOption(
                    value: a,
                    label:
                        l10n.translate('template_builder.allergy_option.$a')))
                .toList(),
            selected: _aiAllergyIds,
            multiSelect: true,
            onToggle: (v) => setState(() {
              if (_aiAllergyIds.contains(v)) {
                _aiAllergyIds.remove(v);
              } else {
                _aiAllergyIds.add(v);
              }
            }),
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(l10n.translate('template_builder.ai_form.restriction_label'),
              style: t.labelL),
          SizedBox(height: 8.h),
          AppChipPicker<String>(
            options: _restrictionOptions
                .map((r) => AppChipOption(
                    value: r,
                    label: l10n
                        .translate('template_builder.restriction_option.$r')))
                .toList(),
            selected: _aiRestrictionIds,
            multiSelect: true,
            onToggle: (v) => setState(() {
              if (_aiRestrictionIds.contains(v)) {
                _aiRestrictionIds.remove(v);
              } else {
                _aiRestrictionIds.add(v);
              }
            }),
          ),
          SizedBox(height: AppSpacing.xl.h),
          AppButton(
            label: l10n.translate('template_builder.ai_form.generate'),
            icon: Icons.auto_awesome_rounded,
            loading: _generating,
            onPressed: _generating ? null : _generate,
          ),
          SizedBox(height: AppSpacing.lg.h),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final week = PlanNutritionCalculator.calculateWeek(
        _days.map((d) => d.meals).toList(), _dishCatalog);
    final user = context.watch<UserProvider>().user;

    return ListView(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      children: [
        _buildDetailsSection(context),
        SizedBox(height: AppSpacing.lg.h),
        TemplateNutritionPanel(
          dayTotals: week.perDay[_activeDayIndex],
          weekAverageTotals: week.average,
          targetCalories: _parsedCalorieTarget,
          targetMacros: _parsedTargetMacros,
        ),
        SizedBox(height: AppSpacing.lg.h),
        TemplateAllergenPanel(
          days: _days,
          dishCatalog: _dishCatalog,
          ownProfile: user?.profile ?? UserNutritionProfile.empty,
          ownLabel: l10n.translate('common.you'),
        ),
        SizedBox(height: AppSpacing.lg.h),
        _buildDayTabs(context),
        SizedBox(height: AppSpacing.md.h),
        TemplateDayEditor(
          meals: _days[_activeDayIndex].meals,
          dishCatalog: _dishCatalog,
          pickerCatalog: _allDishes,
          onChanged: (meals) => setState(() {
            _days = [
              for (final d in _days)
                d.dayIndex == _activeDayIndex ? d.copyWith(meals: meals) : d,
            ];
          }),
        ),
        SizedBox(height: AppSpacing.xxl.h),
      ],
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final palette = AppPalette.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            controller: _nameCtrl,
            labelText: l10n.translate('template_builder.editor.name_label'),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: AppSpacing.md.h),
          AppTextField(
            controller: _descriptionCtrl,
            labelText:
                l10n.translate('template_builder.editor.description_label'),
            maxLines: 3,
            minLines: 2,
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(l10n.translate('template_builder.editor.goal_label'),
              style: t.labelL),
          SizedBox(height: 6.h),
          AppChipPicker<String>(
            options: _goalOptions
                .map((g) => AppChipOption(
                    value: g,
                    label: l10n.translate('template_builder.goal.$g')))
                .toList(),
            selected: {_goal},
            onToggle: (v) => setState(() => _goal = v),
          ),
          SizedBox(height: AppSpacing.md.h),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _calorieCtrl,
                  labelText:
                      l10n.translate('template_builder.editor.calorie_label'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixText: 'kcal',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _proteinCtrl,
                  labelText: l10n.translate('nutrition.macro_protein_short'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixText: 'g',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: AppTextField(
                  controller: _carbsCtrl,
                  labelText: l10n.translate('nutrition.macro_carbs_short'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixText: 'g',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: AppTextField(
                  controller: _fatCtrl,
                  labelText: l10n.translate('nutrition.macro_fat_short'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  suffixText: 'g',
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(l10n.translate('template_builder.editor.tags_label'),
              style: t.labelL),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ..._tags.map((tag) => Chip(
                    label: Text(tag, style: t.labelS),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    backgroundColor: palette.surfaceVariant,
                    deleteIconColor: palette.textSecondary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )),
              SizedBox(
                width: 150.w,
                child: AppTextField(
                  controller: _tagInputCtrl,
                  hintText: l10n.translate('template_builder.editor.tag_hint'),
                  onSubmitted: (v) {
                    final trimmed = v.trim();
                    if (trimmed.isEmpty || _tags.contains(trimmed)) {
                      _tagInputCtrl.clear();
                      return;
                    }
                    setState(() {
                      _tags.add(trimmed);
                      _tagInputCtrl.clear();
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(l10n.translate('template_builder.editor.share_scope_label'),
              style: t.labelL),
          SizedBox(height: 6.h),
          AppChipPicker<String>(
            options: [
              AppChipOption(
                  value: 'private',
                  label:
                      l10n.translate('template_builder.share_scope.private')),
              if (_gymId != null)
                AppChipOption(
                    value: 'gym',
                    label: l10n.translate('template_builder.share_scope.gym')),
            ],
            selected: {
              _shareScope == 'gym' && _gymId == null ? 'private' : _shareScope
            },
            onToggle: (v) => setState(() => _shareScope = v),
          ),
          SizedBox(height: AppSpacing.sm.h),
          AppToggle(
            value: _isPublic,
            onChanged: (v) => setState(() => _isPublic = v),
            label: l10n.translate('template_builder.editor.is_public_label'),
            description:
                l10n.translate('template_builder.editor.is_public_description'),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTabs(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                  l10n.translate('template_builder.editor.days_heading'),
                  style: t.titleL),
            ),
            PopupMenuButton<String>(
              icon:
                  Icon(Icons.more_horiz_rounded, color: palette.textSecondary),
              onSelected: _handleDayMenuAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'copy',
                  child:
                      Text(l10n.translate('template_builder.editor.copy_day')),
                ),
                PopupMenuItem(
                  value: 'paste',
                  enabled: _clipboardDay != null,
                  child:
                      Text(l10n.translate('template_builder.editor.paste_day')),
                ),
                PopupMenuItem(
                  value: 'paste_all',
                  enabled: _clipboardDay != null,
                  child: Text(
                      l10n.translate('template_builder.editor.paste_all_days')),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8.h),
        AppFilterBar(
          children: List.generate(
            7,
            (i) => AppFilterPill(
              label: l10n.translate('template_builder.editor.day_label',
                  variables: {'n': '${i + 1}'}),
              active: _activeDayIndex == i,
              onTap: () => setState(() => _activeDayIndex = i),
            ),
          ),
        ),
      ],
    );
  }
}

/// A drag-and-drop-shaped picker card for the 3-path entry screen.
class _PathCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String description;
  final VoidCallback? onTap;

  const _PathCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppPalette.of(context);
    return AppCard(
      onTap: onTap,
      semanticLabel: '$title. $description',
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm.r),
            ),
            child: Icon(icon, color: accent, size: 22.r),
          ),
          SizedBox(width: AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: t.titleM),
                SizedBox(height: 2.h),
                Text(description,
                    style: t.bodyM.copyWith(color: palette.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: palette.textTertiary, size: 20.r),
        ],
      ),
    );
  }
}

/// Session-scoped, in-memory-only "clipboard" entry for copy/paste day-or-
/// week (Faz 3 §3.3). Deliberately NOT `MealEntry` itself reused directly —
/// pasting into a DIFFERENT day should copy VALUES, never something that
/// could alias back to the original list — so this holds a plain,
/// independent value snapshot and reconstructs a fresh `MealEntry` on paste.
class MealEntryClipboard {
  final String? dishId;
  final String? customFood;
  final double portion;
  final String mealType;
  final String? note;

  const MealEntryClipboard({
    this.dishId,
    this.customFood,
    required this.portion,
    required this.mealType,
    this.note,
  });

  factory MealEntryClipboard.of(MealEntry e) => MealEntryClipboard(
        dishId: e.dishId,
        customFood: e.customFood,
        portion: e.portion,
        mealType: e.mealType,
        note: e.note,
      );

  MealEntry toEntry() => MealEntry(
        dishId: dishId,
        customFood: customFood,
        portion: portion,
        mealType: mealType,
        note: note,
      );
}
