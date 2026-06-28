import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum GymSubscriptionTier { free, standard, premium }

extension GymSubscriptionTierX on GymSubscriptionTier {
  String get firestoreValue => name;
  String get displayName => switch (this) {
        GymSubscriptionTier.free => 'Free',
        GymSubscriptionTier.standard => 'Standard',
        GymSubscriptionTier.premium => 'Premium',
      };

  static GymSubscriptionTier fromString(String? value) => switch (value) {
        'standard' => GymSubscriptionTier.standard,
        'premium' => GymSubscriptionTier.premium,
        _ => GymSubscriptionTier.free,
      };
}

class GymModel {
  final String id;
  final String ownerUid;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? address;
  final String? city;
  final String? district;
  final String? country;
  final bool isPublic;
  final int memberCount;
  final GymSubscriptionTier subscriptionTier;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? latitude;
  final double? longitude;
  final int checkInRadius;
  final String? qrToken;
  final DateTime? qrTokenExpiresAt;
  final String? brandColor;

  const GymModel({
    required this.id,
    required this.ownerUid,
    required this.name,
    this.description,
    this.logoUrl,
    this.address,
    this.city,
    this.district,
    this.country,
    required this.isPublic,
    required this.memberCount,
    required this.subscriptionTier,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.checkInRadius = 100,
    this.qrToken,
    this.qrTokenExpiresAt,
    this.brandColor,
  });

  factory GymModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime ts(dynamic v) =>
        v is Timestamp ? v.toDate() : DateTime.now();

    return GymModel(
      id: doc.id,
      ownerUid: d['owner_uid'] as String? ?? '',
      name: d['name'] as String? ?? '',
      description: d['description'] as String?,
      logoUrl: d['logo_url'] as String?,
      address: d['address'] as String?,
      city: d['city'] as String?,
      district: d['district'] as String?,
      country: d['country'] as String?,
      isPublic: d['is_public'] as bool? ?? true,
      memberCount: d['member_count'] as int? ?? 0,
      subscriptionTier: GymSubscriptionTierX.fromString(
          d['subscription_tier'] as String?),
      tags: List<String>.from(d['tags'] as List? ?? []),
      createdAt: ts(d['created_at']),
      updatedAt: ts(d['updated_at']),
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      checkInRadius: d['check_in_radius'] as int? ?? 100,
      qrToken: d['qr_token'] as String?,
      qrTokenExpiresAt: d['qr_token_expires_at'] is Timestamp
          ? (d['qr_token_expires_at'] as Timestamp).toDate()
          : null,
      brandColor: d['brand_color'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'owner_uid': ownerUid,
        'name': name,
        if (description != null) 'description': description,
        if (logoUrl != null) 'logo_url': logoUrl,
        if (address != null) 'address': address,
        if (city != null) 'city': city,
        if (district != null) 'district': district,
        if (country != null) 'country': country,
        'is_public': isPublic,
        'member_count': memberCount,
        'subscription_tier': subscriptionTier.firestoreValue,
        'tags': tags,
        'created_at': Timestamp.fromDate(createdAt),
        'updated_at': Timestamp.fromDate(updatedAt),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        'check_in_radius': checkInRadius,
        if (brandColor != null) 'brand_color': brandColor,
      };

  GymModel copyWith({
    String? name,
    String? description,
    String? logoUrl,
    String? address,
    String? city,
    String? district,
    String? country,
    bool? isPublic,
    int? memberCount,
    GymSubscriptionTier? subscriptionTier,
    List<String>? tags,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    int? checkInRadius,
    String? qrToken,
    DateTime? qrTokenExpiresAt,
    String? brandColor,
  }) =>
      GymModel(
        id: id,
        ownerUid: ownerUid,
        name: name ?? this.name,
        description: description ?? this.description,
        logoUrl: logoUrl ?? this.logoUrl,
        address: address ?? this.address,
        city: city ?? this.city,
        district: district ?? this.district,
        country: country ?? this.country,
        isPublic: isPublic ?? this.isPublic,
        memberCount: memberCount ?? this.memberCount,
        subscriptionTier: subscriptionTier ?? this.subscriptionTier,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        checkInRadius: checkInRadius ?? this.checkInRadius,
        qrToken: qrToken ?? this.qrToken,
        qrTokenExpiresAt: qrTokenExpiresAt ?? this.qrTokenExpiresAt,
        brandColor: brandColor ?? this.brandColor,
      );

  String get locationDisplay {
    final parts = [city, country].where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }

  bool get hasLocation => latitude != null && longitude != null;

  bool get qrValid =>
      qrToken != null &&
      qrTokenExpiresAt != null &&
      qrTokenExpiresAt!.isAfter(DateTime.now());
}

extension GymModelBrandingX on GymModel {
  Color get resolvedBrandColor {
    if (brandColor != null) {
      final parsed = int.tryParse(brandColor!);
      if (parsed != null) return Color(parsed);
    }
    return const Color(0xFFF97300);
  }
}
