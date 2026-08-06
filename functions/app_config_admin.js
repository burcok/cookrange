'use strict';

// Faz A Faz 2 — the safe write path for app_config/{critical,client,server}.
// Replaces the client-direct `set(..., merge: true)` write
// (lib/core/services/admin_service.dart's updateAppConfig, gated only by
// firestore.rules' `allow write: if isAdmin()`) with a validated callable —
// see this repo's DECISIONS.md ADR-023 for the full design rationale. Once
// this ships, firestore.rules sets every app_config/* doc to
// `write: if false`: THIS callable becomes the only path, for anyone,
// admin included.
//
// `app_config/global` (the legacy doc) is deliberately NOT writable
// through this callable — it isn't a `doc` value in config_schema.json at
// all, and Faz 3 is what seeds real data into `critical`/`client`/`server`
// to replace it.
//
// UPDATE (Faz A Faz 4): the note this replaced said the existing Flutter
// config screen (lib/screens/admin/admin_app_config_screen.dart) would
// keep writing `global` directly "until [Faz 3 seeding + this rules
// change] has actually happened in production" — but firestore.rules
// denies every `app_config/*` write unconditionally as of THIS callable
// shipping, regardless of what has or hasn't happened in production yet;
// there is no such grace window. That screen's own writer
// (AdminService.updateAppConfig) has since been rewired to call THIS
// callable directly (split per-doc via the schema's own `doc` field) —
// it was flagged and fixed as a live regression, not left broken until
// the real web admin panel (DECISIONS.md ADR-024) replaces it.

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { assertCallable } = require('./notifications');
const { checkAndBumpSlidingWindow } = require('./rate_limit');
const schema = require('./config_schema.json');

const VALID_DOCS = ['critical', 'client', 'server'];
const LARGE_CHANGE_RATIO = 0.5; // ±50%
const CONFIG_WRITE_WINDOW_MS = 10 * 60 * 1000;
const CONFIG_WRITE_MAX_IN_WINDOW = 10;

function schemaEntriesForDoc(doc) {
  const out = new Map();
  for (const [key, entry] of Object.entries(schema)) {
    if (key === '_meta' || entry.doc !== doc) continue;
    out.set(key, entry);
  }
  return out;
}

// Unflattens a dotted schema key ('ai.free_daily_limit') into `target`'s
// nested shape — the reverse of how config_schema.json's keys are
// authored, and the actual Firestore storage shape (nested maps, matching
// the pre-existing app_config/global convention — see DECISIONS.md ADR-023).
function setNestedValue(target, dottedKey, value) {
  const parts = dottedKey.split('.');
  let node = target;
  for (let i = 0; i < parts.length - 1; i++) {
    const part = parts[i];
    if (typeof node[part] !== 'object' || node[part] === null || Array.isArray(node[part])) {
      node[part] = {};
    }
    node = node[part];
  }
  node[parts[parts.length - 1]] = value;
}

function getNestedValue(obj, dottedKey) {
  const parts = dottedKey.split('.');
  let node = obj;
  for (const part of parts) {
    if (node === null || typeof node !== 'object') return undefined;
    node = node[part];
  }
  return node;
}

async function isAdminUid(db, uid) {
  const snap = await db.collection('admin_roles').doc(uid).get();
  return snap.exists && snap.data().is_admin === true;
}

/** Throws HttpsError('invalid-argument', ...) on the first violation. */
function validateType(key, entry, value) {
  switch (entry.type) {
    case 'bool':
      if (typeof value !== 'boolean') {
        throw new functions.https.HttpsError('invalid-argument', `${key}: expected a bool`);
      }
      break;
    case 'int':
      if (typeof value !== 'number' || !Number.isInteger(value)) {
        throw new functions.https.HttpsError('invalid-argument', `${key}: expected an integer`);
      }
      break;
    case 'double':
      if (typeof value !== 'number' || !Number.isFinite(value)) {
        throw new functions.https.HttpsError('invalid-argument', `${key}: expected a number`);
      }
      break;
    case 'string':
      if (typeof value !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', `${key}: expected a string`);
      }
      break;
    case 'enum':
      if (typeof value !== 'string' || !Array.isArray(entry.enum) || !entry.enum.includes(value)) {
        throw new functions.https.HttpsError(
          'invalid-argument', `${key}: expected one of ${JSON.stringify(entry.enum || [])}`,
        );
      }
      break;
    case 'string_list':
      if (!Array.isArray(value) || !value.every((v) => typeof v === 'string')) {
        throw new functions.https.HttpsError('invalid-argument', `${key}: expected a list of strings`);
      }
      break;
    default:
      if (entry.type.startsWith('map<') || entry.type === 'object') {
        if (value === null || typeof value !== 'object' || Array.isArray(value)) {
          throw new functions.https.HttpsError('invalid-argument', `${key}: expected an object`);
        }
      } else {
        throw new functions.https.HttpsError('invalid-argument', `${key}: unknown schema type "${entry.type}"`);
      }
  }
  if (typeof value === 'number') {
    if (typeof entry.min === 'number' && value < entry.min) {
      throw new functions.https.HttpsError('invalid-argument', `${key}: below minimum ${entry.min}`);
    }
    if (typeof entry.max === 'number' && value > entry.max) {
      throw new functions.https.HttpsError('invalid-argument', `${key}: above maximum ${entry.max}`);
    }
  }
}

