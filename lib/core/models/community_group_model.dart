import 'package:cloud_firestore/cloud_firestore.dart';

/// A location-based community group (e.g. a city/neighborhood/diet-style hub).
/// Stored at `community_groups/{groupId}`.
class CommunityGroupModel {
  final String id;
  final String name;
  final String? description;
  final String? city;
  final String? district;
  final String? coverImageUrl;
  final String ownerUid;
  final int memberCount;
  final bool isPublic;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastActivityAt;

  const CommunityGroupModel({
    required this.id,
    required this.name,
    this.description,
    this.city,
    this.district,
    this.coverImageUrl,
    required this.ownerUid,
    this.memberCount = 1,
    this.isPublic = true,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    required this.lastActivityAt,
  });

  /// "City · District" (or whichever parts exist).
  String get locationDisplay {
    final parts = [
      if (district != null && district!.isNotEmpty) district,
      if (city != null && city!.isNotEmpty) city,
    ];
    return parts.join(' · ');
  }

  factory CommunityGroupModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    DateTime ts(String k) =>
        (d[k] is Timestamp) ? (d[k] as Timestamp).toDate() : DateTime(2025);
    return CommunityGroupModel(
      id: doc.id,
      name: d['name'] as String? ?? '',
      description: d['description'] as String?,
      city: d['city'] as String?,
      district: d['district'] as String?,
      coverImageUrl: d['cover_image_url'] as String?,
      ownerUid: d['owner_uid'] as String? ?? '',
      memberCount: (d['member_count'] as num?)?.toInt() ?? 0,
      isPublic: d['is_public'] as bool? ?? true,
      tags: List<String>.from(d['tags'] ?? const []),
      createdAt: ts('created_at'),
      updatedAt: ts('updated_at'),
      lastActivityAt: ts('last_activity_at'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (description != null) 'description': description,
      if (city != null) 'city': city,
      if (district != null) 'district': district,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      'owner_uid': ownerUid,
      'member_count': memberCount,
      'is_public': isPublic,
      'tags': tags,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'last_activity_at': Timestamp.fromDate(lastActivityAt),
    };
  }
}

enum GroupMemberRole { owner, moderator, member }

extension GroupMemberRoleX on GroupMemberRole {
  String get value => name;
  static GroupMemberRole fromString(String? v) => switch (v) {
        'owner' => GroupMemberRole.owner,
        'moderator' => GroupMemberRole.moderator,
        _ => GroupMemberRole.member,
      };
}

/// A member of a group, stored at `community_groups/{groupId}/members/{uid}`.
class CommunityGroupMemberModel {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final GroupMemberRole role;
  final DateTime joinedAt;

  const CommunityGroupMemberModel({
    required this.uid,
    this.displayName,
    this.photoURL,
    this.role = GroupMemberRole.member,
    required this.joinedAt,
  });

  factory CommunityGroupMemberModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CommunityGroupMemberModel(
      uid: doc.id,
      displayName: d['display_name'] as String?,
      photoURL: d['photo_url'] as String?,
      role: GroupMemberRoleX.fromString(d['role'] as String?),
      joinedAt: (d['joined_at'] is Timestamp)
          ? (d['joined_at'] as Timestamp).toDate()
          : DateTime(2025),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      if (displayName != null) 'display_name': displayName,
      if (photoURL != null) 'photo_url': photoURL,
      'role': role.value,
      'joined_at': Timestamp.fromDate(joinedAt),
    };
  }
}
