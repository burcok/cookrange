import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/models/challenge_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/challenge_service.dart';
import '../../../core/widgets/ds/ds.dart';

class CreateChallengeSheet extends StatefulWidget {
  const CreateChallengeSheet({super.key});

  @override
  State<CreateChallengeSheet> createState() => _CreateChallengeSheetState();
}

class _CreateChallengeSheetState extends State<CreateChallengeSheet> {
  final ChallengeService _service = ChallengeService();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _goalCtrl = TextEditingController();

  ChallengeType _selectedType = ChallengeType.steps;
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _isPublic = true;
  bool _isCreating = false;

  static IconData _typeIcon(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return Icons.directions_walk;
      case ChallengeType.calories:
        return Icons.local_fire_department;
      case ChallengeType.workoutDays:
        return Icons.fitness_center;
      case ChallengeType.custom:
        return Icons.emoji_events;
    }
  }

  static String _typeLabelKey(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return 'challenge.type.steps';
      case ChallengeType.calories:
        return 'challenge.type.calories';
      case ChallengeType.workoutDays:
        return 'challenge.type.workoutDays';
      case ChallengeType.custom:
        return 'challenge.type.custom';
    }
  }

  static String _typeDefaultUnit(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return 'steps';
      case ChallengeType.calories:
        return 'kcal';
      case ChallengeType.workoutDays:
        return 'days';
      case ChallengeType.custom:
        return '';
    }
  }

  static String _typeDefaultGoal(ChallengeType t) {
    switch (t) {
      case ChallengeType.steps:
        return '10000';
      case ChallengeType.calories:
        return '500';
      case ChallengeType.workoutDays:
        return '5';
      case ChallengeType.custom:
        return '100';
    }
  }

  @override
  void initState() {
    super.initState();
    _goalCtrl.text = '10000';
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      _titleCtrl.text.trim().isNotEmpty &&
      (int.tryParse(_goalCtrl.text) ?? 0) > 0 &&
      !_isCreating;

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _endDate = picked);
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final title = _titleCtrl.text.trim();
    final goal = int.tryParse(_goalCtrl.text) ?? 0;
    if (title.isEmpty || goal <= 0) return;

    final unit = _selectedType == ChallengeType.custom
        ? l10n.translate('challenge.type.custom_unit')
        : _typeDefaultUnit(_selectedType);

    setState(() => _isCreating = true);
    try {
      final challenge = await _service.createChallenge(
        title: title,
        description: _descCtrl.text.trim(),
        type: _selectedType,
        goal: goal,
        unit: unit,
        endDate: _endDate,
        isPublic: _isPublic,
      );
      if (mounted) Navigator.pop(context, challenge);
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        AppSnackBar.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final primary = context.read<ThemeProvider>().primaryColor;

    final typeOptions = ChallengeType.values
        .map((ct) => AppChipOption<ChallengeType>(
              value: ct,
              label: l10n.translate(_typeLabelKey(ct)),
              icon: _typeIcon(ct),
            ))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet.r)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: AppSize.sheetHandleW.w,
            height: AppSize.sheetHandleH.h,
            margin: EdgeInsets.only(top: AppSpacing.sm.h, bottom: AppSpacing.lg.h),
            decoration: BoxDecoration(
              color: palette.border,
              borderRadius: BorderRadius.circular(AppRadius.full.r),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('challenge.create.title'),
                    style: t.headlineS
                        .copyWith(color: palette.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: AppSpacing.xl.h),

                  // Name
                  AppTextField(
                    controller: _titleCtrl,
                    labelText: l10n.translate('challenge.create.name_label'),
                    hintText: l10n.translate('challenge.create.name_hint'),
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.next,
                  ),
                  SizedBox(height: AppSpacing.md.h),

                  // Description
                  AppTextField(
                    controller: _descCtrl,
                    labelText: l10n.translate('challenge.create.desc_label'),
                    hintText: l10n.translate('challenge.create.desc_hint'),
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  // Type picker
                  Text(
                    l10n.translate('challenge.create.type_label'),
                    style: t.labelL.copyWith(
                        color: palette.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: AppSpacing.sm.h),
                  AppChipPicker<ChallengeType>(
                    options: typeOptions,
                    selected: {_selectedType},
                    onToggle: (ct) => setState(() {
                      _selectedType = ct;
                      _goalCtrl.text = _typeDefaultGoal(ct);
                    }),
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  // Goal
                  AppTextField(
                    controller: _goalCtrl,
                    labelText: l10n.translate('challenge.create.goal_label'),
                    hintText: l10n.translate('challenge.create.goal_hint'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    textInputAction: TextInputAction.done,
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  // End date
                  Text(
                    l10n.translate('challenge.create.end_date_label'),
                    style: t.labelL.copyWith(
                        color: palette.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: AppSpacing.xs.h),
                  GestureDetector(
                    onTap: _pickEndDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl.w, vertical: AppSpacing.md.h),
                      decoration: BoxDecoration(
                        color: palette.surfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.input.r),
                        border: Border.all(color: palette.border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: AppSize.iconSm.r, color: primary),
                          SizedBox(width: AppSpacing.sm.w),
                          Text(
                            DateFormat('dd MMM yyyy').format(_endDate),
                            style: t.bodyL.copyWith(color: palette.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),

                  // Public toggle
                  AppToggle(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    label: l10n.translate('challenge.create.public_label'),
                    description: l10n.translate('challenge.create.public_subtitle'),
                  ),
                  SizedBox(height: AppSpacing.xxl.h),
                ],
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.xl.w, AppSpacing.xs.h,
                AppSpacing.xl.w, MediaQuery.of(context).padding.bottom + AppSpacing.md.h),
            child: AppButton(
              label: l10n.translate('challenge.create.btn'),
              loading: _isCreating,
              onPressed: _canCreate ? _create : null,
            ),
          ),
        ],
      ),
    );
  }
}
