import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/onboarding_options.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/utils/app_routes.dart';
import '../../core/widgets/ds/ds.dart';

class PriorityOnboardingScreen extends StatefulWidget {
  const PriorityOnboardingScreen({super.key});

  @override
  State<PriorityOnboardingScreen> createState() =>
      _PriorityOnboardingScreenState();
}

class _PriorityOnboardingScreenState extends State<PriorityOnboardingScreen>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  String? _selectedGoal;
  String? _selectedActivity;
  bool _isSaving = false;

  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Show only the 4 most common goals for quick setup
  static const _quickGoals = [
    'lose_weight',
    'gain_weight',
    'maintain_weight',
    'feel_energetic',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0.08, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nextStep() {
    _controller.reverse().then((_) {
      setState(() => _step++);
      _controller.forward();
    });
  }

  Future<void> _finish() async {
    if (_selectedGoal == null || _selectedActivity == null) return;
    setState(() => _isSaving = true);
    try {
      await AuthService().updateUserOnboardingData({
        'primary_goals': _selectedGoal,
        'activity_level': _selectedActivity,
        'onboarding_completed': true,
      });
      if (mounted) {
        unawaited(Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.main,
          (route) => false,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppPalette.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AppPalette.of(context);
    final primary = context.watch<ThemeProvider>().primaryColor;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(l10n, palette, primary),
              const SizedBox(height: 32),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _step == 0
                        ? _buildGoalStep(l10n, palette, primary)
                        : _buildActivityStep(l10n, palette, primary),
                  ),
                ),
              ),
              _buildFooter(l10n, palette, primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, AppPalette palette, Color primary) {
    final t = AppText.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.rocket_launch, color: primary, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.translate('onboarding.priority.badge'),
              style: t.labelL.copyWith(color: primary),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _step == 0
              ? l10n.translate('onboarding.priority.goal_title')
              : l10n.translate('onboarding.priority.activity_title'),
          style: t.headlineL.copyWith(color: palette.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          _step == 0
              ? l10n.translate('onboarding.priority.goal_subtitle')
              : l10n.translate('onboarding.priority.activity_subtitle'),
          style: t.bodyL.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 24),
        // Step indicator
        Row(
          children: List.generate(2, (i) {
            final active = i == _step;
            final done = i < _step;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < 1 ? 6 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active || done ? primary : palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildGoalStep(AppLocalizations l10n, AppPalette palette, Color primary) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: _quickGoals.map((key) {
        final option = OnboardingOptions.primaryGoals[key]!;
        final isSelected = _selectedGoal == key;
        return _buildOptionCard(
          icon: option['icon'] as IconData,
          label: l10n.translate(option['label'] as String),
          isSelected: isSelected,
          palette: palette,
          primary: primary,
          onTap: () => setState(() => _selectedGoal = key),
        );
      }).toList(),
    );
  }

  Widget _buildActivityStep(AppLocalizations l10n, AppPalette palette, Color primary) {
    return ListView(
      children: OnboardingOptions.activityLevels.entries.map((entry) {
        final isSelected = _selectedActivity == entry.key;
        final option = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            icon: option['icon'] as IconData,
            label: l10n.translate(option['label'] as String),
            isSelected: isSelected,
            palette: palette,
            primary: primary,
            onTap: () => setState(() => _selectedActivity = entry.key),
            height: 72,
            isRow: true,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required AppPalette palette,
    required Color primary,
    required VoidCallback onTap,
    double? height,
    bool isRow = false,
  }) {
    final t = AppText.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: height,
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: 0.12)
              : palette.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primary : palette.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: palette.shadow.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isRow
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(icon,
                        color: isSelected ? primary : palette.textSecondary,
                        size: 26),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        label,
                        style: t.bodyL.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected ? primary : palette.textPrimary,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: primary, size: 20),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isSelected ? primary : palette.textSecondary,
                      size: 32),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: t.labelL.copyWith(
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? primary : palette.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter(AppLocalizations l10n, AppPalette palette, Color primary) {
    final canProceed =
        _step == 0 ? _selectedGoal != null : _selectedActivity != null;
    final t = AppText.of(context);

    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: canProceed && !_isSaving
                ? (_step == 0 ? _nextStep : _finish)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    _step == 0
                        ? l10n.translate('common.next')
                        : l10n.translate('onboarding.priority.get_started'),
                    style: t.titleM.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.main,
            (route) => false,
          ),
          child: Text(
            l10n.translate('onboarding.priority.skip'),
            style: t.bodyM.copyWith(color: palette.textSecondary),
          ),
        ),
      ],
    );
  }
}
