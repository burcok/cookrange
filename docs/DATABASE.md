# DATABASE.md — Data Model, Firestore, Indexes & Rules

> Canonical map of the data layer. Before touching a model, a query, an index, or a security rule,
> read the relevant row here. **Code is truth — if this drifts, fix it.**
> Owners: `lib/core/models/**`, `lib/core/data/**`, `lib/core/repositories/**`,
> `firestore.rules`, `firestore.indexes.json`, `storage.rules`.
>
> Rule *intent* and the threat model live in [`SECURITY.md`](SECURITY.md); this document owns the
> shapes and the access matrix.

---

## 0. Collection tree — quick scan

Read this first; drop to §1 only when you need the access rules.

```
users/{uid}                                   public profile + onboarding_data, roles, tier mirror,
                                                xp/level (Faz 5 §5.1, server-write only)
  ├─ private/nutrition                         PII — height/weight/gender/DOB, allergies, restrictions
  ├─ private/account                           PII (N1) — email, login/device history, FCM token
  ├─ private/presence_prefs                    per-gym auto-check-in toggle + friend-notify toggle
  ├─ private/chat_prefs                        Faz 2 §2.4 — per-chat pin/archive/mute/delete (map
                                                keyed by chatId → Timestamp of the action; presence of
                                                the key is the on/off signal)
  ├─ meal_plans/current                        current weekly plan (+ generationPromptHash)
  ├─ meal_plan_history/{YYYY-MM-DD}            archived weekly plans
  ├─ plan_offers/{id}                           Faz 3 §3.2 — a meal_plan_templates/{id} sent to this
                                                user (immutable template_snapshot). create: server-only
  ├─ food_logs/{id} · exercise_logs/{id}       daily diary · workout logs
  ├─ favorites/{recipeId} · recent_foods/{id}  saved recipes · quick-add cache (~20)
  ├─ recipe_notes/{recipeId} · lists/{listId}  user notes · shopping lists
  ├─ saved_posts/{postId}                      bookmarked posts
  ├─ starred_messages/{messageId}               Faz 2 §2.2 — starred chat messages (doc id = messageId)
  ├─ notifications/{id}                        RETIRED (BLK-03) — see notifications/{uid}/items below
  ├─ notification_preferences/{id}             per-group mute prefs
  ├─ program_enrollments/{programId}           enrolled programs + progress
  ├─ commissions/{id} · payout_requests/{id}   economy — SERVER-WRITE ONLY
  ├─ ai_twin_projections/{id}                  saved AI projections (locale-tagged)
  ├─ ai_weekly_recaps/{id} · food_analyses/{id}  weekly recaps · AI food-analysis history
  ├─ achievements/{key}                        earned badges
  ├─ xp_events/{eventId}                        Faz 5 §5.1 — immutable XP ledger, eventId is the
                                                idempotency key (`${kind}_${refId}`). Server-write only
  ├─ engagement_credit_events/{eventId}          Faz 5 §5.2 — immutable RECEIVED-engagement credit
                                                ledger (distinct-account reaction/like thresholds,
                                                template use, weekly group-contribution top-3).
                                                Same eventId idempotency shape as xp_events, different
                                                collection (never reused) — see functions/engagement_credit.js
  ├─ (root) .group_top3_streak / .group_top3_streak_week_key   Faz 5 §5.3 — consecutive-week
                                                group-contribution streak counter, field-locked like
                                                xp/level above. Server-write only (bumpGroupTop3Streak)
  ├─ (root) .streak_freeze_count                 SEC-14 — login streak-freeze count, field-locked
                                                like xp/level above. `onboarding_data.streak` (line 18)
                                                is ALSO field-locked as of SEC-14 despite living
                                                nested inside the otherwise client-writable
                                                onboarding_data map (meal_reminder/water_reminder
                                                stay client-writable — see firestore.rules'
                                                onboardingStreakChanged()). Server-write only
                                                (processStreakLogin); create is additionally bounded
                                                to the <=1 welcome-gift shape for both fields.
                                                SEC-31 extended the same server-write-only lock to
                                                `.last_login_at` (processStreakLogin's SOLE input for
                                                the days-since-last-login diff — previously forgeable
                                                to an arbitrary past Timestamp via the raw SDK) and
                                                `.streak_freeze_used_at` (the freeze-consumed
                                                timestamp). Both are written only inside
                                                processStreakLogin's own transaction; the client's
                                                former redundant write of last_login_at
                                                (firestore_service.dart's handleUserLogin,
                                                existing-user branch) was removed. last_login_at is
                                                deliberately left unbounded on `create` — see that
                                                rule's own SEC-31 comment for the arithmetic showing
                                                the existing streak_freeze_count/onboarding_data.streak
                                                create bounds already neutralize it
  ├─ credit_moderation/{autoId}                  Faz 5 §5.2 — shadow-restriction restrict/lift log,
                                                account-scoped equivalent of community_groups'
                                                moderation/{autoId} below. Server/admin-write only
  ├─ consents/{purpose}                        KVKK/GDPR consent records
  ├─ progress_sharing/{scopeId}                 Faz 4 §4.1 — tiered (0-3), per-scope
                                                ('gym_{id}'|'coach_{uid}') sharing consent.
                                                Different SHAPE from consents/{purpose} above
                                                (per-scope + tiered, not global + bool) —
                                                owner-direct write, versioned/timestamped
  ├─ access_log/{entryId}                       Faz 4 §4.2 — "who generated a summary about
                                                me, and when" (viewer_uid, viewer_type,
                                                scope_id, viewed_at). Server-write only
  ├─ following/{uid} · followers/{uid}         follow graph (one-way)
  ├─ friends/{id} · friend_requests/{id}       friendship (mutual) — SERVER-WRITE ONLY (SEC-06)
  ├─ coaching_requests/{clientUid}             coach link requests
  └─ block_list/{blockedId}                    blocked users

dishes/{id}                                   recipe DB (admin-write, seeded)
posts/{id}                                    community posts  (+ /comments, /likes, /reactions,
                                               /credit_progress — Faz 5 §5.2, fully server-only cache
                                               of the content-quality/duplicate verdict + running
                                               weighted progress toward the post-reactions credit
                                               threshold; /comments/{id}/credit_progress mirrors this
                                               for the comment-likes credit threshold)
chats/{id}/messages/{id}                      chat threads + messages (v2 schema — Faz 2 §2.1).
                                               A group's own chat is one of these (`groupId` set) —
                                               see community_groups/{id} below
signals/{id}                                  ephemeral broadcasts (TTL via expiresAt)
community_groups/{id}                         unified groups (Faz 2 §2.3): public/private/gym, paired
                                               1:1 chat, announcement-only, join policy, invites
  ├─ members/{uid}                            role owner|admin|moderator|member (+ muted_until/banned)
  ├─ join_requests/{uid}                      pending asks when join_policy == 'request'
  ├─ moderation/{autoId}                      mute/kick/ban log, immutable, target-uid-readable
  ├─ secrets/invite                           owner/admin-only invite code (never on the public doc)
  ├─ weekly_contributions/{weekKey}/members/{uid}  Faz 5 §5.2 — per-member weekly contribution
                                               score (message×1/post×3/comment×2, same weights as
                                               activity_score, flat weekly sum not decayed). Fully
                                               server-only; feeds the weekly top-3 credit sweep
  └─ weekly_leaderboard/{weekKey}              Faz 5 §5.3 — the denormalized, group-member-readable
                                               top-10 summary of the row above (current week, live
                                               display) — never a widened read on weekly_contributions
                                               itself
group_invites/{code}                          server-only reverse lookup (code → group_id), doc id =
                                               code, fully closed to client reads (redeemGroupInvite
                                               only)
squads/{id}                                   streak squads
reports/{id} · privacy_requests/{id}          moderation queue · DSAR channel
moderation_appeals/{id}                       Faz 2 §2.6 — appeal against one specific group
                                               moderation/{autoId} entry, doc id == that entry's id
rate_limits/{uid}                             Faz 2 §2.6 — server-only sliding-window ledger for
                                               reports/moderation actions/appeals abuse throttling
referrals/{code}                              referral codes (personal/coach-vanity/gym — Faz 6 §6.1)

gyms/{id}                                     gym profiles (+ /members, /posts, /checkins,
                                               /presence, /presence_sessions — Faz 1,
                                               /member_summaries, /progress_share_invites — Faz 4)
gym_wars/{id} · gym_applications/{id}         competition · owner applications
coach_profiles/{uid}                          coach profiles (+ /clients, /reviews,
                                               /member_summaries, /progress_share_invites — Faz 4)
coach_applications/{id}                       coach applications
programs/{id}/weeks/{id}/sessions             marketplace programs

ai_credits/{uid}          SERVER-ONLY WRITE   daily quota + bonus + lifetime totals. Faz 5 §5.2's
                                              received-engagement credit lands in `.bonus` here too
                                              (same field, same grantBonusCredits writer — no 2nd currency)
entitlements/{uid}        SERVER-ONLY WRITE   premium tier + expiry — SOURCE OF TRUTH
credit_restrictions/{uid} SERVER/ADMIN WRITE  Faz 5 §5.2 — shadow-restriction state
                                              (is_shadow_restricted, reason, flag_count, latest_entry_id).
                                              Owner-read (appeal path needs to know), same shape as
                                              ai_credits/entitlements above
reciprocity_pairs/{pairKey}  SERVER-ONLY      Faz 5 §5.2 — bidirectional interaction counts between two
                                              uids (pairKey = sorted "uidA_uidB"), feeds the
                                              reciprocity-ring down-weighting. Fully closed, no client
                                              read/write path at all — see engagement_credit_logic.js
engagement_diversity/{uid}   SERVER-ONLY      Faz 5 §5.2 — rolling window (last 20) of distinct-engager
                                              uids a RECEIVER has gotten credit-worthy engagement from,
                                              feeds the closed-cluster/concentration down-weighting.
                                              Fully closed, same shape as reciprocity_pairs above
community_weekly_xp/{weekKey}/members/{uid}  Faz 5 §5.3 — denormalized per-week XP rollup (this
                                              WEEK's XP only, not lifetime), bumped transactionally by
                                              awardXp (functions/progress.js) inside the same
                                              transaction as every XP award. Flat authenticated-read
                                              (xp is already public on users/{uid} itself) — backs the
                                              weekly community leaderboard AND, via a chunked whereIn
                                              lookup, the in-gym leaderboard. Server-write only
processed_purchases/{id}  SERVER-ONLY         purchase-token replay guard (no client access)
ai_usage_logs/{id}        SERVER-ONLY WRITE   per-request AI cost trail (admin-read)
ai_usage_stats/{doc}      SERVER-ONLY WRITE   global + day_YYYY-MM-DD rollups
admin_audit/{id}                              append-only admin action log
admin_config/{doc}                            admin-only flags
app_config/global         PUBLIC READ         remote config — NO SECRETS EVER
settings/content_filter   PUBLIC READ         blocked-keyword list (mirrored from admin config)
broadcasts/{id} · seeds/{doc} · logs/{uid}    broadcasts · seed gates · activity audit
failed_login_attempts/{id} SERVER-ONLY        brute-force tracking
```

---

## 1. Firestore Collection Map

