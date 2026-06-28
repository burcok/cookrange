import '../models/user_model.dart';
import 'app_routes.dart';

/// The route the app should navigate to next, with an optional initial step
/// for the onboarding screen.
class OnboardingDestination {
  final String route;
  /// Non-null only when [route] == [AppRoutes.onboarding].
  final int? initialStep;

  const OnboardingDestination(this.route, {this.initialStep});
}

/// Pure, synchronous resolver: given a [UserModel], returns the next
/// navigation destination. Call this once after loading the user in splash
/// and whenever the route guard needs a re-check.
///
/// Decision tree:
///   1. No user            → login
///   2. Email unverified   → verifyEmail
///   3. Intro not seen     → intro
///   4. Onboarding complete & data valid → main
///   5. Onboarding incomplete → onboarding @ first missing step
class OnboardingFlowResolver {
  const OnboardingFlowResolver._();

  /// Returns the [OnboardingDestination] for the given [user].
  static OnboardingDestination resolve(UserModel? user) {
    if (user == null) {
      return const OnboardingDestination(AppRoutes.login);
    }

    if (!user.introSeen) {
      return const OnboardingDestination(AppRoutes.intro);
    }

    if (_isDataComplete(user)) {
      return const OnboardingDestination(AppRoutes.main);
    }

    final step = firstIncompleteStep(user.onboardingData);
    return OnboardingDestination(AppRoutes.onboarding, initialStep: step);
  }

  /// Returns the step index (0-based) of the first incomplete onboarding step.
  /// Returns 0 if no data exists at all.
  static int firstIncompleteStep(Map<String, dynamic>? data) {
    if (data == null) return 0;

    // Step 1 — Goals & Activity
    final goals = data['primary_goals'];
    final hasGoals = goals is List ? goals.isNotEmpty : goals != null;
    if (!hasGoals || data['activity_level'] == null) return 1;

    // Step 2 — Dietary prefs (optional; always considered done)

    // Step 3 — Cooking level & kitchen equipment
    final equipment = data['kitchen_equipments'];
    final hasEquipment = equipment is List ? equipment.isNotEmpty : equipment != null;
    if (data['cooking_level'] == null || !hasEquipment) return 3;

    // Step 4 — Lifestyle & meal schedule
    if (data['lifestyle_profile_id'] == null || data['meal_schedule'] == null) return 4;

    // Step 5 — Personal info (PII from private/nutrition subcollection,
    // merged into onboardingData by splash before this resolver is called)
    final personal = data['personal_info'] as Map<String, dynamic>?;
    if (personal == null ||
        personal['gender'] == null ||
        personal['birth_date'] == null ||
        personal['height'] == null ||
        personal['weight'] == null) {
      return 5;
    }

    return 0; // all done
  }

  /// True when the user's onboarding data satisfies every required field.
  static bool _isDataComplete(UserModel user) {
    if (!user.onboardingCompleted) return false;
    final data = user.onboardingData;
    if (data == null) return false;

    final goals = data['primary_goals'];
    final hasGoals = goals is List ? goals.isNotEmpty : goals != null;
    final equipment = data['kitchen_equipments'];
    final hasEquipment = equipment is List ? equipment.isNotEmpty : equipment != null;
    final personal = data['personal_info'] as Map<String, dynamic>?;

    return hasGoals &&
        data['activity_level'] != null &&
        data['cooking_level'] != null &&
        hasEquipment &&
        data['meal_schedule'] != null &&
        personal != null &&
        personal['gender'] != null &&
        personal['birth_date'] != null &&
        personal['height'] != null &&
        personal['weight'] != null;
  }
}
