// Firestore security-rules unit tests — locks in the hardened model.
//
// Run with the Firestore emulator:
//   cd test/firestore_rules && npm install
//   firebase emulators:exec --only firestore --project demo-cookrange \
//     "node --test --test-reporter=spec ."
// (from the repo root the emulators:exec picks up firebase.json's firestore port.)
//
// These assert the SECURITY guarantees we deployed: users can't self-grant
// premium/credits/ban, server-only ledgers are read-only to clients, private
// PII is owner-only, the economy is locked, and content has size caps —
// while confirming the INTENTIONAL allowances (profile edits, self-service
// roles) still work.

import { test, before, after, beforeEach } from 'node:test';
import assert from 'node:assert';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc,
  serverTimestamp, deleteField, writeBatch,
} from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const RULES = readFileSync(join(__dirname, '..', '..', 'firestore.rules'), 'utf8');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-cookrange',
    firestore: { rules: RULES },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  if (env) await env.clearFirestore();
});

// Authenticated client db for a uid.
const db = (uid) => env.authenticatedContext(uid).firestore();

// Seed a doc bypassing rules (admin-level).
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (c) => {
    await setDoc(doc(c.firestore(), path), data);
  });
}

// ─── users/{uid} field-lock ──────────────────────────────────────────────────

test('owner CANNOT self-grant premium', async () => {
  await seed('users/u1', { displayName: 'A', subscription_tier: 'free' });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { subscription_tier: 'premium' })
  );
});

test('owner CANNOT self-grant reputation_score (Faz 0 §0.4)', async () => {
  await seed('users/u1', { displayName: 'A', reputation_score: 0 });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { reputation_score: 99999 })
  );
});

test('achievements: owner reads their own, CANNOT self-grant any badge (Faz 0 §0.4)', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/achievements/streak100'), {
      earned_at: serverTimestamp(),
    })
  );
  await seed('users/u1/achievements/streak100', { earned_at: new Date() });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/achievements/streak100')));
  await assertFails(getDoc(doc(db('u2'), 'users/u1/achievements/streak100')));
});

test('owner CANNOT self-grant xp/level directly (Faz 5 §5.1)', async () => {
  await seed('users/u1', { displayName: 'A', xp: 0, level: 1 });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { xp: 999999 })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { level: 999 })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { level_updated_at: serverTimestamp() })
  );
  // Sanity check: a non-protected field on the same doc still updates fine —
  // proves the failures above are the field lock, not a broken owner rule.
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1'), { displayName: 'B' })
  );
});

test('owner CANNOT self-grant group_top3_streak directly (Faz 5 §5.3)', async () => {
  await seed('users/u1', { displayName: 'A', group_top3_streak: 0 });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { group_top3_streak: 999 })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { group_top3_streak_week_key: '2026-08-03' })
  );
});

test('owner CANNOT self-grant streak_freeze_count or onboarding_data.streak directly (SEC-14)', async () => {
  await seed('users/u1', {
    displayName: 'A',
    streak_freeze_count: 0,
    onboarding_data: { streak: 1 },
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { streak_freeze_count: 999 })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { 'onboarding_data.streak': 999 })
  );
});

test('owner CAN still update onboarding_data.meal_reminder/water_reminder without touching streak (SEC-14)', async () => {
  // Regression guard for the wrong fix: a blanket hasAny(['onboarding_data'])
  // would reject this too, since meal_reminder/water_reminder live in the
  // same top-level map as the now-protected streak. Uses set(merge:true),
  // not a plain updateDoc() — mirrors the real write path exactly
  // (firestore_service.dart's updateUserData -> set(merge:true);
  // settings_screen.dart writes {'onboarding_data': {'water_reminder': map}}
  // specifically so it recursively merges into the sibling map instead of
  // replacing the whole onboarding_data field — see that file's own comment).
  await seed('users/u1', {
    displayName: 'A',
    onboarding_data: { streak: 5, meal_reminder: { enabled: false } },
  });
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1'), {
      onboarding_data: { meal_reminder: { enabled: true, times: ['08:00'] } },
    }, { merge: true })
  );
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1'), {
      onboarding_data: { water_reminder: { enabled: true, target_ml: 2000 } },
    }, { merge: true })
  );
});

test('users/{uid} create is bounded to the welcome-gift shape (SEC-14)', async () => {
  // Legitimate shape: handleUserLogin's new-user branch (firestore_service.dart)
  // sets exactly these two welcome-gift values on first sign-in.
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1'), {
      displayName: 'A',
      streak_freeze_count: 1,
      onboarding_data: { streak: 1 },
    })
  );
  // Attacker-supplied streak_freeze_count far beyond the welcome gift.
  await assertFails(
    setDoc(doc(db('u2'), 'users/u2'), {
      displayName: 'B',
      streak_freeze_count: 999999,
    })
  );
  // Attacker-supplied onboarding_data.streak far beyond the welcome gift.
  await assertFails(
    setDoc(doc(db('u3'), 'users/u3'), {
      displayName: 'C',
      onboarding_data: { streak: 50 },
    })
  );
});

// SEC-30: `createUserDocumentOnRegister` (firestore_service.dart) used to pass
// through a caller-supplied `onboardingData` map AS-IS, including an explicit
// `null` (a real, reachable value on a getOnboardingData() cache-miss/parse
// failure — see that method). The KEY is present in that case, so the SEC-14
// bound above's `!('onboarding_data' in request.resource.data)` guard doesn't
// short-circuit, and the old rule then evaluated `'streak' in null`, which
// raises a Firestore Rules runtime "Null value error" — an ERRORING condition
// denies the whole `create`, not just the unbounded field. So a legitimate
// registration was rejected outright: Firebase Auth created the account, but
// the Firestore users/{uid} doc silently never was. Confirmed empirically
// (throwaway probe against this same emulator) that reusing
// onboardingStreakChanged()'s `.get(key, default)` idiom verbatim does NOT
// fix this — `.get` only substitutes the default for a MISSING key, not one
// present with value `null`, so it still throws the identical error. The
// rule now guards with an explicit `is map` type check instead.
test('users/{uid} create SUCCEEDS with onboarding_data: null present (SEC-30)', async () => {
  await assertSucceeds(
    setDoc(doc(db('u4'), 'users/u4'), {
      displayName: 'D',
      onboarding_data: null,
    })
  );
});

// Same class of bug, not just the one reported symptom: any non-map value —
// not only `null` — would hit the exact same `'streak' in <non-map>` runtime
// error under the old rule. The `is map` guard (rather than a narrower
// `== null` check) closes the whole class, not just the confirmed case.
test('users/{uid} create SUCCEEDS with a non-map onboarding_data value (SEC-30)', async () => {
  await assertSucceeds(
    setDoc(doc(db('u5'), 'users/u5'), {
      displayName: 'E',
      onboarding_data: 'not-a-map',
    })
  );
});

// End-to-end shape check: the exact batch `createUserDocumentOnRegister`
// (firestore_service.dart) now sends on a getOnboardingData() cache-miss —
// `onboarding_data` OMITTED entirely (not even present as `null`), across
// BOTH documents of its real batch.commit() (main doc + private/account),
// exactly as the Dart fix emits it. Proves the full real-world failure
// scenario end-to-end, not just the synthetic null/non-map probes above.
test('users/{uid} create batch SUCCEEDS end-to-end matching createUserDocumentOnRegister with no onboarding data (SEC-30)', async () => {
  const uid = 'u6-e2e-register';
  const firestore = db(uid); // one instance, reused for batch + every doc()
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, `users/${uid}`), {
    displayName: null,
    photoURL: null,
    onboarding_completed: false,
    // onboarding_data intentionally absent — matches the Dart fix's
    // `if (onboardingData != null) 'onboarding_data': onboardingData`.
    created_at: serverTimestamp(),
    last_login_at: serverTimestamp(),
    user_verified: false,
  });
  batch.set(doc(firestore, `users/${uid}/private/account`), {
    email: 'newuser@example.com',
  });
  await assertSucceeds(batch.commit());
  // The main doc must be readable back and genuinely exist post-fix — this
  // is the concrete "did the Firestore doc actually get created" check.
  const snap = await getDoc(doc(firestore, `users/${uid}`));
  assert.strictEqual(snap.exists(), true);
  assert.strictEqual(snap.data().onboarding_completed, false);
  assert.strictEqual('onboarding_data' in snap.data(), false);
});

// SEC-29: `create` had NO constraint at all on the 16 fields
// touchesProtectedUserFields() (above) locks against `update` — only the two
// SEC-14 bounds just above (streak_freeze_count / onboarding_data.streak)
// existed. A technical user could bypass the app and call the Firestore
// client SDK directly to self-create a `users/{uid}` doc with e.g.
// `xp: 999999` or `subscription_tier: 'premium'` already baked in.
// firestore.rules now rejects `create` outright if the payload contains ANY
// of these 16 keys — no legitimate client creation flow ever sets them (see
// the rule's own comment), so forbidding their presence is strictly safer
// than trying to bound each one individually.
test('users/{uid} create REJECTS any of the 16 server-authoritative fields (SEC-29)', async () => {
  // One single-field payload per forbidden key — exercises the LITERAL
  // STRING of every entry in firestore.rules' new hasAny([...]) list, so a
  // typo there (which would silently leave exactly one field unprotected)
  // shows up as a failing assertion instead of passing silently.
  const forbiddenFieldPayloads = {
    xp: 1,
    level: 1,
    level_updated_at: new Date(),
    reputation_score: 100,
    reputation_updated_at: new Date(),
    subscription_tier: 'premium',
    subscription_expires_at: new Date(),
    subscription_product_id: 'com.cookrange.premium.annual',
    subscription_purchase_token: 'forged-token',
    ai_credits_used: -100,
    ai_credits_reset_at: new Date(),
    ai_credits_bonus: 999999,
    referral_used: true,
    is_banned: false,
    group_top3_streak: 5,
    group_top3_streak_week_key: '2026-08-03',
  };

  let i = 0;
  for (const [field, value] of Object.entries(forbiddenFieldPayloads)) {
    i += 1;
    const uid = `sec29-forbidden-${i}`;
    await assertFails(
      setDoc(doc(db(uid), `users/${uid}`), {
        displayName: 'Attacker',
        [field]: value,
      })
    );
  }
});

test('users/{uid} create still SUCCEEDS for a normal legitimate payload with none of the 16 forbidden keys (SEC-29)', async () => {
  // Regression guard for the new forbid-list: a brand-new doc shaped like
  // handleUserLogin's new-user branch (firestore_service.dart) — displayName
  // + onboarding_data + streak_freeze_count within the SEC-14 bound, none of
  // the SEC-29 forbidden keys — must still be creatable.
  await assertSucceeds(
    setDoc(doc(db('legit-newuser'), 'users/legit-newuser'), {
      displayName: 'Legit User',
      photoURL: null,
      created_at: serverTimestamp(),
      onboarding_completed: false,
      onboarding_data: { streak: 1 },
      streak_freeze_count: 1,
      last_login_at: serverTimestamp(),
      last_active_at: serverTimestamp(),
      is_online: true,
    })
  );
});

// SEC-31: SEC-14 locked streak_freeze_count/onboarding_data.streak (the
// OUTPUTS of processStreakLogin, functions/progress.js) but missed the one
// field that function reads as its SOLE input to decide which branch to
// take — last_login_at. Before this, a client could call the raw SDK
// directly (not just the app's own FieldValue.serverTimestamp() convention —
// nothing at the rules level enforced that over a fabricated literal
// Timestamp) to set last_login_at to an arbitrary past value, then call
// processStreakLogin repeatedly to farm streak increments or drain/refill
// streak_freeze_count on demand — defeating SEC-14 one hop removed from the
// fields it actually locked.
test('owner CANNOT self-grant an arbitrary last_login_at directly (SEC-31)', async () => {
  await seed('users/u1', { displayName: 'A', last_login_at: new Date() });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), {
      last_login_at: new Date('2020-01-01'),
    })
  );
});

test('owner CANNOT self-grant streak_freeze_used_at directly (SEC-31)', async () => {
  // streak_freeze_used_at is the companion timestamp processStreakLogin
  // writes alongside a freeze consumption (functions/progress.js) — same
  // server-write-only shape as last_login_at above, closed for the same
  // reason. No client code has ever written this field directly (the
  // client-side freeze logic that used to was deleted by the original
  // SEC-14 fix).
  await seed('users/u1', { displayName: 'A' });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), {
      streak_freeze_used_at: serverTimestamp(),
    })
  );
});

test('owner CAN still perform a normal existing-user login update (last_active_at + is_online, no last_login_at) after SEC-31', async () => {
  // Matches the ACTUAL fixed handleUserLogin existing-user branch
  // (firestore_service.dart) exactly: publicLoginData starts life with
  // last_login_at/last_active_at/is_online, but last_login_at is now
  // stripped via publicLoginData.remove('last_login_at') before this
  // branch's own batch.update() call — processStreakLogin (called just
  // before, in its own transaction) already wrote last_login_at
  // authoritatively, so the client's own write of it is now both redundant
  // and forbidden by the rule above. Regression guard: proves the new rule
  // doesn't collateral-damage the two fields that DO still legitimately
  // update on every single login.
  await seed('users/u1', {
    displayName: 'A',
    last_login_at: new Date(),
    last_active_at: new Date(),
    is_online: false,
  });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1'), {
      last_active_at: serverTimestamp(),
      is_online: true,
    })
  );
});

// SEC-32: `onboardingStreakChanged()` (the `update`-side sibling of SEC-30's
// `create`-time fix — same file, same root cause) has the identical
// `.get(key, default)` null-safety bug SEC-30 fixed there, proven
// empirically during that fix's own investigation but deliberately left
// unfixed on this sibling at the time ("that helper's analogous latent gap
// isn't currently reachable by any real code path... flagged separately
// rather than fixed here"). `.get(key, default)` only substitutes `default`
// for a MISSING key, not one present with value `null` — if
// `onboarding_data` is explicitly `null` on either side of an `update`
// diff, `resource.data.get('onboarding_data', {})` (or the
// `request.resource.data` equivalent) evaluates to `null` itself (not
// `{}`), and the chained `.get('streak', null)` on that `null` raises the
// same Firestore Rules runtime "Null value error" — an ERRORING condition
// denies the whole `update`, not just this one field's check. Confirmed via
// grep (same methodology as SEC-30): no `update`/`set(merge:true)` call
// anywhere in `lib/` (`firestore_service.dart`'s `updateUserData`,
// `onboarding_provider.dart`'s `persistV2Profile`, `settings_screen.dart`'s
// reminder writes) ever sends an explicit `null` — this is pure
// defense-in-depth, not a currently-reachable bug.
//
// Fixed the same way as SEC-30: an explicit `is map` guard before
// descending into `.get('streak', ...)`, applied on BOTH sides of the
// comparison (this function diffs two document snapshots, not one
// create-time payload, so it needs the guard twice — `let oldStreak =
// resource.data.get('onboarding_data', {}) is map ? ...get('streak', null)
// : null`, mirrored for `newStreak` against `request.resource.data`).
// Confirmed empirically against the emulator (a throwaway probe, same
// methodology SEC-30's own fix used) that this eliminates the runtime
// error entirely, for a non-map value too, not only `null` — and confirmed
// the `let`/ternary syntax itself actually compiles and runs (not assumed).
//
// Judgment call — the null-transition is DENIED, not allowed through this
// check, once a real streak value already exists. `onboardingStreakChanged()`
// already treats ANY change to the effective streak value as "changed" and
// blocks it, including a value disappearing entirely: an update that kept
// `onboarding_data` a map but dropped just the `streak` key was ALREADY
// blocked before this fix, unrelated to the null-safety bug (`5 != null` is
// the same comparison whether `streak` vanishes because the key was
// dropped or because the whole map became `null`). Denying here is
// consistent with that pre-existing precedent — and empirically confirmed
// below to also be the *safer* choice, not just the simpler one: a
// tempting "smarter" variant that let the null-transition through this
// check (e.g. by requiring both sides to be a map before comparing at all)
// would reopen a two-step forgery — null the map out in one write (which
// that variant must allow, to grant the exception), then set
// `onboarding_data: {streak: <anything>}` in a second write, where the
// reference doc's `onboarding_data` is now non-map, so that variant's
// "both sides must be a map" gate would ALSO skip the comparison on the
// follow-up write, letting the value land unchecked two writes removed
// from the lock instead of one. The plain symmetric fix (substitute `null`
// for a non-map side, then always compare) closes both the single- and
// two-step versions at once, with no special-casing — matching SEC-30's
// own preference for the explicit, simple guard over a cleverer variant.
test('users/{uid} update REJECTS onboarding_data: null when a real streak value already exists (SEC-32)', async () => {
  await seed('users/sec32-u1', { displayName: 'A', onboarding_data: { streak: 5 } });
  // Must be a clean, intentional denial (streak effectively 5 -> null is
  // "changed", same as any other streak diff) — not the old Rules-runtime
  // crash. The no-crash half of that claim is what the next test actually
  // proves (see its own comment).
  await assertFails(
    updateDoc(doc(db('sec32-u1'), 'users/sec32-u1'), { onboarding_data: null })
  );
});

