class WeightLog {
  final DateTime date;
  final double weight;
  final String? note;

  WeightLog({
    required this.date,
    required this.weight,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weight': weight,
        'note': note,
      };

  factory WeightLog.fromJson(Map<String, dynamic> json) => WeightLog(
        date: DateTime.parse(json['date']),
        weight: (json['weight'] as num).toDouble(),
        note: json['note'],
      );
}
