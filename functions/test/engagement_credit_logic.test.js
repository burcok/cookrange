'use strict';

// Faz 5 §5.2 — unit tests for the pure, Firebase-independent anti-abuse
// logic (`engagement_credit_logic.js`). No emulator, no firebase-admin —
// this file is required directly and asserted against with Node's built-in
// test runner:
//
//   node --test functions/test/engagement_credit_logic.test.js
//
// This is the part of Faz 5 §5.2 the plan calls out as "most likely to
// need future tuning" (reciprocity-ring/duplicate-content detection) — so
// it's the part tested most thoroughly, per this session's established bar.

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const logic = require('../engagement_credit_logic');

describe('content-quality gate', () => {
  test('post: short text with no image is NOT eligible', () => {
    assert.equal(logic.isPostEligibleContent({ content: 'too short', imageCount: 0 }), false);
  });

  test('post: text at/over the minimum length IS eligible', () => {
    assert.equal(
      logic.isPostEligibleContent({ content: 'x'.repeat(20), imageCount: 0 }),
      true,
    );
  });

  test('post: an image makes even a tiny caption eligible', () => {
    assert.equal(logic.isPostEligibleContent({ content: 'hi', imageCount: 1 }), true);
  });

  test('post: empty content, no image → not eligible', () => {
    assert.equal(logic.isPostEligibleContent({ content: '', imageCount: 0 }), false);
  });

  test('comment: below minimum length is not eligible', () => {
    assert.equal(logic.isCommentEligibleContent({ content: 'hey' }), false);
  });

  test('comment: at minimum length is eligible', () => {
    assert.equal(logic.isCommentEligibleContent({ content: '1234567890' }), true);
  });

  test('message: attachment alone is enough regardless of body', () => {
    assert.equal(
      logic.isMessageEligibleContent({ body: '', attachmentCount: 1 }),
      true,
    );
  });

  test('message: no attachment falls back to text length', () => {
    assert.equal(
      logic.isMessageEligibleContent({ body: 'short', attachmentCount: 0 }),
      false,
    );
  });
});

describe('duplicate-content detection', () => {
  test('exact repost (after normalization) is a duplicate', () => {
    const recent = ['Bugün harika bir kahvaltı yaptım, çok lezzetliydi!'];
    assert.equal(
      logic.isNearDuplicateText('Bugün harika bir kahvaltı yaptım, çok lezzetliydi!', recent),
      true,
    );
  });

  test('same text with different punctuation/case is still a duplicate', () => {
    // Plain ASCII on purpose — avoids Turkish dotted/dotless-I case-folding
    // ambiguity entirely; this test is about punctuation/case normalization,
    // not locale-specific casing.
    const recent = ['I made a great breakfast today, it was so delicious!'];
    assert.equal(
      logic.isNearDuplicateText('i MADE a great BREAKFAST today it was so delicious', recent),
      true,
    );
  });

  test('near-identical text with one word swapped (15/16 words shared) is a duplicate', () => {
    // 16 distinct words, differing in exactly the last one:
    // intersection=15, union=17, Jaccard=15/17≈0.882 >= 0.85 threshold.
    const recent = ['bu tarif gerçekten harika oldu bugün akşam yemeğinde denedim çok lezzetliydi herkese tavsiye ederim kesinlikle deneyin'];
    const candidate = 'bu tarif gerçekten harika oldu bugün akşam yemeğinde denedim çok lezzetliydi herkese tavsiye ederim kesinlikle öneririm';
    assert.equal(logic.isNearDuplicateText(candidate, recent), true);
  });

  test('similar-but-more-different text (below the 0.85 bar) is NOT a duplicate', () => {
    // Same 16-word base, but 5 of the 16 words differ:
    // intersection=11, union=21, Jaccard=11/21≈0.524 < 0.85.
    const recent = ['bu tarif gerçekten harika oldu bugün akşam yemeğinde denedim çok lezzetliydi herkese tavsiye ederim kesinlikle deneyin'];
    const candidate = 'bu tarif gerçekten güzel oldu dün öğlen yemeğinde denedim epey lezzetliydi herkese tavsiye ederim kesinlikle öneririm';
    assert.equal(logic.isNearDuplicateText(candidate, recent), false);
  });

  test('genuinely different content is NOT flagged as duplicate', () => {
    const recent = ['Bugün harika bir kahvaltı yaptım, çok lezzetliydi!'];
    assert.equal(
      logic.isNearDuplicateText('Yeni tarif denedim, tavuklu sebzeli bir yemek pişirdim akşam için.', recent),
      false,
    );
  });

  test('empty candidate text is never a duplicate (nothing to compare)', () => {
    assert.equal(logic.isNearDuplicateText('   ', ['anything here']), false);
  });

  test('empty recent-texts list never flags a duplicate', () => {
    assert.equal(logic.isNearDuplicateText('some real content here', []), false);
  });

  test('jaccardSimilarity of two empty sets is 0, not NaN', () => {
    assert.equal(logic.jaccardSimilarity(new Set(), new Set()), 0);
  });

  test('jaccardSimilarity of identical sets is 1', () => {
    const s = new Set(['a', 'b', 'c']);
    assert.equal(logic.jaccardSimilarity(s, new Set(s)), 1);
  });
});

