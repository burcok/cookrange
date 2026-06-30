import 'package:cloud_firestore/cloud_firestore.dart';

/// Current version of the legal documents users consent against. Bump this when
/// the Privacy Policy / consent text materially changes — consents recorded
/// against an older version become "stale" and the user is re-prompted.
const String kLegalPolicyVersion = '2026-06-29';

/// A consentable processing purpose. Each maps to a Firestore doc id and to a
/// `consent.purpose.*` localization key. Order here = display order.
enum ConsentPurpose {
  healthData,
  location,
  aiProcessing,
  crossBorderTransfer,
  analytics,
  notifications,
  marketing,
}

extension ConsentPurposeX on ConsentPurpose {
  /// Stable Firestore document id (snake_case, never localized).
  String get docId => switch (this) {
        ConsentPurpose.healthData => 'health_data',
        ConsentPurpose.location => 'location',
        ConsentPurpose.aiProcessing => 'ai_processing',
        ConsentPurpose.crossBorderTransfer => 'cross_border_transfer',
        ConsentPurpose.analytics => 'analytics',
        ConsentPurpose.notifications => 'notifications',
        ConsentPurpose.marketing => 'marketing',
      };

  static ConsentPurpose? fromDocId(String id) {
    for (final p in ConsentPurpose.values) {
      if (p.docId == id) return p;
    }
    return null;
  }

  String get titleKey => 'consent.purpose.${docId}_title';
  String get descKey => 'consent.purpose.${docId}_desc';

  /// Whether withdrawing this consent blocks a core experience (shown as a note).
  bool get isSensitive => switch (this) {
        ConsentPurpose.healthData ||
        ConsentPurpose.location ||
        ConsentPurpose.aiProcessing ||
        ConsentPurpose.crossBorderTransfer =>
          true,
        _ => false,
      };
}

/// A single recorded consent decision (KVKK/GDPR accountability — demonstrable,
/// versioned, withdrawable). Stored at `users/{uid}/consents/{purpose.docId}`.
class ConsentModel {
  final ConsentPurpose purpose;
  final bool granted;
  final String policyVersion;
  final DateTime? updatedAt;

  const ConsentModel({
    required this.purpose,
    required this.granted,
    required this.policyVersion,
    this.updatedAt,
  });

  /// A not-yet-recorded consent for [purpose] (no decision made by the user).
  factory ConsentModel.unset(ConsentPurpose purpose) => ConsentModel(
        purpose: purpose,
        granted: false,
        policyVersion: '',
      );

  factory ConsentModel.fromFirestore(
      ConsentPurpose purpose, Map<String, dynamic> d) {
    final ts = d['updated_at'];
    return ConsentModel(
      purpose: purpose,
      granted: d['granted'] as bool? ?? false,
      policyVersion: d['policy_version'] as String? ?? '',
      updatedAt: ts is Timestamp ? ts.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'purpose': purpose.docId,
        'granted': granted,
        'policy_version': policyVersion,
        'updated_at': FieldValue.serverTimestamp(),
      };

  /// True if the user has never recorded a decision for this purpose.
  bool get isUnset => updatedAt == null && policyVersion.isEmpty;

  /// True if granted against an older policy version (needs re-consent).
  bool get isStale =>
      granted && !isUnset && policyVersion != kLegalPolicyVersion;
}
