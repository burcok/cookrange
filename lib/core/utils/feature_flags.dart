import 'package:firebase_auth/firebase_auth.dart';
import '../services/app_config_service.dart';

/// Thin convenience wrapper around [AppConfigService.isAvailable] for UI
/// entry points (menu items, quick actions, discovery cards) that need to
/// hide themselves when a feature is kill-switched or the current user
/// isn't in its gradual-rollout bucket.
///
/// Audit N2: `isFeatureEnabled`/`isInRollout` were written but had zero
/// callers anywhere in the app — gym (13 screens), coach (8), programs (3)
/// and squad were always fully live regardless of the admin panel's
/// toggles. This is the single choke point every entry point now goes
/// through; it resolves the current uid from FirebaseAuth so call sites
/// don't have to plumb it through themselves.
///
/// Deliberately entry-point-level, not screen-level: these four domains are
/// reached via direct widget pushes (`onPush(const GymDashboardScreen())`),
/// not named routes, so `RouteGuard` (which keys off `ModalRoute` route
/// names) can't gate them — hiding the tappable entry point is the actual
/// choke point for how users reach these screens today.
class FeatureFlags {
  FeatureFlags._();

  static bool isEnabled(String feature) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return AppConfigService().isAvailable(feature, uid: uid);
  }

  // Canonical keys — also registered in admin_app_config_screen.dart's
  // `_featureKeys` so admins can toggle them from the panel.
  static const gym = 'gym';
  static const coach = 'coach';
  static const programs = 'programs';
  static const squad = 'squad';

  /// Faz 3 §3.3 — the meal-plan template builder/library. A dedicated
  /// kill-switch independent of `gym`/`coach` themselves: those gate
  /// reaching the dashboards at all, this lets a rollout problem specific
  /// to template generation (e.g. the AI-draft path) be killed without
  /// taking down the whole coach/gym dashboard.
  static const mealPlanTemplates = 'meal_plan_templates';

  /// Faz 6 §6.1 — gym invite-code generation/QR/poster export. Same reason
  /// as `mealPlanTemplates`: a problem specific to this surface (e.g. the
  /// poster image-capture path) shouldn't require killing the whole gym
  /// dashboard to shut off.
  static const gymInviteCodes = 'gym_invite_codes';

  /// Faz 6 §6.5/§6.6 — the attribution funnel stats on
  /// `GymInviteCodesScreen` and the new `GymEarningsScreen`. A dedicated
  /// kill-switch, not folded into `gymInviteCodes`: code generation/QR/
  /// poster export already shipped and is independently verified — a
  /// problem in the newer, more complex attribution/commission surface
  /// shouldn't require killing the already-working invite-code feature to
  /// shut off.
  static const gymAttribution = 'gym_attribution';
}
