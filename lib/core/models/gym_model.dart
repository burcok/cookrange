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
  final String? brandColor;
  final bool isVerified;

  /// Per-weekday opening hours. Keys are lowercase 3-letter English weekday
  /// abbreviations (`mon`, `tue`, `wed`, `thu`, `fri`, `sat`, `sun`). Each
  /// value is either `null` (closed that day) or a map
  /// `{"open": "HH:mm", "close": "HH:mm"}` (24h, local time, zero-padded).
  ///
  /// Example:
  /// ```json
  /// {
  ///   "mon": {"open": "07:00", "close": "23:00"},
  ///   "tue": {"open": "07:00", "close": "23:00"},
  ///   "sun": null
  /// }
  /// ```
  /// A day that is missing from the map is treated the same as `null`
  /// (closed / not configured). Produced by the opening-hours step in
  /// gym_setup_screen.dart.
  final Map<String, dynamic>? openingHours;

  /// Max concurrent members the owner considers "full" — used to compute an
  /// occupancy percentage. Optional; the owner may not set one.
  final int? capacity;

  /// How many members are inside RIGHT NOW (Faz 1 §1.4/1.5/1.6). Server-only
  /// — written exclusively by `recordPresenceEvent`'s transaction
  /// (`functions/presence.js`); `firestore.rules`' `touchesProtectedGymFields()`
  /// denies the owner's otherwise-blanket update rule from touching it
  /// directly, same as `reputation_score`/`achievements` elsewhere. Stays at
  /// 0 until the Faz 1 §1.2 client geofence trigger is actually shipped.
  final int liveOccupancy;

  /// Gym owner's own opt-in for whether automatic background check-in
  /// detection (geofencing) is offered to their members at all. Defaults to
  /// `false` — existing gyms created before this field existed must not
  /// suddenly have it enabled.
  final bool geofenceEnabled;

  /// Gym's public contact phone number, carried over from the approved
  /// [GymApplicationModel.contactPhone] (see AdminService.approveGymApplication).
  final String? contactPhone;

  /// How many signups this gym's own invite codes (`referrals/{code}` with
  /// `type: 'gym'`) have ever attributed (Faz 6 §6.5) — bumped exclusively by
  /// `applyReferral`'s gym-attribution transaction (`functions/economy.js`).
  /// Deliberately a SEPARATE counter from [memberCount]: redeeming an invite
  /// code attributes a signup to this gym's marketing, it does not make that
  /// person a gym MEMBER (a distinct, explicit `joinGym` action). Server-only
  /// — `touchesProtectedGymFields()` (firestore.rules) denies the owner's
  /// otherwise-blanket update rule from touching it directly, same as
  /// [liveOccupancy].
  final int attributedMemberCount;

  /// How many DISTINCT attributed users have ever converted to a real,
  /// validated premium purchase at least once (Faz 6 §6.6) — bumped
  /// exclusively by `maybeAwardGymCommission` on a user's FIRST premium
  /// purchase after attribution (never again on renewal; contrast with
  /// `gym_attributions/{uid}.lifetime_commission_try`, which accrues every
  /// purchase). Server-only, same protection as [attributedMemberCount].
  final int attributedPremiumCount;

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
    this.brandColor,
    this.isVerified = false,
    this.openingHours,
    this.capacity,
    this.liveOccupancy = 0,
    this.geofenceEnabled = false,
    this.contactPhone,
    this.attributedMemberCount = 0,
    this.attributedPremiumCount = 0,
  });

  factory GymModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    DateTime ts(dynamic v) => v is Timestamp ? v.toDate() : DateTime.now();

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
      subscriptionTier:
          GymSubscriptionTierX.fromString(d['subscription_tier'] as String?),
      tags: List<String>.from(d['tags'] as List? ?? []),
      createdAt: ts(d['created_at']),
      updatedAt: ts(d['updated_at']),
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      checkInRadius: d['check_in_radius'] as int? ?? 100,
      // Faz 0 §0.7: qr_token/qr_token_expires_at moved off this public doc
      // to gyms/{gymId}/private/qr_token (owner/admin-read-only) — see
      // GymQrToken / GymService.getQrTokenStream. No longer parsed here.
      brandColor: d['brand_color'] as String?,
      isVerified: d['is_verified'] as bool? ?? false,
      openingHours: d['opening_hours'] as Map<String, dynamic>?,
      capacity: d['capacity'] as int?,
      liveOccupancy: d['live_occupancy'] as int? ?? 0,
      // Faz 1.1: must default false on absence — existing gyms created
      // before this field existed must not suddenly opt in to background
      // geofence check-in detection just because the field is missing.
      geofenceEnabled: d['geofence_enabled'] as bool? ?? false,
      contactPhone: d['contact_phone'] as String?,
      attributedMemberCount: d['attributed_member_count'] as int? ?? 0,
      attributedPremiumCount: d['attributed_premium_count'] as int? ?? 0,
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
        if (openingHours != null) 'opening_hours': openingHours,
        if (capacity != null) 'capacity': capacity,
        'live_occupancy': liveOccupancy,
        'geofence_enabled': geofenceEnabled,
        if (contactPhone != null) 'contact_phone': contactPhone,
        'attributed_member_count': attributedMemberCount,
        'attributed_premium_count': attributedPremiumCount,
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
    String? brandColor,
    Map<String, dynamic>? openingHours,
    int? capacity,
    int? liveOccupancy,
    bool? geofenceEnabled,
    String? contactPhone,
    int? attributedMemberCount,
    int? attributedPremiumCount,
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
        brandColor: brandColor ?? this.brandColor,
        isVerified: isVerified,
        openingHours: openingHours ?? this.openingHours,
        capacity: capacity ?? this.capacity,
        liveOccupancy: liveOccupancy ?? this.liveOccupancy,
        geofenceEnabled: geofenceEnabled ?? this.geofenceEnabled,
        contactPhone: contactPhone ?? this.contactPhone,
        attributedMemberCount:
            attributedMemberCount ?? this.attributedMemberCount,
        attributedPremiumCount:
            attributedPremiumCount ?? this.attributedPremiumCount,
      );

  String get locationDisplay {
    final parts = [city, country].where((p) => p != null && p.isNotEmpty);
    return parts.join(', ');
  }

  bool get hasLocation => latitude != null && longitude != null;

  /// Occupancy as a 0-100+ percentage of [capacity]. Null if no capacity was
  /// set (nothing to divide by) — callers should show the raw count instead.
  int? get occupancyPercent {
    final cap = capacity;
    if (cap == null || cap <= 0) return null;
    return ((liveOccupancy / cap) * 100).round();
  }
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
