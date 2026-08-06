#!/usr/bin/env node
'use strict';

/**
 * Faz A Faz 3 — seeds app_config/{server,client,critical} from
 * config_schema.json's own declared defaults, via the SAME nested-doc
 * construction (setNestedValue) and cross-field validation
 * (crossFieldInvariantErrors) app_config_admin.js's updateAppConfig
 * callable uses — so the seed is validated and versioned from birth
 * (PLAN.md Faz A §A8 Faz 3), not a second, hand-written write path.
 *
 * NOT a deployed Cloud Function — not required by index.js, so Firebase's
 * deploy tooling never sees it. A one-time manual ops script, run directly
 * with `node`.
 *
 * Idempotent by refusal, not by overwrite: if a target doc already
 * exists, this script logs and SKIPS it rather than clobbering whatever is
 * there — re-seeding an already-seeded doc is not this script's job.
 *
 * SAFETY: refuses to touch the production project unless
 * --confirm-production is passed explicitly. Seeding production Firestore
 * is a deliberate, one-way action — this repo's config-migration plan
 * treats it as a standing decision for the project owner to make and
 * execute themselves, not something to automate unilaterally. Run against
 * the emulator to verify first.
 *
 * Usage (emulator — this is how it was verified):
 *   firebase emulators:exec --only firestore --project demo-cookrange \
 *     "node functions/seed_app_config.js --project demo-cookrange"
 *
 * Usage (dry run against either project — prints what WOULD be written,
 * touches nothing):
 *   node functions/seed_app_config.js --project demo-cookrange --dry-run
 *
 * Usage (production — DO NOT run without explicit owner sign-off):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json \
 *     node functions/seed_app_config.js --project cookrange-app --confirm-production
 */

const admin = require('firebase-admin');
const schema = require('./config_schema.json');
const { setNestedValue, crossFieldInvariantErrors } = require('./app_config_admin');

const PRODUCTION_PROJECT_ID = 'cookrange-app';
const SEED_DOCS = ['server', 'client', 'critical'];

function parseArgs(argv) {
  const args = { project: null, confirmProduction: false, dryRun: false };
  for (let i = 2; i < argv.length; i++) {
    if (argv[i] === '--project') args.project = argv[++i];
    else if (argv[i] === '--confirm-production') args.confirmProduction = true;
    else if (argv[i] === '--dry-run') args.dryRun = true;
  }
  return args;
}

/** Builds the full nested doc for `targetDoc` from every schema entry whose `doc` matches. */
function buildSeedDoc(targetDoc) {
  const data = {};
  for (const [key, entry] of Object.entries(schema)) {
    if (key === '_meta' || entry.doc !== targetDoc) continue;
    setNestedValue(data, key, entry.default);
  }
  data.config_version = 1;
  return data;
}

async function seedOneDoc(db, targetDoc, dryRun) {
  const data = buildSeedDoc(targetDoc);

  const invariantErrors = crossFieldInvariantErrors(data);
  if (invariantErrors.length > 0) {
    // Would indicate a bug in config_schema.json itself (its own defaults
    // failing its own cross-field rules) — Faz 0's default-equality tests
    // should have already caught this, but never write a doc that fails
    // its own validation.
    throw new Error(`app_config/${targetDoc}'s schema defaults fail cross-field validation: ${invariantErrors.join('; ')}`);
  }

  const groupCount = Object.keys(data).filter((k) => k !== 'config_version').length;
  console.log(`app_config/${targetDoc}: ${groupCount} top-level group(s) from schema defaults.`);

  const ref = db.collection('app_config').doc(targetDoc);
  const existing = await ref.get();
  if (existing.exists) {
    console.log(`  already exists (version ${existing.data().config_version ?? '?'}) — skipping, not overwriting.`);
    return;
  }

  if (dryRun) {
    console.log(`  --dry-run: would write ${JSON.stringify(data).length} bytes; not writing.`);
    return;
  }

  const batch = db.batch();
  batch.set(ref, data);
  batch.set(db.collection('app_config_versions').doc(), {
    doc: targetDoc,
    version: 1,
    before: {},
    after: data,
    diff: Object.keys(data)
      .filter((k) => k !== 'config_version')
      // Firestore rejects `undefined` — a fresh seed has no prior value,
      // so `from` is explicitly `null`, not omitted or undefined.
      .map((k) => ({ key: k, from: null, to: data[k] })),
    actor_uid: 'seed_app_config.js',
    reason: 'Initial seed from config_schema.json defaults (Faz A Faz 3)',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log('  seeded (version 1).');
}

async function main() {
  const args = parseArgs(process.argv);
  if (!args.project) {
    console.error('Usage: node seed_app_config.js --project <firebase-project-id> [--confirm-production] [--dry-run]');
    process.exitCode = 1;
    return;
  }
  if (args.project === PRODUCTION_PROJECT_ID && !args.confirmProduction) {
    console.error(
      `Refusing to seed the PRODUCTION project "${PRODUCTION_PROJECT_ID}" without --confirm-production.\n`
      + 'Run against the emulator first (see this file\'s header comment). Seeding production is a '
      + 'deliberate, one-way action for the project owner to decide on, not something to run casually.',
    );
    process.exitCode = 1;
    return;
  }

  admin.initializeApp({ projectId: args.project });
  const db = admin.firestore();

  for (const targetDoc of SEED_DOCS) {
    await seedOneDoc(db, targetDoc, args.dryRun);
  }
  console.log('Done.');
}

main().catch((e) => {
  console.error('seed_app_config.js failed:', e);
  process.exitCode = 1;
});
