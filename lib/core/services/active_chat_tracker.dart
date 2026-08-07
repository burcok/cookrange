/// Tracks which chat conversation, if any, is currently the front-most
/// screen — purely in memory, used to suppress a redundant push
/// notification for a chat the user is already looking at (Faz 0 §0.4).
/// `FirebaseMessaging.onMessage` only fires while the app is in the
/// foreground, so "is this chat currently open" is already a sufficient
/// suppression signal on its own — no separate foreground/background flag
/// is needed here.
class ActiveChatTracker {
  static final ActiveChatTracker _instance = ActiveChatTracker._internal();
  factory ActiveChatTracker() => _instance;
  ActiveChatTracker._internal();

  String? _activeChatId;

  /// Call from the chat screen's `initState`.
  void setActive(String chatId) => _activeChatId = chatId;

  /// Call from the chat screen's `dispose`. Guarded by [chatId] so a screen
  /// being popped can never clear a DIFFERENT chat that opened after it
  /// (e.g. a quick back-then-reopen race).
  void clear(String chatId) {
    if (_activeChatId == chatId) _activeChatId = null;
  }

  bool isActive(String chatId) => _activeChatId == chatId;
}
