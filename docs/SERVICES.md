# SERVICES.md — Services & Cloud Functions

> All business logic lives here. UI never calls Firebase directly — it goes through a service.
> 75 Dart singletons in `lib/core/services/**` + Cloud Functions in `functions/`.
> **Security-authoritative state lives server-side**: premium in `entitlements/{uid}`, AI credits in
> `ai_credits/{uid}` — both owner-**read** + server-**write-only**; the client never grants premium,
> consumes credits, applies referrals, or deletes accounts directly.
> Pattern: `static final _instance = Foo._internal(); factory Foo() => _instance;`
> **Code is truth — keep this in sync when you add/change a service.**

---

## Auth & Identity
- **AuthService** `auth_service.dart` — Auth lifecycle: email/password, Google, Apple; email
  verification; password reset; session tracking + concurrent-login detection. Holds the app
  `navigatorKey`. In-memory user cache; `invalidateUserCache()` clears it so the next read refetches
  (used to stop a stale cache flag from resurrecting old state — e.g. the meal-plan gate). Session-
  static `mealPlanGatePassed` flag lets "Skip" clear the meal-plan generation gate permanently
  (`RouteGuard` no longer re-loops back into generation). **GDPR account deletion
  is server-authoritative** — `deleteAccount` invokes the `deleteUserAccount` callable (recursive
  subtree + Storage + Auth erasure) instead of client-side deletes. Email no longer sent to analytics.
- **FirestoreService** `firestore_service.dart` — Central Firestore I/O: user CRUD, activity
  logging, role assignment (`addUserRole`), streak, `getUserStream`. `getPrivateNutritionData(uid)`
  migrates + reads PII subcollection; `savePrivateNutritionData(uid, data)` writes it.
  `syncDeviceContext(uid)` writes the full device/IP/app-version context on every app open/resume
  (not just `is_online`) — called from `AppLifecycleService._setOnline`. `verifyAndRepairUserData`
  now backfills `email`/`displayName`/`photoURL` from Auth when missing, so the core profile is
  consistent regardless of sign-up method.
- **AdminStatusService** `admin_status_service.dart` — Real-time ban/admin status; `onBanStatusChanged`
  stream feeds `RouteGuard`; reads `admin_config` for maintenance/min-version.

## AI & Generation (`services/ai/` + AI services)
- **AIService** `ai/ai_service.dart` — LLM engine (OpenRouter). **Proxy-mandatory in release** (all
  calls go through the `aiProxy` Cloud Function); the bundled `OPENROUTER_API_KEY` is **debug-only**
  (release builds never ship/use a client key). 3-retry policy. Typed exceptions:
  `AIRetryableException`, `AIFatalException`, `AIQuotaExceededException` (402), `AIJsonParseException`.
  `generateCompletion`, `generateChatResponse`, `generateJson`. `isConfigured`, `hasProxy`,
  `setProxyUrl()` (from Remote/App Config). Every call is tagged with a `type`
  (`meal_plan`/`recipe`/`insight`/`weekly_recap`/`food_photo`/`chat`) that flows to `aiProxy` for
  per-request cost logging.
- **AiChatService** `ai/ai_chat_service.dart` — Builds profile-aware system prompt for nutrition chat.
- **AiChatHistoryService** `ai/ai_chat_history_service.dart` — In-memory conversation state (voice↔text).
- **PromptService** `ai/prompt_service.dart` — Prompt template library (recipe, weekly plan, ingredient
  validation, plan alternates) + locale instructions. **Prompt-injection guard**: user-supplied text
  is sanitized/fenced before insertion so it can't override system instructions.
- **RecipeGenerationService** `recipe_generation_service.dart` — Structured recipe gen via AI+Prompt.
- **FoodAnalysisService** `food_analysis_service.dart` — Estimates nutrition from a food description.
- **AiInsightService** `ai_insight_service.dart` — Daily accountability insight + 30/60/90-day fitness
  twin projection + risk detection. Caches daily insight in SharedPrefs (per date+locale); saves
  projections to `users/{uid}/ai_twin_projections`. `getLatestProjectionStream` is **locale-agnostic**
  (returns newest doc by `generatedAt` DESC regardless of language). Streams latest + history.
