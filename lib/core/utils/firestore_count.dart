import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Live-ish count of [query] via the cheap `count()` aggregation, polled every
/// [interval] — instead of a whole-collection `.snapshots()` listener that
/// re-reads every matching document on every change.
///
/// `count()` is billed at ~1 read per 1000 docs counted, so this is dramatically
/// cheaper for badges/labels that only need a number (admin counts, member
/// counts, etc.). Use a real `.snapshots()` only when you actually render the
/// documents. The first value is emitted immediately.
Stream<int> pollCount(
  Query<Object?> query, {
  Duration interval = const Duration(seconds: 45),
}) async* {
  while (true) {
    try {
      final snap = await query.count().get();
      yield snap.count ?? 0;
    } catch (_) {
      yield 0;
    }
    await Future<void>.delayed(interval);
  }
}
