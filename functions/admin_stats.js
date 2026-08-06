'use strict';

// ─────────────────────────────────────────────────────────────────────────────
// M5.1 (Faz B) — cross-domain daily rollup, generalizing index.js's
// recordUsage/ai_usage_stats pattern (on-write FieldValue.increment into a
// day_YYYY-MM-DD bucket + a running `global` doc) to the other 7 metric
// domains the admin panel wants: User, Subscription, Community, Gym,
// Coach, Moderation, System. AI itself stays entirely inside
// ai_usage_stats (see computeAiDayStats below) rather than being
// duplicated here — this module's `day_X.ai` sub-object is a straight
// COPY of that existing doc, not a re-derivation.
//
// Two different write mechanisms coexist on the SAME admin_stats/day_X
// doc, same as how ai_usage_stats/day_X already mixes on-write increments
// with nothing else recomputing it:
//   1. On-write increments, accumulated live throughout the day at their
//      own source (account.js's deleteUserAccount -> account_deletions;
//      rate_limit.js's lockUntil -> rate_limit_triggers) — those fields
//      are NOT touched by this module; it only ever writes with
//      { merge: true } so it never clobbers them.
//   2. This module's own SCHEDULED aggregation pass (computeAdminStatsRollup,
//      exported below), which runs once daily and fills in every OTHER
//      field by range-filtered .count()/.aggregate() queries against
//      collections that have no per-event write hook of their own.
//
// Explicitly OUT OF SCOPE for now (Faz B plan's M5.1, "Doğrulanmış açıklar"):
//  - MRR estimate / trial-conversion rate: no product PRICE is ever
//    captured server-side for a purchase (only product_id), and no trial
//    concept exists anywhere in purchase verification (validatePurchase
//    never distinguishes a trial period from a paid one). Faking either
//    number here would be worse than omitting the field.
//  - Function-error count: only in Cloud Logging, not Firestore — would
//    need a separate Cloud Logging client integration, a materially
//    different dependency than anything else in this file.
//  - "aktif salon" as a single stored flag: no such field exists on
//    `gyms`; defined here operationally as "≥1 checkin in the rollup
//    window" instead (see computeGymDayStats).
//  - Distinguishing a brand-new subscriber from a renewal: grantPremium
//    bumps the same `updated_at` for both (no first-grant marker exists),
//    so subscription day-stats report cancellations only, not "new".
// ─────────────────────────────────────────────────────────────────────────────

const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { yesterdayUtcRange, averageResolutionMinutes, reportRate } = require('./admin_stats_math');

function ts(date) {
  return admin.firestore.Timestamp.fromDate(date);
}

/** count() over `query` additionally range-filtered on `field` within [start, end). */
async function countInRange(query, field, start, end) {
  const snap = await query.where(field, '>=', ts(start)).where(field, '<', ts(end)).count().get();
  return snap.data().count || 0;
}

async function computeUserDayStats(db, start, end) {
  const [newSignups, activeUsers, onboardingCompleted, bans] = await Promise.all([
    countInRange(db.collection('users'), 'created_at', start, end),
    countInRange(db.collection('users'), 'last_active_at', start, end),
    countInRange(db.collection('users'), 'onboarding_completed_at', start, end),
    // admin/status/{uid}/flags can't be collection-group queried (each uid
    // gets its own uniquely-named subcollection) — admin_audit is the only
    // queryable record of a ban EVENT (vs. users.is_banned, a current-state
    // flag, not a day count). See M5.1 research: banUser/unbanUser both
    // call logAuditAction with this exact action string.
    countInRange(db.collection('admin_audit').where('action', '==', 'ban_user'), 'createdAt', start, end),
  ]);
  return { new_signups: newSignups, active_users: activeUsers, onboarding_completed: onboardingCompleted, bans };
}

/**
 * Copies (not re-derives) the day's totals straight from ai_usage_stats/day_X
 * — recordUsage already maintains that doc live, all day, on every AI
 * request (including the unpriced_count/quota_rejections fields added
 * alongside this rollup — see index.js). By the time this scheduled
 * function runs for a CLOSED previous day, that doc has stopped
 * accumulating (today's requests bump a new day_X key instead), so it's
 * safe to read as final.
 */
async function computeAiDayStats(db, dayKey) {
  const snap = await db.collection('ai_usage_stats').doc(`day_${dayKey}`).get();
  const d = snap.exists ? snap.data() || {} : {};
  return {
    requests: d.requests || 0,
    tokens: d.tokens || 0,
    cost_usd: d.cost_usd || 0,
    unpriced_count: d.unpriced_count || 0,
    quota_rejections: d.quota_rejections || 0,
  };
}

