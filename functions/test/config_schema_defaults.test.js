'use strict';

// Faz A §A8 Faz 0 — the single most valuable test in the config migration
// (see PLAN.md): asserts every default in the canonical
// functions/config_schema.json equals whatever real, currently-live
// hardcoded constant it is meant to replace — by `require()`ing the real
// modules, not by re-reading config_schema.json's own numbers back at
// itself. This converts "did the migration change behavior?" from a manual
// review question into a CI result.
//
//   node --test functions/test/config_schema_defaults.test.js
//
// Companion to test/config_schema_defaults_test.dart, which covers the
// Dart/client side. Every constant checked here was, as of this change,
// made importable by an additive `Object.assign(module.exports, {...})` (or
// equivalent) appended to its source file — see each of those files' own
// "Faz A (config migration)" comment. No behavior changed; only visibility.
//
// TWO KNOWN, INTENTIONAL non-matches, asserted explicitly rather than
// silently skipped — see PLAN.md's Faz 0 section for the full reasoning:
//   - ai.free_daily_limit / ai.premium_daily_limit: the schema's resolved
//     default (2/20) is asserted to EQUAL the server's real enforced value
//     (functions/index.js) and to DIFFER from AiConfig's still-stale Dart
//     default (5/50) — proving the resolution was applied correctly, not
//     merely omitted.

const { test, describe } = require('node:test');
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');

const schema = JSON.parse(
  fs.readFileSync(path.join(__dirname, '..', 'config_schema.json'), 'utf8'),
);
const defaultOf = (key) => schema[key].default;

const economy = require('../economy');
const index = require('../index');
const progress = require('../progress');
const purchases = require('../purchases');
const presence = require('../presence');
const groups = require('../groups');
const templates = require('../templates');
const moderation = require('../moderation');
const engagementCredit = require('../engagement_credit');
const engagementCreditLogic = require('../engagement_credit_logic');
const createSummariesModule = require('../summaries');

describe('economy.js', () => {
  test('economy.referral_reward_days', () => {
    assert.equal(defaultOf('economy.referral_reward_days'), economy.REFERRAL_REWARD_DAYS);
  });
  test('economy.referral_max_uses', () => {
    assert.equal(defaultOf('economy.referral_max_uses'), economy.REFERRAL_MAX_USES);
  });
  test('economy.referral_commission_try', () => {
    assert.equal(
      defaultOf('economy.referral_commission_try'), economy.REFERRAL_COMMISSION_TRY,
    );
  });
  test('economy.gym_commission_try', () => {
    assert.deepEqual(defaultOf('economy.gym_commission_try'), economy.GYM_COMMISSION_TRY);
  });
});

describe('index.js — AI quota/cost/rate constants', () => {
  test('ai.free_daily_limit: schema (resolved) matches the SERVER value, not the stale Dart default', () => {
    assert.equal(defaultOf('ai.free_daily_limit'), index.FREE_DAILY_LIMIT);
    assert.equal(index.FREE_DAILY_LIMIT, 2, 'server value moved — re-check the Faz 0 resolution note');
  });
  test('ai.premium_daily_limit: schema (resolved) matches the SERVER value, not the stale Dart default', () => {
    assert.equal(defaultOf('ai.premium_daily_limit'), index.PREMIUM_DAILY_LIMIT);
    assert.equal(index.PREMIUM_DAILY_LIMIT, 20, 'server value moved — re-check the Faz 0 resolution note');
  });
  test('ai.max_tokens (MAX_OUTPUT_TOKENS)', () => {
    assert.equal(defaultOf('ai.max_tokens'), index.MAX_OUTPUT_TOKENS);
  });
  test('ai.max_messages', () => {
    assert.equal(defaultOf('ai.max_messages'), index.MAX_MESSAGES);
  });
  test('ai.max_total_chars', () => {
    assert.equal(defaultOf('ai.max_total_chars'), index.MAX_TOTAL_CHARS);
  });
  test('ai.rate_window_ms', () => {
    assert.equal(defaultOf('ai.rate_window_ms'), index.RATE_WINDOW_MS);
  });
  test('ai.rate_max_in_window', () => {
    assert.equal(defaultOf('ai.rate_max_in_window'), index.RATE_MAX_IN_WINDOW);
  });
  test('ai.model_pricing', () => {
    assert.deepEqual(defaultOf('ai.model_pricing'), index.MODEL_PRICING);
  });
  test('ai.allowed_models is a SUBSET of the live set (env-derived entries are additive, not migrated)', () => {
    const schemaDefault = defaultOf('ai.allowed_models');
    for (const model of schemaDefault) {
      assert.ok(
        index.ALLOWED_MODELS.has(model),
        `schema default "${model}" is missing from the live ALLOWED_MODELS set`,
      );
    }
  });
});

