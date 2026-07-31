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
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

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

// ─── Privacy ─────────────────────────────────────────────────────────────────

test('private nutrition PII: only the owner can read', async () => {
  await seed('users/u1/private/nutrition', { weight: 80, allergies: 'nuts' });
  await assertFails(getDoc(doc(db('u2'), 'users/u1/private/nutrition')));
  await assertSucceeds(getDoc(doc(db('u1'), 'users/u1/private/nutrition')));
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

test('admin/status: a user CANNOT self-grant admin', async () => {
  await assertFails(
    setDoc(doc(db('u1'), 'admin/status/u1'), { is_admin: true })
  );
});

test('unauthenticated access is denied', async () => {
  await seed('users/u1', { displayName: 'A' });
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/u1')));
});