/**
 * One field of a `value_shape.fields` descriptor (see config_schema.json's
 * own `value_shape` doc in `_meta.fields`), checked against one leaf value.
 * Deliberately a small, closed set of primitive types (int/double/string/
 * enum) — this exists to catch a wrong LEAF type inside an object/map field
 * (M3.5's own motivating example: `purchases.products`'s `days` arriving as
 * the string `"31"` instead of the int `31`), not to become a second,
 * parallel JSON-Schema implementation.
 */
function validateShapeField(key, fieldName, fieldSpec, value) {
  const path = `${key}.${fieldName}`;
  if (value === undefined) {
    if (!fieldSpec.optional) {
      throw new functions.https.HttpsError('invalid-argument', `${path}: required field is missing`);
    }
    return;
  }
  if (value === null) {
    if (!fieldSpec.nullable) {
      throw new functions.https.HttpsError('invalid-argument', `${path}: null is not allowed here`);
    }
    return;
  }
  switch (fieldSpec.type) {
    case 'int':
      if (typeof value !== 'number' || !Number.isInteger(value)) {
        throw new functions.https.HttpsError('invalid-argument', `${path}: expected an integer`);
      }
      break;
    case 'double':
      if (typeof value !== 'number' || !Number.isFinite(value)) {
        throw new functions.https.HttpsError('invalid-argument', `${path}: expected a number`);
      }
      break;
    case 'string':
      if (typeof value !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', `${path}: expected a string`);
      }
      break;
    case 'enum':
      if (typeof value !== 'string' || !Array.isArray(fieldSpec.enum) || !fieldSpec.enum.includes(value)) {
        throw new functions.https.HttpsError(
          'invalid-argument', `${path}: expected one of ${JSON.stringify(fieldSpec.enum || [])}`,
        );
      }
      break;
    default:
      throw new functions.https.HttpsError('invalid-argument', `${path}: unknown value_shape field type "${fieldSpec.type}"`);
  }
  if (typeof value === 'number') {
    if (typeof fieldSpec.min === 'number' && value < fieldSpec.min) {
      throw new functions.https.HttpsError('invalid-argument', `${path}: below minimum ${fieldSpec.min}`);
    }
    if (typeof fieldSpec.max === 'number' && value > fieldSpec.max) {
      throw new functions.https.HttpsError('invalid-argument', `${path}: above maximum ${fieldSpec.max}`);
    }
  }
}

// Every key in `obj` must be declared in `shape.fields` — not just every
// declared field being present. A typo'd key (e.g. `lockMS` instead of
// `lockMs`) would otherwise pass silently as an "extra" key while the real
// `lockMs` field falls back to missing-but-optional-or-not, which is a much
// more confusing failure mode than rejecting the typo outright.
function validateFixedObjectAgainstShape(key, shape, obj) {
  for (const [fieldName, fieldSpec] of Object.entries(shape.fields)) {
    validateShapeField(key, fieldName, fieldSpec, obj[fieldName]);
  }
  for (const presentKey of Object.keys(obj)) {
    if (!Object.prototype.hasOwnProperty.call(shape.fields, presentKey)) {
      throw new functions.https.HttpsError('invalid-argument', `${key}: unexpected field "${presentKey}"`);
    }
  }
}

