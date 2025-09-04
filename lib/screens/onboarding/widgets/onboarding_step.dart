import 'package:flutter/material.dart';
import '../steps/onboarding_page1.dart';
import '../steps/onboarding_page2.dart';
import '../steps/onboarding_page3.dart';
import '../steps/onboarding_page4.dart';
import '../steps/onboarding_page5.dart';
import '../steps/onboarding_page_profile.dart';

class OnboardingStep extends StatelessWidget {
  final int step;
  final int previousStep;
  final void Function()? onNext;
  final void Function()? onBack;
  final ValueNotifier<bool> isLoadingNotifier;

  const OnboardingStep({
    super.key,
    required this.step,
    required this.previousStep,
    this.onNext,
    this.onBack,
    required this.isLoadingNotifier,
  });

  @override
  Widget build(BuildContext context) {
    try {
      switch (step) {
        case 0:
          return OnboardingPage1(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            isLoadingNotifier: isLoadingNotifier,
          );
        case 1:
          return OnboardingPage2(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            isLoadingNotifier: isLoadingNotifier,
          );
        case 2:
          return OnboardingPage3(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            isLoadingNotifier: isLoadingNotifier,
          );
        case 3:
          return OnboardingPage4(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            isLoadingNotifier: isLoadingNotifier,
          );
        case 4:
          return OnboardingPage5(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            isLoadingNotifier: isLoadingNotifier,
          );
        case 5:
          return OnboardingPageProfile(
            step: step,
            previousStep: previousStep,
            onNext: onNext,
            onBack: onBack,
            isLoadingNotifier: isLoadingNotifier,
          );
        default:
          // This should not be reached if the step count is correct.
          return const Center(child: Text('Invalid step'));
      }
    } catch (e) {
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
}
