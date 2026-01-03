import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cookrange/core/localization/app_localizations.dart';
import 'package:cookrange/core/providers/onboarding_provider.dart';
import 'package:cookrange/core/theme/app_theme.dart';
import 'package:cookrange/widgets/onboarding_common_widgets.dart';
import 'package:cookrange/core/services/analytics_service.dart';
import 'package:cookrange/constants.dart';
import 'package:flutter/foundation.dart' show mapEquals;

class OnboardingPage5 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final ValueNotifier<bool> isLoadingNotifier;

  const OnboardingPage5({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.isLoadingNotifier,
  });

  @override
  State<OnboardingPage5> createState() => _OnboardingPage5State();
}

class _LifestyleProfile {
  final String key;
  final String image;
  final String name;
  final String description;
  final String times;
  final List<String> mealTimes; // For 'fixed' schedule type as a default

  _LifestyleProfile({
    required this.key,
    required this.image,
    required this.name,
    required this.description,
    required this.times,
    required this.mealTimes,
  });
}

class _OnboardingPage5State extends State<OnboardingPage5> {
  final _analyticsService = AnalyticsService();
  DateTime? _stepStartTime;

  _LifestyleProfile? _selectedProfile;
  List<_LifestyleProfile> _profiles = [];

  @override
  void initState() {
    super.initState();
    _stepStartTime = DateTime.now();
    _logStepView();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initializeProfiles();
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    if (_stepStartTime != null) {
      final duration = DateTime.now().difference(_stepStartTime!);
      _analyticsService.logScreenTime(
        screenName: 'onboarding_step_5',
        duration: duration,
      );
    }
    super.dispose();
  }

