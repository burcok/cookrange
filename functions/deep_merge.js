'use strict';

// Recursively merges objects left-to-right — a later object's LEAF values
// win, but a later object's nested object only overrides the keys it
// actually specifies, never wholesale-replacing a sibling subtree an
// earlier object contributed.
//
// Used by app_config.js to merge app_config/global + app_config/client +
// app_config/server. A plain `{...a, ...b}` spread is NOT sufficient
// there: three schema groups are genuinely split across more than one
// document (`ai`: client+server; `gamification`: client+server; `client`:
// client+critical — see config_schema.json's per-key `doc` assignment), so
// a shallow merge would let a later, partial `ai` object silently discard
// every `ai.*` sub-field an earlier object had that the later one doesn't
// mention. Mirrors lib/core/utils/deep_merge.dart's identical
// deepMergeMaps exactly — the two must agree, since both merge the SAME
// Firestore documents (the client merges global+client+critical; the
// server merges global+client+server).

function isPlainObject(v) {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

function deepMerge(objects) {
  const result = {};
  for (const obj of objects) {
    if (!isPlainObject(obj)) continue;
    for (const [key, incoming] of Object.entries(obj)) {
      const existing = result[key];
      if (isPlainObject(existing) && isPlainObject(incoming)) {
        result[key] = deepMerge([existing, incoming]);
      } else {
        result[key] = incoming;
      }
    }
  }
  return result;
}

module.exports = { deepMerge };
