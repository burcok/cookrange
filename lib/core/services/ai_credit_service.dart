import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/ai_credit_model.dart';
import 'analytics_service.dart';

/// Reads the user's AI-credit state from the **server-only** ledger
/// `ai_credits/{uid}`.
///
/// All authoritative logic — daily reset, quota check, consumption, bonus-credit
/// grants — happens SERVER-SIDE (the `aiProxy` and purchase-validation Cloud
/// Functions). The Firestore rule makes `ai_credits/{uid}` owner-READ but
/// deny-WRITE, so this client can show the credit badge and avoid firing a
/// request it knows will 402, but it can never grant or mutate credits.
///
/// Ledger fields (written by the server): `used_today`, `reset_at`, `bonus`.
class AiCreditService {
  static final AiCreditService _i = AiCreditService._();
  factory AiCreditService() => _i;
  AiCreditService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _ledger(String uid) =>
      _db.collection('ai_credits').doc(uid);

  /// Reads the current credit state for [uid]. Returns a fresh model when no
  /// ledger exists yet (server creates it on first AI call).
  Future<AiCreditModel> getCredits(String uid, {bool isPremium = false}) async {
    try {
      final snap = await _ledger(uid).get();
      final data = snap.data();
      if (data == null) return AiCreditModel.fresh(isPremium: isPremium);
      return AiCreditModel.fromFirestore(data, isPremium: isPremium);
    } catch (e) {
      debugPrint('[AiCreditService] getCredits error: $e');
      return AiCreditModel.fresh(isPremium: isPremium);
    }
  }

  /// Returns `true` if the user *appears* to have credits left, so the UI can
  /// avoid firing a request that would 402. This is advisory only — the server
  /// performs the authoritative atomic check + consumption in `aiProxy`.
  Future<bool> checkAndConsume(String uid, bool isPremium) async {
    final credits = await getCredits(uid, isPremium: isPremium);
    if (credits.isExhausted) {
      debugPrint('[AiCreditService] uid=$uid — limit reached '
          '(used=${credits.used}, bonus=${credits.bonus}, isPremium=$isPremium)');
      unawaited(AnalyticsService().logEvent(
        name: 'credit_exhausted',
        parameters: {'uid': uid, 'is_premium': isPremium},
      ));
      return false;
    }
    return true;
  }

  /// No-op: the server rolls back its own ledger on upstream AI failure. Kept
  /// for call-site compatibility with the screens that consume credits.
  Future<void> rollbackCredit(String uid) async {}

  /// No-op: see [rollbackCredit].
  Future<void> rollbackBonusCredit(String uid) async {}

  /// Live stream of the user's credit state — used by the credit badge/sheet.
  Stream<AiCreditModel> getCreditsStream(String uid, {bool isPremium = false}) {
    return _ledger(uid).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return AiCreditModel.fresh(isPremium: isPremium);
      return AiCreditModel.fromFirestore(data, isPremium: isPremium);
    });
  }
}
