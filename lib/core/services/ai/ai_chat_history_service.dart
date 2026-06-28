import 'ai_chat_service.dart';

/// In-memory singleton that keeps the AI conversation alive across
/// voice ↔ text transitions. Both VoiceAssistantOverlay and AIChatScreen
/// share the same list so the conversation is seamless.
class AIChatHistoryService {
  AIChatHistoryService._internal();
  static final AIChatHistoryService _instance =
      AIChatHistoryService._internal();
  factory AIChatHistoryService() => _instance;

  final List<AIChatMessage> messages = [];

  void add(AIChatMessage msg) => messages.add(msg);
  void clear() => messages.clear();
}
