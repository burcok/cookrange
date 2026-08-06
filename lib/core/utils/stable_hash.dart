import 'dart:convert';

/// FNV-1a 32-bit hash — deterministic across Dart/JS/Wasm and reproducible
/// server-side, unlike `String.hashCode` (which the Dart language spec does
/// NOT guarantee stable across runtimes/restarts).
///
/// Replaces `'$feature:$uid'.hashCode` in `AppConfigService.isInRollout`
/// (see DECISIONS.md ADR-023). The real defect that motivated this wasn't
/// instability across app restarts — it was that a Cloud Function could
/// never reproduce the same rollout bucket a client computed, so a user
/// could end up inside a gradual rollout on the client and outside it on
/// the server for the same feature. Mirrored exactly in
/// `functions/stable_hash.js`; both are asserted against the SAME vector
/// table in their respective test files — that shared table is what keeps
/// the two implementations honest.
int fnv1a32(String input) {
  const fnvOffsetBasis = 0x811c9dc5;
  const fnvPrime = 0x01000193;
  var hash = fnvOffsetBasis;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}
