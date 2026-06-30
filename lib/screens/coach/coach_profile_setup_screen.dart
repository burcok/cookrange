import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/coach_profile_model.dart';
import '../../core/services/coach_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'coach_dashboard_screen.dart';

class CoachProfileSetupScreen extends StatefulWidget {
  final CoachProfileModel? existingProfile;
  const CoachProfileSetupScreen({super.key, this.existingProfile});

  @override
  State<CoachProfileSetupScreen> createState() =>
      _CoachProfileSetupScreenState();
}

class _CoachProfileSetupScreenState extends State<CoachProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  int _currentStep = 0;

  // Step 1
  final _bioController = TextEditingController();
  final _certController = TextEditingController();
  final Set<String> _selectedSpecializations = {};
  final List<String> _certifications = [];

  // Step 2
  bool _isAcceptingClients = true;
  bool _isPublic = true;
  final _vanityController = TextEditingController();
  final _rateController = TextEditingController();

  bool _isSaving = false;

  static const _allSpecializations = [
    'Weight Loss',
    'Muscle Gain',
    'Strength',
    'Endurance',
    'Nutrition',
    'HIIT',
    'Yoga',
    'Rehabilitation',
    'Sports Performance',
    'Senior Fitness',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    final p = widget.existingProfile;
    if (p != null) {
      _bioController.text = p.bio ?? '';
      _selectedSpecializations.addAll(p.specializations);
      _certifications.addAll(p.certifications);
      _isAcceptingClients = p.isAcceptingClients;
      _isPublic = p.isPublic;
      _vanityController.text = p.vanityCode ?? '';
      _rateController.text = p.hourlyRate?.toStringAsFixed(0) ?? '';
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    _bioController.dispose();
    _certController.dispose();
    _vanityController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 1) {
      setState(() => _currentStep = 1);
      _pageController.animateToPage(
        1,
        duration: AppMotion.normal,
        curve: AppMotion.emphasized,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep = 0);
      _pageController.animateToPage(
        0,
        duration: AppMotion.normal,
        curve: AppMotion.emphasized,
      );
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await CoachService().setupCoachProfile(
        bio: _bioController.text.trim(),
        specializations: _selectedSpecializations.toList(),
        certifications: List.from(_certifications),
        isAcceptingClients: _isAcceptingClients,
        vanityCode: _vanityController.text.trim().toUpperCase(),
        hourlyRate: double.tryParse(_rateController.text.trim()),
        isPublic: _isPublic,
      );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.success(context, l10n.translate('coach.setup_saved'));

      if (widget.existingProfile != null) {
        Navigator.of(context).pop();
      } else {
        unawaited(Navigator.of(context).pushReplacement(
          AppTransitions.slideRight(const CoachDashboardScreen()),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      AppSnackBar.error(context, l10n.translate('coach.setup_error'));
      debugPrint('CoachProfileSetupScreen._save error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addCertification() {
    final text = _certController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _certifications.add(text);
      _certController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final isEdit = widget.existingProfile != null;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        title: Text(
          l10n.translate(isEdit ? 'coach.edit_title' : 'coach.setup_title'),
          style: AppText.of(context).headlineS.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.bold,
              ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed:
              _currentStep > 0 ? _prevStep : () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _StepIndicator(currentStep: _currentStep, totalSteps: 2),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(context, palette, l10n),
                  _buildStep2(context, palette, l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1(
      BuildContext context, AppPalette palette, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('coach.step1_title'),
            style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('coach.step1_subtitle'),
            style: AppText.of(context)
                .bodyM
                .copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _bioController,
            labelText: l10n.translate('coach.field_bio'),
            hintText: l10n.translate('coach.field_bio_hint'),
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          Text(
            l10n.translate('coach.field_specializations'),
            style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allSpecializations.map((spec) {
              final selected = _selectedSpecializations.contains(spec);
              final primary = Theme.of(context).primaryColor;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (selected) {
                      _selectedSpecializations.remove(spec);
                    } else {
                      _selectedSpecializations.add(spec);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? primary.withValues(alpha: 0.15)
                        : palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: selected
                          ? primary.withValues(alpha: 0.6)
                          : palette.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    spec,
                    style: AppText.of(context).labelS.copyWith(
                          color: selected ? primary : palette.textSecondary,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.translate('coach.field_certifications'),
            style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _certController,
                  hintText: l10n.translate('coach.field_cert_hint'),
                  prefixIcon: const Icon(Icons.verified_rounded),
                  onSubmitted: (_) => _addCertification(),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AppButton(
                  label: l10n.translate('coach.field_cert_add'),
                  onPressed: _addCertification,
                  size: AppButtonSize.small,
                  expand: false,
                ),
              ),
            ],
          ),
          if (_certifications.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _certifications
                  .map((cert) => _CertChip(
                        label: cert,
                        onRemove: () =>
                            setState(() => _certifications.remove(cert)),
                        palette: palette,
                        context: context,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 32),
          AppButton(
            label: 'Continue',
            onPressed: _nextStep,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStep2(
      BuildContext context, AppPalette palette, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('coach.step2_title'),
            style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('coach.step2_subtitle'),
            style: AppText.of(context)
                .bodyM
                .copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 24),
          _ToggleTile(
            title: l10n.translate('coach.field_accepting'),
            value: _isAcceptingClients,
            palette: palette,
            context: context,
            onChanged: (v) => setState(() => _isAcceptingClients = v),
          ),
          const SizedBox(height: 16),
          _ToggleTile(
            title: l10n.translate('coach.field_public'),
            value: _isPublic,
            palette: palette,
            context: context,
            onChanged: (v) => setState(() => _isPublic = v),
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _vanityController,
            labelText: l10n.translate('coach.field_vanity_code'),
            hintText: l10n.translate('coach.field_vanity_hint'),
            prefixIcon: const Icon(Icons.tag_rounded),
            maxLength: 12,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _rateController,
            labelText: l10n.translate('coach.field_hourly_rate'),
            hintText: '0',
            prefixIcon: const Icon(Icons.attach_money_rounded),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 32),
          AppButton(
            label: l10n.translate('coach.setup_save'),
            onPressed: _isSaving ? null : _save,
          ),
          if (_isSaving) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final active = i == currentStep;
          final done = i < currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < totalSteps - 1 ? 8 : 0),
              child: AnimatedContainer(
                duration: AppMotion.normal,
                height: 4,
                decoration: BoxDecoration(
                  color: done || active ? primary : palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _CertChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final AppPalette palette;
  final BuildContext context;
  const _CertChip(
      {required this.label,
      required this.onRemove,
      required this.palette,
      required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: palette.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style:
                  AppText.of(ctx).labelS.copyWith(color: palette.textPrimary)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 16, color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppPalette palette;
  final BuildContext context;
  const _ToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
    required this.palette,
    required this.context,
  });

  @override
  Widget build(BuildContext ctx) {
    final primary = Theme.of(ctx).primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: AppText.of(ctx).bodyM.copyWith(
                    color: palette.textPrimary, fontWeight: FontWeight.w500)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: primary,
            activeTrackColor: primary.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}