### User-scoped (under `users/{uid}`)
| Path | Purpose | Access (rules) |
|---|---|---|
| `users/{uid}` | Public profile + onboarding_data (streak, goals, activity, role, tier) | Read: any auth · Create: owner (bounded, see below) · Update: owner or admin · Delete: owner. **FIELD-LOCKED**: clients cannot write `subscription_tier`/`subscription_*`/`ai_credits_*`/`referral_used`/`is_banned`/`reputation_score`/`reputation_updated_at`/**`xp`/`level`/`level_updated_at`** (Faz 5 §5.1) / **`group_top3_streak`/`group_top3_streak_week_key`** (Faz 5 §5.3) / **`streak_freeze_count`/`onboarding_data.streak`** (`SEC-14`, written only by `processStreakLogin`) / **`last_login_at`/`streak_freeze_used_at`** (`SEC-31`, same writer — `last_login_at` is `processStreakLogin`'s sole input for the streak diff, so leaving it client-writable let the whole `SEC-14` lock be bypassed one hop removed) — these are server/admin-only (entitlements + economy + XP + the group-contribution streak + the login streak/freeze are all server-authoritative). `onboarding_data`'s other keys (`meal_reminder`/`water_reminder`) remain client-writable — only the nested `streak` value is locked. `create` is additionally bounded: `streak_freeze_count` and `onboarding_data.streak` must each be an int in `[0, 1]` if present, so a client can't self-create a doc with an inflated starting value; `last_login_at` is left unbounded on `create` (see `firestore.rules`' `SEC-31` comment — the existing two bounds already cap any gain from a forged value there). **`SEC-29`**: `create` additionally rejects the payload outright if it contains ANY of the other 16 FIELD-LOCKED keys above (`xp`/`level`/`level_updated_at`/`reputation_score`/`reputation_updated_at`/`subscription_*`/`ai_credits_*`/`referral_used`/`is_banned`/`group_top3_streak`/`group_top3_streak_week_key`) — before `SEC-29`, `create` had **zero** constraint on any of them (only the two `SEC-14` bounds existed), so a direct Firestore SDK call could self-create a doc with e.g. `xp: 999999` or `subscription_tier: 'premium'` already baked in. No legitimate client creation path ever sets these at creation time, so they are forbidden outright rather than bounded. |
| `users/{uid}/private/nutrition` | **PII**: height/weight/gender/birth_date, allergies, dietary restrictions, disliked foods, avoid ingredients | Owner only |
| `users/{uid}/private/account` | **PII** (N1): email, login/device/session history, current app version, FCM token | Owner read/write · admin read (never write) |
| `users/{uid}/private/presence_prefs` | Faz 1 §1.4: per-gym auto-check-in toggle (`gym_tracking_enabled` map) + `notify_friends_enabled`. Covered by the generic `private/{docId}` owner-only rule, no dedicated rule block | Owner only |
| `users/{uid}/meal_plans/current` | Current weekly meal plan (+ generationPromptHash) | Owner only |
| `users/{uid}/meal_plan_history/{key}` | Archived weekly plans (key = `YYYY-MM-DD` week start) | Owner only |
| `users/{uid}/plan_offers/{id}` | Faz 3 §3.2 — a `meal_plan_templates/{id}` sent to this user; `template_snapshot` is an immutable copy taken at send time (editing/deleting the source template afterward never touches an already-sent offer). **Faz 3 §3.5**: `sendPlanOffer` also writes a `plan_offer`-typed chat message (see `chats/{id}/messages` row) + a `planOfferReceived` notification to the recipient, in the same server write; a 14-day `expirePlanOffers` scheduled sweep (`functions/templates.js`) flips any still-`pending` offer past `expires_at` to `expired`; an `onPlanOfferResponded` Firestore trigger fires a quiet `planOfferDeclined` notification to `from_uid` on decline only (never on accept — not asked for) | Read: owner · **create: server-only** (`sendPlanOffer` callable, `functions/templates.js` — validates the sender's authority over the template and the recipient's real standing) · update: owner, `status`/`responded_at`/**`decline_reason`** only (Faz 3 §3.5 — optional, ≤300 chars, only alongside `status=='declined'`), `pending`→`accepted`\|`declined` exactly once, `responded_at == request.time` · no delete (durable record, like `food_logs`/`checkins`) |
| `users/{uid}/food_logs/{logId}` | Daily food diary entries | Owner only |
| `users/{uid}/exercise_logs/{logId}` | Workout logs (MET-based calorie burn) | Owner only |
| `users/{uid}/favorites/{recipeId}` | Saved recipes | Owner only |
| `users/{uid}/recent_foods/{dishId}` | Last ~20 logged foods (quick-add) | Owner only |
| `users/{uid}/lists/{listId}` | Shopping lists | Owner only |
| `users/{uid}/saved_posts/{postId}` | Bookmarked community posts | Owner only |
| `users/{uid}/recipe_notes/{recipeId}` | User notes on recipes | Owner only |
| `users/{uid}/notifications/{id}` | **RETIRED** (`BLK-03`) — no rule, falls to catch-all deny. The old forgery hole (`create: if isAuthenticated()`, no field checks); replaced by `notifications/{uid}/items/{id}` below | Deny all |
| `users/{uid}/notification_preferences/{prefId}` | Per-group mute prefs | Owner only |
| `users/{uid}/program_enrollments/{programId}` | Enrolled programs + progress | Owner only |
| `users/{uid}/commissions/{id}` | Affiliate/coach commissions. **Faz 6 §6.6** added a fourth `type`: `gymPremiumShare` — a gym owner's revenue share of an attributed member's real premium purchase (flat `GYM_COMMISSION_TRY` per product, `functions/economy.js`), written by `maybeAwardGymCommission` from inside `purchases.js`'s `validatePurchase`, never from a client action, on EVERY qualifying purchase (a renewing subscriber accrues additional entries over time). **Faz 6 §6.6 follow-up (commission reversal)**: `gymPremiumShare` entries also carry `purchase_key` (a one-way SHA-256 of `platform:token`, NOT the reversible `processed_purchases`-style id — this collection is owner-readable, so a reversible encoding would hand the owner the purchasing member's actual Apple/Google transaction id back for no functional gain), `purchase_platform`, `purchase_product_id` — written at grant time so a LATER genuine refund/chargeback (never a plain, non-renewed expiry — that doesn't retroactively invalidate a past, non-refunded purchase) finds this exact entry again via `entitlements.js`'s `reverseCommissionsForPurchase` (a `collectionGroup('commissions')` query on `purchase_key`, new `COLLECTION_GROUP` index below), called from all three of `purchases.js`'s revocation paths (`validatePurchase`'s own `revoked` branch, `appStoreNotifications`, `playRtdn` — the latter two gate the call to their genuine-refund notification types only, unlike their own entitlement-revocation call just above it, which correctly still treats a plain expiry the same as a refund since losing premium ACCESS on non-renewal is always correct). A matched `pending`/`approved` entry is flipped to `rejected` (existing `CommissionStatus`, already excluded from `getEarningsSummary`'s totals) plus `reversed_at`/`reversed_reason`; an already-`paid` entry is left factually intact (only annotated with `reversed_at`/`reversed_reason` — paid history is never rewritten) and instead gets a new sibling entry: negative `amount`, `status:'pending'`, `adjustment_of`/`adjustment_reason` pointing back at the original, so it nets against this owner's next MANUAL payout via the same `pendingAmount`/`totalEarned` arithmetic, rather than clawing back cash already sent (mirrors `marketplace_terms_{en,tr}.md` §10's "amounts Cookrange owes you may be offset against amounts you owe Cookrange"). The pre-existing `referral` commission (`applyReferral`) is structurally exempt — granted at code-redemption time from a free trial grant with no store transaction behind it, so it never carries a `purchase_key` | Read owner · **write server-only** (economy is server-authoritative) · no client delete (server-side reversal only ever creates/updates, never deletes — the ledger stays append-only) |
| `users/{uid}/payout_requests/{id}` | Payout requests | Owner only |
| `users/{uid}/ai_twin_projections/{id}` | Saved AI fitness projections (locale-tagged). **Faz 5 §5.4**: new `detailedInputs` map (`bmr`/`tdee`/`avgLoggedCalories`/`daysWithLogs`) — the already-computed numbers behind the AI's narrative, captured at generation time (no new AI call). Powers `AiFitnessTwinScreen`'s premium-gated (`Entitlements.advancedAIAnalysis`) detailed-breakdown section; absent on any projection saved before this change, handled as a null-safe "regenerate to see this" state, not a migration | Owner only |
| `users/{uid}/achievements/{key}` | Earned badges (`kAchievementCatalog` in `achievement_model.dart` — 15 keys as of Faz 5 §5.3 (11 original + `level50`/`groupTop3`/`groupStreak4`/`gymRegular`), each with a fixed `points` value now also used to size its Faz 5 §5.1 XP award). Granted only by `syncProgress`/`backfillProgress` (`functions/progress.js`'s `runSync`) or, for the two new sweep-driven badges, `grantAchievementIfNew` (called from `engagement_credit.js`'s `awardWeeklyGroupTop3`) | Read: owner · **write: if false** (server/Admin-SDK only) |
| `users/{uid}/xp_events/{eventId}` | Faz 5 §5.1 — immutable XP ledger: `kind`, `points` (the awarded amount, already capped), `ref_id`, `created_at`, `multiplier_applied` (always `1` in this phase — reserved for §5.2's separate, premium-multiplied received-engagement credit system, never applied to XP itself, which has no premium bonus by design). `eventId = ${kind}_${refId}` is both the idempotency key (a retried instance replays the same stored outcome) and, via a `kind + created_at` composite index, how each kind's daily cap is enforced (count today's already-awarded events, reject the next one once at the cap — capped/rejected attempts are deliberately never written, so cost stays proportional to real awards only). Written exclusively by `awardXp` (`functions/progress.js`), called from `syncProgress` (client-reported: `meal_logged`/`recipe_cooked`/`post_created`/`comment_created`/`reaction_given`, each independently re-verified against the referenced doc before anything is awarded) and directly, in-process, from `presence.js`/`gym.js` (`check_in`) and `templates.js` (`template_accepted`) — see `progress.js`'s header comment for the full per-kind trust model | Read: owner · **write: if false** (server-only, same privacy level as `achievements/*` above — a fine-grained activity timeline is more sensitive than the aggregate `xp`/`level` numbers on the root profile doc) |
| `users/{uid}/engagement_credit_events/{eventId}` | Faz 5 §5.2 — immutable RECEIVED-engagement credit ledger, a SEPARATE collection from `xp_events` per that file's own header comment ("do not reuse xp_events for this"). `source` (`post_reactions`\|`comment_likes`\|`template_used`\|`weekly_group_top3`), `credit` (already premium-multiplied), `ref_id`, `created_at`, `multiplier_applied` (`1`\|`2` — the ACTUAL, applied premium multiplier this ledger was reserved for), `week_key?` (`weekly_group_top3` only — see below). Same `${source}_${refId}` idempotency as `xp_events`. **Cap-check differs by source**: the three daily sources use a `source + created_at` range query, same shape as `xp_events` (correct there, since the award always happens the SAME day its cap applies to); `weekly_group_top3` uses a `source + week_key` EQUALITY query instead — a range on `created_at` can't work for it, because the actual award always happens AFTER its target week has already closed (the sweep runs some day into the FOLLOWING week), so "created_at >= that week's Monday" would still be true once the NEXT target week rolls around too, wrongly counting a past week's award against a later week's cap (caught in review; a user winning two consecutive weeks would have had their second award wrongly blocked). A real award ALSO increments `ai_credits/{uid}.bonus` (`entitlements.js`'s existing `grantBonusCredits` — no second currency). Written exclusively by `awardEngagementCredit` (`functions/engagement_credit.js`) | Read: owner · **write: if false** |
| `users/{uid}/credit_moderation/{autoId}` | Faz 5 §5.2 — shadow-restriction restrict/lift log, account-scoped equivalent of `community_groups/{id}/moderation/{autoId}` below (`action`: `restrict`\|`lift`, `reason`, `issued_by`: `'system'`\|adminUid, `created_at`). Written by `bumpSuspicionFlag` (`functions/engagement_credit.js`, auto-restrict) or `AdminService._liftCreditRestriction` (appeal upheld). The `moderation_appeals` create rule cross-checks this path (`users/{callerUid}/credit_moderation/{appealId}`) for a second, non-group appeal kind — see that row below | Read: owner or admin · **create: admin only** (client) — the real writer is `bumpSuspicionFlag` via Admin SDK, which bypasses this · no update/delete |
| `users/{uid}/consents/{purpose}` | KVKK/GDPR consent records (granted, policy_version, updated_at) per purpose | Owner only |
| `users/{uid}/progress_sharing/{scopeId}` | Faz 4 §4.1 — tiered (0-3) progress-sharing consent, ONE DOC PER SCOPE (`scopeId` = `gym_{gymId}` \| `coach_{uid}`) rather than one doc per global purpose like `consents/{purpose}` above — a member can share more with one coach than another. `level` (0 kapalı\|1 devam\|2 +uyum\|3 +kilo trendi), `granted_at`, `policy_version`, `revoked_at?`. Default 0 (unshared) for every scope not yet decided. `onProgressSharingWrite` (`functions/summaries.js`) deletes that scope's cached `member_summaries` doc on EVERY write here (any tier change, not just a full revoke) — a stale over-permissive cache never survives a tier change, let alone waiting out its own 7-day TTL | Owner read/write direct (mirrors `ConsentService.setConsent` — granting/revoking IS the user's own action); shape-validated (`level` int 0-3, `policy_version` non-empty, `granted_at`/`revoked_at` server-timestamp-only) · no delete (revoke sets `level:0`, keeps history) |
| `users/{uid}/access_log/{entryId}` | Faz 4 §4.2 — transparency log: who generated a progress summary about this member, and when (`viewer_uid`, `viewer_type`, `scope_id`, `viewed_at`). Survives a later consent revocation on purpose — it's a record of past access, not a live permission | Owner read · **server write only** (`generateMemberProgressSummary`) |
| `users/{uid}/following/{targetUid}` | Following graph | Read any auth · create/delete owner |
| `users/{uid}/followers/{sourceUid}` | Follower graph | Read any auth · create/delete sourceUid |
| `users/{uid}/friends/{friendId}` | Accepted friends | Read owner · create/update **server-only** (`sendFriendRequest`/`respondToFriendRequest`, `SEC-06`) · delete owner (unfriend stays client-direct — safe, owner-scoped) |
| `users/{uid}/friend_requests/{id}` | Pending friend requests | Read owner · **fully server-only** create/update/delete (`social.js`, `SEC-06`) — no legitimate client write path remains |
| `users/{uid}/coaching_requests/{clientUid}` | Coach link requests | Read uid or client · write client |
| `users/{uid}/block_list/{blockedId}` | Blocked users | Owner only |
| `users/{uid}/starred_messages/{messageId}` | Faz 2 §2.2 — personal chat-message bookmark. Doc id = messageId (idempotent star/unstar). Denormalized snapshot at star-time (`message_id`, `chat_id`, `sender_id`, `body`, `type`, `starred_at`) — mirrors `MessageReplyTo`'s precedent so it survives a later edit/delete of the original | Owner only (mirrors `block_list`'s rule exactly) |

### Global collections
| Path | Purpose | Access (rules) |
|---|---|---|
| `dishes/{id}` | Recipe/dish DB (seeded; TR + intl) | Read any auth · write admin only |
| `posts/{id}` | Community posts | Read any auth · create author · update: author (any field) or any authenticated user (engagement fields only — `likesCount`/`likedUserIds`/`recentLikers`/`reactions`/`commentsCount`, scalar counters ±1/write — `BLK-08`) · delete author. Content-length capped at rule level. |
| `posts/{id}/comments/{id}` | Post comments | Read any auth · create author · update: author (any field) or any authenticated user (`likesCount`/`reactions` only, ±1/write on `likesCount` — `BLK-08`) · delete author. Content-length capped. |
| `posts/{id}/likes|reactions/{userId}` | Like/reaction toggles | Read any auth · write owner |
| `posts/{id}/credit_progress/{docId}` (also `posts/{id}/comments/{id}/credit_progress/{docId}`) | Faz 5 §5.2 — fully internal bookkeeping for the received-engagement credit sources: `content_checked`/`content_eligible` (the cached content-quality/duplicate-content verdict, computed once and reused by every later reactor/liker AND by the weekly-group-contribution triggers), `counted_uids` (every distinct giver uid ever counted — grows only, never shrinks, so a remove-then-redo reaction/like toggle can never re-count), `weighted_score` (running progress toward the 10-reactor/5-liker threshold, after reciprocity/concentration down-weighting) | **Fully server-only** — `allow read, write: if false`, even for the content's own author |
| `chats/{id}` | Chat threads (private/group/gym — `system` was removed, Faz 2 §2.3: rendered by `chat_list_screen.dart` but never produced by any writer). `unreadCounts` increments are server-only (`onChatMessageCreated`, Faz 2 §2.1) — a participant may only zero their OWN key (`canMarkOwnUnreadZero`). Faz 2 §2.2 adds `pinnedMessageId`/`pinnedBy`/`pinnedAt` (camelCase, matching every sibling field on this doc) — **no rules change was needed**: `canUpdateChatMeta()` is a blocklist (only `participants`/`type`/`createdBy`/`unreadCounts` are protected), so these three were already writable/deletable by any participant. Locked in by a regression test (`rules.test.mjs`) rather than a rule change. **Faz 2 §2.3**: `groupId` (camelCase, new) pairs a chat 1:1 with a `community_groups/{groupId}` doc — set by `CommunityGroupService.createGroup` and `AdminService.approveGymApplication` (same id as the group itself), never by the pre-existing ad-hoc `createGroupChat` flow, which remains a plain participants-array chat with no group behind it. `isPublic` was removed (written by `createGroupChat`, read nowhere — dead). **Faz 2 §2.4 fix**: `onChatMessageCreated` used to derive push/unreadCounts recipients from THIS doc's `participants` array — which for a group-backed chat only ever holds the owner (never updated by `joinGroup`/`approveJoinRequest`/`redeemGroupInvite`/`kickMember`/`banMember`) — so every real member besides the owner silently never got a push or an `unreadCounts` key. The function now branches on `groupId`: when set, recipients come from `community_groups/{groupId}/members` (excluding `banned` ones) instead of `participants` — the same source `canAccessGroupChat()` already treats as authoritative for read access, so this closes the gap without touching the (deliberately client-immutable) `participants` field. Per-chat pin/archive/mute/delete state is NOT on this doc — see `users/{uid}/private/chat_prefs` below, kept off the shared doc so one participant's list-view preference doesn't re-deliver a query snapshot to every other participant/group member | Participants only, **OR** (when `groupId` is set) any active, non-banned member of that group — `canAccessGroupChat()`. A group-backed chat's `participants` array holds only the owner; the rest of the group's membership gets access via `groupId`, not this array (a public/gym group's full membership doesn't belong in a Firestore array field) |
| `users/{uid}/private/chat_prefs` | Faz 2 §2.4 — per-user, per-chat list-view state: `pinned_chats`/`archived_chats`/`muted_chats`/`deleted_chats`, each a map of `chatId → Timestamp` (key presence = on; value = when). `deleted_chats` is a soft, client-computed hide, not a tombstone: a chat reappears the moment its own `updatedAt` moves past the stored deletion instant (`ChatPrefsModel.isDeleted`) — the chat doc itself can never be deleted client-side (`allow delete: if false` above), so "delete" here honestly means "hide until new activity" | Covered by the existing generic `private/{docId}` wildcard rule — owner read/write, no rule change needed (regression-tested in `rules.test.mjs`, matching the `presence_prefs` precedent) |
| `users/{uid}/private/attribution_prefs` | Faz 6 §6.5 — `hidden: bool`, the user's one-tap "disconnect" from the gym-attribution banner on their own profile (`ReferralService.setAttributionHidden`). DISPLAY-only: never touches `gym_attributions/{uid}` itself (immutable by design — see that collection's row above), so the gym's already-earned/earning commission is completely unaffected either way | Covered by the existing generic `private/{docId}` wildcard rule — owner read/write, no rule change needed (same precedent as `chat_prefs`/`presence_prefs`) |
| `chats/{id}/messages/{id}` create, group-backed only | Additionally gated by `canPostInGroup()`: the sender must be an active, non-muted member, and — when the group's `announcement_only` is on — owner or a group-level `admin`. Reading and reacting (`canUpdateMessageEngagement`) are **not** gated by `announcement_only` — "diğerleri okur + tepki verir" | Same `isValidNewMessage()`/`canEditOwnMessage()`/`canUpdateMessageEngagement()` as every other chat — reused verbatim, not reinvented |
| `chats/{id}/messages/{id}` | **Message model v2** (Faz 2 §2.1): `id`, `senderId`, `type` (text/image/system/plan_offer/announcement), `body` (replaces old `text` — media never goes here anymore), `attachments[]` (`kind`/`url`/`mime`/`width`/`height`/`size`/`thumb_url`/`caption`), `reply_to`, `forwarded_from` (`hops`-counted), `reactions` (`{emoji: [uid]}`), `edited_at`, `is_deleted`, `deleted_for` (`'everyone'` or a per-uid array — "delete for me"), `delivered_to[]`/`read_by[]` (per-uid, not the old single global `isRead`), `mentions[]`, `server_timestamp` (serverTimestamp() — client clock is never trusted), `client_id`. **Faz 3 §3.5**: `plan_offer` — set only when `type == 'plan_offer'` (`{offer_id, template_id, template_name, target_calories, from_name}`, denormalized so both chat participants render an identical card even though `plan_offers` read is recipient-only); written exclusively by the `sendPlanOffer` Cloud Function via Admin SDK, which bypasses `isValidNewMessage`'s client-facing allowlist entirely — no client ever writes this field, so the allowlist was never extended for it. A deprecated `timestamp` field is written alongside `server_timestamp` as a compatibility mirror (same instant) purely so the existing `orderBy('timestamp')` message stream keeps surfacing old AND new docs without a backfill — see `ChatService.sendMessage`'s doc comment. **Faz 2 §2.2 deliberately did NOT drop the `timestamp` mirror**, despite that comment's original aspiration: `getMessagesPage`/`getChatMediaPage`/`getMessagesAround` (cursor pagination, media gallery, jump-to-date) all still order by `timestamp`, not `server_timestamp` — switching would silently exclude every pre-v2 message (no `server_timestamp` field at all) from history, pagination, and the gallery, the exact silent-exclusion class this same section already warns about for `markChatAsRead`. Safe to switch only after a real backfill migration writes `server_timestamp` onto every legacy doc (out of scope). **Migration discipline**: pre-v2 (6-field) docs are adapted entirely on the read path (`MessageModel.fromJson`) and never rewritten — see §10. | Participants only. Create requires the full v2 shape (`isValidNewMessage`) with an exhaustive field allowlist and a `server_timestamp == request.time` anti-spoof check; update is split between the sender's own 15-minute content-edit window (`body`/`edited_at`/`is_deleted`/`deleted_for`-as-`'everyone'`), any participant's engagement touches (`reactions`/`read_by`/`delivered_to`/`deleted_for`-as-array — "delete for me"), and — **Faz 2 §2.6**, group-backed chats only — a group owner/group-admin/site-admin's `canModeratorDeleteMessage()` takedown of ANOTHER member's message: `is_deleted`/`deleted_for`-as-`'everyone'` ONLY, no time window, `body` is deliberately left untouched in Firestore (never rendered once `is_deleted` is true, per `MessageModel.isDeletedFor`, but preserved for audit/appeal review rather than wiped like the sender's own delete). Content-length capped. |
| `signals/{id}` | Ephemeral social broadcasts (TTL via expiresAt) | Read any auth · create owner · delete owner. Content-length capped. |
| `community_groups/{id}` | **Unified groups** (Faz 2 §2.3 — P1 fields `name`/`description`/`city`/`district`/`cover_image_url`/`owner_uid`/`member_count`/`is_public`/`tags`/`created_at`/`updated_at`/`last_activity_at` unchanged; new: `chat_id` — the paired `chats/{chat_id}` doc, always == this doc's own id; `kind` (`public`\|`private`\|`gym`); `gym_id?`; `announcement_only`; `invite_enabled` (the invite CODE itself is never here — see `secrets/invite` below); `join_policy` (`open`\|`request`\|`invite`); `rules_text`; `pinned_message_id`. A `kind:'gym'` group + its owner membership + its paired chat are auto-created by `AdminService.approveGymApplication`, same batch, same id as the gym itself. **Faz 2 §2.5**: `activity_score`/`activity_updated_at` — recency-weighted engagement signal (messages×1 + posts×3 + comments×2 + new members×5 in the trailing 24h, each event exponentially decayed by age, 6h half-life — see `functions/groups.js: computeGroupActivityScores`'s header comment for the exact formula and why), written ONLY by that scheduled function (every 15 min, `is_public` groups only) — never client-computed, matching this session's `reputation_score`/`live_occupancy` server-authority pattern exactly (`touchesProtectedGroupFields()` blocks even the owner's otherwise-blanket update rule; `isAdmin()` stays exempt, consistent with every other protected-field check in this file) | Read any auth (discovery) · create: `owner_uid == auth.uid` **or** `isAdmin()` (the gym auto-create path runs under the approving admin's auth, not the gym owner's) · update: owner (not `activity_score`/`activity_updated_at`) /admin, or any member for counter-only fields (`canUpdateGroupCounters`) · delete: owner/admin |
| `community_groups/{id}/members/{uid}` | `role` (`owner`\|`admin`\|`moderator`\|`member` — `moderator` remains unassigned by any service method, same as before this change; `admin` is new and real, assignable via `CommunityGroupService.setMemberRole`), `muted_until?` (mute expiry, checked on every message create), `banned?` (kept — not deleted — so a banned uid can never self-recreate this doc) | Read any auth · create: self as `member` (only when `join_policy == 'open'`) or self as `owner` (only the group's real `owner_uid`), **or** owner/group-admin/site-admin adding someone else (never as `role: 'owner'` — no ownership-transfer path here) · update: owner/site-admin (any field) or a group-level `admin` (`muted_until`/`banned` ONLY — role changes stay owner-only) · delete: self (leave), or owner/group-admin/site-admin (kick). **Faz 2 §2.6**: a `muted_until`/`banned` update or a non-self delete (kick) by the owner/group-admin is ADDITIONALLY denied while `isModerationRateLimited()` (see `moderation/{autoId}` row) — `isAdmin()` and a member's own self-leave are exempt |
| `community_groups/{id}/join_requests/{uid}` | Doc id == requester's uid (idempotent re-request). `uid`, `display_name?`, `photo_url?`, `message?`, `status` (`pending`\|`approved`\|`declined`), `requested_at`, `responded_at?`, `responded_by?`. Approving does **not** itself grant membership — `CommunityGroupService.approveJoinRequest` writes the `members/{uid}` doc as a separate step in the same batch | Read: requester, owner, group-admin, site-admin · create: self, only when `join_policy == 'request'` · update (approve/decline): owner/group-admin/site-admin only, `uid` pinned · delete (withdraw): requester, owner/group-admin/site-admin |
| `community_groups/{id}/moderation/{autoId}` | Immutable log (mirrors `admin_audit`'s shape) — `target_uid`, `action` (`mute`\|`kick`\|`ban`\|`unmute`\|`unban`), `reason?`, `duration_minutes?`, `issued_by`, `created_at` | Create: owner/group-admin/site-admin, `issued_by` pinned to caller, **and** (owner/group-admin branch only — `isAdmin()` exempt) `!isModerationRateLimited()` — Faz 2 §2.6, see `rate_limits/{uid}` below · read: the `target_uid` themselves (transparency), or owner/group-admin/site-admin · no update/delete |
| `community_groups/{id}/secrets/invite` | The actual invite code string (`code`, `created_at`, `created_by`) — deliberately **not** a field on the parent doc (world-readable-to-any-authenticated-user), mirroring the gym QR-token fix (`gyms/{id}/private/qr_token`) and the user-PII split (`users/{uid}/private/account`): a rule can't hide one field of an otherwise-readable document, so a redeemable secret can't live there | Read/write: owner/group-admin/site-admin only |
| `community_groups/{id}/weekly_contributions/{weekKey}/members/{uid}` | Faz 5 §5.2 — per-member weekly contribution score for the group-contribution credit source. `weekKey` = that week's Monday's LOCAL (Turkey, UTC+3) calendar date (`YYYY-MM-DD`, NOT an ISO week number — deliberately simpler, no year-boundary edge cases, see `engagement_credit_logic.js`'s `localWeekKey`). `score` incremented by dedicated onCreate triggers on group-scoped chat messages (×1), posts (×3), comments (×2) — same weights `computeGroupActivityScores` already uses, as a flat weekly sum instead of a decayed "hot right now" score. Read by `awardWeeklyGroupTop3` (scheduled, every 24h, always reprocesses the most recently completed week — idempotent via the ledger, so exact cron timing doesn't matter) AND, as of Faz 5 §5.3, `computeGroupContributionLeaderboards` (scheduled, every 15 min, reads the CURRENT still-accumulating week for live display — see the row directly below) | **Fully server-only** — `allow read, write: if false`, even for the group owner |
| `community_groups/{id}/weekly_leaderboard/{weekKey}` | Faz 5 §5.3 — the denormalized public summary the row above's own comment promised ("a future leaderboard UI would read a denormalized public summary, never this"). One doc per (group, week): `entries: [{uid, display_name, photo_url, score, rank}]`, top 10, recomputed every 15 min by `computeGroupContributionLeaderboards` (`functions/engagement_credit.js`) — mirrors `computeGroupActivityScores`'s cadence (`functions/groups.js`). Consumed by `CommunityGroupService.getWeeklyContributionLeaderboardStream` → `GroupLeaderboardScreen` | Read: any member of THIS group (`isGroupMember(groupId)`) — narrower than `community_weekly_xp` below, because unlike XP a group's contribution activity isn't otherwise public · **write: if false** |
| `group_invites/{code}` | Top-level, doc id == the code (mirrors `referrals/{code}`'s O(1) lookup — no index, no query). `group_id`, `is_active`, `created_by`, `created_at`. The **reverse** (code → group_id) index the `redeemGroupInvite` callable uses; a client never inspects this doc — the callable validates server-side and returns a preview in its response | **Read: `if false`, unconditionally** (even for the group's own owner — generation writes it, nothing ever reads it back through rules) · create/update (regenerate/deactivate): owner/group-admin of the group named in the doc · no delete |
| `notifications/{uid}/items/{id}` | **Canonical notifications path** (`BLK-03`). Fans out to push via `onInAppNotificationCreated`. Schema: `type` (enum name), `isRead`, `timestamp`, `actorUid?`, `actorName?`, `actorPhotoUrl?`, `relatedId?`, `metadata?` — or legacy `title`+`body` for admin free-text messages (no `actorUid`/`metadata` on those, by design — see `NotificationModel.isLegacy`) | Read/update(mark-read)/delete: owner · **create: server-only** (`notifications.js`, `social.js`, `economy.js`, `index.js` broadcast — all Admin SDK) |
| `reports/{id}` | Moderation reports | Create author only, **and** `!isReportRateLimited()` (Faz 2 §2.6) · read/update **admin backend only** |
| `privacy_requests/{id}` | DSAR requests (uid, email, type, message, status, admin_note) | Create owner · read owner/admin · update admin · no delete |
| `moderation_appeals/{id}` | Faz 2 §2.6 ("itiraz yolu") — mirrors `privacy_requests`' shape exactly. Doc id == the SOURCE `community_groups/{groupId}/moderation/{autoId}` entry's own id (at most one appeal per action — a second `set()` by the same uid is a Firestore `update`, denied below, not a `create`). `uid` (appellant, must equal the referenced action's `target_uid`), `group_id`, `group_name` (denormalized), `action` (`mute`\|`kick`\|`ban` — the reversible ones; `unmute`/`unban` are not appealable), `message`, `status` (`pending`\|`upheld`\|`denied`), `created_at`, `resolved_at?`, `resolved_by?`, `admin_note?`. `AdminService.resolveModerationAppeal` ALSO reverses a `mute`/`ban` via the existing `unmuteMember`/`unbanMember` when marked `upheld`. **Faz 5 §5.2**: this SAME collection/lifecycle is reused for a second appeal kind, `action == 'credit_restriction'` — `group_id`/`group_name` are empty strings and `action` on `ModerationAppealModel` reads back as a meaningless placeholder for it (see that model's doc comment; new code branches on `rawAction`/`isCreditRestriction` instead). Its create-rule branch cross-checks `users/{callerUid}/credit_moderation/{this doc's own id}.action == 'restrict'` instead of a group's moderation log — no `target_uid` field needed since that path is already self-scoped to the caller. `AdminService.resolveModerationAppeal` reverses an upheld credit-restriction appeal via `_liftCreditRestriction` (writes a `lift` log entry + clears `is_shadow_restricted` AND resets `flag_count` to 0 — a genuine clean slate) | Create: `uid == request.auth.uid`, content-capped (`message` ≤ 2000 chars), `!isAppealRateLimited()`, **and** either (`action in [mute,kick,ban]` + the `community_groups` moderation-log cross-check) **or** (`action == 'credit_restriction'` + the `credit_moderation` cross-check) · read: appellant or admin · update: admin only · no delete |
| `rate_limits/{uid}` | Faz 2 §2.6 — server-only sliding-window ledger (`functions/rate_limit.js`), one doc per uid holding independent field-pairs per abuse-throttled kind: `report_window_start`/`report_count`/`report_locked_until`, `moderation_window_start`/`moderation_count`/`moderation_locked_until`, `appeal_window_start`/`appeal_count`/`appeal_locked_until`. The `*_locked_until` fields are what `isReportRateLimited()`/`isModerationRateLimited()`/`isAppealRateLimited()` check (via `get()`) before allowing the corresponding collection's client create — mirrors `presence_notify_log`/`processed_purchases`: internal bookkeeping nobody reads back through the client SDK | **Fully server-only** — `allow read, write: if false` unconditionally, even for the doc's own uid |
| `challenges/{id}` | Challenges (legacy; mostly sunset) | Read any auth · create/own |
| `referrals/{code}` | Referral codes — `owner_uid`, `type` (`user`\|`coach_vanity`\|`gym`, default `user`), `used_by_uids[]`, `max_uses`, `created_at`. **Faz 6 §6.1**: `type: 'gym'` codes additionally carry `gym_id` (which gym this poster/QR belongs to) and optional free text `campaign`/`location_note` (capped 80/200 chars — "front desk" vs "Coach Ahmet's Instagram" vs "March campaign" in the gym's own management list) and optional `printed_at` (server-timestamped, best-effort "owner actually exported this poster" marker, not a rigorous print receipt). Gym codes default to `max_uses: 5000`, not the personal-code default of 10 — a poster gets scanned far more than a 1:1 share; see `ReferralService.gymDefaultMaxUses`'s doc comment for why that's a real ceiling, not literally "unlimited" (`used_by_uids` is a plain array on this SAME doc, bounded by Firestore's 1 MiB document size). **Faz 6 §6.3/§6.4**: a code is now genuinely reachable and redeemable — `DeepLinkService` routes an `/invite/{code}` Universal Link with no signed-in session into onboarding (staged in `OnboardingProvider` + on-device via `ReferralService.savePendingCode`, 7-day TTL), the new onboarding referral step previews it pre-auth via the read-only `previewReferralCode` callable (see below), and `OnboardingCompletion.finalizeAndRoute` redeems it via `applyReferral` the moment a real uid exists. **Faz 6 §6.5/§6.6**: `applyReferral` now DOES special-case `type=='gym'` — instead of the generic 7-day-trial + ₺5-commission grant (still exactly what a personal/coach-vanity code gets), a gym code writes a `gym_attributions/{uid}` doc (see new row below), bumps `gyms/{gym_id}.attributed_member_count`, and notifies the gym owner (`NotificationType.gymAttribution`, no actor identity ever attached) — no trial premium is granted to either party for a gym code, since a poster can be scanned up to `max_uses: 5000` times | Read any auth · create: owner, and for `type=='gym'` ALSO cross-checked against `gyms/{gym_id}.owner_uid` via `get()` (a self-asserted `owner_uid` alone would otherwise let anyone stamp someone else's `gym_id` on their own code) · update: owner/admin only, `owner_uid`/`type`/`gym_id` all pinned immutable, `printed_at` (when touched) must equal the server timestamp — mirrors `gyms/{gymId}/members`' `last_check_in` |
| `gym_attributions/{uid}` | **Faz 6 §6.5/§6.6** — server-written, immutable record of which gym's invite code a user redeemed: `gym_id`, `code`, `coach_uid?`, `campaign?`, `attributed_at`, `source` (`'deep_link'\|'manual_entry'\|'in_app'`), `first_premium_at?` (set once, on the user's first real premium purchase), `lifetime_commission_try` (accrues on EVERY qualifying purchase, unlike `first_premium_at`). Written only by `applyReferral`'s gym branch and `maybeAwardGymCommission` (both `functions/economy.js`, Admin SDK). At most one per user, ever — gated by the same `referral_used` one-code-per-account marker `applyReferral` already enforced. Backs the user-facing "you signed up via {gym}" profile transparency (`ReferralService.getMyAttribution`) — the gym's own funnel report reads its aggregate `gyms/{id}.attributed_member_count`/`attributed_premium_count` counters instead of this collection (deliberate: individual identity never reaches the gym, not even via a direct doc read). Covered by both GDPR/KVKK data-subject-rights paths (`DataExportService._collectAll` #27, `deleteUserAccount` step 2 — the gym's own already-recorded `commissions` ledger entry is a separate doc under THEIR subtree and is untouched by either) | Read: **owner only** (the attributed user) — deliberately NOT the gym owner · **create/update/delete: if false**, always (fully server-only) |
| `gyms/{id}` | Gym profiles. `live_occupancy` (Faz 1 §1.4/1.5) is a server-maintained counter — the owner's otherwise-blanket update rule explicitly excludes it (`touchesProtectedGymFields()`). **Faz 6 §6.5/§6.6** added two more counters to that same protected set: `attributed_member_count` (bumped by `applyReferral`'s gym branch on every attribution) and `attributed_premium_count` (bumped by `maybeAwardGymCommission` on a user's first-ever premium conversion, never again on renewal). Faz 2 §2.3: approval also creates a paired `community_groups/{id}` doc (`kind:'gym'`, same id) and `chats/{id}` doc (`type:'gym'`) — see that row above | Read any auth · create owner · update owner/admin (owner CANNOT touch `live_occupancy`/`attributed_member_count`/`attributed_premium_count`) · delete owner |
| `gyms/{id}/members/{id}` | Gym members | Read: owner, the member's own doc, **or (Faz 5 §5.3) any fellow member of the same gym** (`isGymMember(gymId)`) — closes a gap the original audit named but Faz 0 §0.1 never actually fixed: read was owner-or-self ONLY, so `GymLeaderboardService`'s own unfiltered `.collection('members').limit(200)` list query was silently rejected for every non-owner caller. Write: owner (self-join/self-leave/self-check-in handled by the dedicated rules in `firestore.rules`, not this summary) |
| `gyms/{id}/posts/{id}` (+ `/comments`) | Gym community feed | Read any auth · create author · update: author/gym-owner (any field) or any authenticated user (`like_count`/`liked_by_uids`/`comment_count` only, ±1/write on the counters — `BLK-08`) · delete author/owner |
| `gyms/{id}/checkins/{id}` | QR/GPS/manual/**geofence** check-ins. `geofence` (Faz 1 §1.5) is server-only (`recordPresenceEvent`, Admin SDK) — deliberately absent from the client create-rule allowlist below | Read owner/member · create self, `method in ['qr','gps','manual']` only · no update/delete |
| `gyms/{id}/presence/{uid}` | Faz 1 §1.4: live "currently inside" doc — only exists while the member is inside. No raw lat/lng ever (`entered_at`, `source`, `last_seen_at`, `expires_at`, denormalized `display_name`/`photo_url`). Written only by `recordPresenceEvent` | Read owner/self · **write: if false** (server only) |
| `gyms/{id}/presence_sessions/{id}` | Faz 1 §1.4: closed, immutable visit record (`uid`, `entered_at`, `exited_at`, `duration_minutes`, `source`, `ended_by`). Backs the leaderboard/gym-wars/analytics with server-verified visits | Read owner/self (via `resource.data.uid`) · **create/update/delete: if false always** |
| `gyms/{id}/presence_notify_log/{receiverUid_arrivingUid_dayKey}` | Faz 1 §1.7: dedup log so `onGymPresenceCreated` sends at most one "friend at gym" push per (receiver, friend, gym) per day. Purely internal — nothing reads it back | **Fully server-only** (no client read or write) |
| `gyms/{id}/member_summaries/{uid}` | Faz 4 §4.2 — server-generated, tier-gated AI or template progress narrative + the tier-appropriate structured fields it was built from (`tier`, `method` `'ai'`\|`'template'`, `narrative`, `fields`, `generated_at`, `generated_by`, `expires_at` — 7-day TTL). Written only by `generateMemberProgressSummary` (`functions/summaries.js`), which re-derives gym ownership + real membership server-side and rejects outright at `progress_sharing` tier 0. Swept by `expireMemberProgressSummaries` (every 60 min) past `expires_at`; deleted immediately (not on that schedule) by `onProgressSharingWrite` the moment the member's tier for this scope changes at all | Read: gym owner or the member themself · **write: if false** (server only) |
| `gyms/{id}/progress_share_invites/{memberUid}` | Faz 4 §4.3 — dedup receipt for the tier-0 empty state's "send a progress-sharing invite" button (`sendProgressShareInvite`, `functions/summaries.js`). The doc EXISTING is the "already invited, ever" state — created once with `.create()` (fails if present), so this fires at most once per (gym, member) pair, never repeated automatically | Read: gym owner · **write: if false** (server only) |
| `gym_wars/{id}` | Gym vs gym competition | Read any auth · create challenger · update challenger |
| `gym_applications/{id}` | Gym owner applications | Read applicant/admin · create applicant · update admin |
| `coach_profiles/{uid}` | Coach public profiles | Read any auth · create owner · update owner/admin |
| `coach_profiles/{uid}/clients/{clientUid}` | Coach↔client links | Read coach/client · write coach/admin |
| `coach_profiles/{uid}/reviews/{reviewerUid}` | Coach reviews (immutable) | Read any auth · create reviewer (rating 1–5) · no update/delete |
| `coach_profiles/{uid}/member_summaries/{clientUid}` | Faz 4 §4.2 — coach-scope equivalent of `gyms/{id}/member_summaries` above (same shape, same TTL/invalidation). Authority re-derivation requires `clients/{clientUid}.status == 'active'`, not merely a `clients` doc existing (a `pending`/`ended` relationship never qualifies) | Read: the coach or the client themself · **write: if false** (server only) |
| `coach_profiles/{uid}/progress_share_invites/{memberUid}` | Faz 4 §4.3 — coach-scope equivalent of `gyms/{id}/progress_share_invites` above; same one-time-ever dedup receipt | Read: the coach · **write: if false** (server only) |
| `coach_applications/{id}` | Coach applications | Read applicant/admin · create applicant · update admin |
| `programs/{id}` (+ `/weeks/{id}/sessions`) | Marketplace programs | Read any auth · create coach/demo · update coach/admin · delete coach |
| `meal_plan_templates/{id}` | Faz 3 §3.2 — reusable weekly plan authored by a gym/coach/admin, independent of any one member's `meal_plans/current`; sent via `plan_offers` (above) as an immutable copy. `usage_count` ("N üyeye gönderildi") is server-only, bumped by `sendPlanOffer`. `share_scope` (`private`\|`gym`\|`link`\|`marketplace`) + `is_public` gate read; only `private`/`gym`/`is_public` currently have a distinct read mechanism — `link`/`marketplace` are accepted as valid data but have no access mechanism of their own yet (likely a secret-token pattern, mirroring `community_groups/secrets/invite`). **Still not decided as of §3.3** (`MealPlanTemplateService`/the template builder UI): the creator screen's share-scope picker deliberately only offers `private`/`gym` + the independent `is_public` toggle — exactly the values that already have a real read mechanism — rather than surface `link`/`marketplace` controls for a mechanism that doesn't exist yet | Read: author or admin always · `is_public == true` to anyone authenticated · `share_scope == 'gym'` to that `gym_id`'s own members (`gyms/{id}/members/{uid}` `exists()` check) · create/update/delete: author only (`isAdmin()` an additional override, consistent with every other collection in this file) · `usage_count` excluded from the author's own update (`touchesProtectedTemplateFields`) · `name`/`description` content-capped |
| `squads/{id}` | Streak Squads | Read member · create creator · update member · delete creator |
| `ai_credits/{uid}` | Server AI ledger — daily quota (used_today, reset_at, is_premium, bonus_credits) **+ per-user lifetime totals** (lifetime_requests, lifetime_tokens, lifetime_cost_usd, lifetime_by_type). Faz 5 §5.2's received-engagement credit lands in `.bonus` here too, via the same `grantBonusCredits` writer purchase top-ups already use — no second currency | Owner read · **server/admin write only** (server-authoritative; client cannot mint credits) |
| `credit_restrictions/{uid}` | Faz 5 §5.2 — shadow-restriction state: `is_shadow_restricted`, `reason` (`reciprocity_or_concentration`\|`duplicate_content`\|`manual`), `flag_count` (rolling suspicion counter — crossing `AUTO_RESTRICT_FLAG_THRESHOLD` (5) auto-sets `is_shadow_restricted`), `latest_entry_id` (the matching `credit_moderation` log entry, used as the appeal doc's own id), `restricted_at`/`lifted_at`/`updated_at`. Being restricted has **zero effect on content visibility** — it only stops THIS account's own received-engagement credit from accumulating | Owner read (the appeal path needs to show them) · **write: admin only** (real writer is `bumpSuspicionFlag`/`AdminService._liftCreditRestriction`, both effectively server-authoritative) |
| `reciprocity_pairs/{pairKey}` | Faz 5 §5.2 — bidirectional interaction counts between two uids, `pairKey` = the two uids sorted and joined (`"uidLow_uidHigh"`). `uid_low`, `uid_high`, `low_to_high`, `high_to_low`, `updated_at`. Feeds `reciprocityWeight` (`engagement_credit_logic.js`) — a pair with enough history (≥4 total interactions) that's roughly balanced both ways (ratio ≥0.5) gets its NEW interactions down-weighted to 0.2× toward any credit threshold. Never decremented — a removed reaction/like still reflects that the interaction happened | **Fully server-only** — `allow read, write: if false` |
| `engagement_diversity/{uid}` | Faz 5 §5.2 — a RECEIVER's rolling window (last 20) of distinct-engager uids they've gotten credit-worthy engagement from. Feeds `concentrationWeight` — once the window is full, if ≤3 distinct uids account for the whole thing (a "closed cluster" mostly engaging with just this one account, or with each other), further engagement from that same small set is down-weighted 0.2× — the mechanism that catches coordinated rings a purely pairwise check would miss | **Fully server-only** — `allow read, write: if false` |
| `community_weekly_xp/{weekKey}/members/{uid}` | Faz 5 §5.3 — denormalized per-week XP rollup (`xp`, `display_name`, `photo_url`, `updated_at`) — THIS WEEK's XP only, not the lifetime total on `users/{uid}.xp`. Bumped transactionally by `awardXp` (`functions/progress.js`) inside the SAME transaction as every XP award of any kind — free (the transaction already has the user's `displayName`/`photoURL` in hand from its own read), no separate sweep needed. `weekKey` = `LocalWeek`/`localWeekKey`'s Monday date string, same format as every other Faz 5 §5.2/§5.3 week key. Backs `LeaderboardService.getWeeklyXpLeaderboardStream` (community-wide) AND, via a chunked `whereIn` lookup keyed by the gym's own member uids, `GymLeaderboardService.getWeeklyLeaderboardStream` (in-gym) — one collection serves both | Read: **any authenticated user** — deliberately flat, not narrower, because `xp` is already a PUBLIC field on `users/{uid}` (Faz 0 §0.2's field-allowlist); a weekly rollup of an already-public number carries no additional sensitivity · write: `if false` |
| `ai_usage_logs/{id}` | Per-request AI usage/cost log written by `aiProxy` (uid, type, model, prompt/completion/total_tokens, cost_usd, unpriced, created_at) | **Server write only** · admin read |
| `ai_usage_stats/{doc}` | Aggregated AI usage rollups: `global` + `day_YYYY-MM-DD` buckets (total cost/requests/tokens, by_model, by_type) | **Server write only** · admin read |
| `entitlements/{uid}` | Premium entitlement (tier, expiry) — source of truth for paid access; server mirrors `subscription_tier` to the user doc | Owner read · **server/admin write only** |
| `processed_purchases/{id}` | Purchase-token replay guard (dedupes IAP tokens so a receipt can't be redeemed twice) | **Fully server-only** (no client read or write) |
| `admin_roles/{uid}` | The real admin gate (`is_admin: true`) — mirrored onto a Firebase Auth custom claim by `syncAdminClaim` (`functions/admin.js`) so the client can verify it via the ID token. Console/Admin-SDK provisioned only — see the runbook in `docs/SECURITY.md` §4 | Owner or admin read · **write: false unconditionally**, even for an admin |
| `admin_audit/{id}` | Append-only admin action log | Create admin · read admin · no update/delete |
| `admin_config/{doc}` | Feature flags, maintenance, AI model, blocked keywords | Admin only |
| `app_config/global` | Remote App Config — `ai` (models/limits/toggles), `version` (min/latest per platform, force_update, store URLs, update_message i18n), `maintenance`, `announcement`, `features` (kill-switches), `rollout`, `limits`, `endpoints.ai_proxy_url`. **No secrets.** | **Public read** · admin write |
| `settings/content_filter` | Blocked-keyword list mirrored from admin config for client moderation pre-screen | **Public read** · admin write |
| `broadcasts/{id}` | Admin broadcast messages | Admin create/read/update |
| `seeds/{doc}` | Idempotent seed gates (e.g. `demo.demo_programs_v1`) | Auth read/write |
| `logs/{uid}` | Activity/login audit | Owner |
| `failed_login_attempts/{id}` | Brute-force tracking | Create any · read/update/delete admin |
| `settings/{doc}` | App config (read-only) | Read any auth · no write |

---

## 2. Models (`lib/core/models/`, 62 files)

### User & profile
- **user_model.dart** `UserModel` → `users/{uid}`. Fields: uid, email, displayName, photoURL,
  isOnline, onboardingCompleted, createdAt, lastLoginAt, onboardingData (nested public map),
  subscriptionTier (free/premium/pro), userRoles[], gymMemberships, isPrivate (`is_private`).
  `fromFirestore`, `copyWith`, `withPrivateNutrition()`, `hasRole(UserRole)`.
- **user_nutrition_profile.dart** `UserNutritionProfile` — typed view over onboarding_data +
  private nutrition (gender, birthDate, heightCm, weightKg, activityLevel, primaryGoals,
  allergyIds, dietaryRestrictionIds, dislikedFoodKeys, avoidIngredients, cookingLevel,
  kitchenEquipmentIds, lifestyleProfile, mealSchedule). View-only.
- **user_profile_model.dart** `UserProfile` — composite (UserModel + login history + activity).
- **user_activity_model.dart** `UserActivityItem`, **login_history_model.dart** `LoginHistoryItem`,
  **user_logs_model.dart** `UserLogs` → `logs/{uid}`.
- **subscription_model.dart** `SubscriptionTier {free,premium,pro}` + `Entitlements` (derived
  feature flags: isPaid, isPremiumOrAbove, isPro, weeklyMealPlanGenerations, …). **Faz 5 §5.4**:
  `groupChat` corrected from `premiumOrAbove` to `true` (Faz 2 shipped group chat as free for every
  tier; the old value was never enforced and would have been a regression, not a paywall, if wired
  literally) — all 8 gates now have a real call site, see [`PREMIUM.md`](PREMIUM.md) §1.

### Food & nutrition
- **dish_model.dart** `DishModel` → `dishes/{id}`. name/nameEn, descriptions, imageUrl, calories,
  protein/carbs/fat/fiber, category, tags, mealType, prep/cookTime, difficulty, servings,
  ingredients[], instructions[]. `fromFirestore`, `fromJson`, `toJson`, `toRecipe()`.
  Categories (Faz 3 §3.6, reconciled against the actual seed data — the doc comment used to claim
  red_meat/vegan/diet, none of which are ever written): breakfast, chicken, fish, meat, sport,
  turkish_classic, vegetarian, veggie.
- **ingredient_model.dart** `Ingredient` (name, amount, unit, calories) — nested in dishes.
- **recipe_model.dart** `Recipe` — UI model (title, imageUrl, times, servings, difficulty,
  macros{}, ingredients[], instructions[], tags[]). Not Firestore-mapped.
- **food_log_model.dart** `FoodLog` → `users/{uid}/food_logs/{id}` (mealType, dishId, dishName,
  calories, macros, loggedAt, date=YYYY-MM-DD) + `NutritionTotals` + `sumLogs()`.
- **meal_plan_model.dart** `MealPlan` (logical) · **weekly_meal_plan_model.dart**
  `WeeklyMealPlanModel` → `users/{uid}/meal_plans/current` (days[DayMealPlan], totals,
  generationPromptHash, isAiGenerated, aiModel, expiresAt). Faz 3 §3.4 adds `totalFiber`/
  `avgDailyFiber` to `WeeklyMealPlanModel` and `fiber` to `DayMealPlan` — optional, defaulted to 0
  (not `required`), so every pre-existing doc and the AI-generation call site (which still doesn't
  source fiber from the LLM response) parse/construct unchanged; only a post-swap recompute
  populates a real value.
- **meal_entry_model.dart** `MealEntry` (Faz 3 §3.2) — `{dish_id?, custom_food?, portion, meal_type,
  note}`. Replaces the bare `Map<String,String>` (mealType → dishId) shape for template days, which
  can't represent portion, free-text food, a per-meal note, or more than one entry per meal type.
  **No Firebase import** — read by `PlanNutritionCalculator` (below), which must stay
  Firebase-independent.
- **meal_plan_template_model.dart** `MealPlanTemplate` → `meal_plan_templates/{id}` (author_uid/
  author_type/gym_id?, name, description, goal, target_calories, target_macros{}, tags[],
  days[TemplateDay], version, parent_template_id?, is_public, share_scope, usage_count, created_at,
  updated_at) + `TemplateDay` (day_index 0-6, meals[MealEntry] — date-less, unlike `DayMealPlan`,
  since a template only becomes a dated plan on offer-accept).
- **plan_offer_model.dart** `PlanOffer` → `users/{uid}/plan_offers/{id}` (template_id,
  template_snapshot — an immutable copy, not a live reference — from_uid, from_type, from_name,
  message?, status, created_at, expires_at, responded_at?). `isPending`/`isAccepted`/`isDeclined`/
  `isExpired` (the last one also treats a past-`expires_at` `pending` offer as expired client-side,
  ahead of the server-side expiry sweep that flips `status`).

### Fitness
- **exercise_log_model.dart** `ExerciseLog` + `ExerciseType` (MET table: running 9.8 … yoga 2.5).
  `estimateCalories(weightKg, minutes)`.
- **checkin_model.dart** `CheckInModel` → `gyms/{id}/checkins/{id}` (uid, method qr/gps/manual/geofence).

### Gym
- **gym_model.dart** `GymModel` → `gyms/{id}` (ownerUid, name, address, city, district, isPublic,
  memberCount, subscriptionTier, tags, lat/lng, checkInRadius, qrToken+expiry, brandColor,
  isVerified). **gym_member_model.dart**, **gym_post_model.dart** (`GymPostModel`+`GymCommentModel`),
  **gym_war_model.dart**, **gym_analytics_model.dart** (computed), **gym_application_model.dart**.
  Faz 1: **gym_presence_model.dart** `GymPresenceModel` → `gyms/{id}/presence/{uid}` (read-only —
  server-written by `recordPresenceEvent`), **presence_session_model.dart** `PresenceSessionModel` →
  `gyms/{id}/presence_sessions/{id}` (read-only, immutable), **gym_presence_prefs_model.dart**
  `GymPresencePrefsModel` → `users/{uid}/private/presence_prefs`.

### Coach & programs
- **coach_profile_model.dart** `CoachProfileModel` → `coach_profiles/{uid}` (bio, specializations,
  certifications, isAcceptingClients, vanityCode, clientCount, hourlyRate, city, district,
  avgRating, ratingCount, isVerified).
- **coach_client_model.dart** `CoachClientModel`, **coach_review_model.dart** `CoachReviewModel`
  (immutable, transaction-updates coach avgRating), **coach_application_model.dart**.
- **program_model.dart** `ProgramModel` → `programs/{id}` (coach info, difficulty, category,
  durationWeeks, sessionsPerWeek, price, status draft/pending/approved/rejected, enrollmentCount,
  rating). **program_content_model.dart** `ProgramSessionModel`, **program_enrollment_model.dart**
  `ProgramEnrollmentModel` (currentWeek, progressPercent).

### Social
- **community_post.dart** `CommunityPost`+`CommunityComment`+`CommunityUser` → `posts/**`
  (PostType text/recipe/progress/meal, reactions{}, likedByUids[], tags, isEdited).
- **signal_model.dart** `SignalModel` (TTL), **streak_squad_model.dart** `StreakSquadModel`,
  **follow_model.dart** `FollowModel`.
- **chat_model.dart** `ChatModel` (participants, lastMessage, unreadCounts, type, typingUsers,
  **Faz 2 §2.2**: `pinnedMessageId`/`pinnedBy`/`pinnedAt` — single pinned message per chat).
- **message_model.dart** `MessageModel` — **v2 schema (Faz 2 §2.1)**: senderId, type
  (`MessageType`: text/image/system/planOffer/announcement — wire values are snake_case, e.g.
  `plan_offer`), body, attachments (`MessageAttachment`), replyTo (`MessageReplyTo`), forwardedFrom
  (`MessageForwardedFrom`), reactions (`Map<String, List<String>>`), editedAt, isDeleted, deletedFor
  (`'everyone'` or `List<String>`), deliveredTo/readBy (per-uid), mentions (`MessageMention`),
  serverTimestamp, clientId. **Faz 3 §3.5**: `planOfferInfo` (`MessagePlanOfferInfo` —
  offerId/templateId/templateName/targetCalories/fromName), set only for `type == planOffer`; a
  denormalized snapshot taken at send time (`sendPlanOffer`), not a live reference, for the same
  reason `MessageReplyTo` already is one — `plan_offers` read is recipient-only, so the sender's own
  copy of the chat could never re-fetch it live. `isReadBy(uid)`/`isDeliveredTo(uid)`/`isDeletedFor(uid)` are the
  per-recipient query helpers. `fromJson` is a forward-compatible adapter for the old 6-field shape
  (`text`→`body`, `timestamp`→`serverTimestamp`, single global `isRead`→`isReadBy`'s legacy
  fallback) — old docs are read-adapted, never rewritten (§10).
- **starred_message_model.dart** `StarredMessageModel` (Faz 2 §2.2) → `users/{uid}/starred_messages/
  {messageId}`. Denormalized snapshot (messageId, chatId, senderId, body, type, starredAt) taken at
  star-time — survives a later edit/delete of the original, mirroring `MessageReplyTo`'s precedent.
- **notification_model.dart** `NotificationModel` (structured: type enum, actorUid/Name/PhotoUrl,
  relatedId, metadata; legacy title/body fallback). `copyWithRead()`. **Faz 3 §3.5** adds
  `planOfferReceived` (recipient, on send — `metadata.templateName`) and `planOfferDeclined` (the
  original sender, on decline only — `metadata.reason` optional); both follow `friendAtGym`'s exact
  precedent (§1.7) for wiring a new type end-to-end (enum value, `NotificationPresenter` switch cases,
  `writeNotification` call site).

### Commerce & analytics
- **commission_model.dart** `CommissionModel` (referral/coachSession/programSale/**gymPremiumShare**,
  Faz 6 §6.6; pending/approved/paid/rejected) · **earnings_summary_model.dart** `EarningsSummaryModel`
  (computed). **gym_attribution_model.dart** `GymAttributionModel` (Faz 6 §6.5) — read-only view over
  `gym_attributions/{uid}` (above).
- **ai_credit_model.dart** `AiCreditModel` (used, isPremium, resetAt, bonus; freeDailyLimit=2,
  premiumDailyLimit=20; remaining/isExhausted/usagePercent/minutesUntilReset).
- **ai_insight_model.dart** `AiInsightModel` (accountability/riskAlert/projection/tip; riskLevel).
- **consent_model.dart** `ConsentModel` + `ConsentPurpose` enum (healthData, location, aiProcessing,
  crossBorderTransfer, analytics, notifications, marketing) → `users/{uid}/consents/{docId}`. Fields:
  granted, policyVersion, updatedAt. `isUnset`, `isStale` (granted vs `kLegalPolicyVersion`).
  Const `kLegalPolicyVersion` — bump on material legal-text change to trigger re-consent.
- **privacy_request_model.dart** `PrivacyRequestModel` + `PrivacyRequestType` (access, rectification,
  erasure, restriction, objection, portability, withdrawConsent, other) + `PrivacyRequestStatus`
  (pending/inProgress/resolved/rejected) → `privacy_requests/{id}` (DSAR channel).
- **moderation_appeal_model.dart** `ModerationAppealModel` + `ModerationAppealStatus`
  (pending/upheld/denied) → `moderation_appeals/{id}` (Faz 2 §2.6 — mirrors `PrivacyRequestModel`'s
  shape; `action` reuses `community_group_model.dart`'s `GroupModerationAction` enum).
- **leaderboard_entry_model.dart** `LeaderboardEntryModel` (computed) ·
  **report_model.dart** `ReportModel` → `reports/{id}` · **analytics_event.dart** `AnalyticsEvent`.

---

## 3. Reference Data (`lib/core/data/`)
- **dish_data.dart** — ~3,900 lines; 100 TR/intl dishes in batches (meat, fish, breakfast, veggie,
  diet, sport, turkish_classic, snack). Every `id` is unique and enforced by `test/dish_data_test.dart`
  — Faz 3 §3.6 found and fixed 5 ids each silently shared by 2-3 dishes (7 entries total), which
  overwrote each other down to 68 live Firestore docs from 75 source entries. Snack pool is 28 (was
  3 pre-§3.6 — the template builder's 7 weekly snack slots were repeating 1-of-3 constantly).
  Seeded into `dishes/` by `DishSeederService.seedIfEmpty()` — upserts whatever's missing from
  Firestore (a `count()` check first, so steady-state cost stays ~1 read); no longer a one-shot
  "only if the whole collection is empty" gate, which used to mean new dishes added here never
  reached an already-seeded environment automatically.
- **turkish_locations.dart** — all 81 provinces + full district lists (~1,100 districts). Powers
  city/district filters in gym & coach discovery.

## 4. Repositories (`lib/core/repositories/`) — in-memory caches
- **DishRepository** — singleton dish cache (getDishById, prefetch, preload, snapshot; test-mode aware).
- **FoodLogRepository** — todayLogsStream, logMeal/logRecipe, removeLog, getWeeklyLogs.
- **MealPlanRepository** — meal plan CRUD + generation caching.
- **ShoppingRepository** — shopping list (favorites → lists).

---

## 5. Composite Indexes (`firestore.indexes.json`, ~88)

Add an index here for **every new query shape** (`where` + `orderBy` combos). Current families:

- **posts**: createdAt DESC · authorId+timestamp DESC · tags(array)+timestamp DESC ·
  is_announcement+created_at DESC (collection-group)
- **signals**: expiresAt ASC + createdAt DESC
- **messages**: plain `orderBy('timestamp')` (live stream, `getMessagesPage` pagination,
  `getMessagesAround` jump-to-date) needs nothing — single-field queries are auto-indexed (Faz 2
  §2.1 removed the old dead `createdAt` collection-group entry, which indexed a field no message doc
  has ever written). **One composite IS needed**: `type ASC, timestamp DESC` (Faz 2 §2.2,
  `ChatService.getChatMediaPage` — the media-gallery query, `where('type','==','image')
  .orderBy('timestamp')`, mixes an equality filter with an `orderBy` on a different field, which
  Firestore never auto-indexes) — added as a `COLLECTION`-scope entry (per-chat, not a
  collection-group scan) · **starred_messages**: none needed (plain `orderBy('starred_at')`, and
  today nothing even queries it — the UI only ever reads the aggregate id set via
  `streamStarredMessageIds`)
- **food_logs**: date DESC + loggedAt DESC · **exercise_logs**: date+loggedAt
- **challenges**: isPublic+endDate · participantIds(array)+createdAt
- **favorites**: savedAt DESC · **recent_foods**: lastLoggedAt DESC, logCount DESC ·
  **meal_plan_history**: archivedAt DESC
- **gyms**: owner_uid · is_public+name · is_public+city+name · is_public+city+member_count DESC ·
  is_public+city+district+name · **members**: joined_at
- **presence** (collection-group, Faz 1 §1.5): expires_at ASC (stale-session sweep) ·
  **presence_sessions**: uid+entered_at DESC · entered_at DESC
- **checkins** (Faz 1 §1.2): uid+method+timestamp ASC — health-check fallback tier
  (`GymPresenceService.needsHealthCheckCard`) comparing QR vs geofence-sourced visits
- **gym_wars**: gym_a_id+status · gym_b_id+status
- **coach_profiles**: is_public+is_accepting_clients+display_name · +city+avg_rating DESC ·
  +city+client_count DESC · +avg_rating DESC · +client_count DESC · +is_verified+avg_rating DESC ·
  **clients**: status+linked_at DESC · **reviews** (collection-group): coachUid+createdAt DESC
- **programs**: is_published+enrollment_count DESC · +category+enrollment_count DESC ·
  coach_uid+created_at DESC · status+created_at DESC · is_published+status+enrollment_count DESC ·
  +status+category+enrollment_count DESC
- **commissions**: created_at DESC · **commissions** (collection-group, Faz 6 §6.6 follow-up —
  commission reversal lookup, `reverseCommissionsForPurchase`): purchase_key ASC ·
  **ai_twin_projections**: locale+generatedAt DESC
- **community_groups** (Faz 2 §2.3 discovery sorts + §2.5 activity ranking — this bullet was missing
  before §2.5 even though the §2.3 entries already existed in `firestore.indexes.json`; added here
  while adding the two new ones): is_public+last_activity_at DESC · +city+last_activity_at DESC ·
  +city+district+last_activity_at DESC · +member_count DESC · +city+member_count DESC ·
  +city+district+member_count DESC · +created_at DESC · +city+created_at DESC ·
  +city+district+created_at DESC · **+activity_score DESC** (§2.5, global "most active today") ·
  **+city+activity_score DESC** (§2.5, the city-scoped strip — deliberately activity-sorted, not
  created_at-sorted, despite its "yeni"/"new" label; see `CommunityGroupService.
  getActiveGroupsInCity`'s doc comment)
- **join_requests** (Faz 2 §2.3, collection-scoped — a group's own queue, not cross-group):
  status+requested_at ASC (`CommunityGroupService.getPendingJoinRequestsStream`, pending-only oldest
  first). **moderation**, per-group (`getModerationLogStream`): none needed (plain
  `orderBy('created_at')`). **moderation**, COLLECTION_GROUP scope (Faz 2 §2.6,
  `getMyModerationHistoryStream` — "my moderation history across every group"): **target_uid ASC +
  created_at DESC** IS needed — an equality filter combined with an `orderBy` on a different field,
  same reasoning as every other composite in this file. **group_invites**: none — doc-id lookup, no
  query at all. **referrals** was the same doc-id-only story until **Faz 6 §6.1** gym-type codes
  needed a REAL query: a gym's own invite-code management list (`ReferralService.
  gymInviteCodesStream`) reads `gym_id ASC + created_at DESC` — an equality filter combined with an
  `orderBy` on a different field, same reasoning as every composite above. Personal/coach-vanity
  codes never carry `gym_id` and stay pure doc-id lookups, never touching this index
- **coach/gym_applications**: status+submittedAt DESC · applicantUid+submittedAt DESC
- **admin_audit**: createdAt DESC · **reports**: status+timestamp DESC · **squads**: memberUids(array)+createdAt DESC
- **privacy_requests**: uid+created_at DESC (user list) · status+created_at DESC (admin queue)
- **moderation_appeals** (Faz 2 §2.6, mirrors `privacy_requests`): status+created_at DESC (admin
  pending queue — `AdminService.pendingModerationAppealsStream`). No `uid+created_at` index: the
  user-facing screen shows appeal status inline per moderation-history card via a direct doc-id read
  (`ModerationAppealService.watchAppeal`), not a query. **rate_limits**: none — pure doc-id lookup,
  fully server-only, same as `presence_notify_log`
- **following**: followedAt DESC · **users**: onboarding_data.streak DESC (leaderboard)
- **meal_plan_templates** (Faz 3 §3.3, `MealPlanTemplateService`): `author_uid + updated_at DESC` (my
  templates — library screen), `gym_id + share_scope + updated_at DESC` (a gym's shared pool — the
  "fork from another author's shared template" source, mirrors the read rule's own gym-membership
  branch so nothing the query returns can fail it), `is_public + usage_count DESC` (public/marketplace
  discovery — the other fork source). All three confirmed actually needed by the library/fork-picker
  screens before being added — no speculative index. **plan_offers** (Faz 3 §3.5, `PlanOfferService`):
  two composite indexes, different `queryScope` for different callers — `status + created_at DESC`
  (`queryScope: COLLECTION`) backs `streamPendingOffers`, a per-user `users/{uid}/plan_offers` query
  (the offer inbox's pending-first section); `status + expires_at ASC` (`queryScope:
  COLLECTION_GROUP`) backs `expirePlanOffers`' scheduled sweep, which scans every user's pending
  offers at once via `collectionGroup('plan_offers')` — a fundamentally different query shape that a
  `COLLECTION`-scoped index cannot serve. `streamOfferHistory` (the inbox's resolved-offers section)
  deliberately does NOT get its own index: a plain `orderBy('created_at')` needs none, and it filters
  out `pending` client-side — a member's own lifetime offer count is small and bounded, unlike a
  global collection, so a second composite index for a rarely-viewed history list wasn't worth adding.
- **checkins**, one new entry (Faz 4 §4.2): `uid ASC + timestamp DESC` (`queryScope: COLLECTION`) —
  `generateMemberProgressSummary`'s tier-1 aggregation (`aggregateGymFields`) reads a member's own
  last ~60 check-ins newest-first; the pre-existing `uid+method+timestamp` entry doesn't serve this
  (it requires an equality on `method`, which this query doesn't filter on). **member_summaries**
  (collection-group): `expires_at ASC` — same shape as `presence`'s TTL-sweep entry above, and for the
  same reason: `expireMemberProgressSummaries` scans BOTH `gyms/{id}/member_summaries` and
  `coach_profiles/{id}/member_summaries` in one `collectionGroup('member_summaries')` query since they
  share a subcollection name, which (like every other collection-group query in this file) needs an
  explicit entry even for a single field.
- **xp_events** (Faz 5 §5.1, `queryScope: COLLECTION` — always queried within one `users/{uid}`'s own
  subtree, never cross-user): `kind ASC + created_at ASC` — `awardXp`'s daily-cap check,
  `where('kind','==',kind).where('created_at','>=',startOfLocalDay).limit(dailyCap)`, an equality
  filter combined with a range filter on a different field, same reasoning as every other composite
  in this file.
- **engagement_credit_events** (Faz 5 §5.2, `queryScope: COLLECTION`, two entries): `source ASC +
  created_at ASC` — identical shape/reason to `xp_events` above, `awardEngagementCredit`'s DAILY-cap
  check for the three daily sources. `source ASC + week_key ASC` — a SEPARATE entry for
  `weekly_group_top3`'s cap check, an equality match rather than a time range (see that collection's
  row above for why a range breaks across consecutive weeks).
- **comments** (Faz 5 §5.2, `queryScope: COLLECTION_GROUP` — a user's comments live under many
  different posts, so a per-post query can't serve "this author's last 20 comments across
  everything"): `authorId ASC + timestamp DESC` — `fetchRecentAuthorTexts`' duplicate-content lookup
  for the comment-likes credit source. The equivalent `posts` lookup reuses the PRE-EXISTING
  `authorId ASC + timestamp DESC` entry (`queryScope: COLLECTION`) — no new index needed there.
- **messages** (Faz 5 §5.2, `queryScope: COLLECTION` — a specific chat's own `messages` subcollection,
  not cross-chat): `senderId ASC + server_timestamp DESC` — the weekly-group-contribution message
  trigger's own duplicate-content lookup (this sender's last ~20 messages in this same chat).
- **Faz 5 §5.3 — deliberately ZERO new indexes.** Every new query shape this phase added is one of
  three kinds Firestore already serves without a composite entry: (1) `community_weekly_xp/{weekKey}/
  members` ordered by `xp DESC` and `community_groups/{id}/weekly_contributions/{weekKey}/members`
  ordered by `score DESC` (read by the NEW `computeGroupContributionLeaderboards` sweep) are both a
  single-field `orderBy` with no other filter, on a specific (non-collection-group) subcollection path
  — automatically covered by Firestore's default single-field indexes, exactly like the pre-existing
  `weekly_contributions` `score` ordering `awardWeeklyGroupTop3` already relied on needed none either;
  (2) the in-gym leaderboard's `community_weekly_xp/{weekKey}/members` lookup is a chunked
  `where(FieldPath.documentId, whereIn: …)` — doc-id lookups need no index; (3) `gyms/{id}/members`'s
  list query (now reachable by any fellow member, not just the owner) and `community_groups`'
  unconditioned scan (`computeGroupContributionLeaderboards`) are both the exact same unfiltered
  `.limit(n)` shape `awardWeeklyGroupTop3`/`computeGroupActivityScores` already run today.

---

## 6. Storage Rules (`storage.rules`)
| Path | Access |
|---|---|
| `profile_photos/{uid}` | Read any auth · write owner, image <5MB |
| `post_images/{uid}/{file}` | Read any auth · write/delete owner, image |
| `chat_images/{uid}/{file}` | Read any auth · write/delete owner, image |
| `gym_applications/{uid}/documents/{file}` | Owner only, <10MB |
| `coach_applications/{uid}/documents/{file}` | Owner only, <10MB |
| `gym_logos/{gymId}/{file}` | Read any auth · write/delete any auth (app-enforced owner) |

---

## 7. Security-Rule Conventions (when adding a path)
- Default deny. Every new collection gets an explicit rule — never leave one unguarded.
- Owner-only for anything user-private; `request.auth.uid` checks.
- Admin gate via `isAdmin()` in `firestore.rules`, which checks `admin_roles/{uid}` (see
  `admin_audit`, `admin_config`, `reports`). The client mirrors the same decision via the `admin`
  custom claim (`BLK-05`) — never gate UI on `user_roles`, which is client-writable.
- Counters (likes/reactions) get narrow update rules so users can only mutate the counter, not
  the whole doc.
- Immutable collections (reviews, audit) deny update/delete.
- PII never on the public user doc — it lives in `users/{uid}/private/nutrition`.
- **Server-authoritative state is never client-writable.** Entitlements (`entitlements`, the user
  doc's `subscription_*`/`subscription_tier`), AI credits (`ai_credits`, the user doc's
  `ai_credits_*`), economy (`commissions`), and trust flags (`is_banned`, `referral_used`) are
  written only by Cloud Functions / admin. The public user doc is **field-locked**: client creates or
  updates must not touch any of those fields (`SEC-29` closed the `create`-time gap — until then,
  `create` had no constraint on them at all). IAP grants flow through a server purchase verifier
  guarded by `processed_purchases` (replay protection).
- Content-length caps belong in the rule (`request.resource.data.<field>.size() < N`) for any
  user-authored free text — posts, comments, chat messages, signals.

---

## 8. Relationships

Firestore has no joins, so relationships are expressed three ways. Pick deliberately.

| Pattern | Used for | Cost | Risk |
|---|---|---|---|
| **Subcollection** | Owned children — `food_logs`, `members`, `comments`, `reviews` | One read per child | Recursive delete needed on erasure |
| **Denormalized copy** | `display_name`/`photo_url` on members, clients, posts | Free at read | **Goes stale** — needs a defined writer |
| **Reference + fetch** | `dishId` on a food log, `relatedId` on a notification | Extra read | N+1 if looped |

### The graph

```
users/{uid} ─┬─ 1:1  private/nutrition              PII split (ADR-009)
             ├─ 1:1  entitlements/{uid}             premium truth, server-written
             ├─ 1:1  ai_credits/{uid}               quota ledger, server-written
             ├─ 1:N  food_logs → dishes/{id}        by reference
             ├─ 1:1  coach_profiles/{uid}           only if the coach role is held
             ├─ M:N  gyms          via gyms/{id}/members/{uid} + users.gym_memberships[]
             ├─ M:N  community_groups  via members/{uid} + users.group_memberships[] — each group
             │       1:1 chats/{chat_id} (Faz 2 §2.3, same id); a gym approval mirrors this same
             │       1:1 gyms/{id} ↔ community_groups/{id} ↔ chats/{id}, all three sharing one id
             ├─ M:N  follow        via following/{uid} + followers/{uid}   (both sides written)
             ├─ M:N  friends       via friends/{id}, mediated by friend_requests
             └─ M:N  coach↔client  via coach_profiles/{c}/clients/{u} + users/{u}/coaching_requests
```

**Rules for denormalized fields**
1. Every copy has exactly **one** writer. Name it in this document when you add one.
2. Source a user's name from the user doc's **`displayName`** (camelCase), then write it into other
   collections as **`display_name`** (snake). Both conventions are correct in their own place — see
   `CLAUDE.md` §9. Reading `display_name` off the user doc returns null and has broken admin search.
3. **M:N mirrors must be written together.** `gyms/{id}/members/{uid}` and
   `users/{uid}.gym_memberships[]` are one logical edge in two places — write both in a batch, or
   they diverge.
4. Counters (`member_count`, `client_count`, `enrollment_count`) are denormalized and need a narrow
   update rule so a client can move the counter but not the document.

---

## 9. Data lifecycle

| Stage | Where it happens |
|---|---|
| **Created** | Onboarding (in memory, then persisted at registration — ADR-013) · user action · server grant |
| **Read** | Live listeners for hot state; one-shot `.get()` otherwise. Always `.limit()` |
| **Cached** | Three deliberate tiers — in-memory / Hive / Firestore (ADR-016). Stale-while-revalidate |
| **Archived** | Weekly meal plans → `meal_plan_history/{YYYY-MM-DD}` on every regeneration |
| **Expired** | `signals.expiresAt` (TTL policy still needed) · AI daily quota resets at midnight |
| **Exported** | `DataExportService` — profile + PII + every owner subcollection + Storage manifest |
| **Erased** | `deleteUserAccount` — recursive subtree + server docs + authored content + Storage + Auth user |

### Retention

Nothing is auto-deleted today except AI quota resets. Retention periods per data type are defined in
[`COMPLIANCE.md`](COMPLIANCE.md) §4 — that document is authoritative for *how long*; this one for
*where*. Firestore **TTL policies are still to be configured** on `signals.expiresAt`, old `logs`,
and `processed_purchases` (safe to expire after the refund window). Without them, ephemeral data
accumulates cost forever.

> ⚠️ **Adding a user subcollection creates three obligations in the same task:** a security rule,
> inclusion in the **export**, and inclusion in the **erasure** function. Missing the last two is a
> GDPR Art. 17 / Art. 20 failure, not a bug — this is exactly what `BLK-12` is.

**Faz 3 §3.2 example**: `users/{uid}/plan_offers` got all three — the rule (above), `DataExportService._collectAll` (appended, not inserted, so no existing numbered result had to be renumbered), and erasure is automatic (`deleteUserAccount`'s `recursiveDelete(users/{uid})` already covers every subcollection, no code change needed there). `meal_plan_templates` is authored top-level content, not a user subcollection, but got the same treatment by the `posts`/`signals`/`referrals` precedent: `_authoredTemplates` in the export, a `deleteByQuery(... .where('author_uid', '==', uid))` in erasure — safe to delete outright since `plan_offers.template_snapshot` is an immutable copy, never a live reference back to the source template.

---

## 10. Migration strategy

> ⚠️ **No migration framework exists** (`ARCH-06`). Schema changes so far have relied on
> backward-compatible reads and opportunistic repair. Anything beyond that must be built.

### Patterns in use

- **Backward-compatible reads.** Models tolerate missing fields with defaults, so old documents keep
  working — this is why `NotificationModel` still parses legacy `title`/`body`, and why
  `NotificationType` accepts old enum names.
- **Read-time migration.** `getPrivateNutritionData(uid)` moves PII into the private subcollection
  the first time it's read for a user.
- **Opportunistic repair.** `verifyAndRepairUserData` backfills `displayName`/`photoURL`/`email`
  from Auth when they're missing.
- **Idempotent seeding.** `DishSeederService.seedIfEmpty()` and `DemoContentSeeder`, gated by
  `seeds/{docId}` so a seed runs once regardless of how often it's invoked.
- **Transparent re-encryption.** `StorageService` reopens and rewrites pre-existing plaintext Hive
  boxes under AES-256 on first launch after the encryption change.
- **Message model v2 (Faz 2 §2.1)** — the fullest example yet of "adding a field — the safe
  sequence" below: `server_timestamp` is the new canonical field, but `timestamp` is written
  alongside it (same instant) purely so the existing `orderBy('timestamp')` stream isn't left
  excluding every new document. `MessageModel.fromJson` is the backward-compatible read: `body`
  falls back to the old `text`, `serverTimestamp` falls back to the old `timestamp`, and
  `isReadBy(uid)` falls back to the old single global `isRead` bool only when the new `read_by` key
  is entirely absent (never for a v2 doc with an explicit empty array). Nothing about an old
  document is ever rewritten — `ChatService.markChatAsRead`'s per-message read-receipt stamping
  query orders by `server_timestamp`, which pre-v2 docs simply don't have, so they're silently
  excluded from that pass rather than touched.
- **Reputation → XP (Faz 5 §5.1).** No script, no scheduled backfill — `awardXp`
  (`functions/progress.js`) seeds a user's brand-new `xp` field from their existing
  `reputation_score` (the old `streak×2 + postCount×5` value) the FIRST time it ever needs to read
  `xp` and finds it missing; every later read/write uses the real `xp` field. `reputation_score`
  itself keeps being written (now as a plain mirror of `xp`, not an independent formula) so any
  consumer still reading that field name never breaks — see `ReputationService.fromUserData`'s
  fallback and `progress.js`'s `awardXp` doc comment for the exact mechanics.

### Rules for any migration

1. **Idempotent.** Running it twice must equal running it once.
2. **Versioned.** Record what ran, against which schema version.
3. **Logged.** Emit progress and failures; never mutate user data silently.
4. **Reversible or additive.** Prefer adding a field over rewriting one. Never destroy the old shape
   in the same release that introduces the new one.
5. **Batched with limits.** Firestore batches cap at 500 writes; large backfills need pagination and
   need to survive being interrupted halfway.
6. **Backfill server-side** for anything users can't be relied upon to trigger — a read-time
   migration only reaches users who open the app.

### Adding a field — the safe sequence

```
1. Write the field alongside the old one; read either.       (deploy)
2. Backfill existing documents.                              (script, idempotent)
3. Switch reads to the new field only.                       (deploy)
4. Stop writing the old field.                               (deploy)
5. Remove it — only after every supported client is on step 3.
```

Steps 3–5 are gated on the **oldest client version still in the field**, which is what
`app_config.version.min_supported` exists to control ([`DEVOPS.md`](DEVOPS.md) §4).