test('users/{uid} update SUCCEEDS setting onboarding_data: null when no prior streak value exists (SEC-32)', async () => {
  // This is the test that actually proves the Rules-runtime crash is gone,
  // not just that the write above is denied for some unspecified reason: a
  // crash always manifests as a denial, never as a success, so the OLD,
  // unfixed `.get(key, default)` chain hitting a bare `null` here would
  // make this assertSucceeds() fail too (not merely fail for a different
  // reason) — exactly like SEC-30's create-time analog test. Both sides
  // resolve to "no streak" here (old: key absent entirely; new:
  // onboarding_data explicitly null) — no diff, so nothing to protect
  // against, and no error should reach the client.
  await seed('users/sec32-u2', { displayName: 'B' });
  await assertSucceeds(
    updateDoc(doc(db('sec32-u2'), 'users/sec32-u2'), { onboarding_data: null })
  );
});

test('users/{uid} update SUCCEEDS setting a non-map onboarding_data when no prior streak value exists (SEC-32)', async () => {
  // Same class of bug as SEC-30, not just the one reported symptom: a
  // non-map value (not only `null`) hits the identical `.get` chain. The
  // `is map` guard (rather than a narrower `== null` check) closes the
  // whole class, exactly as SEC-30's own equivalent test confirmed on the
  // create side.
  await seed('users/sec32-u3', { displayName: 'C' });
  await assertSucceeds(
    updateDoc(doc(db('sec32-u3'), 'users/sec32-u3'), { onboarding_data: 'not-a-map' })
  );
});

test('owner CAN still update an unrelated field while a real onboarding_data.streak is present, untouched (SEC-32)', async () => {
  // Regression guard: the ordinary "streak present, unrelated field
  // changes" path must still work. onboarding_data isn't mentioned in the
  // update at all, so request.resource.data carries the exact same streak
  // value forward unchanged (old === new, no diff, nothing flagged).
  await seed('users/sec32-u4', { displayName: 'A', onboarding_data: { streak: 5 } });
  await assertSucceeds(
    updateDoc(doc(db('sec32-u4'), 'users/sec32-u4'), { displayName: 'Z' })
  );
});

test('owner CANNOT bypass the streak lock by nulling onboarding_data then re-setting it in a second write (SEC-32)', async () => {
  // Empirical confirmation of the DENY judgment call's own reasoning above,
  // not just an assertion of it: proves the two-step forgery path a
  // "smarter" allow-the-null-transition variant would have reopened is not
  // actually reachable through the fix as implemented, because step one
  // alone is already denied.
  await seed('users/sec32-u5', { displayName: 'A', onboarding_data: { streak: 5 } });
  await assertFails(
    updateDoc(doc(db('sec32-u5'), 'users/sec32-u5'), { onboarding_data: null })
  );
  await assertFails(
    updateDoc(doc(db('sec32-u5'), 'users/sec32-u5'), { onboarding_data: { streak: 999999 } })
  );
});

test('xp_events: owner reads their own ledger, a stranger CANNOT, and NOBODY can write it directly (Faz 5 §5.1)', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/xp_events/meal_logged_fake1'), {
      kind: 'meal_logged', points: 999999, ref_id: 'fake1', created_at: serverTimestamp(), multiplier_applied: 1,
    })
  );
  await seed('users/u1/xp_events/meal_logged_log1', {
    kind: 'meal_logged', points: 5, ref_id: 'log1', created_at: new Date(), multiplier_applied: 1,
  });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/xp_events/meal_logged_log1')));
  await assertFails(getDoc(doc(db('u2'), 'users/u1/xp_events/meal_logged_log1')));
  // Not even the owner may update or delete an existing ledger entry —
  // immutable, matches `food_logs`/`checkins`' "durable record" precedent.
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/xp_events/meal_logged_log1'), { points: 999999 })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/xp_events/meal_logged_log1')));
});

test('community_weekly_xp: ANY authenticated user can read (xp is already public), NOBODY can write it directly (Faz 5 §5.3)', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'community_weekly_xp/2026-08-03/members/u1'), {
      xp: 999999, display_name: 'A',
    })
  );
  await seed('community_weekly_xp/2026-08-03/members/u1', { xp: 50, display_name: 'A' });
  await assertSucceeds(getDoc(doc(db('u1'), 'community_weekly_xp/2026-08-03/members/u1')));
  // Unlike xp_events above, this is a flat authenticated-read collection —
  // a completely unrelated uid can read it too (xp is already public on
  // users/{uid} itself; this is just a weekly rollup of the same number).
  await assertSucceeds(getDoc(doc(db('u2'), 'community_weekly_xp/2026-08-03/members/u1')));
  await assertFails(
    updateDoc(doc(db('u1'), 'community_weekly_xp/2026-08-03/members/u1'), { xp: 999999 })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'community_weekly_xp/2026-08-03/members/u1')));
});

test('owner CANNOT self-grant AI bonus credits on the user doc', async () => {
  await seed('users/u1', { displayName: 'A' });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { ai_credits_bonus: 99999 })
  );
});

test('banned user CANNOT self-unban', async () => {
  await seed('users/u1', { is_banned: true });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1'), { is_banned: false })
  );
});

test('owner CAN edit allowed profile fields (displayName)', async () => {
  await seed('users/u1', { displayName: 'A' });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1'), { displayName: 'B' })
  );
});

test('owner CAN self-assign coach/gym role (admin gated server-side, by design)', async () => {
  await seed('users/u1', { displayName: 'A' });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1'), { user_roles: ['coach'] })
  );
});

test('user CANNOT write another user doc', async () => {
  await seed('users/u2', { displayName: 'B' });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u2'), { displayName: 'hacked' })
  );
});

// ─── Server-only ledgers ─────────────────────────────────────────────────────

test('ai_credits/{uid}: owner reads, client CANNOT write', async () => {
  await seed('ai_credits/u1', { used_today: 1, bonus: 0 });
  await assertSucceeds(getDoc(doc(db('u1'), 'ai_credits/u1')));
  await assertFails(setDoc(doc(db('u1'), 'ai_credits/u1'), { bonus: 99999 }));
});

test('entitlements/{uid}: owner reads, client CANNOT write', async () => {
  await seed('entitlements/u1', { tier: 'free' });
  await assertSucceeds(getDoc(doc(db('u1'), 'entitlements/u1')));
  await assertFails(setDoc(doc(db('u1'), 'entitlements/u1'), { tier: 'premium' }));
});

test('processed_purchases: fully server-only (read + write denied)', async () => {
  await seed('processed_purchases/x', { uid: 'u1' });
  await assertFails(getDoc(doc(db('u1'), 'processed_purchases/x')));
  await assertFails(setDoc(doc(db('u1'), 'processed_purchases/y'), { uid: 'u1' }));
});

// ─── Economy ─────────────────────────────────────────────────────────────────

test('commissions: owner reads, client CANNOT create (server-only)', async () => {
  await seed('users/u1/commissions/c0', { amount: 5 });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/commissions/c0')));
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/commissions/c1'), { amount: 100000 })
  );
});

test('referrals: non-owner CANNOT rewrite used_by_uids; owner can update own', async () => {
  await seed('referrals/CODE1', {
    owner_uid: 'u1',
    used_by_uids: [],
    max_uses: 10,
  });
  await assertFails(
    updateDoc(doc(db('u2'), 'referrals/CODE1'), { used_by_uids: ['u2'] })
  );
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'referrals/CODE1'), { max_uses: 5 })
  );
});

// ─── Referrals: gym-type invite codes (Faz 6 §6.1) ────────────────────────────

test('referrals gym-type: the real gym owner CAN create a code for their own gym', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'referrals/GYMCODE1'), {
      owner_uid: 'owner1',
      type: 'gym',
      gym_id: 'g1',
      campaign: 'Front desk',
      created_at: serverTimestamp(),
      used_by_uids: [],
      max_uses: 5000,
    })
  );
});

test('referrals gym-type: CANNOT create a code for a gym you do not own, even naming yourself owner_uid', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g2', { owner_uid: 'owner2' });
  // owner2 sets owner_uid to themselves (the pre-existing check alone would
  // pass this) but points gym_id at owner1's gym — the real-ownership get()
  // must be what actually blocks it.
  await assertFails(
    setDoc(doc(db('owner2'), 'referrals/GYMCODE2'), {
      owner_uid: 'owner2',
      type: 'gym',
      gym_id: 'g1',
      created_at: serverTimestamp(),
      used_by_uids: [],
      max_uses: 5000,
    })
  );
});

test('referrals: an unrecognized type value is rejected', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'referrals/BADTYPE'), {
      owner_uid: 'u1',
      type: 'not_a_real_type',
      created_at: serverTimestamp(),
      used_by_uids: [],
      max_uses: 10,
    })
  );
});

test('referrals gym-type: campaign/location_note past the length cap are rejected', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await assertFails(
    setDoc(doc(db('owner1'), 'referrals/GYMCODE3'), {
      owner_uid: 'owner1',
      type: 'gym',
      gym_id: 'g1',
      campaign: 'x'.repeat(81),
      created_at: serverTimestamp(),
      used_by_uids: [],
      max_uses: 5000,
    })
  );
  await assertFails(
    setDoc(doc(db('owner1'), 'referrals/GYMCODE4'), {
      owner_uid: 'owner1',
      type: 'gym',
      gym_id: 'g1',
      location_note: 'x'.repeat(201),
      created_at: serverTimestamp(),
      used_by_uids: [],
      max_uses: 5000,
    })
  );
});

test('referrals gym-type: gym_id/type are pinned immutable on update, even for the owner of both gyms', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g2', { owner_uid: 'owner1' }); // owner1 legitimately owns BOTH
  await seed('referrals/GYMCODE5', {
    owner_uid: 'owner1',
    type: 'gym',
    gym_id: 'g1',
    used_by_uids: [],
    max_uses: 5000,
  });
  // Cannot repoint to a different gym, even one the SAME owner also owns —
  // the pin isn't just a proxy for the ownership check above.
  await assertFails(
    updateDoc(doc(db('owner1'), 'referrals/GYMCODE5'), { gym_id: 'g2' })
  );
  // Cannot relabel the type either.
  await assertFails(
    updateDoc(doc(db('owner1'), 'referrals/GYMCODE5'), { type: 'user' })
  );
  // An update that doesn't touch either pinned field still succeeds.
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'referrals/GYMCODE5'), { campaign: 'Reception' })
  );
});

test('referrals gym-type: printed_at must be the server timestamp, not a client-supplied date', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('referrals/GYMCODE6', {
    owner_uid: 'owner1',
    type: 'gym',
    gym_id: 'g1',
    used_by_uids: [],
    max_uses: 5000,
  });
  await assertFails(
    updateDoc(doc(db('owner1'), 'referrals/GYMCODE6'), {
      printed_at: new Date('2020-01-01'),
    })
  );
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'referrals/GYMCODE6'), {
      printed_at: serverTimestamp(),
    })
  );
});

test('referrals gym-type: admin can manage a gym code they do not themselves own', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('referrals/GYMCODE7', {
    owner_uid: 'owner1',
    type: 'gym',
    gym_id: 'g1',
    used_by_uids: [],
    max_uses: 5000,
  });
  await assertSucceeds(
    updateDoc(doc(db('admin1'), 'referrals/GYMCODE7'), { max_uses: 0 })
  );
});

// ─── Faz 6 §6.5/§6.6: gym attribution + revenue share ───────────────────────
//
// gym_attributions/{uid} is server-written only (applyReferral's gym branch
// + maybeAwardGymCommission, both Admin SDK — bypass these rules entirely).
// Read scope is a deliberate design choice, not an oversight: owner-only
// (the attributed user themselves), NEVER the gym's owner directly — "bireysel
// kullanıcı kimliği salona gitmez" (individual identity never reaches the
// gym) applies to raw document reads too, not just to a hypothetical report
// endpoint. The gym-facing funnel instead reads its OWN aggregate counters
// (gyms/{id}.attributed_member_count/attributed_premium_count), asserted
// separately below alongside live_occupancy's existing protection.

test('gym_attributions: owner reads their own, a stranger CANNOT read it', async () => {
  await seed('gym_attributions/u1', {
    gym_id: 'g1',
    code: 'GYMCODE1',
    source: 'deep_link',
    lifetime_commission_try: 0,
  });
  await assertSucceeds(getDoc(doc(db('u1'), 'gym_attributions/u1')));
  await assertFails(getDoc(doc(db('u2'), 'gym_attributions/u1')));
});

test('gym_attributions: the attributed gym\'s OWN owner CANNOT read it either — identity never reaches the gym', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gym_attributions/u1', {
    gym_id: 'g1',
    code: 'GYMCODE1',
    source: 'deep_link',
    lifetime_commission_try: 0,
  });
  await assertFails(getDoc(doc(db('owner1'), 'gym_attributions/u1')));
});

test('gym_attributions: fully server-only — no client create, update, or delete, not even by the attributed user', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'gym_attributions/u1'), {
      gym_id: 'g1',
      code: 'GYMCODE1',
      source: 'in_app',
      lifetime_commission_try: 0,
    })
  );
  await seed('gym_attributions/u1', {
    gym_id: 'g1',
    code: 'GYMCODE1',
    source: 'in_app',
    lifetime_commission_try: 0,
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'gym_attributions/u1'), { lifetime_commission_try: 999 })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'gym_attributions/u1')));
});

test('gyms: owner CANNOT write attributed_member_count/attributed_premium_count directly (Faz 6 §6.5/§6.6 — server-only counters)', async () => {
  await seed('gyms/g1', {
    owner_uid: 'owner1',
    city: 'Istanbul',
    attributed_member_count: 3,
    attributed_premium_count: 1,
  });
  await assertFails(
    updateDoc(doc(db('owner1'), 'gyms/g1'), { attributed_member_count: 999 })
  );
  await assertFails(
    updateDoc(doc(db('owner1'), 'gyms/g1'), { attributed_premium_count: 999 })
  );
  // Owner still has full control of ordinary fields — only these two counters
  // (and live_occupancy, tested elsewhere) are fenced off.
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'gyms/g1'), { city: 'Ankara' })
  );
  // Admin retains the escape hatch (support fixing a stuck counter), same as
  // live_occupancy's existing test.
  await seed('admin_roles/admin1', { is_admin: true });
  await assertSucceeds(
    updateDoc(doc(db('admin1'), 'gyms/g1'), { attributed_member_count: 0 })
  );
});

test('commissions: client CANNOT self-grant a gymPremiumShare entry either (Faz 6 §6.6 — same server-only rule, no type-based carve-out)', async () => {
  await assertFails(
    setDoc(doc(db('owner1'), 'users/owner1/commissions/fake1'), {
      type: 'gymPremiumShare',
      amount: 1000000,
      currency: 'TRY',
      referee_uid: 'u1',
      gym_id: 'g1',
      status: 'pending',
    })
  );
  // Nor can the attributed user plant one into the gym owner's ledger.
  await assertFails(
    setDoc(doc(db('u1'), 'users/owner1/commissions/fake2'), {
      type: 'gymPremiumShare',
      amount: 1000000,
      currency: 'TRY',
      referee_uid: 'u1',
      gym_id: 'g1',
      status: 'pending',
    })
  );
});

// ─── Faz 6 §6.6 follow-up: commission reversal (refund/chargeback/expiry) ───
//
// Reversal is written by a NEW server-only function
// (entitlements.js's reverseCommissionsForPurchase, called from purchases.js's
// three revocation paths via the Admin SDK, which bypasses these rules
// entirely) — never a client action. It reuses the SAME blanket
// `allow write: if false` on users/{uid}/commissions/{id} above (no rule
// change was needed to add it), so these tests exist to prove that blanket
// deny genuinely covers the NEW fields/values this feature introduces
// (purchase_key, reversed_at/reversed_reason, the rejected status transition,
// adjustment_of/adjustment_reason offsetting entries) and not just the
// pre-existing ones already covered above.

test('commissions: client CANNOT flip their own pending commission to rejected (forging a reversal)', async () => {
  await seed('users/owner1/commissions/c1', {
    type: 'gymPremiumShare',
    amount: 15,
    currency: 'TRY',
    status: 'pending',
    purchase_key: 'abc123',
  });
  await assertFails(
    updateDoc(doc(db('owner1'), 'users/owner1/commissions/c1'), {
      status: 'rejected',
      reversed_at: serverTimestamp(),
      reversed_reason: 'apple_REFUND',
    })
  );
});

