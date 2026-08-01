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
import { doc, getDoc, setDoc, updateDoc, deleteDoc } from 'firebase/firestore';

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
  // admin_roles/admin_audit/admin_config do), so this exercises the implicit
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
  await seed('admin_roles/u1', { is_admin: true });
  await seed('admin_audit/a1', { action: 'test', admin_uid: 'u1' });
  await seed('ai_usage_logs/l1', { uid: 'u2', cost: 1 });
  await seed('admin_config/global', { maintenance_mode: false });

  await assertSucceeds(getDoc(doc(db('u1'), 'admin_audit/a1')));
  await assertSucceeds(getDoc(doc(db('u1'), 'ai_usage_logs/l1')));
  await assertSucceeds(getDoc(doc(db('u1'), 'admin_config/global')));

  await assertFails(getDoc(doc(db('u2'), 'admin_audit/a1')));
  await assertFails(getDoc(doc(db('u2'), 'ai_usage_logs/l1')));
  await assertFails(getDoc(doc(db('u2'), 'admin_config/global')));
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

test('unauthenticated access is denied', async () => {
  await seed('users/u1', { displayName: 'A' });
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/u1')));
});