describe('reciprocity-ring weighting', () => {
  test('brand-new pair (no history) counts at full weight', () => {
    assert.equal(logic.reciprocityWeight(0, 0), 1);
  });

  test('small sample below MIN_PAIR_SAMPLE counts at full weight even if lopsided', () => {
    // total = 3, below the MIN_PAIR_SAMPLE=4 floor — too little data to judge.
    assert.equal(logic.reciprocityWeight(2, 1), 1);
  });

  test('large, perfectly balanced back-and-forth is down-weighted', () => {
    assert.equal(logic.reciprocityWeight(10, 10), logic.RECIPROCITY_DOWNWEIGHT);
  });

  test('large, one-sided history (never reciprocated) is NOT down-weighted', () => {
    // 20 given one way, 1 given back — ratio 1/20 = 0.05, well under threshold.
    assert.equal(logic.reciprocityWeight(20, 1), 1);
  });

  test('ratio exactly at the threshold is down-weighted (boundary is inclusive)', () => {
    // 8 and 4: total=12 (>=4), ratio = 4/8 = 0.5 == RECIPROCITY_RATIO_THRESHOLD.
    assert.equal(logic.reciprocityWeight(8, 4), logic.RECIPROCITY_DOWNWEIGHT);
  });

  test('ratio just under the threshold is NOT down-weighted', () => {
    // 9 and 4: ratio = 4/9 ≈ 0.444 < 0.5.
    assert.equal(logic.reciprocityWeight(9, 4), 1);
  });

  test('negative/garbage inputs are clamped to zero, never throw', () => {
    assert.equal(logic.reciprocityWeight(-5, -5), 1);
    assert.equal(logic.reciprocityWeight(NaN, NaN), 1);
  });
});

describe('closed-cluster (concentration) weighting', () => {
  test('window smaller than CONCENTRATION_WINDOW is never judged', () => {
    const window = Array.from({ length: 5 }, (_, i) => `uid${i}`);
    assert.equal(logic.concentrationWeight(window, 'uid0'), 1);
  });

  test('full window with healthy diversity (>3 distinct) is not down-weighted', () => {
    // 20 slots, 10 distinct uids repeating — diversity is fine.
    const window = Array.from({ length: 20 }, (_, i) => `uid${i % 10}`);
    assert.equal(logic.concentrationWeight(window, 'uid0'), 1);
  });

  test('full window dominated by <=3 distinct uids IS down-weighted for one of them', () => {
    const window = Array.from({ length: 20 }, (_, i) => `uid${i % 3}`);
    assert.equal(logic.concentrationWeight(window, 'uid1'), logic.CONCENTRATION_DOWNWEIGHT);
  });

  test('a distinct concentrated window does not penalize a giver OUTSIDE that set', () => {
    const window = Array.from({ length: 20 }, (_, i) => `uid${i % 3}`);
    assert.equal(logic.concentrationWeight(window, 'brand_new_uid'), 1);
  });
});

