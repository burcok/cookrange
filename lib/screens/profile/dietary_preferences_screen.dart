import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/onboarding_options.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/user_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/widgets/ds/ds.dart';

class DietaryPreferencesScreen extends StatefulWidget {
  const DietaryPreferencesScreen({super.key});

  @override
  State<DietaryPreferencesScreen> createState() =>
      _DietaryPreferencesScreenState();
}

class _DietaryPreferencesScreenState extends State<DietaryPreferencesScreen> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  List<String> _avoidIngredients = [];
  bool _isSaving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().user?.profile;
    _avoidIngredients = List<String>.from(profile?.avoidIngredients ?? []);
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _addItem() {
    final text = _textController.text.trim();
    if (text.isEmpty || _avoidIngredients.contains(text)) return;
    setState(() {
      _avoidIngredients.add(text);
      _hasChanges = true;
    });
    _textController.clear();
    _focusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _removeItem(String item) {
    setState(() {
      _avoidIngredients.remove(item);
      _hasChanges = true;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _save() async {
    final uid = context.read<UserProvider>().user?.uid;
    final userProvider = context.read<UserProvider>();
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      await FirestoreService().updateAvoidIngredients(uid, _avoidIngredients);
      await userProvider.refreshUser();
      if (!mounted) return;
      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });
      unawaited(HapticFeedback.mediumImpact());
      AppSnackBar.success(
        context,
        AppLocalizations.of(context).translate('dietary_prefs.saved'),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppSnackBar.error(
        context,
        AppLocalizations.of(context).translate('generic_error.title_main'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final t = AppText.of(context);
    final profile = context.read<UserProvider>().user?.profile;

    final allergyIds = profile?.allergyIds ?? [];
    final dietaryIds = profile?.dietaryRestrictionIds ?? [];

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: palette.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('dietary_prefs.title'),
          style: t.titleM.copyWith(color: palette.textPrimary),
        ),
        actions: [
          if (_hasChanges)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: AppButton(
                label: l10n.translate('dietary_prefs.save'),
                onPressed: _save,
                loading: _isSaving,
                size: AppButtonSize.small,
                expand: false,
              ),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Allergies (read-only) ─────────────────────────────────────
            _SectionCard(
              title: l10n.translate('dietary_prefs.allergies_title'),
              subtitle: l10n.translate('dietary_prefs.allergies_subtitle'),
              palette: palette,
              t: t,
              icon: Icons.warning_amber_rounded,
              iconColor: palette.error,
              child: allergyIds.isEmpty
                  ? Text(
                      l10n.translate('dietary_prefs.none_set'),
                      style: t.bodyM.copyWith(color: palette.textSecondary),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allergyIds.map((id) {
                        final info = OnboardingOptions.allergies[id];
                        final label = info != null
                            ? l10n.translate(info['label'] as String)
                            : id;
                        return _ReadOnlyChip(
                          label: label,
                          color: palette.error,
                          palette: palette,
                          t: t,
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 12),

            // ── Dietary Restrictions (read-only) ──────────────────────────
            _SectionCard(
              title: l10n.translate('dietary_prefs.diet_title'),
              subtitle: l10n.translate('dietary_prefs.diet_subtitle'),
              palette: palette,
              t: t,
              icon: Icons.eco_rounded,
              iconColor: palette.success,
              child: dietaryIds.isEmpty
                  ? Text(
                      l10n.translate('dietary_prefs.none_set'),
                      style: t.bodyM.copyWith(color: palette.textSecondary),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: dietaryIds.map((id) {
                        final info = OnboardingOptions.dietaryRestrictions[id];
                        final label = info != null
                            ? l10n.translate(info['label'] as String)
                            : id;
                        return _ReadOnlyChip(
                          label: label,
                          color: palette.success,
                          palette: palette,
                          t: t,
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 12),

            // ── Avoid Ingredients (editable) ──────────────────────────────
            _SectionCard(
              title: l10n.translate('dietary_prefs.avoid_title'),
              subtitle: l10n.translate('dietary_prefs.avoid_subtitle'),
              palette: palette,
              t: t,
              icon: Icons.block_rounded,
              iconColor: palette.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input row
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          hintText: l10n.translate('dietary_prefs.avoid_hint'),
                          onSubmitted: (_) => _addItem(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AddButton(onTap: _addItem, primary: palette.warning),
                    ],
                  ),
                  if (_avoidIngredients.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _avoidIngredients
                          .map((item) => _RemovableChip(
                                label: item,
                                onRemove: () => _removeItem(item),
                                palette: palette,
                                t: t,
                              ))
                          .toList(),
                    ),
                  ],
                  if (_avoidIngredients.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.translate('dietary_prefs.avoid_empty'),
                      style: t.labelS.copyWith(color: palette.textTertiary),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save button (bottom)
            AnimatedOpacity(
              opacity: _hasChanges ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: AppButton(
                label: l10n.translate('dietary_prefs.save'),
                onPressed: _hasChanges ? _save : null,
                loading: _isSaving,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final AppPalette palette;
  final AppText t;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.t,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style:
                            t.labelL.copyWith(color: palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            t.labelS.copyWith(color: palette.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ReadOnlyChip extends StatelessWidget {
  final String label;
  final Color color;
  final AppPalette palette;
  final AppText t;

  const _ReadOnlyChip({
    required this.label,
    required this.color,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: t.labelS.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final AppPalette palette;
  final AppText t;

  const _RemovableChip({
    required this.label,
    required this.onRemove,
    required this.palette,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: palette.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: t.labelS.copyWith(
              color: palette.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded,
                size: 16, color: palette.warning.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final Color primary;

  const _AddButton({required this.onTap, required this.primary});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.add_rounded, color: primary, size: 24),
      ),
    );
  }
}
