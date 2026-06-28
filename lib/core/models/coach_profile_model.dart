import 'package:cloud_firestore/cloud_firestore.dart';

class CoachProfileModel {
  final String uid;
  final String displayName;
  final String? photoURL;
  final String? bio;
  final List<String> specializations;
  final List<String> certifications;
  final bool isAcceptingClients;
  final String? vanityCode;
  final int clientCount;
  final double? hourlyRate;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoachProfileModel({
    required this.uid,
    required this.displayName,
    this.photoURL,
    this.bio,
    required this.specializations,
    required this.certifications,
    required this.isAcceptingClients,
    this.vanityCode,
    required this.clientCount,
    this.hourlyRate,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CoachProfileModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CoachProfileModel(
      uid: doc.id,
      displayName: data['display_name'] as String? ?? '',
      photoURL: data['photo_url'] as String?,
      bio: data['bio'] as String?,
      specializations: List<String>.from(data['specializations'] as List? ?? []),
      certifications: List<String>.from(data['certifications'] as List? ?? []),
      isAcceptingClients: data['is_accepting_clients'] as bool? ?? true,
      vanityCode: data['vanity_code'] as String?,
      clientCount: data['client_count'] as int? ?? 0,
      hourlyRate: (data['hourly_rate'] as num?)?.toDouble(),
      isPublic: data['is_public'] as bool? ?? true,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'display_name': displayName,
        'photo_url': photoURL,
        'bio': bio,
        'specializations': specializations,
        'certifications': certifications,
        'is_accepting_clients': isAcceptingClients,
        'vanity_code': vanityCode,
        'client_count': clientCount,
        'hourly_rate': hourlyRate,
        'is_public': isPublic,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
      };

  CoachProfileModel copyWith({
    String? uid,
    String? displayName,
    String? photoURL,
    String? bio,
    List<String>? specializations,
    List<String>? certifications,
    bool? isAcceptingClients,
    String? vanityCode,
    int? clientCount,
    double? hourlyRate,
    bool? isPublic,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      CoachProfileModel(
        uid: uid ?? this.uid,
        displayName: displayName ?? this.displayName,
        photoURL: photoURL ?? this.photoURL,
        bio: bio ?? this.bio,
        specializations: specializations ?? this.specializations,
        certifications: certifications ?? this.certifications,
        isAcceptingClients: isAcceptingClients ?? this.isAcceptingClients,
        vanityCode: vanityCode ?? this.vanityCode,
        clientCount: clientCount ?? this.clientCount,
        hourlyRate: hourlyRate ?? this.hourlyRate,
        isPublic: isPublic ?? this.isPublic,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
