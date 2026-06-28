import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/community_post.dart';
import '../models/notification_model.dart';
import 'analytics_service.dart';
import 'log_service.dart';
import 'notification_service.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logger = LogService();

  String get currentUserId => _auth.currentUser?.uid ?? 'guest';

  // --- Helpers ---

  String get _currentUserId => _auth.currentUser?.uid ?? 'guest';

  Future<CommunityUser> _getCurrentCommunityUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      return CommunityUser(
        id: user.uid,
        name: user.displayName ?? 'User',
        avatarUrl: user.photoURL ??
            'https://i.pravatar.cc/150?u=${user.uid}', // Fallback
      );
    }
    // Fallback for guest
    return CommunityUser(
      id: 'guest',
      name: 'Guest User',
      avatarUrl: 'https://i.pravatar.cc/150?u=guest',
    );
  }

  // --- Posts ---

  // --- Posts ---

  /// [authorIds] — restrict to posts from these user IDs (Friends filter; max 30).
  /// [gymOnly] — restrict to posts tagged with gym-related tags.
  /// Automatically filters out posts from blocked users (client-side).
  Stream<List<CommunityPost>> getPostsStream({
    int limit = 20,
    List<String>? authorIds,
    bool gymOnly = false,
  }) async* {
    final blockedIds = await getBlockedIds();
    final userId = _currentUserId;

    Query<Map<String, dynamic>> query = _firestore.collection('posts');

    if (authorIds != null && authorIds.isNotEmpty) {
      query = query.where('authorId', whereIn: authorIds.take(30).toList());
    } else if (gymOnly) {
      query = query.where('tags',
          arrayContainsAny: ['gym', 'fitness', 'workout', 'training', 'crossfit', 'powerlifting']);
    }

    yield* query
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) =>
                CommunityPost.fromMap(doc.data(), doc.id, currentUserId: userId))
            .where((p) => !blockedIds.contains(p.author.id))
            .toList());
  }

  Future<List<CommunityPost>> getPosts({int limit = 10}) async {
    try {
      final userId = _currentUserId;
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      final posts = snapshot.docs
          .map((doc) =>
              CommunityPost.fromMap(doc.data(), doc.id, currentUserId: userId))
          .toList();

      return posts;
    } catch (e) {
      debugPrint("Error fetching posts: $e");
      return [];
    }
  }

  /// Cursor-based pagination. Returns posts and the last document for the next page.
  /// Pass the same [authorIds]/[gymOnly] as the active stream filter.
  Future<({List<CommunityPost> posts, DocumentSnapshot? lastDoc})>
      fetchPostsPage({
    int limit = 20,
    DocumentSnapshot? startAfter,
    List<String>? authorIds,
    bool gymOnly = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('posts');

      if (authorIds != null && authorIds.isNotEmpty) {
        query = query.where('authorId', whereIn: authorIds.take(30).toList());
      } else if (gymOnly) {
        query = query.where('tags',
            arrayContainsAny: ['gym', 'fitness', 'workout', 'training', 'crossfit', 'powerlifting']);
      }

      query = query.orderBy('timestamp', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final userId = _currentUserId;
      final blockedIds = await getBlockedIds();
      final posts = snapshot.docs
          .map((doc) =>
              CommunityPost.fromMap(doc.data(), doc.id, currentUserId: userId))
          .where((p) => !blockedIds.contains(p.author.id))
          .toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return (posts: posts, lastDoc: lastDoc);
    } catch (e) {
      _logger.error('fetchPostsPage failed', error: e);
      return (posts: <CommunityPost>[], lastDoc: null);
    }
  }

  Future<void> createPost(
      String content, List<String> imageUrls, List<String> tags) async {
    final user = await _getCurrentCommunityUser();

    final newPost = CommunityPost(
      id: '', // Firestore will gen
      author: user,
      content: content,
      imageUrls: imageUrls,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      timestamp: DateTime.now(),
      tags: tags,
    );

    final docRef = await _firestore.collection('posts').add({
      ...newPost.toMap(),
      'authorId': user.id, // top-level for filter queries (authorId + timestamp index)
      'likedUserIds': [],
      'commentsCount': 0,
      'likesCount': 0,
    });

    await _logger.logActivity('post_create', {
      'post_id': docRef.id,
      'content_length': content.length,
      'has_images': imageUrls.isNotEmpty,
      'tags': tags,
    });
    unawaited(AnalyticsService().logEvent(
      name: 'post_created',
      parameters: {
        'has_images': imageUrls.isNotEmpty,
        'tag_count': tags.length,
      },
    ));
  }

  Future<void> updatePost(String postId, String newContent,
      {List<String>? newTags}) async {
    final uid = currentUserId;
    if (uid.isEmpty) throw Exception("User not authenticated");

    // Firestore rules should enforce ownership, but good to check/handle error
    final Map<String, dynamic> updates = {
      'content': newContent,
      'isEdited': true,
    };
    if (newTags != null) {
      updates['tags'] = newTags;
    }

    await _firestore.collection('posts').doc(postId).update(updates);

    await _logger.logActivity('post_update', {
      'post_id': postId,
      'new_content_len': newContent.length,
      if (newTags != null) 'tags_count': newTags.length,
    });
  }

  Future<CommunityPost?> getPostDetails(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final userId = _currentUserId;

      // Fetch user's reactions
      if (userId != 'guest') {
        final reactionDoc = await _firestore
            .collection('posts')
            .doc(postId)
            .collection('reactions')
            .doc(userId)
            .get();

        if (reactionDoc.exists) {
          final rData = reactionDoc.data();
          if (rData != null) {
            if (rData['emojis'] != null) {
              data['userReactions'] = List<String>.from(rData['emojis']);
            } else if (rData['emoji'] != null) {
              // Migration/Fallback for single emoji
              data['userReactions'] = [rData['emoji']];
            }
          }
        }
      }

      return CommunityPost.fromMap(data, doc.id, currentUserId: _currentUserId);
    } catch (e) {
      debugPrint("Error fetching post details: $e");
      return null;
    }
  }

  // --- Interactions ---

  Future<bool> deletePost(String postId) async {
    final userId = _currentUserId;
    if (userId == 'guest') return false;

    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return false;

      // Verify owner
      final authorId = (postDoc.data() as Map<String, dynamic>)['author']['id'];
      if (authorId != userId) return false;

      final postRef = _firestore.collection('posts').doc(postId);

      // Client-side subcollection cleanup (best-effort; Cloud Function handles edge cases)
      final batch = _firestore.batch();

      // Delete top-level likes and reactions
      for (final sub in ['likes', 'reactions']) {
        final snap = await postRef.collection(sub).get();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
      }

      // Delete comments + each comment's likes
      final commentsSnap = await postRef.collection('comments').get();
      for (final commentDoc in commentsSnap.docs) {
        final commentLikesSnap =
            await commentDoc.reference.collection('likes').get();
        for (final likeDoc in commentLikesSnap.docs) {
          batch.delete(likeDoc.reference);
        }
        batch.delete(commentDoc.reference);
      }

      batch.delete(postRef);
      await batch.commit();

      await _logger.logActivity('post_delete', {
        'post_id': postId,
      });

      return true;
    } catch (e) {
      debugPrint("Error deleting post: $e");
      return false;
    }
  }

  Future<bool> likePost(String postId) async {
    final userId = _currentUserId;
    if (userId == 'guest') return false;

    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    String? authorId;

    final liked = await _firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) return false;

      final pData = postDoc.data();
      authorId = (pData?['author'] as Map<String, dynamic>?)?['id'] as String?;

      List<dynamic> recentLikers = [];
      if (pData != null && pData.containsKey('recentLikers')) {
        recentLikers = List.from(pData['recentLikers']);
      }

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        recentLikers.removeWhere((item) => item['id'] == userId);
        transaction.update(postRef, {
          'likesCount': FieldValue.increment(-1),
          'likedUserIds': FieldValue.arrayRemove([userId]),
          'recentLikers': recentLikers,
        });
        return false;
      } else {
        // Like
        final user = await _getCurrentCommunityUser();
        final userMap = user.toMap();

        recentLikers.removeWhere((item) => item['id'] == userId);
        recentLikers.insert(0, userMap);
        if (recentLikers.length > 3) {
          recentLikers = recentLikers.sublist(0, 3);
        }

        transaction.set(likeRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'userId': userId,
          'userName': user.name,
          'userAvatar': user.avatarUrl,
        });
        transaction.update(postRef, {
          'likesCount': FieldValue.increment(1),
          'likedUserIds': FieldValue.arrayUnion([userId]),
          'recentLikers': recentLikers,
        });
        return true;
      }
    });

    if (liked) {
      unawaited(_logger.logActivity('post_like', {'post_id': postId}));
    } else {
      unawaited(_logger.logActivity('post_unlike', {'post_id': postId}));
    }

    // Notification fan-out (skip self-like)
    final aid = authorId;
    if (aid != null && aid != userId) {
      final ns = NotificationService();
      if (liked) {
        unawaited(ns.sendNotification(
          targetUserId: aid,
          type: NotificationType.likePost,
          actorUid: userId,
          actorName: _auth.currentUser?.displayName,
          actorPhotoUrl: _auth.currentUser?.photoURL,
          relatedId: postId,
        ));
      } else {
        unawaited(ns.deleteNotificationByRelatedId(
          targetUserId: aid,
          relatedId: postId,
          type: NotificationType.likePost,
        ));
      }
    }

    return liked;
  }

  Future<bool> likeComment(String postId, String commentId) async {
    final userId = _currentUserId;
    if (userId == 'guest') return false;

    final commentRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);
    final likeRef = commentRef.collection('likes').doc(userId);

    String? commentAuthorId;

    final liked = await _firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);
      final commentDoc = await transaction.get(commentRef);

      if (!commentDoc.exists) return false;

      final cData = commentDoc.data();
      commentAuthorId =
          (cData?['author'] as Map<String, dynamic>?)?['id'] as String?;

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        transaction.update(commentRef, {'likesCount': FieldValue.increment(-1)});
        return false;
      } else {
        // Like
        final user = await _getCurrentCommunityUser();
        transaction.set(likeRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'userId': userId,
          'userName': user.name,
          'userAvatar': user.avatarUrl,
        });
        transaction.update(commentRef, {'likesCount': FieldValue.increment(1)});
        return true;
      }
    });

    if (liked) {
      unawaited(_logger.logActivity('comment_like', {'post_id': postId, 'comment_id': commentId}));
    } else {
      unawaited(_logger.logActivity('comment_unlike', {'post_id': postId, 'comment_id': commentId}));
    }

    // Notification fan-out (skip self-like)
    final aid = commentAuthorId;
    if (aid != null && aid != userId) {
      final ns = NotificationService();
      final relatedId = '${commentId}_like';
      if (liked) {
        unawaited(ns.sendNotification(
          targetUserId: aid,
          type: NotificationType.likeComment,
          actorUid: userId,
          actorName: _auth.currentUser?.displayName,
          actorPhotoUrl: _auth.currentUser?.photoURL,
          relatedId: relatedId,
          metadata: {'postId': postId, 'commentId': commentId},
        ));
      } else {
        unawaited(ns.deleteNotificationByRelatedId(
          targetUserId: aid,
          relatedId: relatedId,
          type: NotificationType.likeComment,
        ));
      }
    }

    return liked;
  }

  Future<CommunityComment> addComment(String postId, String content) async {
    final user = await _getCurrentCommunityUser();

    final commentRef =
        _firestore.collection('posts').doc(postId).collection('comments').doc();

    final newComment = CommunityComment(
      id: commentRef.id,
      author: user,
      content: content,
      timestamp: DateTime.now(),
    );

    final batch = _firestore.batch();
    batch.set(commentRef, newComment.toMap());
    batch.update(_firestore.collection('posts').doc(postId),
        {'commentsCount': FieldValue.increment(1)});

    await batch.commit();

    await _logger.logActivity('comment_add', {
      'post_id': postId,
      'comment_id': commentRef.id,
      'content_len': content.length,
    });

    // Notify post author (fire-and-forget)
    unawaited(_sendCommentNotification(postId, user));

    return newComment;
  }

  Future<void> _sendCommentNotification(
      String postId, CommunityUser commenter) async {
    try {
      final postSnap =
          await _firestore.collection('posts').doc(postId).get();
      if (!postSnap.exists) return;
      final authorId = (postSnap.data()?['author'] as Map<String, dynamic>?)?[
          'id'] as String?;
      final myId = _currentUserId;
      if (authorId == null || authorId == myId) return;
      await NotificationService().sendNotification(
        targetUserId: authorId,
        type: NotificationType.comment,
        actorUid: commenter.id,
        actorName: commenter.name,
        actorPhotoUrl: commenter.avatarUrl,
        relatedId: postId,
      );
    } catch (e) {
      _logger.error('_sendCommentNotification failed', error: e);
    }
  }

  /// Real-time stream of comments for [postId], ordered oldest-first.
  ///
  /// Reaction sub-reads are skipped here to keep the stream fast; they are
  /// fetched on demand when the user interacts with a specific comment.
  Stream<List<CommunityComment>> commentsStream(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => CommunityComment.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((Object e) {
      debugPrint('commentsStream error: $e');
      return <CommunityComment>[];
    });
  }

  /// Cursor-based page of comments (newest-first). Pass [startAfter] from the
  /// last doc in the previous page to continue pagination.
  Future<({List<CommunityComment> items, DocumentSnapshot? lastDoc})>
      getCommentsPage(
    String postId, {
    DocumentSnapshot? startAfter,
    int limit = 20,
  }) async {
    try {
      var query = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .limit(limit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snap = await query.get();
      final items = snap.docs
          .map((d) => CommunityComment.fromMap(d.data(), d.id))
          .toList();
      return (items: items, lastDoc: snap.docs.isNotEmpty ? snap.docs.last : null);
    } catch (e) {
      debugPrint('getCommentsPage error: $e');
      return (items: <CommunityComment>[], lastDoc: null);
    }
  }

  Future<List<CommunityComment>> getComments(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      final userId = _currentUserId;
      List<CommunityComment> comments = [];

      // Note: fetching user reaction for EACH comment is N+1 reads.
      // Optimization: Fetch all reactions for this user in this post context if structured that way.
      // Or just accept it for now as comments are limited (or pagination limits it).

      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (userId != 'guest') {
          final reactionDoc =
              await doc.reference.collection('reactions').doc(userId).get();
          if (reactionDoc.exists && reactionDoc.data() != null) {
            final rData = reactionDoc.data()!;
            if (rData['emojis'] != null) {
              data['userReactions'] = List<String>.from(rData['emojis']);
            } else if (rData['emoji'] != null) {
              data['userReactions'] = [rData['emoji']];
            }
          }
        }
        comments.add(CommunityComment.fromMap(data, doc.id));
      }

      return comments;
    } catch (e) {
      debugPrint("Error fetching comments: $e");
      return [];
    }
  }

  Future<void> updateComment(
      String postId, String commentId, String newContent) async {
    final uid = currentUserId;
    if (uid.isEmpty) return;

    await _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'content': newContent,
      'isEdited': true,
    });

    await _logger.logActivity('comment_update', {
      'post_id': postId,
      'comment_id': commentId,
    });
  }

  Future<bool> deleteComment(String postId, String commentId) async {
    try {
      final uid = currentUserId;
      if (uid.isEmpty) return false;

      // Note: Ideally verify ownership before delete
      await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .delete();

      // Decrement comment count
      await _firestore.collection('posts').doc(postId).update({
        'commentsCount': FieldValue.increment(-1),
      });

      await _logger.logActivity('comment_delete', {
        'post_id': postId,
        'comment_id': commentId,
      });

      return true;
    } catch (e) {
      debugPrint("Error deleting comment: $e");
      return false;
    }
  }

  /// Toggles a reaction on a post or comment.
  /// If [commentId] is null, it's a post reaction.
  /// Toggles a reaction on a post or comment.
  /// If [commentId] is null, it's a post reaction.
  Future<void> toggleReaction({
    required String postId,
    String? commentId,
    required String emoji,
  }) async {
    final userId = _currentUserId;
    if (userId == 'guest') return;

    final DocumentReference docRef = commentId == null
        ? _firestore.collection('posts').doc(postId)
        : _firestore
            .collection('posts')
            .doc(postId)
            .collection('comments')
            .doc(commentId);

    final reactionRef = docRef.collection('reactions').doc(userId);

    String? authorId;
    bool reactionAdded = false;

    await _firestore.runTransaction((transaction) async {
      final reactionDoc = await transaction.get(reactionRef);
      final parentDoc = await transaction.get(docRef);

      if (!parentDoc.exists) return;

      final pData = parentDoc.data() as Map<String, dynamic>?;
      authorId = (pData?['author'] as Map<String, dynamic>?)?['id'] as String?;

      Map<String, int> currentCounts = {};
      if (pData != null && pData.containsKey('reactions')) {
        currentCounts = Map<String, int>.from(pData['reactions']);
      }

      List<String> userEmojis = [];
      if (reactionDoc.exists && reactionDoc.data() != null) {
        final rData = reactionDoc.data() as Map<String, dynamic>;
        if (rData['emojis'] != null) {
          userEmojis = List<String>.from(rData['emojis']);
        } else if (rData['emoji'] != null) {
          userEmojis = [rData['emoji']];
        }
      }

      if (userEmojis.contains(emoji)) {
        // REMOVE
        reactionAdded = false;
        userEmojis.remove(emoji);
        int count = currentCounts[emoji] ?? 0;
        if (count > 0) currentCounts[emoji] = count - 1;
        if (currentCounts[emoji] == 0) currentCounts.remove(emoji);
      } else {
        // ADD
        reactionAdded = true;
        userEmojis.add(emoji);
        currentCounts[emoji] = (currentCounts[emoji] ?? 0) + 1;
      }

      if (userEmojis.isEmpty) {
        transaction.delete(reactionRef);
      } else {
        transaction.set(reactionRef, {
          'emojis': userEmojis,
          'userId': _currentUserId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      final Map<String, dynamic> updates = {'reactions': currentCounts};

      if (commentId == null) {
        final fieldPath = 'reactionUserIds.$emoji';
        final isRemoving = !userEmojis.contains(emoji);
        if (!isRemoving) {
          updates[fieldPath] = FieldValue.arrayUnion([userId]);
        } else {
          updates[fieldPath] = FieldValue.arrayRemove([userId]);
        }
      }

      transaction.update(docRef, updates);
    });

    await _logger.logActivity('reaction_toggle', {
      'post_id': postId,
      'comment_id': commentId,
      'emoji': emoji,
    });

    // Notification fan-out (skip self-reaction)
    final aid = authorId;
    if (aid != null && aid != userId) {
      final ns = NotificationService();
      final target = commentId ?? postId;
      final relatedId = '${target}_rx_$emoji';
      if (reactionAdded) {
        unawaited(ns.sendNotification(
          targetUserId: aid,
          type: NotificationType.reaction,
          actorUid: userId,
          actorName: _auth.currentUser?.displayName,
          actorPhotoUrl: _auth.currentUser?.photoURL,
          relatedId: relatedId,
          metadata: {
            'emoji': emoji,
            'postId': postId,
            if (commentId != null) 'commentId': commentId,
          },
        ));
      } else {
        unawaited(ns.deleteNotificationByRelatedId(
          targetUserId: aid,
          relatedId: relatedId,
          type: NotificationType.reaction,
        ));
      }
    }
  }

  List<CommunityGroup> getGroups() {
    return [
      CommunityGroup(
        id: 'g1',
        name: 'Cookrange',
        imageUrl: '',
        hasUpdate: true,
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ];
  }

  // --- Reporting & Moderation ---

  Future<void> reportPost(String postId, String reason) async {
    final userId = _currentUserId;
    if (userId == 'guest') return;
    try {
      final postSnap = await _firestore.collection('posts').doc(postId).get();
      final authorId =
          (postSnap.data()?['author'] as Map<String, dynamic>?)?['id'] as String?;
      await _firestore.collection('reports').add({
        'reporterId': userId,
        'targetType': 'post',
        'targetId': postId,
        'postId': postId,
        'authorId': authorId,
        'reason': reason,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      unawaited(_logger.logActivity('post_report', {'post_id': postId, 'reason': reason}));
    } catch (e) {
      _logger.error('reportPost failed', error: e);
    }
  }

  Future<void> reportComment(
      String postId, String commentId, String reason) async {
    final userId = _currentUserId;
    if (userId == 'guest') return;
    try {
      final commentSnap = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId)
          .get();
      final authorId =
          (commentSnap.data()?['author'] as Map<String, dynamic>?)?['id'] as String?;
      await _firestore.collection('reports').add({
        'reporterId': userId,
        'targetType': 'comment',
        'targetId': commentId,
        'postId': postId,
        'authorId': authorId,
        'reason': reason,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      unawaited(_logger.logActivity('comment_report', {
        'post_id': postId,
        'comment_id': commentId,
        'reason': reason,
      }));
    } catch (e) {
      _logger.error('reportComment failed', error: e);
    }
  }

  // --- Block List ---

  Future<void> blockUser(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == 'guest' || userId == targetUserId) return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('block_list')
        .doc(targetUserId)
        .set({'timestamp': FieldValue.serverTimestamp()});
    unawaited(_logger.logActivity('user_block', {'target_id': targetUserId}));
  }

  Future<void> unblockUser(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == 'guest') return;
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('block_list')
        .doc(targetUserId)
        .delete();
    unawaited(_logger.logActivity('user_unblock', {'target_id': targetUserId}));
  }

  Future<List<String>> getBlockedIds() async {
    final userId = _currentUserId;
    if (userId == 'guest') return [];
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('block_list')
          .get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> isBlocked(String targetUserId) async {
    final userId = _currentUserId;
    if (userId == 'guest') return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('block_list')
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Preload feeds to warm up cache
  Future<void> preloadFeeds() async {
    try {
      await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();
    } catch (e) {
      // Ignore
    }
  }
}
