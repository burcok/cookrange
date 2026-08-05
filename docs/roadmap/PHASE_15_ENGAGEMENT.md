# Phase 15 — Daily Engagement Loop & Gamification — Product Roadmap

> Status: **Shipped, unevenly — verified 2026-08-05.** All six sub-phases have real, wired code;
> none of this doc is "not started" anymore. §15.1/15.3/15.4/15.6 are functionally complete with
> narrow, named gaps. §15.2 shipped a different card than this doc specifies (a 7-day sparkline, not
> the yesterday+trend+takeaway+CTA card the PM section describes). §15.5's achievement half is
> essentially complete against this doc's own proposed badge list; its streak-freeze "earn rules"
> were never built, and its two new notification types are dead code. See each §15.N's own
> **Verified** line for the specifics and file citations — do not assume 1:1 delivery from "shipped."
> Owner: product + engineering. Created: 2026-06-30.
> Governing rules: `CLAUDE.md` R0–R9 + Definition of Done. This doc is the single source of
> truth for Phase 15's original scope; `TODO.md` carries the checklist mirror.

---

## 0. The thesis — turn a "set-and-forget" app into a "open-it-daily" app

Cookrange today is feature-rich but **passive**: it plans and calculates, then waits for the user to
come back on their own. The six features below form a tight **daily loop** + a **gamification spine**
that gives users a reason to return every day and a reason to feel progress when they do. Crucially,
**most of the backend already exists** — this phase is mostly *wiring, UX, and one greenfield service*,
which is why it is high-leverage and genuinely shippable.

The single north-star metric: **D1/D7/D30 retention** of users who receive ≥1 reminder and open the
app. Secondary: daily-logging rate (meals logged / active day) and weekly-recap open rate.