/**
 * Enforces `entry.value_shape` (present on exactly the 15 object/
 * map<string,object> schema entries that have one — the other ~114 scalar/
 * array entries have no value_shape and this is a no-op for them). Runs
 * AFTER validateType has already confirmed `value` is at least an object —
 * this only ever sees something validateType already accepted.
 *
 *   kind: "fixed_object" — `value` itself must match `shape.fields`
 *     (the 10 moderation.*_rate_limit entries, cost.pricing).
 *   kind: "map_of_fixed_object" — `value`'s KEYS are arbitrary (a model
 *     name, a store product ID, an XP event name); each of `value`'s
 *     VALUES must match `shape.fields` (ai.model_pricing, purchases.
 *     products, gamification.xp_table, engagement.credit_table).
 *
 * Known simplification: purchases.products' real shape has `kind`-
 * conditional required fields (subscription needs tier+days, consumable
 * needs bonusCredits) that this does not enforce — every field for that
 * entry is declared `optional` instead, so a same-shape mix-up (a
 * consumable missing bonusCredits) still passes. What this DOES catch is
 * the concrete gap the plan called out: a wrong LEAF TYPE, e.g. `days`
 * arriving as `"31"` instead of `31`.
 */
function validateValueShape(key, entry, value) {
  const shape = entry.value_shape;
  if (!shape) return;
  if (shape.kind === 'fixed_object') {
    validateFixedObjectAgainstShape(key, shape, value);
    return;
  }
  if (shape.kind === 'map_of_fixed_object') {
    for (const [mapKey, mapValue] of Object.entries(value)) {
      const path = `${key}.${mapKey}`;
      if (mapValue === null || typeof mapValue !== 'object' || Array.isArray(mapValue)) {
        throw new functions.https.HttpsError('invalid-argument', `${path}: expected an object`);
      }
      validateFixedObjectAgainstShape(path, shape, mapValue);
    }
    return;
  }
  throw new functions.https.HttpsError('invalid-argument', `${key}: unknown value_shape.kind "${shape.kind}"`);
}

// Cross-field invariants no per-field rule can catch — checked against the
// RESULTING full document (current data + patch applied), since a rule
// can depend on a field this particular patch doesn't even touch. See each
// invariant's corresponding config_schema.json entry note for why it
// exists.
function crossFieldInvariantErrors(nextData) {
  const errors = [];

  const free = getNestedValue(nextData, 'ai.free_daily_limit');
  const premium = getNestedValue(nextData, 'ai.premium_daily_limit');
  if (typeof free === 'number' && typeof premium === 'number' && premium < free) {
    errors.push('ai.premium_daily_limit must be >= ai.free_daily_limit');
  }

  const quietStart = getNestedValue(nextData, 'presence.quiet_hours_start');
  const quietEnd = getNestedValue(nextData, 'presence.quiet_hours_end');
  if (typeof quietStart === 'number' && typeof quietEnd === 'number' && quietStart >= quietEnd) {
    errors.push('presence.quiet_hours_start must be < presence.quiet_hours_end');
  }

  const textModel = getNestedValue(nextData, 'ai.text_model');
  const allowedModels = getNestedValue(nextData, 'ai.allowed_models');
  if (textModel && Array.isArray(allowedModels) && allowedModels.length > 0
      && !allowedModels.includes(textModel)) {
    errors.push('ai.text_model must be a member of ai.allowed_models when that list is non-empty');
  }

  const tierFloor = getNestedValue(nextData, 'gamification.tier_level_floor');
  if (tierFloor && typeof tierFloor === 'object') {
    const order = ['newcomer', 'active', 'contributor', 'expert', 'legend'];
    let prevValue = -Infinity;
    for (const tier of order) {
      const v = tierFloor[tier];
      if (typeof v !== 'number') continue;
      if (v <= prevValue) {
        errors.push('gamification.tier_level_floor must be strictly ascending, newcomer through legend');
        break;
      }
      prevValue = v;
    }
  }

  return errors;
}

async function requireAdmin(db, context) {
  const callerUid = assertCallable(context);
  // Checked TWICE: the custom claim (may be up to ~1h stale after
  // revocation — Firebase ID tokens are cached client-side) AND a live
  // admin_roles read (cannot be stale — see docs/SECURITY.md's admin
  // model). Neither check alone is sufficient on its own for a write this
  // sensitive.
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'not_admin');
  }
  if (!(await isAdminUid(db, callerUid))) {
    throw new functions.https.HttpsError('permission-denied', 'not_admin');
  }
  return callerUid;
}

