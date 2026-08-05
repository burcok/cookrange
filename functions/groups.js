'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// Faz 2 §2.3 — unified groups, server-side surface.
//
// Only `redeemGroupInvite` is built here (invite-code redemption — the one
// piece of §2.3 that genuinely needs server validation: it grants group
// membership, which firestore.rules alone can't gate on a code the client
// supplies, since the code lives in a fully-closed `group_invites/{code}`
// doc — see that collection's rules comment in firestore.rules). Activity
// score computation and automated moderation (the plan's other listed
// residents of this file) are Faz 2 §2.5/§2.6 — out of scope here and
// deliberately not stubbed.
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { APP_CHECK_ENFORCE } = require('./config');
const { assertCallable } = require('./notifications');

exports.redeemGroupInvite = functions.https.onCall(async (data, context) => {
  const uid = context.auth && context.auth.uid;
  if (!uid) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }
  if (context.app === undefined && APP_CHECK_ENFORCE) {
    throw new functions.https.HttpsError('failed-precondition', 'App Check required');
  }

  const code = (data && data.code ? String(data.code) : '').trim().toUpperCase();
  if (code.length < 4) {
    throw new functions.https.HttpsError('invalid-argument', 'invalid_code');
  }

  const db = admin.firestore();
  const inviteRef = db.collection('group_invites').doc(code);

  // Validate + claim atomically — mirrors applyReferral's shape
  // (functions/economy.js): domain errors are returned from inside the
  // transaction (never thrown there, so Firestore doesn't retry a
  // business-logic rejection as if it were a contention conflict), then
  // raised as HttpsError once the transaction has resolved.
  const result = await db.runTransaction(async (tx) => {
    const inviteSnap = await tx.get(inviteRef);
    if (!inviteSnap.exists) return { error: 'code_not_found' };
    const invite = inviteSnap.data();
    if (invite.is_active === false) return { error: 'code_inactive' };

    const groupId = invite.group_id;
    const groupRef = db.collection('community_groups').doc(groupId);
    const groupSnap = await tx.get(groupRef);
    if (!groupSnap.exists) return { error: 'group_not_found' };
    const group = groupSnap.data();
    if (group.invite_enabled !== true) return { error: 'invite_disabled' };

    const memberRef = groupRef.collection('members').doc(uid);
    const memberSnap = await tx.get(memberRef);
    if (memberSnap.exists) {
      const member = memberSnap.data();
      if (member.banned === true) return { error: 'banned' };
      return { error: 'already_member', groupId };
    }

    tx.set(memberRef, {
      role: 'member',
      joined_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(groupRef, {
      member_count: admin.firestore.FieldValue.increment(1),
      last_activity_at: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(
      db.collection('users').doc(uid),
      { group_memberships: admin.firestore.FieldValue.arrayUnion(groupId) },
      { merge: true }
    );

    return { groupId, groupName: group.name || '' };
  });

  if (result.error) {
    throw new functions.https.HttpsError('failed-precondition', result.error);
  }

  functions.logger.info('redeemGroupInvite: ok', { uid, groupId: result.groupId });
  return { ok: true, groupId: result.groupId, groupName: result.groupName };
});

// ─────────────────────────────────────────────────────────────────────────────
// Faz 2 §2.5 — "Günün en aktif grupları" (most active groups today).
//
// activity_score = (messages in the last 24h × 1) + (posts × 3) +
// (comments × 2) + (new members × 5), TIME-DECAYED — never client-computed
// (firestore.rules' touchesProtectedGroupFields() closes the client-write
// path; CommunityGroupModel.activityScore's doc comment is the client-side
// half of the same statement). Runs every 15 minutes.
//
// Decay formula — the plan specifies "zaman sönümlü" (time-decayed) but not
// the curve, so this is the explicit, documented choice made here: each
// event's weight = 0.5 ^ (age_hours / HALF_LIFE_HOURS), HALF_LIFE_HOURS = 6.
// A brand-new event counts fully (weight 1); by 6h old it's worth half; by
// the 24h fetch boundary it's worth 0.5^4 ≈ 6%. This is a smooth taper
// rather than the hard cliff a flat count-within-window would produce (a
// message posted 23h59m ago would count identically to one posted a minute
// ago, then fall off a cliff the instant the next 15-min run crosses the
// 24h mark) — simple to explain, cheap to compute (one Math.pow per event),
// and needs no extra field on any doc since it's derived purely from each
// event's own existing timestamp at read time.
// ─────────────────────────────────────────────────────────────────────────────

const ACTIVITY_WINDOW_HOURS = 24;
const ACTIVITY_HALF_LIFE_HOURS = 6;
// MVP cap on groups scored per run — mirrors closeStalePresenceSessions'
// STALE_SWEEP_LIMIT / streakAtRiskNotifier's 500-user cap. Only `is_public`
// groups are scored at all (gym/private groups default is_public: false —
// CommunityGroupService.createGroup — and are reached from their own
// screen, never this discovery carousel), so this is a cap on PUBLIC groups
// specifically, not every group in the app.
const ACTIVITY_GROUPS_PER_RUN = 200;
// Per-group, per-signal scan cap (messages/posts/new-members each) — a
// single group having more than this many of one signal in 24h is not a
// realistic case to optimize for at this stage.
const ACTIVITY_SIGNAL_LIMIT = 300;
// One global query, shared across every group scored this run (see the
// comments-resolution comment below for why comments can't be queried
// per-group the same cheap way messages/posts/members are).
const ACTIVITY_COMMENTS_SCAN_LIMIT = 500;

function activityDecayWeight(eventDate, nowMs) {
  const ageHours = (nowMs - eventDate.getTime()) / (1000 * 60 * 60);
  if (ageHours <= 0) return 1; // clock skew guard — never weight > 1
  return Math.pow(0.5, ageHours / ACTIVITY_HALF_LIFE_HOURS);
}

exports.computeGroupActivityScores = functions
  .pubsub
  .schedule('every 15 minutes')
  .onRun(async (_context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
    const cutoff = admin.firestore.Timestamp.fromMillis(
      nowMs - ACTIVITY_WINDOW_HOURS * 60 * 60 * 1000
    );

    const groupsSnap = await db.collection('community_groups')
      .where('is_public', '==', true)
      .limit(ACTIVITY_GROUPS_PER_RUN)
      .get();

    if (groupsSnap.empty) {
      functions.logger.info('computeGroupActivityScores: no public groups');
      return;
    }

    // ── Comments: resolved ONCE, globally, not per-group ──────────────────
    // Comments live at posts/{postId}/comments/{commentId} with no
    // denormalized groupId on the comment doc itself (community_post.dart's
    // CommunityComment.toMap carries no such field). A per-group query
    // would require first enumerating EVERY post the group has ever had
    // (a comment can land on an old post, not just a recent one) then
    // querying each post's comments subcollection — an unbounded N+1 this
    // codebase's optimization rule (R1) rules out. Instead: one
    // collectionGroup('comments') query for anything recent (a single
    // inequality filter, auto-indexed even at collection-group scope — no
    // composite needed, same reasoning docs/DATABASE.md §5 already
    // documents for the messages stream), then resolve each comment's
    // parent post -> groupId, deduplicated by post id so a busy post's 50
    // comments cost one lookup, not 50.
    const commentsSnap = await db.collectionGroup('comments')
      .where('timestamp', '>=', cutoff)
      .limit(ACTIVITY_COMMENTS_SCAN_LIMIT)
      .get();

    const commentTimestampsByPostId = new Map();
    for (const c of commentsSnap.docs) {
      const postRef = c.ref.parent.parent;
      if (!postRef) continue;
      const list = commentTimestampsByPostId.get(postRef.id) || [];
      list.push(c.data().timestamp);
      commentTimestampsByPostId.set(postRef.id, list);
    }
    const uniquePostIds = [...commentTimestampsByPostId.keys()];
    const postIdToGroupId = new Map();
    for (let i = 0; i < uniquePostIds.length; i += 300) {
      const chunk = uniquePostIds.slice(i, i + 300);
      const refs = chunk.map((id) => db.collection('posts').doc(id));
      if (refs.length === 0) continue;
      const snaps = await db.getAll(...refs);
      for (const s of snaps) {
        if (s.exists && s.data().groupId) postIdToGroupId.set(s.id, s.data().groupId);
      }
    }
    // Fold resolved comment timestamps into a per-group weighted sum once,
    // rather than re-deriving this inside the per-group loop below.
    const commentScoreByGroupId = new Map();
    for (const [postId, timestamps] of commentTimestampsByPostId.entries()) {
      const groupId = postIdToGroupId.get(postId);
      if (!groupId) continue; // comment on a post outside any group — irrelevant here
      let sum = commentScoreByGroupId.get(groupId) || 0;
      for (const ts of timestamps) sum += 2 * activityDecayWeight(ts.toDate(), nowMs);
      commentScoreByGroupId.set(groupId, sum);
    }

    // ── Per-group: messages, posts, new members ───────────────────────────
    let batch = db.batch();
    let batchCount = 0;
    let scored = 0;

    for (const groupDoc of groupsSnap.docs) {
      const groupId = groupDoc.id;
      const group = groupDoc.data();
      const chatId = group.chat_id || groupId; // chat_id always == group id (CommunityGroupModel)

      try {
        const [messagesSnap, postsSnap, newMembersSnap] = await Promise.all([
          db.collection('chats').doc(chatId).collection('messages')
            .where('server_timestamp', '>=', cutoff)
            .limit(ACTIVITY_SIGNAL_LIMIT)
            .get(),
          db.collection('posts')
            .where('groupId', '==', groupId)
            .where('timestamp', '>=', cutoff)
            .limit(ACTIVITY_SIGNAL_LIMIT)
            .get(),
          groupDoc.ref.collection('members')
            .where('joined_at', '>=', cutoff)
            .limit(ACTIVITY_SIGNAL_LIMIT)
            .get(),
        ]);

        let score = commentScoreByGroupId.get(groupId) || 0;
        for (const m of messagesSnap.docs) {
          const ts = m.data().server_timestamp;
          if (ts) score += 1 * activityDecayWeight(ts.toDate(), nowMs);
        }
        for (const p of postsSnap.docs) {
          const ts = p.data().timestamp;
          if (ts) score += 3 * activityDecayWeight(ts.toDate(), nowMs);
        }
        for (const mem of newMembersSnap.docs) {
          const ts = mem.data().joined_at;
          if (ts) score += 5 * activityDecayWeight(ts.toDate(), nowMs);
        }

        batch.update(groupDoc.ref, {
          activity_score: score,
          activity_updated_at: now,
        });
        batchCount++;
        scored++;

        // Firestore batches cap at 500 writes — flush defensively well
        // under that. ACTIVITY_GROUPS_PER_RUN (200) never actually reaches
        // this today; the check just keeps this safe if that cap changes
        // without this loop being revisited.
        if (batchCount >= 400) {
          await batch.commit();
          batch = db.batch();
          batchCount = 0;
        }
      } catch (e) {
        functions.logger.error('computeGroupActivityScores: failed for one group', {
          groupId, error: e.message,
        });
      }
    }

    if (batchCount > 0) await batch.commit();

    functions.logger.info('computeGroupActivityScores: done', {
      groupsScanned: groupsSnap.size, scored,
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// Faz 2 §2.5 cold-start — a handful of official groups per major Turkish
// city, so the discovery carousels aren't empty before any organic public
// group exists. Admin-only (custom claim — mirrors sendAdminNotification's
// check in functions/notifications.js exactly), idempotent (deterministic
// doc ids, skips any that already exist), and owned by the CALLING ADMIN's
// own uid — there is no synthetic "system" account anywhere in this schema
// (owner_uid is read elsewhere as a real user profile reference), so one
// can't be fabricated here either. This mirrors the same manual,
// console-side bootstrapping this codebase already requires for the very
// first admin_roles/{uid} doc (see firestore.rules' isAdmin() comment).
//
// Not wired to any client UI in this pass — invoke once via the Firebase
// console's "Test function" panel or an authenticated HTTPS call, signed in
// as an admin account. See docs/SERVICES.md for the exact note.
// ─────────────────────────────────────────────────────────────────────────────

// Character-for-character copies of the relevant lib/core/data/
// turkish_locations.dart province keys. Cloud Functions (Node) can't import
// a Dart file, so "reuse TurkishLocations for the city list" means keeping
// these spellings in lockstep by hand, not a shared module — update both
// lists together if a spelling ever changes. Chosen as (subjectively) the
// 15 largest Turkish cities/metro areas — "major", not all 81 provinces.
const OFFICIAL_SEED_CITIES = [
  'İstanbul', 'Ankara', 'İzmir', 'Bursa', 'Antalya', 'Adana', 'Konya',
  'Şanlıurfa', 'Gaziantep', 'Kocaeli', 'Mersin', 'Diyarbakır', 'Kayseri',
  'Eskişehir', 'Samsun',
];

// ASCII slug for a deterministic doc id — community_groups ids are
// auto-generated everywhere else; these are the one deliberate exception,
// precisely so re-running this function is a no-op, not a duplicate.
function slugifyCityName(city) {
  return city
    .toLowerCase()
    .replace(/İ/g, 'i').replace(/ı/g, 'i').replace(/ş/g, 's')
    .replace(/ğ/g, 'g').replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ç/g, 'c')
    .replace(/[^a-z0-9]+/g, '_');
}

// Two per city — literally a "handful" per the plan's own wording; kept
// small and explicit rather than guessing at a larger "right" number.
const OFFICIAL_GROUP_TEMPLATES = [
  {
    suffix: 'general',
    name: (city) => `${city} Cookrange Topluluğu`,
    description: (city) => `${city}'de Cookrange kullanan herkes için resmi topluluk grubu.`,
  },
  {
    suffix: 'nutrition',
    name: (city) => `${city} Sağlıklı Yaşam`,
    description: (city) => `${city}'de sağlıklı beslenme ve fitness hedeflerini paylaşanlar için.`,
  },
];

exports.seedOfficialGroups = functions.https.onCall(async (data, context) => {
  const adminUid = assertCallable(context);
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError('permission-denied', 'admin_required');
  }

  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();
  let created = 0;
  let skipped = 0;

  for (const city of OFFICIAL_SEED_CITIES) {
    const citySlug = slugifyCityName(city);
    for (const tpl of OFFICIAL_GROUP_TEMPLATES) {
      const groupId = `official_${citySlug}_${tpl.suffix}`;
      const groupRef = db.collection('community_groups').doc(groupId);
      const existing = await groupRef.get();
      if (existing.exists) {
        skipped++;
        continue;
      }

      const batch = db.batch();
      batch.set(groupRef, {
        name: tpl.name(city),
        description: tpl.description(city),
        city,
        owner_uid: adminUid,
        member_count: 1,
        is_public: true,
        tags: ['official'],
        created_at: now,
        updated_at: now,
        last_activity_at: now,
        chat_id: groupId,
        kind: 'public',
        announcement_only: false,
        invite_enabled: false,
        join_policy: 'open',
        activity_score: 0,
      });
      batch.set(db.collection('chats').doc(groupId), {
        participants: [adminUid],
        unreadCounts: { [adminUid]: 0 },
        type: 'group',
        updatedAt: now,
        name: tpl.name(city),
        groupId,
      });
      batch.set(groupRef.collection('members').doc(adminUid), {
        role: 'owner',
        joined_at: now,
      });
      batch.set(
        db.collection('users').doc(adminUid),
        { group_memberships: admin.firestore.FieldValue.arrayUnion(groupId) },
        { merge: true }
      );
      await batch.commit();
      created++;
    }
  }

  functions.logger.info('seedOfficialGroups: done', { created, skipped, adminUid });
  return { created, skipped };
});
