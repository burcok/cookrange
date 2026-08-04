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
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp,
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

test('gym checkins: create requires a server timestamp and a real method (S13 restated)', async () => {
  await seed('gyms/g1', { owner_uid: 'owner1' });
  await assertSucceeds(
    setDoc(doc(db('u2'), 'gyms/g1/checkins/c1'), {
      uid: 'u2', timestamp: serverTimestamp(), method: 'qr',
    })
  );
  // Client-supplied clock value instead of the server sentinel — rejected.
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/checkins/c2'), {
      uid: 'u2', timestamp: new Date(), method: 'qr',
    })
  );
  // Method outside the allowlist — rejected.
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/checkins/c3'), {
      uid: 'u2', timestamp: serverTimestamp(), method: 'geofence',
    })
  );
  // Forging another user's uid — rejected.
  await assertFails(
    setDoc(doc(db('u2'), 'gyms/g1/checkins/c4'), {
      uid: 'someone-else', timestamp: serverTimestamp(), method: 'qr',
    })
  );
  await assertFails(
    updateDoc(doc(db('u2'), 'gyms/g1/checkins/c1'), { method: 'gps' })
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

test('unauthenticated access is denied', async () => {
  await seed('users/u1', { displayName: 'A' });
  const anon = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(anon, 'users/u1')));
});