test('commissions: client CANNOT resurrect an already-rejected entry back to pending', async () => {
  await seed('users/owner1/commissions/c2', {
    type: 'gymPremiumShare',
    amount: 15,
    currency: 'TRY',
    status: 'rejected',
    reversed_at: new Date(),
    reversed_reason: 'apple_REFUND',
  });
  await assertFails(
    updateDoc(doc(db('owner1'), 'users/owner1/commissions/c2'), { status: 'pending' })
  );
});

test('commissions: client CANNOT plant a fake offsetting/adjustment entry (negative-amount clawback reversal) into any ledger', async () => {
  // Own ledger.
  await assertFails(
    setDoc(doc(db('owner1'), 'users/owner1/commissions/fakeAdj1'), {
      type: 'gymPremiumShare',
      amount: -15,
      currency: 'TRY',
      status: 'pending',
      adjustment_of: 'c1',
      adjustment_reason: 'self-serve clawback reversal',
    })
  );
  // Someone else's ledger.
  await assertFails(
    setDoc(doc(db('u1'), 'users/owner1/commissions/fakeAdj2'), {
      type: 'gymPremiumShare',
      amount: -15,
      currency: 'TRY',
      status: 'pending',
      adjustment_of: 'c1',
    })
  );
});

test('commissions: a paid entry carrying purchase-tracing fields is still owner-readable but not owner-writable', async () => {
  await seed('users/owner1/commissions/c3', {
    type: 'gymPremiumShare',
    amount: 15,
    currency: 'TRY',
    status: 'paid',
    purchase_key: 'deadbeef',
    purchase_platform: 'ios',
    purchase_product_id: 'com.cookrange.premium.monthly',
  });
  await assertSucceeds(getDoc(doc(db('owner1'), 'users/owner1/commissions/c3')));
  await assertFails(
    updateDoc(doc(db('owner1'), 'users/owner1/commissions/c3'), { purchase_key: 'tampered' })
  );
  await assertFails(
    updateDoc(doc(db('owner1'), 'users/owner1/commissions/c3'), { amount: 999999 })
  );
});

// ─── Privacy ─────────────────────────────────────────────────────────────────

test('private nutrition PII: only the owner can read', async () => {
  await seed('users/u1/private/nutrition', { weight: 80, allergies: 'nuts' });
  await assertFails(getDoc(doc(db('u2'), 'users/u1/private/nutrition')));
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/private/nutrition')));
});

test('private/account: owner reads/writes; admin CAN read but CANNOT write; a third user is denied both (N1)', async () => {
  await seed('users/u1/private/account', { email: 'u1@example.com' });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/private/account')));
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1/private/account'), {
      email: 'u1@example.com', fcm_token: 'tok',
    })
  );

  await seed('admin_roles/admin1', { is_admin: true });
  await assertSucceeds(getDoc(doc(db('admin1'), 'users/u1/private/account')));
  await assertFails(
    setDoc(doc(db('admin1'), 'users/u1/private/account'), { email: 'hacked@example.com' })
  );

  await assertFails(getDoc(doc(db('u2'), 'users/u1/private/account')));
  await assertFails(
    setDoc(doc(db('u2'), 'users/u1/private/account'), { email: 'hacked@example.com' })
  );
});

test('meal_plan_history: owner-only read and write (BLK-06)', async () => {
  // Regression test — this path had no rule at all until BLK-06, so every
  // read and write hit the catch-all deny silently (swallowed by
  // debugPrint), and the history feature never worked.
  await seed('users/u1/meal_plan_history/2026-01-05', { archivedAt: 1 });
  await assertFails(getDoc(doc(db('u2'), 'users/u1/meal_plan_history/2026-01-05')));
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/meal_plan_history/2026-01-05')));
  await assertFails(
    setDoc(doc(db('u2'), 'users/u1/meal_plan_history/2026-01-06'), { archivedAt: 2 })
  );
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1/meal_plan_history/2026-01-06'), { archivedAt: 2 })
  );
});

// ─── Content caps + privilege ────────────────────────────────────────────────

test('posts: oversized content is rejected, normal content allowed', async () => {
  const big = 'x'.repeat(6000);
  await assertFails(
    setDoc(doc(db('u1'), 'posts/p1'), { authorId: 'u1', content: big })
  );
  await assertSucceeds(
    setDoc(doc(db('u1'), 'posts/p2'), { authorId: 'u1', content: 'hello' })
  );
});

// SEC-07 fix: the optional `groupId` field on a top-level post (used for
// group-scoped feeds, per community_service.dart's own comment) had NO
// group-membership check at all — a banned/muted/never-joined user could
// post into ANY group's feed, unlike the parallel group-chat message path
// (canPostInGroup). Posts with no groupId (personal/public feed) are
// unaffected.
test('posts: a groupId post requires real, active, unmuted group membership (SEC-07)', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2, announcement_only: false });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'posts/p1'), { authorId: 'u2', content: 'hi group', groupId: 'gr1' })
  );
  // u3 was never a member of gr1 at all.
  await assertFails(
    setDoc(doc(db('u3'), 'posts/p2'), { authorId: 'u3', content: 'sneaking in', groupId: 'gr1' })
  );
  // A post with no groupId at all is entirely unaffected by this check.
  await assertSucceeds(
    setDoc(doc(db('u3'), 'posts/p3'), { authorId: 'u3', content: 'personal feed post' })
  );
});

test('posts: a BANNED group member cannot post into that group via groupId (SEC-07)', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2, announcement_only: false });
  await seed('community_groups/gr1/members/u2', { role: 'member', banned: true });
  await assertFails(
    setDoc(doc(db('u2'), 'posts/p1'), { authorId: 'u2', content: 'let me back in', groupId: 'gr1' })
  );
});

test('posts/comments: commenting on a group post requires the SAME group membership as posting (SEC-07)', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2, announcement_only: false });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('posts/p1', { authorId: 'u2', content: 'group post', groupId: 'gr1' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'posts/p1/comments/c1'), { authorId: 'u2', content: 'nice' })
  );
  await assertFails(
    setDoc(doc(db('u3'), 'posts/p1/comments/c2'), { authorId: 'u3', content: 'not a member' })
  );
});

// ─── Post/comment/gym-post engagement lockdown (BLK-08) ─────────────────────

test('posts: non-owner CANNOT touch groupId, content, or make an arbitrary likesCount jump', async () => {
  await seed('posts/p1', {
    authorId: 'u1', content: 'hi', likesCount: 0, commentsCount: 0,
  });
  // The exploit this ticket exists for: hijacking a post into another group.
  await assertFails(
    updateDoc(doc(db('u2'), 'posts/p1'), { groupId: 'some-group' })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'posts/p1'), { content: 'hacked' })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'posts/p1'), { likesCount: 99999 })
  );
});

test('posts: non-owner CAN make a legitimate +1/-1 engagement update', async () => {
  await seed('posts/p1', {
    authorId: 'u1', content: 'hi', likesCount: 0, commentsCount: 0,
  });
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'posts/p1'), {
      likesCount: 1, likedUserIds: ['u2'], recentLikers: [{ id: 'u2' }],
    })
  );
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'posts/p1'), { commentsCount: 1 })
  );
});

test('posts: non-owner CAN react (reactionUserIds), Faz 0 audit fix for toggleReaction', async () => {
  await seed('posts/p1', {
    authorId: 'u1', content: 'hi', likesCount: 0, commentsCount: 0, reactions: {},
  });
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'posts/p1'), {
      reactions: { '🔥': 1 }, 'reactionUserIds.🔥': ['u2'],
    })
  );
});

test('posts: owner retains full update rights (unaffected by the engagement allowlist)', async () => {
  await seed('posts/p1', {
    authorId: 'u1', content: 'hi', likesCount: 0, commentsCount: 0,
  });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'posts/p1'), { content: 'edited by owner', tags: ['x'] })
  );
});

test('post comments: non-owner CANNOT rewrite content or jump likesCount, CAN +1 it', async () => {
  await seed('posts/p1/comments/c1', { authorId: 'u1', content: 'hi', likesCount: 0 });
  await assertFails(
    updateDoc(doc(db('u2'), 'posts/p1/comments/c1'), { content: 'hacked' })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'posts/p1/comments/c1'), { likesCount: 500 })
  );
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'posts/p1/comments/c1'), { likesCount: 1 })
  );
});

// SEC-07 fix: this create rule used to say "membership enforced app-side"
// but had no such check, and no content-length cap at all.
test('gym posts: create requires real gym membership + a content cap (SEC-07)', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'gyms/g1/posts/p1'), { author_uid: 'u2', content: 'hi gym' })
  );
  // u3 has no gyms/g1/members/u3 doc at all.
  await assertFails(
    setDoc(doc(db('u3'), 'gyms/g1/posts/p2'), { author_uid: 'u3', content: 'not a member' })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/posts/p3'), { author_uid: 'u2', content: 'x'.repeat(6000) })
  );
});

test('gym posts/comments: comment create requires real gym membership + a content cap (SEC-07)', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await seed('gyms/g1/posts/p1', { author_uid: 'u2', content: 'hi gym' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'gyms/g1/posts/p1/comments/c1'), { author_uid: 'u2', content: 'nice' })
  );
  await assertFails(
    setDoc(doc(db('u3'), 'gyms/g1/posts/p1/comments/c2'), { author_uid: 'u3', content: 'not a member' })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/posts/p1/comments/c3'), { author_uid: 'u2', content: 'x'.repeat(3000) })
  );
});

test('gym posts: non-owner/non-author CANNOT flip is_announcement or is_pinned, CAN +1 like_count', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/posts/p1', {
    author_uid: 'u1', content: 'hi', is_announcement: false, is_pinned: false,
    like_count: 0, comment_count: 0,
  });
  await assertFails(
    updateDoc(doc(db('u2'), 'gyms/g1/posts/p1'), { is_announcement: true })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'gyms/g1/posts/p1'), { is_pinned: true })
  );
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'gyms/g1/posts/p1'), {
      like_count: 1, liked_by_uids: ['u2'],
    })
  );
  // The gym owner still has unrestricted access (separate branch, untouched).
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'gyms/g1/posts/p1'), { is_pinned: true })
  );
});

test('admin/status: a user CANNOT self-grant admin', async () => {
  // admin/status/{uid}/flags (per firestore.rules:32) — 4 segments, a valid
  // document reference. No match block exists for this path at all (only
  // admin_roles/admin_audit do — admin_config's rule was removed outright,
  // Faz A §A9, not merely absent here), so this exercises the implicit
  // default-deny at the bottom of firestore.rules, same as a real client
  // attempt against this not-yet-built path would hit.
  await assertFails(
    setDoc(doc(db('u1'), 'admin/status/u1/flags'), { is_admin: true })
  );
});

test('admin_roles: write is denied to everyone via client SDK, even an admin (BLK-05)', async () => {
  // admin_roles/{uid} is console/Admin-SDK only (write: false unconditionally)
  // — the whole bootstrap runbook depends on this being true, since it's the
  // only thing that makes a self-granted admin claim impossible.
  await seed('admin_roles/u1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('u1'), 'admin_roles/u2'), { is_admin: true })
  );
});

test('admin-only collections: provisioned admin reads, non-admin denied (BLK-05)', async () => {
  // admin_roles/{uid} is the real admin gate (isAdmin() in firestore.rules).
  // Seed it directly to simulate a console-provisioned admin — this is the
  // only way it's ever created for real too. u2 has no admin_roles doc, i.e.
  // the default state of every account before BLK-05.
  //
  // admin_config REMOVED from this list (Faz A §A9) — it's no longer an
  // "admin-only" collection, it's a "nobody, not even an admin" collection
  // now that its rule has been deleted outright (see the dedicated
  // admin_config test further down).
  await seed('admin_roles/u1', { is_admin: true });
  await seed('admin_audit/a1', { action: 'test', admin_uid: 'u1' });
  await seed('ai_usage_logs/l1', { uid: 'u2', cost: 1 });

  await assertSucceeds(getDoc(doc(db('u1'), 'admin_audit/a1')));
  await assertSucceeds(getDoc(doc(db('u1'), 'ai_usage_logs/l1')));

  await assertFails(getDoc(doc(db('u2'), 'admin_audit/a1')));
  await assertFails(getDoc(doc(db('u2'), 'ai_usage_logs/l1')));
});

test('admin_users: write is denied to everyone via client SDK, even an admin (M1.4)', async () => {
  // admin_users/{uid} (fine-grained permissions, layered on top of the
  // admin_roles coarse gate — DECISIONS.md ADR-024) follows the exact same
  // console/Admin-SDK-only posture as admin_roles: self-granting a role or
  // permission would be privilege escalation.
  await seed('admin_roles/u1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('u1'), 'admin_users/u2'), { role: 'owner' })
  );
});

test('admin_users: owner reads own doc, any admin reads others\', neither for a stranger (M1.4)', async () => {
  await seed('admin_roles/u1', { is_admin: true });
  await seed('admin_users/u2', {
    role: 'engineer',
    grants: [],
    denials: [],
    status: 'active',
    permissions_version: 1,
  });

  // u1: admin (via admin_roles), not the doc's owner — isAdmin() branch.
  await assertSucceeds(getDoc(doc(db('u1'), 'admin_users/u2')));
  // u2: the doc's owner, no admin_roles doc of their own — isOwner() branch.
  await assertSucceeds(getDoc(doc(db('u2'), 'admin_users/u2')));
  // u3: neither owner nor admin.
  await assertFails(getDoc(doc(db('u3'), 'admin_users/u2')));
});

// ─── Notifications / friends / follow (BLK-03, SEC-06) ──────────────────────

test('notifications: client CANNOT create even for themselves; owner reads/marks-read/dismisses', async () => {
  // Canonical path notifications/{uid}/items/{docId} — the whole point of
  // BLK-03 is that this is Cloud-Functions-only, so even u1 creating their
  // OWN notification doc must fail (that used to be exactly how a forged
  // actorName got into someone else's inbox on the old path).
  await assertFails(
    setDoc(doc(db('u1'), 'notifications/u1/items/n1'), {
      type: 'system',
      isRead: false,
      actorName: 'Forged Name',
    })
  );

  await seed('notifications/u1/items/n1', {
    type: 'follow',
    isRead: false,
    actorUid: 'u2',
    actorName: 'B',
  });
  await assertSucceeds(getDoc(doc(db('u1'), 'notifications/u1/items/n1')));
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'notifications/u1/items/n1'), { isRead: true })
  );
  await assertFails(getDoc(doc(db('u2'), 'notifications/u1/items/n1')));
  await assertFails(
    setDoc(doc(db('u2'), 'notifications/u1/items/n2'), { type: 'system' })
  );
});

test('notifications: old users/{uid}/notifications path is retired (BLK-03)', async () => {
  // This path was the original forgery hole (allow create: if isAuthenticated(),
  // no field checks). It has no rule at all now — falls to the catch-all deny,
  // same as any other unmodelled path.
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/notifications/n1'), { type: 'system' })
  );
});

test('friends: client CANNOT create/update another user into their list; owner CAN still unfriend (delete)', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u2/friends/u1'), { since: 1 })
  );
  await seed('users/u1/friends/u2', { since: 1 });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/friends/u2'), { since: 2 })
  );
  await assertSucceeds(deleteDoc(doc(db('u1'), 'users/u1/friends/u2')));
});

test('friend_requests: fully server-only — client CANNOT create, update or delete (SEC-06)', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u2/friend_requests/u1'), { type: 'incoming' })
  );
  await seed('users/u1/friend_requests/u2', { type: 'outgoing' });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/friend_requests/u2'), { type: 'incoming' })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/friend_requests/u2')));
});

// ─── Faz 0 audit fix: gym join / check-in was unreachable ──────────────────
// Previously `gyms/{id}/members/{memberId}` write required gym-owner-or-
// admin, so a member could never write their OWN membership doc — joinGym,
// leaveGym, and _recordCheckIn (which updates last_check_in on the member
// doc in the same batch as the checkin create) all failed for every
// non-owner. These tests lock in the fix and its boundaries.

test('gym members: a user CAN self-join at standard tier, CANNOT self-join at premium', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1', member_count: 0 });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'gyms/g1/members/u2'), {
      tier: 'standard', joined_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u3'), 'gyms/g1/members/u3'), {
      tier: 'premium', joined_at: serverTimestamp(),
    })
  );
});

test('gym members: owner CAN create a member at any tier (e.g. their own premium record)', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1', member_count: 0 });
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'gyms/g1/members/owner1'), {
      tier: 'premium', joined_at: serverTimestamp(),
    })
  );
});

test('gyms: a non-owner CAN bump member_count by exactly ±1, CANNOT set it arbitrarily', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1', member_count: 5 });
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'gyms/g1'), { member_count: 6 })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'gyms/g1'), { member_count: 500 })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'gyms/g1'), { member_count: 6, city: 'Istanbul' })
  );
});

