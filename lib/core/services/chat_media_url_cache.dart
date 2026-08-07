import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'crashlytics_service.dart';

/// Faz 5 — resolves a `chat_media/{chatId}/{uid}/{fileName}` BARE storage
/// path into a short-lived signed URL via the `getChatMediaUrl` callable
/// (`functions/chat_media.js`).
///
/// This path exists because `chat_images/{scopeId}/` (the pre-existing,
/// still-used upload path — `StorageUploadService.uploadChatImage`) degrades
/// to "any authenticated user can read" for a GROUP chat: `storage.rules`
/// can't call Firestore to verify real group membership, and a group chat's
/// `scopeId` (the chatId) has no `_` for the participants-pair check to key
/// off. `chat_media/`'s own Storage rule is `allow read: if false` ALWAYS —
/// the only way to ever read one back is this callable, which re-verifies
/// the caller is a real participant/group-member of the owning chat in
/// Firestore before minting a V4 signed URL. See
/// `StorageUploadService.uploadGroupChatMedia` and `ChatAttachmentImage`
/// (the widget that calls this cache at render time).
///
/// In-memory only (ADR-016: session-scoped, cheap to recompute — a resolved
/// URL expires in 24h anyway, so persisting it past one app session buys
/// nothing). A cold restart just re-resolves on first render, exactly like
/// any other cache miss.
class ChatMediaUrlCache {
  static final ChatMediaUrlCache _instance = ChatMediaUrlCache._internal();
  factory ChatMediaUrlCache() => _instance;
  ChatMediaUrlCache._internal();

  final Map<String, ({String url, DateTime expiresAt})> _cache = {};

  // Collapses concurrent resolves of the SAME path (e.g. a message bubble
  // and a media-grid cell rendering the same attachment at once) into one
  // callable invocation rather than one per caller.
  final Map<String, Future<String?>> _inFlight = {};

  // Mirrors the callable's own signed-URL lifetime (functions/chat_media.js
  // — 24h) minus a safety margin, so a cached URL is never handed out right
  // before its real, server-minted signature actually expires.
  static const Duration _signedUrlTtl = Duration(hours: 24);
  static const Duration _safetyMargin = Duration(minutes: 5);

  /// Derives the owning chatId from a `chat_media/{chatId}/{uid}/{fileName}`
  /// path — the path format IS the only chatId this cache (and the DS-layer
  /// widgets that call it) has, since `MessageAttachment`/`AppMessageBubble`
  /// carry no separate chatId field of their own (they render purely off the
  /// message/attachment, chat-agnostic by design). Returns null for anything
  /// not shaped like a `chat_media/` path.
  static String? chatIdFromStoragePath(String storagePath) {
    final parts = storagePath.split('/');
    if (parts.length < 2 || parts[0] != 'chat_media') return null;
    return parts[1];
  }

  /// Resolves [storagePath] (scoped to [chatId], which the callable
  /// re-verifies the caller belongs to) to a renderable URL, or null on
  /// failure — callers treat null exactly like any other broken-image case,
  /// never crash.
  Future<String?> resolve({
    required String chatId,
    required String storagePath,
  }) async {
    final cached = _cache[storagePath];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.url;
    }

    final pending = _inFlight[storagePath];
    if (pending != null) return pending;

    final future = _resolveUncached(chatId: chatId, storagePath: storagePath);
    _inFlight[storagePath] = future;
    try {
      return await future;
    } finally {
      // Map.remove returns the removed Future itself (already resolved by
      // this point, its value already consumed above) — discard it
      // explicitly rather than leaving a bare, unawaited Future-valued
      // expression statement.
      unawaited(_inFlight.remove(storagePath));
    }
  }

  Future<String?> _resolveUncached({
    required String chatId,
    required String storagePath,
  }) async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getChatMediaUrl')
          .call({'chatId': chatId, 'storagePath': storagePath});
      final data = Map<String, dynamic>.from(result.data as Map);
      final url = data['url'] as String?;
      if (url == null || url.isEmpty) return null;
      _cache[storagePath] = (
        url: url,
        expiresAt: DateTime.now().add(_signedUrlTtl - _safetyMargin),
      );
      return url;
    } on FirebaseFunctionsException catch (e, st) {
      debugPrint('ChatMediaUrlCache.resolve error: ${e.code} ${e.message}');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'ChatMediaUrlCache.resolve storagePath=$storagePath'));
      return null;
    } catch (e, st) {
      debugPrint('ChatMediaUrlCache.resolve error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'ChatMediaUrlCache.resolve storagePath=$storagePath'));
      return null;
    }
  }

  /// Test/debug hook — clears every cached entry and any in-flight resolve.
  @visibleForTesting
  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}
