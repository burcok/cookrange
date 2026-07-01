import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/cost_analytics_model.dart';

/// Builds the admin **cost & profit estimate** from the project's own usage.
///
/// Real counts come from cheap Firestore `count()` aggregations; the rest is
/// estimated from [UsageAssumptions] × published unit prices ([FirebasePricing],
/// [OpenRouterPricing], [RevenueAssumptions]). Everything is an ESTIMATE.
class CostAnalyticsService {
  static final CostAnalyticsService _i = CostAnalyticsService._();
  factory CostAnalyticsService() => _i;
  CostAnalyticsService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Gathers live counts and returns the estimated cost/revenue/profit.
  Future<CostAnalytics> compute({
    UsageAssumptions assumptions = const UsageAssumptions(),
  }) async {
    final counts = await _gatherCounts();
    return estimate(counts, assumptions);
  }

  /// Projects the estimate to a hypothetical [targetUsers] (counts scaled
  /// proportionally, premium ratio preserved) — powers the "what-if" simulation.
  CostAnalytics simulateAt(
    int targetUsers,
    CostAnalytics base,
    UsageAssumptions assumptions,
  ) {
    final current = base.counts.totalUsers;
    final factor = current <= 0 ? 0.0 : targetUsers / current;
    final scaled = UsageCounts(
      totalUsers: targetUsers,
      premiumUsers: (base.counts.premiumUsers * factor).round(),
      totalDocuments: (base.counts.totalDocuments * factor).round(),
      docsByCollection: base.counts.docsByCollection
          .map((k, v) => MapEntry(k, (v * factor).round())),
      aiCallsToday: base.counts.aiCallsToday,
      imageObjectsEstimate: (base.counts.imageObjectsEstimate * factor).round(),
    );
    return estimate(scaled, assumptions);
  }

  // ─── Counts (real, via aggregation) ──────────────────────────────────────────

  Future<UsageCounts> _gatherCounts() async {
    final results = await Future.wait([
      _countCol('users'),
      _countQuery(_db.collection('users').where('subscription_tier',
          whereIn: ['premium', 'pro'])),
      _countCol('posts'),
      _countCol('dishes'),
      _countCol('chats'),
      _countGroup('food_logs'),
      _countGroup('food_analyses'),
      _countGroup('messages'),
    ]);
    final users = results[0];
    final premium = results[1];
    final posts = results[2];
    final dishes = results[3];
    final chats = results[4];
    final foodLogs = results[5];
    final foodAnalyses = results[6];
    final messages = results[7];

    final docsByCollection = <String, int>{
      'users': users,
      'posts': posts,
      'dishes': dishes,
      'chats': chats,
      'food_logs': foodLogs,
      'food_analyses': foodAnalyses,
      'messages': messages,
    };
    final totalDocs = docsByCollection.values.fold<int>(0, (a, b) => a + b);
    // Proxy for stored image objects: avatars + post images + analyzed photos.
    final imageObjects = users + posts + foodAnalyses;

    return UsageCounts(
      totalUsers: users,
      premiumUsers: premium,
      totalDocuments: totalDocs,
      docsByCollection: docsByCollection,
      aiCallsToday: 0,
      imageObjectsEstimate: imageObjects,
    );
  }

  Future<int> _countCol(String c) => _countQuery(_db.collection(c));

  Future<int> _countQuery(Query q) async {
    try {
      final snap = await q.count().get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('CostAnalyticsService: count failed: $e');
      return 0;
    }
  }

  Future<int> _countGroup(String c) async {
    try {
      final snap = await _db.collectionGroup(c).count().get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('CostAnalyticsService: group count failed ($c): $e');
      return 0;
    }
  }

  // ─── Estimation engine ───────────────────────────────────────────────────────

  /// Pure estimation (no I/O) — also unit-tested directly.
  static CostAnalytics estimate(UsageCounts c, UsageAssumptions a) {
    final dau = (c.totalUsers * a.dailyActiveFraction).round();

    // Firestore operations (monthly), net of daily free quota.
    final readsMo = dau * a.readsPerActiveUserPerDay * 30;
    final writesMo = dau * a.writesPerActiveUserPerDay * 30;
    final billableReads =
        max(0, readsMo - FirebasePricing.firestoreFreeReadsPerDay * 30);
    final billableWrites =
        max(0, writesMo - FirebasePricing.firestoreFreeWritesPerDay * 30);
    final firestoreOpsCost =
        billableReads / 100000 * FirebasePricing.firestoreReadPer100k +
            billableWrites / 100000 * FirebasePricing.firestoreWritePer100k;

    // Firestore storage.
    final fsGiB = c.totalDocuments * a.avgDocKb / (1024 * 1024);
    final fsStorageCost =
        max(0.0, fsGiB - FirebasePricing.firestoreFreeStorageGiB) *
            FirebasePricing.firestoreStoragePerGiBMonth;

    // Cloud Storage (images) + download egress.
    final imgGB = c.imageObjectsEstimate * a.avgImageKb / (1000 * 1000);
    final storageCost = max(0.0, imgGB - FirebasePricing.storageFreeGB) *
        FirebasePricing.storagePerGBMonth;
    final egressGB = dau * 20 * a.avgImageKb / (1000 * 1000) * 30; // ~20 views/day
    final egressCost = egressGB * FirebasePricing.storageDownloadPerGB;

    // Cloud Functions invocations (AI + chat + notifications proxy).
    final invocationsMo = dau * 10 * 30;
    final fnCost = max(
            0, invocationsMo - FirebasePricing.functionsFreeInvocationsPerMonth) /
        1000000 *
        FirebasePricing.functionsInvocationPerMillion;

    // AI (OpenRouter) — estimated calls × per-call cost (0 on the free model).
    final aiCallsMo = (dau * 1.5 * 30).round();
    final aiCost = aiCallsMo * OpenRouterPricing.costPerCallUsd;

    final lines = <CostLine>[
      CostLine(
          key: 'firestore_ops',
          monthlyUsd: firestoreOpsCost,
          detail: '${_k(readsMo)} reads / ${_k(writesMo)} writes mo'),
      CostLine(
          key: 'firestore_storage',
          monthlyUsd: fsStorageCost,
          detail: '${_k(c.totalDocuments)} docs'),
      CostLine(
          key: 'storage',
          monthlyUsd: storageCost + egressCost,
          detail: '${imgGB.toStringAsFixed(2)} GB + egress'),
      CostLine(
          key: 'functions',
          monthlyUsd: fnCost,
          detail: '${_k(invocationsMo)} calls mo'),
      CostLine(
          key: 'ai',
          monthlyUsd: aiCost,
          detail: '${_k(aiCallsMo)} AI calls mo'),
    ];

    final monthlyCost = lines.fold<double>(0, (s, l) => s + l.monthlyUsd);

    // Revenue (monthly), net of the store cut.
    final gross = c.premiumUsers * RevenueAssumptions.premiumMonthlyPrice;
    final netRevenue = gross * (1 - RevenueAssumptions.storeCutFraction);
    final profit = netRevenue - monthlyCost;

    return CostAnalytics(
      counts: c,
      costLines: lines,
      monthlyCostUsd: monthlyCost,
      monthlyRevenueUsd: netRevenue,
      monthlyProfitUsd: profit,
      arpuUsd: c.totalUsers > 0 ? netRevenue / c.totalUsers : 0,
      costPerUserUsd: c.totalUsers > 0 ? monthlyCost / c.totalUsers : 0,
      assumptions: a,
      generatedAt: DateTime.now(),
    );
  }

  static String _k(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}
