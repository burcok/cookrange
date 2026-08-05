# FEATURES.md — Capability Catalog

> The answer to **"does Cookrange already do X, and where is it?"**
> If it's here, the code exists. **The State column tells you whether it actually works.**
> If it isn't here at all, check [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md).

### State legend

| | Meaning |
|---|---|
| ✅ | **Working** — demonstrated functional (evidence in `TODO.md` §1.4) |
| 🚧 | **Built, unverified** — code exists; no proof it runs end to end |
| ⛔ | **Built, blocked** — a known defect makes it non-functional. Blocker ID given |
| 🔒 | **Built, kill-switched** — deferred to M6 by scope decision ADR-012 |
| ❌ | **Not built** |

> ⚠️ Far more of this surface is *written* than is *verified*. **A 🚧 is not a promise.** Overall
> progress figures and blocker detail live in [`../PROJECT_STATE.md`](../PROJECT_STATE.md) — this
> document never carries percentages or health scores, so that they can only ever be wrong in one
> place.
>
> **Since** = the milestone the capability first appeared in. The app has never been released, so
> these are internal markers, not shipped versions.

---

## Nutrition & food

| Feature | State | Since | Depends on | Next |
|---|---|---|---|---|
| AI weekly meal plan — hash-cached, allergen-filtered, archived | ✅ | v0.5 | `WeeklyMealPlanService`, `aiProxy` | `isConfigured` guard confirmed present (throws `AIFatalException` rather than fabricating a plan) — `BLK-01` is stale for this row, `AI_SYSTEM.md` §1/§9 already show it closed. 180-dish ceiling now mitigated by a round-robin cap (`PromptService.maxDishesPerPrompt`, Faz 3 §3.6); the real fix (`AI-03`'s relevance-based candidate selector) is still not built |
| Food logging — today's plan / recipe / AI-scanned / barcode | ✅ | v0.4 | `FoodLogService` | "Quick-add" is built (`quick_add_sheet.dart`, `FoodLogService.logQuickFood`) but has **zero navigational callers anywhere in the app** (confirmed by repo-wide search) — no button or menu reaches it, so it's dropped from this row's description until something wires it up. It is not one of the app's real logging methods today |
| Recent & frequent foods | ✅ | v0.6 | `RecentFoodService` (Hive) | Only reachable from the orphaned quick-add sheet above — same caveat |
| Recipe database — TR + international, seeded | ⛔ `BLK-11` | v0.3 | `DishService`, `dish_data.dart` | Unseedable in-app; 100 dishes (Faz 3 §3.6: was 75), need ≥ 300 |
| Favorites, recipe notes | ✅ | v0.6 | `FavoriteService`, `RecipeNoteService` | — |
| Cooking mode — step pager, timer, wakelock, finish→log | ✅ | v0.7 | `wakelock_plus` | — |
| AI recipe generation — credit-gated | ✅ | v0.6 | `RecipeGenerationService` | `isConfigured` guard confirmed present, same as meal plans — `BLK-01` stale here too. Not auto-logged: generating only builds the recipe object; logging requires Cooking Mode's explicit "Log & Finish" (`FoodLogService.logRecipe`) |
| AI food analysis — describe **or** photo (vision) | 🚧 | v0.9 | `FoodAnalysisService`, vision model | Single-image only (the prompt explicitly merges multiple foods on one plate into one estimate, not itemized); allergen chips shown are informational only, never cross-checked against the user's declared allergies |
| Barcode scanning | 🚧 | v0.8 | `mobile_scanner`, Open Food Facts (direct REST call, no SDK) | Description corrected — "manual-entry fallback" is re-typing the barcode's digits through the same OFF lookup, not a manual nutrition-entry fallback; on a miss there is no way to log the product's macros by hand. `BarcodeProduct` also carries no allergen field at all |
| Nutrition analytics — 7-day bars, macros, 0-100 consistency score | ✅ | v0.7 | `CalorieCalculator`, `NutritionAnalyticsService` | Real and wired (`nutrition_hub_screen.dart`'s Insights tab); free-tier gate (`Entitlements.nutritionAnalytics`) is `true` for every tier today — not actually gating anyone |
| Nutrition analytics — 30-day trend (premium) | 🚧 | v0.9.6 | `Entitlements.advancedTrends` | Not device-verified |
| Shopping list — auto-generate, source-meal attribution, sync, `.ics` | ✅ | v0.7 | `ShoppingListSyncService` | — |
| Meal plan calendar export (`.ics`) — per-meal VEVENTs, Apple/Google/Outlook | ✅ | v0.8 | `MealPlanCalendarService`, `share_plus` | — |
| Meal plan history + restore | ✅ | v0.8 | `WeeklyMealPlanService.getMealPlanHistory`/`restorePlan` | `BLK-06` is stale — `firestore.rules` has a clean owner-only `meal_plan_history` rule today (`allow read, write: if isOwner(uid)`, confirmed by direct read), and both the history screen and restore path have real navigation callers from `home.dart` |
| Meal plan templates & offers — gym/coach builds a plan template (AI-generated / from-scratch grid / forked) and sends it to a member/client, who previews macros + an allergen check against their own profile + the day-by-day plan before accepting/declining | ✅ | v0.9 | `MealPlanTemplateService`, `PlanOfferService`, `PlanNutritionCalculator`, `functions/templates.js` (`sendPlanOffer`/`onPlanOfferResponded`/`expirePlanOffers`) | Not previously in this doc at all. Accepting **replaces** the member's current plan (old one archived to history first); recipient eligibility is real gym-membership/active-coaching-relationship only, not any two users; `shareScope: 'link'/'marketplace'` is accepted as data with no read-access mechanism built yet |
| Hydration tracking — onboarding-personalized target + reminders, home-screen daily logger | ✅ | v0.6 | `OnboardingProjectionService.recommendedWaterMl`, `PushNotificationService.scheduleDailyWaterReminder`, `TrackingCard` (Hive-only) | Not previously called out beyond "Hydration...logging". Onboarding computes a personalized target (~33ml/kg + activity bonus, clamped 1500–4000ml) and schedules 2–12 reminders across the waking window, but the **daily tracking widgets don't read it back** — both `TrackingCard` and `TodaySummaryCard` hardcode a fixed 2000ml/day goal regardless of the personalized value |
| Weight logging — daily entry + 7-day mini chart | ✅ | v0.6 | `TrackingCard`, `WeightLogSheet` (Hive-only) | — |
| Exercise logging — pick type/duration, MET-table-estimated burn, shown live next to today's calorie target | ✅ | v0.6 | `ExerciseLogService` | Manual entry only — no HealthKit/Google Fit/step-count integration exists anywhere in `lib/`. Burned calories are informational only, shown as their own badge — never merged into or subtracted from the calorie target, which changes only on profile update or explicit plan regeneration |

## AI intelligence

| Feature | State | Since | Depends on | Next |
|---|---|---|---|---|
| AI chat coach — profile-aware, voice-bridged | 🚧 | v0.7 | `AiChatService` | Streaming responses |
| AI Fitness Twin — 30/60/90-day projection | ✅ | v0.8 | `AiInsightService` | — |
| AI Fitness Twin — detailed BMR/TDEE breakdown (premium) | 🚧 | v0.9.6 | `Entitlements.advancedAIAnalysis` | Not device-verified |
| Daily accountability insight — cached per day+locale | ✅ | v0.8 | `AiInsightService` | — |
| Weekly AI recap — score, wins, challenges, trend | ✅ | v0.9 | idempotent per week+locale | — |
| Risk detection — client-side, no AI call | ✅ | v0.8 | — | — |
| Voice assistant overlay | 🚧 | v0.7 | `speech_to_text` | — |
| Server-side AI quota — fail-closed, transactional | ✅ | v0.9 | `aiProxy` | — |
| Real cost metering — tokens × model price | ✅ | v0.9.5 | `ai_usage_logs/stats` | — |
| AI credits — 2/day free, 20/day premium, IAP bonus | 🚧 | v0.9 | server ledger | Blocked commercially by `BLK-04` |
| Prompt-injection guard + deterministic allergen filter | ✅ | v0.9 | `PromptService`, `AllergenSafety` | — |

Detail: [`AI_SYSTEM.md`](AI_SYSTEM.md).

## Social & community

| Feature | State | Since | Depends on | Next |
|---|---|---|---|---|
| Feed — posts, reactions, comments, image carousel | ✅ | v0.5 | `CommunityService` | Post field-mutation hole `BLK-08` |
| Filters & topics — Global/Friends/Following/Gym/Saved | ✅ | v0.7 | `AppFilterBar` | — |
| Friends, follow graph, weekly highlights | ✅ | v0.5 | `FriendService`, `FollowService` | Open creates (`S5`) closed in code+rules, deploy pending |
| @mentions with notification fan-out | ✅ | v0.7 | — | — |
| Direct messages + group/gym chat — reply, forward, react, edit/delete (15-min window), pin, star, mentions, read receipts, typing, cursor-paginated history, media gallery, in-chat search | ✅ | v0.5 → Faz 2 §2.1–§2.2 | `ChatService`, `message_model.dart` v2 | Not end-to-end encrypted — server-readable by design, so report/moderator-takedown can work |
| In-app notifications — structured, locale-rendered | ✅ | v0.6 | `NotificationPresenter` | — |
| **Push notifications** | 🚧 `BLK-03` | v0.6 | Cloud Functions | Every notification type now has a deployed, server-authored writer (`notifications.js`/`social.js`); physical-device verification still pending — no hardware in this environment, and the iOS Simulator cannot receive real APNs |
| Community groups — unified public/private/gym, 3 join policies, announcement-only, moderation, invite codes, activity-ranked discovery | 🚧 | v0.9 → Faz 2 §2.3–§2.6 | `CommunityGroupService` | Gym groups auto-create on gym-application approval (`kind:'gym'`); rules- and unit-tested end to end (182/182 + 209/209 per `PROJECT_STATE.md`); no Cloud Function trigger (`computeGroupActivityScores`) or physical-device walkthrough has fired against live data yet |
| Group member CSV export (premium admin tool) | 🚧 | v0.9.6 | `Entitlements.exportData` | Not device-verified |
| Streak squads — invite-code group; shows members' individual streaks side by side + a streak leaderboard | 🚧 | v0.7 | `StreakSquadService` | No shared/pooled streak exists — each member's streak is their own |
| Signals — ephemeral, TTL | 🚧 | v0.6 | needs a Firestore TTL policy | — |
| Streaks + milestones + freeze | ✅ | v0.4 | `functions/progress.js` (`processStreakLogin`), unit-tested | `SEC-14` closed in code+rules, deploy + value-reconciliation pending. Streak is a **login** streak (consecutive calendar days signed in), not tied to whether you actually logged food/water/exercise that day. Server-authoritative: a missed day either consumes one "freeze" (streak preserved, `streak_freeze_count` -1) if the user has one, or resets the streak to 1. New users get exactly 1 free freeze at signup (`firestore_service.dart`'s "welcome gift"); no other grant path (purchase, achievement, referral) was found in the code — describe this as a one-time gift, not a renewable/earnable mechanic, until one is confirmed |
| XP & levels — server-authoritative ledger | 🚧 | v0.9.6 (Faz 5 §5.1) | `functions/progress.js` (`awardXp`/`syncProgress`) | Fixed, server-owned points/caps table (`XP_TABLE`) — a client can name *which* event happened, never its point value; idempotent per-event ledger (`xp_events/{kind}_{refId}`); increasing-interval level curve mirrored in `xp_level_curve.dart`. Unit- and rules-tested (client cannot self-write `xp`/`level`/`xp_events`); never fired against live traffic |
| Achievements — 15 badges, idempotent | ✅ | v0.9.5 | `AchievementService` | Grant + display verified; `achievementEarned`/`streakFreezeUsed` notification types are wired end to end in the presenter but never actually written — no call site anywhere in `functions/` (`docs/roadmap/PHASE_15_ENGAGEMENT.md` §15.5) |
| Reputation tier | 🚧 | v0.9.6 (Faz 5 §5.1) | derives from XP level bands | **No longer client-computed/forgeable** — migrated off the old `streak×2 + postCount×5` formula onto server-derived XP level bands (`tierFromLevel`); `firestore.rules` denies client writes to `xp`/`level`/`reputation_score` unconditionally |
| Leaderboards — global streak, friends, weekly XP (community + per-group) | 🚧 | v0.7 → Faz 5 §5.3 | `LeaderboardService`, `community_weekly_xp/{weekKey}` | Weekly XP rollup is now written transactionally inside `awardXp` itself — closes a same-session-found bug where that collection was silently always-empty since it first shipped; a separate per-group weekly contribution leaderboard is write-denied even to the group owner |
| Received-engagement AI credit | 🚧 | v0.9.6 (Faz 5 §5.2) | `functions/engagement_credit.js` | Reactions/comment-likes/template-reuse/weekly group top-3 fund the *existing* `ai_credits.bonus` pool (not a third currency); real anti-abuse (reciprocity-pair down-weighting, account-age gate, near-duplicate rejection, shadow-restriction + appeal); Premium doubles the credit value and its cap only — never XP itself, which has no monetary equivalent anywhere in `progress.js` |
| Moderation — keyword screen, reports, image scan, group kick/ban/mute, appeals | 🚧 | v0.8 → Faz 2 §2.6 | `BLK-05` closed — admin queue is reachable; `moderation_appeals` (Faz 2 §2.6) adds a user-facing appeal path for group mute/kick/ban | Reports/moderation-actions/appeals are now sliding-window rate-limited (`functions/rate_limit.js`); general UGC (posts/comments/signals/friend-requests) is still unthrottled |

Detail: [`COMMUNITY.md`](COMMUNITY.md).

## Gym ecosystem — built and live, not kill-switched

> ADR-012 planned to gate this behind a kill-switch for an M6 relaunch. In the current code,
> `FeatureFlags.gym` (→ `AppConfigService.isFeatureEnabled`) defaults to **enabled** and gates the
> real entry points (side menu, Discover hub, quick actions, home role card) — nothing indicates it
> has ever been switched off. The 🔒 state below is retired for this domain: read "M6" as the
> remaining go-to-market milestone (real pilots, the live-traffic/hardware verifications each row
> still calls out), not a code gate. Detail: [`GYM_ECOSYSTEM.md`](GYM_ECOSYSTEM.md).

| Feature | State | Since | Notes |
|---|---|---|---|
| Gym profiles, brand colour, verification | 🚧 | v0.8 | No real application has been approved end to end against the live callables yet |
| Gym setup | 🚧 | v0.8 | `BLK-07` closed — the logo upload path and the Storage rule now agree on the same prefix |
| Membership & check-in — QR / GPS / manual / geofence | 🚧 | v0.8 | QR and geofence check-ins are server-validated; the GPS path's radius check is still client-only (`S13`, partially closed) |
| Presence & auto check-in — geofence enter/exit, live occupancy, friend-at-gym push (Faz 1) | 🚧 | v0.9.6 | Consent-gated (`ConsentPurpose.gymPresence`, default off); no raw lat/lng ever stored, only enter/exit events. Server side deployed and rules-tested; the client geofence trigger is written but unverified on real iOS/Android hardware in this environment |
| Gym community feed, leaderboard, analytics | 🚧 | v0.8 | Member leaderboard is now weekly-XP-based (Faz 5), not raw check-in count |
| Gym discovery — city/district, 4 sorts, map | 🚧 | v0.9 | "Near Me" is the KVKK reference implementation |
| Gym Wars | 🚧 | v0.9 | Built and working, not just modeled — `getWarScore()` runs a real check-in `count()` query; a scheduled function auto-resolves an expired war and notifies both gyms |
| Invite codes, attribution & revenue share (Faz 6 §6.1/§6.5/§6.6) | 🚧 | v0.9.6 | QR/poster codes → signup attribution → manually-paid commission on a real Premium purchase; no individual identity ever reaches the gym, only aggregate counts |

Detail: [`GYM_ECOSYSTEM.md`](GYM_ECOSYSTEM.md).

## Coach & marketplace — built and live, not kill-switched

> ADR-012 planned to gate this behind a kill-switch for an M6 relaunch, same as gym (see that
> section above). In the current code, `FeatureFlags.coach` (→ `AppConfigService.isFeatureEnabled`)
> defaults to **enabled** and gates the same real entry points as the gym flag (side menu, Discover
> hub, quick actions, home role card) — nothing indicates it has ever been switched off. The 🔒 state
> below is retired for this domain too: read "M6" as the remaining go-to-market milestone (a real
> pilot, `BLK-09`/`S13` closing), not a code gate. The code kept advancing well past ADR-012's cut
> date, too — Faz 4 replaced the coach-facing AI report with a full server-authoritative consent
> system (below), and Faz 6 kept coach vanity-code commissions flowing through the same
> `applyReferral` path used for gym attribution.

| Feature | State | Since | Notes |
|---|---|---|---|
| Coach profiles, verification, vanity code | 🚧 | v0.8 | — |
| Application → admin approval → role flip | 🚧 | v0.8 | `BLK-05` closed and deployed — the admin surface is reachable now; no real coach application has been approved end to end against the live callables yet |
| Coach discovery — curation, 4 sorts, filters | 🚧 | v0.9 | — |
| Client management, at-risk detection, tiered consent-gated AI progress reports | 🚧 | v0.8 → rebuilt Faz 4 | The old unguarded client-side AI call (read another person's health data with zero consent check) is **deleted**. Replaced with a 4-tier (0-3) member-consent system + a server-authoritative `generateMemberProgressSummary` callable — re-verifies the relationship, rejects outright at tier 0, rate-limits to 1 generation/member/24h, never fetches a field above the granted tier. See `COACH_ECOSYSTEM.md` §4 |
| Coach reviews — immutable, transactional average | 🚧 | v0.8 | `S13` partially mitigated, not closed: the app now gates the "rate" button on a real linked-client relationship + a food-log anti-fraud check (`CoachReviewService.canReview`), but `firestore.rules`' create rule still has no relationship check — a write that bypasses the app is still ungated |
| Program marketplace — browse, enroll, track | ⛔ `BLK-09` | v0.8 | `coach_uid=='demo'` lets anyone publish — confirmed still present in `firestore.rules` |
| Paid programs | ❌ | — | Deliberately stubbed behind an honest banner |

Detail: [`COACH_ECOSYSTEM.md`](COACH_ECOSYSTEM.md).

## Monetization

| Feature | State | Since | Notes |
|---|---|---|---|
| Premium subscription — monthly / yearly | ⛔ `BLK-04` | v0.9 | Client + server complete; **no store products exist** |
| AI credit top-ups (consumable) | ⛔ `BLK-04` | v0.9 | Same |
| Server-side receipt validation + replay guard | 🚧 | v0.9.5 | Never run against a real store |
| Refund/expiry revocation webhooks | 🚧 | v0.9.5 | Pending store credentials |
| Referral — 6-char codes, 7-day trial both sides | 🚧 | v0.8 | Server-validated; **personal/coach-vanity codes only** — a `type:'gym'` code (Faz 6) does not grant a trial at all, it writes a `gym_attributions` record instead (see Gym ecosystem) |
| Referral & gym-attribution commissions | 🚧 | v0.8 → Faz 6 | `referral` (flat ₺5, granted the instant a personal/coach-vanity code is redeemed — tied to a free trial, not a real purchase) and `gymPremiumShare` (flat ₺/product, only after a real store-verified Premium purchase by an attributed user, accrues on every renewal, not just the first) — both server-write-only, both **tracking only, no payout rail** (`REF-04`). A genuine refund/chargeback now reverses a `gymPremiumShare` entry; the `referral` type is structurally exempt (never tied to a store purchase) |

Detail: [`PREMIUM.md`](PREMIUM.md).

## Growth & retention

| Feature | State | Since |
|---|---|---|
| Deep links — universal + custom scheme | 🚧 | v0.8 |
| Social sharing + shareable fitness card (PNG) | ✅ | v0.8 |
| "What's New" once-per-version sheet | ✅ | v0.9 |
| Coachmark tips, profile completeness card | ✅ | v0.9 |
| Meal reminders, streak-at-risk, weekly-plan-ready nudges | 🚧 | v0.9.5 |

## Personalization & Settings

> Added 2026-08-06 — this capability existed in code all along but had never been given its own
> section; it was previously buried as a single conflated row in Platform & compliance. The
> Settings screen (`lib/screens/profile/settings_screen.dart`, ~2,700 lines) is the hub for
> everything below.

| Feature | State | Notes |
|---|---|---|
| Live theme color — 4 presets, cross-device | ✅ | `ThemeProvider.setPrimaryColor` persists to `SharedPreferences` **and** the user's Firestore doc (`primary_color`), reloaded on sign-in on any device via `_listenToAuthChanges`. 4 swatches offered in Settings: brand orange `#F97300`, blue, green, pink. Read by `ThemeProvider.primaryColor` across dozens of screens app-wide (settings, food scan, cooking mode, AI insight cards, profile, notifications, AI fitness twin, community post cards, …). Free on every tier — no `Entitlements`/paywall gate found anywhere near it |
| Theme mode — light/dark | ✅ | `ThemeProvider.themeMode`; Settings' "Appearance" section exposes one dark/light `Switch`. `ThemeMode.system` is a value the provider can store/load, but no control in the current UI ever sets it — it's reachable in code, not in the product |
| Language switcher — EN/TR | ✅ | `LanguageProvider` + a flag/checkmark bottom sheet from Settings → Appearance → Language. Detail: `LOCALIZATION.md` |
| Notification preferences — mute by category | ✅ | `NotificationPreferencesService`, one Firestore map field (`notification_muted`). 7 user-facing groups (likes, comments, friends, system, referral, reminders, friend-at-gym presence) covering 15 of the app's 28 `NotificationType` values — the other 13 (achievement/streak-freeze grants, coach/gym application-lifecycle, level-up, gym attribution, plan-offer, …) are always-on and not user-mutable. **Two separate UI surfaces write the same field**: Settings' inline toggles cover 6 of the 7 groups (missing "presence"), and a distinct "Notification Preferences" sheet (a different row, same screen) covers all 7 — functionally fine since both hit the same field, but worth consolidating |
| Water reminder scheduling | ✅ | `PushNotificationService.scheduleDailyWaterReminder` / `spreadReminderTimes` — evenly spread across the user's configured wake/sleep window, timezone-correct, unit-tested (`test/water_reminder_schedule_test.dart`) |
| Meal reminder scheduling (breakfast/lunch/dinner) | 🚧 | Same local-notification service (`scheduleDailyMealReminders`), a simpler fixed-time path than water's spread algorithm; not covered by the water-reminder unit test |
| Dietary avoid-list | ✅ | `DietaryPreferencesScreen` → `FirestoreService.updateAvoidIngredients` — free-text ingredients a user excludes from AI-generated plans/recipes |
| OS font-scaling — respected, clamped | ✅ | `ScreenUtilService.getTextScaleFactor` reads the system text-scale and clamps it to 0.8×–1.3×; wired app-wide via a `MediaQuery` wrapper in `main.dart`, not just defined and unused |

Data export and account deletion also live in Settings; both are already tracked under
**Platform & compliance**'s GDPR export/erasure row below, not duplicated here.

## Admin & ops

| Feature | State | Since | Notes |
|---|---|---|---|
| Admin hub — categorized grid + nav drawer | 🚧 `BLK-05` | v0.9.5 | `BLK-05` closed 2026-08-01 — `syncAdminClaim` deployed & confirmed live (`firebase functions:list`), rules-tested end to end (`admin_roles/{uid}` → `isAdmin()` chain). Reachable now; no real admin session has exercised the 9-screen surface yet — nobody has been console-provisioned |
| User management — ban, role, force logout, reset | 🚧 `BLK-05` | v0.9 | Same — reachable, unverified by a real admin session |
| Application review (coach + gym) | 🚧 `BLK-05` | v0.8 | Same |
| Moderation queue + bulk takedown | 🚧 `BLK-05` | v0.8 | Same |
| Remote app config — models, gates, kill-switches | ✅ | v0.9.5 | Client **and** proxy, no redeploy |
| Maintenance mode + force-update gates | ✅ | v0.9.5 | The working incident levers |
| Cost & profit dashboard | 🚧 | v0.9.5 | AI cost real; Firebase cost estimated |
| Append-only audit log | 🚧 | v0.9 | — |
| Broadcasts | 🚧 | v0.9 | — |

## Platform & compliance

| Feature | State | Notes |
|---|---|---|
| EN/TR localization — 3,233 keys, exact parity, CI-gated | ✅ | Highest-quality subsystem in the project |
| Personalization — theme color, theme mode, language | ✅ | See **Personalization & Settings** above for the full breakdown |
| Design system — 26 components (16 base + 10 chat) over semantic tokens | ✅ | 152 hex + 230 `Colors.white/black` literals still leak in `lib/screens` outside the token layer (re-measured 2026-08-06, same `grep` methodology as the original 120/214 count — grown, not shrunk) |
| iOS + Android — Apple/Google sign-in, ATT, guards, haptics | 🚧 `BLK-02` | Code fix shipped and closed 2026-08-01 (`NSPhotoLibraryUsageDescription` added); physical-device confirmation still owed — Simulator-verified only |
| In-app legal docs (Privacy, Terms, KVKK, Açık Rıza) EN+TR | 🚧 | Drafted; **lawyer review pending** |
| Consent Center — per-purpose, versioned, withdrawable | ✅ | `ConsentService` — 8 purposes: health data, location, AI processing, cross-border transfer, analytics, notifications, marketing, gym presence |
| DSAR channel + admin queue | 🚧 `BLK-05` | `syncAdminClaim` deployed & confirmed live 2026-08-01 — the queue is technically reachable now; no real admin session has exercised it yet |
| GDPR export + account erasure | ⛔ `BLK-12` | Coverage incomplete |
| Age gating (min 16) | ✅ | Onboarding birth date |
| Hive AES-256 at rest | ✅ | Key in `flutter_secure_storage` |
| App Check | ⛔ `BLK-14` | Providers wired; **enforcement off** |
| Accessibility | 🚧 | `AccessibilityUtils` (reduce-motion/high-contrast/reduce-transparency helpers) called from ~10 widgets/screens, `Semantics` labels present in ~15 files; OS font-scaling is respected app-wide but clamped to 0.8×–1.3× (`ScreenUtilService`, wired in `main.dart`) — still no dedicated screen-reader, contrast, or touch-target audit pass |
| Crashlytics / Analytics / Performance | 🚧 | Consent-gated; **Crashlytics blinded by swallow-and-log** |
| Offline — Firestore persistence + Hive | 🚧 | No write queue, no conflict resolution |

## Not built

Integration & widget tests · rules tests in VCS · monitoring, alerting, SLOs · structured production
logging · staging environment · backups & DR · DI / service interfaces · full-text search · payout
rail · challenges (deliberately sunset) · white-label beyond a brand colour · auth
rate-limiting & MFA · migration framework · proxy load testing ·
API versioning · release obfuscation · tablet layouts · offline write queue · behavioural-analytics ML.

> **Correction:** this list previously included "XP/levels" — false as of Faz 5 §5.1. A
> server-authoritative XP/leveling system is built (see Social & community below); it was never
> retracted from this list when it shipped.

IDs in `TODO.md` §1.6. Build plans in [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md).

---

## Maintaining this file

- A new capability gets a row **and** a `README.md` update — same task.
- New code lands as **🚧**, never ✅. Promotion to ✅ requires demonstrating it works, and the same
  promotion in `PROJECT_STATE.md` §5.
- When a blocker closes, update the row's State **and** `PROJECT_STATE.md` §3.
- Never add a percentage or health score here.