- **AiCreditService** `ai_credit_service.dart` — **Read-only** view over the server-only
  `ai_credits/{uid}` ledger (owner-read, server-write-only). Quota enforcement + consumption now live
  entirely in the `aiProxy`/`entitlements` Cloud Functions — the client no longer writes credits.
  Exposes `getCreditsStream` (live `used_today`/`reset_at`/`bonus`); legacy client
  consume/rollback/add paths removed. Daily limits: free 2/day, premium 20/day, IAP bonus never reset.

## Nutrition & Food
- **DishService** `dish_service.dart` — `dishes/` CRUD + seed; streams; admin edit/delete.
- **FoodLogService** `food_log_service.dart` — Logs meals (dish/recipe/scanned/quick/barcode),
  daily totals, today stream, date-range history. Auto-upserts `recent_foods`.
- **RecentFoodService** `recent_food_service.dart` — Last ~20 foods (Hive), quick-add carousel.
- **BarcodeLookupService** `barcode_lookup_service.dart` — Barcode → product nutrition (Open Food Facts).
- **WeeklyMealPlanService** `weekly_meal_plan_service.dart` — AI weekly plan; hash-based cache
  invalidation (profile change → regenerate); **filters allergen-unsafe dishes via `AllergenSafety`
  before sending candidates to the AI** (defense-in-depth on top of allergy validation);
  `getMealPlanHistory`, `restorePlan`, auto-archive to `meal_plan_history/{key}`. Writes
  `users/{uid}/meal_plans/current`.
- **MealPlanCalendarService** `meal_plan_calendar_service.dart` — Export plan as `.ics`.
- **NutritionAnalyticsService** `nutrition_analytics_service.dart` — Weekly summary, macro %, trends.
- **StorageService** `storage_service.dart` — Local Hive: recipes, plans, shopping, hydration, weight,
  settings (boxes: user/recipes/meal_plans/settings/shopping/hydration/weight). **Boxes are AES-256
  encrypted** — the cipher key is generated once and stored in `flutter_secure_storage` (Keychain/
  Keystore). One-time migration transparently re-opens and re-writes any pre-existing plaintext boxes
  under encryption.

## Social & Community
- **CommunityService** `community_service.dart` — Posts CRUD, cursor pagination (`fetchPostsPage`),
  comments, reactions, groups, topic filter (arrayContains tags), weekly highlights
  (`getTopPostThisWeek`/`getTopStreakUserThisWeek`), mention fan-out, content moderation
  (`_checkContent` blocked-keyword pre-screen — reads the list from **public-read
  `settings/content_filter`**, mirrored there by admins; previously read the admin-only
  `admin_config/global` doc, so the filter was dead for normal users), `reportContent`.
- **ChatService** `chat_service.dart` — Chats + messages, typing status, unread counts, mark-read,
  group/private/system creation.
- **FollowService** `follow_service.dart` — Following/followers (batch), counts, isFollowing stream,
  follow notification fan-out.
- **FriendService** `friend_service.dart` — Search users, friendship status, send/accept/reject.
- **FavoriteService** `favorite_service.dart` — `users/{uid}/favorites`; toggle, isFavorite stream.
- **ReferralService** `referral_service.dart` — 6-char codes (`referrals/{code}`). **Apply is
  server-authoritative** — calls the `applyReferral` callable (server-validated reward + commission
  ledger); the client no longer batch-writes rewards/premium. Reward: 7-day premium trial both sides.
- **ReputationService** `reputation_service.dart` — Reputation badges/score from activity.
- **SignalService** `signal_service.dart` — Ephemeral broadcasts (TTL via expiresAt).
- **StreakSquadService** `streak_squad_service.dart` — Squads (`squads/`), invite codes, leaderboard.
- **NotificationService** `notification_service.dart` — **Structured-only** in-app notifications
  (type, actorUid/Name/PhotoUrl, relatedId, metadata — never pre-rendered text). Pagination, mark-read.