describe('progress.js', () => {
  test('gamification.max_xp_events_per_call', () => {
    assert.equal(defaultOf('gamification.max_xp_events_per_call'), progress.MAX_XP_EVENTS_PER_CALL);
  });
  test('gamification.achievement_points', () => {
    assert.deepEqual(defaultOf('gamification.achievement_points'), progress.ACHIEVEMENT_POINTS);
  });
  test('gamification.gym_regular_checkin_threshold', () => {
    assert.equal(
      defaultOf('gamification.gym_regular_checkin_threshold'),
      progress.GYM_REGULAR_CHECKIN_THRESHOLD,
    );
  });
  test('gamification.group_streak_achievement_threshold', () => {
    assert.equal(
      defaultOf('gamification.group_streak_achievement_threshold'),
      progress.GROUP_STREAK_ACHIEVEMENT_THRESHOLD,
    );
  });
  test('gamification.tier_level_floor', () => {
    assert.deepEqual(defaultOf('gamification.tier_level_floor'), progress.TIER_LEVEL_FLOOR);
  });
  test('gamification.local_utc_offset_hours', () => {
    assert.equal(defaultOf('gamification.local_utc_offset_hours'), progress.LOCAL_UTC_OFFSET_HOURS);
  });
  test('gamification.level_curve_coefficient', () => {
    assert.equal(defaultOf('gamification.level_curve_coefficient'), progress.LEVEL_CURVE_COEFFICIENT);
  });
  test('gamification.max_level', () => {
    assert.equal(defaultOf('gamification.max_level'), progress.MAX_LEVEL);
  });
  test('XP_TABLE (already exported pre-migration)', () => {
    assert.deepEqual(defaultOf('gamification.xp_table'), progress.XP_TABLE);
  });
});

describe('purchases.js', () => {
  test('purchases.products', () => {
    assert.deepEqual(defaultOf('purchases.products'), purchases.PRODUCTS);
  });
});

describe('presence.js', () => {
  test('presence.timestamp_skew_ms', () => {
    assert.equal(defaultOf('presence.timestamp_skew_ms'), presence.TIMESTAMP_SKEW_MS);
  });
  test('presence.rate_limit_reentry_ms', () => {
    assert.equal(defaultOf('presence.rate_limit_reentry_ms'), presence.RATE_LIMIT_REENTRY_MS);
  });
  test('presence.presence_ttl_ms', () => {
    assert.equal(defaultOf('presence.presence_ttl_ms'), presence.PRESENCE_TTL_MS);
  });
  test('presence.stale_sweep_limit', () => {
    assert.equal(defaultOf('presence.stale_sweep_limit'), presence.STALE_SWEEP_LIMIT);
  });
  test('presence.max_friends_fanout', () => {
    assert.equal(defaultOf('presence.max_friends_fanout'), presence.MAX_FRIENDS_FANOUT);
  });
  test('presence.notify_log_ttl_days', () => {
    assert.equal(defaultOf('presence.notify_log_ttl_days'), presence.NOTIFY_LOG_TTL_DAYS);
  });
  test('presence.quiet_hours_start / quiet_hours_end', () => {
    assert.equal(defaultOf('presence.quiet_hours_start'), presence.QUIET_HOURS_START);
    assert.equal(defaultOf('presence.quiet_hours_end'), presence.QUIET_HOURS_END);
  });
});

