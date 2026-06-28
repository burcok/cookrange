import 'package:cloud_firestore/cloud_firestore.dart';

class GymPostModel {
  final String id;
  final String gymId;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final bool authorIsOwner;
  final String content;
  final String? imageUrl;
  final bool isAnnouncement;
  final bool isPinned;
  final int likeCount;
  final List<String> likedByUids;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const GymPostModel({
    required this.id,
    required this.gymId,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.authorIsOwner,
    required this.content,
    this.imageUrl,
    required this.isAnnouncement,
    required this.isPinned,
    required this.likeCount,
    required this.likedByUids,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
  });

  bool isLikedBy(String uid) => likedByUids.contains(uid);

  factory GymPostModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

    return GymPostModel(
      id: doc.id,
      gymId: d['gym_id'] as String? ?? '',
      authorUid: d['author_uid'] as String? ?? '',
      authorName: d['author_name'] as String? ?? '',
      authorPhotoUrl: d['author_photo_url'] as String?,
      authorIsOwner: d['author_is_owner'] as bool? ?? false,
      content: d['content'] as String? ?? '',
      imageUrl: d['image_url'] as String?,
      isAnnouncement: d['is_announcement'] as bool? ?? false,
      isPinned: d['is_pinned'] as bool? ?? false,
      likeCount: d['like_count'] as int? ?? 0,
      likedByUids: List<String>.from(d['liked_by_uids'] as List? ?? []),
      commentCount: d['comment_count'] as int? ?? 0,
      createdAt: ts(d['created_at']),
      updatedAt: ts(d['updated_at']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'gym_id': gymId,
        'author_uid': authorUid,
        'author_name': authorName,
        if (authorPhotoUrl != null) 'author_photo_url': authorPhotoUrl,
        'author_is_owner': authorIsOwner,
        'content': content,
        if (imageUrl != null) 'image_url': imageUrl,
        'is_announcement': isAnnouncement,
        'is_pinned': isPinned,
        'like_count': likeCount,
        'liked_by_uids': likedByUids,
        'comment_count': commentCount,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  GymPostModel copyWith({
    String? gymId,
    String? authorUid,
    String? authorName,
    String? authorPhotoUrl,
    bool? authorIsOwner,
    String? content,
    String? imageUrl,
    bool? isAnnouncement,
    bool? isPinned,
    int? likeCount,
    List<String>? likedByUids,
    int? commentCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      GymPostModel(
        id: id,
        gymId: gymId ?? this.gymId,
        authorUid: authorUid ?? this.authorUid,
        authorName: authorName ?? this.authorName,
        authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
        authorIsOwner: authorIsOwner ?? this.authorIsOwner,
        content: content ?? this.content,
        imageUrl: imageUrl ?? this.imageUrl,
        isAnnouncement: isAnnouncement ?? this.isAnnouncement,
        isPinned: isPinned ?? this.isPinned,
        likeCount: likeCount ?? this.likeCount,
        likedByUids: likedByUids ?? this.likedByUids,
        commentCount: commentCount ?? this.commentCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class GymCommentModel {
  final String id;
  final String postId;
  final String authorUid;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;

  const GymCommentModel({
    required this.id,
    required this.postId,
    required this.authorUid,
    required this.authorName,
    this.authorPhotoUrl,
    required this.content,
    required this.createdAt,
  });

  factory GymCommentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

    return GymCommentModel(
      id: doc.id,
      postId: d['post_id'] as String? ?? '',
      authorUid: d['author_uid'] as String? ?? '',
      authorName: d['author_name'] as String? ?? '',
      authorPhotoUrl: d['author_photo_url'] as String?,
      content: d['content'] as String? ?? '',
      createdAt: ts(d['created_at']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'post_id': postId,
        'author_uid': authorUid,
        'author_name': authorName,
        if (authorPhotoUrl != null) 'author_photo_url': authorPhotoUrl,
        'content': content,
        'created_at': Timestamp.fromDate(createdAt),
      };

  GymCommentModel copyWith({
    String? postId,
    String? authorUid,
    String? authorName,
    String? authorPhotoUrl,
    String? content,
    DateTime? createdAt,
  }) =>
      GymCommentModel(
        id: id,
        postId: postId ?? this.postId,
        authorUid: authorUid ?? this.authorUid,
        authorName: authorName ?? this.authorName,
        authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
        content: content ?? this.content,
        createdAt: createdAt ?? this.createdAt,
      );
}