- **NotificationPreferencesService** `notification_preferences_service.dart` — Per-group mute prefs
  (likes/comments/friends/system/referral) in `users/{uid}.notification_muted`.

## Coach & Gym
- **CoachService** `coach_service.dart` — Coach profiles, client links, discovery/search, top coaches
  (`getTopCoachesStream`: verified+accepting, avgRating DESC). `searchCoaches(query, city:, district:, sortBy:)` — sortBy: `avg_rating` | `client_count` (default) | `created_at`. `CoachProfileModel` includes `latitude`/`longitude` for client-side near-me sorting.
- **GymService** `gym_service.dart` — Gym CRUD, owner gym stream, member mgmt, discovery
  (`searchGyms(query, city:, district:, sortBy:, startAfter:, limit:)` — sortBy: `avg_rating` | `member_count` (default) | `created_at` | `name`), QR token.
- **GymLeaderboardService**, **GymAnalyticsService**, **GymApplicationService**, **GymPostService**.
- **CoachApplicationService**, **CoachReviewService** (transaction-updates avgRating/ratingCount).

## Billing & Credits
- **BillingService** `billing_service.dart` — `in_app_purchase`; subscriptions
  (`com.cookrange.premium.{monthly,yearly}`), consumable top-up (`cookrange_ai_credits_10`), restore.
  **No client-side premium grant or credit write** — every purchase is sent to the `validatePurchase`
  callable, which verifies the receipt against Apple/Google and writes `entitlements/{uid}` +
  `ai_credits/{uid}` server-side (mirrored to `subscription_tier`/`subscription_expires_at`).
- **CommissionService** `commission_service.dart` — `users/{uid}/commissions` + payout_requests;
  `recordReferralCommission` (₺5/premium referral), `recordCoachSessionCommission`, earnings summary.
  (Tracking layer only; payout processing deferred — see roadmap.)

## Admin & Moderation
- **AdminService** `admin_service.dart` — The admin API surface (~30 methods): application review
  (approve/reject coach+gym), `searchUsers`, `banUser`/`unbanUser`, `setUserRole`, history streams,
  `logAuditAction`+`auditLogStream`, `pendingCountStream`, reports (pending/reviewed/dismiss/remove +
  bulk), `fetchAnalyticsSnapshot` (count() aggregates), `premiumUsersStream`, `bannedUsersStream`,
  `aiUsageStream`, `grantBonusCredits` (writes the server-only `ai_credits/{uid}` ledger),
  `referralsStream`/`voidReferralCode`, program review
  (approve/reject/pending/history), `adminConfigStream`/`updateAdminConfig`, `broadcastsStream`/
  `sendBroadcast`, `setGymVerified`/`setCoachVerified`, `forceLogout`, `sendPasswordReset`,
  `getUserDataStats`, `getAppConfig`/`updateAppConfig` (read + audited write of `app_config/global`,
  backing `AdminAppConfigScreen`).
- **CostAnalyticsService** `cost_analytics_service.dart` — Admin-only cost/revenue/profit estimates
  (Firebase pricing + `count()` aggregates) **plus real AI usage**: `fetchAiUsageStats` reads
  `ai_usage_stats/global` (+ day buckets — total cost/requests/tokens, `by_model`, `by_type`) and
  `fetchUserAiLogs(uid)` queries `ai_usage_logs` for a per-user breakdown. Powers
  `AdminCostAnalyticsScreen` (now shows real AI spend, not just estimates).
- **AdminAppConfigScreen** `screens/admin/admin_app_config_screen.dart` — Admin editor for the Remote
  App Config (`app_config/global`) via `AdminService.getAppConfig`/`updateAppConfig`: AI models/limits,
  version gates + force-update, maintenance mode, announcement, feature kill-switches, rollout %.

