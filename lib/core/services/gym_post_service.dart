import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/gym_post_model.dart';

/// Service for gym community posts and comments.
///
/// Collection: `gyms/{gymId}/posts/{postId}`
/// Comments subcollection: `gyms/{gymId}/posts/{postId}/comments/{commentId}`
class GymPostService {
  static final GymPostService _instance = GymPostService._internal();
  factory GymPostService() => _instance;
  GymPostService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _postsRef(String gymId) =>
      _db.collection('gyms').doc(gymId).collection('posts');

  CollectionReference<Map<String, dynamic>> _commentsRef(
          String gymId, String postId) =>
      _db
          .collection('gyms')
          .doc(gymId)
          .collection('posts')
          .doc(postId)
          .collection('comments');

  // ── Create post ─────────────────────────────────────────────────────────────

  Future<void> createPost({
    required String gymId,
    required String content,
    String? imageUrl,
    required bool isAnnouncement,
    required bool isOwner,
  }) async {
    debugPrint(
        '[GymPostService] createPost gymId=$gymId isAnnouncement=$isAnnouncement');
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final now = DateTime.now();
      final doc = _postsRef(gymId).doc();

      final post = GymPostModel(
        id: doc.id,
        gymId: gymId,
        authorUid: user.uid,
        authorName: user.displayName ?? 'Member',
        authorPhotoUrl: user.photoURL,
        authorIsOwner: isOwner,
        content: content.trim(),
        imageUrl: imageUrl,
        isAnnouncement: isAnnouncement,
        isPinned: false,
        likeCount: 0,
        likedByUids: [],
        commentCount: 0,
        createdAt: now,
        updatedAt: now,
      );

      await doc.set(post.toFirestore());
      debugPrint('[GymPostService] createPost success docId=${doc.id}');
    } catch (e, st) {
      debugPrint('[GymPostService] createPost error: $e\n$st');
      rethrow;
    }
  }

  // ── Delete post ─────────────────────────────────────────────────────────────

  Future<void> deletePost(String gymId, String postId) async {
    debugPrint('[GymPostService] deletePost gymId=$gymId postId=$postId');
    try {
      await _postsRef(gymId).doc(postId).delete();
      debugPrint('[GymPostService] deletePost success');
    } catch (e, st) {
      debugPrint('[GymPostService] deletePost error: $e\n$st');
      rethrow;
    }
  }

  // ── Toggle pin ──────────────────────────────────────────────────────────────

  Future<void> togglePin(
      String gymId, String postId, bool currentlyPinned) async {
    debugPrint(
        '[GymPostService] togglePin gymId=$gymId postId=$postId currentlyPinned=$currentlyPinned');
    try {
      await _postsRef(gymId).doc(postId).update({
        'is_pinned': !currentlyPinned,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('[GymPostService] togglePin success');
    } catch (e, st) {
      debugPrint('[GymPostService] togglePin error: $e\n$st');
      rethrow;
    }
  }

  // ── Toggle announcement ──────────────────────────────────────────────────────

  Future<void> toggleAnnouncement(
      String gymId, String postId, bool currentlyAnnouncement) async {
    debugPrint(
        '[GymPostService] toggleAnnouncement gymId=$gymId postId=$postId');
    try {
      await _postsRef(gymId).doc(postId).update({
        'is_announcement': !currentlyAnnouncement,
        'updated_at': Timestamp.fromDate(DateTime.now()),
      });
      debugPrint('[GymPostService] toggleAnnouncement success');
    } catch (e, st) {
      debugPrint('[GymPostService] toggleAnnouncement error: $e\n$st');
      rethrow;
    }
  }

  // ── Toggle like ─────────────────────────────────────────────────────────────

  Future<void> toggleLike(
      String gymId, String postId, String uid, bool currentlyLiked) async {
    debugPrint(
        '[GymPostService] toggleLike gymId=$gymId postId=$postId uid=$uid currentlyLiked=$currentlyLiked');
    try {
      final ref = _postsRef(gymId).doc(postId);
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final currentCount = data['like_count'] as int? ?? 0;

        if (currentlyLiked) {
          tx.update(ref, {
            'liked_by_uids': FieldValue.arrayRemove([uid]),
            'like_count': (currentCount - 1).clamp(0, double.maxFinite.toInt()),
          });
        } else {
          tx.update(ref, {
            'liked_by_uids': FieldValue.arrayUnion([uid]),
            'like_count': currentCount + 1,
          });
        }
      });
      debugPrint('[GymPostService] toggleLike success');
    } catch (e, st) {
      debugPrint('[GymPostService] toggleLike error: $e\n$st');
      rethrow;
    }
  }

  // ── Feed stream ─────────────────────────────────────────────────────────────

  /// Streams all posts for a gym, sorted client-side: pinned first, then by date DESC.
  Stream<List<GymPostModel>> getFeedStream(String gymId) {
    debugPrint('[GymPostService] getFeedStream gymId=$gymId');
    return _postsRef(gymId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) {
      final posts =
          snap.docs.map((d) => GymPostModel.fromFirestore(d)).toList();
      // Sort client-side: pinned first, then by date DESC
      posts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return posts;
    });
  }

  // ── Announcements stream ────────────────────────────────────────────────────

  /// Streams only announcement posts, sorted: pinned first, then by date DESC.
  Stream<List<GymPostModel>> getAnnouncementsStream(String gymId) {
    debugPrint('[GymPostService] getAnnouncementsStream gymId=$gymId');
    return _postsRef(gymId)
        .where('is_announcement', isEqualTo: true)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map((snap) {
      final posts =
          snap.docs.map((d) => GymPostModel.fromFirestore(d)).toList();
      posts.sort((a, b) {
        if (a.isPinned && !b.isPinned) return -1;
        if (!a.isPinned && b.isPinned) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return posts;
    });
  }

  // ── Add comment ─────────────────────────────────────────────────────────────

  Future<void> addComment({
    required String gymId,
    required String postId,
    required String content,
  }) async {
    debugPrint('[GymPostService] addComment gymId=$gymId postId=$postId');
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final commentRef = _commentsRef(gymId, postId).doc();
      final postRef = _postsRef(gymId).doc(postId);

      final comment = GymCommentModel(
        id: commentRef.id,
        postId: postId,
        authorUid: user.uid,
        authorName: user.displayName ?? 'Member',
        authorPhotoUrl: user.photoURL,
        content: content.trim(),
        createdAt: DateTime.now(),
      );

      final batch = _db.batch();
      batch.set(commentRef, comment.toFirestore());
      batch.update(postRef, {
        'comment_count': FieldValue.increment(1),
      });
      await batch.commit();
      debugPrint(
          '[GymPostService] addComment success commentId=${commentRef.id}');
    } catch (e, st) {
      debugPrint('[GymPostService] addComment error: $e\n$st');
      rethrow;
    }
  }

  // ── Delete comment ──────────────────────────────────────────────────────────

  Future<void> deleteComment(
      String gymId, String postId, String commentId) async {
    debugPrint(
        '[GymPostService] deleteComment gymId=$gymId postId=$postId commentId=$commentId');
    try {
      final commentRef = _commentsRef(gymId, postId).doc(commentId);
      final postRef = _postsRef(gymId).doc(postId);

      final batch = _db.batch();
      batch.delete(commentRef);
      batch.update(postRef, {
        'comment_count': FieldValue.increment(-1),
      });
      await batch.commit();
      debugPrint('[GymPostService] deleteComment success');
    } catch (e, st) {
      debugPrint('[GymPostService] deleteComment error: $e\n$st');
      rethrow;
    }
  }

  // ── Comments stream ─────────────────────────────────────────────────────────

  Stream<List<GymCommentModel>> getCommentsStream(String gymId, String postId) {
    debugPrint(
        '[GymPostService] getCommentsStream gymId=$gymId postId=$postId');
    return _commentsRef(gymId, postId)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => GymCommentModel.fromFirestore(d)).toList());
  }
}
