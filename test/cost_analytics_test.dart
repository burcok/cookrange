import 'package:flutter_test/flutter_test.dart';
import 'package:cookrange/core/models/cost_analytics_model.dart';
import 'package:cookrange/core/services/cost_analytics_service.dart';

void main() {
  group('CostAnalyticsService.estimate', () {
    const a = UsageAssumptions();

    test('cost = sum of lines; profit = revenue - cost; ARPU correct', () {
      const counts = UsageCounts(
        totalUsers: 1000,
        premiumUsers: 100,
        totalDocuments: 50000,
        imageObjectsEstimate: 3000,
      );
      final r = CostAnalyticsService.estimate(counts, a);
      final lineSum = r.costLines.fold<double>(0, (s, l) => s + l.monthlyUsd);
      expect((r.monthlyCostUsd - lineSum).abs() < 0.001, true);
      expect(
          (r.monthlyProfitUsd - (r.monthlyRevenueUsd - r.monthlyCostUsd)).abs() <
              0.001,
          true);
      expect((r.arpuUsd - (r.monthlyRevenueUsd / 1000)).abs() < 0.001, true);
      expect(r.costLines.length, 5);
    });

    test('zero users → zero revenue/ARPU, no crash', () {
      const counts =
          UsageCounts(totalUsers: 0, premiumUsers: 0, totalDocuments: 0);
      final r = CostAnalyticsService.estimate(counts, a);
      expect(r.monthlyRevenueUsd, 0);
      expect(r.arpuUsd, 0);
    });

    test('more premium users ⇒ more revenue', () {
      const none =
          UsageCounts(totalUsers: 100, premiumUsers: 0, totalDocuments: 100);
      const some =
          UsageCounts(totalUsers: 100, premiumUsers: 50, totalDocuments: 100);
      expect(
        CostAnalyticsService.estimate(some, a).monthlyRevenueUsd >
            CostAnalyticsService.estimate(none, a).monthlyRevenueUsd,
        true,
      );
    });
  });
}
