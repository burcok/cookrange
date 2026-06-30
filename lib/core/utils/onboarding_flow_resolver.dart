import '../models/user_model.dart';
import 'app_routes.dart';

/// The route the app should navigate to next.
class OnboardingDestination {
  final String route;

  const OnboardingDestination(this.route);
}

/// Pure, synchronous resolver: given an already-loaded [UserModel], returns the
/// next navigation destination. Called by splash after loading the user.
///
/// Decision tree (the user is authenticated by the time this runs — splash
/// handles the logged-out case separately, and the intro carousel is a
/// pre-registration screen, so it is never a destination here):
///   1. No user                          → login
///   2. Onboarding complete & data valid → main
///   3. Otherwise                        → onboardingV2 (logged-in completion)
///
/// In case 3 the V2 flow runs in logged-in mode: it prefills from the account's
/// partial data and persists back to the same uid instead of creating a new
/// account (see `onboarding_flow_screen.dart`).
class OnboardingFlowResolver {
  const OnboardingFlowResolver._();

  /// Returns the [OnboardingDestination] for the given [user].
  static OnboardingDestination resolve(UserModel? user) {
    if (user == null) {
      return const OnboardingDestination(AppRoutes.login);
    }

    if (_isDataComplete(user)) {
      return const OnboardingDestination(AppRoutes.main);
    }

    return const OnboardingDestination(AppRoutes.onboardingV2);
  }

  /// True when the user's onboarding data satisfies every required field.
  static bool _isDataComplete(UserModel user) {
    if (!user.onboardingCompleted) return false;
    final data = user.onboardingData;
    if (data == null) return false;

    final goals = data['primary_goals'];
    final hasGoals = goals is List ? goals.isNotEmpty : goals != null;
    final equipment = data['kitchen_equipments'];
    final hasEquipment =
        equipment is List ? equipment.isNotEmpty : equipment != null;
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
