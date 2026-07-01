/// Models + pricing constants for the admin **cost & profit estimation**
/// dashboard. Everything here is an ESTIMATE: Firebase does not expose real
/// billing inside the app, so we approximate cost from the project's own usage
/// (document counts, user/premium counts, AI usage) multiplied by published unit
/// prices, with tunable assumptions. Treat figures as directional, not invoices.
///
/// Prices are Blaze-plan approximations (USD) as of 2026 and are CONFIGURABLE —
/// update [FirebasePricing] / [OpenRouterPricing] / [RevenueAssumptions] if your
/// region/plan/prices differ. Free tiers are subtracted before charging.
library;

/// Firebase / GCP Blaze unit prices (USD). Approximate — tune as needed.
class FirebasePricing {
  // Cloud Firestore
  static const double firestoreReadPer100k = 0.06;
  static const double firestoreWritePer100k = 0.18;
  static const double firestoreDeletePer100k = 0.02;
  static const double firestoreStoragePerGiBMonth = 0.18; // after 1 GiB free
  static const double firestoreFreeStorageGiB = 1.0;
  // Daily free quotas (per day): 50k reads, 20k writes, 20k deletes, 1 GiB stored.
  static const int firestoreFreeReadsPerDay = 50000;
  static const int firestoreFreeWritesPerDay = 20000;

  // Cloud Storage
  static const double storagePerGBMonth = 0.026;
  static const double storageDownloadPerGB = 0.12; // network egress
  static const double storageFreeGB = 5.0;

  // Cloud Functions (2nd gen / 1st gen approx)
  static const double functionsInvocationPerMillion = 0.40; // after 2M free
  static const int functionsFreeInvocationsPerMonth = 2000000;

  // Cloud Vision SafeSearch
  static const double visionPer1000 = 1.50; // after 1000/month free
  static const int visionFreePerMonth = 1000;

  // Auth: email/Google/Apple are free up to generous MAU limits → treated as $0.
  static const double authPerUserMonth = 0.0;
}

/// AI provider (OpenRouter) cost assumptions. The default model is free, so the
/// default per-call cost is 0; set [costPerCallUsd] if you use a paid model.
class OpenRouterPricing {
  /// Estimated USD cost per AI generation (1 call). `openrouter/free` ≈ 0.
  static const double costPerCallUsd = 0.0;

  /// Estimated cost per vision (photo) generation if using a paid vision model.
  static const double costPerVisionCallUsd = 0.0;
}

/// Revenue + business assumptions (USD). Tune to your real prices.
class RevenueAssumptions {
  static const double premiumMonthlyPrice = 4.99;
  static const double premiumYearlyPricePerMonth = 3.33; // 39.99/yr ≈ 3.33/mo
  static const double aiCreditsPackPrice = 1.99; // cookrange_ai_credits_10
  /// App Store / Play take a cut. 0.15 = 15% (small-business), 0.30 = standard.
  static const double storeCutFraction = 0.15;
}

/// Tunable usage assumptions for the parts we can't measure directly in-app
/// (Firestore op counts, average image size). Surfaced + editable in the UI.
class UsageAssumptions {
  /// Estimated Firestore reads per active user per day.
  final int readsPerActiveUserPerDay;

  /// Estimated Firestore writes per active user per day.
  final int writesPerActiveUserPerDay;

  /// Average uploaded image size in KB (post/profile/chat photos).
  final double avgImageKb;

  /// Average documents stored per user (rough storage proxy), in KB.
  final double avgDocKb;

  /// Fraction of total users active on a given day (DAU/total).
  final double dailyActiveFraction;

  const UsageAssumptions({
    this.readsPerActiveUserPerDay = 120,
    this.writesPerActiveUserPerDay = 30,
    this.avgImageKb = 250,
    this.avgDocKb = 3,
    this.dailyActiveFraction = 0.35,
  });

  UsageAssumptions copyWith({
    int? readsPerActiveUserPerDay,
    int? writesPerActiveUserPerDay,
    double? avgImageKb,
    double? avgDocKb,
    double? dailyActiveFraction,
  }) {
    return UsageAssumptions(
      readsPerActiveUserPerDay:
          readsPerActiveUserPerDay ?? this.readsPerActiveUserPerDay,
      writesPerActiveUserPerDay:
          writesPerActiveUserPerDay ?? this.writesPerActiveUserPerDay,
      avgImageKb: avgImageKb ?? this.avgImageKb,
      avgDocKb: avgDocKb ?? this.avgDocKb,
      dailyActiveFraction: dailyActiveFraction ?? this.dailyActiveFraction,
    );
  }
}

/// A single named cost line (e.g. "Firestore", "Storage", "AI").
class CostLine {
  final String key; // i18n key suffix, e.g. 'firestore'
  final double monthlyUsd;
  final String detail; // short human-readable basis, e.g. "12.4k docs"

  const CostLine({
    required this.key,
    required this.monthlyUsd,
    this.detail = '',
  });
}

/// Raw, real counts gathered from the project (not estimates).
class UsageCounts {
  final int totalUsers;
  final int premiumUsers;
  final int totalDocuments; // summed across counted collections
  final Map<String, int> docsByCollection;
  final int aiCallsToday; // from server ai_usage counter if present, else 0/est
  final int imageObjectsEstimate; // proxy for stored images

  const UsageCounts({
    required this.totalUsers,
    required this.premiumUsers,
    required this.totalDocuments,
    this.docsByCollection = const {},
    this.aiCallsToday = 0,
    this.imageObjectsEstimate = 0,
  });
}

/// The full estimate the dashboard renders.
class CostAnalytics {
  final UsageCounts counts;
  final List<CostLine> costLines; // Firebase + AI breakdown
  final double monthlyCostUsd; // sum of cost lines
  final double monthlyRevenueUsd; // net of store cut
  final double monthlyProfitUsd; // revenue - cost
  final double arpuUsd; // revenue / total users
  final double costPerUserUsd; // cost / total users
  final UsageAssumptions assumptions;
  final DateTime generatedAt;

  const CostAnalytics({
    required this.counts,
    required this.costLines,
    required this.monthlyCostUsd,
    required this.monthlyRevenueUsd,
    required this.monthlyProfitUsd,
    required this.arpuUsd,
    required this.costPerUserUsd,
    required this.assumptions,
    required this.generatedAt,
  });

  double get marginPercent =>
      monthlyRevenueUsd <= 0 ? 0 : (monthlyProfitUsd / monthlyRevenueUsd) * 100;
}
