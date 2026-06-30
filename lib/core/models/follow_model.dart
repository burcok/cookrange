import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a follow relationship stored at:
///   users/{currentUid}/following/{targetUid}
///   users/{targetUid}/followers/{currentUid}
///
/// [uid] is the user ID of the other party (target when following, follower
/// when reading from the followers subcollection). [followedAt] is the
/// server-assigned timestamp of the follow action.
class FollowModel {
  final String uid;
  final DateTime followedAt;

  const FollowModel({
    required this.uid,
    required this.followedAt,
  });

  factory FollowModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return FollowModel(
      uid: doc.id,
      followedAt:
          (data['followedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'followedAt': FieldValue.serverTimestamp(),
      };

  FollowModel copyWith({
    String? uid,
    DateTime? followedAt,
  }) {
    return FollowModel(
      uid: uid ?? this.uid,
      followedAt: followedAt ?? this.followedAt,
    );
  }
}
