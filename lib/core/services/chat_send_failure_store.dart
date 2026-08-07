import 'package:flutter/foundation.dart';
import '../models/message_model.dart';

/// A message send Firestore permanently rejected (rules/App Check/
/// invalid-argument) and rolled back from its local cache — it will never
/// reappear via `ChatService.getChatMessages`'s live stream, so this is the
/// only case that needs client-side memory of a failed send at all.
/// Firestore's own offline mutation queue (`persistenceEnabled: true`,
/// `app_initialization_service.dart`) already retries every recoverable
/// network failure automatically, including across an app restart — that
/// path needs no code here.
class PendingSendFailure {
  final String clientId;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String body;
  final List<MessageAttachment> attachments;
  final MessageReplyTo? replyTo;
  final List<MessageMention> mentions;
  final DateTime createdAt;
  final String errorCode;

  const PendingSendFailure({
    required this.clientId,
    required this.chatId,
    required this.senderId,
    required this.type,
    this.body = '',
    this.attachments = const [],
    this.replyTo,
    this.mentions = const [],
    required this.createdAt,
    required this.errorCode,
  });

  /// Renders as an ordinary [MessageModel] so `AppMessageBubble` needs no
  /// special-casing — `sendFailed: true` is the only thing that marks it as
  /// synthetic. `serverTimestamp` is stamped with the local failure time so
  /// it sorts into the timeline at the moment the user actually tried to
  /// send it, not at "now" each time the list rebuilds.
  MessageModel toMessageModel() => MessageModel(
        id: clientId,
        senderId: senderId,
        type: type,
        body: body,
        attachments: attachments,
        replyTo: replyTo,
        mentions: mentions,
        serverTimestamp: createdAt,
        clientId: clientId,
        sendFailed: true,
      );
}

/// Per-chat memory of hard-failed sends, keyed by `clientId` so a retry
/// (same clientId) can supersede its own failure record. Deliberately NOT
/// Hive-persisted: a hard rejection (bad rules/data shape) replays
/// identically on retry, so persisting one across an app restart would only
/// produce a zombie bubble that fails again forever instead of simply
/// disappearing when the user leaves the chat — see `ChatMessageMerge`.
class ChatSendFailureStore {
  static final ChatSendFailureStore _instance =
      ChatSendFailureStore._internal();
  factory ChatSendFailureStore() => _instance;
  ChatSendFailureStore._internal();

  final Map<String, ValueNotifier<List<PendingSendFailure>>> _byChat = {};

  ValueListenable<List<PendingSendFailure>> watch(String chatId) =>
      _notifierFor(chatId);

  ValueNotifier<List<PendingSendFailure>> _notifierFor(String chatId) =>
      _byChat.putIfAbsent(chatId, () => ValueNotifier(const []));

  void add(PendingSendFailure failure) {
    final notifier = _notifierFor(failure.chatId);
    notifier.value = [...notifier.value, failure];
  }

  /// Called once a retry (same clientId) is issued, or the user dismisses
  /// the failed bubble outright.
  void remove(String chatId, String clientId) {
    final notifier = _byChat[chatId];
    if (notifier == null) return;
    notifier.value =
        notifier.value.where((f) => f.clientId != clientId).toList();
  }

  void clearChat(String chatId) => _byChat.remove(chatId);
}