test('gyms: owner CANNOT write live_occupancy directly (Faz 1 §1.4/1.5 — server-only counter)', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1', live_occupancy: 3, city: 'Istanbul' });
  await assertFails(
    updateDoc(doc(db('owner1'), 'gyms/g1'), { live_occupancy: 999 })
  );
  // Owner still has full control of ordinary fields — only live_occupancy is fenced off.
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'gyms/g1'), { city: 'Ankara' })
  );
  // Admin retains the escape hatch (support fixing a stuck counter).
  await seed('admin_roles/admin1', { is_admin: true });
  await assertSucceeds(
    updateDoc(doc(db('admin1'), 'gyms/g1'), { live_occupancy: 0 })
  );
});

test('gym members: a member CAN record their own check-in timestamp, CANNOT touch other fields or backdate it', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1', member_count: 1 });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'gyms/g1/members/u2'), {
      last_check_in: serverTimestamp(),
    })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'gyms/g1/members/u2'), { tier: 'premium' })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'gyms/g1/members/u2'), {
      last_check_in: new Date(),
    })
  );
});

test('gym members: a member CAN leave (delete their own doc); CANNOT delete another member', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await seed('gyms/g1/members/u3', { tier: 'standard' });
  await assertSucceeds(deleteDoc(doc(db('u2'), 'gyms/g1/members/u2')));
  await assertFails(deleteDoc(doc(db('u2'), 'gyms/g1/members/u3')));
});

// Faz 5 §5.3 fix — gyms/{id}/members read was owner-or-self only, so a
// regular member could read their OWN doc but never anyone else's, and
// (this is the part a single getDoc test can't prove — Firestore evaluates
// LIST/query requests against every document the query COULD return, not
// per-document) an unfiltered `.collection('members').limit(200).get()`
// list query — exactly what GymLeaderboardService.getWeeklyLeaderboardStream
// runs — was rejected OUTRIGHT for every non-owner caller. isGymMember(gymId)
// fixes both, and stays scoped to fellow members only (not thrown open to
// every authenticated user, unlike community_groups' members read).
test('gym members: a fellow member CAN read another member\'s doc directly AND list the whole collection; a non-member CANNOT', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await seed('gyms/g1/members/u3', { tier: 'standard' });

  // Direct doc read: a fellow member (u2) reading ANOTHER member's (u3) doc.
  await assertSucceeds(getDoc(doc(db('u2'), 'gyms/g1/members/u3')));

  // The actual list-query shape the leaderboard uses — unfiltered, capped.
  const membersCol = (uid) => collection(db(uid), 'gyms/g1/members');
  await assertSucceeds(getDocs(membersCol('u2')));

  // A non-member (u4 has no membership doc in g1 at all) gets neither.
  await assertFails(getDoc(doc(db('u4'), 'gyms/g1/members/u3')));
  await assertFails(getDocs(membersCol('u4')));
});

test('gym checkins: SEC-08 fix — no client write of ANY shape succeeds anymore, not even a well-formed one', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  // This exact payload shape used to succeed (create only checked
  // uid/timestamp/method) — the whole point of the SEC-08 fix is that it
  // no longer does. Both real check-in paths (QR, GPS) now go through
  // validateGymCheckin/validateGymGpsCheckin (functions/gym.js, Admin SDK).
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/checkins/c1'), {
      uid: 'u2', timestamp: serverTimestamp(), method: 'qr',
    })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/checkins/c2'), {
      uid: 'u2', timestamp: serverTimestamp(), method: 'gps',
    })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/checkins/c3'), {
      uid: 'u2', timestamp: serverTimestamp(), method: 'manual',
    })
  );
  // Not even the gym's own owner, or a real admin, can write one directly —
  // mirrors this file's app_config lockdown precedent exactly.
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('owner1'), 'gyms/g1/checkins/c4'), {
      uid: 'owner1', timestamp: serverTimestamp(), method: 'qr',
    })
  );
  await assertFails(
    setDoc(doc(db('admin1'), 'gyms/g1/checkins/c5'), {
      uid: 'admin1', timestamp: serverTimestamp(), method: 'qr',
    })
  );
  await seed('gyms/g1/checkins/c6', { uid: 'u2', timestamp: new Date(), method: 'qr' });
  await assertFails(updateDoc(doc(db('u2'), 'gyms/g1/checkins/c6'), { method: 'gps' }));
  await assertFails(deleteDoc(doc(db('u2'), 'gyms/g1/checkins/c6')));
});

// ─── Faz 1 §1.4: gym presence (geofence check-in), server-authoritative ────

test('gym presence: owner and the member themself CAN read; another member CANNOT read someone else\'s', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await seed('gyms/g1/members/u3', { tier: 'standard' });
  await seed('gyms/g1/presence/u2', {
    entered_at: serverTimestamp(), source: 'geofence', last_seen_at: serverTimestamp(),
  });
  await assertSucceeds(getDoc(doc(db('owner1'), 'gyms/g1/presence/u2')));
  await assertSucceeds(getDoc(doc(db('u2'), 'gyms/g1/presence/u2')));
  await assertFails(getDoc(doc(db('u3'), 'gyms/g1/presence/u2')));
});

test('gym presence: no client — not even the member or the owner — can write it directly (server-only)', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/presence/u2'), {
      entered_at: serverTimestamp(), source: 'geofence', last_seen_at: serverTimestamp(),
    })
  );
  await seed('gyms/g1/presence/u2', { entered_at: serverTimestamp(), source: 'geofence' });
  await assertFails(
    updateDoc(doc(db('owner1'), 'gyms/g1/presence/u2'), { source: 'manual_confirm' })
  );
  await assertFails(deleteDoc(doc(db('u2'), 'gyms/g1/presence/u2')));
});

test('gym presence_sessions: owner and the session\'s own uid CAN read; a stranger CANNOT; no client can write', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/presence_sessions/s1', {
    uid: 'u2', entered_at: serverTimestamp(), exited_at: serverTimestamp(),
    duration_minutes: 45, source: 'geofence', ended_by: 'exit',
  });
  await assertSucceeds(getDoc(doc(db('owner1'), 'gyms/g1/presence_sessions/s1')));
  await assertSucceeds(getDoc(doc(db('u2'), 'gyms/g1/presence_sessions/s1')));
  await assertFails(getDoc(doc(db('u4'), 'gyms/g1/presence_sessions/s1')));

  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/presence_sessions/s2'), {
      uid: 'u2', entered_at: serverTimestamp(), exited_at: serverTimestamp(),
      duration_minutes: 10, source: 'qr', ended_by: 'manual',
    })
  );
  await assertFails(
    updateDoc(doc(db('owner1'), 'gyms/g1/presence_sessions/s1'), { duration_minutes: 999 })
  );
  await assertFails(deleteDoc(doc(db('owner1'), 'gyms/g1/presence_sessions/s1')));
});

test('users/{uid}/private/presence_prefs: owner-only via the generic private/{docId} rule (Faz 1 §1.4)', async () => {
  await seed('users/u1/private/presence_prefs', { gym_tracking_enabled: { g1: true } });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/private/presence_prefs')));
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1/private/presence_prefs'), { notify_friends_enabled: true })
  );
  await assertFails(getDoc(doc(db('u2'), 'users/u1/private/presence_prefs')));
});

test('users/{uid}/private/chat_prefs: owner-only via the generic private/{docId} rule (Faz 2 §2.4)', async () => {
  // Pin/archive/mute/delete list-view prefs — no rule change was needed for
  // this doc (see ChatPrefsModel's doc comment), same as presence_prefs
  // above. Locked in here rather than assumed.
  await seed('users/u1/private/chat_prefs', { pinned_chats: { c1: true } });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/private/chat_prefs')));
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1/private/chat_prefs'), { archived_chats: { c2: true } })
  );
  await assertFails(getDoc(doc(db('u2'), 'users/u1/private/chat_prefs')));
  await assertFails(
    updateDoc(doc(db('u2'), 'users/u1/private/chat_prefs'), { muted_chats: { c3: true } })
  );
});

test('gym presence_notify_log: fully server-only — not even the gym owner can read or write it (Faz 1 §1.7)', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/presence_notify_log/u2_u3_20260804', {
    receiver_uid: 'u2', arriving_uid: 'u3', day_key: '20260804',
  });
  await assertFails(getDoc(doc(db('owner1'), 'gyms/g1/presence_notify_log/u2_u3_20260804')));
  await assertFails(getDoc(doc(db('u2'), 'gyms/g1/presence_notify_log/u2_u3_20260804')));
  await assertFails(
    setDoc(doc(db('owner1'), 'gyms/g1/presence_notify_log/u2_u3_20260805'), {
      receiver_uid: 'u2', arriving_uid: 'u3', day_key: '20260805',
    })
  );
});

test('gym private/qr_token: owner and admin read+write, a member and a stranger cannot (Faz 0 §0.7)', async () => {
  // Previously qr_token lived directly on the public gyms/{gymId} doc,
  // readable by any authenticated user — this asserts the replacement path
  // (gyms/{gymId}/private/qr_token) is actually locked down to owner/admin,
  // closing the "read the token without ever scanning" bypass.
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await seed('admin_roles/u3', { is_admin: true });
  await seed('gyms/g1/private/qr_token', {
    token: 'ABC123', expires_at: serverTimestamp(),
  });

  await assertSucceeds(getDoc(doc(db('owner1'), 'gyms/g1/private/qr_token')));
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'gyms/g1/private/qr_token'), {
      token: 'NEW', expires_at: serverTimestamp(),
    })
  );
  await assertSucceeds(getDoc(doc(db('u3'), 'gyms/g1/private/qr_token')));

  // u2 is a real member of g1 but not the owner — still denied. This is the
  // exact property the fix depends on: members must never read this path.
  await assertFails(getDoc(doc(db('u2'), 'gyms/g1/private/qr_token')));
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/private/qr_token'), {
      token: 'HACKED', expires_at: serverTimestamp(),
    })
  );
  // An authenticated stranger with no relationship to the gym at all.
  await assertFails(getDoc(doc(db('u4'), 'gyms/g1/private/qr_token')));
});

// ─── Faz 0 audit fix: community_groups member self-write couldn't escalate ─

test('community_groups: a user CAN self-join as member, CANNOT self-assign owner on someone else\'s group', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 1 });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'community_groups/gr1/members/u2'), {
      role: 'member', joined_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u3'), 'community_groups/gr1/members/u3'), {
      role: 'owner', joined_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u4'), 'community_groups/gr1/members/u4'), {
      role: 'moderator', joined_at: serverTimestamp(),
    })
  );
});

test('community_groups: the real owner CAN self-create their own owner membership doc', async () => {
  // Mirrors CommunityGroupService.createGroup's sequencing: the parent doc
  // is created (and, in this test, seeded) before the owner's membership
  // doc — so this get() always reads an already-committed parent.
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 0 });
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'community_groups/gr1/members/owner1'), {
      role: 'owner', joined_at: serverTimestamp(),
    })
  );
});

test('community_groups: member_count moves by ±1 only; a member CANNOT self-update their own role', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 3 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'community_groups/gr1'), { member_count: 4 })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'community_groups/gr1'), { member_count: 999 })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'community_groups/gr1/members/u2'), { role: 'owner' })
  );
});

test('community_groups: a ban (member_count -1) then unban (member_count +1) nets to the original count — both individually rule-legal ±1 moves (CommunityGroupService.banMember/unbanMember)', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 5 });
  await seed('community_groups/gr1/members/u2', { role: 'member', banned: false });
  // banMember's pair: member_count -1 + banned:true
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'community_groups/gr1'), { member_count: 4 })
  );
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'community_groups/gr1/members/u2'), { banned: true })
  );
  // unbanMember's pair: member_count +1 + banned:false — restores the
  // original count. Before this fix, unbanMember never wrote member_count
  // at all, silently leaving groups permanently under-counted by 1 per
  // ban→unban cycle even though the rules always permitted the +1 move.
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'community_groups/gr1'), { member_count: 5 })
  );
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'community_groups/gr1/members/u2'), { banned: false })
  );
});

test('community_groups: activity_score/activity_updated_at are server-only — the owner CANNOT write them directly (Faz 2 §2.5)', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 1, activity_score: 0 });
  // The owner's otherwise-blanket update rule explicitly excludes these two
  // fields (touchesProtectedGroupFields) — only computeGroupActivityScores
  // (functions/groups.js, Admin SDK) may set them. A client-writable score
  // would be forgeable (trivially "win" the discovery carousel).
  await assertFails(
    updateDoc(doc(db('owner1'), 'community_groups/gr1'), { activity_score: 999999 })
  );
  await assertFails(
    updateDoc(doc(db('owner1'), 'community_groups/gr1'), { activity_updated_at: serverTimestamp() })
  );
  // The block is scoped to exactly these two keys, not a blanket freeze —
  // the owner retains every other field they already had.
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'community_groups/gr1'), { description: 'updated' })
  );
});

// ─── Faz 2 §2.3: unified groups — kind/join_policy, gym auto-create ────────

test('community_groups: create validates kind/join_policy against the schema enum', async () => {
  await assertSucceeds(
    setDoc(doc(db('u1'), 'community_groups/gA'), {
      owner_uid: 'u1', name: 'A', kind: 'gym', join_policy: 'invite',
    })
  );
  await assertFails(
    setDoc(doc(db('u1'), 'community_groups/gB'), {
      owner_uid: 'u1', name: 'B', kind: 'not_a_real_kind',
    })
  );
  await assertFails(
    setDoc(doc(db('u1'), 'community_groups/gC'), {
      owner_uid: 'u1', name: 'C', join_policy: 'not_a_real_policy',
    })
  );
});

test("community_groups: an admin CAN create a group on someone else's behalf (gym auto-create), a non-admin cannot", async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertSucceeds(
    setDoc(doc(db('admin1'), 'community_groups/gymGroup1'), {
      owner_uid: 'gymOwner1', name: 'Gym Group', kind: 'gym',
    })
  );
  await assertFails(
    setDoc(doc(db('randomUser'), 'community_groups/gymGroup2'), {
      owner_uid: 'gymOwner1', name: 'Gym Group 2', kind: 'gym',
    })
  );
});

test('community_groups/members: self-join as member requires join_policy == open', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 1, join_policy: 'open' });
  await seed('community_groups/gr2', { owner_uid: 'owner1', member_count: 1, join_policy: 'request' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'community_groups/gr1/members/u2'), {
      role: 'member', joined_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'community_groups/gr2/members/u2'), {
      role: 'member', joined_at: serverTimestamp(),
    })
  );
});

test("community_groups/members: a group-level admin CAN add another user as member, CANNOT grant them owner", async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/adm1', { role: 'admin' });
  await assertSucceeds(
    setDoc(doc(db('adm1'), 'community_groups/gr1/members/u5'), {
      role: 'member', joined_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('adm1'), 'community_groups/gr1/members/u6'), {
      role: 'owner', joined_at: serverTimestamp(),
    })
  );
});

test('community_groups/members: a group-level admin CAN mute/ban another member, CANNOT change their role', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 3 });
  await seed('community_groups/gr1/members/adm1', { role: 'admin' });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await assertSucceeds(
    updateDoc(doc(db('adm1'), 'community_groups/gr1/members/u2'), { muted_until: serverTimestamp() })
  );
  await assertSucceeds(
    updateDoc(doc(db('adm1'), 'community_groups/gr1/members/u2'), { banned: true })
  );
  await assertFails(
    updateDoc(doc(db('adm1'), 'community_groups/gr1/members/u2'), { role: 'moderator' })
  );
});

test('community_groups/members: a group-level admin CAN kick (delete) a member; a plain member CANNOT kick another', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 3 });
  await seed('community_groups/gr1/members/adm1', { role: 'admin' });
  await seed('community_groups/gr1/members/u7', { role: 'member' });
  await seed('community_groups/gr1/members/u8', { role: 'member' });
  await seed('community_groups/gr1/members/u9', { role: 'member' });
  await assertSucceeds(deleteDoc(doc(db('adm1'), 'community_groups/gr1/members/u7')));
  await assertFails(deleteDoc(doc(db('u8'), 'community_groups/gr1/members/u9')));
});

test('join_requests: create succeeds when join_policy is request, fails when open', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', join_policy: 'request' });
  await seed('community_groups/gr2', { owner_uid: 'owner1', join_policy: 'open' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'community_groups/gr1/join_requests/u2'), {
      uid: 'u2', status: 'pending', requested_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'community_groups/gr2/join_requests/u2'), {
      uid: 'u2', status: 'pending', requested_at: serverTimestamp(),
    })
  );
});

test('join_requests: the requester and owner/admin CAN read; a stranger CANNOT; only owner/admin can approve', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', join_policy: 'request' });
  await seed('community_groups/gr1/join_requests/u2', { uid: 'u2', status: 'pending' });
  await assertSucceeds(getDoc(doc(db('u2'), 'community_groups/gr1/join_requests/u2')));
  await assertSucceeds(getDoc(doc(db('owner1'), 'community_groups/gr1/join_requests/u2')));
  await assertFails(getDoc(doc(db('u3'), 'community_groups/gr1/join_requests/u2')));
  await assertFails(
    updateDoc(doc(db('u2'), 'community_groups/gr1/join_requests/u2'), { status: 'approved' })
  );
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'community_groups/gr1/join_requests/u2'), {
      status: 'approved', responded_at: serverTimestamp(), responded_by: 'owner1',
    })
  );
});

