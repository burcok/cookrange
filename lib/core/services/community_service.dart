import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/community_post.dart';
import '../models/notification_model.dart';
import 'log_service.dart';

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

  Stream<List<CommunityPost>> getPostsStream({int limit = 20}) {
    final userId = _currentUserId;
    return _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) =>
              CommunityPost.fromMap(doc.data(), doc.id, currentUserId: userId))
          .toList();
    });
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
      print("Error fetching posts: $e");
      return [];
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
      'likedUserIds': [], // Init empty list
      'commentsCount': 0,
      'likesCount': 0,
    });

    await _logger.logActivity('post_create', {
      'post_id': docRef.id,
      'content_length': content.length,
      'has_images': imageUrls.isNotEmpty,
      'tags': tags,
    });
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
      print("Error fetching post details: $e");
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

      // Delete the document
      // Note: Subcollections (likes, comments) are not automatically deleted by client SDKs
      // A Cloud Function is usually best for recursive delete.
      // For now, we delete the post doc which makes it disappear from queries.
      await _firestore.collection('posts').doc(postId).delete();

      await _logger.logActivity('post_delete', {
        'post_id': postId,
      });

      return true;
    } catch (e) {
      print("Error deleting post: $e");
      return false;
    }
  }

  Future<bool> likePost(String postId) async {
    final userId = _currentUserId;
    if (userId == 'guest') return false;

    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    // We also need to update the top-level 'likedUserIds' array for the feed efficiently
    return _firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);
      final postDoc = await transaction.get(postRef);

      if (!postDoc.exists) return false;

      List<dynamic> recentLikers = [];
      if (postDoc.data() != null &&
          (postDoc.data() as Map).containsKey('recentLikers')) {
        recentLikers = List.from(postDoc['recentLikers']);
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

        // Avoid duplicates just in case
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
    }).then((result) {
      if (result) {
        _logger.logActivity('post_like', {'post_id': postId});
      } else {
        _logger.logActivity('post_unlike', {'post_id': postId});
      }
      return result;
    });
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

    return _firestore.runTransaction((transaction) async {
      final likeDoc = await transaction.get(likeRef);
      final commentDoc = await transaction.get(commentRef);

      if (!commentDoc.exists) return false;

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        transaction.update(commentRef, {
          'likesCount': FieldValue.increment(-1),
          'isLiked':
              false, // For local simple tracking if stored, but 'isLiked' logic is client side typically
          // Actually, update likedUserIds if needed? Comments might not need face pile.
        });
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
        transaction.update(commentRef, {
          'likesCount': FieldValue.increment(1),
        });
        return true;
      }
    }).then((result) {
      if (result) {
        _logger.logActivity(
            'comment_like', {'post_id': postId, 'comment_id': commentId});
      } else {
        _logger.logActivity(
            'comment_unlike', {'post_id': postId, 'comment_id': commentId});
      }
      return result;
    });
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

    // Batch or Transaction to ensure count updates
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

    return newComment;
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
      print("Error fetching comments: $e");
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
      print("Error deleting comment: $e");
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

    await _firestore.runTransaction((transaction) async {
      final reactionDoc = await transaction.get(reactionRef);
      final parentDoc = await transaction.get(docRef);

      if (!parentDoc.exists) return;

      Map<String, int> currentCounts = {};
      if (parentDoc.data() != null &&
          (parentDoc.data() as Map).containsKey('reactions')) {
        currentCounts = Map<String, int>.from(parentDoc['reactions']);
      }

      List<String> userEmojis = [];
      if (reactionDoc.exists && reactionDoc.data() != null) {
        final rData = reactionDoc.data() as Map<String, dynamic>;
        if (rData['emojis'] != null) {
          userEmojis = List<String>.from(rData['emojis']);
        } else if (rData['emoji'] != null) {
          // Migration
          userEmojis = [rData['emoji']];
        }
      }

      if (userEmojis.contains(emoji)) {
        // REMOVE
        userEmojis.remove(emoji);
        int count = currentCounts[emoji] ?? 0;
        if (count > 0) currentCounts[emoji] = count - 1;
        if (currentCounts[emoji] == 0) currentCounts.remove(emoji);
      } else {
        // ADD
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

      // Sync "Heart" reaction with "likedUserIds" for feed visibility checking
      // Only do this for Posts, not Comments (commentId == null)
      if (commentId == null) {
        // Sync emojis for feed visibility
        // Field: reactionUserIds.{emoji}
        // Note: Firestore map keys cannot contain '.', but emojis are fine.
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
  }

  List<CommunityGroup> getGroups() {
    return [
      CommunityGroup(
        id: 'g1',
        name: 'Runners',
        imageUrl: 'https://i.pravatar.cc/150?u=runners',
        hasUpdate: true,
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      // ... keep simple mocks or remove if unused heavily
    ];
  }

  // --- Notifications (Mock for now) ---

  Future<List<NotificationModel>> getNotifications() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return []; // Empty for now or mock
  }

  Future<void> clearAllNotifications() async {
    // Mock implementation
  }

  Future<void> deleteNotification(String id) async {
    // Mock implementation
  }
  // --- Reporting ---

  Future<void> reportPost(String postId, String reason) async {
    // In a real app, this would write to a reports collection
    await _logger.logActivity('post_report', {
      'post_id': postId,
      'reason': reason,
      'reporter_id': _currentUserId,
    });
    // Simulating API call
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> reportComment(
      String postId, String commentId, String reason) async {
    await _logger.logActivity('comment_report', {
      'post_id': postId,
      'comment_id': commentId,
      'reason': reason,
      'reporter_id': _currentUserId,
    });
    // Simulating API call
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