async function computeSubscriptionDayStats(db, start, end) {
  const cancelled = await countInRange(db.collection('entitlements'), 'revoked_at', start, end);
  return { cancelled };
}

async function computeCommunityDayStats(db, start, end) {
  const [posts, comments, messages, groupsCreated, reportsFiled] = await Promise.all([
    countInRange(db.collection('posts'), 'timestamp', start, end),
    countInRange(db.collectionGroup('comments'), 'timestamp', start, end),
    countInRange(db.collectionGroup('messages'), 'server_timestamp', start, end),
    countInRange(db.collection('community_groups'), 'created_at', start, end),
    countInRange(db.collection('reports'), 'timestamp', start, end),
  ]);
  const contentVolume = posts + comments + messages;
  return {
    posts,
    comments,
    messages,
    groups_created: groupsCreated,
    reports_filed: reportsFiled,
    report_rate: reportRate(reportsFiled, contentVolume),
  };
}

async function computeGymDayStats(db, start, end) {
  const [checkinsSnap, presenceSessions, commissionsAgg] = await Promise.all([
    // Needs the actual docs (not just a count) to derive active_gyms below
    // from each checkin's parent gym id — no stored "active gym" flag
    // exists to count directly instead (see module header).
    db.collectionGroup('checkins').where('timestamp', '>=', ts(start)).where('timestamp', '<', ts(end)).get(),
    // entered_at (not exited_at): reuses this collection's existing
    // [uid, entered_at] / [entered_at] indexes and defines "presence
    // session" by when it STARTED, consistent with how every other day
    // metric here is keyed off a creation timestamp.
    countInRange(db.collectionGroup('presence_sessions'), 'entered_at', start, end),
    db
      .collectionGroup('commissions')
      .where('created_at', '>=', ts(start))
      .where('created_at', '<', ts(end))
      .aggregate({
        count: admin.firestore.AggregateField.count(),
        total_amount: admin.firestore.AggregateField.sum('amount'),
      })
      .get(),
  ]);

  const activeGymIds = new Set(checkinsSnap.docs.map((d) => d.ref.parent.parent && d.ref.parent.parent.id).filter(Boolean));
  const agg = commissionsAgg.data();

  return {
    checkins: checkinsSnap.size,
    active_gyms: activeGymIds.size,
    presence_sessions: presenceSessions,
    commissions_count: agg.count || 0,
    commissions_total: agg.total_amount || 0,
  };
}

async function computeCoachDayStats(db, start, end) {
  const [applications, programEnrollments, planOffers] = await Promise.all([
    countInRange(db.collection('coach_applications'), 'submittedAt', start, end),
    countInRange(db.collectionGroup('program_enrollments'), 'enrolled_at', start, end),
    countInRange(db.collectionGroup('plan_offers'), 'created_at', start, end),
  ]);
  return { applications, program_enrollments: programEnrollments, plan_offers: planOffers };
}

async function computeModerationDayStats(db, start, end) {
  const [resolvedReportsSnap, resolvedAppealsSnap] = await Promise.all([
    db.collection('reports').where('reviewedAt', '>=', ts(start)).where('reviewedAt', '<', ts(end)).get(),
    db.collection('moderation_appeals').where('resolved_at', '>=', ts(start)).where('resolved_at', '<', ts(end)).get(),
  ]);

  const resolutionPairs = [
    ...resolvedReportsSnap.docs.map((doc) => {
      const d = doc.data();
      return {
        createdAt: d.timestamp && d.timestamp.toDate ? d.timestamp.toDate() : null,
        resolvedAt: d.reviewedAt && d.reviewedAt.toDate ? d.reviewedAt.toDate() : null,
      };
    }),
    ...resolvedAppealsSnap.docs.map((doc) => {
      const d = doc.data();
      return {
        createdAt: d.created_at && d.created_at.toDate ? d.created_at.toDate() : null,
        resolvedAt: d.resolved_at && d.resolved_at.toDate ? d.resolved_at.toDate() : null,
      };
    }),
  ];

  // rate_limit_triggers itself lives directly on this same admin_stats/day_X
  // doc already, via lockUntil's own on-write increment (rate_limit.js) —
  // nothing to add for it here, the scheduled write below merges around it.
  return {
    reports_resolved: resolvedReportsSnap.size,
    appeals_resolved: resolvedAppealsSnap.size,
    avg_resolution_minutes: averageResolutionMinutes(resolutionPairs),
  };
}

async function computeSystemDayStats(db, start, end) {
  const configChanges = await countInRange(db.collection('app_config_versions'), 'created_at', start, end);
  return { config_changes: configChanges };
}