test('join_requests: the requester CAN withdraw (delete) their own request; a stranger cannot', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/join_requests/u2', { uid: 'u2', status: 'pending' });
  await assertFails(deleteDoc(doc(db('u3'), 'community_groups/gr1/join_requests/u2')));
  await assertSucceeds(deleteDoc(doc(db('u2'), 'community_groups/gr1/join_requests/u2')));
});

test('moderation: owner/group-admin CAN log a moderation action; a plain member CANNOT', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 3 });
  await seed('community_groups/gr1/members/adm1', { role: 'admin' });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'community_groups/gr1/moderation/m1'), {
      target_uid: 'u2', action: 'mute', issued_by: 'owner1', created_at: serverTimestamp(),
    })
  );
  await assertSucceeds(
    setDoc(doc(db('adm1'), 'community_groups/gr1/moderation/m2'), {
      target_uid: 'u2', action: 'kick', issued_by: 'adm1', created_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'community_groups/gr1/moderation/m3'), {
      target_uid: 'owner1', action: 'ban', issued_by: 'u2', created_at: serverTimestamp(),
    })
  );
});

test('moderation: the target uid CAN read their own entry; a stranger CANNOT; nobody can update or delete it', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/moderation/m1', {
    target_uid: 'u2', action: 'mute', issued_by: 'owner1',
  });
  await assertSucceeds(getDoc(doc(db('u2'), 'community_groups/gr1/moderation/m1')));
  await assertSucceeds(getDoc(doc(db('owner1'), 'community_groups/gr1/moderation/m1')));
  await assertFails(getDoc(doc(db('u3'), 'community_groups/gr1/moderation/m1')));
  await assertFails(
    updateDoc(doc(db('owner1'), 'community_groups/gr1/moderation/m1'), { reason: 'edited' })
  );
  await assertFails(deleteDoc(doc(db('owner1'), 'community_groups/gr1/moderation/m1')));
});

// ─── Faz 2 §2.6: moderation-action rate-limit lock ──────────────────────────
// `functions/moderation.js`'s onGroupModerationActionCreated trigger stamps
// `rate_limits/{uid}.moderation_locked_until` once an owner/group-admin
// crosses the sliding-window threshold — these tests seed that field
// directly (the trigger itself needs Cloud Functions, not the rules
// emulator) and confirm firestore.rules actually enforces it, on all THREE
// paths a mute/kick/ban action touches: the moderation log create, the
// members update (mute/ban), and the members delete (kick). isAdmin() (site
// admin) stays exempt, matching every other protected-field check in this
// file; a member's own self-leave is also exempt (it isn't moderation).

test('moderation: create is denied while the owner/admin is moderation-rate-limited; isAdmin() is exempt', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('rate_limits/owner1', { moderation_locked_until: new Date(Date.now() + 60000) });
  await assertFails(
    setDoc(doc(db('owner1'), 'community_groups/gr1/moderation/mLocked'), {
      target_uid: 'u2', action: 'mute', issued_by: 'owner1', created_at: serverTimestamp(),
    })
  );
  await assertSucceeds(
    setDoc(doc(db('admin1'), 'community_groups/gr1/moderation/mAdmin'), {
      target_uid: 'u2', action: 'mute', issued_by: 'admin1', created_at: serverTimestamp(),
    })
  );
});

test('community_groups/members: mute/ban update is denied while the actor is moderation-rate-limited; unaffected once the lock expires', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('rate_limits/owner1', { moderation_locked_until: new Date(Date.now() + 60000) });
  await assertFails(
    updateDoc(doc(db('owner1'), 'community_groups/gr1/members/u2'), { banned: true })
  );
  await seed('rate_limits/owner1', { moderation_locked_until: new Date(Date.now() - 60000) });
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'community_groups/gr1/members/u2'), { banned: true })
  );
});

test('community_groups/members: kick (delete) by an owner/admin is denied while rate-limited; a member leaving themselves is unaffected', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 3 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('community_groups/gr1/members/u3', { role: 'member' });
  await seed('rate_limits/owner1', { moderation_locked_until: new Date(Date.now() + 60000) });
  await assertFails(deleteDoc(doc(db('owner1'), 'community_groups/gr1/members/u2')));
  // u3 leaving of their own accord is NOT a moderation action — owner1's
  // lock must not spill over onto anyone else's self-leave.
  await assertSucceeds(deleteDoc(doc(db('u3'), 'community_groups/gr1/members/u3')));
});

test('community_groups/secrets/invite: owner/admin read+write; a member and a stranger cannot', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'community_groups/gr1/secrets/invite'), {
      code: 'ABCD1234', created_by: 'owner1', created_at: serverTimestamp(),
    })
  );
  await assertSucceeds(getDoc(doc(db('owner1'), 'community_groups/gr1/secrets/invite')));
  await assertFails(getDoc(doc(db('u2'), 'community_groups/gr1/secrets/invite')));
  await assertFails(
    setDoc(doc(db('u2'), 'community_groups/gr1/secrets/invite'), { code: 'HACKED' })
  );
});

test("group_invites: nobody can read it; owner/group-admin of the referenced group CAN create/deactivate; a stranger cannot", async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/members/adm1', { role: 'admin' });
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'group_invites/CODE123'), {
      group_id: 'gr1', is_active: true, created_by: 'owner1',
    })
  );
  await assertFails(getDoc(doc(db('owner1'), 'group_invites/CODE123')));
  await assertSucceeds(
    setDoc(doc(db('adm1'), 'group_invites/CODE456'), {
      group_id: 'gr1', is_active: true, created_by: 'adm1',
    })
  );
  await assertFails(
    setDoc(doc(db('u9'), 'group_invites/CODE789'), {
      group_id: 'gr1', is_active: true, created_by: 'u9',
    })
  );
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'group_invites/CODE123'), { is_active: false })
  );
});

// ─── Faz 2 §2.3: group-backed chats — the group's own "akış + sohbet" ──────
// A group-backed chat (`chats/{chatId}.groupId` set) grants the WHOLE
// group's membership access via canAccessGroupChat()/canPostInGroup(), not
// just whoever is in `participants` (which only ever holds the owner).

test('chats: an admin CAN create a chat whose only participant is someone else (gym auto-create); a non-admin cannot', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertSucceeds(
    setDoc(doc(db('admin1'), 'chats/gymChat1'), {
      participants: ['gymOwner1'], type: 'gym', groupId: 'gymGroup1', unreadCounts: { gymOwner1: 0 },
    })
  );
  await assertFails(
    setDoc(doc(db('randomUser'), 'chats/gymChat2'), {
      participants: ['gymOwner1'], type: 'gym', groupId: 'gymGroup1', unreadCounts: { gymOwner1: 0 },
    })
  );
});

test("chats: a group member (not in participants) CAN read a group-backed chat via groupId; a non-member cannot", async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await assertSucceeds(getDoc(doc(db('u2'), 'chats/gr1')));
  await assertFails(getDoc(doc(db('u9'), 'chats/gr1')));
});

test("messages: announcement_only blocks a plain group member's post; owner/admin CAN still post", async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2, announcement_only: true });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await assertFails(
    setDoc(doc(db('u2'), 'chats/gr1/messages/m1'), {
      id: 'm1', senderId: 'u2', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(), client_id: 'm1',
    })
  );
  await assertSucceeds(
    setDoc(doc(db('owner1'), 'chats/gr1/messages/m2'), {
      id: 'm2', senderId: 'owner1', type: 'announcement', body: 'listen up',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(), client_id: 'm2',
    })
  );
});

test('messages: a plain group member CAN still react even when announcement_only is on ("diğerleri okur + tepki verir")', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2, announcement_only: true });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await seed('chats/gr1/messages/m1', { senderId: 'owner1', type: 'announcement', body: 'hi' });
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'chats/gr1/messages/m1'), { 'reactions.🔥': ['u2'] })
  );
});

test('messages: a muted group member CANNOT post even when announcement_only is off', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2, announcement_only: false });
  await seed('community_groups/gr1/members/u2', {
    role: 'member', muted_until: new Date(Date.now() + 60000),
  });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await assertFails(
    setDoc(doc(db('u2'), 'chats/gr1/messages/m1'), {
      id: 'm1', senderId: 'u2', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(), client_id: 'm1',
    })
  );
});

test('chats/messages: a banned group member CANNOT read the chat or post', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member', banned: true });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await assertFails(getDoc(doc(db('u2'), 'chats/gr1')));
  await assertFails(
    setDoc(doc(db('u2'), 'chats/gr1/messages/m1'), {
      id: 'm1', senderId: 'u2', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(), client_id: 'm1',
    })
  );
});

test('messages: a non-member CANNOT post in a group-backed chat', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 1 });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await assertFails(
    setDoc(doc(db('u9'), 'chats/gr1/messages/m1'), {
      id: 'm1', senderId: 'u9', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(), client_id: 'm1',
    })
  );
});

// ─── Faz 2 §2.6: moderator message takedown ─────────────────────────────────
// A group owner/admin (or site admin) may flip is_deleted/deleted_for on
// ANOTHER member's message — but never rewrite body, and never outside a
// group-backed chat. Distinct from the sender's own canEditOwnMessage()
// path (15-minute window, body-clearing) already covered above.

test("messages: the group owner CAN take down another member's message (moderator delete)", async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await seed('chats/gr1/messages/m1', { senderId: 'u2', type: 'text', body: 'bad words' });
  await assertSucceeds(
    updateDoc(doc(db('owner1'), 'chats/gr1/messages/m1'), {
      is_deleted: true, deleted_for: 'everyone',
    })
  );
});

test("messages: a group-level admin CAN take down another member's message; a plain member CANNOT", async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 3 });
  await seed('community_groups/gr1/members/adm1', { role: 'admin' });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('community_groups/gr1/members/u3', { role: 'member' });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await seed('chats/gr1/messages/m1', { senderId: 'u2', type: 'text', body: 'bad words' });
  await seed('chats/gr1/messages/m2', { senderId: 'u2', type: 'text', body: 'more bad words' });
  await assertSucceeds(
    updateDoc(doc(db('adm1'), 'chats/gr1/messages/m1'), {
      is_deleted: true, deleted_for: 'everyone',
    })
  );
  await assertFails(
    updateDoc(doc(db('u3'), 'chats/gr1/messages/m2'), {
      is_deleted: true, deleted_for: 'everyone',
    })
  );
});

test("messages: moderator delete CANNOT also rewrite body (only is_deleted/deleted_for may move)", async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  await seed('chats/gr1/messages/m1', { senderId: 'u2', type: 'text', body: 'bad words' });
  await assertFails(
    updateDoc(doc(db('owner1'), 'chats/gr1/messages/m1'), {
      is_deleted: true, deleted_for: 'everyone', body: 'rewritten by moderator',
    })
  );
});

test('messages: moderator delete has no meaning outside a group-backed chat (a private-chat participant CANNOT use it on the other side)', async () => {
  await seed('chats/dm1', {
    participants: ['a1', 'b1'], type: 'private', unreadCounts: { a1: 0, b1: 0 },
  });
  await seed('chats/dm1/messages/m1', { senderId: 'b1', type: 'text', body: 'hello' });
  await assertFails(
    updateDoc(doc(db('a1'), 'chats/dm1/messages/m1'), {
      is_deleted: true, deleted_for: 'everyone',
    })
  );
});

// ─── Faz 2 §2.6: kicked/banned members actually lose write access ──────────

test('community_groups/members: a kicked member loses chat read/post access afterward', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1', member_count: 2 });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('chats/gr1', {
    participants: ['owner1'], type: 'group', groupId: 'gr1', unreadCounts: { owner1: 0 },
  });
  // Confirm access existed beforehand, then the owner kicks u2 (deletes their
  // membership doc) exactly as CommunityGroupService.kickMember does.
  await assertSucceeds(getDoc(doc(db('u2'), 'chats/gr1')));
  await assertSucceeds(deleteDoc(doc(db('owner1'), 'community_groups/gr1/members/u2')));
  await assertFails(getDoc(doc(db('u2'), 'chats/gr1')));
  await assertFails(
    setDoc(doc(db('u2'), 'chats/gr1/messages/m1'), {
      id: 'm1', senderId: 'u2', type: 'text', body: 'let me back in',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(), client_id: 'm1',
    })
  );
});

// ─── Faz 0 audit fix: reports/signals/comments field-name mismatches ───────
// firestore.rules already required these exact field names; the app-side
// models/services wrote a different name and were silently denied. These
// tests document the shape the (now-fixed) client code must send.

test('reports: create requires reporterId == auth.uid (not reporterUid/reportedBy)', async () => {
  await assertSucceeds(
    setDoc(doc(db('u1'), 'reports/r1'), {
      reporterId: 'u1', targetType: 'post', targetId: 'p1', reason: 'spam',
    })
  );
  await assertFails(
    setDoc(doc(db('u1'), 'reports/r2'), {
      reporterUid: 'u1', targetType: 'post', targetId: 'p1', reason: 'spam',
    })
  );
});

// ─── Faz 2 §2.6: reactive rate-limit lock (functions/rate_limit.js stamps
// this once a sliding-window trigger detects a burst; these tests seed the
// resulting `rate_limits/{uid}` doc directly rather than exercising the
// trigger itself, which needs Cloud Functions, not just the rules emulator) ─

test('reports: create is denied while report_locked_until is in the future; succeeds once it has passed', async () => {
  await seed('rate_limits/u1', { report_locked_until: new Date(Date.now() + 60000) });
  await assertFails(
    setDoc(doc(db('u1'), 'reports/rLocked'), {
      reporterId: 'u1', targetType: 'post', targetId: 'p1', reason: 'spam',
    })
  );
  await seed('rate_limits/u2', { report_locked_until: new Date(Date.now() - 60000) });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'reports/rExpiredLock'), {
      reporterId: 'u2', targetType: 'post', targetId: 'p1', reason: 'spam',
    })
  );
});

test('signals: create requires userId == auth.uid (not senderId)', async () => {
  await assertSucceeds(
    setDoc(doc(db('u1'), 'signals/s1'), {
      userId: 'u1', message: 'need a spotter', createdAt: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u1'), 'signals/s2'), {
      senderId: 'u1', message: 'need a spotter', createdAt: serverTimestamp(),
    })
  );
});

test('post comments: create requires a top-level authorId matching auth.uid', async () => {
  await seed('posts/p1', { authorId: 'u9', content: 'hi' });
  await assertSucceeds(
    setDoc(doc(db('u1'), 'posts/p1/comments/c1'), {
      authorId: 'u1', content: 'nice', likesCount: 0,
    })
  );
  // The pre-fix shape — nested author.id only, no top-level authorId.
  await assertFails(
    setDoc(doc(db('u1'), 'posts/p1/comments/c2'), {
      author: { id: 'u1' }, content: 'nice', likesCount: 0,
    })
  );
});

// ─── Faz 0 audit fix: a chat participant could rewrite chat membership ────

test('chats: a participant CAN update lastMessage/typingUsers, CANNOT touch participants/type/createdBy', async () => {
  await seed('chats/c1', {
    participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 },
  });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'chats/c1'), { 'typingUsers.u1': true })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1'), { participants: ['u1', 'u2', 'u3'] })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1'), { type: 'group' })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1'), { createdBy: 'u1' })
  );
});

// ─── Faz 2 §2.1: message model v2 — create validation ─────────────────────
// Before this, create only checked senderId + a `text` size cap; update let
// ANY participant rewrite ANY field of ANYONE's message. This is the first
// rules coverage this suite has ever had for the messages subcollection.

test('messages: a participant CAN create a valid v2 message (serverTimestamp() sentinel required)', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertSucceeds(
    setDoc(doc(db('u1'), 'chats/c1/messages/m1'), {
      id: 'm1', senderId: 'u1', type: 'text', body: 'hello',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm1',
    })
  );
});

test('messages: create FAILS if senderId does not match auth.uid (spoofed sender)', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/m2'), {
      id: 'm2', senderId: 'u2', type: 'text', body: 'hello',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm2',
    })
  );
});

test('messages: create FAILS with a client Date instead of a serverTimestamp() sentinel', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/m3'), {
      id: 'm3', senderId: 'u1', type: 'text', body: 'hello',
      server_timestamp: new Date(), timestamp: serverTimestamp(),
      client_id: 'm3',
    })
  );
});

test('messages: create FAILS when body exceeds the 5000-char cap', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/m4'), {
      id: 'm4', senderId: 'u1', type: 'text', body: 'x'.repeat(5001),
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm4',
    })
  );
});

