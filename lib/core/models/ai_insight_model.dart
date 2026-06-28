enum AiInsightType { accountability, riskAlert, projection, tip }

enum AiRiskLevel { none, low, medium, high }

class AiInsightModel {
  final AiInsightType type;
  final AiRiskLevel riskLevel;
  final String message;
  final String? actionLabel;
  final String? actionRoute;
  final List<String> tips;
  final DateTime generatedAt;

  const AiInsightModel({
    required this.type,
    required this.riskLevel,
    required this.message,
    this.actionLabel,
    this.actionRoute,
    this.tips = const [],
    required this.generatedAt,
  });

  factory AiInsightModel.riskCard({
    required AiRiskLevel level,
    required String message,
    String? actionLabel,
  }) =>
      AiInsightModel(
        type: AiInsightType.riskAlert,
        riskLevel: level,
        message: message,
        actionLabel: actionLabel,
        generatedAt: DateTime.now(),
      );

  factory AiInsightModel.fromJson(Map<String, dynamic> json) => AiInsightModel(
        type: AiInsightType.accountability,
        riskLevel: AiRiskLevel.none,
        message: json['message'] as String? ?? '',
        tips: List<String>.from(json['tips'] as List? ?? []),
        generatedAt: DateTime.now(),
      );
}
