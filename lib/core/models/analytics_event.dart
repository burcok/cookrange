class AnalyticsEvent {
  final String name;
  final Map<String, Object> parameters;
  final String timestamp;

  AnalyticsEvent({
    required this.name,
    required this.parameters,
  }) : timestamp = DateTime.now().toIso8601String();

  Map<String, Object> toMap() {
    return {
      'name': name,
      'parameters': parameters,
      'timestamp': timestamp,
    };
  }

  factory AnalyticsEvent.fromMap(Map<dynamic, dynamic> map) {
    return AnalyticsEvent(
      name: map['name'] as String,
      parameters: Map<String, Object>.from(
        (map['parameters'] as Map).map(
          (key, value) => MapEntry(key.toString(), value as Object),
        ),
      ),
    );
  }
}
