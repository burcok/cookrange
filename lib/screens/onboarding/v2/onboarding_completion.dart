import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/utils/app_routes.dart';

/// Shared tail of the V2 onboarding flow, used by BOTH entry points:
///  • new-account registration (`register_screen`), and
///  • logged-in completion of an account whose onboarding was left unfinished
///    (`onboarding_flow_screen`, logged-in mode).
///
/// Persists the in-memory [OnboardingProvider] profile against [user]'s
/// account, schedules the water reminder, repopulates [UserProvider] with the
/// completed model, clears the draft, and routes to AI meal-plan generation.
class OnboardingCompletion {
  OnboardingCompletion._();

  /// While true, [RouteGuard] becomes inert (renders the current child without
  /// redirecting). This closes the race where account creation fires
  /// `authStateChanges` → RouteGuard Section B redirects the register screen to
  /// onboarding BEFORE this slow (Firestore) finalize navigates to plan
  /// generation. Callers set it true *before* `registerWithEmail`; it is cleared
  /// one frame after we navigate. See `docs/roadmap/ONBOARDING_V2.md` §8.
  static bool isFinalizing = false;

  static Future<void> finalizeAndRoute(
    BuildContext context, {
    required User user,
  }) async {
    isFinalizing = true;
    // Capture everything that needs `context` up front — the rest of this
    // method runs across async gaps.
    final ob = context.read<OnboardingProvider>();
    final userProvider = context.read<UserProvider>();
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context);

    // The account already exists by the time we get here — a persistence hiccup
    // must NOT strand the user. Best-effort everything, log failures, always
    // advance to plan generation.
    try {
      // 1. Persist the collected profile (display name + public onboarding_data
      //    + private nutrition + onboarding_completed) against the account.
      await ob.persistV2Profile(user);

      // 2. Carry the premium intent forward for the post-onboarding purchase prompt.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pending_premium_intent', ob.wantsPremiumIntent);

      // 3. Schedule the daily water reminder if the user opted in.
      if (ob.waterReminderEnabled && ob.waterDailyTargetMl != null) {
        final liters = (ob.waterDailyTargetMl! / 1000).toStringAsFixed(1);
        unawaited(PushNotificationService().scheduleDailyWaterReminder(
          title: l10n.translate('water_reminder.notif_title'),
          body: l10n.translate('water_reminder.notif_body',
              variables: {'liters': liters}),
          wakeTime: ob.waterWakeTime,
          sleepTime: ob.waterSleepTime,
        ));
      }

      // 4. Repopulate UserProvider with the completed model. We derive it from
      //    the in-hand state via copyWith (forcing the just-written fields)
      //    rather than re-fetching: persistV2Profile writes through
      //    FirestoreService directly and does NOT invalidate AuthService's
      //    user-data cache, so a getUserData() here could return a stale
      //    onboarding_completed:false model and bounce the user straight back
      //    into onboarding.
      final base =
          userProvider.user ?? await AuthService().getUserData(user.uid);
      if (base != null) {
        final name = ob.firstName;
        final mergedOnboarding = <String, dynamic>{
          ...ob.publicOnboardingData,
          ...ob.privateNutritionData,
        };
        userProvider.setUser(base.copyWith(
          onboardingCompleted: true,
          onboardingData: mergedOnboarding,
          displayName: (name != null && name.isNotEmpty) ? name : null,
        ));
      }

      // 5. Clear the in-memory draft.
      ob.reset();
    } catch (e, s) {
      debugPrint('V2 onboarding finalize error (continuing anyway): $e\n$s');
    }

    // Navigate via the captured navigator (not `context`) so this still works
    // even if the register screen unmounted during the awaits above.
    // Social-auth providers (Google, Apple) already have emailVerified=true →
    // go straight to plan generation. Email-auth accounts need to verify first.
    final destination = user.emailVerified
        ? AppRoutes.mealPlanGeneration
        : AppRoutes.verifyEmail;
    unawaited(navigator.pushNamedAndRemoveUntil(
        destination, (route) => false));

    // Release the guard one frame later, once the generation route has built —
    // by then onboarding_completed:true is in UserProvider, so normal routing
    // (which whitelists plan generation, then allows /main) takes over cleanly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isFinalizing = false;
    });
  }
}
