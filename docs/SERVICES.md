# SERVICES.md — Services & Cloud Functions

> All business logic lives here. UI never calls Firebase directly — it goes through a service.
> 75 Dart singletons in `lib/core/services/**` + 4 Cloud Functions in `functions/index.js`.
> Pattern: `static final _instance = Foo._internal(); factory Foo() => _instance;`
> **Code is truth — keep this in sync when you add/change a service.**

---

## Auth & Identity
- **AuthService** `auth_service.dart` — Auth lifecycle: email/password, Google, Apple; email
  verification; password reset; GDPR account deletion; session tracking + concurrent-login
  detection. Holds the app `navigatorKey`. In-memory user cache. Touches `users/{uid}`, `logs/{uid}`.
- **FirestoreService** `firestore_service.dart` — Central Firestore I/O: user CRUD, activity
  logging, role assignment (`addUserRole`), streak, `getUserStream`. `getPrivateNutritionData(uid)`
  migrates + reads PII subcollection; `savePrivateNutritionData(uid, data)` writes it.
- **AdminStatusService** `admin_status_service.dart` — Real-time ban/admin status; `onBanStatusChanged`
  stream feeds `RouteGuard`; reads `admin_config` for maintenance/min-version.

## AI & Generation (`services/ai/` + AI services)
- **AIService** `ai/ai_service.dart` — LLM engine (OpenRouter). Direct key (dev) or **proxy mode**
  (prod). 3-retry policy. Typed exceptions: `AIRetryableException`, `AIFatalException`,
  `AIQuotaExceededException` (402), `AIJsonParseException`. `generateCompletion`, `generateChatResponse`,
  `generateJson`. `isConfigured`, `hasProxy`, `setProxyUrl()` (from Remote Config).
- **AiChatService** `ai/ai_chat_service.dart` — Builds profile-aware system prompt for nutrition chat.
- **AiChatHistoryService** `ai/ai_chat_history_service.dart` — In-memory conversation state (voice↔text).
- **PromptService** `ai/prompt_service.dart` — Prompt template library (recipe, weekly plan, ingredient
  validation, plan alternates) + locale instructions.
- **RecipeGenerationService** `recipe_generation_service.dart` — Structured recipe gen via AI+Prompt.
- **FoodAnalysisService** `food_analysis_service.dart` — Estimates nutrition from a food description.
- **AiInsightService** `ai_insight_service.dart` — Daily accountability insight + 30/60/90-day fitness
  twin projection + risk detection. Caches daily insight in SharedPrefs (per date+locale); saves
  projections to `users/{uid}/ai_twin_projections`. Streams latest + history.
- **AiCreditService** `ai_credit_service.dart` — Daily AI quota (free 2/day, premium 20/day, bonus
  credits from IAP never reset). `checkAndConsume` (burns bonus first; **skipped in proxy mode** —
  server enforces), `rollbackCredit`/`rollbackBonusCredit`, `addBonusCredits`, `getCreditsStream`.
  Authority is the `aiProxy` Cloud Function; client is read-only when proxied.

## Nutrition & Food
- **DishService** `dish_service.dart` — `dishes/` CRUD + seed; streams; admin edit/delete.
- **FoodLogService** `food_log_service.dart` — Logs meals (dish/recipe/scanned/quick/barcode),
  daily totals, today stream, date-range history. Auto-upserts `recent_foods`.
- **RecentFoodService** `recent_food_service.dart` — Last ~20 foods (Hive), quick-add carousel.
- **BarcodeLookupService** `barcode_lookup_service.dart` — Barcode → product nutrition (Open Food Facts).
- **WeeklyMealPlanService** `weekly_meal_plan_service.dart` — AI weekly plan; hash-based cache
  invalidation (profile change → regenerate); allergy validation; `getMealPlanHistory`, `restorePlan`,
  auto-archive to `meal_plan_history/{key}`. Writes `users/{uid}/meal_plans/current`.
- **MealPlanCalendarService** `meal_plan_calendar_service.dart` — Export plan as `.ics`.
- **NutritionAnalyticsService** `nutrition_analytics_service.dart` — Weekly summary, macro %, trends.
- **StorageService** `storage_service.dart` — Local Hive: recipes, plans, shopping, hydration, weight,
  settings (boxes: user/recipes/meal_plans/settings/shopping/hydration/weight).

## Social & Community
- **CommunityService** `community_service.dart` — Posts CRUD, cursor pagination (`fetchPostsPage`),
  comments, reactions, groups, topic filter (arrayContains tags), weekly highlights
  (`getTopPostThisWeek`/`getTopStreakUserThisWeek`), mention fan-out, content moderation
  (`_checkContent` blocked-keyword pre-screen), `reportContent`.
- **ChatService** `chat_service.dart` — Chats + messages, typing status, unread counts, mark-read,
  group/private/system creation.
