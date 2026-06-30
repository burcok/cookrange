import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/coach_application_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/storage_upload_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'coach_application_pending_screen.dart';

class CoachApplicationScreen extends StatefulWidget {
  const CoachApplicationScreen({super.key});

  @override
  State<CoachApplicationScreen> createState() => _CoachApplicationScreenState();
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

  // Step 3 — Phone Verification
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String? _verificationId;
  bool _phoneVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;

  // Step 4 — Documents
  File? _certDocFile;
  File? _idDocFile;

  // Step 5 — References
  final List<Map<String, TextEditingController>> _refCtrls = [];

  // Animation
  late final AnimationController _fadeCtrl =
      AnimationController(vsync: this, duration: AppMotion.normal);
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: AppMotion.decelerate);

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
    'Boxing',
    'CrossFit',
    'Pilates',
    'Running',
    'Cycling',
  ];

  static const _evidenceLabelOptions = [
    'PT License',
    'NASM/ACE',
    'CPD Certificate',
    'IFBB Card',
    'Reference Letter',
    'Diploma / Degree',
    'Experience Certificate',
    'Other',
  ];

  static const _totalSteps = 5;

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
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
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

  // ── Validation ─────────────────────────────────────────────────────────────

  bool get _step1Valid =>
      _bioCtrl.text.trim().length >= 80 &&
      _selectedSpecs.length >= 3 &&
      _rateCtrl.text.trim().isNotEmpty;

  bool get _step2Valid => _evidenceFiles.length >= 2;

  bool get _step3Valid => _phoneVerified;

  bool get _step4Valid => _certDocFile != null && _idDocFile != null;

  bool get _step5Valid => _refCtrls.every((m) =>
      m['name']!.text.trim().isNotEmpty &&
      m['contact']!.text.trim().isNotEmpty);

  // ── Phone OTP ──────────────────────────────────────────────────────────────

  Future<void> _sendOtp() async {
    if (_sendingOtp) return;
    final phone = '+90${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';
    setState(() => _sendingOtp = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted)
            setState(() {
              _phoneVerified = true;
              _sendingOtp = false;
            });
        },
        verificationFailed: (e) {
          if (mounted) {
            setState(() => _sendingOtp = false);
            AppSnackBar.error(
              context,
              e.message ??
                  AppLocalizations.of(context).translate('gym.phone_error'),
            );
          }
        },
        codeSent: (verificationId, resendToken) {
          if (mounted)
            setState(() {
              _verificationId = verificationId;
              _sendingOtp = false;
            });
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('CoachApplicationScreen: OTP send error: $e');
      if (mounted) {
        setState(() => _sendingOtp = false);
        AppSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null || _otpCtrl.text.length < 6) return;
    setState(() => _verifyingOtp = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCtrl.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      if (mounted)
        setState(() {
          _phoneVerified = true;
          _verifyingOtp = false;
        });
    } catch (e) {
      debugPrint('CoachApplicationScreen: OTP verify error: $e');
      if (mounted) {
        setState(() => _verifyingOtp = false);
        AppSnackBar.error(
          context,
          AppLocalizations.of(context).translate('gym.otp_invalid'),
        );
      }
    }
  }

  // ── Document Picker ────────────────────────────────────────────────────────

  Future<void> _pickDoc(ValueChanged<File?> onPicked) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null && result.files.single.path != null) {
        unawaited(HapticFeedback.selectionClick());
        onPicked(File(result.files.single.path!));
      }
    } catch (e) {
      debugPrint('CoachApplicationScreen: file pick error: $e');
    }
  }

  // ── Evidence Picker ────────────────────────────────────────────────────────

  Future<void> _pickEvidence() async {
    final granted = await PermissionService().requestPhotos(context);
    if (!mounted || !granted) return;
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null || !mounted) return;

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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                    style: t.headlineS.copyWith(fontWeight: FontWeight.w800),
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

  // ── Submit ─────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_step5Valid) return;
    setState(() => _submitting = true);
    try {
      final user = context.read<UserProvider>().user;
      if (user == null) throw Exception('Not logged in');

      // Upload cert and id documents
      String? certDocUrl;
      String? idDocUrl;

      if (_certDocFile != null) {
        certDocUrl = await StorageUploadService().uploadCoachDocument(
          uid: user.uid,
          fileName: 'cert_document',
          file: _certDocFile!,
        );
      }
      if (_idDocFile != null) {
        idDocUrl = await StorageUploadService().uploadCoachDocument(
          uid: user.uid,
          fileName: 'id_document',
          file: _idDocFile!,
        );
      }

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
        contactPhone: '+90${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}',
        certDocUrl: certDocUrl,
        idDocUrl: idDocUrl,
      );

      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      await Navigator.of(context).pushReplacement(
          AppTransitions.slideUp(const CoachApplicationPendingScreen()));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, AppLocalizations.of(context).translate('errors.general'));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  void _nextPage() {
    final l10n = AppLocalizations.of(context);
    switch (_currentStep) {
      case 2: // Phone step
        if (!_phoneVerified) {
          AppSnackBar.warning(
            context,
            l10n.translate('coach.step_phone_subtitle'),
          );
          return;
        }
      case 3: // Docs step
        if (_certDocFile == null || _idDocFile == null) {
          AppSnackBar.warning(
            context,
            l10n.translate('coach.docs_required_warning'),
          );
          return;
        }
      default:
        break;
    }
    _pageController.nextPage(
        duration: AppMotion.normal, curve: AppMotion.standard);
    setState(() => _currentStep++);
  }

  void _prevPage() {
    _pageController.previousPage(
        duration: AppMotion.normal, curve: AppMotion.standard);
    setState(() => _currentStep--);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          onPressed:
              _currentStep > 0 ? _prevPage : () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.translate('coach.app_title'),
          style: t.titleM.copyWith(
              color: palette.textPrimary, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Text(
              '${_currentStep + 1}/$_totalSteps',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: List.generate(_totalSteps, (i) {
                final done = i < _currentStep;
                final active = i == _currentStep;
                return Expanded(
                  child: Padding(
                    padding:
                        EdgeInsets.only(right: i < _totalSteps - 1 ? 6 : 0),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      curve: AppMotion.emphasized,
                      height: 4,
                      decoration: BoxDecoration(
                        color: done
                            ? primary
                            : active
                                ? primary.withValues(alpha: 0.5)
                                : palette.border,
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
                  _buildStep3Phone(palette, l10n, t, primary),
                  _buildStep4Docs(palette, l10n, t, primary),
                  _buildStep5(palette, l10n, t, primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Professional Info ────────────────────────────────────────────

  Widget _buildStep1(
      AppPalette palette, AppLocalizations l10n, AppText t, Color primary) {
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
                selectedColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.15),
                checkmarkColor: Theme.of(context).primaryColor,
                labelStyle: t.labelM.copyWith(
                  color: sel
                      ? Theme.of(context).primaryColor
                      : palette.textPrimary,
                ),
                side: BorderSide(
                    color:
                        sel ? Theme.of(context).primaryColor : palette.border),
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

  Widget _buildStep2(
      AppPalette palette, AppLocalizations l10n, AppText t, Color primary) {
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
                            style:
                                t.labelL.copyWith(fontWeight: FontWeight.w700),
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

  // ── Step 3: Phone Verification ────────────────────────────────────────────

  Widget _buildStep3Phone(
      AppPalette palette, AppLocalizations l10n, AppText t, Color primary) {
    final otpSent = _verificationId != null && !_phoneVerified;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('coach.step_phone_title'),
            style: t.headlineS.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('coach.step_phone_subtitle'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 24),

          // Info card
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.translate('coach.phone_info'),
                    style: t.labelS.copyWith(color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (_phoneVerified) ...[
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: palette.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check_circle_rounded,
                        color: palette.success, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      l10n.translate('gym.phone_verified'),
                      style: t.bodyM.copyWith(
                        color: palette.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            AppTextField(
              controller: _phoneCtrl,
              labelText: l10n.translate('gym.phone_label'),
              hintText: l10n.translate('gym.phone_hint'),
              prefixIcon: const Icon(Icons.phone_rounded),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              enabled: _verificationId == null,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: otpSent
                  ? l10n.translate('gym.phone_resend')
                  : l10n.translate('gym.phone_send_otp'),
              onPressed: _sendOtp,
              loading: _sendingOtp,
              icon: Icons.send_rounded,
            ),
            if (otpSent) ...[
              const SizedBox(height: 24),
              AppTextField(
                controller: _otpCtrl,
                labelText: l10n.translate('gym.phone_otp_label'),
                hintText: l10n.translate('gym.phone_otp_hint'),
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: l10n.translate('gym.phone_verify'),
                onPressed: _verifyOtp,
                loading: _verifyingOtp,
                icon: Icons.verified_rounded,
              ),
            ],
          ],
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: l10n.translate('common.next'),
              onPressed: _step3Valid ? _nextPage : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 4: Certifications & ID ───────────────────────────────────────────

  Widget _buildStep4Docs(
      AppPalette palette, AppLocalizations l10n, AppText t, Color primary) {
    final uploadedCount =
        (_certDocFile != null ? 1 : 0) + (_idDocFile != null ? 1 : 0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('coach.step_docs_title'),
            style: t.headlineS.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.translate('coach.step_docs_subtitle'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
          const SizedBox(height: 24),

          // Info card
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.translate('coach.docs_info'),
                    style: t.labelS.copyWith(color: palette.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Document counter badge
          AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: uploadedCount == 2
                  ? palette.success.withValues(alpha: 0.12)
                  : palette.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: uploadedCount == 2 ? palette.success : palette.border,
              ),
            ),
            child: Text(
              l10n
                  .translate('coach.docs_count')
                  .replaceAll('{n}', '$uploadedCount'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: uploadedCount == 2
                    ? palette.success
                    : palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Coach certificate
          _DocUploadCard(
            label: l10n.translate('coach.docs_cert'),
            tapLabel: l10n.translate('coach.docs_tap_upload'),
            uploadedLabel: l10n.translate('coach.docs_uploaded'),
            file: _certDocFile,
            isRequired: true,
            onTap: () => _pickDoc((f) => setState(() => _certDocFile = f)),
            palette: palette,
            primary: primary,
          ),
          const SizedBox(height: 14),

          // ID document
          _DocUploadCard(
            label: l10n.translate('coach.docs_id'),
            tapLabel: l10n.translate('coach.docs_tap_upload'),
            uploadedLabel: l10n.translate('coach.docs_uploaded'),
            file: _idDocFile,
            isRequired: true,
            onTap: () => _pickDoc((f) => setState(() => _idDocFile = f)),
            palette: palette,
            primary: primary,
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: AppButton(
              label: l10n.translate('common.next'),
              onPressed: _step4Valid ? _nextPage : null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 5: References ─────────────────────────────────────────────────────

  Widget _buildStep5(
      AppPalette palette, AppLocalizations l10n, AppText t, Color primary) {
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
              onPressed: (_step5Valid && !_submitting) ? _submit : null,
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

// ── Doc Upload Card ───────────────────────────────────────────────────────────

class _DocUploadCard extends StatelessWidget {
  final String label;
  final String tapLabel;
  final String uploadedLabel;
  final File? file;
  final bool isRequired;
  final VoidCallback onTap;
  final AppPalette palette;
  final Color primary;

  const _DocUploadCard({
    required this.label,
    required this.tapLabel,
    required this.uploadedLabel,
    required this.file,
    required this.isRequired,
    required this.onTap,
    required this.palette,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final isPicked = file != null;
    final fileName = file?.path.split('/').last;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPicked
              ? palette.success.withValues(alpha: 0.06)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isPicked ? palette.success : palette.border,
            width: isPicked ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPicked
                    ? palette.success.withValues(alpha: 0.12)
                    : palette.border.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                isPicked
                    ? Icons.check_circle_rounded
                    : Icons.upload_file_rounded,
                color: isPicked ? palette.success : palette.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: AppText.of(context).bodyM.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 4),
                        Text(
                          '*',
                          style: TextStyle(
                            color: palette.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPicked ? (fileName ?? uploadedLabel) : tapLabel,
                    style: AppText.of(context).labelS.copyWith(
                          color:
                              isPicked ? palette.success : palette.textTertiary,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isPicked ? Icons.edit_rounded : Icons.chevron_right_rounded,
              color: palette.textTertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
