import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  // Get all chats for a user, sorted by update time
  Stream<List<ChatModel>> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatModel.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  // Combined stream for chats + online status
  Stream<List<ChatModel>> getUserChatsWithStatus(String userId) {
    final controller = StreamController<List<ChatModel>>();
    List<ChatModel> lastChats = [];
    Map<String, Map<String, dynamic>> userDataMap =
        {}; // Changed to store full user data
    StreamSubscription? chatsSub;
    StreamSubscription? usersSub;

    void emit() {
      if (controller.isClosed) return;
      final updatedChats = lastChats.map((chat) {
        if (chat.type == ChatType.private) {
          final otherId = chat.participants
              .firstWhere((p) => p != userId, orElse: () => '');
          if (otherId.isNotEmpty && userDataMap.containsKey(otherId)) {
            final userData = userDataMap[otherId]!;
            final newMetadata = Map<String, dynamic>.from(chat.metadata ?? {});

            // Online Status Verification Logic
            final bool isOnlineFlag = userData['is_online'] ?? false;
            final Timestamp? lastActiveTs =
                userData['last_active_at'] as Timestamp?;
            final DateTime? lastActiveAt = lastActiveTs?.toDate();

            bool isActuallyOnline = false;
            if (isOnlineFlag) {
              if (lastActiveAt != null) {
                final difference = DateTime.now().difference(lastActiveAt);
                // 2 minutes threshold for faster stale detection
                if (difference.inMinutes < 2) {
                  isActuallyOnline = true;
                }
              } else {
                // If online but no timestamp (legacy?), assume online or decide strict
                // Let's assume offline to be safe against ghost sessions
                isActuallyOnline = false;
              }
            }

            newMetadata['is_online'] = isActuallyOnline;

            return chat.copyWith(
              name: userData['displayName'],
              image: userData['photoURL'],
              metadata: newMetadata,
            );
          }
        }
        return chat;
      }).toList();
      controller.add(updatedChats);
    }

    chatsSub = getUserChats(userId).listen((chats) {
      lastChats = chats;
      // Identify users to watch
      final userIdsToWatch = chats
          .where((c) => c.type == ChatType.private)
          .expand((c) => c.participants)
          .where((p) => p != userId)
          .toSet()
          .take(10) // Limit to 10 for whereIn query constraint
          .toList();

      if (userIdsToWatch.isEmpty) {
        emit();
        return;
      }

      usersSub?.cancel();
      usersSub = _firestore
          .collection('users')
          .where(FieldPath.documentId, whereIn: userIdsToWatch)
          .snapshots()
          .listen((snapshot) {
        for (var doc in snapshot.docs) {
          userDataMap[doc.id] = doc.data();
        }
        emit();
      });

      // Emit initial data immediately in case user status takes time
      emit();
    });

    controller.onCancel = () {
      chatsSub?.cancel();
      usersSub?.cancel();
    };

    return controller.stream;
  }

  // Get messages for a specific chat
  Stream<List<MessageModel>> getChatMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromJson(doc.data()))
          .toList();
    });
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String text,
    MessageType type = MessageType.text,
  }) async {
    final messageId = _uuid.v4();
    final timestamp = DateTime.now();

    final message = MessageModel(
      id: messageId,
      senderId: senderId,
      text: text,
      type: type,
      timestamp: timestamp,
      isRead: false,
    );

    final chatRef = _firestore.collection('chats').doc(chatId);

    // Run as transaction to ensure consistency
    await _firestore.runTransaction((transaction) async {
      final chatDoc = await transaction.get(chatRef);
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participants']);
      final unreadCounts = Map<String, dynamic>.from(chatData['unreadCounts']);

      // Increment unread counts for other participants
      for (var participantId in participants) {
        if (participantId != senderId) {
          unreadCounts[participantId] = (unreadCounts[participantId] ?? 0) + 1;
        }
      }

      // Add message to subcollection
      final messageRef = chatRef.collection('messages').doc(messageId);
      transaction.set(messageRef, message.toJson());

      // Update chat document
      transaction.update(chatRef, {
        'lastMessage': message.toJson(),
        'updatedAt': Timestamp.fromDate(timestamp),
        'unreadCounts': unreadCounts,
      });
    });
  }

  // Mark chat as read for a user
  Future<void> markChatAsRead(String chatId, String userId) async {
    final chatRef = _firestore.collection('chats').doc(chatId);

    // 1. Reset unread count for this user and update lastMessage.isRead
    await _firestore.runTransaction((transaction) async {
      final chatDoc = await transaction.get(chatRef);
      if (!chatDoc.exists) return;

      final chatData = chatDoc.data()!;
      final unreadCounts =
          Map<String, dynamic>.from(chatData['unreadCounts'] ?? {});

      final Map<String, dynamic> updates = {};

      if (unreadCounts[userId] != 0) {
        unreadCounts[userId] = 0;
        updates['unreadCounts'] = unreadCounts;
      }

      // Also mark lastMessage as read if it wasn't sent by current user
      final lastMessage = chatData['lastMessage'] as Map<String, dynamic>?;
      if (lastMessage != null &&
          lastMessage['senderId'] != userId &&
          lastMessage['isRead'] != true) {
        updates['lastMessage.isRead'] = true;
      }

      if (updates.isNotEmpty) {
        transaction.update(chatRef, updates);
      }
    });

    // 2. Mark messages as read (Batch update)
    // We only want to mark messages NOT sent by current user as read
    final unreadMessagesQuery = await chatRef
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .get();

    if (unreadMessagesQuery.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (var doc in unreadMessagesQuery.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    }
  }

  // Set typing status
  Future<void> setTypingStatus(
      String chatId, String userId, bool isTyping) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    await chatRef.update({
      'typingUsers.$userId': isTyping,
    });
  }

  // Get single chat stream
  Stream<ChatModel> getChat(String chatId) {
    return _firestore.collection('chats').doc(chatId).snapshots().map((doc) {
      if (!doc.exists) throw Exception("Chat not found");
      return ChatModel.fromJson(doc.data()!, doc.id);
    });
  }

  // Create or get existing private chat
  Future<String> createOrGetPrivateChat(
      String currentUserId, String otherUserId) async {
    // Ideally, we might want to query if a chat already exists between these two.
    // However, Firestore doesn't support easy "exact array equality" queries.
    // A common pattern is to store a unique ID generated from sorted user IDs.
    // Or we can just query chats containing currentUserId and filter client-side (costly if many chats).

    // For now, simpler approach: Query chats where 'participants' contains currentUserId
    // Then filter for the one that also has otherUserId and size is 2.

    final querySnapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUserId)
        .get();

    for (var doc in querySnapshot.docs) {
      final List<dynamic> participants = doc.data()['participants'];
      if (participants.length == 2 && participants.contains(otherUserId)) {
        return doc.id;
      }
    }

    // Create new chat
    final newChatId = _uuid.v4();
    final now = DateTime.now();

    final newChat = ChatModel(
      id: newChatId,
      participants: [currentUserId, otherUserId],
      unreadCounts: {currentUserId: 0, otherUserId: 0},
      type: ChatType.private,
      updatedAt: now,
    );

    await _firestore.collection('chats').doc(newChatId).set(newChat.toJson());
    return newChatId;
  }

  /// Stream of total unread message count across all chats
  Stream<int> getUnreadMessageCountStream(String userId) {
    return getUserChats(userId).map((chats) {
      return chats.fold<int>(
          0, (sum, chat) => sum + (chat.unreadCounts[userId] ?? 0));
    });
  }

  /// Preload chats to warm up cache
  Future<void> preloadChats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .orderBy('updatedAt', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Ignore
    }
  }
}