describe('pushCappedWindow (bounded FIFO)', () => {
  test('appends under the cap without evicting', () => {
    assert.deepEqual(logic.pushCappedWindow(['a', 'b'], 'c', 5), ['a', 'b', 'c']);
  });

  test('evicts the oldest entry once over the cap', () => {
    assert.deepEqual(logic.pushCappedWindow(['a', 'b', 'c'], 'd', 3), ['b', 'c', 'd']);
  });

  test('handles a non-array input defensively', () => {
    assert.deepEqual(logic.pushCappedWindow(undefined, 'a', 3), ['a']);
  });
});

describe('combinedEngagementWeight', () => {
  test('takes the more punitive of the two signals — reciprocity worse', () => {
    const w = logic.combinedEngagementWeight({
      priorGivenGiverToReceiver: 10,
      priorGivenReceiverToGiver: 10, // reciprocal → 0.2
      receiverRecentGivers: [], // window too small → concentration = 1
      giverUid: 'x',
    });
    assert.equal(w, logic.RECIPROCITY_DOWNWEIGHT);
  });

  test('takes the more punitive of the two signals — concentration worse', () => {
    const window = Array.from({ length: 20 }, (_, i) => `uid${i % 2}`);
    const w = logic.combinedEngagementWeight({
      priorGivenGiverToReceiver: 0,
      priorGivenReceiverToGiver: 0, // no reciprocity history → 1
      receiverRecentGivers: window,
      giverUid: 'uid0',
    });
    assert.equal(w, logic.CONCENTRATION_DOWNWEIGHT);
  });

  test('neither signal fires → full weight', () => {
    const w = logic.combinedEngagementWeight({
      priorGivenGiverToReceiver: 1,
      priorGivenReceiverToGiver: 0,
      receiverRecentGivers: ['a', 'b'],
      giverUid: 'brand_new',
    });
    assert.equal(w, 1);
  });
});

describe('account-age gate', () => {
  test('brand-new account (no createdAt) is never old enough', () => {
    assert.equal(logic.isAccountOldEnough(null, Date.now()), false);
  });

  test('account younger than 3 days is not old enough', () => {
    const now = Date.now();
    const created = now - (2 * 24 * 60 * 60 * 1000);
    assert.equal(logic.isAccountOldEnough(created, now), false);
  });

  test('account exactly at 3 days is old enough (boundary inclusive)', () => {
    const now = Date.now();
    const created = now - logic.MIN_ACCOUNT_AGE_MS;
    assert.equal(logic.isAccountOldEnough(created, now), true);
  });

  test('account older than 3 days is old enough', () => {
    const now = Date.now();
    const created = now - (10 * 24 * 60 * 60 * 1000);
    assert.equal(logic.isAccountOldEnough(created, now), true);
  });
});

describe('shadow-restriction auto-trigger', () => {
  test('below threshold does not restrict', () => {
    assert.equal(logic.shouldAutoRestrict(logic.AUTO_RESTRICT_FLAG_THRESHOLD - 1), false);
  });

  test('at threshold restricts', () => {
    assert.equal(logic.shouldAutoRestrict(logic.AUTO_RESTRICT_FLAG_THRESHOLD), true);
  });

  test('above threshold restricts', () => {
    assert.equal(logic.shouldAutoRestrict(logic.AUTO_RESTRICT_FLAG_THRESHOLD + 10), true);
  });

  test('missing/garbage input never restricts', () => {
    assert.equal(logic.shouldAutoRestrict(undefined), false);
    assert.equal(logic.shouldAutoRestrict(NaN), false);
  });
});

