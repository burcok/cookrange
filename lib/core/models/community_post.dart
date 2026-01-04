import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityUser {
  final String id;
  final String name;
  final String avatarUrl;

  CommunityUser({
    required this.id,
    required this.name,
    required this.avatarUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
    };
  }

  factory CommunityUser.fromMap(Map<String, dynamic> map) {
    return CommunityUser(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown',
      avatarUrl: map['avatarUrl'] ?? '',
    );
  }
}

class CommunityComment {
  final String id;
  final CommunityUser author;
  final String content;
  final DateTime timestamp;
  final int likesCount;
  bool isLiked;
  final Map<String, int> reactions;
  List<String> userReactions;
  final bool isEdited;

  CommunityComment({
    required this.id,
    required this.author,
    required this.content,
    required this.timestamp,
    this.likesCount = 0,
    this.isLiked = false,
    this.reactions = const {},
    this.userReactions = const [],
    this.isEdited = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'author': author.toMap(),
      'content': content,
      'timestamp': Timestamp.fromDate(timestamp),
      'likesCount': likesCount,
      'isLiked': isLiked,
      'reactions': reactions,
      'isEdited': isEdited,
    };
  }

  factory CommunityComment.fromMap(Map<String, dynamic> map, String id) {
    return CommunityComment(
      id: id,
      author: CommunityUser.fromMap(map['author'] ?? {}),
      content: map['content'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      likesCount: map['likesCount'] ?? 0,
      isLiked: map['isLiked'] ?? false,
      reactions: Map<String, int>.from(map['reactions'] ?? {}),
      userReactions: List<String>.from(map['userReactions'] ?? []),
      isEdited: map['isEdited'] ?? false,
    );
  }
}

class CommunityGroup {
  final String id;
  final String name;
  final String imageUrl;
  final bool hasUpdate;
  final bool isNew;

  final DateTime? lastMessageTime;

  CommunityGroup({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.hasUpdate = false,
    this.isNew = false,
    this.lastMessageTime,
  });
}

class CommunityPost {
  final String id;
  final CommunityUser author;
  final String content;
  final String? imageUrl;
  final List<String> imageUrls; // New: Support multiple images
  int likesCount;
  int commentsCount;
  final DateTime timestamp;
  bool isLiked;
  bool isBookmarked;
  final List<String> tags;
  final List<CommunityUser> likedByUsers;
  final Map<String, int> reactions;
  List<String> userReactions;
  final bool isEdited; // New: For face pile

  CommunityPost({
    required this.id,
    required this.author,
    required this.content,
    this.imageUrl,
    this.imageUrls = const [],
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.timestamp,
    this.isLiked = false,
    this.isBookmarked = false,
    this.tags = const [],
    this.likedByUsers = const [],
    this.reactions = const {},
    this.userReactions = const [],
    this.isEdited = false,
  });

  CommunityPost copyWith({
    String? id,
    CommunityUser? author,
    String? content,
    String? imageUrl,
    List<String>? imageUrls,
    int? likesCount,
    int? commentsCount,
    DateTime? timestamp,
    bool? isLiked,
    bool? isBookmarked,
    List<String>? tags,
    List<CommunityUser>? likedByUsers,
    Map<String, int>? reactions,
    List<String>? userReactions,
    bool? isEdited,
  }) {
    return CommunityPost(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      timestamp: timestamp ?? this.timestamp,
      isLiked: isLiked ?? this.isLiked,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      tags: tags ?? this.tags,
      likedByUsers: likedByUsers ?? this.likedByUsers,
      reactions: reactions ?? this.reactions,
      userReactions: userReactions ?? this.userReactions,
      isEdited: isEdited ?? this.isEdited,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'author': author.toMap(),
      'content': content,
      'imageUrls': imageUrls,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'timestamp': Timestamp.fromDate(timestamp),
      'tags': tags,
      'reactions': reactions,
      'isEdited': isEdited,
      // Note: likedByUsers is typically stored in a subcollection or separate logic,
      // but for "recent likers" face pile, we can store a small array.
      'recentLikers': likedByUsers.map((u) => u.toMap()).toList(),
    };
  }

  factory CommunityPost.fromMap(Map<String, dynamic> map, String id,
      {String? currentUserId}) {
    final List<String> images = List<String>.from(map['imageUrls'] ?? []);
    if (images.isEmpty && map['imageUrl'] != null) {
      images.add(map['imageUrl']);
    }

    final likedUserIds = List<String>.from(map['likedUserIds'] ?? []);
    final isLikedByCurrentUser =
        currentUserId != null && likedUserIds.contains(currentUserId);

    return CommunityPost(
      id: id,
      author: CommunityUser.fromMap(map['author'] ?? {}),
      content: map['content'] ?? '',
      imageUrl: images.isNotEmpty ? images.first : null,
      imageUrls: images,
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      tags: List<String>.from(map['tags'] ?? []),
      likedByUsers: (map['recentLikers'] as List<dynamic>?)
              ?.map((e) => CommunityUser.fromMap(e))
              .toList() ??
          [],
      isLiked: isLikedByCurrentUser, // Real check
      isBookmarked: false,
      reactions: Map<String, int>.from(map['reactions'] ?? {}),
      userReactions: List<String>.from(map['userReactions'] ?? []),
      isEdited: map['isEdited'] ?? false,
    );
  }
}
