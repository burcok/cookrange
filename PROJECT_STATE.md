# PROJECT_STATE.md — Live Status

> **Read this first, every session.** It is the single source of truth for *where the project is
> right now*. Everything else describes how the system works; this says what actually works.
>
> Keep it **small**. Status lines only — no design, no rationale, no task detail. Full task cards
> live in [`TODO.md`](TODO.md); decisions live in [`DECISIONS.md`](DECISIONS.md).

**Last updated:** 2026-08-01 · **Source of record:** `TODO.md` §1 (audit 2026-07-31; `BLK-13` re-verified 2026-08-01; `BLK-01` and `BLK-02` closed 2026-08-01)

> ⚠️ **Stale below this line as of 2026-08-04.** A full audit-remediation pass ("Faz 0") closed the
> `firestore.rules`/`storage.rules` broken-path blockers, the N1 PII leak, N2 feature-gate wiring, and
> several server-authority gaps — plus the start of a "Faz 1" gym geofence/presence feature (data
> model, Cloud Functions, consent, live occupancy, friend notifications, client geofence
> integration — `native_geofence`). None of that work is reflected in the percentages/scorecard
> below yet; treat this file as accurate only through 2026-08-01 until a fuller refresh lands.

---

## 1. Where we are

| | |
|---|---|
| `pubspec.yaml` version | `1.0.0+1` |
| **Honest state** | **v0.9.6 — internal alpha** (not shippable) |
| Current milestone | **M1 — Truth**: make what already exists actually work |
| First shippable | `v1.0.0-beta1`, consumer-only scope, after M1 + M2 + M3 |
| Store presence | None. Neither developer programme is enrolled. |
| Scope decision | **Consumer-only v1.** Gym / coach / programs / marketplace / commissions / payouts deferred to **M6**, kept in-tree behind kill-switches. See [`DECISIONS.md`](DECISIONS.md) ADR-012. |

### Progress to a public v1 — **~30–35 %**

| Dimension | % |
|---|---|
| Feature surface **written** | ~84 % |
| Feature surface **verified functional** | ~45 % |
| Backend / infrastructure configured | ~30 % |
| Security gates closed (`S0`–`S17`) | **0 %** |
| Monetization functional | **0 %** |
| Store readiness | ~10 % |
| Test coverage | ~1 % |
| Accessibility | ~15 % |

> ⚠️ **"Written" ≠ "works."** ~84 % of the feature surface exists in code; only ~45 % is verified
> functional. Seven confirmed dead paths, and no integration tests to bound the real number. Any doc
> that lists a feature as present is describing **code that exists**, not a proven working flow.
> Status lives here and nowhere else.

---

## 2. Health scorecard

| Dimension | Score | One-line reality |
|---|---|---|
| Architecture | 6.5 / 10 | Clean layering; god objects, abandoned repository layer, no DI seam |
| Flutter craft | 7.0 / 10 | Analyzer-clean at 115k LOC, real design system; 87 raw spinners, 334 hardcoded colours |
| Firebase | 6.0 / 10 | 684-line rules with real field-locking; 7 path/rule mismatches, 8 open-write holes |
| AI | 7.0 / 10 | Best-in-class quota/cost/injection/allergen layers; mock-data default fixed (`BLK-01`); real proxy E2E unverified (`BE-01`) |
| **Security** | **4.0 / 10** | Sophisticated design; **all 18 of its own gates unchecked**, App Check unenforced |
| Performance | 6.0 / 10 | Cached images, `pollCount`, pagination; **zero measurement anywhere** |
| UX | 6.5 / 10 | Design system + motion + flawless i18n; accessibility 3/10, loading states 4/10 |
| Scalability | 5.0 / 10 | Fine to ~100k with known work; hard **180-dish prompt ceiling** |
| Code quality | 6.5 / 10 | Readable, null-safe; **swallow-and-log is the systemic defect** |
| Maintainability | 5.5 / 10 | 40 files > 800 LOC, no interfaces, no test seam |
| **Documentation** | **6.5 / 10** | Well-organised and now status-honest (this file); breadth still outruns verification |
| **Testing** | **3.0 / 10** | **~1 % coverage** (unchanged) — but `test/` is now tracked, 0 failing, and **all 4 CI jobs are confirmed green** for the first time in this repo's history |
| Business readiness | 2.0 / 10 | **Zero revenue capability**; premium bypassable |
| Production readiness | 3.0 / 10 | CI green, worst data-integrity blocker fixed; still no monitoring, no backups, no store presence |
| **Weighted composite** | **5.4 / 10** | Strong design instincts, high velocity, **no verification discipline** |

---

## 3. Critical blockers — nothing ships until these close

Full cards in [`TODO.md`](TODO.md) §2.