describe('groups.js', () => {
  test('groups.activity_window_hours', () => {
    assert.equal(defaultOf('groups.activity_window_hours'), groups.ACTIVITY_WINDOW_HOURS);
  });
  test('groups.activity_half_life_hours', () => {
    assert.equal(defaultOf('groups.activity_half_life_hours'), groups.ACTIVITY_HALF_LIFE_HOURS);
  });
  test('groups.activity_groups_per_run', () => {
    assert.equal(defaultOf('groups.activity_groups_per_run'), groups.ACTIVITY_GROUPS_PER_RUN);
  });
  test('groups.activity_signal_limit', () => {
    assert.equal(defaultOf('groups.activity_signal_limit'), groups.ACTIVITY_SIGNAL_LIMIT);
  });
  test('groups.activity_comments_scan_limit', () => {
    assert.equal(
      defaultOf('groups.activity_comments_scan_limit'), groups.ACTIVITY_COMMENTS_SCAN_LIMIT,
    );
  });
});

describe('templates.js', () => {
  test('templates.offer_ttl_days', () => {
    assert.equal(defaultOf('templates.offer_ttl_days'), templates.OFFER_TTL_DAYS);
  });
  test('templates.max_recipients_per_call', () => {
    assert.equal(defaultOf('templates.max_recipients_per_call'), templates.MAX_RECIPIENTS_PER_CALL);
  });
  test('templates.max_message_length', () => {
    assert.equal(defaultOf('templates.max_message_length'), templates.MAX_MESSAGE_LENGTH);
  });
});

describe('moderation.js — 3 rate-limit triples', () => {
  test('moderation.report_rate_limit', () => {
    assert.deepEqual(defaultOf('moderation.report_rate_limit'), {
      windowMs: moderation.REPORT_RATE_WINDOW_MS,
      max: moderation.REPORT_RATE_MAX_IN_WINDOW,
      lockMs: moderation.REPORT_LOCK_MS,
    });
  });
  test('moderation.action_rate_limit', () => {
    assert.deepEqual(defaultOf('moderation.action_rate_limit'), {
      windowMs: moderation.MOD_RATE_WINDOW_MS,
      max: moderation.MOD_RATE_MAX_IN_WINDOW,
      lockMs: moderation.MOD_LOCK_MS,
    });
  });
  test('moderation.appeal_rate_limit', () => {
    assert.deepEqual(defaultOf('moderation.appeal_rate_limit'), {
      windowMs: moderation.APPEAL_RATE_WINDOW_MS,
      max: moderation.APPEAL_RATE_MAX_IN_WINDOW,
      lockMs: moderation.APPEAL_LOCK_MS,
    });
  });
});

describe('media.js — VISION_DAILY_CAP (env-driven; test in isolation)', () => {
  test('defaults to the schema value when VISION_DAILY_CAP is unset', () => {
    const hadEnv = Object.prototype.hasOwnProperty.call(process.env, 'VISION_DAILY_CAP');
    const prevValue = process.env.VISION_DAILY_CAP;
    delete process.env.VISION_DAILY_CAP;
    delete require.cache[require.resolve('../media')];
    try {
      const media = require('../media');
      assert.equal(defaultOf('media.vision_daily_cap'), media.VISION_DAILY_CAP);
    } finally {
      if (hadEnv) process.env.VISION_DAILY_CAP = prevValue;
      delete require.cache[require.resolve('../media')];
    }
  });
});

