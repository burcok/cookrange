import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/onboarding_provider.dart';
import '../../../../widgets/number_picker_modal.dart';
import '../steps/onboarding_page1.dart';
import '../steps/onboarding_page2.dart';
import '../steps/onboarding_page3.dart';
import '../steps/onboarding_page4.dart';
import '../steps/onboarding_page5.dart';

class OnboardingStep extends StatelessWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  const OnboardingStep({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    try {
      final onboarding = Provider.of<OnboardingProvider>(context);
      switch (step) {
        case 0:
          return OnboardingPage1(
              step: step, previousStep: previousStep, onNext: onNext);
        case 1:
          return OnboardingPage2(
              step: step,
              previousStep: previousStep,
              onNext: onNext,
              onBack: onBack,
              onboarding: onboarding);
        case 2:
          return OnboardingPage3(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            onboarding: onboarding,
          );
        case 3:
          return OnboardingPage4(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            onboarding: onboarding,
            showActivityPicker: _showActivityPicker,
            showNumberInput: _showNumberInput,
          );
        case 4:
          return OnboardingPage5(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
          );
        default:
          return const Center(child: Text('Bilinmeyen adım'));
      }
    } catch (e, stack) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Bir hata oluştu. Lütfen tekrar deneyin.',
                  style: TextStyle(color: Colors.red, fontSize: 16)),
              const SizedBox(height: 8),
              Text(e.toString(),
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    }
  }

  void _showActivityPicker(
      BuildContext context, OnboardingProvider onboarding) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Az (Haftada 1-2)'),
            onTap: () {
              onboarding.setActivityLevel('Az (Haftada 1-2)');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Orta (Haftada 3-4)'),
            onTap: () {
              onboarding.setActivityLevel('Orta (Haftada 3-4)');
              Navigator.pop(context);
            },
          ),
          ListTile(
            title: const Text('Çok (Haftada 5+)'),
            onTap: () {
              onboarding.setActivityLevel('Çok (Haftada 5+)');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _showNumberInput(
      BuildContext context, OnboardingProvider onboarding, String field) {
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
        if (field == 'weight') onboarding.setWeight(value.toDouble());
        if (field == 'height') onboarding.setHeight(value.toDouble());
        if (field == 'targetWeight')
          onboarding.setTargetWeight(value.toDouble());
      }
    });
  }
}