| ID | Blocker | Domain |
|---|---|---|
| `BLK-04` | 🔥 Monetization non-functional end to end | [Premium](docs/PREMIUM.md) |
| `BLK-07` | 🔥 Gym logo upload writes to an unruled Storage prefix | [Gym](docs/GYM_ECOSYSTEM.md) |
| `BLK-09` | 🔥 `coach_uid == 'demo'` lets any user publish to the public marketplace | [Coach](docs/COACH_ECOSYSTEM.md) |
| `BLK-10` | 🔥 User doc world-readable with `email`, `last_login_ip`, device fingerprints | [Security](docs/SECURITY.md) |
| `BLK-11` | 🔥 Dish catalog unseedable in-app; only 100 dishes (Faz 3 §3.6: was 75) vs. ≥300 target | [Database](docs/DATABASE.md) |
| `BLK-12` | 🔥 GDPR erasure + export incomplete | [Compliance](docs/COMPLIANCE.md) |
| `BLK-14` | 🔥 App Check not enforced (`APP_ENV=development`) | [Security](docs/SECURITY.md) |
| `BLK-15` | 🔥 Live OpenRouter key bundled as a Flutter asset + shipped in CI artifacts | [AI](docs/AI_SYSTEM.md) |
| `BLK-16` | 🔥 No Apple / Google enrolment, no signing identity | [DevOps](docs/DEVOPS.md) |
| `BLK-17` | 🔥 No monitoring, alerting, backups; single environment | [DevOps](docs/DEVOPS.md) |

**Security gates `S0`–`S17`: all 18 open.** See [`docs/SECURITY.md`](docs/SECURITY.md) §8 and
`docs/roadmap/GO_LIVE.md` Phase 5S. `S0` (rotate the leaked Admin SA key) is first and unblocks nothing else — do it now.

---

## 4. Partially working — code exists, flow is broken