test('messages: create FAILS if read_by/reactions arrive pre-populated (forged social proof)', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/m5'), {
      id: 'm5', senderId: 'u1', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm5', read_by: ['u2'],
    })
  );
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/m6'), {
      id: 'm6', senderId: 'u1', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm6', reactions: { '🔥': ['u1'] },
    })
  );
});

test('messages: create FAILS with an unlisted extra field', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/m7'), {
      id: 'm7', senderId: 'u1', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm7', totally_made_up_field: true,
    })
  );
});

test('messages: create FAILS with a type outside the schema enum', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/m8'), {
      id: 'm8', senderId: 'u1', type: 'voice_note', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm8',
    })
  );
});

test('messages: a non-participant CANNOT create a message in someone else\'s chat', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertFails(
    setDoc(doc(db('u3'), 'chats/c1/messages/m9'), {
      id: 'm9', senderId: 'u3', type: 'text', body: 'hi',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(),
      client_id: 'm9',
    })
  );
});

// ─── Faz 2 §2.1: message model v2 — update rules ───────────────────────────
// Split between the sender's own 15-minute content-edit window
// (canEditOwnMessage) and any participant's engagement touches — reactions/
// read receipts/delivery receipts/"delete for me" (canUpdateMessageEngagement).

test('messages: the sender CAN edit body within the 15-minute window; another participant CANNOT', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await seed('chats/c1/messages/m10', {
    id: 'm10', senderId: 'u1', type: 'text', body: 'original',
    server_timestamp: new Date(), // "now" — well within the 15-min window
  });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'chats/c1/messages/m10'), {
      body: 'edited', edited_at: serverTimestamp(),
    })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'chats/c1/messages/m10'), { body: 'hijacked' })
  );
});

test('messages: the sender CANNOT edit body once the 15-minute window has passed', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  const twentyMinAgo = new Date(Date.now() - 20 * 60 * 1000);
  await seed('chats/c1/messages/m11', {
    id: 'm11', senderId: 'u1', type: 'text', body: 'original',
    server_timestamp: twentyMinAgo,
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1/messages/m11'), { body: 'too late' })
  );
});

test('messages: a pre-migration message (no server_timestamp at all) is never editable', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await seed('chats/c1/messages/old1', {
    id: 'old1', senderId: 'u1', text: 'legacy message', type: 'text',
    timestamp: new Date(), isRead: false,
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1/messages/old1'), { body: 'trying to edit' })
  );
});

test('messages: any participant CAN append read_by/delivered_to/reactions (engagement fields)', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await seed('chats/c1/messages/m12', {
    id: 'm12', senderId: 'u1', type: 'text', body: 'hi',
    server_timestamp: new Date(), read_by: [], delivered_to: [], reactions: {},
  });
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'chats/c1/messages/m12'), { read_by: ['u2'] })
  );
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'chats/c1/messages/m12'), { delivered_to: ['u2'] })
  );
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'chats/c1/messages/m12'), { 'reactions.🔥': ['u2'] })
  );
});

test('messages: a non-sender CANNOT change body even while also touching an engagement field', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await seed('chats/c1/messages/m13', {
    id: 'm13', senderId: 'u1', type: 'text', body: 'hi',
    server_timestamp: new Date(), read_by: [],
  });
  await assertFails(
    updateDoc(doc(db('u2'), 'chats/c1/messages/m13'), {
      body: 'hijacked', read_by: ['u2'],
    })
  );
});

test("messages: deleted_for can only become the 'everyone' string via the sender's own edit window, never via the engagement path", async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await seed('chats/c1/messages/m14', {
    id: 'm14', senderId: 'u1', type: 'text', body: 'hi', server_timestamp: new Date(),
  });
  // Sender, within window: CAN delete for everyone.
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'chats/c1/messages/m14'), {
      is_deleted: true, deleted_for: 'everyone', body: '',
    })
  );

  await seed('chats/c1/messages/m15', {
    id: 'm15', senderId: 'u1', type: 'text', body: 'hi', server_timestamp: new Date(),
  });
  // A different participant CANNOT set the 'everyone' string themselves...
  await assertFails(
    updateDoc(doc(db('u2'), 'chats/c1/messages/m15'), { deleted_for: 'everyone' })
  );
  // ...but CAN add themselves to a "delete for me" array.
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'chats/c1/messages/m15'), { deleted_for: ['u2'] })
  );
});

// ─── Faz 2 §2.1: chats.unreadCounts — self-zero only, increments server-only ─
// Increments now come exclusively from onChatMessageCreated (Admin SDK,
// bypasses rules); these lock down what a CLIENT may still do directly.

test('chats: a participant CAN zero their OWN unreadCounts key (mark-as-read)', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 3, u2: 0 } });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'chats/c1'), { 'unreadCounts.u1': 0 })
  );
});

test("chats: a participant CANNOT zero ANOTHER participant's unreadCounts key", async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 3, u2: 5 } });
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1'), { 'unreadCounts.u2': 0 })
  );
});

test('chats: a participant CANNOT set their own unreadCounts to a non-zero value (no self-inflating)', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 3, u2: 0 } });
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1'), { 'unreadCounts.u1': 99 })
  );
});

test('chats: zeroing unreadCounts CANNOT be bundled with any other field in the same write', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 3, u2: 0 } });
  await assertFails(
    updateDoc(doc(db('u1'), 'chats/c1'), {
      'unreadCounts.u1': 0, 'typingUsers.u1': true,
    })
  );
});

// ─── Faz 2 §2.2: chat pinning — proves canUpdateChatMeta() already covers it ─
// No firestore.rules change was needed to support pinning: canUpdateChatMeta()
// is a BLOCKLIST (only participants/type/createdBy/unreadCounts are
// protected), so pinnedMessageId/pinnedBy/pinnedAt were already writable by
// any participant before ChatModel even declared them. This test locks that
// assumption in — if canUpdateChatMeta() is ever tightened into an allowlist,
// this goes red instead of pinning silently breaking in the app.

test('chats: a participant CAN set pinnedMessageId/pinnedBy/pinnedAt (no rule change needed)', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'chats/c1'), {
      pinnedMessageId: 'm1', pinnedBy: 'u1', pinnedAt: serverTimestamp(),
    })
  );
  // Unpin (field delete) is likewise just a chat-meta update — no blocked
  // field is touched.
  await assertSucceeds(
    updateDoc(doc(db('u2'), 'chats/c1'), {
      pinnedMessageId: deleteField(), pinnedBy: deleteField(), pinnedAt: deleteField(),
    })
  );
});

// ─── Faz 2 §2.2: starred messages — per-user chat bookmark, owner-only ─────

test('starred_messages: owner CAN star (create) and read their own bookmark', async () => {
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1/starred_messages/m1'), {
      message_id: 'm1', chat_id: 'c1', sender_id: 'u2', body: 'hi', type: 'text',
      starred_at: serverTimestamp(),
    })
  );
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/starred_messages/m1')));
});

test("starred_messages: another user CANNOT read or write someone else's starred messages", async () => {
  await seed('users/u1/starred_messages/m1', {
    message_id: 'm1', chat_id: 'c1', sender_id: 'u2', body: 'hi', type: 'text',
  });
  await assertFails(getDoc(doc(db('u2'), 'users/u1/starred_messages/m1')));
  await assertFails(deleteDoc(doc(db('u2'), 'users/u1/starred_messages/m1')));
});

test('starred_messages: owner CAN unstar (delete) their own bookmark', async () => {
  await seed('users/u1/starred_messages/m1', {
    message_id: 'm1', chat_id: 'c1', sender_id: 'u2', body: 'hi', type: 'text',
  });
  await assertSucceeds(deleteDoc(doc(db('u1'), 'users/u1/starred_messages/m1')));
});

// ─── Faz 0 audit fix (S6): food_logs become immutable once written ────────

test('food_logs: owner CAN create and read, CANNOT update or delete (S6)', async () => {
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1/food_logs/l1'), { calories: 500 })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/food_logs/l1'), { calories: 1 })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/food_logs/l1')));
});

// ─── Faz 2 §2.6: moderation appeals ("itiraz yolu") ─────────────────────────
// Doc id == the SOURCE community_groups/{groupId}/moderation/{autoId}
// entry's own id — the create rule get()s that exact path (using the
// appeal's own id) to confirm it's a real action targeting the caller, so a
// client can't fabricate an appeal against an action that isn't theirs.

test('moderation_appeals: the real target of a moderation action CAN appeal it; a mismatched uid or wrong action CANNOT', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/moderation/act1', {
    target_uid: 'u2', action: 'ban', issued_by: 'owner1',
  });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'moderation_appeals/act1'), {
      uid: 'u2', group_id: 'gr1', group_name: 'Test Group', action: 'ban',
      message: 'this was a mistake', status: 'pending', created_at: serverTimestamp(),
    })
  );
  // A stranger cannot file under someone else's targeted action.
  await assertFails(
    setDoc(doc(db('u3'), 'moderation_appeals/act1b'), {
      uid: 'u3', group_id: 'gr1', group_name: 'Test Group', action: 'ban',
      message: 'not my ban', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

test('moderation_appeals: create FAILS when the appeal id does not name a real moderation action targeting the caller', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/moderation/act2', {
    target_uid: 'someoneElse', action: 'mute', issued_by: 'owner1',
  });
  await assertFails(
    setDoc(doc(db('u2'), 'moderation_appeals/act2'), {
      uid: 'u2', group_id: 'gr1', group_name: 'Test Group', action: 'mute',
      message: 'not actually mine', status: 'pending', created_at: serverTimestamp(),
    })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'moderation_appeals/doesNotExist'), {
      uid: 'u2', group_id: 'gr1', group_name: 'Test Group', action: 'mute',
      message: 'no such action', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

test('moderation_appeals: read is target-or-admin only; update is admin-only (the appellant CANNOT resolve their own)', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('moderation_appeals/act1', {
    uid: 'u2', group_id: 'gr1', group_name: 'Test Group', action: 'ban',
    message: 'appeal text', status: 'pending',
  });
  await assertSucceeds(getDoc(doc(db('u2'), 'moderation_appeals/act1')));
  await assertSucceeds(getDoc(doc(db('admin1'), 'moderation_appeals/act1')));
  await assertFails(getDoc(doc(db('u3'), 'moderation_appeals/act1')));
  await assertFails(
    updateDoc(doc(db('u2'), 'moderation_appeals/act1'), { status: 'upheld' })
  );
  await assertSucceeds(
    updateDoc(doc(db('admin1'), 'moderation_appeals/act1'), {
      status: 'upheld', resolved_by: 'admin1', resolved_at: serverTimestamp(),
    })
  );
});

test('moderation_appeals: create is denied while the appellant is appeal-rate-limited', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/moderation/act3', {
    target_uid: 'u2', action: 'kick', issued_by: 'owner1',
  });
  await seed('rate_limits/u2', { appeal_locked_until: new Date(Date.now() + 60000) });
  await assertFails(
    setDoc(doc(db('u2'), 'moderation_appeals/act3'), {
      uid: 'u2', group_id: 'gr1', group_name: 'Test Group', action: 'kick',
      message: 'appeal while locked', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

// ─── SEC-12: UGC rate limits, six new kinds (functions/ugc_rate_limit.js) ──
// Same "seed the resulting rate_limits/{uid} doc directly" idiom as
// reports/moderation/appeals above — the trigger itself needs Cloud
// Functions, not just the rules emulator.

test('posts: create is denied while the author is post-rate-limited', async () => {
  await seed('rate_limits/u1', { post_locked_until: new Date(Date.now() + 60000) });
  await assertFails(setDoc(doc(db('u1'), 'posts/pLocked'), { authorId: 'u1', content: 'spam' }));
  await seed('rate_limits/u2', { post_locked_until: new Date(Date.now() - 60000) });
  await assertSucceeds(setDoc(doc(db('u2'), 'posts/pOk'), { authorId: 'u2', content: 'fine' }));
});

test('posts/comments: create is denied while the author is comment-rate-limited', async () => {
  await seed('posts/p1', { authorId: 'owner1', content: 'hi' });
  await seed('rate_limits/u1', { comment_locked_until: new Date(Date.now() + 60000) });
  await assertFails(
    setDoc(doc(db('u1'), 'posts/p1/comments/cLocked'), { authorId: 'u1', content: 'spam' })
  );
});

test('chat messages: create is denied while the sender is message-rate-limited', async () => {
  await seed('chats/c1', { participants: ['u1', 'u2'], type: 'private', unreadCounts: { u1: 0, u2: 0 } });
  await seed('rate_limits/u1', { message_locked_until: new Date(Date.now() + 60000) });
  await assertFails(
    setDoc(doc(db('u1'), 'chats/c1/messages/mLocked'), {
      id: 'mLocked', senderId: 'u1', type: 'text', body: 'spam',
      server_timestamp: serverTimestamp(), timestamp: serverTimestamp(), client_id: 'mLocked',
    })
  );
});

test('community_groups: create is denied while the owner is group-create-rate-limited', async () => {
  await seed('rate_limits/u1', { group_create_locked_until: new Date(Date.now() + 60000) });
  await assertFails(
    setDoc(doc(db('u1'), 'community_groups/grLocked'), { owner_uid: 'u1', name: 'Spam Group' })
  );
});

test('following: create is denied while the follower is follow-rate-limited; unfollowing is unaffected', async () => {
  await seed('rate_limits/u1', { follow_locked_until: new Date(Date.now() + 60000) });
  await assertFails(setDoc(doc(db('u1'), 'users/u1/following/u2'), {}));
  // Unfollowing (delete) is deliberately not gated by this lock.
  await seed('users/u1/following/u3', {});
  await assertSucceeds(deleteDoc(doc(db('u1'), 'users/u1/following/u3')));
});

test('post reactions/likes: create is denied while the user is reaction-rate-limited; un-reacting is unaffected', async () => {
  await seed('rate_limits/u1', { reaction_locked_until: new Date(Date.now() + 60000) });
  await assertFails(setDoc(doc(db('u1'), 'posts/p1/reactions/u1'), { emoji: '🔥' }));
  await assertFails(setDoc(doc(db('u1'), 'posts/p1/likes/u1'), {}));
  await seed('posts/p1/likes/u2', {});
  await assertSucceeds(deleteDoc(doc(db('u2'), 'posts/p1/likes/u2')));
});

// ─── Faz 2 §2.6: rate_limits ledger is fully server-only ───────────────────

test('rate_limits: fully denied to any client read or write, even the doc\'s own uid', async () => {
  await seed('rate_limits/u1', { report_count: 1 });
  await assertFails(getDoc(doc(db('u1'), 'rate_limits/u1')));
  await assertFails(
    setDoc(doc(db('u1'), 'rate_limits/u1'), { report_locked_until: new Date(0) })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'rate_limits/u1')));
});

// ─── Faz 3 §3.2: meal_plan_templates + plan_offers ─────────────────────────

test('meal_plan_templates: author_uid must match the caller — a spoofed author_uid is rejected, a correct one succeeds', async () => {
  await assertFails(
    setDoc(doc(db('gym1'), 'meal_plan_templates/t1'), {
      author_uid: 'someoneElse', author_type: 'gym', share_scope: 'private', is_public: false, name: 'Plan A',
    })
  );
  await assertSucceeds(
    setDoc(doc(db('gym1'), 'meal_plan_templates/t1'), {
      author_uid: 'gym1', author_type: 'gym', share_scope: 'private', is_public: false, name: 'Plan A',
    })
  );
});

test('meal_plan_templates: create validates author_type/share_scope against the schema enum', async () => {
  await assertFails(
    setDoc(doc(db('gym1'), 'meal_plan_templates/t2'), {
      author_uid: 'gym1', author_type: 'bogus', share_scope: 'private', is_public: false, name: 'X',
    })
  );
  await assertFails(
    setDoc(doc(db('gym1'), 'meal_plan_templates/t3'), {
      author_uid: 'gym1', author_type: 'gym', share_scope: 'bogus', is_public: false, name: 'X',
    })
  );
});

test('meal_plan_templates: a new template CANNOT start with a nonzero usage_count', async () => {
  await assertFails(
    setDoc(doc(db('gym1'), 'meal_plan_templates/t4'), {
      author_uid: 'gym1', author_type: 'gym', share_scope: 'private', is_public: false, name: 'X', usage_count: 5,
    })
  );
});

test('meal_plan_templates: a private template is readable only by its author or admin, not a stranger', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('meal_plan_templates/t1', {
    author_uid: 'gym1', author_type: 'gym', share_scope: 'private', is_public: false, name: 'X',
  });
  await assertSucceeds(getDoc(doc(db('gym1'), 'meal_plan_templates/t1')));
  await assertSucceeds(getDoc(doc(db('admin1'), 'meal_plan_templates/t1')));
  await assertFails(getDoc(doc(db('stranger'), 'meal_plan_templates/t1')));
});

test('meal_plan_templates: is_public makes it readable by anyone authenticated', async () => {
  await seed('meal_plan_templates/t1', {
    author_uid: 'gym1', author_type: 'gym', share_scope: 'marketplace', is_public: true, name: 'X',
  });
  await assertSucceeds(getDoc(doc(db('stranger'), 'meal_plan_templates/t1')));
});

test('meal_plan_templates: share_scope==gym is readable by that gym\'s own member, not by an outsider', async () => {
  await seed('meal_plan_templates/t1', {
    author_uid: 'gymOwner', author_type: 'gym', share_scope: 'gym', gym_id: 'g1', is_public: false, name: 'X',
  });
  await seed('gyms/g1/members/member1', { tier: 'standard' });
  await assertSucceeds(getDoc(doc(db('member1'), 'meal_plan_templates/t1')));
  await assertFails(getDoc(doc(db('outsider'), 'meal_plan_templates/t1')));
});

test('meal_plan_templates: a non-author CANNOT update or delete someone else\'s template; the author CAN', async () => {
  await seed('meal_plan_templates/t1', {
    author_uid: 'gym1', author_type: 'gym', share_scope: 'private', is_public: false, name: 'X',
  });
  await assertFails(updateDoc(doc(db('u2'), 'meal_plan_templates/t1'), { name: 'hacked' }));
  await assertFails(deleteDoc(doc(db('u2'), 'meal_plan_templates/t1')));
  await assertSucceeds(updateDoc(doc(db('gym1'), 'meal_plan_templates/t1'), { name: 'renamed' }));
});

test('meal_plan_templates: usage_count is server-only — even the author CANNOT bump it directly', async () => {
  await seed('meal_plan_templates/t1', {
    author_uid: 'gym1', author_type: 'gym', share_scope: 'private', is_public: false, name: 'X', usage_count: 0,
  });
  await assertFails(updateDoc(doc(db('gym1'), 'meal_plan_templates/t1'), { usage_count: 999 }));
});

test('meal_plan_templates: oversized name is rejected on create', async () => {
  const big = 'x'.repeat(3000);
  await assertFails(
    setDoc(doc(db('gym1'), 'meal_plan_templates/t5'), {
      author_uid: 'gym1', author_type: 'gym', share_scope: 'private', is_public: false, name: big,
    })
  );
});

test('plan_offers: create is server-only — a client CANNOT plant an offer, even on themselves', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), {
      template_id: 't1', from_uid: 'u1', from_type: 'gym', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

test('plan_offers: the recipient CAN read their own offer; a stranger CANNOT', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'pending',
  });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/plan_offers/o1')));
  await assertFails(getDoc(doc(db('u2'), 'users/u1/plan_offers/o1')));
});