- **FollowService** `follow_service.dart` — Following/followers (batch), counts, isFollowing stream,
  follow notification fan-out.
- **FriendService** `friend_service.dart` — Search users, friendship status, send/accept/reject.
- **FavoriteService** `favorite_service.dart` — `users/{uid}/favorites`; toggle, isFavorite stream.
- **ReferralService** `referral_service.dart` — 6-char codes (`referrals/{code}`), apply → batch reward
  (7-day premium trial both sides) + commission record + notification.
- **ReputationService** `reputation_service.dart` — Reputation badges/score from activity.
- **SignalService** `signal_service.dart` — Ephemeral broadcasts (TTL via expiresAt).
- **StreakSquadService** `streak_squad_service.dart` — Squads (`squads/`), invite codes, leaderboard.
- **NotificationService** `notification_service.dart` — **Structured-only** in-app notifications
  (type, actorUid/Name/PhotoUrl, relatedId, metadata — never pre-rendered text). Pagination, mark-read.
- **NotificationPreferencesService** `notification_preferences_service.dart` — Per-group mute prefs
  (likes/comments/friends/system/referral) in `users/{uid}.notification_muted`.

## Coach & Gym
- **CoachService** `coach_service.dart` — Coach profiles, client links, discovery/search, top coaches
  (`getTopCoachesStream`: verified+accepting, avgRating DESC).
- **GymService** `gym_service.dart` — Gym CRUD, owner gym stream, member mgmt, discovery
  (`searchGyms` w/ city/district/sortBy), QR token.
- **GymLeaderboardService**, **GymAnalyticsService**, **GymApplicationService**, **GymPostService**.
- **CoachApplicationService**, **CoachReviewService** (transaction-updates avgRating/ratingCount).

## Billing & Credits
- **BillingService** `billing_service.dart` — `in_app_purchase`; subscriptions
  (`com.cookrange.premium.{monthly,yearly}`), consumable top-up (`cookrange_ai_credits_10` →
  `AiCreditService.addBonusCredits(10)`), restore. Writes `subscription_tier`/`subscription_expires_at`.
- **CommissionService** `commission_service.dart` — `users/{uid}/commissions` + payout_requests;
  `recordReferralCommission` (₺5/premium referral), `recordCoachSessionCommission`, earnings summary.
  (Tracking layer only; payout processing deferred — see roadmap.)

## Admin & Moderation
- **AdminService** `admin_service.dart` — The admin API surface (~30 methods): application review
  (approve/reject coach+gym), `searchUsers`, `banUser`/`unbanUser`, `setUserRole`, history streams,
  `logAuditAction`+`auditLogStream`, `pendingCountStream`, reports (pending/reviewed/dismiss/remove +
  bulk), `fetchAnalyticsSnapshot` (count() aggregates), `premiumUsersStream`, `bannedUsersStream`,
  `aiUsageStream`, `grantBonusCredits`, `referralsStream`/`voidReferralCode`, program review
  (approve/reject/pending/history), `adminConfigStream`/`updateAdminConfig`, `broadcastsStream`/
  `sendBroadcast`, `setGymVerified`/`setCoachVerified`, `forceLogout`, `sendPasswordReset`,
  `getUserDataStats`.

## Feature, Config & Push
- **FeatureGateService** `feature_gate_service.dart` — Entitlement checks + `showPaywall()`.
- **RemoteConfigService** `remote_config_service.dart` — Flags: `maintenanceMode`, `minVersion`,
  `aiModel`, `maxMealRetries`, `featureVoiceAssistant`, `featureNutritionAnalytics`, `aiProxyUrl`.
- **PushNotificationService** `push_notification_service.dart` — FCM + `flutter_local_notifications`.
  Initializes the `timezone` DB (`flutter_timezone` → device zone) in `initialize()`. Hydration
  reminders are precise + multi-time: `scheduleDailyWaterReminder({title, body, wakeTime, sleepTime,
  count})` uses `zonedSchedule` (`matchDateTimeComponents.time`, **inexact** alarms — no Android 13+
  exact-alarm permission) at clock times evenly spread across the wake→sleep window (handles midnight
  wrap), over a reserved id block (7001–7012). `cancelWaterReminder()` clears the block. Spread math is
  pure + unit-tested (`PushNotificationService.spreadReminderTimes`).
- **PermissionService** `permission_service.dart` — Runtime permission requests (camera/GPS/notif).
- **ATTConsentService** `att_consent_service.dart` — iOS App Tracking Transparency (one-shot,
  `att_prompted` SharedPref key).