| System | Blocked by |
|---|---|
| 🚧 AI meal planning · recipe generation — no longer fabricates when unconfigured (`BLK-01` ✅); real end-to-end generation still unverified | `BE-01` |
| 🚧 Push notifications — every notification type has a server-authored writer, deployed (`BLK-03` ✅); physical push delivery unverified — no device in this environment | — |
| 🚧 Admin surface (~7,400 LOC, 9 screens) — reachable now (`BLK-05` ✅); no real admin session has exercised it yet | — |
| 🚧 Monetization (IAP client + server validation both exist) | `BLK-04` |
| 🚧 Gym ecosystem (11 screens) · Coach ecosystem (8 screens) — `BLK-03` deployed, no real approval exercised end to end yet | `BLK-07` |
| 🚧 Gym geofence auto check-in (Faz 1 — `native_geofence`, `functions/presence.js`'s `recordPresenceEvent`/`onGymPresenceCreated`/`closeStalePresenceSessions`, live occupancy, friend-at-gym push) — server side deployed and rules-tested; client integration (permission flow, region registration, background callback) is **written but physically unverified** — no iOS/Android hardware in this environment, so the actual enter/dwell/exit callback chain has never fired on a real device | needs a physical device |
| 🚧 Chat + unified groups (Faz 2 §2.1–§2.6, **all six sub-phases now built** — message model v2; `chat_detail_screen.dart` rebuilt on `lib/core/widgets/ds/chat/` with reply/forward/react/edit/delete/pin/star/report all wired to real buttons now, not just service methods; `community_groups` unified groups — public/private/gym, announcement-only, join policy, invites, moderation; `chat_list_screen.dart` rebuilt — segmented filter, unread filter, search, pin/archive/mute, swipe-to-archive, delete-for-me) — all built, rules-tested and unit-tested; see `docs/DATABASE.md`'s `chats`/`community_groups`/`chat_prefs` rows and `docs/SERVICES.md`'s `ChatService`/`CommunityGroupService` entries for what exists, rather than restating it here. **Faz 2 §2.4 fix**: `onChatMessageCreated`'s push/`unreadCounts` fan-out now sources group-chat recipients from `community_groups/{id}/members`, not the `participants` array (that array only ever held the group's owner, so every other real member was silently never notified/counted) — reasoned-through and syntax-checked against the same access model `canAccessGroupChat()` already uses, but **no functional test harness exists for Cloud Functions in this repo** (`CLAUDE.md` §8), so the trigger has never actually fired against live group data here. **Faz 2 §2.5** (most-active-groups carousel + city strip, `ActiveGroupsSection` directly below the community tab header — the old `CommunityService.getGroups()` stub is now removed entirely): `community_groups.activity_score`/`activity_updated_at` are computed by a new scheduled `computeGroupActivityScores` (`functions/groups.js`, every 15 min) and are rules-verified as unwritable by any client including the owner (`touchesProtectedGroupFields()`, 96/96 rules suite) — but exactly like the §2.4 fix above, **this Cloud Function has never actually fired against live data**, only syntax-checked (`node -c`). Cold start uses a new `seedOfficialGroups` admin-only callable (not wired to any button in this pass — manual invocation only). **Faz 2 §2.6** (moderation, closing out the phase): group member-list + kick/ban/mute/unmute UI (`group_members_screen.dart`, reason input on every action, duration chips on mute) wired onto the already-built `CommunityGroupService` methods — the write paths themselves are unchanged, so every pre-existing kick/ban/mute rules test still passes unmodified; a new `canModeratorDeleteMessage()` rule + `ChatService.deleteMessageAsModerator` let a group owner/admin take down another member's message (flips `is_deleted`/`deleted_for` only, never `body`); a new appeal path (`moderation_appeals/{id}`, mirrors the `privacy_requests` DSAR pattern exactly — `ModerationAppealScreen` user-side, `AdminModerationAppealsScreen` admin-side, resolving "upheld" auto-reverses a mute/ban) closes the plan's "itiraz yolu" ask; `CommunityService._checkContent` is now fail-closed instead of fail-open on a keyword-list refresh error (was a silent `catch {}`, R4 violation); a genuine, pre-existing schema gap found while verifying Faz 0 §0.1's "unified reports schema" claim was also fixed — `chat_service.dart`'s `reportMessage`/`reportUser` wrote only `created_at`/`targetAuthorUid`, while `AdminService`'s admin-queue queries and `ReportModel` read `timestamp`/`authorId` (written by the OTHER three report call sites in `community_service.dart`), so every message/user report was silently invisible in the admin queue despite writing successfully — same silent-exclusion class as the `streakAtRiskNotifier` bug fixed earlier this session; new reactive abuse-rate throttling (`functions/rate_limit.js` shared helper + `functions/moderation.js`'s three `onCreate` triggers, `rate_limits/{uid}` ledger, ADR-019) caps reports/moderation-actions/appeals per sliding window — additive to every existing write path, but, like every other Cloud Function change this session, **only syntax-checked, never fired against live data**. 110/110 rules suite (96 baseline + 14 new: moderator-delete positive/negative, kicked-member access revocation, moderation-appeal CRUD + rate-limit lock, `rate_limits` fully-denied). None of §2.6's new UI has been exercised on a real device/simulator either — same "written, not device-verified" status as the rest of Faz 2. **Faz 2 §2.3 fix** (a separate effort, this session): `group_detail_screen.dart`'s Join button is now `join_policy`-aware — 'open' joins immediately, 'request' opens the same request-sheet/`requestToJoin` flow `active_groups_section.dart`'s `_ActiveGroupCardState._handleJoin` already used, 'invite' shows an informational state instead of attempting a doomed join — confirmed here by reading the code itself, not by taking the claim on trust. **Faz 2 §2.3/§2.6 fix** (this task): the other half of that same gap — `group_members_screen.dart` gained a "Pending requests" section, visible only to the owner/group-admin/site-admin (the exact `canManage` check already gating kick/ban/mute, reused rather than reinvented), streaming `getPendingJoinRequestsStream` with Approve/Decline wired to `approveJoinRequest`/`declineJoinRequest` — all three existed since Faz 2 §2.3, rules-tested, with no caller anywhere in the app until now. `join_policy == 'request'` is therefore wired end-to-end for the first time: request → owner/admin queue → approve/decline → real membership. No `firestore.rules` edit was needed — the `join_requests` read/create/update/delete rules and both methods' write shape were already covered. **Faz 0 §0.1–§0.5** (a source-level chat audit, separate session — found real gaps the paragraph above didn't cover, since Faz 2's own verification never inspected `firestore.indexes.json` or the send/push code paths): `firestore.indexes.json` had **zero indexes for the `chats` collection** despite `ChatService.getUserChats`'s `arrayContains + orderBy` requiring one — the app's primary chat-list query worked only because someone hand-created it in the Firebase console at some point, so a clean deploy from this repo alone would have failed it with `FAILED_PRECONDITION`; restored (plus a new `messages[type, server_timestamp]` composite alongside the existing `[type, timestamp]` one). Chat send is now genuinely optimistic: `chat_detail_screen.dart` no longer bare-awaits `sendMessage` with no failure path — a hard rejection (rules/App-Check/auth) now throws a typed `ChatSendRejectedException` and renders as a retryable "failed" bubble (`ChatSendFailureStore` + `ChatMessageMerge`, both new, both unit-tested) instead of silently vanishing; a pending write's null `server_timestamp` (confirmed: `Query.snapshots()` has no `serverTimestampBehavior` param in the installed `cloud_firestore` version) no longer sorts the just-sent bubble to the wrong end of the list. Delivery ticks are now a real `MessageSendState` (sending/sent/delivered/read/failed, `MessageStatusResolver`, unit-tested) instead of a bool pair with no "sending" state — which also fixed a correctness bug: a group-backed chat's `participants` array holds only the owner, so "read by everyone" could never fire for a real group and now correctly degrades to "read by anyone" for `groupId != null` chats. A chat push's `chatId` (already in the FCM payload) now actually opens that conversation instead of just the chat list, and a push for the chat you're already viewing suppresses the redundant local notification (`ActiveChatTracker`, new). `ChatService` is now a proper singleton (was constructed fresh per screen). **Verified**, unlike most of the rest of this row: `flutter analyze lib/` clean (same 29 pre-existing info-level lints, zero new), full suite 276/276 (from 209 — new tests: `chat_message_merge_test.dart`, `message_status_test.dart`), `dart format` clean. **Not verified**: no Firestore rules changed in this pass, so the 182/182 rules suite is unaffected but also didn't exercise anything new; no physical push delivery, no production deploy, no on-device confirmation that the fixed index actually resolves a `FAILED_PRECONDITION` in a fresh project — same standing hardware limitation as the rest of this file | Faz 2 is now feature-complete for this plan; remaining gaps are verification-only (Cloud Function triggers never fired live, no physical-device UI walkthrough) — see the row's own text above for exactly which parts. The join-button/approval gap previously noted here is now closed (see description column) — both halves are built and verified short of a device/simulator run: `flutter analyze lib/` clean (same 29 pre-existing info-level lints, zero new), full suite 209/209 (no regressions), rules suite 182/182 (grown from the 110/110 cited above via unrelated work elsewhere this session, not this task — no rule changed here). Physical push delivery for chat messages shares the same unverified-hardware caveat as the Push notifications row above. **Chat Upgrade Faz 1–7** (separate session, this file's largest single chat pass yet — full rationale in `DECISIONS.md` ADR-025/026/027, don't restate here): multi-device session registry (replaces single-session kickout — `users/{uid}/devices`, `revokeDevice` callable, a real "your devices" screen), RTDB-backed presence/typing (`PresenceService`, real `onDisconnect`, mirrored onto the same `users/{uid}` fields every existing reader already used), a `chat_inbox` read-model split fixing the structural "group unread always zero for non-owners" bug, a rewritten idempotent/chunked/multi-device-push fan-out, server-authored group system messages, image thumbnails, a signed-URL fix for the group-chat-image storage-scoping gap (`CHAT-03`/`SEC-13`), voice messages end-to-end, and link detection in bubbles. **Verified**: `flutter analyze lib/` clean (same 29 pre-existing info-level lints, zero new), full Dart suite 294/294, full `node --test` suite in `functions/` 238/238, `dart format` clean, `flutter pub get`/dependency resolution clean for the three new packages (`firebase_database`, `record`, `just_audio`). **Deployed** (separate session, after the above was written): all 7 new/changed Cloud Functions (`revokeDevice`, `mirrorPresence`, `reconcileStalePresence`, `onGroupMemberWritten`, `onGroupDocUpdated`, `getChatMediaUrl`, `onChatMessageCreated`) confirmed live via `firebase functions:list` (the CLI's own "failed to create/update" warnings during this deploy were repeatedly false negatives — a pre-existing flaky-reporting pattern for this project, see below); `firestore.rules` released; all Firestore composite indexes live (verified 0 missing against `firebase firestore:indexes`, including the two new chat entries); `storage.rules` released; `database.rules.json` released to `cookrange-app-default-rtdb` (RTDB was in fact already provisioned — the earlier note above was wrong, corrected here rather than left standing). **A pre-existing, unrelated bug was found and fixed while unblocking this deploy**: `firestore.indexes.json` contained 18 single-field entries in the composite `indexes` array (spanning `account`, `checkins`, `commissions`, `users`, `gyms`, and others — none of them chat-related), which Firestore's composite-index API rejects outright ("configure using single field index controls"); since the deploy processes the file as one atomic batch and aborts on the first bad entry, these were silently blocking every index behind them, including the two new chat ones. None of the 18 had ever been live, so they were removed rather than migrated to `fieldOverrides` — if collection-group single-field querying is genuinely needed for any of those collections, that still needs to be added properly, as a separate task. Firestore's own index-creation API also proved flaky in the same way as Functions — the same "index already exists"/"operation already in progress" 409s that turned out to be async-completion races, not real failures, resolved by retrying (verified via a direct live-vs-local diff, not by trusting the CLI's text). **Still not verified**: the Firestore rules emulator suite could not run in this environment (Java unavailable) so the new rule blocks are pattern-consistent but not locally re-verified against the existing 182-test suite; no physical device has exercised any of this end-to-end (voice recording, push across real multiple devices, presence transitions on an actual kill) — deployed infrastructure is not the same claim as "works," and that gap is still open |
| 🚧 Teşvik ekonomisi (Faz 5, **all four sub-phases §5.1–§5.4 now built**) — server-authoritative throughout; every write path rules-tested; **no live Cloud Function has actually fired against real data**, same standing limitation as every other Faz 1-4 Cloud Function change above (`CLAUDE.md` §8, no functional execution harness exists in this repo). **§5.1** XP/levels + reputation-tier migration: `users/{uid}.xp`/`.level`, immutable `xp_events` ledger, `awardXp`/`syncProgress` in `functions/progress.js`, level-up notification, profile level chip — verified via unit tests (`xp_level_curve_test.dart`) + the rules suite (client cannot self-write `xp`/`level`/`xp_events`). **§5.2** received-engagement AI credit (`functions/engagement_credit.js` + pure `engagement_credit_logic.js`, 63/63 unit tests): 4 credit sources (post reactions, comment likes, template/recipe reuse, weekly group top-3) land in the *existing* `ai_credits/{uid}.bonus` pool via `entitlements.js`'s `grantBonusCredits` — not a third currency; anti-abuse is real and tested — reciprocity-pair + closed-cluster down-weighting (`reciprocity_pairs`, `engagement_diversity`, both fully server-only), account-age/email-verified eligibility gate, content-quality + near-duplicate-text rejection, an auto shadow-restriction (`credit_restrictions/{uid}`) with an appeal path (`moderation_appeals`); premium multiplier is real (`creditAndCapForPremium`: credit value AND cap ×2, never the distinct-account threshold — "tavanlar da 2×" per the plan, doubling the popularity bar would be backwards). **§5.3** competition/status: weekly community/group/gym leaderboards (XP-based — **correction, found during Faz 8 §8.3's site-content research and closed same session:** these silently read an always-empty `community_weekly_xp/{weekKey}/members` collection since this phase originally shipped — the UI, model and rules were all real (`firestore.rules`' own comment on that collection already documented the exact write shape) but `awardXp` never actually wrote to it; `awardXp` (`functions/progress.js`) now writes the denormalized rollup in the SAME transaction as the XP grant, reusing `localWeekKey` from `engagement_credit_logic.js` so the week boundary stays byte-identical to the client's `LocalWeek.key()` — syntax/module-load verified, **no live traffic through it yet**, same standing limitation as every other Cloud Function change in this document), badge cabinet (11 pre-existing + `groupTop3`/`groupStreak4`), group weekly-contribution leaderboard (`community_groups/{id}/weekly_leaderboard/{weekKey}`, denormalized every 15 min by `computeGroupContributionLeaderboards`, group-member-readable, **write: if false even for the owner** — 169/169 rules suite includes this exact assertion — this one was never affected, it's a separate collection from the XP rollup above) — premium is deliberately kept out of XP/rank entirely (no purchasable status), confirmed by §5.4's audit below. **§5.4** (this task) wired `FeatureGateService`'s `Entitlements` checks for the first time ever — Faz 0 §0.3 built the mechanism and found 0 call sites; that finding was re-verified empirically before this task started and still held (even after Faz 1-4 and §5.1-§5.3) — now all 8 gates have a real call site: `nutritionAnalytics`/`groupChat` at their screens' entry points (both always-true today — "free feature" and Faz 2's shipped free chat, respectively — so neither blocks anyone, but neither is dead scaffolding either); `advancedTrends` gates a new, additive 30-day nutrition-trend section (`NutritionAnalyticsScreen`) and `advancedAIAnalysis` gates a new, additive BMR/TDEE/logged-calorie breakdown (`AiFitnessTwinScreen`) — both premium-exclusive, both leave the existing free view completely untouched; `exportData` gates a new CSV export of a group's member list (`CommunityGroupService.exportMembersCsv`) — the answer this task found to the plan's undefined "premium grup admin araçları" scope, chosen specifically because it takes nothing away from the free, unconditional kick/ban/mute tools already in `CommunityGroupService`; `verifiedBadge`/`weeklyMealPlanGenerations`/`dailyAIChatMessages` are real but currently-inert call sites (pro tier unused; the unified `ai_credits` system is what actually throttles AI generation, these two int getters predate it). Paywall copy (`premium_upgrade_sheet.dart`) gained back one of the two promises Faz 0 §0.6 had removed as unfixably false ("detailed analytics", via the new 30-day trend) — the other ("advanced meal customization") stays removed: Faz 3's template builder is free for every tier by design, and template authorship itself is `author_type in ['gym','coach','admin']`-gated regardless of subscription tier, so it was never a meaningful individual-premium claim | needs a real deploy + live traffic to confirm; `verifiedBadge`/the two vestigial int-getter call sites need a product decision on whether to build real enforcement, retire them, or leave as-is |
| 🚧 QR davet + salon atfetme + gelir (Faz 6, **§6.1–§6.6 now built**) — §6.1 gym invite-code generation (`referrals/{code}` `type:'gym'`, QR + printable poster, `FeatureFlags.gymInviteCodes`), §6.2 site `/davet/{code}` SSR landing (sibling `cookrange-landing` repo), §6.3/§6.4 deep-link → onboarding → apply-at-signup (`app_links`, `DeepLinkService`, `previewReferralCode` callable, onboarding referral step, `OnboardingCompletion.finalizeAndRoute`) were built and independently verified earlier this session — **correction, found during Faz 8 §8.6's technical audit:** the client-side `app_links` wiring is real, but `cookrange-landing`'s `public/.well-known/` has neither `apple-app-site-association` nor `assetlinks.json` (0 matches, static or dynamic route). Without those, iOS/Android won't verify the domain↔app association, so tapping a real `cookrangeapp.com/davet/{code}` link on a phone with the app installed will open the browser, not the app — the deep-link UX this section describes as shipped is untested and very likely non-functional end-to-end today. Blocked on the user's real Apple Team ID and Android signing certificate SHA-256 fingerprint (external account data, not derivable from code) — tracked separately, not fixed in this task. **§6.5/§6.6 (this task)**: `applyReferral` now special-cases `type=='gym'` — instead of the personal-referral 7-day-trial + ₺5-commission grant (which at a 5,000-use poster ceiling would have been a real abuse vector), it writes an immutable `gym_attributions/{uid}` doc, bumps `gyms/{id}.attributed_member_count`, and notifies the owner (no redeemer identity attached). `maybeAwardGymCommission` (`functions/economy.js`, called from `purchases.js`'s `validatePurchase` right after a real subscription purchase is granted) accrues a flat `gymPremiumShare` commission — entirely server-side, never client-triggered. New `GymEarningsScreen` + a funnel-stat header (signups → premium conversions) on `GymInviteCodesScreen`, both behind a new, separately-killable `FeatureFlags.gymAttribution`; user-facing "you signed up via {gym}" transparency + one-tap, display-only disconnect on Settings (the record itself stays immutable — the gym's earned commission isn't retroactively undermined); `assets/legal/marketplace_terms_{en,tr}.md` gained a new §10/§11 gym-commission section and is, for the first time, actually linked from the app (`GymEarningsScreen` → `LegalScreen`) — closes audit finding C16a. Both GDPR/KVKK data-subject-rights paths extended for the new collection (`DataExportService._collectAll` #27, `deleteUserAccount`'s uid-keyed cleanup). Verified: `flutter analyze lib/` 0 new issues (29 pre-existing info-level lints, unchanged), full `flutter test` 209/209, Firestore rules suite 181/181 (5 new tests: `gym_attributions` read/write scope including the deliberate "gym owner cannot read it either" assertion, the two new protected gym counters, and a `gymPremiumShare`-specific commission self-grant denial), `node -c` + `require()` clean on every touched Cloud Function file. **Not verified** — same standing limitation as every other Cloud Function change in this project (`CLAUDE.md` §8, no functional execution harness exists here): neither `applyReferral`'s gym branch nor `maybeAwardGymCommission` has ever fired against a real code redemption or a real purchase. The funnel is deliberately 2 stages (signups → premium), not 3 — "scans" has no honest server-side count anywhere in this repo (a poster is scanned by a bare camera app outside anything Flutter/Functions can observe); building that would need the site's own page-view analytics (§6.7, a separate, sibling-repo concern) | needs a real gym-code redemption + a real premium purchase exercised end to end; §6.7 (site waitlist-referral parity) is separate, sibling-repo work, not started here |
| 🚧 Friends/follow — server-authored writes deployed (`SEC-06` ✅); no live UI flow exercised yet | — |
| 🚧 Program marketplace | `BLK-09` |
| 🚧 Dish catalog | `BLK-11` |
| 🚧 Moderation (scans wrong prefix; queue reachable but unstaffed) | — |
| 🚧 CD — deploy workflow (TestFlight + Play, never run) | `BLK-16` |

## 5. Verified working

Auth (email/Google/Apple) · Onboarding V2 · calorie & macro maths · streak logic · food diary ·
recent/favourite foods · water reminders · weight/hydration/exercise logging · shopping list ·
cooking mode · community feed & comments & reactions · 1:1 + group chat · in-app notifications ·
achievements (grant + display verified — 15-badge catalog, idempotent server grant, wired into
profile; **but** its own celebration notifications, `achievementEarned`/`streakFreezeUsed`, are dead
code — full enum/presenter/push-text support, zero `writeNotification` call sites anywhere in
`functions/`, confirmed by a full grep of every call site; `streak_freeze_count`/`onboarding_data.streak`
are now server-write-only (`SEC-14` — code-complete, not yet deployed; previously absent from
`touchesProtectedUserFields()`'s denylist and client-writable); see
`docs/roadmap/PHASE_15_ENGAGEMENT.md` §15.5) · AI insight/twin/recap (all guard `isConfigured`) · AI
proxy security core ·
AI meal-plan/recipe generation degradation path (`BLK-01` — throws + branded error state when
unconfigured, never fabricates; real proxy call path still unverified, see `BE-01`) ·
iOS photo-picker path (`BLK-02` — `NSPhotoLibraryUsageDescription` present, all 6 gallery call sites
prime via `PermissionService`, permanent CI guard against the string going missing again; confirmed
crash-free on Simulator, physical-iPhone confirmation still pending a device) ·
meal plan history (`BLK-06` — owner rule deployed to production, both read/write paths report to
Crashlytics; rules test confirmed passing in CI, full on-device flow not separately walked) ·
admin authorization (`BLK-05` — `syncAdminClaim` deployed and confirmed live via `firebase
functions:list`; all 3 client gates re-pointed at the custom claim; rules tests confirm the
`admin_roles` → `isAdmin()` chain end to end in CI; no real admin session has exercised the 9-screen
surface yet — nobody has been console-provisioned) ·
push notification fan-out + social-write lockdown (`BLK-03`/`SEC-06` — 8 Cloud Functions
(`createNotification`, `retractNotification`, `sendAdminNotification`, `followUser`, `unfollowUser`,
`sendFriendRequest`, `respondToFriendRequest`, `cancelFriendRequest`) deployed and confirmed live via
`firebase functions:list`; Firestore rules deployed cleanly; rules tests confirm client cannot forge
a notification or write another user's `friends`/`friend_requests`, end to end in CI; no real
gym/coach approval or friend-request/follow flow has been exercised against the live callables yet,
and physical push delivery is unverifiable in this environment — no iOS/Android hardware, no real
APNs on the Simulator) ·
allergen pre-filter · prompt-injection guard · Hive AES-256 · consent registry · design system ·
EN/TR parity (2,722 keys) · maintenance + force-update gates · feature kill-switches ·
image upload pipeline · `pollCount` discipline · `flutter analyze lib/` 0 errors ·
Firestore rules test suite (22 test cases, partial coverage) green in real CI
([run #30704409637](https://github.com/burcok/cookrange/actions/runs/30704409637), incl. the 4 new
`BLK-03`/`SEC-06` assertions) ·
**CI — all 4 jobs green** (`analyze-and-test`, `firestore-rules`, `secret-scan`, `build-android`),
confirmed in a real run, first time in this repo's history.

Evidence table: `TODO.md` §1.4.

## 6. Not built at all

Integration/widget tests · rules tests in VCS · monitoring & SLOs · structured production logging ·
staging environment · backups & DR · DI / service interfaces · full-text search · payout rail ·
white-label · auth rate-limiting & MFA · migration framework · proxy load testing · API versioning ·
release obfuscation · tablet layouts · offline write queue · behavioural-analytics ML.

IDs in `TODO.md` §1.6.

---

## 7. Milestones

| Milestone | Version | Exit criterion | Est (solo) |
|---|---|---|---|
| **M1 — Truth** | `v0.9.7` | Every consumer-path feature demonstrated on a physical iPhone **and** Android against a production-configured backend. All 17 blockers closed (`BLK-13` ✅, `BLK-01` ✅, `BLK-02` ✅ code/CI, physical-device confirmation still owed, 14 remain). ~~CI green~~ **✅ done** — all 4 jobs confirmed. | 4–6 w |
| **M2 — Legal** | `v0.9.8` | `S0`–`S17` green. User doc split. Erasure + export complete. Privacy labels + Data Safety filed. DPA executed. Backups live. | 3–4 w ∥ |
| **M3 — Commerce** | `v0.9.9` | Both stores enrolled. 3 products live. One real sandbox purchase → real entitlement. Premium gated server-side. | 3–4 w ∥ |
| **M4 — Beta** | `v1.0.0-beta1` | 50–100 real users. Dish catalog ≥ 300. D7 measured. Crash-free > 99 %. A11y pass on 10 flows. | 4 w |
| **M5 — Launch** | `v1.0.0` | Live on both stores, staged rollout, alerting on, rollback lever tested. | 2–3 w |
| **M6 — Ecosystem** | `v1.1.0` | Gym + coach reopened. 5–10 pilots. Payout rail live. `BLK-09` closed. | 6–8 w |
| **M7 — Scale** | `v1.2.0`+ | Search, BigQuery, Cloud Tasks fan-out. 10k → 100k users. | ongoing |

**To M5:** solo 2.5–3.5 months with the consumer-only cut applied · 2 engineers 1.5–2 months.
Store review is an irreducible 1–2 weeks of wall clock.

---

## 8. Next recommended actions

1. **`S0` — rotate the leaked Firebase Admin service-account key.** Independent of everything; a live
   key bypassing all rules is the highest-severity open item.
2. ~~**`BLK-01`**~~ **Done** — mock block deleted, `isConfigured` guards added to both AI services,
   branded error states wired in `home.dart` / `explore_screen.dart`, startup Crashlytics assertion
   added, regression test in `test/meal_plan_ai_unavailable_test.dart`. Release builds can no longer
   fabricate a meal plan. **Residual:** `BE-01` (deploy `aiProxy` + set `ai_proxy_url`) is now a hard
   launch dependency instead of a silently-degraded one — without it, users see the honest error state
   forever, not a broken app, but the feature doesn't work either.
3. ~~**`BLK-13`** / **`CI-11`** / **`CI-12`**~~ **All done — all 4 CI jobs confirmed green**
   ([run #46](https://github.com/burcok/cookrange/actions/runs/30690211684), commit `091429e`), first
   time in this repo's history. Four stacked root causes found and fixed across the two follow-on
   cards: a stale Flutter CI pin, an invalid `firebase_options.dart` placeholder, a genuine
   `assets/Fonts`/`assets/fonts` case-sensitivity bug masked by macOS project-wide, and a hardcoded
   local-machine-only Java path in `android/gradle.properties`. Every one confirmed by reproduction —
   a real `ubuntu:24.04` container (via `colima`, no Docker Desktop here) matching CI's architecture,
   with a full Android SDK set up for the last one — not guessed at from log fragments. **Recommended
   next step: `CI-02` branch protection**, now genuinely achievable; not done here, since it's a
   repository-settings change outside what was asked for.
4. ~~**`BLK-02`**~~ **Done (code)** — `NSPhotoLibraryUsageDescription` added; found and fixed a related
   gap along the way (3 of 6 gallery call sites had no `PermissionService` priming at all — now all
   six do); added `scripts/check_ios_permissions.sh` as a permanent CI guard so a missing iOS usage
   string can't recur silently. **Residual:** physical-iPhone confirmation and a signed
   `flutter build ipa` are still owed — verified on the Simulator only (no crash, correct primer +
   Settings-redirect flow), and a real device needs `BLK-16` (no signing identity yet) regardless.
5. ~~`BLK-06`~~ **done** — `meal_plan_history` rule deployed to production with your go-ahead, rules
   test confirmed green in CI.
   ~~`BLK-05`~~ **done** — `admin_roles` custom-claim sync (`syncAdminClaim`) deployed to production
   with your go-ahead (`firebase deploy --only functions:syncAdminClaim`, confirmed live via
   `firebase functions:list`); all three client gates, the bootstrap runbook, and rules tests
   shipped alongside it. Followed with a downstream sweep of the ~30 "unreachable until `BLK-05`"
   references across `TODO.md` (`ADM-*`, `MOD-01`, `NOTIF-13`, `MKT-02`, `LEG-09`, etc.) now that
   the fix is confirmed live.
6. ~~**`BLK-03` + `SEC-06`**~~ **done** — one canonical notification path
   (`notifications/{uid}/items/{docId}`), all creation moved server-side
   (`functions/notifications.js`, `social.js`): `createNotification`/`retractNotification` (generic
   social types, actor always re-derived from `context.auth.uid`), `sendAdminNotification`
   (admin-claim-gated), and `followUser`/`unfollowUser`/`sendFriendRequest`/`respondToFriendRequest`/
   `cancelFriendRequest` (edge + notification written atomically). `firestore.rules`: `friends`/
   `friend_requests` locked to server-only, old `users/{uid}/notifications` retired (straight cutover —
   no real users yet to migrate), new canonical path rule added. Found and fixed two adjacent bugs in
   the same files: `executeBroadcast`/`applyReferral` wrote `createdAt` instead of `timestamp` (would
   have silently excluded those docs from the paginated feed once this path became canonical), and
   `executeBroadcast` was double-sending push (its own direct send plus a second generic-text send via
   the trigger it also happened to write into). `getPushText` rewritten with full EN/TR text for all 21
   `NotificationType` values, closing `I18N-04` in the same change. 4 new rules tests (22 total)
   confirmed passing in real CI. **Deployed** with your go-ahead: 8 Cloud Functions (the deploy hit
   the same ambiguous "failed to create function" CLI error as `BLK-05`, repeatedly — each retry
   advanced one function further while the CLI reported the *next* one as failed; deployed in small
   batches, confirming every function via `firebase functions:list` rather than trusting the CLI
   message, until all 8 were verified live) and the Firestore rules (clean on the first attempt).
   **Residual:** physical push delivery **cannot be verified in this environment**: no iOS/Android
   hardware, and the iOS Simulator cannot receive real APNs push at all — this is a harder limit than
   `BLK-01`/`BLK-02`'s partial Simulator verification. No real gym/coach approval or friend-request
   flow has been exercised end to end against the live callables yet either.
7. ~~**`BLK-08`**~~ **done** — the `posts` update rule was a denylist (only
   `authorId`/`content`/`imageUrls`/`tags` blocked), so any authenticated user could write any other
   field — `groupId`, `metadata`, etc. Replaced with an allowlist of the real engagement fields
   (confirmed against actual call sites, not guessed): `likesCount`/`likedUserIds`/`recentLikers`/
   `reactions`/`commentsCount`, with the two scalar counters delta-constrained to ±1 per write. Found
   and fixed the identical bug twice more while investigating: `posts/{id}/comments` (same pattern)
   and `gyms/{id}/posts` (a different collection, snake_case fields — this is where the
   `is_announcement` flag the ticket named actually lives, not on the main `posts` collection). 5 new
   rules tests (27 total) confirmed passing in real CI, and the Firestore rules deploy confirmed
   clean with your go-ahead. **Residual, honestly noted:** the `reactions` map and
   `likedUserIds`/`recentLikers` arrays are allowlisted but not delta-constrained (Firestore rules
   can't cheaply validate "one element changed" on a map/array) — a non-owner could still write an
   arbitrary `reactions` value in one call. Fully closing that needs the trigger-based rewrite the
   ticket offered as an alternative; not attempted here since the actual client code denormalizes far
   more per like (an array + a name/avatar list) than a simple counter, making that a materially
   larger, separate undertaking, not this ticket's 1-day scope.
8. Then M2 security gates in the order fixed by `GO_LIVE.md` Phase 5S — **server write paths first
   (`S2`→`S3`→`S4`), then lock the rules (`S1`, `S5`)**. Locking first breaks live flows.

---

## 9. Maintaining this file

Update it when — and only when — one of these changes: version, milestone, a blocker opens/closes,
a health score moves, or a system changes column (built → working, or working → broken).
A feature landing in code is **not** a reason to touch §5; moving it to §5 requires demonstrating it
works. Keep the whole file under ~200 lines.
