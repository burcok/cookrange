import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/coach_application_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'coach_application_pending_screen.dart';

class CoachApplicationScreen extends StatefulWidget {
  const CoachApplicationScreen({super.key});

  @override
  State<CoachApplicationScreen> createState() =>
      _CoachApplicationScreenState();
}

class _CoachApplicationScreenState extends State<CoachApplicationScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _submitting = false;

  // Step 1 — Professional Info
  final _bioCtrl = TextEditingController();
  final Set<String> _selectedSpecs = {};
  int _experienceYears = 1;
  final _rateCtrl = TextEditingController();

  // Step 2 — Evidence
  final List<File> _evidenceFiles = [];
  final List<String> _evidenceLabels = [];

  // Step 3 — References
  final List<Map<String, TextEditingController>> _refCtrls = [];

  // Animation
  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: AppMotion.normal);
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: AppMotion.decelerate);

  static const _allSpecializations = [
    'Weight Loss', 'Muscle Gain', 'Strength', 'Endurance', 'Nutrition',
    'HIIT', 'Yoga', 'Rehabilitation', 'Sports Performance', 'Senior Fitness',
    'Boxing', 'CrossFit', 'Pilates', 'Running', 'Cycling',
  ];

  static const _evidenceLabelOptions = [
    'PT License', 'NASM/ACE', 'CPD Certificate', 'IFBB Card',
    'Reference Letter', 'Diploma / Degree', 'Experience Certificate', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();
    _addRefEntry();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bioCtrl.dispose();
    _rateCtrl.dispose();
    _fadeCtrl.dispose();
    for (final m in _refCtrls) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  void _addRefEntry() {
    _refCtrls.add({
      'name': TextEditingController(),
      'contact': TextEditingController(),
      'description': TextEditingController(),
    });
    setState(() {});
  }

  void _removeRefEntry(int i) {
    if (_refCtrls.length <= 1) return;
    final m = _refCtrls.removeAt(i);
    for (final c in m.values) {
      c.dispose();
    }
    setState(() {});
  }

  bool get _step1Valid =>
      _bioCtrl.text.trim().length >= 80 &&
      _selectedSpecs.length >= 3 &&
      _rateCtrl.text.trim().isNotEmpty;

  bool get _step2Valid => _evidenceFiles.length >= 2;

  bool get _step3Valid =>
      _refCtrls.every((m) =>
          m['name']!.text.trim().isNotEmpty &&
          m['contact']!.text.trim().isNotEmpty);

  Future<void> _pickEvidence() async {
    final granted = await PermissionService().requestPhotos(context);
    if (!mounted || !granted) return;
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

    // Pick label
    final label = await _pickEvidenceLabel();
    if (label == null || !mounted) return;

    setState(() {
      _evidenceFiles.add(File(file.path));
      _evidenceLabels.add(label);
    });
    unawaited(HapticFeedback.lightImpact());
  }

  Future<String?> _pickEvidenceLabel() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final palette = AppPalette.of(ctx);
        final t = AppText.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    AppLocalizations.of(ctx)
                        .translate('coach.app_evidence_label_title'),
                    style: t.headlineS
                        .copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                ..._evidenceLabelOptions.map((l) => ListTile(
                      title: Text(l, style: t.bodyM),
                      onTap: () => Navigator.of(ctx).pop(l),
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!_step3Valid) return;
    setState(() => _submitting = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('Not logged in');
      final refs = _refCtrls
          .map((m) => {
                'name': m['name']!.text.trim(),
                'contact': m['contact']!.text.trim(),
                'description': m['description']!.text.trim(),
              })
          .toList();
      await CoachApplicationService().submitApplication(
        applicantUid: user.uid,
        displayName: user.displayName ?? '',
        bio: _bioCtrl.text.trim(),
        specializations: _selectedSpecs.toList(),
        experienceYears: _experienceYears,
        hourlyRate: int.tryParse(_rateCtrl.text.trim()) ?? 0,
        evidenceFiles: _evidenceFiles,
        evidenceLabels: _evidenceLabels,
        references: refs,
      );
      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      await Navigator.of(context).pushReplacement(
          AppTransitions.slideUp(const CoachApplicationPendingScreen()));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context,
            AppLocalizations.of(context).translate('errors.general'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
        duration: AppMotion.normal, curve: AppMotion.standard);
    setState(() => _currentStep++);
  }

  void _prevPage() {
    _pageController.previousPage(
        duration: AppMotion.normal, curve: AppMotion.standard);
    setState(() => _currentStep--);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final l10n = AppLocalizations.of(context);
    final t = AppText.of(context);
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: palette.textPrimary, size: 20),
          onPressed: _currentStep > 0
              ? _prevPage
              : () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('coach.app_title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: List.generate(3, (i) {
                final done = i < _currentStep;
                final active = i == _currentStep;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 6 : 0),
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
          ),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(palette, l10n, t, primary),
                  _buildStep2(palette, l10n, t, primary),
                  _buildStep3(palette, l10n, t, primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Professional Info ────────────────────────────────────────────

  Widget _buildStep1(AppPalette palette, AppLocalizations l10n,
      AppText t, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('coach.app_step1_title'),
              style: t.headlineS.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(l10n.translate('coach.app_step1_sub'),
              style: t.bodyM.copyWith(color: palette.textSecondary)),
          const SizedBox(height: 24),

          // Bio
          Text(l10n.translate('coach.field_bio'),
              style: t.labelL.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AppTextField(
            controller: _bioCtrl,
            hintText: l10n.translate('coach.app_bio_hint'),
            maxLines: 5,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text(
            '${_bioCtrl.text.trim().length}/80 min',
            style: t.labelS.copyWith(
              color: _bioCtrl.text.trim().length >= 80
                  ? palette.success
                  : palette.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // Specializations
          Text(l10n.translate('coach.field_specializations'),
              style: t.labelL.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            l10n.translate('coach.app_spec_min'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allSpecializations.map((s) {
              final sel = _selectedSpecs.contains(s);
              return FilterChip(
                label: Text(s),
                selected: sel,
                onSelected: (v) {
                  setState(() {
                    if (v) {
                      _selectedSpecs.add(s);
                    } else {
                      _selectedSpecs.remove(s);
                    }
                  });
                },
                selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                checkmarkColor: Theme.of(context).primaryColor,
                labelStyle: t.labelM.copyWith(
                  color: sel
                      ? Theme.of(context).primaryColor
                      : palette.textPrimary,
                ),
                side: BorderSide(
                    color: sel
                        ? Theme.of(context).primaryColor
                        : palette.border),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Experience years
          Text(l10n.translate('coach.app_experience_years'),
              style: t.labelL.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                onPressed: _experienceYears > 1
                    ? () => setState(() => _experienceYears--)
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: Theme.of(context).primaryColor,
              ),
              Text('$_experienceYears', style: t.headlineS),
              IconButton(
                onPressed: _experienceYears < 50
                    ? () => setState(() => _experienceYears++)
                    : null,
                icon: const Icon(Icons.add_circle_outline),
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(l10n.translate('coach.app_years_label'),
                  style: t.bodyM.copyWith(color: palette.textSecondary)),
            ],
          ),
          const SizedBox(height: 20),

          // Hourly rate
          Text(l10n.translate('coach.app_hourly_rate'),
              style: t.labelL.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          AppTextField(
            controller: _rateCtrl,
            hintText: l10n.translate('coach.app_rate_hint'),
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.currency_lira),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: l10n.translate('common.next'),
              onPressed: _step1Valid ? _nextPage : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Evidence Documents ────────────────────────────────────────────

  Widget _buildStep2(AppPalette palette, AppLocalizations l10n,
      AppText t, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('coach.app_step2_title'),
              style: t.headlineS.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(l10n.translate('coach.app_step2_sub'),
              style: t.bodyM.copyWith(color: palette.textSecondary)),
          const SizedBox(height: 24),

          // Evidence list
          ..._evidenceFiles.asMap().entries.map((e) {
            final i = e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _evidenceFiles[i],
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _evidenceLabels[i],
                            style: t.labelL.copyWith(
                                fontWeight: FontWeight.w700),
                          ),
                          Text(
                            l10n.translate('coach.app_doc_uploaded'),
                            style: t.bodyM.copyWith(color: palette.success),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: palette.error, size: 20),
                      onPressed: () => setState(() {
                        _evidenceFiles.removeAt(i);
                        _evidenceLabels.removeAt(i);
                      }),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Add evidence button
          OutlinedButton.icon(
            onPressed: _pickEvidence,
            icon: const Icon(Icons.upload_file_rounded),
            label: Text(l10n.translate('coach.app_add_evidence')),
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: BorderSide(color: primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translate('coach.app_evidence_hint'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: l10n.translate('common.next'),
              onPressed: _step2Valid ? _nextPage : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: References ─────────────────────────────────────────────────────

  Widget _buildStep3(AppPalette palette, AppLocalizations l10n,
      AppText t, Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('coach.app_step3_title'),
              style: t.headlineS.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(l10n.translate('coach.app_step3_sub'),
              style: t.bodyM.copyWith(color: palette.textSecondary)),
          const SizedBox(height: 24),

          ..._refCtrls.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${l10n.translate('coach.app_ref_label')} ${i + 1}',
                          style: t.labelL.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        if (_refCtrls.length > 1)
                          IconButton(
                            icon: Icon(Icons.remove_circle_outline,
                                color: palette.error, size: 20),
                            onPressed: () => _removeRefEntry(i),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: m['name']!,
                      hintText: l10n.translate('coach.app_ref_name'),
                      prefixIcon: const Icon(Icons.person_outline),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: m['contact']!,
                      hintText: l10n.translate('coach.app_ref_contact'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: m['description']!,
                      hintText: l10n.translate('coach.app_ref_desc'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            );
          }),

          TextButton.icon(
            onPressed: _addRefEntry,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(l10n.translate('coach.app_add_ref')),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: _submitting
                  ? l10n.translate('common.loading')
                  : l10n.translate('coach.app_submit'),
              onPressed: (_step3Valid && !_submitting) ? _submit : null,
              loading: _submitting,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('coach.app_submit_note'),
            textAlign: TextAlign.center,
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}
