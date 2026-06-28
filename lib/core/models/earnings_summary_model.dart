class EarningsSummaryModel {
  final double totalEarned;
  final double pendingAmount;
  final double paidAmount;
  final int referralCount;
  final int coachSessionCount;

  const EarningsSummaryModel({
    required this.totalEarned,
    required this.pendingAmount,
    required this.paidAmount,
    required this.referralCount,
    required this.coachSessionCount,
  });

  static const empty = EarningsSummaryModel(
    totalEarned: 0,
    pendingAmount: 0,
    paidAmount: 0,
    referralCount: 0,
    coachSessionCount: 0,
  );
}
