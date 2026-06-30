import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/community_post.dart';
import '../models/notification_model.dart';
import 'analytics_service.dart';
import 'firestore_service.dart';
import 'log_service.dart';
import 'notification_service.dart';

class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LogService _logger = LogService();

  List<String> _cachedBlockedKeywords = [];
  DateTime? _keywordsCacheTime;

  String get currentUserId => _auth.currentUser?.uid ?? 'guest';

  // --- Helpers ---

  String get _currentUserId => _auth.currentUser?.uid ?? 'guest';

  Future<CommunityUser> _getCurrentCommunityUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Firestore is the source of truth for the in-app avatar (uploaded photos
      // land on users/{uid}.photoURL, not on the Firebase Auth profile).
      final model = await FirestoreService().getUserData(user.uid);
      final photo = (model?.photoURL?.isNotEmpty ?? false)
          ? model!.photoURL!
          : (user.photoURL ?? '');
      return CommunityUser(
        id: user.uid,
        name: model?.displayName ?? user.displayName ?? 'User',
        avatarUrl: photo, // empty string → AppInitialsAvatar in UI
      );
    }
    // Fallback for guest — no photo; UI shows initials
    return CommunityUser(
      id: 'guest',
      name: 'Guest User',
      avatarUrl: '',
    );
  }

  // --- Content Guard ---

  Future<void> _checkContent(String text) async {
    final now = DateTime.now();
    if (_keywordsCacheTime == null ||
        now.difference(_keywordsCacheTime!) > const Duration(minutes: 5)) {
      try {
        final doc = await _firestore
            .collection('admin_config')
            .doc('global')
            .get();
        _cachedBlockedKeywords = List<String>.from(
            doc.data()?['blocked_keywords'] as List? ?? []);
        _keywordsCacheTime = now;
      } catch (_) {
        _cachedBlockedKeywords = [];
      }
    }
    if (_cachedBlockedKeywords.isEmpty) return;
    final lower = text.toLowerCase();
    for (final kw in _cachedBlockedKeywords) {
      if (kw.isNotEmpty && lower.contains(kw.toLowerCase())) {
        throw Exception('content_blocked');
      }
    }
  }

  // --- Posts ---

  // --- Posts ---

  /// [authorIds] — restrict to posts from these user IDs (Friends filter; max 30).
  /// [gymOnly] — restrict to posts tagged with gym-related tags.
  /// [topic] — restrict to posts with this topic tag (arrayContains).
  /// Automatically filters out posts from blocked users (client-side).
  Stream<List<CommunityPost>> getPostsStream({
    int limit = 20,
    List<String>? authorIds,
    bool gymOnly = false,
    String? topic,
  }) async* {
    final blockedIds = await getBlockedIds();
    final userId = _currentUserId;

    Query<Map<String, dynamic>> query = _firestore.collection('posts');

    if (authorIds != null && authorIds.isNotEmpty) {
      query = query.where('authorId', whereIn: authorIds.take(30).toList());
    } else if (gymOnly) {
      query = query.where('tags',
          arrayContainsAny: ['gym', 'fitness', 'workout', 'training', 'crossfit', 'powerlifting']);
    } else if (topic != null && topic.isNotEmpty) {
      query = query.where('tags', arrayContains: topic);
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

  /// Group-scoped feed: posts whose top-level `groupId` matches [groupId],
  /// newest first. Blocked authors are filtered client-side.
  Stream<List<CommunityPost>> getGroupFeedStream(String groupId,
      {int limit = 30}) async* {
    final blockedIds = await getBlockedIds();
    final userId = _currentUserId;
    yield* _firestore
        .collection('posts')
        .where('groupId', isEqualTo: groupId)
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
  /// Pass the same [authorIds]/[gymOnly]/[topic] as the active stream filter.
  Future<({List<CommunityPost> posts, DocumentSnapshot? lastDoc})>
      fetchPostsPage({
    int limit = 20,
    DocumentSnapshot? startAfter,
    List<String>? authorIds,
    bool gymOnly = false,
    String? topic,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('posts');

      if (authorIds != null && authorIds.isNotEmpty) {
        query = query.where('authorId', whereIn: authorIds.take(30).toList());
      } else if (gymOnly) {
        query = query.where('tags',
            arrayContainsAny: ['gym', 'fitness', 'workout', 'training', 'crossfit', 'powerlifting']);
      } else if (topic != null && topic.isNotEmpty) {
        query = query.where('tags', arrayContains: topic);
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
    String content,
    List<String> imageUrls,
    List<String> tags, {
    PostType postType = PostType.text,
    Map<String, dynamic> metadata = const {},
    String? authorRole,
    String? groupId,
  }) async {
    await _checkContent(content);
    final user = await _getCurrentCommunityUser();

    final newPost = CommunityPost(
      id: '',
      author: user,
      content: content,
      imageUrls: imageUrls,
      imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
      timestamp: DateTime.now(),
      tags: tags,
      postType: postType,
      metadata: metadata,
      authorRole: authorRole,
    );

    final docRef = await _firestore.collection('posts').add({
      ...newPost.toMap(),
      'authorId': user.id,
      'likedUserIds': [],
      'commentsCount': 0,
      'likesCount': 0,
      // Top-level groupId enables group-scoped feeds (null = global feed).
      if (groupId != null) 'groupId': groupId,
    });

    final newPostId = docRef.id;

    await _logger.logActivity('post_create', {
      'post_id': newPostId,
      'content_length': content.length,
      'has_images': imageUrls.isNotEmpty,
      'tags': tags,
      'post_type': postType.value,
      if (authorRole != null) 'author_role': authorRole,
    });
    unawaited(AnalyticsService().logEvent(
      name: 'post_created',
      parameters: {
        'has_images': imageUrls.isNotEmpty,
        'tag_count': tags.length,
        'post_type': postType.value,
      },
    ));

    // Mention notification fan-out (fire-and-forget, never blocks post creation)
    final mentions = metadata['mentions'];
    if (mentions is List && mentions.isNotEmpty) {
      final ns = NotificationService();
      for (final raw in mentions) {
        if (raw is! Map) continue;
        final mentionedUid = raw['uid'] as String?;
        if (mentionedUid == null || mentionedUid == user.id) continue;
        unawaited(ns.sendNotification(
          targetUserId: mentionedUid,
          type: NotificationType.system,
          actorUid: user.id,
          actorName: user.name,
          actorPhotoUrl: user.avatarUrl,
          relatedId: newPostId,
          metadata: {'postId': newPostId, 'subtype': 'mention'},
        ));
      }
    }
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
    await _checkContent(content);
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

  /// Legacy stub retired — real groups now live in [CommunityGroupService]
  /// and are reached via the community "Groups" carousel → GroupsDiscoveryScreen.
  List<CommunityGroup> getGroups() => const [];

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

  /// Generic content reporter. Writes a `reports/{id}` doc for any content type.
  /// [type] should be `'post'` or `'squad'`.
  Future<void> reportContent({
    required String type,
    required String targetId,
    required String targetAuthorUid,
    required String reporterUid,
    required String reason,
  }) async {
    if (reporterUid == 'guest' || reporterUid.isEmpty) return;
    try {
      await _firestore.collection('reports').add({
        'type': type,
        'targetId': targetId,
        'targetAuthorUid': targetAuthorUid,
        'reporterUid': reporterUid,
        'reason': reason,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      unawaited(_logger.logActivity('content_report', {
        'type': type,
        'target_id': targetId,
        'reason': reason,
      }));
    } catch (e) {
      _logger.error('reportContent failed', error: e);
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

  // ── Weekly Highlights ─────────────────────────────────────────────────────

  /// Returns the post with the highest [likesCount] created in the last 7 days,
  /// or null when no posts exist in that window.
  ///
  /// Requires a composite index on `posts`: createdAt ASC + likesCount DESC.
  /// The query uses `timestamp` (the field used everywhere else in this service)
  /// and falls back to null on any error so the card simply hides itself.
  Future<CommunityPost?> getTopPostThisWeek() async {
    try {
      final cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7)),
      );
      final snap = await _firestore
          .collection('posts')
          .where('timestamp', isGreaterThanOrEqualTo: cutoff)
          .orderBy('timestamp', descending: false)
          .orderBy('likesCount', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      final userId = _currentUserId;
      return CommunityPost.fromMap(doc.data(), doc.id, currentUserId: userId);
    } catch (e) {
      _logger.error('getTopPostThisWeek failed', error: e);
      return null;
    }
  }

  /// Returns a map with uid, displayName, photoURL, and streak for the user
  /// with the highest streak value, or null when the query fails.
  ///
  /// Uses the existing composite index on `users`: onboarding_data.streak DESC
  /// (added for the leaderboard feature).
  Future<Map<String, dynamic>?> getTopStreakUserThisWeek() async {
    try {
      final snap = await _firestore
          .collection('users')
          .orderBy('onboarding_data.streak', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final uid = snap.docs.first.id;
      final onboarding = data['onboarding_data'] as Map<String, dynamic>? ?? {};
      final streak = onboarding['streak'] as int? ?? 0;
      if (streak <= 0) return null;

      return {
        'uid': uid,
        'displayName': data['displayName'] as String? ?? '',
        'photoURL': data['photoURL'] as String? ?? '',
        'streak': streak,
      };
    } catch (e) {
      _logger.error('getTopStreakUserThisWeek failed', error: e);
      return null;
    }
  }

  // ── Save / Bookmark ────────────────────────────────────────────────────────

  Future<void> savePost(CommunityPost post) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    debugPrint('CommunityService: savePost postId=${post.id}');
    final data = {
      ...post.toMap(),
      'id': post.id,
      'authorId': post.author.id,
      'savedAt': FieldValue.serverTimestamp(),
    };
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .doc(post.id)
        .set(data);
  }

  Future<void> unsavePost(String postId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    debugPrint('CommunityService: unsavePost postId=$postId');
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .doc(postId)
        .delete();
  }

  Stream<bool> isPostSavedStream(String postId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(false);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .doc(postId)
        .snapshots()
        .map((snap) => snap.exists)
        .handleError((_) => false);
  }

  Stream<List<CommunityPost>> getSavedPostsStream() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_posts')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              final postId = data['id'] as String? ?? d.id;
              return CommunityPost.fromMap(data, postId, currentUserId: uid);
            }).toList())
        .handleError((_) => <CommunityPost>[]);
  }
}