async function requireWriteNotRateLimited(db, callerUid) {
  // Prevents a compromised admin session (or a UI bug) from
  // broadcast-storming app_config/critical, which carries a realtime
  // listener on every device.
  const { limited } = await checkAndBumpSlidingWindow(
    db, callerUid, 'config_write', CONFIG_WRITE_WINDOW_MS, CONFIG_WRITE_MAX_IN_WINDOW,
  );
  if (limited) {
    throw new functions.https.HttpsError('resource-exhausted', 'config_write_rate_limited');
  }
}

/**
 * updateAppConfig({ doc, patch, reason?, confirm?, force? }) — Faz A §A5.
 *
 * `patch` is `{ 'dotted.schema.key': value, ... }`. Every key must exist in
 * config_schema.json with `doc === doc` — an unknown key, or a key that
 * belongs to a DIFFERENT doc, is rejected outright (no silent acceptance
 * of a typo, and no way to write a `server`-only field into `client`,
 * which would defeat the audience-based security partition those docs
 * exist for).
 *
 * `sensitive: true` fields require `confirm: true` and a `reason` of at
 * least 10 characters. Any numeric change of more than ±50% from the
 * currently stored value requires `force: true` — catches the fat-finger
 * (5 -> 500) that per-field min/max bounds cannot, because a wildly wrong
 * value is often still inside its legal range.
 */
const updateAppConfig = functions.https.onCall(async (data, context) => {
  const targetDoc = data && typeof data.doc === 'string' ? data.doc : '';
  const patch = data && typeof data.patch === 'object' && data.patch !== null && !Array.isArray(data.patch)
    ? data.patch : null;
  const reason = data && typeof data.reason === 'string' ? data.reason.trim() : '';
  const confirm = data && data.confirm === true;
  const force = data && data.force === true;

  if (!VALID_DOCS.includes(targetDoc)) {
    throw new functions.https.HttpsError('invalid-argument', `doc must be one of ${VALID_DOCS.join(', ')}`);
  }
  if (!patch || Object.keys(patch).length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'patch must be a non-empty object of {dottedKey: value}');
  }

  const db = admin.firestore();
  const callerUid = await requireAdmin(db, context);
  await requireWriteNotRateLimited(db, callerUid);

  const validEntries = schemaEntriesForDoc(targetDoc);
  const docRef = db.collection('app_config').doc(targetDoc);
  const currentSnap = await docRef.get();
  const currentData = currentSnap.exists ? (currentSnap.data() || {}) : {};

  let anySensitive = false;
  let anyLargeChange = false;

  for (const [key, value] of Object.entries(patch)) {
    const entry = validEntries.get(key);
    if (!entry) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        `"${key}" is not a valid setting for app_config/${targetDoc} (unknown key, or it belongs to a different doc)`,
      );
    }
    validateType(key, entry, value);
    validateValueShape(key, entry, value);
    if (entry.sensitive) anySensitive = true;

    if (typeof value === 'number') {
      const before = getNestedValue(currentData, key);
      if (typeof before === 'number' && before !== 0) {
        const changeRatio = Math.abs(value - before) / Math.abs(before);
        if (changeRatio > LARGE_CHANGE_RATIO) anyLargeChange = true;
      }
    }
  }

  if (anySensitive && !confirm) {
    throw new functions.https.HttpsError('failed-precondition', 'sensitive_change_requires_confirm');
  }
  if (anySensitive && reason.length < 10) {
    throw new functions.https.HttpsError('failed-precondition', 'sensitive_change_requires_reason');
  }
  if (anyLargeChange && !force) {
    throw new functions.https.HttpsError('failed-precondition', 'large_change_requires_force');
  }

  // Apply onto a deep copy of the CURRENT doc, then validate cross-field
  // invariants against the RESULTING full document.
  const nextData = JSON.parse(JSON.stringify(currentData));
  for (const [key, value] of Object.entries(patch)) {
    setNestedValue(nextData, key, value);
  }
  const invariantErrors = crossFieldInvariantErrors(nextData);
  if (invariantErrors.length > 0) {
    throw new functions.https.HttpsError('invalid-argument', invariantErrors.join('; '));
  }

  // Firestore rejects `undefined` — a key being set for the first time
  // (no prior value at all, not even a schema default written yet) must
  // record `from: null`, not `from: undefined` (caught by
  // functions/seed_app_config.js hitting this exact case on a fresh seed).
  const diff = Object.entries(patch).map(([key, to]) => ({
    key, from: getNestedValue(currentData, key) ?? null, to,
  }));
  const nextVersion = (Number(currentData.config_version) || 0) + 1;
  nextData.config_version = nextVersion;

  const batch = db.batch();
  batch.set(docRef, nextData);
  batch.set(db.collection('app_config_versions').doc(), {
    doc: targetDoc,
    version: nextVersion,
    before: currentData,
    after: nextData,
    diff,
    actor_uid: callerUid,
    reason: reason || null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  // Matches the EXISTING admin_audit field shape exactly (notifications.js's
  // sendAdminNotification / admin_service.dart's logAuditAction) — camelCase,
  // not this repo's more common snake_case, because this collection already
  // shipped with that shape and mixing conventions within one collection is
  // worse than being consistent with the wrong one.
  batch.set(db.collection('admin_audit').doc(), {
    action: 'update_app_config',
    targetUid: `app_config:${targetDoc}`,
    adminUid: callerUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    metadata: { diff, version: nextVersion, reason: reason || null },
  });
  await batch.commit();

  functions.logger.info('updateAppConfig: ok', {
    callerUid, targetDoc, version: nextVersion, keys: Object.keys(patch),
  });
  return { ok: true, version: nextVersion, diff };
});