test('plan_offers: the recipient CAN accept — status+responded_at as a real serverTimestamp() sentinel only', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', template_snapshot: { name: 'X' }, status: 'pending',
  });
  // A client Date instead of the serverTimestamp() sentinel is rejected —
  // same anti-spoof idiom as messages/checkins elsewhere in this file.
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), { status: 'accepted', responded_at: new Date() })
  );
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), { status: 'accepted', responded_at: serverTimestamp() })
  );
});

test('plan_offers: the recipient CANNOT rewrite from_uid or the template_snapshot while responding', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', template_snapshot: { name: 'X' }, status: 'pending',
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), {
      status: 'declined', responded_at: serverTimestamp(), from_uid: 'u1',
    })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), {
      status: 'declined', responded_at: serverTimestamp(), template_snapshot: { name: 'hacked' },
    })
  );
});

test('plan_offers: the recipient CAN decline with no reason — decline_reason is optional', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'pending',
  });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), { status: 'declined', responded_at: serverTimestamp() })
  );
});

test('plan_offers: the recipient CAN decline WITH an optional reason (≤300 chars)', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'pending',
  });
  await assertSucceeds(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), {
      status: 'declined', responded_at: serverTimestamp(), decline_reason: 'Not the right fit for me right now.',
    })
  );
});

test('plan_offers: decline_reason CANNOT be attached to an accept', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'pending',
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), {
      status: 'accepted', responded_at: serverTimestamp(), decline_reason: 'sneaking a reason onto an accept',
    })
  );
});

test('plan_offers: an oversized decline_reason (>300 chars) is rejected', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'pending',
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), {
      status: 'declined', responded_at: serverTimestamp(), decline_reason: 'x'.repeat(301),
    })
  );
});

test('plan_offers: a non-string decline_reason is rejected', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'pending',
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), {
      status: 'declined', responded_at: serverTimestamp(), decline_reason: 12345,
    })
  );
});

test('plan_offers: a non-recipient CANNOT respond to someone else\'s offer', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'pending',
  });
  await assertFails(
    updateDoc(doc(db('u2'), 'users/u1/plan_offers/o1'), { status: 'declined', responded_at: serverTimestamp() })
  );
});

test('plan_offers: an already-resolved offer CANNOT be responded to again', async () => {
  await seed('users/u1/plan_offers/o1', {
    template_id: 't1', from_uid: 'gym1', from_type: 'gym', status: 'accepted', responded_at: new Date(),
  });
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/plan_offers/o1'), { status: 'declined', responded_at: serverTimestamp() })
  );
});

test('plan_offers: nobody can delete an offer — durable record, same immutability class as food_logs/checkins', async () => {
  await seed('users/u1/plan_offers/o1', { template_id: 't1', from_uid: 'gym1', status: 'pending' });
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/plan_offers/o1')));
});

// ─── Faz 4 §4.1/§4.2: tiered progress-sharing consent + summary cache ──────
// NOTE on coverage boundary: this suite runs `--only firestore` (no Functions
// emulator), so it can only assert RULES — the callable's own tier-0
// rejection (generateMemberProgressSummary throwing permission-denied at
// level<=0) and the onProgressSharingWrite trigger's actual cache-deletion
// are function LOGIC, not rules, and cannot fire here (confirmed: this repo
// has no functional Cloud Functions test harness — see functions/summaries.js
// for that logic). What IS proven below is the data-layer invariant that
// makes both of those meaningful: a client can never create, forge, or erase
// a member_summaries doc directly — REGARDLESS of the scope's current tier —
// so the callable's server-side tier check is the only possible gate, and
// the trigger's delete is the only possible way a cached doc goes away
// early.

test('progress_sharing: owner CAN grant a valid tier with a server timestamp', async () => {
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), {
      level: 1, policy_version: '2026-06-29', granted_at: serverTimestamp(), revoked_at: null,
    })
  );
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1')));
});

test('progress_sharing: owner CAN revoke (level 0) with a server-timestamped revoked_at, via a partial merge', async () => {
  await seed('users/u1/progress_sharing/gym_g1', {
    level: 2, policy_version: '2026-06-29', granted_at: new Date(), revoked_at: null,
  });
  // A merge-only update (ProgressSharingService.revoke's real shape) that
  // never re-sends granted_at — proves the rule doesn't require touching it
  // on revoke (Firestore's own merge semantics carry the prior value
  // forward; nothing rules-specific to assert beyond this write succeeding).
  await assertSucceeds(
    setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), {
      level: 0, policy_version: '2026-06-29', revoked_at: serverTimestamp(),
    }, { merge: true })
  );
});

test('progress_sharing: a client CANNOT set an out-of-range or non-integer level', async () => {
  const base = { policy_version: '2026-06-29', granted_at: serverTimestamp(), revoked_at: null };
  await assertFails(setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), { ...base, level: 4 }));
  await assertFails(setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), { ...base, level: -1 }));
  await assertFails(setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), { ...base, level: '2' }));
});

test('progress_sharing: a client CANNOT set an empty/missing policy_version', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), {
      level: 1, policy_version: '', granted_at: serverTimestamp(), revoked_at: null,
    })
  );
});

test('progress_sharing: granted_at CANNOT be a spoofed client timestamp', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), {
      level: 1, policy_version: '2026-06-29', granted_at: new Date(), revoked_at: null,
    })
  );
});

test('progress_sharing: granting (level>0) with a non-null revoked_at is rejected', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1'), {
      level: 1, policy_version: '2026-06-29', granted_at: serverTimestamp(), revoked_at: serverTimestamp(),
    })
  );
});

test('progress_sharing: a stranger CANNOT read or write another user\'s scope', async () => {
  await seed('users/u1/progress_sharing/coach_c1', {
    level: 3, policy_version: '2026-06-29', granted_at: new Date(), revoked_at: null,
  });
  await assertFails(getDoc(doc(db('u2'), 'users/u1/progress_sharing/coach_c1')));
  await assertFails(
    setDoc(doc(db('u2'), 'users/u1/progress_sharing/coach_c1'), {
      level: 0, policy_version: '2026-06-29', revoked_at: serverTimestamp(),
    }, { merge: true })
  );
});

test('progress_sharing: nobody can delete a scope doc (revoke sets level:0 instead)', async () => {
  await seed('users/u1/progress_sharing/gym_g1', {
    level: 1, policy_version: '2026-06-29', granted_at: new Date(), revoked_at: null,
  });
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/progress_sharing/gym_g1')));
});

test('access_log: owner CAN read their own entries; a stranger CANNOT', async () => {
  await seed('users/u1/access_log/e1', {
    viewer_uid: 'owner1', viewer_type: 'gym', scope_id: 'gym_g1', viewed_at: new Date(),
  });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/access_log/e1')));
  await assertFails(getDoc(doc(db('u2'), 'users/u1/access_log/e1')));
});

test('access_log: fully server-only — not even the owner can write it directly', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/access_log/e2'), {
      viewer_uid: 'owner1', viewer_type: 'gym', scope_id: 'gym_g1', viewed_at: serverTimestamp(),
    })
  );
  await seed('users/u1/access_log/e1', {
    viewer_uid: 'owner1', viewer_type: 'gym', scope_id: 'gym_g1', viewed_at: new Date(),
  });
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/access_log/e1')));
});

test('gym member_summaries: owner and the member themself CAN read; another member CANNOT', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/members/u2', { tier: 'standard' });
  await seed('gyms/g1/members/u3', { tier: 'standard' });
  await seed('gyms/g1/member_summaries/u2', {
    tier: 1, method: 'template', narrative: 'x', fields: {}, generated_by: 'owner1',
  });
  await assertSucceeds(getDoc(doc(db('owner1'), 'gyms/g1/member_summaries/u2')));
  await assertSucceeds(getDoc(doc(db('u2'), 'gyms/g1/member_summaries/u2')));
  await assertFails(getDoc(doc(db('u3'), 'gyms/g1/member_summaries/u2')));
});

test('gym member_summaries: no client — not the owner, not the member — can write it directly, regardless of tier', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  // Even a fully-shared (tier 3) scope must not let a client forge the
  // OUTPUT doc directly — the only legitimate writer is
  // generateMemberProgressSummary (Admin SDK).
  await seed('users/u2/progress_sharing/gym_g1', {
    level: 3, policy_version: '2026-06-29', granted_at: new Date(), revoked_at: null,
  });
  await assertFails(
    setDoc(doc(db('owner1'), 'gyms/g1/member_summaries/u2'), {
      tier: 3, method: 'ai', narrative: 'forged', fields: {}, generated_by: 'owner1',
    })
  );
  await seed('gyms/g1/member_summaries/u2', { tier: 3, method: 'ai', narrative: 'x', fields: {} });
  await assertFails(
    updateDoc(doc(db('owner1'), 'gyms/g1/member_summaries/u2'), { narrative: 'tampered' })
  );
  await assertFails(deleteDoc(doc(db('u2'), 'gyms/g1/member_summaries/u2')));
});

test('coach member_summaries: the coach and the client themself CAN read; a stranger CANNOT', async () => {
  await seed('coach_profiles/coach1', { bio: 'x' });
  await seed('coach_profiles/coach1/clients/u2', { status: 'active' });
  await seed('coach_profiles/coach1/member_summaries/u2', {
    tier: 1, method: 'template', narrative: 'x', fields: {}, generated_by: 'coach1',
  });
  await assertSucceeds(getDoc(doc(db('coach1'), 'coach_profiles/coach1/member_summaries/u2')));
  await assertSucceeds(getDoc(doc(db('u2'), 'coach_profiles/coach1/member_summaries/u2')));
  await assertFails(getDoc(doc(db('u4'), 'coach_profiles/coach1/member_summaries/u2')));
});

test('coach member_summaries: no client can write it directly', async () => {
  await seed('coach_profiles/coach1', { bio: 'x' });
  await assertFails(
    setDoc(doc(db('coach1'), 'coach_profiles/coach1/member_summaries/u2'), {
      tier: 1, method: 'template', narrative: 'x', fields: {}, generated_by: 'coach1',
    })
  );
});

test('gym progress_share_invites: owner CAN read; the invited member and a stranger CANNOT', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await seed('gyms/g1/progress_share_invites/u2', {
    invited_by: 'owner1', invited_at: new Date(),
  });
  await assertSucceeds(getDoc(doc(db('owner1'), 'gyms/g1/progress_share_invites/u2')));
  await assertFails(getDoc(doc(db('u2'), 'gyms/g1/progress_share_invites/u2')));
  await assertFails(getDoc(doc(db('u3'), 'gyms/g1/progress_share_invites/u2')));
});

test('gym progress_share_invites: no client — not even the owner — can write it directly', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await assertFails(
    setDoc(doc(db('owner1'), 'gyms/g1/progress_share_invites/u2'), {
      invited_by: 'owner1', invited_at: serverTimestamp(),
    })
  );
  await seed('gyms/g1/progress_share_invites/u2', { invited_by: 'owner1', invited_at: new Date() });
  await assertFails(deleteDoc(doc(db('owner1'), 'gyms/g1/progress_share_invites/u2')));
});

test('coach progress_share_invites: the coach CAN read; the invited client and a stranger CANNOT', async () => {
  await seed('coach_profiles/coach1', { bio: 'x' });
  await seed('coach_profiles/coach1/progress_share_invites/u2', {
    invited_by: 'coach1', invited_at: new Date(),
  });
  await assertSucceeds(getDoc(doc(db('coach1'), 'coach_profiles/coach1/progress_share_invites/u2')));
  await assertFails(getDoc(doc(db('u2'), 'coach_profiles/coach1/progress_share_invites/u2')));
  await assertFails(getDoc(doc(db('u4'), 'coach_profiles/coach1/progress_share_invites/u2')));
});

test('coach progress_share_invites: no client can write it directly', async () => {
  await seed('coach_profiles/coach1', { bio: 'x' });
  await assertFails(
    setDoc(doc(db('coach1'), 'coach_profiles/coach1/progress_share_invites/u2'), {
      invited_by: 'coach1', invited_at: serverTimestamp(),
    })
  );
});

// SEC-09 — a review used to have no server-side check that the reviewer is
// (or ever was) a real client of that coach; CoachReviewService.canReview()
// checked this client-side only, which a direct API/SDK write bypasses.
test('coach reviews: a linked client CAN create a review; an unlinked stranger CANNOT (SEC-09)', async () => {
  await seed('coach_profiles/coach1', { bio: 'x' });
  await seed('coach_profiles/coach1/clients/u2', { status: 'active' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'coach_profiles/coach1/reviews/u2'), {
      reviewerUid: 'u2', rating: 5, comment: 'great coach',
    })
  );
  // u3 has no coach_profiles/coach1/clients/u3 doc at all.
  await assertFails(
    setDoc(doc(db('u3'), 'coach_profiles/coach1/reviews/u3'), {
      reviewerUid: 'u3', rating: 5, comment: 'never actually a client',
    })
  );
});

test('coach reviews: a linked client cannot forge a review AS someone else', async () => {
  await seed('coach_profiles/coach1', { bio: 'x' });
  await seed('coach_profiles/coach1/clients/u2', { status: 'active' });
  await assertFails(
    setDoc(doc(db('u2'), 'coach_profiles/coach1/reviews/u4'), {
      reviewerUid: 'u4', rating: 5, comment: 'forged',
    })
  );
});

test('coach reviews: immutable once created — no update or delete, even by the reviewer', async () => {
  await seed('coach_profiles/coach1', { bio: 'x' });
  await seed('coach_profiles/coach1/clients/u2', { status: 'active' });
  await seed('coach_profiles/coach1/reviews/u2', { reviewerUid: 'u2', rating: 5 });
  await assertFails(
    updateDoc(doc(db('u2'), 'coach_profiles/coach1/reviews/u2'), { rating: 1 })
  );
  await assertFails(deleteDoc(doc(db('u2'), 'coach_profiles/coach1/reviews/u2')));
});

// ─── Programs (marketplace) — BLK-09 ───────────────────────────────────────
// The `coach_uid == 'demo'` client-write bypass ("reserved for the
// DemoContentSeeder") is removed: it could never distinguish the real
// seeder from an attacker copying the same write, so ANY authenticated
// user could inject fake "Cookrange Team" listings. Demo content now
// seeds server-side only, via seedDemoContent (functions/demo_content.js).

