import 'package:cloud_firestore/cloud_firestore.dart';

enum GymMemberTier { standard, premium }

extension GymMemberTierX on GymMemberTier {
  String get firestoreValue => name;
  static GymMemberTier fromString(String? v) =>
      v == 'premium' ? GymMemberTier.premium : GymMemberTier.standard;
}

class GymMemberModel {
  final String uid;
  final String? displayName;
  final String? photoURL;
  final DateTime joinedAt;
  final GymMemberTier tier;
  final DateTime? lastCheckIn;

  const GymMemberModel({
    required this.uid,
    this.displayName,
    this.photoURL,
    required this.joinedAt,
    required this.tier,
    this.lastCheckIn,
  });

  factory GymMemberModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

    return GymMemberModel(
      uid: doc.id,
      displayName: d['display_name'] as String?,
      photoURL: d['photo_url'] as String?,
      joinedAt: ts(d['joined_at']),
      tier: GymMemberTierX.fromString(d['tier'] as String?),
      lastCheckIn: d['last_check_in'] is Timestamp
          ? (d['last_check_in'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'display_name': displayName,
        'photo_url': photoURL,
        'joined_at': Timestamp.fromDate(joinedAt),
        'tier': tier.firestoreValue,
        if (lastCheckIn != null)
          'last_check_in': Timestamp.fromDate(lastCheckIn!),
      };

  bool get isActiveToday {
    if (lastCheckIn == null) return false;
    final now = DateTime.now();
    return lastCheckIn!.year == now.year &&
        lastCheckIn!.month == now.month &&
        lastCheckIn!.day == now.day;
  }
}
