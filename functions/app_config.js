'use strict';

// Faz A Faz 1 — server-side read path. Replaces index.js's old inline
// getAppConfig(), which read only app_config/global (5-min TTL, one doc).
//
// Reads app_config/global (LEGACY) + app_config/client + app_config/server,
// DEEP-merged (see deep_merge.js — a shallow spread would silently discard
// half of any group split across docs, e.g. `ai`). Still reading the
// legacy doc deliberately: nothing has migrated any real admin override
// off app_config/global yet (Faz 3 hasn't seeded the new docs), so
// dropping it now would silently lose whatever an admin has already set
// there in production. Removed in Faz 5 once migration is complete and
// observed.
//
// One shared cache, two TTLs selected per call: general callers get 60s
// (`BULK_TTL_MS`); money/kill-switch-relevant callers (aiProxy, the
// coach_report AI path in summaries.js) pass `{ fast: true }` for 5s. A
// single cache slot is correct here, not two: a `fast` caller forcing an
// early refresh benefits every other caller too (fresher data for free),
// and a `fast` call within a still-fresh window reuses exactly what a
// general caller would already be using.
//
// Deliberately NOT exposing app_config/critical through this module at
// all: nothing server-side reads maintenance/version/announcement/
// features/rollout today (those are pure client-UI concerns), so there is
// no consumer to build for yet. Add it here, following this same shape,
// the day a Cloud Function actually needs to consult a kill-switch.

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { deepMerge } = require('./deep_merge');

const BULK_TTL_MS = 60 * 1000;
const FAST_TTL_MS = 5 * 1000;

let _cache = null;
let _cacheAt = 0;

async function _fetchDoc(name) {
  try {
    const snap = await admin.firestore().collection('app_config').doc(name).get();
    return snap.exists ? (snap.data() || {}) : {};
  } catch (e) {
    functions.logger.warn(`app_config: failed to read app_config/${name} — treating as empty`, {
      error: e.message,
    });
    return {};
  }
}

async function _fetchMerged() {
  const [global, client, server] = await Promise.all([
    _fetchDoc('global'),
    _fetchDoc('client'),
    _fetchDoc('server'),
  ]);
  return deepMerge([global, client, server]);
}

/**
 * The merged app_config (global+client+server, deep-merged). Cached
 * BULK_TTL_MS by default; pass `{ fast: true }` for the 5s TTL used by
 * money/kill-switch-relevant call sites. Fails safe to the previous cache
 * (or `{}` if there has never been one) — a transient Firestore error here
 * must never crash a caller that just wants a config value with a default.
 */
async function getConfig({ fast = false } = {}) {
  const now = Date.now();
  const ttl = fast ? FAST_TTL_MS : BULK_TTL_MS;
  if (_cache && now - _cacheAt < ttl) {
    return _cache;
  }
  try {
    _cache = await _fetchMerged();
    _cacheAt = now;
  } catch (e) {
    functions.logger.warn('app_config.getConfig failed — keeping previous cache', {
      error: e.message,
    });
    _cache = _cache || {};
  }
  return _cache;
}

module.exports = { getConfig };