  void _logStepView() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'lifestyle_profile',
      action: 'view',
      parameters: {
        'step_number': 5,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logSelection(String profileKey) {
    _analyticsService.logUserInteraction(
      interactionType: 'selection',
      target: 'lifestyle_profile_selection',
      parameters: {
        'step': 5,
        'profile': profileKey,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _initializeProfiles() {
    final localizations = AppLocalizations.of(context);
    _profiles = [
      _LifestyleProfile(
          key: 'early_bird',
          image: 'assets/images/onboarding/onboarding-5-1.png',
          name: localizations
              .translate('onboarding.page5.profiles.early_bird.name'),
          description: localizations
              .translate('onboarding.page5.profiles.early_bird.description'),
          times: localizations
              .translate('onboarding.page5.profiles.early_bird.times'),
          mealTimes: ['07:00', '12:00', '18:00']),
      _LifestyleProfile(
          key: 'worker',
          image: 'assets/images/onboarding/onboarding-5-2.png',
          name:
              localizations.translate('onboarding.page5.profiles.worker.name'),
          description: localizations
              .translate('onboarding.page5.profiles.worker.description'),
          times:
              localizations.translate('onboarding.page5.profiles.worker.times'),
          mealTimes: ['08:00', '13:00', '19:00']),
      _LifestyleProfile(
        key: 'night_owl',
        image: 'assets/images/onboarding/onboarding-5-3.png',
        name:
            localizations.translate('onboarding.page5.profiles.night_owl.name'),
        description: localizations
            .translate('onboarding.page5.profiles.night_owl.description'),
        times: localizations
            .translate('onboarding.page5.profiles.night_owl.times'),
        mealTimes: ['11:00', '16:00', '21:00'],
      ),
      _LifestyleProfile(
        key: 'rotating_shifts',
        image: 'assets/images/onboarding/onboarding-5-4.png',
        name: localizations
            .translate('onboarding.page5.profiles.rotating_shifts.name'),
        description: localizations
            .translate('onboarding.page5.profiles.rotating_shifts.description'),
        times: localizations
            .translate('onboarding.page5.profiles.rotating_shifts.times'),
        mealTimes: [], // Handled by schedule editor
      ),
      _LifestyleProfile(
        key: 'irregular_schedule',
        image: 'assets/images/onboarding/onboarding-5-5.png',
        name: localizations
            .translate('onboarding.page5.profiles.irregular_schedule.name'),
        description: localizations.translate(
            'onboarding.page5.profiles.irregular_schedule.description'),
        times: localizations
            .translate('onboarding.page5.profiles.irregular_schedule.times'),
        mealTimes: [], // Handled by schedule editor
      ),
    ];
    setState(() {});
  }

  void _loadInitialData() {
    final onboarding = context.read<OnboardingProvider>();
    if (onboarding.lifestyleProfile != null && _profiles.isNotEmpty) {
      final initialProfileKey = onboarding.lifestyleProfile!['value'];
      final profile = _profiles.firstWhere(
        (p) => p.key == initialProfileKey,
        orElse: () => _profiles.first,
      );
      _selectedProfile = profile;
    } else if (_profiles.isNotEmpty) {
      _selectedProfile = _profiles.first;
    }

    if (onboarding.mealSchedule?['schedule_type'] == null) {
      String defaultScheduleType;
      if (_selectedProfile?.key == 'rotating_shifts') {
        defaultScheduleType = 'rotating';
      } else if (_selectedProfile?.key == 'irregular_schedule') {
        defaultScheduleType = 'irregular';
      } else {
        defaultScheduleType = 'fixed';
      }
      onboarding.setScheduleType(defaultScheduleType);
    }
    setState(() {});
  }

  void _onProfileSelected(_LifestyleProfile profile) {
    setState(() {
      _selectedProfile = profile;
    });

    final onboarding = context.read<OnboardingProvider>();
    String newScheduleType;
    List<String>? mealTimes;

    if (profile.key == 'rotating_shifts') {
      newScheduleType = 'rotating';
    } else if (profile.key == 'irregular_schedule') {
      newScheduleType = 'irregular';
    } else {
      newScheduleType = 'fixed';
      mealTimes = profile.mealTimes;
    }

    onboarding.setScheduleType(newScheduleType, mealTimes: mealTimes);
    _logSelection(profile.key);
  }

  void _onContinue() {
    if (_selectedProfile != null) {
      context
          .read<OnboardingProvider>()
          .setLifestyleProfile(_selectedProfile!.key);
      widget.onNext?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_profiles.isEmpty) {
      return Scaffold(
        backgroundColor: colorScheme.backgroundColor2,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.backgroundColor2,
      body: SafeArea(
        child: Column(
          children: [
            OnboardingHeader(
              title: localizations.translate('onboarding.page5.header'),
              currentStep: 5,
              totalSteps: 6,
              previousStep: widget.previousStep,
              onBackButtonPressed: () {
                _analyticsService.logUserInteraction(
                  interactionType: 'navigation',
                  target: 'back_button',
                  parameters: {
                    'step': 5,
                    'timestamp': DateTime.now().toIso8601String(),
                  },
                );
                if (widget.onBack != null) {
                  widget.onBack!();
                }
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Main Title
                    Text(
                      localizations.translate('onboarding.page5.title'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onboardingTitleColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      localizations.translate('onboarding.page5.description'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: colorScheme.onboardingSubtitleColor,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(height: 24),
                    ..._profiles.map((profile) => _buildProfileCard(profile)),
                    const SizedBox(height: 24),
                    Selector<OnboardingProvider, String?>(
                      selector: (_, provider) =>
                          provider.mealSchedule?['schedule_type'],
                      builder: (context, scheduleType, _) {
                        if (scheduleType == 'rotating') {
                          return _buildRotatingScheduleEditor();
                        }
                        if (scheduleType == 'irregular') {
                          return _buildIrregularScheduleEditor();
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildPreview(),
                    const SizedBox(height: 100), // For bottom button spacing
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: OnboardingContinueButton(
        onPressed: _selectedProfile != null ? _onContinue : null,
        text: localizations.translate('onboarding.continue'),
        isLoadingNotifier: widget.isLoadingNotifier,
      ),
    );
  }

  Widget _buildProfileCard(_LifestyleProfile profile) {
    final isSelected = _selectedProfile?.key == profile.key;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => _onProfileSelected(profile),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? primaryColor : Colors.grey.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onboardingTitleColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onboardingSubtitleColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    profile.times,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onboardingSubtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                profile.image,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIrregularScheduleEditor() {
    final localizations = AppLocalizations.of(context);
    final mealSchedule = context.watch<OnboardingProvider>().mealSchedule ?? {};

    final Map<String, IconData> mealIcons = {
      'breakfast': Icons.restaurant_outlined,
      'lunch': Icons.local_cafe_outlined,
      'dinner': Icons.nightlight_round,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Text(
          localizations
              .translate('onboarding.page5.schedule_editor.irregular.title'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onboardingTitleColor,
          ),
        ),
        const SizedBox(height: 16),
        _buildTimePickerRow(
          'breakfast',
          localizations.translate('onboarding.page5.preview.breakfast'),
          mealSchedule['breakfast'] ?? '08:00',
          mealIcons['breakfast']!,
          (time) => context
              .read<OnboardingProvider>()
              .updateMealTime('breakfast', time),
        ),
        _buildTimePickerRow(
          'lunch',
          localizations.translate('onboarding.page5.preview.lunch'),
          mealSchedule['lunch'] ?? '13:00',
          mealIcons['lunch']!,
          (time) =>
              context.read<OnboardingProvider>().updateMealTime('lunch', time),
        ),
        _buildTimePickerRow(
          'dinner',
          localizations.translate('onboarding.page5.preview.dinner'),
          mealSchedule['dinner'] ?? '19:00',
          mealIcons['dinner']!,
          (time) =>
              context.read<OnboardingProvider>().updateMealTime('dinner', time),
        ),
      ],
    );
  }

  Widget _buildRotatingScheduleEditor() {
    return Selector<OnboardingProvider, int>(
        selector: (_, provider) =>
            provider.mealSchedule?['rotation_weeks'] ?? 2,
        builder: (context, rotationWeeks, _) {
          final localizations = AppLocalizations.of(context);
          final colorScheme = Theme.of(context).colorScheme;

          return Container(
            padding:
                const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
            decoration: BoxDecoration(
              color: Colors.transparent, // White card background
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate(
                      'onboarding.page5.profiles.rotating_shifts.name'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onboardingTitleColor,
                  ),
                ),
                const SizedBox(height: 24),
                _buildWeekSelector(rotationWeeks),
                const SizedBox(height: 24),
                Divider(color: Colors.grey.withValues(alpha: 0.5)),
                for (int i = 0; i < rotationWeeks; i++)
                  _buildWeekScheduleEditor(i + 1,
                      isLast: i == rotationWeeks - 1),
              ],
            ),
          );
        });
  }

  Widget _buildWeekSelector(int selectedWeeks) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: List.generate(3, (index) {
          final week = index + 2;
          final isSelected = week == selectedWeeks;
          return Expanded(
            child: GestureDetector(
              onTap: () =>
                  context.read<OnboardingProvider>().updateRotationWeeks(week),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$week ${localizations.translate('onboarding.page5.schedule_editor.rotating.week_short')}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isSelected
                        ? Colors.white
                        : colorScheme.onboardingSubtitleColor,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildWeekScheduleEditor(int week, {bool isLast = false}) {
    final localizations = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final Map<String, IconData> mealIcons = {
      'breakfast': Icons.restaurant_outlined,
      'lunch': Icons.local_cafe_outlined,
      'dinner': Icons.nightlight_round,
    };

    return Selector<OnboardingProvider, Map<String, dynamic>>(
      selector: (_, provider) {
        final shifts = provider.mealSchedule?['shifts'] as List? ?? [];
        return shifts.firstWhere(
          (s) => s['week'] == week,
          orElse: () => {
            'breakfast': '07:00',
            'lunch': '12:00',
            'dinner': '18:00',
          },
        );
      },
      shouldRebuild: (previous, next) => !mapEquals(previous, next),
      builder: (context, weekSchedule, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: 24.0, bottom: 12.0), // Adjusted padding
              child: Text(
                '${localizations.translate('onboarding.page5.schedule_editor.rotating.week')} $week',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onboardingTitleColor,
                ),
              ),
            ),
            _buildTimePickerRow(
              'breakfast',
              localizations.translate('onboarding.page5.preview.breakfast'),
              weekSchedule['breakfast']!,
              mealIcons['breakfast']!,
              (time) => context
                  .read<OnboardingProvider>()
                  .updateMealTime('breakfast', time, week: week),
            ),
            const SizedBox(height: 12),
            _buildTimePickerRow(
              'lunch',
              localizations.translate('onboarding.page5.preview.lunch'),
              weekSchedule['lunch']!,
              mealIcons['lunch']!,
              (time) => context
                  .read<OnboardingProvider>()
                  .updateMealTime('lunch', time, week: week),
            ),
            const SizedBox(height: 12),
            _buildTimePickerRow(
              'dinner',
              localizations.translate('onboarding.page5.preview.dinner'),
              weekSchedule['dinner']!,
              mealIcons['dinner']!,
              (time) => context
                  .read<OnboardingProvider>()
                  .updateMealTime('dinner', time, week: week),
            ),
            if (!isLast)
              const SizedBox(
                height: 24,
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimePickerRow(String mealKey, String label, String currentTime,
      IconData icon, Function(String) onTimeChanged) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.5))),
      child: Row(
        children: [
          Icon(
            icon,
            color: colorScheme.onboardingSubtitleColor,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: colorScheme.onboardingTitleColor),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              final initialTime = TimeOfDay(
                hour: int.parse(currentTime.split(':')[0]),
                minute: int.parse(currentTime.split(':')[1]),
              );

              final time = await showTimePicker(
                context: context,
                initialTime: initialTime,
              );

              if (time != null) {
                onTimeChanged(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
              ),
              child: Text(
                currentTime,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onboarding = context.watch<OnboardingProvider>();
    final mealSchedule = onboarding.mealSchedule;
    final scheduleType = onboarding.mealSchedule?['schedule_type'];

    if (scheduleType != 'fixed') {
      return const SizedBox.shrink();
    }

    String breakfastTime = '--:--';
    String lunchTime = '--:--';
    String dinnerTime = '--:--';

    if (mealSchedule != null) {
      breakfastTime = mealSchedule['breakfast'] ?? '--:--';
      lunchTime = mealSchedule['lunch'] ?? '--:--';
      dinnerTime = mealSchedule['dinner'] ?? '--:--';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.translate('onboarding.page5.preview.title'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'Poppins',
            color: colorScheme.onboardingTitleColor,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          child: Column(
            children: [
              _buildMealTimeline(
                iconPath: 'assets/icons/breakfast.png',
                mealName: localizations
                    .translate('onboarding.page5.preview.breakfast'),
                time: breakfastTime,
                isFirst: true,
              ),
              _buildMealTimeline(
                iconPath: 'assets/icons/lunch.png',
                mealName:
                    localizations.translate('onboarding.page5.preview.lunch'),
                time: lunchTime,
              ),
              _buildMealTimeline(
                iconPath: 'assets/icons/dinner.png',
                mealName:
                    localizations.translate('onboarding.page5.preview.dinner'),
                time: dinnerTime,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMealTimeline({
    required String iconPath,
    required String mealName,
    required String time,
    bool isFirst = false,
    bool isLast = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 80,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Column(
              spacing: 10,
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : colorScheme.onboardingSubtitleColor
                            .withValues(alpha: 0.3),
                  ),
                ),
                Image.asset(
                  iconPath,
                  width: 32,
                  height: 32,
                  color: colorScheme.onboardingTitleColor,
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : colorScheme.onboardingSubtitleColor
                            .withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                mealName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onboardingTitleColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onboardingSubtitleColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