test('programs: an authenticated user CAN create their own program; a stranger cannot forge coach_uid', async () => {
  await assertSucceeds(
    setDoc(doc(db('coach1'), 'programs/p1'), {
      coach_uid: 'coach1', coach_name: 'Coach One', title: 'Real Program',
      difficulty: 'beginner', category: 'lifestyle',
    })
  );
  await assertFails(
    setDoc(doc(db('coach1'), 'programs/p2'), {
      coach_uid: 'someone_else', coach_name: 'Coach One', title: 'Forged owner',
    })
  );
});

test("programs: the 'demo' coach_uid bypass is GONE — no authenticated user can write it directly (BLK-09)", async () => {
  await assertFails(
    setDoc(doc(db('attacker1'), 'programs/fake1'), {
      coach_uid: 'demo', coach_name: 'Cookrange Team', title: 'Fake spam listing',
      difficulty: 'beginner', category: 'lifestyle', is_published: true,
    })
  );
});

test("programs/weeks: the 'demo' coach_uid bypass is GONE on week content too (BLK-09)", async () => {
  await seed('programs/demoProgram1', { coach_uid: 'demo', title: 'Pre-existing demo program' });
  await assertFails(
    setDoc(doc(db('attacker1'), 'programs/demoProgram1/weeks/w1'), {
      week_number: 1, title: 'Injected fake week',
    })
  );
});

test('programs/weeks: the owning coach CAN write their own program\'s week content; a stranger cannot', async () => {
  await seed('programs/p1', { coach_uid: 'coach1', title: 'Real Program' });
  await assertSucceeds(
    setDoc(doc(db('coach1'), 'programs/p1/weeks/w1'), { week_number: 1, title: 'Week 1' })
  );
  await assertFails(
    setDoc(doc(db('u2'), 'programs/p1/weeks/w2'), { week_number: 2, title: 'Injected' })
  );
});

test('seeds/demo: nobody can read or write it directly — the seedDemoContent callable (Admin SDK) is the only path (BLK-09)', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(getDoc(doc(db('u1'), 'seeds/demo')));
  await assertFails(setDoc(doc(db('u1'), 'seeds/demo'), { demo_programs_v1: true }));
  await assertFails(getDoc(doc(db('admin1'), 'seeds/demo')));
});

// ─── Faz 5 §5.2: received-engagement credit ────────────────────────────────

test('engagement_credit_events: owner reads their own ledger, a stranger CANNOT, and NOBODY can write it directly', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/engagement_credit_events/post_reactions_fakepost1'), {
      source: 'post_reactions', credit: 999999, ref_id: 'fakepost1',
      created_at: serverTimestamp(), multiplier_applied: 1,
    })
  );
  await seed('users/u1/engagement_credit_events/post_reactions_post1', {
    source: 'post_reactions', credit: 1, ref_id: 'post1',
    created_at: new Date(), multiplier_applied: 1,
  });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/engagement_credit_events/post_reactions_post1')));
  await assertFails(getDoc(doc(db('u2'), 'users/u1/engagement_credit_events/post_reactions_post1')));
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/engagement_credit_events/post_reactions_post1'), { credit: 999999 })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/engagement_credit_events/post_reactions_post1')));
});

test('credit_restrictions/{uid}: owner reads, client (even the owner) CANNOT write', async () => {
  await seed('credit_restrictions/u1', { is_shadow_restricted: false, flag_count: 2 });
  await assertSucceeds(getDoc(doc(db('u1'), 'credit_restrictions/u1')));
  await assertFails(getDoc(doc(db('u2'), 'credit_restrictions/u1')));
  await assertFails(
    setDoc(doc(db('u1'), 'credit_restrictions/u1'), { flag_count: 0 }, { merge: true })
  );
});

test('shadow-restricted user CANNOT self-lift their own restriction', async () => {
  await seed('credit_restrictions/u1', { is_shadow_restricted: true, reason: 'duplicate_content' });
  await assertFails(
    updateDoc(doc(db('u1'), 'credit_restrictions/u1'), { is_shadow_restricted: false })
  );
});

test('credit_restrictions: admin CAN write (manual override)', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('credit_restrictions/u1', { is_shadow_restricted: false });
  await assertSucceeds(
    updateDoc(doc(db('admin1'), 'credit_restrictions/u1'), { is_shadow_restricted: true, reason: 'manual' })
  );
});

test('users/{uid}/credit_moderation: owner and admin CAN read; a stranger CANNOT; NO client can create/update/delete it directly', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('users/u1/credit_moderation/restrict1', {
    action: 'restrict', reason: 'duplicate_content', issued_by: 'system', created_at: new Date(),
  });
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/credit_moderation/restrict1')));
  await assertSucceeds(getDoc(doc(db('admin1'), 'users/u1/credit_moderation/restrict1')));
  await assertFails(getDoc(doc(db('u2'), 'users/u1/credit_moderation/restrict1')));
  // Regular client (even the affected owner) cannot self-write a restrict/lift entry.
  await assertFails(
    setDoc(doc(db('u1'), 'users/u1/credit_moderation/fake1'), {
      action: 'lift', reason: 'self-service', issued_by: 'u1', created_at: serverTimestamp(),
    })
  );
  await assertFails(
    updateDoc(doc(db('u1'), 'users/u1/credit_moderation/restrict1'), { reason: 'edited' })
  );
  await assertFails(deleteDoc(doc(db('u1'), 'users/u1/credit_moderation/restrict1')));
});

test('reciprocity_pairs: fully denied to any client, even a party to the pair', async () => {
  await seed('reciprocity_pairs/u1_u2', { uid_low: 'u1', uid_high: 'u2', low_to_high: 3, high_to_low: 1 });
  await assertFails(getDoc(doc(db('u1'), 'reciprocity_pairs/u1_u2')));
  await assertFails(
    setDoc(doc(db('u1'), 'reciprocity_pairs/u1_u2'), { low_to_high: 0 }, { merge: true })
  );
});

test('engagement_diversity: fully denied to any client, even the doc\'s own uid', async () => {
  await seed('engagement_diversity/u1', { recent_givers: ['u2', 'u3'] });
  await assertFails(getDoc(doc(db('u1'), 'engagement_diversity/u1')));
  await assertFails(
    setDoc(doc(db('u1'), 'engagement_diversity/u1'), { recent_givers: [] }, { merge: true })
  );
});

test('posts credit_progress: fully denied to any client, even the post\'s own author', async () => {
  await seed('posts/p1', { authorId: 'u1', author: { id: 'u1' }, content: 'hello' });
  await seed('posts/p1/credit_progress/reactions', { counted_uids: ['u2'], weighted_score: 1 });
  await assertFails(getDoc(doc(db('u1'), 'posts/p1/credit_progress/reactions')));
  await assertFails(
    setDoc(doc(db('u1'), 'posts/p1/credit_progress/reactions'), { weighted_score: 999 }, { merge: true })
  );
});

test('comment credit_progress: fully denied to any client, even the comment\'s own author', async () => {
  await seed('posts/p1', { authorId: 'u1', author: { id: 'u1' }, content: 'hello' });
  await seed('posts/p1/comments/c1', { authorId: 'u1', content: 'a comment' });
  await seed('posts/p1/comments/c1/credit_progress/likes', { counted_uids: ['u2'], weighted_score: 1 });
  await assertFails(getDoc(doc(db('u1'), 'posts/p1/comments/c1/credit_progress/likes')));
  await assertFails(
    setDoc(doc(db('u1'), 'posts/p1/comments/c1/credit_progress/likes'), { weighted_score: 999 }, { merge: true })
  );
});

test('community_groups weekly_contributions: fully denied to any client, even the group owner', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/weekly_contributions/2026-08-03/members/u2', { score: 5 });
  await assertFails(getDoc(doc(db('owner1'), 'community_groups/gr1/weekly_contributions/2026-08-03/members/u2')));
  await assertFails(
    setDoc(doc(db('owner1'), 'community_groups/gr1/weekly_contributions/2026-08-03/members/u2'), { score: 999 }, { merge: true })
  );
});

test('community_groups weekly_leaderboard: a group member CAN read the denormalized summary, a non-member CANNOT, and NOBODY can write it — not even the owner (Faz 5 §5.3)', async () => {
  await seed('community_groups/gr1', { owner_uid: 'owner1' });
  await seed('community_groups/gr1/members/owner1', { role: 'owner' });
  await seed('community_groups/gr1/members/u2', { role: 'member' });
  await seed('community_groups/gr1/weekly_leaderboard/2026-08-03', {
    entries: [{ uid: 'u2', display_name: 'B', photo_url: null, score: 12, rank: 1 }],
    updated_at: new Date(),
  });

  // A real member (u2, not the owner) CAN read it.
  await assertSucceeds(getDoc(doc(db('u2'), 'community_groups/gr1/weekly_leaderboard/2026-08-03')));
  // A non-member (u5 has no membership doc in gr1) CANNOT.
  await assertFails(getDoc(doc(db('u5'), 'community_groups/gr1/weekly_leaderboard/2026-08-03')));
  // Fully server-only to write — the owner is not exempt (mirrors
  // weekly_contributions above, which this doc denormalizes).
  await assertFails(
    setDoc(doc(db('owner1'), 'community_groups/gr1/weekly_leaderboard/2026-08-03'), {
      entries: [], updated_at: new Date(),
    }, { merge: true })
  );
});

// ─── Faz 5 §5.2: moderation_appeals extended for credit-restriction appeals ─
// Reuses the EXACT SAME collection/lifecycle/rate-limiter as the Faz 2 §2.6
// group-moderation appeal above — see firestore.rules' comment on this new
// branch for why the cross-check path differs (self-scoped uid, no group_id).

test('moderation_appeals: the real restricted user CAN appeal their own credit restriction', async () => {
  await seed('users/u2/credit_moderation/restrict1', {
    action: 'restrict', reason: 'duplicate_content', issued_by: 'system', created_at: new Date(),
  });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'moderation_appeals/restrict1'), {
      uid: 'u2', action: 'credit_restriction', group_id: '', group_name: '',
      message: 'this was a genuine post, not a repost', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

test('moderation_appeals: CANNOT fabricate a credit-restriction appeal against another account\'s entry', async () => {
  await seed('users/u2/credit_moderation/restrict1', {
    action: 'restrict', reason: 'duplicate_content', issued_by: 'system', created_at: new Date(),
  });
  // u3 references u2's real restrict entry id, but the credit_restriction
  // branch always looks up users/{request.auth.uid}/credit_moderation/{id} —
  // i.e. users/u3/credit_moderation/restrict1, which was never seeded.
  await assertFails(
    setDoc(doc(db('u3'), 'moderation_appeals/restrict1'), {
      uid: 'u3', action: 'credit_restriction', group_id: '', group_name: '',
      message: 'not actually mine', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

test('moderation_appeals: CANNOT appeal a credit-restriction entry that does not exist', async () => {
  await assertFails(
    setDoc(doc(db('u2'), 'moderation_appeals/doesNotExist'), {
      uid: 'u2', action: 'credit_restriction', group_id: '', group_name: '',
      message: 'no such restriction', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

test('moderation_appeals: CANNOT appeal an already-lifted credit restriction (nothing to appeal)', async () => {
  await seed('users/u2/credit_moderation/lifted1', {
    action: 'lift', reason: 'manual', issued_by: 'admin1', created_at: new Date(),
  });
  await assertFails(
    setDoc(doc(db('u2'), 'moderation_appeals/lifted1'), {
      uid: 'u2', action: 'credit_restriction', group_id: '', group_name: '',
      message: 'appealing a lift?', status: 'pending', created_at: serverTimestamp(),
    })
  );
});

test('unauthenticated access is denied', async () => {
  await seed('users/u1', { displayName: 'A' });
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/u1')));
});

// ─── app_config/* — Faz A §A2 audience split + §A5 write lockdown ───────────
//
// The KEY assertion across this whole section: even a real admin
// (admin_roles/{uid}.is_admin == true) cannot write app_config/* directly
// anymore — updateAppConfig/rollbackAppConfig (functions/app_config_admin.js,
// Admin SDK) are the only path in. That is what actually closes the gap the
// old `allow write: if isAdmin()` left open for ~120 settings including
// money and anti-abuse thresholds.

test('app_config/critical: anonymous CAN read (public — kill-switches/maintenance must work pre-login)', async () => {
  await seed('app_config/critical', { maintenance: { enabled: false } });
  const anon = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(anon, 'app_config/critical')));
});

test('app_config/critical: write is denied to everyone, including a real admin', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('admin1'), 'app_config/critical'), { maintenance: { enabled: true } })
  );
  await assertFails(
    setDoc(doc(db('u1'), 'app_config/critical'), { maintenance: { enabled: true } })
  );
});

test('app_config/client: anonymous CANNOT read (carries AI quota numbers)', async () => {
  await seed('app_config/client', { ai: { free_daily_limit: 2 } });
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'app_config/client')));
});

test('app_config/client: a plain authenticated (non-admin) user CAN read', async () => {
  await seed('app_config/client', { ai: { free_daily_limit: 2 } });
  await assertSucceeds(getDoc(doc(db('u1'), 'app_config/client')));
});

test('app_config/client: write is denied to everyone, including a real admin', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('admin1'), 'app_config/client'), { ai: { free_daily_limit: 999 } })
  );
});

test('app_config/server: a plain authenticated (non-admin) user CANNOT read (commission rates, XP table, anti-abuse thresholds — publishing these is a printed manual for evading every abuse defense)', async () => {
  await seed('app_config/server', { economy: { referral_commission_try: 5 } });
  await assertFails(getDoc(doc(db('u1'), 'app_config/server')));
});

test('app_config/server: a real admin CAN read', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('app_config/server', { economy: { referral_commission_try: 5 } });
  await assertSucceeds(getDoc(doc(db('admin1'), 'app_config/server')));
});

test('app_config/server: write is denied to everyone, including a real admin', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('admin1'), 'app_config/server'), { economy: { referral_commission_try: 999999 } })
  );
});

test('app_config/global (legacy): read stays public — unchanged production behavior', async () => {
  await seed('app_config/global', { ai: { text_model: 'openai/gpt-4o-mini' } });
  const anon = env.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(anon, 'app_config/global')));
});

test('app_config/global (legacy): write is now denied even to a real admin — THE behavior change from before this migration (old rule: allow write: if isAdmin())', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('admin1'), 'app_config/global'), { ai: { text_model: 'attacker-model' } })
  );
});

test('app_config: an unmatched/mistyped doc id is denied by default (no catch-all rule exists to accidentally permit it)', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'app_config/this_doc_id_does_not_exist')));
  await assertFails(getDoc(doc(db('admin1'), 'app_config/this_doc_id_does_not_exist')));
  await assertFails(
    setDoc(doc(db('admin1'), 'app_config/this_doc_id_does_not_exist'), { x: 1 })
  );
});

test('app_config: update() and delete() are equally denied, not just create/set, for a real admin', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('app_config/critical', { maintenance: { enabled: false } });
  await assertFails(
    updateDoc(doc(db('admin1'), 'app_config/critical'), { 'maintenance.enabled': true })
  );
  await assertFails(deleteDoc(doc(db('admin1'), 'app_config/critical')));
});

// ─── app_config_versions/{id} — Faz A §A6, immutable change history ────────

test('app_config_versions: a real admin CAN read', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await seed('app_config_versions/v1', { doc: 'critical', version: 1 });
  await assertSucceeds(getDoc(doc(db('admin1'), 'app_config_versions/v1')));
});

test('app_config_versions: a plain authenticated (non-admin) user CANNOT read (a diff can reveal server-only values mid-transition)', async () => {
  await seed('app_config_versions/v1', { doc: 'critical', version: 1 });
  await assertFails(getDoc(doc(db('u1'), 'app_config_versions/v1')));
});

test('app_config_versions: anonymous CANNOT read', async () => {
  await seed('app_config_versions/v1', { doc: 'critical', version: 1 });
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'app_config_versions/v1')));
});

test('app_config_versions: write is denied to everyone, including a real admin — only updateAppConfig/rollbackAppConfig (Admin SDK) ever write this', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('admin1'), 'app_config_versions/fake'), { doc: 'critical', version: 999 })
  );
});

test('app_config_versions: a forged/backdated version cannot be inserted by an admin to fake history', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(
    setDoc(doc(db('admin1'), 'app_config_versions/backdated'), {
      doc: 'critical', version: 1, actor_uid: 'admin1', created_at: new Date(2000, 0, 1),
    })
  );
});

// ─── admin_config — Faz A §A9, orphaned second config surface, removed ─────

test('admin_config: denied by default now that its rule is removed — even a real admin', async () => {
  await seed('admin_roles/admin1', { is_admin: true });
  await assertFails(getDoc(doc(db('admin1'), 'admin_config/global')));
  await assertFails(
    setDoc(doc(db('admin1'), 'admin_config/global'), { blocked_keywords: ['x'] })
  );
});
