import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/models/gym_model.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/gym_service.dart';
import '../../core/services/storage_upload_service.dart';
import '../../core/widgets/ds/ds.dart';

/// Gym profile create / edit screen — step-by-step form.
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

  // Form state
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  bool _isPublic = true;
  final List<String> _selectedTags = [];

  // Branding state
  Color _selectedBrandColor = const Color(0xFFF97300);
  File? _logoFile;
  bool _uploadingLogo = false;

  static const _gymTags = [
    'CrossFit', 'Yoga', 'Boxing', 'Pilates', 'Powerlifting',
    'Bodybuilding', 'Cardio', 'HIIT', 'Martial Arts', 'Swimming',
  ];

  bool get _isEditMode => widget.existingGym != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final g = widget.existingGym!;
      _nameCtrl.text = g.name;
      _descCtrl.text = g.description ?? '';
      _addressCtrl.text = g.address ?? '';
      _cityCtrl.text = g.city ?? '';
      _countryCtrl.text = g.country ?? '';
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
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0 && _nameCtrl.text.trim().isEmpty) {
      AppSnackBar.warning(
        context,
        AppLocalizations.of(context).translate('gym.setup_name_required'),
      );
      return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: AppMotion.normal,
        curve: AppMotion.emphasized,
      );
    } else {
      _save();
    }
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
      debugPrint('GymSetupScreen: logo uploaded to $url');
    } catch (e) {
      debugPrint('GymSetupScreen: logo upload error: $e');
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

    try {
      if (_isEditMode) {
        await GymService().updateGym(widget.existingGym!.id, {
          'name': _nameCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'country': 'Türkiye',
          'is_public': _isPublic,
          'tags': _selectedTags,
          'brand_color': _brandColorHex,
        });
        if (_logoFile != null) {
          await _uploadLogoAndUpdate(widget.existingGym!.id);
        }
        if (!mounted) return;
        AppSnackBar.success(
          context,
          AppLocalizations.of(context).translate('gym.setup_updated'),
        );
        Navigator.of(context).pop(true);
      } else {
        final gym = await GymService().createGym(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          city: _cityCtrl.text.trim(),
          country: 'Türkiye',
          isPublic: _isPublic,
          tags: _selectedTags,
        );
        // Apply brand color right after creation
        await GymService().updateGym(gym.id, {'brand_color': _brandColorHex});
        // Upload logo if picked
        if (_logoFile != null) {
          await _uploadLogoAndUpdate(gym.id);
        }
        if (!mounted) return;
        unawaited(context.read<UserProvider>().refreshUser());
        AppSnackBar.success(
          context,
          AppLocalizations.of(context).translate('gym.setup_created'),
        );
        Navigator.of(context).pop(gym);
      }
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(
        context,
        AppLocalizations.of(context).translate('gym.setup_error'),
      );
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
          onPressed: _currentStep > 0 ? _prevStep : () => Navigator.pop(context),
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
              '${_currentStep + 1}/3',
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
            totalSteps: 3,
            primary: primary,
            palette: palette,
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _Step1BasicInfo(
                  nameCtrl: _nameCtrl,
                  descCtrl: _descCtrl,
                  palette: palette,
                  isDark: isDark,
                  l10n: l10n,
                  selectedBrandColor: _selectedBrandColor,
                  onColorChanged: (c) => setState(() => _selectedBrandColor = c),
                  logoFile: _logoFile,
                  uploadingLogo: _uploadingLogo,
                  existingLogoUrl: widget.existingGym?.logoUrl,
                  onLogoChanged: (f) => setState(() => _logoFile = f),
                ),
                _Step2Location(
                  addressCtrl: _addressCtrl,
                  cityCtrl: _cityCtrl,
                  palette: palette,
                  isDark: isDark,
                  l10n: l10n,
                ),
                _Step3Settings(
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
    final isLast = _currentStep == 2;
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
                : l10n.translate('gym.setup_create'))
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
    Color(0xFFF97300), // orange (default)
    Color(0xFFEF4444), // red
    Color(0xFFEC4899), // pink
    Color(0xFF8B5CF6), // purple
    Color(0xFF6366F1), // indigo
    Color(0xFF3B82F6), // blue
    Color(0xFF06B6D4), // cyan
    Color(0xFF10B981), // green
    Color(0xFF84CC16), // lime
    Color(0xFFF59E0B), // amber
    Color(0xFF78716C), // stone
    Color(0xFF1F2937), // dark
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
                            ? Image.network(existingLogoUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Center(
                                  child: Icon(
                                    Icons.add_a_photo_rounded,
                                    color: palette.textTertiary,
                                    size: 28,
                                  ),
                                ))
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

class _Step2Location extends StatelessWidget {
  final TextEditingController addressCtrl;
  final TextEditingController cityCtrl;
  final AppPalette palette;
  final bool isDark;
  final AppLocalizations l10n;

  const _Step2Location({
    required this.addressCtrl,
    required this.cityCtrl,
    required this.palette,
    required this.isDark,
    required this.l10n,
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
          AppTextField(
            controller: addressCtrl,
            labelText: l10n.translate('gym.field_address'),
            hintText: l10n.translate('gym.field_address_hint'),
            prefixIcon: const Icon(Icons.location_on_rounded),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: cityCtrl,
            labelText: l10n.translate('gym.field_city'),
            hintText: l10n.translate('gym.field_city_hint'),
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }
}

// ── Step 3: Settings & tags ───────────────────────────────────────────────────

class _Step3Settings extends StatelessWidget {
  final bool isPublic;
  final List<String> selectedTags;
  final List<String> allTags;
  final AppPalette palette;
  final bool isDark;
  final Color primary;
  final AppLocalizations l10n;
  final ValueChanged<bool> onPublicChanged;
  final ValueChanged<String> onTagToggled;

  const _Step3Settings({
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
                    isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withValues(alpha: 0.15)
                        : palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? primary
                          : palette.border,
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? primary
                          : palette.textSecondary,
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