describe('credit table + premium 2x multiplier', () => {
  test('free user gets base credit and base cap', () => {
    const r = logic.creditAndCapForPremium('post_reactions', false);
    assert.equal(r.credit, 1);
    assert.equal(r.dailyCap, 2);
    assert.equal(r.threshold, 10);
    assert.equal(r.multiplierApplied, 1);
  });

  test('premium user gets doubled credit AND doubled cap', () => {
    const r = logic.creditAndCapForPremium('post_reactions', true);
    assert.equal(r.credit, 2);
    assert.equal(r.dailyCap, 4);
    assert.equal(r.multiplierApplied, 2);
  });

  test('premium does NOT double the distinct-account threshold', () => {
    const free = logic.creditAndCapForPremium('post_reactions', false);
    const premium = logic.creditAndCapForPremium('post_reactions', true);
    assert.equal(free.threshold, premium.threshold);
  });

  test('weekly_group_top3 uses weeklyCap, not dailyCap, doubled for premium', () => {
    const free = logic.creditAndCapForPremium('weekly_group_top3', false);
    const premium = logic.creditAndCapForPremium('weekly_group_top3', true);
    assert.equal(free.dailyCap, null);
    assert.equal(free.weeklyCap, 1);
    assert.equal(premium.weeklyCap, 2);
    assert.equal(premium.credit, 10);
  });

  test('template_used has no distinct-account threshold (null)', () => {
    const r = logic.creditAndCapForPremium('template_used', false);
    assert.equal(r.threshold, undefined);
  });

  test('unknown source key returns null', () => {
    assert.equal(logic.creditAndCapForPremium('not_a_real_source', false), null);
  });

  test('every documented §5.2 source exists in the table with the plan\'s exact base numbers', () => {
    assert.equal(logic.CREDIT_TABLE.post_reactions.credit, 1);
    assert.equal(logic.CREDIT_TABLE.post_reactions.dailyCap, 2);
    assert.equal(logic.CREDIT_TABLE.comment_likes.credit, 1);
    assert.equal(logic.CREDIT_TABLE.comment_likes.dailyCap, 1);
    assert.equal(logic.CREDIT_TABLE.template_used.credit, 1);
    assert.equal(logic.CREDIT_TABLE.template_used.dailyCap, 3);
    assert.equal(logic.CREDIT_TABLE.weekly_group_top3.credit, 5);
    assert.equal(logic.CREDIT_TABLE.weekly_group_top3.weeklyCap, 1);
  });
});

