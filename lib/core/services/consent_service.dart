import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/consent_model.dart';
import 'auth_service.dart';
import 'crashlytics_service.dart';

/// Records and exposes the user's per-purpose consent decisions for KVKK/GDPR
/// accountability — demonstrable (timestamped + policy-versioned), withdrawable,
/// and surfaced in one place (the Consent Center).
///
/// Source of truth: `users/{uid}/consents/{purpose.docId}` (owner-only).
class ConsentService {
  static final ConsentService _instance = ConsentService._internal();
  factory ConsentService() => _instance;
  ConsentService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _auth = AuthService();

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('consents');

  /// Live stream of all consent decisions, keyed by purpose. Purposes with no
  /// recorded decision yet resolve to [ConsentModel.unset].
  Stream<Map<ConsentPurpose, ConsentModel>> watchConsents() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _col(uid).snapshots().map((snap) {
      final map = <ConsentPurpose, ConsentModel>{
        for (final p in ConsentPurpose.values) p: ConsentModel.unset(p),
      };
      for (final doc in snap.docs) {
        final purpose = ConsentPurposeX.fromDocId(doc.id);
        if (purpose != null) {
          map[purpose] = ConsentModel.fromFirestore(purpose, doc.data());
        }
      }
      return map;
    });
  }

  /// One-shot read of all consents (e.g. for gating checks at feature entry).
  Future<Map<ConsentPurpose, ConsentModel>> getConsents() async {
    final uid = _uid;
    final map = <ConsentPurpose, ConsentModel>{
      for (final p in ConsentPurpose.values) p: ConsentModel.unset(p),
    };
    if (uid == null) return map;
    try {
      final snap = await _col(uid).get();
      for (final doc in snap.docs) {
        final purpose = ConsentPurposeX.fromDocId(doc.id);
        if (purpose != null) {
          map[purpose] = ConsentModel.fromFirestore(purpose, doc.data());
        }
      }
    } catch (e, st) {
      debugPrint('ConsentService.getConsents error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'ConsentService.getConsents'));
    }
    return map;
  }

  /// Whether the user has actively granted [purpose] against the current policy
  /// version. Stale or unset consents return false (so callers re-prompt).
  Future<bool> hasConsent(ConsentPurpose purpose) async {
    final uid = _uid;
    if (uid == null) return false;
    try {
      final doc = await _col(uid).doc(purpose.docId).get();
      if (!doc.exists) return false;
      final model = ConsentModel.fromFirestore(purpose, doc.data()!);
      return model.granted && !model.isStale;
    } catch (e) {
      debugPrint('ConsentService.hasConsent error: $e');
      return false;
    }
  }

  /// Records the consent decisions captured at registration in one batch.
  /// Essential purposes (health data, AI, cross-border) are required to use the
  /// app and are granted here; analytics + marketing are optional opt-ins.
  /// Location + notifications stay unset (consented at point of use).
  Future<void> recordInitialConsents({
    bool analytics = false,
    bool marketing = false,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final batch = _db.batch();
      void put(ConsentPurpose p, bool granted) {
        batch.set(
          _col(uid).doc(p.docId),
          ConsentModel(
                  purpose: p, granted: granted, policyVersion: kLegalPolicyVersion)
              .toFirestore(),
        );
      }

      put(ConsentPurpose.healthData, true);
      put(ConsentPurpose.aiProcessing, true);
      put(ConsentPurpose.crossBorderTransfer, true);
      put(ConsentPurpose.analytics, analytics);
      put(ConsentPurpose.marketing, marketing);
      await batch.commit();
      debugPrint('Initial consents recorded @ $kLegalPolicyVersion '
          '(analytics=$analytics, marketing=$marketing)');
      unawaited(CrashlyticsService().log('consent.initial_recorded'));
    } catch (e, st) {
      debugPrint('ConsentService.recordInitialConsents error: $e');
      unawaited(CrashlyticsService().recordError(e, st,
          reason: 'ConsentService.recordInitialConsents'));
    }
  }

  /// Records (or withdraws) consent for [purpose], stamping the current policy
  /// version + server time. This is the auditable consent event.
  Future<void> setConsent(ConsentPurpose purpose, bool granted) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final model = ConsentModel(
        purpose: purpose,
        granted: granted,
        policyVersion: kLegalPolicyVersion,
      );
      await _col(uid).doc(purpose.docId).set(model.toFirestore());
      debugPrint(
          'Consent ${granted ? "granted" : "withdrawn"}: ${purpose.docId} @ $kLegalPolicyVersion');
      unawaited(CrashlyticsService().log(
          'consent.${granted ? "grant" : "withdraw"}.${purpose.docId}'));
    } catch (e, st) {
      debugPrint('ConsentService.setConsent error: $e');
      unawaited(CrashlyticsService()
          .recordError(e, st, reason: 'ConsentService.setConsent'));
      rethrow;
    }
  }
}
