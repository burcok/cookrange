import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// Triggers idempotent, server-side seeding of demo marketplace programs on
/// first install.
///
/// BLK-09 fix: this used to write directly to Firestore's public `programs`
/// collection (`coach_uid: 'demo'`), gated only by a firestore.rules bypass
/// that could not distinguish "the real seeder" from "an attacker copying
/// the same write" — any authenticated user could inject arbitrary fake
/// "Cookrange Team" marketplace listings. The actual seeding (fixed
/// content, idempotent via the `seeds/demo` marker doc) now happens
/// entirely server-side in the `seedDemoContent` Cloud Function
/// (functions/demo_content.js) via the Admin SDK; this class only invokes
/// it. firestore.rules' `programs`/`weeks`/`seeds` client-write bypasses
/// are removed alongside this.
class DemoContentSeeder {
  static final _instance = DemoContentSeeder._internal();
  factory DemoContentSeeder() => _instance;
  DemoContentSeeder._internal();

  Future<void> seedIfEmpty() async {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('seedDemoContent')
          .call();
      debugPrint('DemoContentSeeder: seedDemoContent result=${result.data}');
    } catch (e) {
      // Non-fatal — mirrors the retired client-write version's own posture
      // (a demo-content seeding failure must never block app startup).
      debugPrint('DemoContentSeeder: seedDemoContent call failed (non-fatal) — $e');
    }
  }
}
