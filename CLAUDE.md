# Cookrange — AI Engineering Guide

> AI-powered nutrition & fitness app. Flutter (iOS + Android) + Firebase backend.

---

## 📖 START HERE — The Documentation System

This file holds the **rules** (R0–R9 + Definition of Done). Two companions hold the rest:

- **`AGENTS.md`** — *how to work*: the mandatory per-prompt workflow, the pre-flight checklist,
  anti-drift constraints, and the "keep docs in sync" golden rule. **Read it before any task.**
- **`ARCHITECTURE.md`** — *how the system fits together*: layers, data flow, directory map.
- **`docs/`** — *where everything is* (so you don't grep blind): `DATA_MODEL.md`, `SERVICES.md`,
  `FRONTEND.md`, `DESIGN_SYSTEM.md`, `FEATURES.md`, `PLATFORM.md`, `LOCALIZATION.md`,
  `COMPLIANCE.md`, `roadmap/GO_LIVE.md`, `roadmap/FUTURE_FEATURES.md`. Index: `docs/INDEX.md`.

> ⚖️ **Legal-first is non-negotiable.** Data security + KVKK/GDPR compliance are release blockers.
> Any feature touching personal data must pass the Legal & Privacy checklist (`AGENTS.md` §2) and the
> framework in `docs/COMPLIANCE.md`: disclose purpose + consent *before* access, minimize (prefer
> transient/on-device over storage), and never store more than needed. Reference impl: the
> "gyms near me" consent gate (location used on-device, not stored).

**The loop every prompt:** classify the task → read the relevant `docs/` file → think in 3 roles
(R0) → satisfy the pre-flight checklist (`AGENTS.md` §2) → make the smallest correct change →
`flutter analyze lib/` (0 errors) → **update the `docs/` file you just made stale.** When you change
code, the doc that covers it (and `CLAUDE.md`/`TODO.md` if scope/status changed) must change in the
same task — code is truth, docs must not drift.

---

## 🔱 GLOBAL ENGINEERING RULES (NON-NEGOTIABLE — APPLY ON EVERY PROMPT)

> These rules are **always active**. They are not optional, not per-task. Every feature, fix,
> refactor, and design change must satisfy **all** of them. After completing any work, **update
> this section and `TODO.md`** so the rules and roadmap stay current for future prompts.

### R0 — Multi-Role Mindset (think as a team, not a coder)
Before writing code for any non-trivial feature, reason through it from three perspectives, in order:
1. **Product Manager** — What problem does this solve? What's the user story, the edge cases, the
   success metric, the "even better than expected" version? Define scope before touching code.
2. **Senior Architect** — Data model, collection/table shape, indexes, caching tier, security
   rules, migration/seed needs, failure modes, scalability. Decide the *right* structure, not the
   quick one. Identify the optimal implementation order (dependencies first).
3. **Senior Developer** — Implement cleanly: idiomatic, optimized, tested against analyze, matching
   surrounding conventions. Smooth UX, full platform + theme + i18n coverage.

For large/multi-part features, you may delegate these roles to parallel sub-agents (PM agent,
architect agent, dev agent) and synthesize. Always produce the **most optimal, professional**
result — aim to exceed the expected outcome, not just meet it.

### R1 — Optimization is mandatory, always
Every feature/fix must be the **most optimized** version reasonable: no N+1 reads, batch/transaction
where applicable, `const` constructors, lazy/paginated lists, `RepaintBoundary` for heavy widgets,
debounced inputs, cancelled subscriptions in `dispose`, image caching, minimal rebuilds
(`Selector`/`ValueListenableBuilder` over broad `watch`). Never ship an obviously slower path.

### R2 — Data layer discipline (decide it deliberately)
For anything touching data, the **architect role decides** and you implement end-to-end:
- **Where data lives** — choose the correct tier per the R3 caching policy.
- **Firestore shape** — collection path, doc schema, and **composite/single-field indexes** added to
  `firestore.indexes.json` whenever a query needs them. Add **security rules** to `firestore.rules` /
  `storage.rules` for every new path. Never leave a collection unguarded.
- **Seed / dump / one-time setup** — if a feature needs reference data (categories, dishes, presets),
  provide a one-time idempotent seeder (pattern: `seedIfEmpty()`), or a documented one-shot script in
  `lib/scripts/`. If a one-time table/collection or backfill is required, build it and note it in `TODO.md`.
- **Migrations** — versioned, idempotent, logged. Never silently mutate user data.

### R3 — Caching policy (pick the right tier every time)
Decide consciously for each piece of state — never default blindly:
- **In-memory (service singleton / provider)** — hot, session-scoped, cheap to recompute
  (e.g. current meal plan, unread counts). Fastest; lost on restart.
- **Local app storage (Hive / SharedPreferences)** — device-scoped, must survive restart but not
  cross-device (settings, theme, draft input, offline cache, last-synced snapshot).
- **Firestore (server)** — source of truth, cross-device, multi-user, or auditable
  (profile, logs, social, subscription). Always the authority; cache reads locally when it helps UX.
Prefer **stale-while-revalidate**: show cached instantly, refresh in background, reconcile.

### R4 — Logging at the highest level everywhere
Every service method, async boundary, and error path logs meaningfully. Use `debugPrint` (dev) and
route real errors/crashes to `CrashlyticsService` with context (screen, uid, operation). Log
inputs/outputs of AI calls, Firestore failures, purchase events, migrations. No silent `catch {}`.

### R5 — Performance-grade UX (smooth, native-feeling, both platforms)
- **Animations**: use `AnimationController` / `AnimatedContainer` / implicit animations with
  intentional curves & durations (see design tokens). Target 60fps; no jank, no abrupt state jumps.
- **iOS + Android parity**: test both. Platform-guard where needed (`Platform.isIOS`), respect safe
  areas, use Cupertino-correct gestures where it matters. Haptics on meaningful actions.

### R6 — Theme + i18n are never optional
- **Dark/Light**: never hardcode a color. Use `Theme.of(context)`, `AppColors` extension, or design
  tokens. Every new UI must look correct in both themes.
- **EN/TR parity**: every user-visible string gets both `en.json` and `tr.json` keys in the same
  change. Key naming: `screen.section.element`.

### R7 — Design language: "billion-dollar product"
Every surface must feel like a flagship app from a top-tier company — modern, innovative, cohesive,
and on-brand for a premium nutrition/fitness product. This explicitly includes the states people
forget: **loading, empty, error, success, modals/sheets, selectors/pickers, transitions**. No raw
`CircularProgressIndicator` dropped on a blank screen, no default grey error text, no abrupt modals.
Use the shared design system (tokens + reusable components in `lib/core/theme/` and
`lib/core/widgets/`) — build the component once, reuse everywhere. Sustainable and unique.

### R8 — Keep the guide and roadmap alive
After every meaningful change: update the relevant section here, tick/append `TODO.md`, and keep the
"Key Services / Files" tables accurate. Rules and status must never drift from the code.

### R9 — Shared-file parallel-write guard (MANDATORY)
**Never let two agents or two tool calls write the same shared JSON/rules file at the same time.**
This caused a silent key-loss collision in Phase 12. The rule:
- `en.json` / `tr.json`: all localization key additions must be **sequential** — use a Python
  `json.load → mutate → json.dump` script one key group at a time, never a raw `sed` patch.
- `firestore.indexes.json` / `firestore.rules` / `storage.rules`: one agent owns a file per turn.
- When spawning parallel sub-agents, assign each a **disjoint file set**. If two agents need the same
  file, serialize them or have one collect both changes and write once.
- `test/i18n_parity_test.dart` is the CI gate — it must pass after every localization change.

### Definition of Done (every task must pass)
☑ Multi-role reasoning applied · ☑ Optimized (R1) · ☑ Data tier + indexes + rules + seed correct
(R2/R3) · ☑ Logged (R4) · ☑ Smooth + iOS/Android (R5) · ☑ Dark/Light + EN/TR (R6) ·
☑ Flagship-grade UI incl. loading/empty/error/modal states (R7) · ☑ `flutter analyze lib/` has
**0 errors** · ☑ CLAUDE.md + TODO.md updated (R8).

---

## Architecture at a Glance

```
lib/
├── core/
│   ├── models/          # Pure Dart data models (Firestore ↔ app boundary)
│   ├── providers/       # ChangeNotifier state (LanguageProvider, ThemeProvider, UserProvider)
│   ├── services/        # All business logic and Firebase access (singleton pattern)
│   │   └── ai/          # AIService, PromptService (OpenRouter / DeepSeek)
│   ├── utils/           # Route constants, helpers, ban check observer
│   ├── theme/           # AppTheme (light + dark, primary color slot)
│   └── localization/    # AppLocalizations, en.json, tr.json
├── screens/             # One directory per feature
│   ├── home/            # Main dashboard + meal plan + food logging
│   ├── community/       # Social feed (posts, comments, reactions)
│   ├── chat/            # 1:1 real-time chat
│   ├── profile/         # Profile view + settings + legal
│   ├── shopping/        # Shopping list (Hive local + meal-plan auto-gen)
│   └── auth/            # Login, register, verify email, forgot password
└── main.dart            # Firebase init + MultiProvider + MaterialApp
```

## State Management

- **Provider** (not Riverpod, not Bloc) — all providers extend `ChangeNotifier`
- Providers live in `lib/core/providers/`
- Services are singletons (`factory() => _instance`) — never instantiate with `new`
- Access via `context.read<T>()` (mutations) or `context.watch<T>()` / `Consumer<T>` (UI)

## Firebase Collections

| Collection | Purpose |
|---|---|
| `users/{uid}` | User profile, public onboarding data (streak, activity_level, goals, cooking_level, `main_goal`, `target_weight`, `water_reminder`, `cooks_for_others`, etc.) |
| `users/{uid}/private/nutrition` | **Owner-only PII** — personal_info (height/weight/gender/birth_date), allergies, dietary_restrictions, disliked_foods, avoid_ingredients |
| `users/{uid}/meal_plans/current` | Current weekly meal plan |
| `users/{uid}/food_logs/{logId}` | Daily food diary entries |
| `posts/{postId}` | Community posts |
| `posts/{postId}/comments/{commentId}` | Post comments |
| `chats/{chatId}/messages/{msgId}` | Chat messages |
| `notifications/{uid}/items/{id}` | In-app notifications |
| `dishes/{dishId}` | Recipe/dish database (seeded once) |
| `signals/{uid}` | Ephemeral social broadcasts |
| `admin/status/{uid}` | Ban/admin flags |
| `referrals/{code}` | Referral code docs (owner, usedByUids, maxUses) |
| `users/{uid}/favorites/{recipeId}` | Saved/bookmarked recipes |
| `users/{uid}/recent_foods/{dishId}` | Recent & frequent food log entries (max 20) |
| `users/{uid}/meal_plan_history/{key}` | Archived weekly meal plans (key = `YYYY-MM-DD` week start) |

## Key Services

| Service | File | Notes |
|---|---|---|
| `AuthService` | `auth_service.dart` | Singleton, Firebase Auth wrapper, Google + Apple + email |
| `FirestoreService` | `firestore_service.dart` | User CRUD, activity logging, streak, notifications; `getPrivateNutritionData(uid)` migrates + reads PII subcollection; `savePrivateNutritionData(uid, data)` writes PII |
| `AIService` | `ai/ai_service.dart` | OpenRouter client, typed exceptions, 3-retry policy |
| `WeeklyMealPlanService` | `weekly_meal_plan_service.dart` | AI-generated plan, Firestore caching, hash invalidation |
| `FoodLogService` | `food_log_service.dart` | Real-time food diary stream for home dashboard |
| `StorageUploadService` | `storage_upload_service.dart` | Firebase Storage (avatars, post images) |
| `PushNotificationService` | `push_notification_service.dart` | FCM + local notifications |
| `CommunityService` | `community_service.dart` | Posts CRUD + cursor-based pagination |
| `DishService` | `dish_service.dart` | Firestore dish DB, seed on demand |
| `GlobalErrorHandler` | `global_error_handler.dart` | **Single** `FlutterError.onError` owner; wired into `MaterialApp.builder` |
| `ATTConsentService` | `att_consent_service.dart` | iOS App Tracking Transparency; one-shot prompt, SharedPrefs `att_prompted` key |
| `DeepLinkService` | `deep_link_service.dart` | `app_links` universal + custom-scheme routing; `init(navigatorKey)` in splash |
| `ReferralService` | `referral_service.dart` | 6-char referral codes; Firestore `referrals/{code}`; batch-write reward on apply |
| `SharingService` | `sharing_service.dart` | Native share-sheet wrapper for recipes, progress, posts, challenges, referrals |
| `DataExportService` | `data_export_service.dart` | GDPR data export — downloads user Firestore data as JSON |
| `ShareableFitnessCard` | `widgets/shareable_fitness_card.dart` | Capture-to-PNG progress card; `capture(key)` → share_plus |
| `NotificationService` | `notification_service.dart` | In-app notifications. **Stores STRUCTURED data only** (`type`, `actorUid/Name/PhotoUrl`, `relatedId`, `metadata`) — never pre-rendered text |
| `NotificationPresenter` | `utils/notification_presenter.dart` | Renders notification title/body/icon/color dynamically from `notifications.feed.*` keys; legacy docs fall back to stored title/body |
| `openUserProfile` / `ProfileLink` | `utils/profile_navigation.dart` | Standard way to open a user's profile from any avatar/name (`{userId}` or `{user}`); self → own profile |
| `FavoriteService` | `favorite_service.dart` | `users/{uid}/favorites/{recipeId}`; `toggleFavorite`, `isFavoriteStream`, `getFavoritesStream` |
| `RecentFoodService` | `recent_food_service.dart` | `users/{uid}/recent_foods`; auto-upserted by `FoodLogService`; max 20 entries; `getRecentFoods`, `getFrequentFoods` |
| `NotificationPreferencesService` | `notification_preferences_service.dart` | Per-group mute prefs in `users/{uid}.notification_muted`; groups: likes/comments/friends/system/referral |
| `WeeklyMealPlanService` (extended) | `weekly_meal_plan_service.dart` | Added `getMealPlanHistory`, `restorePlan`, auto-archive to `meal_plan_history/{key}` on every save |
| `AiCreditService` | `ai_credit_service.dart` | Daily AI credit quotas (free=2/day, premium=20/day); `checkAndConsume(uid, isPremium)` burns bonus credits first; `rollbackCredit(uid)` / `rollbackBonusCredit(uid)` for failed AI calls; `addBonusCredits(uid, count)` for IAP top-ups; `getCreditsStream(uid)` **auto-resets** quota when `reset_at` is in the past (day-rollover detected on stream read) |
| `AchievementService` | `achievement_service.dart` | 11-badge system; `earn(uid, key)` idempotent Firestore write; `checkAndGrant(uid, {streak, tier, justLoggedMeal, justLoggedPhoto, justPosted, justCookedAndLogged})` fires from all success paths; `backfillForUser(uid)` for existing accounts; `getAchievementsStream(uid)` live stream. Catalog in `achievement_model.dart` (`kAchievementCatalog`). |
| `AchievementsGrid` | `screens/profile/widgets/achievements_grid.dart` | Profile badge grid; earned/locked tiles; bounce unlock animation (reduced-motion aware); tap → `AppSheet` detail. Shown after reputation badge in `profile_screen.dart`. |
| `WhatsNewService` | `whats_new_service.dart` | Singleton; `shouldShow()` → true once per version bump (SharedPrefs `whats_new_last_version`); skips first install |
| `WhatsNewSheetContent` | `core/widgets/whats_new_sheet.dart` | DS bottom sheet for version changelogs; `WhatsNewSheetContent.show(context)` static method |
| `CoachmarkTip` | `core/widgets/coachmark_tip.dart` | One-time contextual tooltip (SharedPrefs-gated); `prefKey` param; dismiss-on-tap; reduced-motion aware |
| `ProfileCompletenessCard` | `screens/profile/widgets/profile_completeness_card.dart` | Owner-only card (3 steps: photo/meal/challenge); progress ring; self-hides when complete |
| `DiscoverHubScreen` | `screens/discover/discover_hub_screen.dart` | Unified 2×2 discovery grid (Gyms/Coaches/Programs/Challenges) + premium banner; `AppRoutes.discover` |
| `GymJoinPromptSheet` | `screens/gym/gym_join_prompt_sheet.dart` | Shown when non-member scans gym QR; join + check-in flow; `GymJoinPromptSheet.show(context, gymId:, gymName:, uid:)` |
| `RoleQuickCard` | `screens/home/widgets/role_quick_card.dart` | Role-aware home dashboard card (gymOwner/coach/admin); quick-entry to role dashboards; hidden for consumers |
| `AiInsightService` (extended) | `ai_insight_service.dart` | `generateFitnessTwin(user, locale:)` → persists to `users/{uid}/ai_twin_projections`; `getLatestProjectionStream(uid, locale)` is **locale-agnostic** (no `.where('locale')` filter — returns newest doc regardless of language); locale-tagged SharedPrefs cache for daily insight. **15.4**: `generateWeeklyRecap(user, locale:)` (idempotent per week+locale via Firestore cache, low-data <3 days is free), `checkLowDataThisWeek(uid)`, `getLatestWeeklyRecapStream(uid)`, `static weekKey(DateTime)` → `users/{uid}/ai_weekly_recaps/{doc}` |
| `WeeklyRecapScreen` | `screens/ai/weekly_recap_screen.dart` | Score ring, wins/challenges sections, trend chip, recommendation, Share sheet. Credit-gated (free for low-data recaps). Entry via `WeeklyRecapCard` on home. |
| `WeeklyRecapCard` | `screens/home/widgets/weekly_recap_card.dart` | Home teaser: shows week score + trend when recap exists for current week; "Generate" CTA otherwise. Streams from `ai_weekly_recaps`. |
| `AdminService` (extended) | `admin_service.dart` | Added `searchUsers`, `getUsersStream`, `banUser`, `unbanUser`, `setUserRole`, `coachApplicationHistoryStream`, `gymApplicationHistoryStream`, `logAuditAction`, `auditLogStream`, `pendingCountStream` |
| `AiCreditsSheet` | `screens/ai/widgets/ai_credits_sheet.dart` | Bottom sheet: usage bar, reset countdown, plan chip, upgrade CTA (shows SnackBar placeholder — `ai.premium_coming_soon`); `AiCreditsSheet.show(context, uid:, isPremium:)` |
| `AiCreditBadge` | `screens/ai/widgets/ai_credit_badge.dart` | Tappable badge → opens `AiCreditsSheet`; live credit stream |
| `OnboardingProjectionService` | `onboarding_projection_service.dart` | Pure Dart: BMI+band, calories/macros (reuses `CalorieCalculator`), **safe-clamped** weekly rate + ETA, recommended water. Powers onboarding pages 5 + 14 |
| `IntroScreen` / `OnboardingFlowScreen` | `screens/onboarding/v2/` | V2 flow: Yazio-style intro carousel + 14-page host (`onboarding_scaffold.dart` chrome, `v2/widgets/onboarding_widgets.dart` controls). `OnboardingFlowScreen(loggedInCompletion:)` runs pre-registration (default) **or** logged-in completion (prefills + persists to the existing uid). See "Onboarding V2" above |
| `OnboardingCompletion` | `screens/onboarding/v2/onboarding_completion.dart` | Shared completion tail for BOTH onboarding exits (new-account register + logged-in completion): `finalizeAndRoute` → `OnboardingProvider.persistV2Profile` + water reminder + `UserProvider` (copyWith) + route to `mealPlanGeneration`; best-effort so a write hiccup never strands the account |

### Firestore collections (Phase 12 additions)
| Collection | Purpose |
|---|---|
| `users/{uid}/ai_twin_projections/{id}` | Persisted AI fitness projections; fields: `locale`, `generatedAt`, payload, `inputsHash` |
| `users/{uid}/ai_weekly_recaps/{id}` | Weekly AI coach recaps (owner-only); fields: `weekKey` (YYYY-MM-DD Monday), `locale`, `score`, `wins[]`, `challenges[]`, `trend`, `recommendation`, `isLowData`, `generatedAt` |
| `admin_audit/{id}` | Append-only audit log for every admin action (who/what/when/target); admin-only rules |
| `ai_credits/{uid}` | Daily AI quota: `used_today`, `reset_at`, `is_premium`, `bonus_credits` (IAP top-ups, not reset at midnight) |
| `reports/{id}` | Moderation reports; `status` (pending/reviewed), `targetType`, `reason`; indexes on `status+timestamp` |
| `seeds/{docId}` | Idempotent seed gates (e.g. `demo.demo_programs_v1`); authenticated read/write |

### Phase 15 additions (engagement & gamification)
`PushNotificationService` extended with `scheduleDailyMealReminders({times, title, body})` + `cancelMealReminders()` (ID block 8001–8008, mirrors water reminder pattern). `NotificationPreferencesService.preferencePairs` has new `reminders` group covering `mealReminder`, `streakAtRisk`, `weeklyPlanReady`. `settings_screen.dart` has `_showMealReminderSheet()` with breakfast/lunch/dinner pickers; stores `onboarding_data.meal_reminder{enabled, times[]}`. `functions/index.js` has `streakAtRiskNotifier` (daily 17:00 UTC, checks `food_logs.date == today`) and `weeklyPlanReadyNotifier` (Mon 07:00 UTC) cron producers; both respect `notification_muted.reminders`, cap at 500 users.

### Firestore collections (Phase 15 additions)
| Collection | Purpose |
|---|---|
| `users/{uid}/achievements/{key}` | Earned badges — owner-only; `key` = `AchievementKey.name`; fields: `earned_at`. Rules: owner R/W. |

### Firestore collections (Phase 13 additions)
| Collection | Purpose |
|---|---|
| `community_groups/{groupId}` | Location-based community groups: `name, description, city, district, owner_uid, member_count, is_public, tags[], last_activity_at`. Members at `.../members/{uid}` (`role`). Discovery indexes on `is_public`(+`city`(+`district`)) × sort field. See `docs/roadmap/COMMUNITY_GROUPS.md`. |
| `users/{uid}/food_analyses/{id}` | AI food-analysis history (owner-only): full `NutritionEstimate` JSON + `created_at` |
| `posts/{postId}.groupId` | Optional top-level field — group-scoped feed (null = global). Index `groupId+timestamp` |
| `users/{uid}.group_memberships[]` | Array of joined group ids (mirrors `gym_memberships`) for "My groups" |

### Phase 13 — features & fixes (current)
- **Shared filter bar** — `AppFilterBar` / `AppFilterPill` (`core/widgets/ds/app_filter_bar.dart`,
  exported from `ds.dart`): canonical 34h pill bar. **All four discovery surfaces now consume it** —
  gym & coach discovery, program marketplace, and community feed/topics. `AppFilterPill` has `sort`
  (label + check) and `.picker` (value + chevron) styles + per-pill `accent` (e.g. energy "Near me")
  and `loading` (spinner, hides label).
- **Foods & Nutrition hub** — `NutritionHubScreen` (`screens/nutrition_hub/`): tabbed Browse Foods
  (DishService catalog + category filter + search) · Favorites (`FavoritesBody`) · Insights
  (`NutritionAnalyticsScreen(showChrome:false)`). Route `AppRoutes.nutritionHub`; entry from quick
  actions + side menu. Repointed the old Favorites/Analytics quick-actions here.
- **Food analysis v2** (`food_scan_screen.dart`) — Describe **or Photo** input. `AIService.generateJsonFromImage`
  (vision; `.env OPENROUTER_VISION_MODEL`, `isVisionAvailable` gates the photo option).
  `FoodAnalysisService.analyzeFoodPhoto` + enriched `NutritionEstimate` (fiber/sugar/sodium, health
  score, allergens, confidence, portion). Portion stepper rescales live. **AI credits now metered**
  (checkAndConsume + rollback) with live `AiCreditBadge`; analysis history via `FoodAnalysisHistoryService`.
- **Barcode scanner** — explicit initializing / permission-denied / camera-unavailable states +
  **manual entry** fallback (no more silent black screen, e.g. on simulator).
- **Shopping list** — items now carry `sourceMeals`/`sourceDates` (which dish/day needs each
  ingredient); "for: …" subtitle + This-week/Today filters. (Market data dropped — no source.)
- **Admin** — fixed empty users list (`getUsersStream` ordered by camelCase `createdAt` → snake_case
  `created_at`), fixed `searchUsers` escaped `\$query`, added `AdminService.sendNotificationToUser`
  (+ action-sheet UI), wired `TestDataLibrary.adminUsers()` for test mode.
- **Bug fixes** — self-profile-as-stranger (`profile_screen` `_isSelf`), weight-save dismissing the
  profile (`WeightLogSheet`), My Programs infinite spinner (composite index + un-swallowed stream
  error + StatefulWidget retry), onboarding water reminder defaults to ON.

| Service / Widget | File | Notes |
|---|---|---|
| `CommunityGroupService` | `community_group_service.dart` | Groups CRUD + membership + discovery; `CommunityService.getGroupFeedStream` for the group feed |
| `FoodAnalysisHistoryService` | `food_analysis_history_service.dart` | Owner-only `users/{uid}/food_analyses`; `save`, `streamRecent` |
| `AppFilterBar` / `AppFilterPill` | `core/widgets/ds/app_filter_bar.dart` | Canonical pill filter bar (sort + picker styles, per-pill accent) |
| `NutritionHubScreen` | `screens/nutrition_hub/nutrition_hub_screen.dart` | Browse Foods / Favorites / Insights tabs |
| `WeightLogSheet` | `screens/home/widgets/weight_log_sheet.dart` | Shared weight-log sheet (home card + profile completeness card) |

### Notifications (architecture)
- **Never store display text.** Call `NotificationService.sendNotification(type:, actorUid:, actorName:, actorPhotoUrl:, relatedId:, metadata:)`. Text is rendered on the reader's device by `NotificationPresenter` so it's always in their language with the real actor name.
- Add new notification copy as `notifications.feed.*` keys (EN+TR) with `{actor}`/`{emoji}`/`{days}` vars.
- `NotificationType` is backward-compatible: old names (`like`, `friend_request`…) still parse; prefer granular values (`likePost`, `likeComment`, `reaction`, `referral`, `streakMilestone`).

### Profile privacy
- `UserModel.isPrivate` (`is_private`). Non-friends viewing a private profile see only the lock card; owner + accepted friends see full. Enforced in `profile_screen.dart` (`_privacyResolved` gate + fresh re-fetch). Profile detail is UI-gated (lives on the readable user doc); `food_logs`/`meal_plans` are server-side owner-only.

### Role growth card (side menu)
- `_ConsumerCard` in `side_menu.dart` accepts `hideGym` and `hideCoach` bool params. `_buildRoleCard` always appends `_ConsumerCard` when the user lacks at least one of gym-owner/coach, passing `hideGym: isGymOwner` and `hideCoach: isCoach`. This means: admin sees "Register Gym" + "Become Coach"; gym owner sees "Become Coach" only; coach sees "Register Gym" only; already both → no grow card. Users who already hold a role never see the "become X" option for it.

### Discovery filter bars (gym & coach screens)
- **Redesigned filter bar** — single-row horizontal scrollable pills (height 34h). Design: full text inline per chip (icon + label + trailing ▼/✓), `AnimatedContainer` color transitions. A `VerticalDivider` separates **location** (city, optional district) from **sort** pills.
- **Gym sort options** (`gym_discovery_screen.dart`): `avg_rating` (Highest Rated), `member_count` (Popular, **default**), `created_at` (Newest), `near_me` (Nearest — energy-colored, KVKK consent-gated). Sort default changed from `name` to `member_count`. `GymService.searchGyms` now accepts `avg_rating` as a valid `sortBy`.
- **Coach sort options** (`coach_discovery_screen.dart`): `avg_rating` (Highest Rated), `client_count` (Popular, **default**), `created_at` (Newest), `near_me` (Nearest — same KVKK consent flow as gym). District filter added (shown when city is selected). `CoachProfileModel` now carries `latitude`/`longitude` for client-side near-me sorting.
- **Map view** (`_GymMapView`): A 96px horizontal gym list panel sits below the map. Tapping a card opens the info sheet (name, address, description, tags, member count + "View Gym" CTA). The sheet was enhanced with `address`, `description`, and `tags` fields from `GymModel`.

### Onboarding V2 (pre-registration — INVERTED flow)
- **Onboarding now runs BEFORE registration.** Flow: `Splash → Intro carousel → [Başla] → Onboarding (14 pages, in `lib/screens/onboarding/v2/`) → [Onayla] → Register → AI meal-plan generation → Home`. Side paths: intro/report `[Zaten hesabım var]` → `OnboardingProvider.reset()` → Login; Login `[Kayıt ol]` → `AppRoutes.onboardingV2`.
- `OnboardingProvider` accumulates everything **in-memory (no uid)**; the shared tail `OnboardingCompletion.finalizeAndRoute` (`v2/onboarding_completion.dart`) persists it — public `onboarding_data` + private nutrition + `displayName` + `onboarding_completed:true` via `OnboardingProvider.persistV2Profile` (all best-effort) — schedules the water reminder, repopulates `UserProvider` (built via `copyWith`, since `persistV2Profile` writes through `FirestoreService` and does **not** invalidate the `AuthService` cache → a refetch could be stale), and routes to `mealPlanGeneration`. Two callers: `register_screen._completeV2Onboarding` (new account; also records consents) and the logged-in completion path below.
- `AppRoutes.intro` + `AppRoutes.onboardingV2` are **unwrapped** (pre-auth, like splash). Host: `onboarding_flow_screen.dart`; shared chrome: `onboarding_scaffold.dart`; shared controls: `v2/widgets/onboarding_widgets.dart`.
- **Email verification is a HARD GATE** — `RouteGuard` Section C blocks all routes except `/verify_email` and `/meal_plan_generation` until `firebaseUser.emailVerified == true`. Social auth (Google) skips the gate (already verified). `OnboardingCompletion.finalizeAndRoute` routes email-auth accounts to `/verify_email` instead of `/meal_plan_generation`; on successful verification `verify_email.dart` routes to `/meal_plan_generation` (onboarding complete) or back into `onboardingV2` (logged-in completion path, onboarding incomplete). New `onboarding_data` keys: `main_goal`, `target_weight`, `water_reminder{enabled,target_ml,wake,sleep}`, `cooks_for_others`.
- **Legacy post-registration onboarding is fully removed** (`onboarding_screen.dart`, `steps/`, `screens/onboarding/widgets/`, `lib/widgets/onboarding_common_widgets.dart`, `AppRoutes.onboarding`). An already-authenticated account whose `onboarding_completed == false` (a legacy incomplete, or a V2 final-write failure) finishes in the **same V2 flow in logged-in mode**: `OnboardingFlowScreen(loggedInCompletion: true)` (route arg `OnboardingFlowScreen.loggedInCompletionArgs`) prefills from `UserProvider.user.onboardingData` (+ `displayName`), then `OnboardingCompletion` persists to the **existing uid** (no new account) and routes to `mealPlanGeneration`. Splash, RouteGuard (§B+§D), and verify-email send such accounts here; `OnboardingFlowResolver.resolve` returns only `main` (complete) or `onboardingV2` (incomplete) — the logged-out `intro`/`firstIncompleteStep` branches were dropped since the resolver only ever runs for an authenticated user.
- New features introduced here: **water reminder** (`PushNotificationService.scheduleDailyWaterReminder` — precise, multi-time daily reminders via `timezone`/`flutter_timezone` + `zonedSchedule`, spread across the wake→sleep window; editable from **Settings → Water reminder**) and **`cooks_for_others`** flag (per-household meal scaling shelved — see `docs/roadmap/ONBOARDING_V2.md` §7).

## AI Integration

- Provider: OpenRouter (`https://openrouter.ai/api/v1/chat/completions`)
- Model: `openrouter/free` (configurable)
- Key stored in `.env` (client-side for MVP; move server-side before GA)
- `AIService.isConfigured` guards all AI calls — returns empty results if key is placeholder
- JSON responses: use `AIService.generateJson()` which returns `Map<String, dynamic>`
- Error hierarchy: `AIRetryableException` → retry up to 3×; `AIFatalException` → abort
- Never add AI features that don't degrade gracefully when `isConfigured == false`

## Localization

- Two locales: `en` (English) and `tr` (Turkish) — **must remain in parity**
- Files: `assets/localization/{en,tr}.json`
- Access: `AppLocalizations.of(context).translate('key.path')`
- **When adding any user-visible string, add both EN and TR keys simultaneously**
- Key naming: `screen.section.element` (e.g. `settings.account.change_email`)

## Design System (USE THIS — see Rule R7)

> Flagship design system lives in `lib/core/theme/` (tokens) + `lib/core/widgets/ds/` (components).
> One barrel import: `import 'package:cookrange/core/widgets/ds/ds.dart';`. Build a component once,
> reuse everywhere. **Prefer DS tokens/components over ad-hoc `Container`/`ElevatedButton`/hex.**

**Tokens** (`lib/core/theme/`):
- `AppSpacing` / `AppRadius` / `AppSize` / `AppElevation` — geometry (design-px; apply `.r`/`.w`/`.h` at call site).
- `AppMotion` — durations (`instant/fast/normal/slow/ambient`) + curves (`standard/emphasized/spring`…).
- `AppPalette.of(context)` (or `context.palette`) — **semantic color roles**: `surface`, `surfaceVariant`,
  `textPrimary/Secondary/Tertiary`, `border`, `success/warning/error/info`, macro accents
  (`protein/carbs/fat/calories`), `shadow/scrim/shimmer*`. Theme-aware. **Use these instead of raw hex.**
- `AppText.of(context)` — semantic typography (`displayL`…`labelS`, `overline`), theme-aware, Poppins.

**Components** (`lib/core/widgets/ds/`):
- `AppButton` — variants (primary/secondary/tonal/ghost/destructive), sizes, loading, haptics, press-scale.
- `AppCard` / `AppGlassCard` — standard + frosted-glass surfaces with press feedback.
- `AppSheet.show(...)` — the standard modern bottom sheet (handle, blur scrim, title row, safe-area).
- `AppShimmer` + `AppSkeletonBox` / `AppSkeletonList` — branded loading skeletons (no bare spinners).
- `AppEmptyState` / `AppErrorState` — illustrated, animated, on-brand states with CTA/retry.

**Theme plumbing** (legacy, still active):
- `ThemeProvider` manages `ThemeMode` (light/dark) and `primaryColor` (live brand color).
- `AppTheme.lightTheme(primaryColor)` / `AppTheme.darkTheme(primaryColor)` in `app_theme.dart`.
- Primary/brand color: `themeProvider.primaryColor` — default orange `AppPalette.brand` (`0xFFF97300`).
- **Never hardcode colors.** Migrating old screens: replace `Color(0xFF2E3A59)` → `palette.textPrimary`,
  `Color(0xFF0D1117)` → `palette.background`, white cards → `palette.surface`, etc.

## Code Conventions

- No comments unless the WHY is non-obvious
- Singletons for all services: `static final _instance = Foo._internal(); factory Foo() => _instance;`
- `mounted` check before every `setState` or `context` use after `await`
- Use `unawaited()` (with `dart:async` import) for intentional fire-and-forget
- `StatefulBuilder` inside `showDialog` for dialog-local loading state
- Platform guards: `if (Platform.isIOS)` for Apple Sign-In, Apple-specific UI
- Cursor pagination: `DocumentSnapshot startAfter` pattern (see `community_service.dart:fetchPostsPage`)

## MVP Status

All B1-B13 blockers are complete. App is in **v0.9.5 consumer-beta state**. Phase 2–3.5 are fully shipped:
design system, food scanning, nutrition analytics, cooking mode, community, challenges, shopping list,
settings, referral program, deep linking, ATT consent, accessibility semantics, performance RepaintBoundaries,
GDPR data export, social sharing, and shareable fitness card. **Onboarding V2** (pre-registration inverted flow:
Yazio-style intro + 14 personalized pages + water reminder + household flag) is shipped — see
`docs/roadmap/ONBOARDING_V2.md` (incl. known follow-ups). See `TODO.md` for current roadmap.

## Running Locally

```bash
flutter pub get
flutter run
```

CI runs on every PR: `flutter analyze` + `flutter test` + Android debug build (`.github/workflows/ci.yml`).

## Key Files to Know First

1. `lib/main.dart` — app entry, providers, MaterialApp
2. `lib/screens/splash_screen.dart` — all heavy initialization (Firebase, Hive, AI, push)
3. `lib/core/services/auth_service.dart` — auth state machine
4. `lib/screens/home/home.dart` — core product screen (~1200 LOC)
5. `assets/localization/en.json` — all user-visible strings
