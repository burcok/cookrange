'use strict';

// FNV-1a 32-bit hash — mirrors lib/core/utils/stable_hash.dart exactly.
// See that file's doc comment (and PLAN.md Faz A §A3) for why this exists:
// a Cloud Function must be able to reproduce the exact same rollout bucket
// a client computed for `AppConfigService.isInRollout`, which Dart's
// String.hashCode cannot guarantee.

const FNV_OFFSET_BASIS = 0x811c9dc5;
const FNV_PRIME = 0x01000193;

function fnv1a32(input) {
  let hash = FNV_OFFSET_BASIS;
  const bytes = Buffer.from(input, 'utf8');
  for (let i = 0; i < bytes.length; i++) {
    hash ^= bytes[i];
    hash = Math.imul(hash, FNV_PRIME) >>> 0;
  }
  return hash;
}

module.exports = { fnv1a32 };
