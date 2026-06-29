import 'package:flutter/material.dart';

import '../../../core/utils/app_routes.dart';

/// Transition from the completed V2 onboarding flow to account creation.
///
/// Navigates to the register screen with a flag so it knows to persist the
/// collected [OnboardingProvider] profile at sign-up and then route to the AI
/// meal-plan generation screen (instead of the legacy post-register onboarding).
class OnboardingRegistrationHandoff {
  OnboardingRegistrationHandoff._();

  /// Route argument key/flag indicating the register screen was reached from
  /// the V2 onboarding flow.
  static const String fromOnboardingArg = 'from_onboarding_v2';

  static void go(BuildContext context) {
    Navigator.of(context).pushNamed(
      AppRoutes.register,
      arguments: const {fromOnboardingArg: true},
    );
  }
}
