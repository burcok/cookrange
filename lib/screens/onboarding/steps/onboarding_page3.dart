import 'package:flutter/material.dart';
import '../../../constants.dart';
import '../../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../widgets/onboarding_common_widgets.dart';
import '../../../../widgets/gender_picker_modal.dart';
import '../../../../widgets/date_picker_modal.dart';
import '../../../../widgets/number_picker_modal.dart';
import '../../../core/services/analytics_service.dart';

class OnboardingPage3 extends StatefulWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final OnboardingProvider onboarding;
  const OnboardingPage3({
    Key? key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.onboarding,
  }) : super(key: key);

  @override
  State<OnboardingPage3> createState() => _OnboardingPage3State();
}

class _OnboardingPage3State extends State<OnboardingPage3> {
  final _analyticsService = AnalyticsService();
  late TextEditingController weightController;
  late TextEditingController heightController;
  late TextEditingController birthDateController;
  String? selectedGender;
  DateTime? selectedBirthDate;
  DateTime? _stepStartTime;

  @override
  void initState() {
    super.initState();
    _stepStartTime = DateTime.now();
    selectedGender = widget.onboarding.gender;
    weightController =
        TextEditingController(text: widget.onboarding.weight?.toString() ?? '');
    heightController =
        TextEditingController(text: widget.onboarding.height?.toString() ?? '');
    birthDateController = TextEditingController(
        text: widget.onboarding.birthDate != null
            ? _formatDate(widget.onboarding.birthDate!)
            : '');
    selectedBirthDate = widget.onboarding.birthDate;
    _logStepView();
  }

  @override
  void dispose() {
    if (_stepStartTime != null) {
      final duration = DateTime.now().difference(_stepStartTime!);
      _analyticsService.logScreenTime(
        screenName: 'onboarding_step_3',
        duration: duration,
      );
    }
    weightController.dispose();
    heightController.dispose();
    birthDateController.dispose();
    super.dispose();
  }