/**
 * Current-state gauges — recomputed fresh every run (plain values, NOT
 * FieldValue.increment; there is nothing to accumulate, each is "as of
 * this rollup"). Covers exactly the queue counters M5.3's dashboard plan
 * calls for (bekleyen rapor/başvuru/DSAR/itiraz) plus a few natural
 * current totals.
 */
async function computeGlobalSnapshot(db) {
  const [
    totalUsers,
    activePremium,
    activeCoaches,
    totalGyms,
    pendingReports,
    pendingAppeals,
    pendingPrivacyRequests,
    pendingCoachApplications,
    pendingGymApplications,
  ] = await Promise.all([
    db.collection('users').count().get().then((s) => s.data().count || 0),
    db.collection('entitlements').where('tier', '==', 'premium').count().get().then((s) => s.data().count || 0),
    db
      .collection('coach_profiles')
      .where('is_public', '==', true)
      .where('is_accepting_clients', '==', true)
      .count()
      .get()
      .then((s) => s.data().count || 0),
    db.collection('gyms').count().get().then((s) => s.data().count || 0),
    db.collection('reports').where('status', '==', 'pending').count().get().then((s) => s.data().count || 0),
    db.collection('moderation_appeals').where('status', '==', 'pending').count().get().then((s) => s.data().count || 0),
    db.collection('privacy_requests').where('status', '==', 'pending').count().get().then((s) => s.data().count || 0),
    db.collection('coach_applications').where('status', '==', 'pending').count().get().then((s) => s.data().count || 0),
    db.collection('gym_applications').where('status', '==', 'pending').count().get().then((s) => s.data().count || 0),
  ]);

  return {
    total_users: totalUsers,
    active_premium: activePremium,
    active_coaches: activeCoaches,
    total_gyms: totalGyms,
    pending_reports: pendingReports,
    pending_appeals: pendingAppeals,
    pending_privacy_requests: pendingPrivacyRequests,
    pending_coach_applications: pendingCoachApplications,
    pending_gym_applications: pendingGymApplications,
  };
}

/**
 * The actual rollup logic, separated from the .schedule().onRun() wrapper
 * below so it can be invoked directly (no Pub/Sub trigger, no Functions
 * emulator) against the Firestore emulator for verification — same reason
 * summaries.js exports a plain factory instead of only a bound trigger.
 */
async function runAdminStatsRollup(now = new Date()) {
  const db = admin.firestore();
  const { start, end, dayKey } = yesterdayUtcRange(now);

  const [userStats, aiStats, subscriptionStats, communityStats, gymStats, coachStats, moderationStats, systemStats, globalSnapshot] =
    await Promise.all([
      computeUserDayStats(db, start, end),
      computeAiDayStats(db, dayKey),
      computeSubscriptionDayStats(db, start, end),
      computeCommunityDayStats(db, start, end),
      computeGymDayStats(db, start, end),
      computeCoachDayStats(db, start, end),
      computeModerationDayStats(db, start, end),
      computeSystemDayStats(db, start, end),
      computeGlobalSnapshot(db),
    ]);

  const nowTs = admin.firestore.FieldValue.serverTimestamp();
  await Promise.all([
    db
      .collection('admin_stats')
      .doc(`day_${dayKey}`)
      .set(
        {
          day: dayKey,
          users: userStats,
          ai: aiStats,
          subscription: subscriptionStats,
          community: communityStats,
          gym: gymStats,
          coach: coachStats,
          moderation: moderationStats,
          system: systemStats,
          updated_at: nowTs,
        },
        { merge: true } // never clobber account_deletions/rate_limit_triggers, accumulated on-write throughout the day
      ),
    db.collection('admin_stats').doc('global').set({ ...globalSnapshot, updated_at: nowTs }, { merge: true }),
  ]);

  functions.logger.info('computeAdminStatsRollup: done', { dayKey });
  return { dayKey };
}

// Once daily, 02:00 UTC — after every timezone's "yesterday" is fully
// closed. Matches this codebase's own convention for wall-clock schedules
// (functions.pubsub.schedule + .timeZone('UTC'), e.g. index.js's
// streakAtRiskNotifier/weeklyPlanReadyNotifier) rather than an interval.
exports.computeAdminStatsRollup = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    try {
      await runAdminStatsRollup();
    } catch (e) {
      functions.logger.error('computeAdminStatsRollup failed', { error: e.message });
      throw e; // no custom retry config anywhere else in this codebase's schedules — match that, don't add one here either.
    }
  });

// Exposed for direct invocation in tests/manual verification — never
// imported by index.js (only the schedule export above is).
exports._internal = { runAdminStatsRollup };
