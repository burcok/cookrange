/// Subscription tier for a user account.
enum SubscriptionTier {
  free,
  premium,
  pro;

  static SubscriptionTier fromString(String? value) {
    switch (value) {
      case 'premium':
        return SubscriptionTier.premium;
      case 'pro':
        return SubscriptionTier.pro;
      default:
        return SubscriptionTier.free;
    }
  }

  String get id => name;

  bool get isPaid => this != SubscriptionTier.free;
  bool get isPremiumOrAbove =>
      this == SubscriptionTier.premium || this == SubscriptionTier.pro;
  bool get isPro => this == SubscriptionTier.pro;
}

/// Typed entitlements derived from subscription tier.
///
/// Add new feature flags here as needed. The defaults encode the free-tier
/// limits so call sites never need to null-check.
class Entitlements {
  final SubscriptionTier tier;

  const Entitlements(this.tier);

  static const Entitlements free = Entitlements(SubscriptionTier.free);

  // ─── Meal planning ────────────────────────────────────────────────────────
  /// Number of AI meal-plan generations allowed per week.
  int get weeklyMealPlanGenerations => switch (tier) {
        SubscriptionTier.free => 2,
        SubscriptionTier.premium => 10,
        SubscriptionTier.pro => 999,
      };

  // ─── AI features ──────────────────────────────────────────────────────────
  /// Number of AI chat messages allowed per day.
  int get dailyAIChatMessages => switch (tier) {
        SubscriptionTier.free => 10,
        SubscriptionTier.premium => 50,
        SubscriptionTier.pro => 999,
      };

  bool get advancedAIAnalysis => tier.isPremiumOrAbove;

  // ─── Analytics ────────────────────────────────────────────────────────────
  bool get nutritionAnalytics => true; // free feature
  bool get advancedTrends => tier.isPremiumOrAbove;

  // ─── Community ────────────────────────────────────────────────────────────
  /// Faz 5 §5.4: this getter predates Faz 2 (K5/K8), which shipped group
  /// chat as a core, free-for-everyone retention feature ("WhatsApp seviyesi
  /// sohbet") — `community_groups`' paired chat doc has no tier check
  /// anywhere (`CommunityGroupService`/`firestore.rules`' `canAccessGroupChat()`
  /// gate on membership only). Gating basic group-chat access behind
  /// `premiumOrAbove` now would revoke something every free member already
  /// has — a regression, not a paywall. Corrected to match shipped reality
  /// (`docs/PREMIUM.md` §1: "Community, chat, streaks, achievements ✅ ✅")
  /// rather than left at its stale, never-wired original value.
  bool get groupChat => true;
  bool get verifiedBadge => tier.isPro;

  // ─── Export ───────────────────────────────────────────────────────────────
  bool get exportData => tier.isPremiumOrAbove;
}