### What already exists (verified against source — do NOT rebuild)
| Capability | Where | Implication for Phase 15 |
|---|---|---|
| Local + scheduled notifications, timezone-aware, ID-block reservation, `spreadReminderTimes()` pure fn | `push_notification_service.dart` (water reminder block `7001–7012`) | **Mirror** for meal/streak reminders (new ID blocks) |
| In-app structured notifications + presenter + mute groups | `notification_service.dart`, `notification_presenter.dart`, `notification_preferences_service.dart` | **Extend** enum + presenter + one new mute group |
| Cloud Functions: `broadcasts` collection + 5-min `drainScheduledBroadcasts` + `sendNotificationOnCreate` (mute-aware FCM) | `functions/index.js` | **Reuse** for server-side weekly-plan/streak fan-out |
| `streak_freeze_count` field + `onboarding_data.streak`, auto-consume on gap — now server-authoritative (`SEC-14`: `functions/progress.js`'s `processStreakLogin`); `grantStreakFreeze` deleted as dead code (0 callers), the 1-freeze welcome gift itself is unchanged | `firestore_service.dart`, `functions/progress.js` | Streak-freeze **backend done** → only UI + earn-rules missing |
| `TodaySummaryCard` (calories/streak/water/next-meal 2×2) | `home/widgets/today_summary_card.dart` | **Enhance**, don't replace — add yesterday + 7-day trend |
| Photo→nutrition flow: `analyzeFoodPhoto` → `NutritionEstimate` → `logScannedFood`, credit-metered | `food_scan_screen.dart`, `food_analysis_service.dart`, `food_log_service.dart` | One-tap photo log = **streamline** existing flow |
| Daily AI insight + risk detection + fitness-twin pattern (locale-aware, cached, persisted) | `ai_insight_service.dart`, `ai_insight_card.dart` | Weekly recap = **new method following the twin pattern** |
| `createPost(content, imageUrls, tags, {postType, metadata, authorRole, groupId})`, `PostType.{text,recipe,progress,meal}` | `community_service.dart`, `community_post.dart` | "Cooked it" = **new caller** of an existing API |
| Reputation score (`streak×2 + posts×5`), 5 tiers, cached on user doc | `reputation_service.dart` | Achievements **build on** this; tier-up = an achievement trigger |
| AI credit gate `checkAndConsume(uid, isPremium)` / `rollbackCredit(uid)` | `ai_credit_service.dart` | Every AI generation in this phase **must** meter + rollback |

### What is greenfield (net-new build)
- Achievement / badge model + service (`achievement_model.dart`, `achievement_service.dart`).
- `generateWeeklyRecap()` on `AiInsightService` + its persistence subcollection.
- Meal-time + streak-at-risk notification scheduling + their settings UI.
- "Cooked it" share button in the cooking finish sheet.

---

## 1. Recommended sequencing (dependencies first, ROI second)

The daily loop (15.1 + 15.2 + 15.3) delivers retention fastest; the gamification spine (15.5) is a
soft dependency for badges shown inside recaps/notifications, so its **model** lands early even though
its full surface ships later.

1. **15.5a — Achievement foundation** (model + service + streak-freeze UI). Foundation for badges referenced elsewhere.
2. **15.1 — Smart re-engagement notifications.** Highest retention ROI; pure wiring on existing infra.
3. **15.2 — Daily "Bugün" recap.** Local-only calc, no AI cost, instant value.
4. **15.3 — One-tap photo logging.** Removes the biggest logging-friction point.
5. **15.4 — Weekly AI coach recap.** "Wow" moment + premium justification.
6. **15.6 — "Pişirdim" community share** + **15.5b** badge surfacing (profile achievements grid).

Total realistic effort: **~3–4 focused weeks** for one developer, given how much is reuse.

---

## 2. Cross-cutting requirements (apply to EVERY item — R1/R4/R5/R6)

These are not per-feature footnotes; they are the Definition of Done for each sub-phase.

- **R1 Optimization:** no N+1 Firestore reads — batch/aggregate; recap uses one `getLogsForDateRange`
  call, not 7 day-queries. `const` constructors everywhere. New home card behind a `RepaintBoundary`.
  Streams cancelled in `dispose`. Local-calc cards must not trigger AI. Cache recap results
  (SWR: show cached, refresh in background).
- **R4 Logging:** every new service method logs via `debugPrint` (dev) + routes real failures to
  `CrashlyticsService` with `{screen, uid, operation}`. AI calls log input hash + outcome. No silent
  `catch {}`. Notification scheduling logs the computed times.
- **R5 Platform + motion:** iOS + Android parity (notification permission already primed via
  `PermissionService`; exact-alarm not required — `inexactAllowWhileIdle`). Haptics on
  achievement-earned and share. All animations 60fps, intentional curves from `AppMotion`, and
  **reduced-motion aware** (gate `AnimationController`s, fall back to `AnimatedOpacity`/instant).
  Respect safe areas in any new sheet.
- **R6 Theme + i18n:** zero hardcoded colors — `AppPalette`/`context.palette` + DS components only.
  **Every** new user-visible string ships EN + TR **simultaneously** (R9: one-key-group-at-a-time via
  a Python `json.load→mutate→dump`, never parallel writes). `test/i18n_parity_test.dart` must stay green.
- **R7 States:** every new surface defines loading (skeleton, not bare spinner), empty, error, and
  success states using `AppSkeleton*`/`AppEmptyState`/`AppErrorState`/`AppSnackBar`.
- **AI credits:** any feature that calls the model goes through `checkAndConsume` → on failure
  `rollbackCredit`; show `AiCreditsSheet` when exhausted. Local-calc features (15.2) cost **0** credits.
- **Legal (COMPLIANCE.md):** no new PII storage. Recaps/notifications read data the user already owns.
  Notification scheduling is opt-out per group; defaults documented below.

---

## 15.1 — Smart Re-engagement Notifications · High impact · Medium effort

**Verified 2026-08-05 — shipped, two mechanisms swapped, two gaps.** All three types exist end to
end: enum (`notification_model.dart:33-35`), the `reminders` mute group
(`notification_preferences_service.dart:40-44`, mirrored in `functions/index.js:489-491`), full
presenter cases, local meal-reminder scheduling + a settings sheet
(`push_notification_service.dart:222-273`, `settings_screen.dart:338-424`, id block `8001-8008` as
specified). Streak-at-risk and weekly-plan-ready shipped as two dedicated `pubsub.schedule` Cloud
Functions (`functions/index.js:1094` `streakAtRiskNotifier`, `:1159` `weeklyPlanReadyNotifier`)
instead of this doc's proposed `broadcasts`-row design — same server-side suppression outcome
(checks `food_logs` for today before sending), different mechanism. Two real gaps: there is no
`onboarding_data.streak_reminder` settings entry — streak-at-risk has no user-configurable time, just
the shared `reminders` mute toggle, and fires at a fixed `17:00 UTC` for every user rather than a
per-user local evening time; the "cancel today's already-logged meal reminders on resume" client
guard this doc's Dev section asks for was never built. **Flagged, not fixed:**
`weeklyPlanReadyNotifier` queries `onboarding_completed == true` (`functions/index.js:1166-1167`),
not `meal_plan_generated == true` as this doc specifies — it pushes "your weekly meal plan is ready"
to every onboarded user, including ones who never generated a plan.

### PM
**Problem:** users forget to log and silently churn. **Solution:** three gentle, mutable nudges that
respect the user's day. **User stories:**
- *Meal-time reminder:* "It's ~12:30, log your lunch" — fires at user-configured meal windows.
- *Streak-at-risk:* "Don't break your 12-day streak 🔥 — you haven't logged today" — fires once in the
  evening only if (a) streak ≥ 2 and (b) no food log today.
- *Weekly-plan-ready:* "Your new week of meals is ready" — Sunday evening, only for users with a plan.

**Edge cases:** night-shift wake/sleep windows (handled by `spreadReminderTimes`); user logged before
the nudge → suppress (server-side check in broadcast / client guard); muted group → never send;
timezone changes; notification permission denied (no schedule, surface a soft prompt once).
**Success metric:** % of nudged users who open + log within 2h.

### Architect
- **Notification types:** add `mealReminder`, `streakAtRisk`, `weeklyPlanReady` to `NotificationType`
  (`notification_model.dart`) — backward-compatible, append only.
- **Mute group:** add `reminders` group to `NotificationPreferencesService.preferencePairs`
  (maps the 3 new types) + mirror in `functions/index.js` `typeToMuteGroup`.
- **Local vs server tier (R3):**
  - *Meal-time reminders* → **local** scheduled (`zonedSchedule`, daily repeat), ID block
    `8001–8008`. No server cost, works offline. Configured on device.
  - *Streak-at-risk* → **local** evening check is unreliable (needs "did they log today?"). Use a
    **local** daily reminder at user's evening time that the app **cancels** at next launch if a log
    exists; OR (preferred) a **server** `broadcasts` row evaluated by `drainScheduledBroadcasts` that
    queries today's logs before sending. Decision: **server-side** (accurate suppression). ID: n/a (FCM).
  - *Weekly-plan-ready* → **server** scheduled broadcast (Sunday 19:00 local-ish), queries users with
    `meal_plan_generated == true` + reminders not muted.
- **Settings storage:** mirror `water_reminder` shape under `onboarding_data.meal_reminder`
  `{enabled, times:[\"08:00\",\"12:30\",\"19:00\"]}` and `onboarding_data.streak_reminder`
  `{enabled, time:\"20:00\"}`. Written via `FirestoreService.updateUserData`, merged into `UserProvider`.
- **Indexes/rules:** broadcasts already ruled; streak-at-risk query (`food_logs` by date) is owner-only,
  no new index (date-equality on a subcollection). Document any new composite if the server query needs it.

### Dev
- `PushNotificationService`: `scheduleDailyMealReminders({required List<String> times, ...})`,
  `cancelMealReminders()` (cancel block 8001–8008), reusing `_nextInstanceOfTime`.
- `NotificationPresenter`: add `titleFor/bodyFor/categoryFor/iconFor/colorFor` cases for the 3 types.
- `settings_screen.dart`: `_showMealReminderSheet()` + `_showStreakReminderSheet()` mirroring
  `_showWaterReminderSheet()` (AppSheet, time pickers, AppToggle, AppButton, AppSnackBar.success).
- `functions/index.js`: weekly-plan + streak-at-risk broadcast producers (cron-scheduled function that
  enqueues `broadcasts` rows) + the suppression query in the streak case.
- Client guard: on app resume, cancel today's pending meal reminders whose meal type is already logged.

### i18n keys (EN+TR)
`notifications.feed.meal_reminder_title/body`, `..streak_at_risk_title/body`,
`..weekly_plan_ready_title/body`; `notifications.feed.cat_reminder`; `settings.reminders.meal_*`,
`settings.reminders.streak_*`; `notification_prefs.reminders`.

### Docs to update on completion
`docs/SERVICES.md` (PushNotificationService + functions), `docs/DATABASE.md`
(onboarding_data reminder fields, NotificationType, `broadcasts`), `docs/LOCALIZATION.md` (key groups),
`docs/PLATFORM.md` (notification behavior), `CLAUDE.md` Key Services, `TODO.md`.

---

## 15.2 — Daily "Bugün" Recap Card · High impact · Low–Medium effort · 0 AI credits

**Verified 2026-08-05 — shipped, but a different card than this section specifies.**
`home/widgets/bugun_recap_card.dart` (`BugunRecapCard`) is wired into `home.dart:877`, sitting
between `AiInsightCard` and `TodaySummaryCard` exactly as planned; it computes from one
`FoodLogService.getLogsForDateRange` call (`bugun_recap_card.dart:87-88`), caches via a SharedPrefs
SWR snapshot (`_kCachePrefix = 'bugun_recap_'`), and defines skeleton/empty/success states — the
Architect spec is met almost exactly (this resolves `TODO.md`'s own `HOME-05`, which flagged this
card as "status disputed" pending exactly this check). What actually renders is a 7-day kcal
sparkline + avg/target stat row — not the yesterday-specific reflection card with trend arrows
(up/down/flat), a plain-language takeaway, or the "Plan today's meals" CTA the PM section below
describes, and there is no tap-through. None of `home.recap.yesterday`/`trend_up`/`trend_down`/
`trend_flat`/`cta_plan`/`takeaway_over`/`takeaway_under`/`takeaway_on_target` exist in `en.json`/
`tr.json` — the real keys are `home.recap.title/avg/target/days_logged/today_short/empty_title/
empty_subtitle`.

### PM
**Problem:** opening the app gives no "here's where you stand" moment. **Solution:** a glanceable card
that summarizes *yesterday* and the *7-day trend*, with one plain-language takeaway and a forward CTA
("Plan today's meals"). Distinct from `TodaySummaryCard` (which is *today's live* numbers) — this is
*reflection + momentum*. **Edge cases:** brand-new user (no history → encouraging empty state, not a
sad zero); no logs yesterday (gentle "let's start today"); first day after install.
**Success metric:** card tap-through to logging/plan.

### Architect
- **Tier (R3):** pure **local computation** — `FoodLogService.getLogsForDateRange(uid, day-7, today)`
  in **one** call; aggregate client-side. **No AI, no new collection.** Cache the computed summary in
  memory for the session + a SharedPrefs snapshot (`bugun_recap_YYYY-MM-DD`) for instant cold-start
  paint (SWR).
- **Placement:** `home.dart` between `AiInsightCard` and `TodaySummaryCard` (after line ~836).
- **Data:** yesterday totals, 7-day avg calories vs target, streak state, trend direction (up/down/flat).

### Dev
- New widget `home/widgets/bugun_recap_card.dart` (`AppGlassCard` + a tiny 7-bar sparkline painter,
  reusing the `BarChartPainter` approach from nutrition analytics; `RepaintBoundary`-wrapped).
- Home: compute `_recapSummary` once in `initState`/stream callback; pass to the card. Stream-driven so
  it updates if yesterday's late log lands.
- States: skeleton while computing, encouraging empty state for no-history users.

### i18n keys (EN+TR)
`home.recap.title`, `home.recap.yesterday`, `home.recap.avg_7d`, `home.recap.trend_up/down/flat`,
`home.recap.cta_plan`, `home.recap.empty`, `home.recap.takeaway_over/under/on_target`.

### Docs to update
`docs/FRONTEND.md` (home card order), `docs/FEATURES.md`, `docs/LOCALIZATION.md`, `TODO.md`.

---

## 15.3 — One-Tap Photo Food Logging · High impact · Low–Medium effort

**Verified 2026-08-05 — shipped as specified.** `MealTimeUtil.mealTypeForHour`
(`lib/core/utils/meal_time_util.dart`) is the shared util this doc asked for.
`FoodScanScreen(expressPhoto: true)` (`food_scan_screen.dart:34-95`) auto-opens the camera on mount,
auto-detects meal type from the hour, defaults portion ×1, and reuses the identical credit-gated
analysis/logging path (`_analyzePhoto`, same `checkAndConsume`/`rollbackCredit` dance as the text
path). Home's "Snap & Log" button (`home.dart:1083-1103`, `food_scan.express_snap_btn`) is gated on
`FoodAnalysisService().isPhotoAvailable` exactly as specified. Two minor nuances, not functional
breaks: home's own `_nextMealName` (`home.dart:191-198`) was never switched over to `MealTimeUtil` —
it still duplicates the hour-bucket logic independently (the two happen to agree on every real hour,
so not a live bug, just not the single source of truth this doc's Architect section asked for); there
is no distinct "low confidence" hint copy, only the pre-existing generic confidence-percentage
display reused as-is.

### PM
**Problem:** the photo→log path exists but takes too many taps (open scan → switch to photo tab → pick →
analyze → choose meal → adjust portion → log). **Solution:** a "Snap & Log" express path: one tap on
home opens the camera directly, auto-detects meal type by time of day, defaults portion ×1, shows the
estimate with a single prominent **Log** button (portion/meal-type still editable, just not required).
**Edge cases:** vision model not configured (`isVisionAvailable == false` → hide express entry, keep
text path); credits exhausted (`AiCreditsSheet`); low-confidence estimate (surface confidence + "edit"
nudge); permission denied (existing `PermissionService` primer).
**Success metric:** photo logs per active user; taps-to-log reduced.

### Architect
- **Reuse, don't rebuild:** `analyzeFoodPhoto` → `NutritionEstimate` → `logScannedFood` already exist
  and are credit-metered. This is a **new entry mode**, not a new pipeline.
- **Auto meal type:** lift the existing `_nextMealName` hour logic into a shared
  `MealTimeUtil.mealTypeForHour(int)` so home, scan, and reminders agree.
- **Tier:** AI (vision) → must `checkAndConsume`/`rollbackCredit` (already wired in scan screen — keep
  identical gating in the express path).

### Dev
- `food_scan_screen.dart`: add a constructor flag `expressPhoto: true` (or a thin
  `QuickPhotoLogSheet`) that boots straight into camera, pre-sets `_selectedMealType` from the hour and
  `_portionFactor = 1.0`, and emphasizes the Log button. Reuse all existing analysis/logging code.
- Home: add a "Snap & Log" affordance (camera glyph on/near the existing Scan button or quick-actions),
  gated by `FoodAnalysisService().isPhotoAvailable`.
- States already handled by the scan screen; ensure express path inherits skeleton/error/empty.

### i18n keys (EN+TR)
`food_scan.express_title`, `food_scan.snap_and_log`, `food_scan.auto_meal_hint`,
`food_scan.low_confidence_hint`.

### Docs to update
`docs/FEATURES.md` (food analysis), `docs/SERVICES.md` (MealTimeUtil if added), `docs/FRONTEND.md`,
`docs/LOCALIZATION.md`, `TODO.md`.

---

## 15.4 — Weekly AI Coach Recap · High impact · Medium effort · premium lever

**Verified 2026-08-05 — shipped as specified; already reflected in `docs/FEATURES.md`'s "Weekly AI
recap" row.** `AiInsightService.generateWeeklyRecap` (`ai_insight_service.dart:391-521`) follows the
fitness-twin pattern exactly: Firestore-cached idempotent per week+locale, `<3` logged days or
`!isConfigured` → a free fallback recap, persisted to `users/{uid}/ai_weekly_recaps` (rule at
`firestore.rules:1517-1519`, mirrors `ai_twin_projections` verbatim as specified). Credit-gated with
rollback on failure/quota exceptions (`weekly_recap_screen.dart:60-109`), share via `share_plus`
(`:571`), and a home teaser card (`weekly_recap_card.dart`). One gap: the "Monday notification
deep-link" entry point this doc's Dev section asks for does not exist — there is no dedicated "your
recap is ready" push notification anywhere in `functions/`; the only Monday-morning push is §15.1's
unrelated `weeklyPlanReadyNotifier` (about meal plans, not the AI recap). The home card is the only
entry point that actually exists.

### PM
**Problem:** the AI investment isn't visible enough; users don't get a "coach who noticed my week."
**Solution:** every Monday, a personalized recap: consistency score, one win + one challenge, weight
trend, and one concrete recommendation for the coming week — generated from the last 7 days of logs.
Shareable (ties into social). **Edge cases:** too little data (< 3 logged days → encouraging
low-data variant, no wasted AI call); AI unavailable (`isConfigured == false` → graceful fallback
recap from local stats); locale (TR users get TR recap). **Success metric:** recap open + share rate;
premium conversion from the recap CTA.

### Architect
- **Method:** `AiInsightService.generateWeeklyRecap(UserModel user, {String locale})` following the
  **exact `generateFitnessTwin` pattern** (locale instruction in prompt, `generateJson`, typed parse,
  `unawaited` persistence).
- **Persistence (R3):** new owner-only subcollection `users/{uid}/ai_weekly_recaps/{weekKey}`
  (`weekKey = YYYY-MM-DD` Monday) — `{locale, generatedAt, payload, inputsHash}`. Idempotent per week
  (don't regenerate if a recap for this `weekKey`+locale exists and inputs unchanged → SWR).
- **Trigger:** server `broadcasts`/scheduled function nudges "recap ready" Monday AM; the heavy AI call
  runs **client-side on open** (keeps the key/credit model intact) OR is precomputed — decision:
  **client-side on first open of the week**, metered via `checkAndConsume`. Notification is just the
  doorbell.
- **Rules:** add `ai_weekly_recaps` owner-only read/write to `firestore.rules` (mirror
  `ai_twin_projections`). No composite index needed (single-collection, ordered by `generatedAt`).
- **Credits:** 1 credit per generation; `rollbackCredit` on failure; fallback variant costs 0.

### Dev
- `ai_insight_service.dart`: `generateWeeklyRecap` + `_fallbackWeeklyRecap` + `_saveWeeklyRecap` +
  `getLatestWeeklyRecapStream(uid, locale)`.
- New screen `screens/ai/weekly_recap_screen.dart` (DS hero, score ring reuse, win/challenge cards,
  trend sparkline, recommendation, **Share** via `SharingService`). Loading skeleton, error retry,
  low-data empty state.
- Entry points: Monday notification deep-link + a card slot on home (auto-shows once per week, dismissible).
- `firestore.rules`: `ai_weekly_recaps` owner rule (single-file owner per R9).

### i18n keys (EN+TR)
`ai.weekly_recap_title`, `..consistency_score`, `..your_win`, `..your_challenge`, `..recommendation`,
`..share`, `..low_data`, `..weight_trend`, `notifications.feed.weekly_recap_ready_title/body`.

### Docs to update
`docs/SERVICES.md` (AiInsightService + functions), `docs/DATABASE.md` (`ai_weekly_recaps` +
rules), `docs/FRONTEND.md` (new screen + route), `docs/FEATURES.md`, `docs/LOCALIZATION.md`,
`CLAUDE.md` (Key Services + Firestore collections), `TODO.md`.

---

## 15.5 — Streak Freeze UI + Achievements / Badges · Medium–High impact · Medium effort

**Verified 2026-08-05 — achievements half essentially complete, streak-freeze "earn rules" never
built, two notification types confirmed dead.** The catalog (`achievement_model.dart:9-152`,
`kAchievementCatalog`) has 15 keys. All 6 badges this doc proposes exist under matching or
near-matching names: `firstMealLogged`→`first_meal`, `firstPhotoLog`→`first_photo`,
`firstPost`→`first_post`, `firstCook`→`first_cook`, `streak7/30/100`→`streak_7/30/100`; "reputation
tier-ups" shipped as 4 distinct badges (`tierActive/Contributor/Expert/Legend`) rather than this
doc's single generic `tier_up` key — finer-grained than proposed, not a gap. The other 4 keys
(`level50`, `groupTop3`, `groupStreak4`, `gymRegular`) are unrelated later work (Faz 5 §5.3) layered
onto the same catalog — not part of this doc's scope; see `docs/DATABASE.md`'s `achievements` row for
that half. `AchievementsGrid` (`screens/profile/widgets/achievements_grid.dart`) is wired into
`profile_screen.dart:573`: earned/locked tiles, a reduced-motion-aware unlock animation
(`MediaQuery.disableAnimations`), a detail sheet — matches the Dev spec closely. The freeze count IS
shown via a snowflake glyph on the home streak chip (`StreakChip`, `streak_calendar_sheet.dart:
112-135`, rendered at `home.dart:955`) exactly as asked. **Not built:** the "ways to earn freezes
(milestones, premium grant)" the PM section asks for — `TODO.md`'s own `GAM-06` independently found
the same thing ("the UI shipped, the earn rules did not"); `grantStreakFreeze` was only ever called
for the one-time welcome gift, and has since been deleted outright as dead code (`SEC-14`) — the
welcome gift itself is unchanged, written inline by `handleUserLogin`'s new-user branch; any future
earn-rules work needs a new server-side grant path (`GAM-06`). **Confirmed broken, flagged not fixed:**
`NotificationType.achievementEarned` and `.streakFreezeUsed` have full enum/presenter/push-text
support (`notification_model.dart:31-32`, 5 presenter switch statements, `functions/index.js:
576-580`) but are never actually triggered — every `writeNotification(db, {...})` call site across
all of `functions/*.js` (15 checked) was read; none passes either type. `grantAchievementIfNew`
(`functions/progress.js:384-395`) awards XP on a new badge but never notifies. **Fixed (`SEC-14`):**
`streak_freeze_count` was absent from `touchesProtectedUserFields()`'s denylist entirely — unlike the
structurally identical `group_top3_streak` counter entry — and `onboarding_data.streak` was also
client-writable (nested inside the otherwise-legitimately-client-writable `onboarding_data` map
alongside `meal_reminder`/`water_reminder`, so closing it needed its own `onboardingStreakChanged()`
diff helper rather than a blanket denylist entry — see `firestore.rules`). Both fields are now
server-write-only, written only by the new `processStreakLogin` Cloud Function
(`functions/progress.js`); `users/{uid}`'s `allow create` is also now bounded so a client can't
self-create a doc with either field pre-inflated. Not yet deployed to the live project; no
reconciliation pass exists for values a user may have already inflated before this fix landed.

### PM
**Problem:** streaks reset harshly (churn trigger) and there's no collectible sense of progress.
**Solution (two parts):**
- **(a) Streak freeze** — surface the *already-working* freeze mechanic: show freeze count, a "freeze
  used" celebration when it saves a streak, and ways to earn freezes (milestones, premium grant).
- **(b) Achievements** — a small, tasteful badge system (first meal logged, 7/30/100-day streak,
  first cook, first post, reputation tier-ups, first photo log) shown as a profile grid with
  earned/locked states + an unlock animation/snackbar.
**Edge cases:** double-grant (idempotent earn), retroactive grants for existing users (backfill on
first open), locked-state copy. **Success metric:** streak-survival rate; achievements earned per user.

### Architect
- **Streak freeze backend is done** (`streak_freeze_count`, auto-consume). Work is
  **UI + earn rules** only. Add `NotificationType.streakFreezeUsed` (optional) for the save moment.
  (Historical note: `grantStreakFreeze`, named here at proposal time, was dead code — 0 callers beyond
  the welcome gift — and has since been deleted; server-side computation moved to `processStreakLogin`
  as part of `SEC-14`. Any new earn-rules grant path needs a new Cloud Function, not this name.)
- **Achievements (greenfield):**
  - Model `achievement_model.dart`: `id, key, titleKey, descKey, icon/emoji, type, pointsAwarded,
    earnedAt`. Definitions live in a static catalog (code constant) — no remote config needed for v1.
  - Service `achievement_service.dart`: `earn(uid, key)` (idempotent — writes
    `users/{uid}/achievements/{key}` only if absent), `getAchievementsStream(uid)`, `checkAndGrant(uid)`
    (evaluates eligibility from existing signals: streak, postCount, reputation tier, food-log count).
  - **Tier (R3):** earned achievements → **Firestore** (cross-device, auditable). Catalog → in-code.
  - **Hooks (no new N+1):** call `checkAndGrant` opportunistically after existing successful operations
    (login streak update, `logRecipe`/`logScannedFood`, `createPost`, reputation recompute) via
    `unawaited` — never block the UI path.
  - **Rules:** `users/{uid}/achievements/{id}` owner read; **write owner-only but validated** (or via a
    Cloud Function if we want anti-cheat — v1: client write owner-only, documented as a known soft spot
    like `member_count`).
- **Indexes:** none (small per-user subcollection, no cross-user query in v1).

### Dev
- `home`/profile: streak chip shows freeze count (snowflake glyph); "freeze used" banner reusing the
  milestone-banner pattern.
- `screens/profile/widgets/achievements_grid.dart`: earned/locked tiles, unlock animation
  (reduced-motion aware), tap → detail sheet. Entry from profile.
- `achievement_service.dart` + `achievement_model.dart` + catalog constant.
- Wire `unawaited(AchievementService().checkAndGrant(uid))` into the existing success paths listed above.
- `firestore.rules`: `achievements` subcollection owner rule.
- Backfill: on first open post-update, run one `checkAndGrant` so existing users earn what they've
  already qualified for.

### i18n keys (EN+TR)
`achievements.title`, `achievements.locked`, `achievements.earned_on`, per-badge
`achievements.<key>.title/desc` (first_meal, streak_7/30/100, first_cook, first_post, tier_up,
first_photo_log…), `streak.freeze_count`, `streak.freeze_used_title/body`.

### Docs to update
`docs/SERVICES.md` (AchievementService), `docs/DATABASE.md` (achievements subcollection + rules +
NotificationType), `docs/FRONTEND.md` (achievements grid + profile), `docs/FEATURES.md`,
`docs/LOCALIZATION.md`, `CLAUDE.md` (Key Services + collections), `TODO.md`.

---

## 15.6 — "Pişirdim / I Cooked This" Community Share · Medium impact · Low effort

**Verified 2026-08-05 — shipped; the R4/R7 error-path polish this doc asks for is missing.** The
finish sheet's "Share to Community" toggle + optional caption (`cooking_mode_screen.dart:298-419`)
calls `CommunityService().createPost(..., postType: PostType.meal, metadata: {has_cooked_badge:
true, ...})` on the Log & Finish tap (`:505-538`); `glass_post_card.dart:329-330,1004-1039` renders
the 🍳 pill via `community.cooked_it_badge`. The `first_cook` achievement hook is wired, but
indirectly — not from this screen, but because `FoodLogService.logRecipe`
(`food_log_service.dart:101-111`, called by the same tap) already reports `justCookedAndLogged: true`
for its own reasons (Faz 5 XP). Two confirmed gaps: the share `createPost` call is `unawaited` inside
a bare `try {} catch (_) {}` that only resets the button's loading flag on failure — no
`debugPrint`/Crashlytics, no error snackbar, no retry (`:505-550`, an R4 silent-catch); there is no
success snackbar or haptic on a successful share either, despite `cooking.share_success`/
`cooking.share_error` keys existing in both `en.json` and `tr.json` with zero references anywhere in
`lib/` — evidence a snackbar was drafted and never wired up, not that it was never planned. The
metadata written is also narrower than this doc's proposed shape: no `cooked_at`, `meal_type`,
`calories`, `protein`, `carbs`, or `fat`, only `has_cooked_badge`/`recipe_title`/`recipe_id`/
`image_url`.

### PM
**Problem:** cooking mode and the social feed are disconnected; finishing a recipe is a perfect
"brag moment" that currently goes nowhere. **Solution:** a third action in the cooking finish sheet —
**Share to Community** — that one-taps a `PostType.meal` post with the recipe image and a "cooked it"
badge. Optionally also logs the meal (compose with existing Log & Finish). **Edge cases:** private
account (still allowed to post — it's their feed); no recipe image (upload from a default or skip
image); offline (queue/snackbar). Earns the `first_cook` achievement (ties to 15.5).
**Success metric:** posts created from cooking mode; feed liveliness.

### Architect
- **Reuse:** `CommunityService.createPost(content, imageUrls, tags, postType: PostType.meal,
  metadata: {...})` + `StorageUploadService.uploadPostImage`. No new collection, no new model.
- **Metadata:** `{recipe_id, recipe_title, cooked_at, meal_type, calories, protein, carbs, fat,
  has_cooked_badge: true}` (matches the existing meal-post metadata convention).
- **Image:** if `recipe.imageUrl` is a network asset, the post can reference it directly or re-host via
  `uploadPostImage`; decision: reference existing URL when present (no re-upload), else skip image.
- **Tier:** Firestore (it's a social post). No AI, no credits.

### Dev
- `cooking_mode_screen.dart` `_showFinishSheet`: add a "Share to Community" button + optional caption
  field; on tap → `createPost(...)` → `AppSnackBar.success` + haptic; `unawaited` achievement check.
- `glass_post_card.dart`: render a small "🍳 Cooked it" pill when `metadata['has_cooked_badge'] == true`.
- States: posting spinner on the button, error snackbar with retry.

### i18n keys (EN+TR)
`cooking.share_to_community`, `cooking.share_caption_hint`, `cooking.shared_success`,
`community.cooked_it_badge`.

### Docs to update
`docs/FEATURES.md` (cooking + community), `docs/SERVICES.md` (CommunityService caller note),
`docs/FRONTEND.md`, `docs/LOCALIZATION.md`, `TODO.md`.

---

## 3. New Firestore surface summary (for `DATABASE.md` + `firestore.rules`)

| Path | Purpose | Rules | Index |
|---|---|---|---|
| `users/{uid}/ai_weekly_recaps/{weekKey}` | Weekly AI recap payloads (owner-only) | owner R/W (mirror `ai_twin_projections`) — **built as specified**, `firestore.rules:1517-1519` | none |
| `users/{uid}/achievements/{key}` | Earned badges (owner-only) | **built tighter than v1 called for**: owner read, but `allow write: if false` (`firestore.rules:1526-1529`) — server/Admin-SDK only from day one (`syncProgress`/`backfillProgress`), not the client-owner-write this row proposed | none |
| `users/{uid}.onboarding_data.meal_reminder` | `{enabled, times[]}` | existing user-doc rule — **built as specified** | — |
| `users/{uid}.onboarding_data.streak_reminder` | `{enabled, time}` | **not built** — streak-at-risk shipped as a server cron with no per-user time, so this field never got written; see §15.1 | — |
| `broadcasts/{id}` (reuse) | Server-scheduled weekly-plan / streak-at-risk fan-out | **not the mechanism used** — both shipped as dedicated `pubsub.schedule` functions instead; see §15.1 | existing |
| `NotificationType` additions | `mealReminder, streakAtRisk, weeklyPlanReady, streakFreezeUsed` (+ optional) | all 4 exist (`notification_model.dart:31-35`), plus `achievementEarned` (not listed here); `streakFreezeUsed`/`achievementEarned` are wired but never actually sent — see §15.5 | — |

**R9 reminder:** `firestore.rules`, `firestore.indexes.json`, `en.json`, `tr.json` are
**single-owner-per-turn** shared files. When implementing in parallel, serialize all writes to these.

---

## 4. Definition of Done — Phase 15
☑ Each of 15.1–15.6 satisfies R0–R7 + the §2 cross-cutting list · ☑ All AI paths metered + rollback,
local-calc paths cost 0 credits · ☑ New Firestore paths have owner-only rules; any new query has its
index · ☑ Every new string EN+TR, parity test green · ☑ Loading/empty/error/success states for every
new surface · ☑ iOS+Android, light+dark, 60fps, reduced-motion · ☑ `flutter analyze lib/` 0 errors ·
☑ Owning `docs/` files + `CLAUDE.md` + `TODO.md` updated in the same task as the code (R8).
