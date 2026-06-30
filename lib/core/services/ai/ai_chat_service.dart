import '../../../core/models/user_model.dart';
import 'ai_service.dart';

class AIChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool isLoading;

  const AIChatMessage({
    required this.role,
    required this.content,
    this.isLoading = false,
  });

  AIChatMessage copyWith({String? content, bool? isLoading}) => AIChatMessage(
        role: role,
        content: content ?? this.content,
        isLoading: isLoading ?? this.isLoading,
      );
}

class AIChatService {
  static final AIChatService _instance = AIChatService._internal();
  factory AIChatService() => _instance;
  AIChatService._internal();

  final AIService _ai = AIService();

  String _buildSystemPrompt(UserModel user) {
    final p = user.profile;
    final goals = p.primaryGoals.isNotEmpty
        ? p.primaryGoals.join(', ')
        : 'maintain health';
    final restrictions = [...p.allergyIds, ...p.dietaryRestrictionIds];
    final restrictionStr =
        restrictions.isNotEmpty ? restrictions.join(', ') : 'none';
    final dislikes =
        p.dislikedFoodKeys.isNotEmpty ? p.dislikedFoodKeys.join(', ') : 'none';

    return '''You are a friendly AI nutrition assistant for Cookrange.
You help users with meal advice, nutrition questions, and healthy eating guidance.

User profile:
- Goals: $goals
- Activity level: ${p.activityLevel}
- Dietary restrictions & allergies: $restrictionStr
- Dislikes: $dislikes
- Calorie target: ~${p.heightCm != null && p.weightKg != null ? "calculated based on profile" : "unknown"}

Rules:
- Give practical, personalized advice based on their profile.
- Keep responses concise (2–4 sentences unless more detail is requested).
- Be warm, encouraging, and helpful.
- If asked about dishes, suggest options compatible with their restrictions.
- Never recommend anything that conflicts with their allergies or dietary restrictions.
- Respond in the same language the user writes in (English or Turkish).''';
  }

  Future<String> sendMessage({
    required UserModel user,
    required List<AIChatMessage> history,
    required String userMessage,
  }) async {
    final systemPrompt = _buildSystemPrompt(user);

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...history
          .where((m) => !m.isLoading)
          .map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    return _ai.generateChatResponse(messages: messages);
  }
}
