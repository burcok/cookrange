import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/ds/ds.dart';
import 'onboarding_completion.dart';
import 'pages/activity_page.dart';
import 'pages/cooking_page.dart';
import 'pages/dietary_page.dart';
import 'pages/goal_gender_page.dart';
import 'pages/household_page.dart';
import 'pages/lifestyle_page.dart';
import 'pages/metrics_page.dart';
import 'pages/motivation_page.dart';
import 'pages/name_page.dart';
import 'pages/premium_page.dart';
import 'pages/report_page.dart';
import 'pages/target_weight_page.dart';
import 'pages/trust_page.dart';
import 'pages/water_page.dart';
import 'registration_handoff.dart';

/// Host for the V2 (pre-registration) onboarding flow. Owns the [PageController],
/// page order, and forward/back/complete navigation. Each page renders its own
/// [OnboardingScaffold] and gates its own "continue".
class OnboardingFlowScreen extends StatefulWidget {
  /// Route-argument key marking a logged-in onboarding-completion entry into the
  /// flow (an authenticated account finishing onboarding it never completed), as
  /// opposed to the default pre-registration entry. Read by the route builder.
  static const String loggedInCompletionArg = 'logged_in_completion';

  /// Convenience route arguments for [loggedInCompletionArg]. Passed by splash,
  /// the route guard, and verify-email when redirecting an authenticated but
  /// not-yet-onboarded user here.
  static const Map<String, dynamic> loggedInCompletionArgs = {
    loggedInCompletionArg: true,
  };

  /// When true, the flow finalizes against the CURRENT account (persists the
  /// collected profile to the existing uid) instead of handing off to
  /// registration. See [OnboardingCompletion.finalizeAndRoute].
  final bool loggedInCompletion;

  const OnboardingFlowScreen({super.key, this.loggedInCompletion = false});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  final PageController _ctrl = PageController();
  int _index = 0;

  /// Re-entrancy guard for the logged-in completion path (final-page tap).
  bool _completing = false;

  /// One-shot guard so the logged-in prefill below runs only once.
  bool _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Logged-in completion only: hydrate the in-memory provider from the
    // account's partial onboarding data so the user resumes with their prior
    // answers instead of a blank flow.
    if (!widget.loggedInCompletion || _prefilled) return;
    _prefilled = true;
    // Defer the provider mutation out of the build phase. initializeFromFirestore
    // / setFirstName call notifyListeners on the ancestor OnboardingProvider,
    // which during build throws "setState() called during build".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<UserProvider>().user;
      final ob = context.read<OnboardingProvider>();
      final data = user?.onboardingData;
      if (data != null && data.isNotEmpty) {
        ob.initializeFromFirestore(data);
      }
      // Seed the name page from the existing display name when onboarding_data
      // carries no first name of its own.
      final name = user?.displayName;
      if ((ob.firstName == null || ob.firstName!.isEmpty) &&
          name != null &&
          name.isNotEmpty) {
        ob.setFirstName(name);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Widget> _buildPages() {
    const total = 14;
    Widget at(int i, Widget Function(int step) build) => build(i);
    return [
      at(0, (s) => OnboardingNamePage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(1, (s) => OnboardingGoalGenderPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(2, (s) => OnboardingActivityPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(3, (s) => OnboardingMetricsPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(4, (s) => OnboardingTargetWeightPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(5, (s) => OnboardingMotivationPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(6, (s) => OnboardingTrustPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(7, (s) => OnboardingDietaryPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(8, (s) => OnboardingCookingPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(9, (s) => OnboardingLifestylePage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(10, (s) => OnboardingWaterPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(11, (s) => OnboardingHouseholdPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(12, (s) => OnboardingPremiumPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
      at(13, (s) => OnboardingReportPage(
          step: s, totalSteps: total, onNext: _next, onBack: _back)),
    ];
  }

  void _next() {
    if (_index < 13) {
      _ctrl.nextPage(duration: AppMotion.normal, curve: AppMotion.emphasized);
    } else {
      _complete();
    }
  }

  void _back() {
    if (_index > 0) {
      _ctrl.previousPage(
          duration: AppMotion.normal, curve: AppMotion.emphasized);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _complete() {
    if (widget.loggedInCompletion) {
      unawaited(_completeLoggedIn());
    } else {
      // Hand off to registration; account creation persists the collected
      // OnboardingProvider profile (see [OnboardingRegistrationHandoff]).
      OnboardingRegistrationHandoff.go(context);
    }
  }

  /// Finalizes onboarding for an already-authenticated account: persists the
  /// collected profile to the existing uid and routes to plan generation,
  /// instead of creating a new account.
  Future<void> _completeLoggedIn() async {
    if (_completing) return;
    final user = AuthService().currentUser;
    if (user == null) {
      // Session ended unexpectedly — fall back to the registration handoff so
      // the collected profile still has somewhere to land.
      OnboardingRegistrationHandoff.go(context);
      return;
    }
    // Safety gate: each page gates its own field, so this should already hold;
    // it guards against navigation bugs persisting a partial profile.
    if (!context.read<OnboardingProvider>().isV2Complete) return;
    _completing = true;
    await OnboardingCompletion.finalizeAndRoute(context, user: user);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _index > 0) _back();
      },
      child: PageView(
        controller: _ctrl,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (i) => setState(() => _index = i),
        children: pages,
      ),
    );
  }
}