## Feature, Config & Push
- **FeatureGateService** `feature_gate_service.dart` — Entitlement checks + `showPaywall()`.
- **AppConfigService** `app_config_service.dart` — Remote App Config client over `app_config/global`
  (public-read, admin-write, **no secrets**). Boot flow is **cache-first**: reads the SharedPrefs
  snapshot instantly, then background-refreshes with a **6h TTL**; exposes a reactive `ValueNotifier`
  so gates rebuild on change. Parses into `AppConfig` (`app_config_model.dart`, every field has a
  fail-safe default). Config sections: `ai` (text/vision model, `model_by_type`, `max_tokens`
  [`_by_type`], temperature, timeout, free/premium daily limits, feature toggles), `version`
  (min_supported/latest per platform, force_update, store URLs, i18n update_message), `maintenance`,
  `announcement`, `features` (kill-switch, default-ON), `rollout` (%), `limits`,
  `endpoints.ai_proxy_url`. Helpers: `isFeatureEnabled(key)` (kill-switch), rollout bucketing.
  Consumed by `version_gate.dart` (→ `ForceUpdateScreen`), `MaintenanceScreen`, `AnnouncementBanner`,
  and feature gates — all evaluated at `route_guard.dart` build start. The **same doc is read
  server-side by `aiProxy`** (5-min cache) so model/max_tokens/quota change without redeploy.
- **RemoteConfigService** `remote_config_service.dart` — Firebase Remote Config flags: `maintenanceMode`,
  `minVersion`, `aiModel`, `maxMealRetries`, `featureVoiceAssistant`, `featureNutritionAnalytics`,
  `aiProxyUrl`. (Being superseded by `AppConfigService`/`app_config/global`.)
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
  (batch-writes essentials=granted + optionals at registration), `applyCollectionConsent` (ties the
  user's consent state to the Analytics/Crashlytics collection flags so collection only runs once
  consent is granted). Source of truth:
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
- **DataExportService** — **Complete GDPR export**: profile + **private nutrition PII** + all
  user subcollections (logs, plans, lists, posts, food analyses, achievements, consents, etc.) +
  a Storage file manifest → JSON share.
- **LogService** — Structured logging + device/IP context (Hive-cached).
- **CrashlyticsService** — `recordError`, breadcrumbs, custom keys (screen/tier/aiModel).
  **Collection is privacy-by-default OFF** — enabled only after the user grants consent
  (via `ConsentService.applyCollectionConsent`).
- **AnalyticsService** — Event queue (Hive), batch, `logScreenView`. **Collection is
  privacy-by-default OFF** — gated on consent (no email or PII in event payloads).
- **PerformanceService** — `HttpMetric` on AI calls + custom traces.
- **ExerciseLogService**, **ProgramService**, **LeaderboardService**, **RecipeNoteService**,
  **ShoppingListSyncService** (`users/{uid}/lists/shopping`).
- **DishSeederService** (`seedIfEmpty` batch), **DishImageService**, **DemoContentSeeder**
  (sample programs; `seeds/` gate).
- **DeviceInfoService**, **ScreenUtilService**, **SystemUIService**, **AppInitializationService**
  (orchestrates boot), **AppLifecycleService**, **ProviderInitializationService**,
  **RouteConfigurationService**, **LoggingNavigatorObserver**.
- **GlobalErrorHandler** — single `FlutterError.onError` owner; wired into `MaterialApp.builder`.
- **AllergenSafety** (util) — Deterministic allergen filter: given a user's allergies/avoid lists,
  flags/removes unsafe dishes. Used by `WeeklyMealPlanService` (pre-AI) and food flows.
- **safeLaunchUrl** (util) — Hardened `url_launcher` wrapper: only opens URLs whose scheme + host pass
  an allowlist (blocks arbitrary/`javascript:`/unexpected-host navigation).
- **AppEnv** (util) — Central env reader (`flutter_dotenv`): typed access to keys, `APP_ENV`, and the
  debug-only `OPENROUTER_API_KEY`; single place that decides dev-vs-release behavior.