/**
 * rollbackAppConfig({ doc, version, reason }) — Faz A §A7.3. Applies a
 * PRIOR version's full snapshot as a NEW forward version — never rewrites
 * history, never decrements config_version. Re-validates the snapshot
 * against the CURRENT schema's cross-field invariants before applying: a
 * snapshot from weeks ago may no longer satisfy a rule that has since
 * changed. On failure, reports why rather than silently dropping keys —
 * the admin can then re-apply corrected values through updateAppConfig.
 */
const rollbackAppConfig = functions.https.onCall(async (data, context) => {
  const targetDoc = data && typeof data.doc === 'string' ? data.doc : '';
  const targetVersion = data && Number.isInteger(data.version) ? data.version : null;
  const reason = data && typeof data.reason === 'string' ? data.reason.trim() : '';

  if (!VALID_DOCS.includes(targetDoc)) {
    throw new functions.https.HttpsError('invalid-argument', `doc must be one of ${VALID_DOCS.join(', ')}`);
  }
  if (targetVersion === null) {
    throw new functions.https.HttpsError('invalid-argument', 'version must be an integer');
  }
  if (reason.length < 10) {
    throw new functions.https.HttpsError('failed-precondition', 'rollback_requires_reason');
  }

  const db = admin.firestore();
  const callerUid = await requireAdmin(db, context);
  await requireWriteNotRateLimited(db, callerUid);

  const versionSnap = await db.collection('app_config_versions')
    .where('doc', '==', targetDoc)
    .where('version', '==', targetVersion)
    .limit(1)
    .get();
  if (versionSnap.empty) {
    throw new functions.https.HttpsError('not-found', 'version_not_found');
  }
  const snapshotAfter = versionSnap.docs[0].data().after || {};

  const invariantErrors = crossFieldInvariantErrors(snapshotAfter);
  if (invariantErrors.length > 0) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      `cannot restore version ${targetVersion}: it no longer satisfies current validation rules (${invariantErrors.join('; ')}). Use updateAppConfig with corrected values instead.`,
    );
  }

  const docRef = db.collection('app_config').doc(targetDoc);
  const currentSnap = await docRef.get();
  const currentData = currentSnap.exists ? (currentSnap.data() || {}) : {};

  const restored = JSON.parse(JSON.stringify(snapshotAfter));
  const nextVersion = (Number(currentData.config_version) || 0) + 1;
  restored.config_version = nextVersion;

  const batch = db.batch();
  batch.set(docRef, restored);
  batch.set(db.collection('app_config_versions').doc(), {
    doc: targetDoc,
    version: nextVersion,
    before: currentData,
    after: restored,
    diff: [{ key: '(rollback)', from: `v${currentData.config_version || 0}`, to: `v${targetVersion}` }],
    actor_uid: callerUid,
    reason,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(db.collection('admin_audit').doc(), {
    action: 'rollback_app_config',
    targetUid: `app_config:${targetDoc}`,
    adminUid: callerUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    metadata: { restoredVersion: targetVersion, newVersion: nextVersion, reason },
  });
  await batch.commit();

  functions.logger.info('rollbackAppConfig: ok', {
    callerUid, targetDoc, restoredVersion: targetVersion, newVersion: nextVersion,
  });
  return { ok: true, version: nextVersion };
});

