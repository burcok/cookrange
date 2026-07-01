import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_model.dart';
import '../../core/services/gym_application_service.dart';
import '../../core/services/gym_service.dart';
import '../../core/services/storage_upload_service.dart';
import '../../core/widgets/ds/ds.dart';
import 'gym_application_pending_screen.dart';

/// Gym profile create / edit screen — 5-step form.
/// Pass [existingGym] to enter edit mode.
class GymSetupScreen extends StatefulWidget {
  final GymModel? existingGym;

  const GymSetupScreen({super.key, this.existingGym});

  @override
  State<GymSetupScreen> createState() => _GymSetupScreenState();
}

class _GymSetupScreenState extends State<GymSetupScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _saving = false;

  // ── Step 1: Basic info ──────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isPublic = true;
  final List<String> _selectedTags = [];
  Color _selectedBrandColor = const Color(0xFFF97300);
  File? _logoFile;
  bool _uploadingLogo = false;

  // ── Step 2: Location ────────────────────────────────────────────────────────
  String? _selectedCity;
  double? _selectedLat;
  double? _selectedLng;
  String? _resolvedAddress;
  bool _geocodingInProgress = false;
  Timer? _geocodeDebounce;

  // ── Step 3: Phone verification ──────────────────────────────────────────────
  final _phoneCtrl = TextEditingController();
  String? _verificationId;
  final _otpCtrl = TextEditingController();
  bool _phoneVerified = false;
  bool _sendingOtp = false;
  bool _verifyingOtp = false;

  // ── Step 4: Documents ───────────────────────────────────────────────────────
  File? _businessLicenseFile;
  File? _idDocFile;
  File? _taxDocFile;

  static const _gymTags = [
    'CrossFit',
    'Yoga',
    'Boxing',
    'Pilates',
    'Powerlifting',
    'Bodybuilding',
    'Cardio',
    'HIIT',
    'Martial Arts',
    'Swimming',
  ];

  bool get _isEditMode => widget.existingGym != null;
  // Edit mode skips phone + document steps: Basic Info → Location → Settings
  int get _totalSteps => _isEditMode ? 3 : 5;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final g = widget.existingGym!;
      _nameCtrl.text = g.name;
      _descCtrl.text = g.description ?? '';
      _selectedCity = g.city;
      _selectedLat = g.latitude;
      _selectedLng = g.longitude;
      _resolvedAddress = g.address;
      _isPublic = g.isPublic;
      _selectedTags.addAll(g.tags);
      if (g.brandColor != null) {
        final parsed = int.tryParse(g.brandColor!);
        if (parsed != null) _selectedBrandColor = Color(parsed);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _geocodeDebounce?.cancel();
    super.dispose();
  }

  void _nextStep() {
    final l10n = AppLocalizations.of(context);

    switch (_currentStep) {
      case 0: // Basic info — both modes
        if (_nameCtrl.text.trim().isEmpty) {
          AppSnackBar.warning(
              context, l10n.translate('gym.setup_name_required'));
          return;
        }
      case 1: // Location — both modes
        if (_selectedCity == null) {
          AppSnackBar.warning(
              context, l10n.translate('gym.location_city_required'));
          return;
        }
        // New gyms must pin a location; edit mode already has coords from existing gym
        if (!_isEditMode && _selectedLat == null) {
          AppSnackBar.warning(
              context, l10n.translate('gym.location_pin_required'));
          return;
        }
      case 2:
        if (_isEditMode) {
          // Edit mode: step 2 = Settings → save directly
          _save();
          return;
        }
        // Create mode: step 2 = Phone verification
        if (!_phoneVerified) {
          AppSnackBar.warning(
              context, l10n.translate('gym.step_phone_subtitle'));
          return;
        }
      case 3: // Documents — create mode only
        if (_businessLicenseFile == null || _idDocFile == null) {
          AppSnackBar.warning(
              context, l10n.translate('gym.docs_required_warning'));
          return;
        }
      case 4: // Settings — create mode only → save
        _save();
        return;
    }

    setState(() => _currentStep++);
    _pageController.animateToPage(
      _currentStep,
      duration: AppMotion.normal,
      curve: AppMotion.emphasized,
    );
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: AppMotion.normal,
        curve: AppMotion.emphasized,
      );
    }
  }

  void _onLocationPinned(double lat, double lng) {
    setState(() {
      _selectedLat = lat;
      _selectedLng = lng;
      _resolvedAddress = null;
      _geocodingInProgress = true;
    });
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 500), () async {
      final address = await _reverseGeocode(lat, lng);
      if (mounted) {
        setState(() {
          _resolvedAddress = address;
          _geocodingInProgress = false;
        });
      }
    });
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&accept-language=tr',
      );
      final response =
          await http.get(url, headers: {'User-Agent': 'CookrangeApp/1.0'});
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['display_name'] as String?;
      }
    } catch (e) {
      debugPrint('GymSetupScreen: Reverse geocode error: $e');
    }
    return null;
  }

  Future<void> _sendOtp() async {
    if (_sendingOtp) return;
    final phone = '+90${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}';
    setState(() => _sendingOtp = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          if (mounted) {
            setState(() {
              _phoneVerified = true;
              _sendingOtp = false;
            });
          }
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
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _sendingOtp = false;
            });
          }
        },
        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      debugPrint('GymSetupScreen: OTP send error: $e');
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
      if (mounted) {
        setState(() {
          _phoneVerified = true;
          _verifyingOtp = false;
        });
      }
    } catch (e) {
      debugPrint('GymSetupScreen: OTP verify error: $e');
      if (mounted) {
        setState(() => _verifyingOtp = false);
        AppSnackBar.error(
          context,
          AppLocalizations.of(context).translate('gym.otp_invalid'),
        );
      }
    }
  }

  String get _brandColorHex {
    final v = _selectedBrandColor.toARGB32();
    return '0x${v.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  Future<void> _uploadLogoAndUpdate(String gymId) async {
    if (_logoFile == null) return;
    setState(() => _uploadingLogo = true);
    try {
      final url = await StorageUploadService().uploadGymLogo(
        gymId: gymId,
        imageFile: _logoFile!,
      );
      await GymService().updateGym(gymId, {'logo_url': url});
      debugPrint('[GymSetupScreen] Logo uploaded to $url');
    } catch (e) {
      debugPrint('[GymSetupScreen] Logo upload error: $e');
      if (mounted) {
        AppSnackBar.error(
          context,
          AppLocalizations.of(context).translate('gym.brand_logo_error'),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final l10n = AppLocalizations.of(context);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (_isEditMode) {
        await GymService().updateGym(widget.existingGym!.id, {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'address': _resolvedAddress ?? '',
          'city': _selectedCity ?? '',
          'country': 'Türkiye',
          'is_public': _isPublic,
          'tags': _selectedTags,
          'brand_color': _brandColorHex,
          if (_selectedLat != null) 'latitude': _selectedLat,
          if (_selectedLng != null) 'longitude': _selectedLng,
        });
        if (_logoFile != null) {
          await _uploadLogoAndUpdate(widget.existingGym!.id);
        }
        if (!mounted) return;
        AppSnackBar.success(context, l10n.translate('gym.setup_updated'));
        Navigator.of(context).pop(true);
      } else {
        // Upload documents, then submit application for admin review
        String? businessDocUrl;
        String? idDocUrl;

        if (_businessLicenseFile != null) {
          businessDocUrl = await StorageUploadService().uploadGymDocument(
            uid: uid,
            fileName: 'business_license',
            file: _businessLicenseFile!,
          );
        }
        if (_idDocFile != null) {
          idDocUrl = await StorageUploadService().uploadGymDocument(
            uid: uid,
            fileName: 'id_document',
            file: _idDocFile!,
          );
        }

        await GymApplicationService().submitApplication(
          applicantUid: uid,
          gymName: _nameCtrl.text.trim(),
          address: _resolvedAddress ?? '',
          city: _selectedCity ?? '',
          description: _descCtrl.text.trim(),
          contactPhone: '+90${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}',
          tags: _selectedTags,
          businessDocUrl: businessDocUrl,
          idDocUrl: idDocUrl,
          latitude: _selectedLat,
          longitude: _selectedLng,
          brandColor: _brandColorHex,
        );

        if (!mounted) return;
        unawaited(
          Navigator.of(context).pushReplacement(
            AppTransitions.slideRight(
              const GymApplicationPendingScreen(showBackButton: false),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('[GymSetupScreen] Save error: $e');
      if (!mounted) return;
      AppSnackBar.error(context, l10n.translate('gym.setup_error'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _currentStep > 0
                ? Icons.arrow_back_ios_rounded
                : Icons.close_rounded,
            color: palette.textPrimary,
            size: 20,
          ),
          onPressed:
              _currentStep > 0 ? _prevStep : () => Navigator.pop(context),
        ),
        title: Text(
          _isEditMode
              ? l10n.translate('gym.edit_title')
              : l10n.translate('gym.setup_screen_title'),
          style: AppText.of(context).titleM.copyWith(
                color: palette.textPrimary,
                fontWeight: FontWeight.w700,
              ),
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
          _StepIndicator(
            currentStep: _currentStep,
            totalSteps: _totalSteps,
            primary: primary,
            palette: palette,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                // Step 1: Basic info (both modes)
                _Step1BasicInfo(
                  nameCtrl: _nameCtrl,
                  descCtrl: _descCtrl,
                  palette: palette,
                  isDark: isDark,
                  l10n: l10n,
                  selectedBrandColor: _selectedBrandColor,
                  onColorChanged: (c) =>
                      setState(() => _selectedBrandColor = c),
                  logoFile: _logoFile,
                  uploadingLogo: _uploadingLogo,
                  existingLogoUrl: widget.existingGym?.logoUrl,
                  onLogoChanged: (f) => setState(() => _logoFile = f),
                ),
                // Step 2: Location (both modes)
                _Step2Location(
                  selectedCity: _selectedCity,
                  selectedLat: _selectedLat,
                  selectedLng: _selectedLng,
                  resolvedAddress: _resolvedAddress,
                  geocodingInProgress: _geocodingInProgress,
                  onCityChanged: (city, lat, lng) {
                    setState(() {
                      _selectedCity = city;
                      _selectedLat = lat;
                      _selectedLng = lng;
                      _resolvedAddress = null;
                    });
                  },
                  onLocationPinned: _onLocationPinned,
                  palette: palette,
                  isDark: isDark,
                  primary: primary,
                  l10n: l10n,
                ),
                // Edit mode: Step 3 = Settings; Create mode: Step 3 = Phone verification
                if (_isEditMode)
                  _Step5Settings(
                    isPublic: _isPublic,
                    selectedTags: _selectedTags,
                    allTags: _gymTags,
                    palette: palette,
                    isDark: isDark,
                    primary: primary,
                    l10n: l10n,
                    onPublicChanged: (v) => setState(() => _isPublic = v),
                    onTagToggled: (tag) {
                      setState(() {
                        if (_selectedTags.contains(tag)) {
                          _selectedTags.remove(tag);
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
                    },
                  )
                else ...[
                  // Step 3: Phone verification (create only)
                  _Step3Phone(
                    phoneCtrl: _phoneCtrl,
                    phoneVerified: _phoneVerified,
                    sendingOtp: _sendingOtp,
                    verifyingOtp: _verifyingOtp,
                    otpCtrl: _otpCtrl,
                    verificationId: _verificationId,
                    onSendOtp: _sendOtp,
                    onVerifyOtp: _verifyOtp,
                    palette: palette,
                    isDark: isDark,
                    primary: primary,
                    l10n: l10n,
                  ),
                  // Step 4: Documents (create only)
                  _Step4Documents(
                    businessLicenseFile: _businessLicenseFile,
                    idDocFile: _idDocFile,
                    taxDocFile: _taxDocFile,
                    onBusinessLicensePicked: (f) =>
                        setState(() => _businessLicenseFile = f),
                    onIdDocPicked: (f) => setState(() => _idDocFile = f),
                    onTaxDocPicked: (f) => setState(() => _taxDocFile = f),
                    palette: palette,
                    isDark: isDark,
                    primary: primary,
                    l10n: l10n,
                  ),
                  // Step 5: Settings (create only)
                  _Step5Settings(
                    isPublic: _isPublic,
                    selectedTags: _selectedTags,
                    allTags: _gymTags,
                    palette: palette,
                    isDark: isDark,
                    primary: primary,
                    l10n: l10n,
                    onPublicChanged: (v) => setState(() => _isPublic = v),
                    onTagToggled: (tag) {
                      setState(() {
                        if (_selectedTags.contains(tag)) {
                          _selectedTags.remove(tag);
                        } else {
                          _selectedTags.add(tag);
                        }
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          _buildBottomBar(context, palette, primary, isDark, l10n),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    AppPalette palette,
    Color primary,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final isLast = _currentStep == _totalSteps - 1;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          top: BorderSide(
            color: palette.border.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: AppButton(
        label: isLast
            ? (_isEditMode
                ? l10n.translate('gym.setup_save')
                : l10n.translate('gym.setup_submit_application'))
            : l10n.translate('gym.setup_next'),
        onPressed: _nextStep,
        loading: _saving,
        icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final Color primary;
  final AppPalette palette;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.primary,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isActive = i == currentStep;
          final isDone = i < currentStep;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.emphasized,
                height: 4,
                decoration: BoxDecoration(
                  color: isDone
                      ? primary
                      : isActive
                          ? primary.withValues(alpha: 0.5)
                          : palette.border,
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

// ── Step 1: Basic info ────────────────────────────────────────────────────────

class _Step1BasicInfo extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final AppPalette palette;
  final bool isDark;
  final AppLocalizations l10n;
  final Color selectedBrandColor;
  final ValueChanged<Color> onColorChanged;
  final File? logoFile;
  final bool uploadingLogo;
  final String? existingLogoUrl;
  final ValueChanged<File?> onLogoChanged;

  const _Step1BasicInfo({
    required this.nameCtrl,
    required this.descCtrl,
    required this.palette,
    required this.isDark,
    required this.l10n,
    required this.selectedBrandColor,
    required this.onColorChanged,
    required this.logoFile,
    required this.uploadingLogo,
    required this.existingLogoUrl,
    required this.onLogoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('gym.step1_title'),
            style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('gym.step1_subtitle'),
            style: AppText.of(context).bodyM.copyWith(
                  color: palette.textSecondary,
                ),
          ),
          const SizedBox(height: 28),
          AppTextField(
            controller: nameCtrl,
            labelText: l10n.translate('gym.field_name'),
            hintText: l10n.translate('gym.field_name_hint'),
            prefixIcon: const Icon(Icons.business_rounded),
            maxLength: 60,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: descCtrl,
            labelText: l10n.translate('gym.field_description'),
            hintText: l10n.translate('gym.field_description_hint'),
            prefixIcon: const Icon(Icons.description_rounded),
            maxLines: 4,
            maxLength: 300,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 28),
          _ColorPickerSection(
            palette: palette,
            selectedColor: selectedBrandColor,
            onColorChanged: onColorChanged,
            l10n: l10n,
          ),
          const SizedBox(height: 24),
          _LogoPickerSection(
            palette: palette,
            logoFile: logoFile,
            uploadingLogo: uploadingLogo,
            existingLogoUrl: existingLogoUrl,
            onLogoChanged: onLogoChanged,
            l10n: l10n,
          ),
        ],
      ),
    );
  }
}

// ── Color Picker Section ──────────────────────────────────────────────────────

class _ColorPickerSection extends StatelessWidget {
  final AppPalette palette;
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;
  final AppLocalizations l10n;

  static const _presetColors = [
    Color(0xFFF97300),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFF8B5CF6),
    Color(0xFF6366F1),
    Color(0xFF3B82F6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFF84CC16),
    Color(0xFFF59E0B),
    Color(0xFF78716C),
    Color(0xFF1F2937),
  ];

  const _ColorPickerSection({
    required this.palette,
    required this.selectedColor,
    required this.onColorChanged,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final hexStr =
        '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.translate('gym.brand_color').toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selectedColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                hexStr,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selectedColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _presetColors.map((color) {
            final isSelected = selectedColor.toARGB32() == color.toARGB32();
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onColorChanged(color);
              },
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.emphasized,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Logo Picker Section ───────────────────────────────────────────────────────

class _LogoPickerSection extends StatelessWidget {
  final AppPalette palette;
  final File? logoFile;
  final bool uploadingLogo;
  final String? existingLogoUrl;
  final ValueChanged<File?> onLogoChanged;
  final AppLocalizations l10n;

  const _LogoPickerSection({
    required this.palette,
    required this.logoFile,
    required this.uploadingLogo,
    required this.existingLogoUrl,
    required this.onLogoChanged,
    required this.l10n,
  });

  Future<void> _pickImage(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 75,
      );
      if (picked != null) {
        onLogoChanged(File(picked.path));
      }
    } catch (e) {
      debugPrint('_LogoPickerSection: image pick error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = logoFile != null || existingLogoUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.translate('gym.brand_logo').toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: palette.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              l10n.translate('gym.brand_logo_optional'),
              style: TextStyle(
                fontSize: 10,
                color: palette.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: uploadingLogo ? null : () => _pickImage(context),
          child: AnimatedContainer(
            duration: AppMotion.fast,
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: palette.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: hasImage
                    ? palette.border
                    : palette.border.withValues(alpha: 0.5),
                width: hasImage ? 1.5 : 1,
              ),
            ),
            child: uploadingLogo
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.textSecondary,
                    ),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md - 1),
                    child: logoFile != null
                        ? Image.file(logoFile!, fit: BoxFit.cover)
                        : existingLogoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: existingLogoUrl!,
                                fit: BoxFit.cover,
                                placeholder: (c, _) => const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (c, _, __) => Center(
                                  child: Icon(
                                    Icons.add_a_photo_rounded,
                                    color: palette.textTertiary,
                                    size: 28,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.add_a_photo_rounded,
                                  color: palette.textTertiary,
                                  size: 28,
                                ),
                              ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.translate('gym.brand_logo_tap'),
          style: AppText.of(context).labelS.copyWith(
                color: palette.textSecondary,
              ),
        ),
      ],
    );
  }
}

// ── Step 2: Location ──────────────────────────────────────────────────────────

class _Step2Location extends StatefulWidget {
  final String? selectedCity;
  final double? selectedLat;
  final double? selectedLng;
  final String? resolvedAddress;
  final bool geocodingInProgress;
  final void Function(String city, double lat, double lng) onCityChanged;
  final void Function(double lat, double lng) onLocationPinned;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final AppLocalizations l10n;

  const _Step2Location({
    required this.selectedCity,
    required this.selectedLat,
    required this.selectedLng,
    required this.resolvedAddress,
    required this.geocodingInProgress,
    required this.onCityChanged,
    required this.onLocationPinned,
    required this.palette,
    required this.isDark,
    required this.primary,
    required this.l10n,
  });

  @override
  State<_Step2Location> createState() => _Step2LocationState();
}

class _Step2LocationState extends State<_Step2Location> {
  final MapController _mapController = MapController();

  // (name, lat, lng)
  static const _turkishCities = [
    ('Adana', 37.0000, 35.3213),
    ('Adıyaman', 37.7648, 38.2786),
    ('Afyonkarahisar', 38.7507, 30.5567),
    ('Ağrı', 39.7191, 43.0503),
    ('Amasya', 40.6499, 35.8353),
    ('Ankara', 39.9334, 32.8597),
    ('Antalya', 36.8969, 30.7133),
    ('Artvin', 41.1828, 41.8183),
    ('Aydın', 37.8444, 27.8458),
    ('Balıkesir', 39.6484, 27.8826),
    ('Bilecik', 40.1506, 29.9792),
    ('Bingöl', 38.8855, 40.4982),
    ('Bitlis', 38.4006, 42.1095),
    ('Bolu', 40.7359, 31.6060),
    ('Burdur', 37.7205, 30.2903),
    ('Bursa', 40.1826, 29.0669),
    ('Çanakkale', 40.1553, 26.4142),
    ('Çankırı', 40.6013, 33.6134),
    ('Çorum', 40.5506, 34.9556),
    ('Denizli', 37.7765, 29.0864),
    ('Diyarbakır', 37.9144, 40.2306),
    ('Edirne', 41.6818, 26.5623),
    ('Elazığ', 38.6810, 39.2264),
    ('Erzincan', 39.7500, 39.5000),
    ('Erzurum', 39.9055, 41.2658),
    ('Eskişehir', 39.7767, 30.5206),
    ('Gaziantep', 37.0662, 37.3833),
    ('Giresun', 40.9128, 38.3895),
    ('Gümüşhane', 40.4386, 39.4814),
    ('Hakkari', 37.5744, 43.7408),
    ('Hatay', 36.4018, 36.3498),
    ('Isparta', 37.7648, 30.5566),
    ('Mersin', 36.8000, 34.6333),
    ('İstanbul', 41.0082, 28.9784),
    ('İzmir', 38.4192, 27.1287),
    ('Kars', 40.6013, 43.0975),
    ('Kastamonu', 41.3887, 33.7827),
    ('Kayseri', 38.7312, 35.4787),
    ('Kırklareli', 41.7333, 27.2167),
    ('Kırşehir', 39.1425, 34.1709),
    ('Kocaeli', 40.8533, 29.8815),
    ('Konya', 37.8715, 32.4846),
    ('Kütahya', 39.4167, 29.9833),
    ('Malatya', 38.3552, 38.3095),
    ('Manisa', 38.6191, 27.4289),
    ('Kahramanmaraş', 37.5858, 36.9371),
    ('Mardin', 37.3212, 40.7245),
    ('Muğla', 37.2154, 28.3636),
    ('Muş', 38.9462, 41.7539),
    ('Nevşehir', 38.6939, 34.6857),
    ('Niğde', 37.9667, 34.6833),
    ('Ordu', 40.9862, 37.8797),
    ('Rize', 41.0201, 40.5234),
    ('Sakarya', 40.6940, 30.4358),
    ('Samsun', 41.2867, 36.3300),
    ('Siirt', 37.9333, 41.9500),
    ('Sinop', 42.0231, 35.1531),
    ('Sivas', 39.7477, 37.0179),
    ('Tekirdağ', 40.9781, 27.5115),
    ('Tokat', 40.3167, 36.5500),
    ('Trabzon', 41.0015, 39.7178),
    ('Tunceli', 39.1079, 39.5479),
    ('Şanlıurfa', 37.1591, 38.7969),
    ('Uşak', 38.6823, 29.4082),
    ('Van', 38.4891, 43.4089),
    ('Yozgat', 39.8181, 34.8147),
    ('Zonguldak', 41.4564, 31.7987),
    ('Aksaray', 38.3687, 34.0370),
    ('Bayburt', 40.2552, 40.2249),
    ('Karaman', 37.1759, 33.2287),
    ('Kırıkkale', 39.8468, 33.5156),
    ('Batman', 37.8812, 41.1351),
    ('Şırnak', 37.5164, 42.4611),
    ('Bartın', 41.6344, 32.3375),
    ('Ardahan', 41.1105, 42.7022),
    ('Iğdır', 39.9167, 44.0333),
    ('Yalova', 40.6500, 29.2667),
    ('Karabük', 41.2061, 32.6204),
    ('Kilis', 36.7184, 37.1212),
    ('Osmaniye', 37.0742, 36.2478),
    ('Düzce', 40.8438, 31.1565),
  ];

  (double, double)? get _cityCoords {
    if (widget.selectedCity == null) return null;
    for (final c in _turkishCities) {
      if (c.$1 == widget.selectedCity) return (c.$2, c.$3);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final l10n = widget.l10n;
    final primary = widget.primary;
    final coords = _cityCoords;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('gym.step2_title'),
            style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('gym.step2_subtitle'),
            style: AppText.of(context).bodyM.copyWith(
                  color: palette.textSecondary,
                ),
          ),
          const SizedBox(height: 28),

          // City dropdown
          Text(
            l10n.translate('gym.location_city_label').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: palette.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            padding: EdgeInsets.zero,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: widget.selectedCity,
                hint: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.translate('gym.location_city_hint'),
                    style: AppText.of(context).bodyM.copyWith(
                          color: palette.textTertiary,
                        ),
                  ),
                ),
                icon: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      color: palette.textSecondary),
                ),
                dropdownColor: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                style: AppText.of(context).bodyM.copyWith(
                      color: palette.textPrimary,
                    ),
                items: _turkishCities.map((city) {
                  return DropdownMenuItem<String>(
                    value: city.$1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(city.$1),
                    ),
                  );
                }).toList(),
                onChanged: (cityName) {
                  if (cityName == null) return;
                  HapticFeedback.selectionClick();
                  for (final c in _turkishCities) {
                    if (c.$1 == cityName) {
                      widget.onCityChanged(cityName, c.$2, c.$3);
                      // Move map to city center
                      _mapController.move(LatLng(c.$2, c.$3), 12.0);
                      break;
                    }
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Map
          if (coords != null) ...[
            Text(
              l10n.translate('gym.location_map_hint'),
              style: AppText.of(context).labelS.copyWith(
                    color: palette.textSecondary,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 280,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      widget.selectedLat ?? coords.$1,
                      widget.selectedLng ?? coords.$2,
                    ),
                    onTap: (tapPosition, latLng) {
                      HapticFeedback.selectionClick();
                      widget.onLocationPinned(
                          latLng.latitude, latLng.longitude);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cookrange.app',
                      maxZoom: 19,
                    ),
                    MarkerLayer(
                      markers: [
                        if (widget.selectedLat != null &&
                            widget.selectedLng != null)
                          Marker(
                            point: LatLng(
                                widget.selectedLat!, widget.selectedLng!),
                            width: 48,
                            height: 48,
                            child: Icon(Icons.location_on,
                                color: primary, size: 48),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Coordinates info card
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: palette.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.translate('gym.location_coords_info'),
                      style: AppText.of(context).labelS.copyWith(
                            color: palette.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Resolved address
            if (widget.geocodingInProgress)
              const AppCard(
                padding: EdgeInsets.all(14),
                child: AppSkeletonBox(),
              )
            else if (widget.resolvedAddress != null)
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.my_location_rounded,
                        color: palette.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.resolvedAddress!,
                        style: AppText.of(context).labelS.copyWith(
                              color: palette.textSecondary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ── Step 3: Phone Verification ────────────────────────────────────────────────

class _Step3Phone extends StatelessWidget {
  final TextEditingController phoneCtrl;
  final bool phoneVerified;
  final bool sendingOtp;
  final bool verifyingOtp;
  final TextEditingController otpCtrl;
  final String? verificationId;
  final VoidCallback onSendOtp;
  final VoidCallback onVerifyOtp;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final AppLocalizations l10n;

  const _Step3Phone({
    required this.phoneCtrl,
    required this.phoneVerified,
    required this.sendingOtp,
    required this.verifyingOtp,
    required this.otpCtrl,
    required this.verificationId,
    required this.onSendOtp,
    required this.onVerifyOtp,
    required this.palette,
    required this.isDark,
    required this.primary,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final otpSent = verificationId != null && !phoneVerified;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('gym.step_phone_title'),
            style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('gym.step_phone_subtitle'),
            style: AppText.of(context).bodyM.copyWith(
                  color: palette.textSecondary,
                ),
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
                    l10n.translate('gym.phone_info'),
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          if (phoneVerified) ...[
            // Success state
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
                      style: AppText.of(context).bodyM.copyWith(
                            color: palette.success,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Phone input
            AppTextField(
              controller: phoneCtrl,
              labelText: l10n.translate('gym.phone_label'),
              hintText: l10n.translate('gym.phone_hint'),
              prefixIcon: const Icon(Icons.phone_rounded),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              enabled: verificationId == null,
            ),
            const SizedBox(height: 16),
            AppButton(
              label: otpSent
                  ? l10n.translate('gym.phone_resend')
                  : l10n.translate('gym.phone_send_otp'),
              onPressed: onSendOtp,
              loading: sendingOtp,
              icon: Icons.send_rounded,
            ),

            // OTP input section (animated)
            if (otpSent) ...[
              const SizedBox(height: 24),
              AppTextField(
                controller: otpCtrl,
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
                onPressed: onVerifyOtp,
                loading: verifyingOtp,
                icon: Icons.verified_rounded,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ── Step 4: Documents ─────────────────────────────────────────────────────────

class _Step4Documents extends StatelessWidget {
  final File? businessLicenseFile;
  final File? idDocFile;
  final File? taxDocFile;
  final ValueChanged<File?> onBusinessLicensePicked;
  final ValueChanged<File?> onIdDocPicked;
  final ValueChanged<File?> onTaxDocPicked;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final AppLocalizations l10n;

  const _Step4Documents({
    required this.businessLicenseFile,
    required this.idDocFile,
    required this.taxDocFile,
    required this.onBusinessLicensePicked,
    required this.onIdDocPicked,
    required this.onTaxDocPicked,
    required this.palette,
    required this.isDark,
    required this.primary,
    required this.l10n,
  });

  Future<void> _pickFile(
      BuildContext context, ValueChanged<File?> onPicked) async {
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
      debugPrint('_Step4Documents: file pick error: $e');
    }
  }

  int get _requiredCount {
    int count = 0;
    if (businessLicenseFile != null) count++;
    if (idDocFile != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('gym.step_docs_title'),
            style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('gym.step_docs_subtitle'),
            style: AppText.of(context).bodyM.copyWith(
                  color: palette.textSecondary,
                ),
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
                    l10n.translate('gym.docs_info'),
                    style: AppText.of(context).labelS.copyWith(
                          color: palette.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Document counter badge
          AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _requiredCount == 2
                  ? palette.success.withValues(alpha: 0.12)
                  : palette.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _requiredCount == 2 ? palette.success : palette.border,
              ),
            ),
            child: Text(
              l10n
                  .translate('gym.docs_count')
                  .replaceAll('{n}', '$_requiredCount'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _requiredCount == 2
                    ? palette.success
                    : palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Business license
          _DocUploadCard(
            label: l10n.translate('gym.docs_business_license'),
            tapLabel: l10n.translate('gym.docs_tap_upload'),
            uploadedLabel: l10n.translate('gym.docs_uploaded'),
            file: businessLicenseFile,
            isRequired: true,
            onTap: () => _pickFile(context, onBusinessLicensePicked),
            palette: palette,
            primary: primary,
          ),
          const SizedBox(height: 14),

          // ID document
          _DocUploadCard(
            label: l10n.translate('gym.docs_id'),
            tapLabel: l10n.translate('gym.docs_tap_upload'),
            uploadedLabel: l10n.translate('gym.docs_uploaded'),
            file: idDocFile,
            isRequired: true,
            onTap: () => _pickFile(context, onIdDocPicked),
            palette: palette,
            primary: primary,
          ),
          const SizedBox(height: 14),

          // Tax certificate (optional)
          _DocUploadCard(
            label: l10n.translate('gym.docs_tax'),
            tapLabel: l10n.translate('gym.docs_tap_upload'),
            uploadedLabel: l10n.translate('gym.docs_uploaded'),
            file: taxDocFile,
            isRequired: false,
            onTap: () => _pickFile(context, onTaxDocPicked),
            palette: palette,
            primary: primary,
          ),
        ],
      ),
    );
  }
}

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

// ── Step 5: Settings & tags ───────────────────────────────────────────────────

class _Step5Settings extends StatelessWidget {
  final bool isPublic;
  final List<String> selectedTags;
  final List<String> allTags;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final AppLocalizations l10n;
  final ValueChanged<bool> onPublicChanged;
  final ValueChanged<String> onTagToggled;

  const _Step5Settings({
    required this.isPublic,
    required this.selectedTags,
    required this.allTags,
    required this.palette,
    required this.isDark,
    required this.primary,
    required this.l10n,
    required this.onPublicChanged,
    required this.onTagToggled,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('gym.step3_title'),
            style: AppText.of(context).headlineS.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.translate('gym.step3_subtitle'),
            style: AppText.of(context).bodyM.copyWith(
                  color: palette.textSecondary,
                ),
          ),
          const SizedBox(height: 28),
          // Public toggle
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    isPublic
                        ? Icons.public_rounded
                        : Icons.lock_outline_rounded,
                    color: primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('gym.field_public'),
                        style: AppText.of(context).bodyM.copyWith(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        l10n.translate('gym.field_public_sub'),
                        style: AppText.of(context).bodyM.copyWith(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ),
                AppToggle(
                  value: isPublic,
                  onChanged: onPublicChanged,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Tags
          Text(
            l10n.translate('gym.field_tags').toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: palette.textSecondary.withValues(alpha: 0.6),
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allTags.map((tag) {
              final isSelected = selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTagToggled(tag);
                },
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withValues(alpha: 0.15)
                        : palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? primary : palette.border,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? primary : palette.textSecondary,
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
}