describe('engagement_credit.js', () => {
  test('engagement.weekly_min_active_members (NOT gym k-anonymity — see privacy.k_anonymity_threshold)', () => {
    assert.equal(
      defaultOf('engagement.weekly_min_active_members'), engagementCredit.WEEKLY_MIN_ACTIVE_MEMBERS,
    );
  });
  test('engagement.weekly_contrib_groups_per_run', () => {
    assert.equal(
      defaultOf('engagement.weekly_contrib_groups_per_run'),
      engagementCredit.WEEKLY_CONTRIB_GROUPS_PER_RUN,
    );
  });
  test('engagement.weekly_top_n', () => {
    assert.equal(defaultOf('engagement.weekly_top_n'), engagementCredit.WEEKLY_TOP_N);
  });
  test('engagement.weekly_candidate_buffer', () => {
    assert.equal(
      defaultOf('engagement.weekly_candidate_buffer'), engagementCredit.WEEKLY_CANDIDATE_BUFFER,
    );
  });
  test('engagement.contrib_leaderboard_groups_per_run', () => {
    assert.equal(
      defaultOf('engagement.contrib_leaderboard_groups_per_run'),
      engagementCredit.CONTRIB_LEADERBOARD_GROUPS_PER_RUN,
    );
  });
  test('engagement.contrib_leaderboard_top_n', () => {
    assert.equal(
      defaultOf('engagement.contrib_leaderboard_top_n'), engagementCredit.CONTRIB_LEADERBOARD_TOP_N,
    );
  });
});

describe('engagement_credit_logic.js', () => {
  test('moderation.post_min_text_length / comment_min_text_length / message_min_text_length', () => {
    assert.equal(defaultOf('moderation.post_min_text_length'), engagementCreditLogic.POST_MIN_TEXT_LENGTH);
    assert.equal(
      defaultOf('moderation.comment_min_text_length'), engagementCreditLogic.COMMENT_MIN_TEXT_LENGTH,
    );
    assert.equal(
      defaultOf('moderation.message_min_text_length'), engagementCreditLogic.MESSAGE_MIN_TEXT_LENGTH,
    );
  });
  test('moderation.duplicate_similarity_threshold / duplicate_recent_window', () => {
    assert.equal(
      defaultOf('moderation.duplicate_similarity_threshold'),
      engagementCreditLogic.DUPLICATE_SIMILARITY_THRESHOLD,
    );
    assert.equal(
      defaultOf('moderation.duplicate_recent_window'), engagementCreditLogic.DUPLICATE_RECENT_WINDOW,
    );
  });
  test('moderation.reciprocity_*', () => {
    assert.equal(
      defaultOf('moderation.reciprocity_min_pair_sample'),
      engagementCreditLogic.RECIPROCITY_MIN_PAIR_SAMPLE,
    );
    assert.equal(
      defaultOf('moderation.reciprocity_ratio_threshold'),
      engagementCreditLogic.RECIPROCITY_RATIO_THRESHOLD,
    );
    assert.equal(
      defaultOf('moderation.reciprocity_downweight'), engagementCreditLogic.RECIPROCITY_DOWNWEIGHT,
    );
  });
  test('moderation.concentration_*', () => {
    assert.equal(defaultOf('moderation.concentration_window'), engagementCreditLogic.CONCENTRATION_WINDOW);
    assert.equal(
      defaultOf('moderation.concentration_distinct_max'),
      engagementCreditLogic.CONCENTRATION_DISTINCT_MAX,
    );
    assert.equal(
      defaultOf('moderation.concentration_downweight'),
      engagementCreditLogic.CONCENTRATION_DOWNWEIGHT,
    );
  });
  test('moderation.min_account_age_ms', () => {
    assert.equal(defaultOf('moderation.min_account_age_ms'), engagementCreditLogic.MIN_ACCOUNT_AGE_MS);
  });
  test('moderation.auto_restrict_flag_threshold', () => {
    assert.equal(
      defaultOf('moderation.auto_restrict_flag_threshold'),
      engagementCreditLogic.AUTO_RESTRICT_FLAG_THRESHOLD,
    );
  });
  test('engagement.credit_table', () => {
    assert.deepEqual(defaultOf('engagement.credit_table'), engagementCreditLogic.CREDIT_TABLE);
  });
});

describe('summaries.js — the k-anonymity threshold this session\'s fix introduced', () => {
  test('privacy.k_anonymity_threshold matches GYM_SHARING_K_ANONYMITY_THRESHOLD', () => {
    assert.equal(
      defaultOf('privacy.k_anonymity_threshold'),
      createSummariesModule.GYM_SHARING_K_ANONYMITY_THRESHOLD,
    );
  });
});