describe('local day/week time helpers (Turkey, fixed UTC+3)', () => {
  test('startOfLocalDayMs: a timestamp just after local midnight rounds down to that midnight', () => {
    // 2026-08-03T00:30:00 LOCAL (UTC+3) == 2026-08-02T21:30:00Z
    const nowMs = Date.UTC(2026, 7, 2, 21, 30, 0);
    const startMs = logic.startOfLocalDayMs(nowMs);
    // Expected local midnight 2026-08-03T00:00 == 2026-08-02T21:00:00Z
    assert.equal(startMs, Date.UTC(2026, 7, 2, 21, 0, 0));
  });

  test('startOfLocalDayMs: a timestamp just before local midnight belongs to the PRIOR day', () => {
    // 2026-08-02T23:59:00 LOCAL == 2026-08-02T20:59:00Z
    const nowMs = Date.UTC(2026, 7, 2, 20, 59, 0);
    const startMs = logic.startOfLocalDayMs(nowMs);
    // Expected local midnight 2026-08-02T00:00 == 2026-08-01T21:00:00Z
    assert.equal(startMs, Date.UTC(2026, 7, 1, 21, 0, 0));
  });

  test('startOfLocalWeekMs: a Wednesday rounds back to that week\'s Monday 00:00 local', () => {
    // 2026-08-05 is a Wednesday. Local Wed 12:00 == UTC 09:00 same day.
    const nowMs = Date.UTC(2026, 7, 5, 9, 0, 0);
    const startMs = logic.startOfLocalWeekMs(nowMs);
    // Monday is 2026-08-03; local midnight 2026-08-03T00:00 == 2026-08-02T21:00:00Z.
    assert.equal(startMs, Date.UTC(2026, 7, 2, 21, 0, 0));
  });

  test('startOfLocalWeekMs: a Monday just after local midnight stays in the SAME week', () => {
    // 2026-08-03T00:10 LOCAL (a Monday) == 2026-08-02T21:10:00Z
    const nowMs = Date.UTC(2026, 7, 2, 21, 10, 0);
    const startMs = logic.startOfLocalWeekMs(nowMs);
    assert.equal(startMs, Date.UTC(2026, 7, 2, 21, 0, 0));
  });

  test('localWeekKey returns the Monday\'s local calendar date', () => {
    const nowMs = Date.UTC(2026, 7, 5, 9, 0, 0); // Wednesday 2026-08-05
    assert.equal(logic.localWeekKey(nowMs), '2026-08-03');
  });

  test('localWeekKey is stable across every day of the same week', () => {
    const monday = logic.localWeekKey(Date.UTC(2026, 7, 2, 21, 0, 1)); // just after Mon local midnight
    const sunday = logic.localWeekKey(Date.UTC(2026, 7, 8, 20, 59, 0)); // just before next Mon local midnight
    assert.equal(monday, sunday);
  });

  test('localWeekKey changes across a week boundary', () => {
    // Week of 2026-08-03 (Mon) runs through Sunday 2026-08-09; the boundary
    // into the next week (Monday 2026-08-10 00:00 local) is UTC 2026-08-09T21:00:00.
    const lastSecondOfWeek = logic.localWeekKey(Date.UTC(2026, 7, 9, 20, 59, 59));
    const firstSecondOfNextWeek = logic.localWeekKey(Date.UTC(2026, 7, 9, 21, 0, 0));
    assert.notEqual(lastSecondOfWeek, firstSecondOfNextWeek);
  });

  test('previousWeekKey steps back exactly one Monday', () => {
    assert.equal(logic.previousWeekKey('2026-08-10'), '2026-08-03');
  });

  test('previousWeekKey crosses a month boundary correctly', () => {
    assert.equal(logic.previousWeekKey('2026-09-07'), '2026-08-31');
  });

  test('previousWeekKey crosses a year boundary correctly', () => {
    assert.equal(logic.previousWeekKey('2027-01-04'), '2026-12-28');
  });

  test('previousWeekKey is the exact inverse of stepping forward 7 days', () => {
    const week = logic.localWeekKey(Date.UTC(2026, 7, 5, 9, 0, 0)); // 2026-08-03
    const nextWeek = logic.localWeekKey(Date.UTC(2026, 7, 12, 9, 0, 0)); // 2026-08-10
    assert.equal(logic.previousWeekKey(nextWeek), week);
  });
});

describe('pickTopNEligible', () => {
  test('skips ineligible entries and promotes the next-ranked eligible one', () => {
    const ranked = [
      { uid: 'a', score: 100, eligible: false },
      { uid: 'b', score: 90, eligible: true },
      { uid: 'c', score: 80, eligible: true },
      { uid: 'd', score: 70, eligible: false },
      { uid: 'e', score: 60, eligible: true },
      { uid: 'f', score: 50, eligible: true },
    ];
    const top3 = logic.pickTopNEligible(ranked, 3);
    assert.deepEqual(top3.map((e) => e.uid), ['b', 'c', 'e']);
  });

  test('fewer eligible entries than N returns only what exists', () => {
    const ranked = [
      { uid: 'a', score: 100, eligible: true },
      { uid: 'b', score: 90, eligible: false },
    ];
    const top3 = logic.pickTopNEligible(ranked, 3);
    assert.deepEqual(top3.map((e) => e.uid), ['a']);
  });

  test('empty ranking returns empty', () => {
    assert.deepEqual(logic.pickTopNEligible([], 3), []);
    assert.deepEqual(logic.pickTopNEligible(undefined, 3), []);
  });
});