/**
 * updateContentFilter({ blockedKeywords, reason, confirm }) — Faz A §A9,
 * hardened per M3.5. Moves `admin_config/global`'s only real, still-live
 * effect (mirroring `blocked_keywords` into `settings/content_filter`, which
 * community_service.dart reads with a fail-closed default) onto the same
 * admin/audit/rate-limit path as the rest of this file, since
 * `AdminService.updateAdminConfig` — the old writer — has zero callers and
 * is being deleted (Faz A §A9), not fixed. Content moderation word lists
 * are unstructured, admin-curated strings, not bounded scalars, so this is
 * deliberately NOT part of config_schema.json's typed settings.
 *
 * M3.5 fixes three real gaps this callable shipped with: `confirm`/`reason`
 * were accepted but never actually enforced (any caller could silently
 * rewrite the entire moderation word list with no confirmation step at
 * all — unlike every field in updateAppConfig, which at minimum requires
 * `sensitive: true` fields to pass confirm+reason); the settings write and
 * its audit entry were two independent Promise.all calls, not atomic (an
 * audit-write failure after a successful content_filter write would leave
 * the change unlogged); and there was no version-history entry at all, so
 * a bad word-list edit had no "what did it look like before" trail besides
 * admin_audit's own before/after counts. This callable is inherently
 * consequential (it moderates content for every user) so confirm+reason
 * are now unconditionally required, not gated on a `sensitive` flag the
 * way config fields are.
 */
const updateContentFilter = functions.https.onCall(async (data, context) => {
  const blockedKeywords = Array.isArray(data && data.blockedKeywords) ? data.blockedKeywords : null;
  const reason = data && typeof data.reason === 'string' ? data.reason.trim() : '';
  const confirm = data && data.confirm === true;

  if (!blockedKeywords || !blockedKeywords.every((k) => typeof k === 'string' && k.trim().length > 0)) {
    throw new functions.https.HttpsError('invalid-argument', 'blockedKeywords must be a list of non-empty strings');
  }
  if (blockedKeywords.length > 2000) {
    throw new functions.https.HttpsError('invalid-argument', 'blockedKeywords exceeds the 2000-entry sanity cap');
  }
  if (!confirm) {
    throw new functions.https.HttpsError('failed-precondition', 'content_filter_change_requires_confirm');
  }
  if (reason.length < 10) {
    throw new functions.https.HttpsError('failed-precondition', 'content_filter_change_requires_reason');
  }

  const db = admin.firestore();
  const callerUid = await requireAdmin(db, context);
  await requireWriteNotRateLimited(db, callerUid);

  const normalized = [...new Set(blockedKeywords.map((k) => k.trim().toLowerCase()))];
  const ref = db.collection('settings').doc('content_filter');
  const beforeSnap = await ref.get();
  const before = beforeSnap.exists ? (beforeSnap.data() || {}) : {};
  const beforeKeywords = before.blocked_keywords || [];

  const batch = db.batch();
  batch.set(ref, { blocked_keywords: normalized, updated_at: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  // Reuses app_config_versions for a history trail, same shape as
  // updateAppConfig's own version entries -- but NOT restorable through
  // rollbackAppConfig, which only ever looks up doc IN ('critical','client',
  // 'server'). A bad word-list change is undone by calling this callable
  // again with a corrected list, not by a generic rollback; extending
  // rollbackAppConfig to cover this doc too is a bigger scope increase than
  // this fix, not something to sneak in unannounced.
  batch.set(db.collection('app_config_versions').doc(), {
    doc: 'content_filter',
    version: null,
    before: { blocked_keywords: beforeKeywords },
    after: { blocked_keywords: normalized },
    diff: [{ key: 'blocked_keywords', from: `${beforeKeywords.length} kelime`, to: `${normalized.length} kelime` }],
    actor_uid: callerUid,
    reason,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  batch.set(db.collection('admin_audit').doc(), {
    action: 'update_content_filter',
    targetUid: 'settings:content_filter',
    adminUid: callerUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      before_count: beforeKeywords.length,
      after_count: normalized.length,
      reason,
    },
  });
  await batch.commit();

  functions.logger.info('updateContentFilter: ok', { callerUid, count: normalized.length });
  return { ok: true, count: normalized.length };
});

module.exports = {
  updateAppConfig,
  rollbackAppConfig,
  updateContentFilter,
  // exported for tests only:
  setNestedValue,
  getNestedValue,
  crossFieldInvariantErrors,
  schemaEntriesForDoc,
  validateValueShape,
};