  void _logStepView() {
    _analyticsService.logUserFlow(
      flowName: 'onboarding',
      step: 'profile_info',
      action: 'view',
      parameters: {
        'step_number': 3,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  void _logFieldUpdate(String field, dynamic value) {
    _analyticsService.logUserInteraction(
      interactionType: 'field_update',
      target: field,
      parameters: {
        'step': 3,
        'field': field,
        'value': value.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showGenderPicker(BuildContext context, OnboardingProvider onboarding) {
    _analyticsService.logUserInteraction(
      interactionType: 'modal_open',
      target: 'gender_picker',
      parameters: {
        'step': 3,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => GenderPickerModal(
        selectedGender: onboarding.gender,
        onSelected: (gender) {
          _logFieldUpdate('gender', gender);
          setState(() {
            selectedGender = gender;
            onboarding.setGender(gender);
          });
        },
      ),
    );
  }

  void _showDatePicker(BuildContext context, OnboardingProvider onboarding) {
    _analyticsService.logUserInteraction(
      interactionType: 'modal_open',
      target: 'date_picker',
      parameters: {
        'step': 3,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    final now = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DatePickerModal(
        initialDate: onboarding.birthDate ?? DateTime(now.year - 20),
        minDate: DateTime(1900, 1, 1),
        maxDate: now,
        onSelected: (date) {
          _logFieldUpdate('birth_date', _formatDate(date));
          setState(() {
            selectedBirthDate = date;
            birthDateController.text = _formatDate(date);
            onboarding.setBirthDate(date);
          });
        },
      ),
    );
  }

  void _showNumberInput(
      BuildContext context, OnboardingProvider onboarding, String field) {
    _analyticsService.logUserInteraction(
      interactionType: 'modal_open',
      target: '${field}_picker',
      parameters: {
        'step': 3,
        'field': field,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
    int min, max, initialValue;
    String unit, title;
    if (field == 'weight') {
      min = 40;
      max = 150;
      unit = 'kg';
      title = 'Kilonu Seç';
      initialValue = onboarding.weight?.toInt() ?? 70;
    } else if (field == 'height') {
      min = 140;
      max = 220;
      unit = 'cm';
      title = 'Boyunu Seç';
      initialValue = onboarding.height?.toInt() ?? 170;
    } else {
      min = 40;
      max = 150;
      unit = 'kg';
      title = 'Hedef Kilonu Seç';
      initialValue = onboarding.targetWeight?.toInt() ?? 60;
    }
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (context) => NumberPickerModal(
        title: title,
        min: min,
        max: max,
        unit: unit,
        initialValue: initialValue,
      ),
    ).then((value) {
      if (value != null && value is int) {
        _logFieldUpdate(field, value);
        setState(() {
          if (field == 'weight') {
            weightController.text = value.toString();
            onboarding.setWeight(value.toDouble());
          }
          if (field == 'height') {
            heightController.text = value.toString();
            onboarding.setHeight(value.toDouble());
          }
          if (field == 'targetWeight') {
            onboarding.setTargetWeight(value.toDouble());
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onboarding = widget.onboarding;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: colorScheme.background,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              _analyticsService.logUserInteraction(
                                interactionType: 'navigation',
                                target: 'back_button',
                                parameters: {
                                  'step': 3,
                                  'timestamp': DateTime.now().toIso8601String(),
                                },
                              );
                              widget.onBack?.call();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: colorScheme.onboardingTitleColor
                                      .withOpacity(0.1),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back,
                                color: colorScheme.onboardingTitleColor,
                                size: 24,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                '3/5',
                                style: TextStyle(
                                  color: colorScheme.onboardingTitleColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.2,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Profilini ',
                                  style: TextStyle(
                                    color: colorScheme
                                        .onboardingNextButtonBorderColor,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                TextSpan(
                                  text: 'tamamlayalım',
                                  style: TextStyle(
                                    color: colorScheme.onboardingTitleColor,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Bu bilgileri sana daha iyi bir hizmet sunmak için kullanacağız.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: colorScheme.onboardingSubtitleColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          // Cinsiyet Modal
                          GestureDetector(
                            onTap: () => _showGenderPicker(context, onboarding),
                            child: OnboardingCardInput(
                              icon: Icons.person,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      selectedGender ?? 'Cinsiyetin',
                                      style: TextStyle(
                                        color: colorScheme
                                            .onboardingOptionTextColor,
                                        fontSize: 17,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down,
                                      color: colorScheme
                                          .onboardingOptionTextColor),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Doğum Tarihi
                          GestureDetector(
                            onTap: () => _showDatePicker(context, onboarding),
                            child: OnboardingCardInput(
                              icon: Icons.calendar_today,
                              child: Text(
                                birthDateController.text.isNotEmpty
                                    ? birthDateController.text
                                    : 'Doğum Tarihin',
                                style: TextStyle(
                                  color: colorScheme.onboardingOptionTextColor,
                                  fontSize: 17,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Kilo
                          GestureDetector(
                            onTap: () =>
                                _showNumberInput(context, onboarding, 'weight'),
                            child: OnboardingCardInput(
                              icon: Icons.monitor_weight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      weightController.text.isNotEmpty
                                          ? weightController.text
                                          : 'Kilon',
                                      style: TextStyle(
                                        color: colorScheme
                                            .onboardingOptionTextColor,
                                        fontSize: 17,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                  Text('kg',
                                      style: TextStyle(
                                          color: colorScheme
                                              .onboardingOptionTextColor,
                                          fontSize: 17,
                                          fontFamily: 'Poppins')),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Boy
                          GestureDetector(
                            onTap: () =>
                                _showNumberInput(context, onboarding, 'height'),
                            child: OnboardingCardInput(
                              icon: Icons.height,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Text(
                                      heightController.text.isNotEmpty
                                          ? heightController.text
                                          : 'Boyun',
                                      style: TextStyle(
                                        color: colorScheme
                                            .onboardingOptionTextColor,
                                        fontSize: 17,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                                  Text('cm',
                                      style: TextStyle(
                                          color: colorScheme
                                              .onboardingOptionTextColor,
                                          fontSize: 17,
                                          fontFamily: 'Poppins')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 24,
                  child: IgnorePointer(
                    ignoring: !_isFormValid(),
                    child: Opacity(
                      opacity: _isFormValid() ? 1.0 : 0.5,
                      child: OnboardingNextButton(
                        step: widget.step,
                        previousStep: widget.previousStep,
                        onNext: () {
                          _analyticsService.logUserInteraction(
                            interactionType: 'button_click',
                            target: 'next_button',
                            parameters: {
                              'step': 3,
                              'gender': onboarding.gender,
                              'birth_date':
                                  onboarding.birthDate?.toIso8601String(),
                              'weight': onboarding.weight,
                              'height': onboarding.height,
                              'timestamp': DateTime.now().toIso8601String(),
                            },
                          );
                          widget.onNext?.call();
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isFormValid() {
    return widget.onboarding.gender != null &&
        widget.onboarding.birthDate != null &&
        widget.onboarding.weight != null &&
        widget.onboarding.height != null;
  }
}

class _OnboardingCardInput extends StatelessWidget {
  final IconData icon;
  final Widget child;
  const _OnboardingCardInput({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.onboardingOptionBgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onboardingOptionTextColor, size: 24),
          const SizedBox(width: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}