- **TestModeService** — dev test-mode toggle (Hive) + `TestDataLibrary`.
- **WhatsNewService** — once-per-version changelog gate (SharedPref `whats_new_last_version`).

---

## Cloud Functions (`functions/`)

> Server-authoritative security layer (hardening 2026-06-30). **10/12 functions + Firestore rules
> deployed to `cookrange-app`**; `appStoreNotifications` + `playRtdn` are pending go-live. App Check
> enforcement + store-credential requirements are gated by `APP_ENV` (`development` | `production`)
> in `config.js`.

**AI proxy** (`index.js`)
- **aiProxy** (HTTPS) — The release AI path. Verifies Firebase **ID token** + **App Check** (App Check
  gated by `APP_ENV`); enforces a **model allowlist**, `max_tokens`/payload-size caps, and a per-uid
  **rate limit**; **no wildcard CORS**. Runs **fail-closed `enforceAndConsumeQuota(uid)`** in a
  Firestore transaction (auto-resets daily counter at midnight, burns bonus credits first); returns
  **HTTP 402** when exceeded; otherwise proxies to OpenRouter with `OPENROUTER_API_KEY` (read from
  `functions/.env`). Rolls back the consumed credit on bad request / OpenRouter failure.
  Constants: `FREE_DAILY_LIMIT=2`, `PREMIUM_DAILY_LIMIT=20`. Reads **`app_config/global`** server-side
  (5-min cache) so model/`max_tokens`/quota can change without a redeploy. **Real cost tracking**:
  captures the OpenRouter `usage` token counts × per-model price (`MODEL_PRICING`) and writes
  per-request `ai_usage_logs/{id}` (uid, `type`, model, prompt/completion/total tokens, `cost_usd`,
  `unpriced`, `created_at`), rolls up `ai_usage_stats/global` (+ `day_YYYY-MM-DD` buckets, by_model/
  by_type), and increments per-user lifetime totals on `ai_credits/{uid}`.

**Entitlements & purchases** (`entitlements.js`, `purchases.js`)
- **grantPremium / revokePremium / grantBonusCredits / claimPurchaseToken** (`entitlements.js`) —
  The **only** writers of `entitlements/{uid}` (premium) and `ai_credits/{uid}` (credits);
  `subscription_tier` is mirrored to the user doc. Server-only.
- **validatePurchase** (callable, `purchases.js`) — Verifies receipts against the **Apple App Store
  Server API** + **Google Play Developer API**, dedupes purchase tokens, and grants entitlements/
  credits via `entitlements.js`. **Fail-closed** (no grant unless the store confirms).
- **appStoreNotifications** / **playRtdn** (`purchases.js`, *pending go-live*) — Store webhooks that
  **revoke** premium on refund/expiry.

**Economy & account** (`economy.js`, `account.js`)
- **applyReferral** (callable, `economy.js`) — Server-validated referral apply + server-side
  commission ledger (replaces the old client batch-write).
- **deleteUserAccount** (callable, `account.js`) — GDPR erasure: recursively deletes the user's
  Firestore subtree + Storage objects + the Auth user.

**Config** (`config.js`)
- **APP_ENV gating** — `development` | `production`; toggles App Check enforcement and the
  store-credential requirement so dev/emulator runs don't break.

**Notifications & broadcasts** (`index.js`)
- **onInAppNotificationCreated** (Firestore trigger) — On new `users/{uid}/notifications/{id}`,
  fans out an FCM push respecting the recipient's mute preferences.
- **onChatMessageCreated** (Firestore trigger) — On new `chats/{id}/messages/{id}`, pushes to other
  participants.
- **executeBroadcast** (internal helper) — Sends admin broadcasts to an audience (all/coaches/
  gymOwners/single uid), immediate or scheduled.

**Secrets / env** (Functions): `OPENROUTER_API_KEY` + Apple/Google store credentials in
`functions/.env`; `APP_ENV` selects enforcement mode.

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