- **ConsentService** `consent_service.dart` — KVKK/GDPR consent records. `watchConsents()` /
  `getConsents()` (all purposes, unset-filled), `setConsent(purpose, granted)` (stamps
  `kLegalPolicyVersion` + server time; Crashlytics breadcrumb), `hasConsent(purpose)` (true only if
  granted & not stale — callers re-prompt otherwise), `recordInitialConsents({analytics, marketing})`
  (batch-writes essentials=granted + optionals at registration). Source of truth:
  `users/{uid}/consents/{docId}` (owner-only). Surfaced in `ConsentCenterScreen` + captured in
  `register_screen`. See `docs/COMPLIANCE.md`.
- **PrivacyRequestService** `privacy_request_service.dart` — DSAR channel. `submit(type, message)`
  → `privacy_requests/{id}`; `myRequestsStream()`. Admin side via `AdminService.privacyRequestsStream`
  / `updatePrivacyRequest` (+ audit log). Screens: `privacy_request_screen` (user),
  `admin_privacy_requests_screen` (admin).

## Infrastructure & Utilities
- **StorageUploadService** — Firebase Storage uploads (avatars, post/chat images).
- **SharingService** — `share_plus` wrapper (recipe/progress/post/shopping/referral/challenge) + deep links.
- **DeepLinkService** — `app_links` universal + custom scheme routing; `init(navigatorKey)` in splash.
- **DataExportService** — GDPR export (profile + logs + plans + lists + posts → JSON share).
- **LogService** — Structured logging + device/IP context (Hive-cached).
- **CrashlyticsService** — `recordError`, breadcrumbs, custom keys (screen/tier/aiModel).
- **AnalyticsService** — Event queue (Hive), batch, `logScreenView`.
- **PerformanceService** — `HttpMetric` on AI calls + custom traces.
- **ExerciseLogService**, **ProgramService**, **LeaderboardService**, **RecipeNoteService**,
  **ShoppingListSyncService** (`users/{uid}/lists/shopping`).
- **DishSeederService** (`seedIfEmpty` batch), **DishImageService**, **DemoContentSeeder**
  (sample programs; `seeds/` gate).
- **DeviceInfoService**, **ScreenUtilService**, **SystemUIService**, **AppInitializationService**
  (orchestrates boot), **AppLifecycleService**, **ProviderInitializationService**,
  **RouteConfigurationService**, **LoggingNavigatorObserver**.
- **GlobalErrorHandler** — single `FlutterError.onError` owner; wired into `MaterialApp.builder`.
- **TestModeService** — dev test-mode toggle (Hive) + `TestDataLibrary`.
- **WhatsNewService** — once-per-version changelog gate (SharedPref `whats_new_last_version`).

---

## Cloud Functions (`functions/index.js`)

- **aiProxy** (HTTPS) — The production AI path. Verifies Firebase **ID token** + **App Check**;
  extracts `uid`; runs **`enforceAndConsumeQuota(uid)`** in a Firestore transaction
  (auto-resets daily counter at midnight, burns bonus credits first, returns `'daily'`/`'bonus'`/
  `'exceeded'`/`'open'`); returns **HTTP 402** when exceeded; otherwise proxies to OpenRouter with the
  secret `OPENROUTER_API_KEY`. Rolls back the consumed credit on bad request / OpenRouter failure.
  Fail-open on Firestore infra error (returns `'open'` so AI stays available).
  Constants: `FREE_DAILY_LIMIT=2`, `PREMIUM_DAILY_LIMIT=20`.
- **onInAppNotificationCreated** (Firestore trigger) — On new `users/{uid}/notifications/{id}`,
  fans out an FCM push respecting the recipient's mute preferences.
- **onChatMessageCreated** (Firestore trigger) — On new `chats/{id}/messages/{id}`, pushes to other
  participants.
- **executeBroadcast** (internal helper) — Sends admin broadcasts to an audience (all/coaches/
  gymOwners/single uid), immediate or scheduled.

**Secrets** (Functions): `OPENROUTER_API_KEY` (`firebase functions:secrets:set`).

---

## Dependencies (grouped — see `pubspec.yaml` for exact versions)
- **Firebase:** core, auth, firestore, storage, analytics, crashlytics, messaging, remote_config,
  performance, app_check; google_sign_in, sign_in_with_apple.
- **State/UI:** provider, flutter_screenutil, cupertino_icons, font_awesome_flutter, flutter_svg,
  cached_network_image.
- **Local:** shared_preferences, hive(+flutter), path_provider.
- **Network/AI:** http, connectivity_plus, flutter_dotenv, flutter_map+latlong2, url_launcher.
- **Device/Media:** device_info_plus, package_info_plus, permission_handler, geolocator, image_picker,
  file_picker, mobile_scanner, qr_flutter, speech_to_text, wakelock_plus, share_plus.
- **Commerce:** in_app_purchase, app_links.
- **Utils:** intl, logging, flutter_local_notifications, uuid, crypto.
- **Dev:** flutter_test, flutter_lints, hive_generator, build_runner, analyzer.
