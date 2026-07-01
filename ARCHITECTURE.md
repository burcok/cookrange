# ARCHITECTURE.md — Cookrange System Map

> The structural truth of the codebase. If you're changing *where* something lives or
> *how layers talk*, this is the contract. Feature-level detail lives in `docs/`.

---

## 1. What Cookrange Is (technically)

A **Flutter** mobile app (iOS + Android) backed by **Firebase** and a small **Node.js
Cloud Functions** layer, with **OpenRouter** for LLM inference (proxied server-side).

- **274** Dart files · ~**100K** LOC
- **42** models · **75** services · **7** providers · **95** screens · **25+** DS widgets
- **State:** Provider (`ChangeNotifier`) — *not* Riverpod/Bloc
- **Backend:** Firestore (source of truth) + Storage + Auth + Messaging + Remote Config +
  Crashlytics + Performance + App Check
- **AI:** OpenRouter via a Cloud Function proxy (`aiProxy`) that enforces quota + hides the key
- **Trust:** **server-authoritative** — the client is not trusted for entitlements, AI credits, the
  economy, or moderation state (see §6.1)
- **Locales:** EN + TR (parity-gated in CI)

---

## 2. The Four-Layer Vertical

```
┌──────────────────────────────────────────────────────────────────┐
│  PRESENTATION            lib/screens/**, lib/core/widgets/**       │
│  Screens + DS widgets. Reads providers, calls services. No        │
│  direct Firebase. No business logic beyond view state.            │
└───────────────────────────────┬──────────────────────────────────┘
                                 │  context.read/watch<Provider>()
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│  STATE                    lib/core/providers/** (7 ChangeNotifiers)│
│  UserProvider, ThemeProvider, LanguageProvider, OnboardingProvider,│
│  NavigationProvider, DeviceInfoProvider, TestModeProvider.         │
│  Holds session state. Talks to services. Notifies UI.             │
└───────────────────────────────┬──────────────────────────────────┘
                                 │  Service() singletons
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│  SERVICES                 lib/core/services/** (75 singletons)     │
│  ALL business logic + Firebase/network access. Auth, Firestore,   │
│  AI, food, social, coach/gym, billing, admin, infra. See          │
│  docs/SERVICES.md. UI must go through these.                      │
└───────────────────────────────┬──────────────────────────────────┘
                                 │  models (de)serialize Firestore
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│  DATA                     lib/core/models/**, lib/core/data/**,    │
│                           lib/core/repositories/**                 │
│  Pure Dart models (fromFirestore/toFirestore/copyWith), seed data │
│  (dishes, TR locations), in-memory repo caches. See DATA_MODEL.md.│
└───────────────────────────────┬──────────────────────────────────┘
                                 ▼
┌──────────────────────────────────────────────────────────────────┐
│  BACKEND      Firestore · Storage · Auth · FCM · Remote Config ·   │
│               Crashlytics · Performance · App Check                │
│               + functions/index.js (aiProxy, notif fan-out)        │
│               + OpenRouter (LLM, behind aiProxy)                   │
└──────────────────────────────────────────────────────────────────┘
```

**Inviolable rules** (enforced by review, see `AGENTS.md` §4):
- UI never imports `cloud_firestore` directly — it calls a service.
- Models/services never import UI widgets.
- Services are singletons (`factory Foo() => _instance`).
- No new layer appears without an explicit instruction.

---

## 3. Directory Map

```
lib/
├── main.dart                  App entry: Firebase init → MultiProvider → MaterialApp
├── constants.dart             Legacy color consts (prefer AppPalette)
├── core/
│   ├── models/                42 data models (Firestore ↔ app boundary)
│   ├── data/                  dish_data.dart (seed dishes), turkish_locations.dart (81 il + ilçe)
│   ├── repositories/          DishRepository, FoodLogRepository, MealPlanRepository, ShoppingRepository (in-memory caches)
│   ├── providers/             7 ChangeNotifier providers (state layer)
│   ├── services/              75 singletons (business logic) — see docs/SERVICES.md
│   │   └── ai/                AIService, AiChatService, AiChatHistoryService, PromptService
│   ├── theme/                 Design tokens: palette, typography, dimensions, gradients, theme
│   ├── widgets/               Shared widgets; ds/ = the design system component library
│   │   └── ds/                AppButton, AppCard, AppGlassCard, AppSheet, AppShimmer, … (barrel: ds.dart)
│   ├── localization/          AppLocalizations (JSON-backed translate())
│   ├── constants/             onboarding_options.dart, etc.
│   └── utils/                 AppRoutes, RouteGuard, profile_navigation, ban_check_observer, accessibility_utils
├── screens/                   95 screens, one dir per feature — see docs/FRONTEND.md
│   ├── splash_screen.dart     Heavy init orchestration
│   ├── main_scaffold.dart     Bottom-nav hub (Home/Community/Profile) + side menu + voice overlay
│   ├── auth/ onboarding/ home/ community/ chat/ profile/ recipe/ shopping/ explore/
│   ├── ai/ notifications/ leaderboard/ legal/ discover/
│   └── gym/ coach/ programs/ admin/   ← business + admin (role-gated)
└── scripts/                   in-app one-off scripts

functions/                     Cloud Functions: index.js (aiProxy + quota, onInAppNotificationCreated,
                               onChatMessageCreated, executeBroadcast); entitlements.js, purchases.js,
                               economy.js, account.js (server-authoritative); config.js (APP_ENV)
```

---

## 4. The Critical Data-Flow Paths

### 4.1 App boot
`main()` → `Firebase.initializeApp()` → `MultiProvider` → `MaterialApp` (initialRoute = splash)
→ `SplashScreen` runs `AppInitializationService.initialize()` (dotenv/AI, error handler,
Firestore persistence + App Check, Hive, Remote Config → sets AI proxy URL, Crashlytics,
Analytics, Auth, FCM, Performance; background: dish + demo seeders) → `UserProvider.loadUser()`
(merges public doc + private nutrition, starts live listener) → `RouteGuard` resolves
(ban → auth → email-verify → onboarding → main).

### 4.2 Auth + role state
`AuthService` (Firebase Auth, Google, Apple) → `UserProvider` holds `UserModel` + a **live
Firestore listener** on `users/{uid}`. When an admin flips a role or subscription tier, the
listener auto-reloads and the side menu / gates update **without restart**.

### 4.3 AI request (quota-safe)
Screen → `AiCreditService.checkAndConsume()` (skipped if proxy mode) → feature service
(`RecipeGenerationService` / `WeeklyMealPlanService` / `AiChatService` / `AiInsightService`)
→ `AIService.generateJson/Completion()` → **`aiProxy` Cloud Function** (verifies Firebase ID
token + App Check, reads model/`max_tokens`/`temperature`/quota from `app_config/global` and
**ignores the client-sent model**, runs `enforceAndConsumeQuota` in a Firestore transaction, returns
402 if exceeded, else calls OpenRouter with the secret key) → response parsed, credit rolled back on
failure. Server is the quota authority; client is read-only in proxy mode. **Real cost tracking:**
`aiProxy` captures OpenRouter's `usage` token counts on each call and logs actual cost to
`ai_usage_logs` / `ai_usage_stats`.

### 4.4 PII separation
Public profile → `users/{uid}` (readable by authenticated users). Sensitive nutrition PII
(height/weight/gender/birth_date, allergies, dietary restrictions, disliked foods) →
`users/{uid}/private/nutrition` (owner-only, server-enforced). `OnboardingProvider` splits
writes via `_toPublicMap()` / `_toPrivateMap()`; `UserProvider` merges on read.

### 4.5 Notifications (no stored text)
Caller → `NotificationService.sendNotification(type, actorUid, actorName, relatedId, metadata)`
writes **structured** data only → `onInAppNotificationCreated` Cloud Function fans out a push
(respecting mute prefs) → reader's device renders localized text via `NotificationPresenter`.

---

## 5. State-Management Conventions

- **Provider** only. Mutations via `context.read<T>()`; UI via `context.watch<T>()` /
  `Consumer<T>` / `Selector<T>` (prefer `Selector` to minimize rebuilds).
- **Services** are stateless-ish singletons; per-session caches live in repositories or the
  service's own in-memory field.
- **Caching tiers** (choose deliberately, R3): in-memory (hot, session) · Hive/SharedPreferences
  (device-scoped, survives restart) · Firestore (source of truth, cross-device). Prefer
  stale-while-revalidate.

---

## 6. Backend Topology

- **Firestore** — source of truth. ~40 collection paths, ~52 composite indexes, full security
  rules. Map in `docs/DATA_MODEL.md`.
- **Storage** — profile photos, post/chat images, application docs, gym logos. Rules enforce
  owner-write + size/type limits.
- **Cloud Functions** (`functions/`):
  - `aiProxy` — HTTPS; token + App Check validation, model allowlist, `max_tokens`/payload caps,
    fail-closed server-side AI quota + per-uid rate limit, no wildcard CORS, OpenRouter proxy.
    Server-authoritative model config: reads `app_config/global` (Admin SDK, 5-min cache) for
    model/tokens/temperature/quota and ignores the client-sent model. Logs real OpenRouter token
    usage/cost to `ai_usage_logs` / `ai_usage_stats`. Requires the `allUsers` Cloud Functions Invoker
    role (deployed private; auth is in-code) — see `docs/PLATFORM.md` §5b.
  - `onInAppNotificationCreated` — Firestore trigger; push fan-out + mute prefs.
  - `onChatMessageCreated` — Firestore trigger; chat push.
  - `executeBroadcast` — internal helper for admin broadcasts.
  - `entitlements.js` — server-only `grantPremium` / `revokePremium` / `grantBonusCredits` →
    `entitlements/{uid}` + `ai_credits/{uid}`.
  - `purchases.js` — `validatePurchase` (Apple App Store Server API + Google Play Developer API
    receipt validation, token dedupe, fail-closed) + `appStoreNotifications` / `playRtdn` (revoke on
    refund/expiry).
  - `economy.js` — `applyReferral` (server-validated no-self-referral / one-per-account / max-uses,
    server commission ledger).
  - `account.js` — `deleteUserAccount` (recursive GDPR/KVKK erasure of the whole user subtree +
    Storage + Auth user).
  - `config.js` — `APP_ENV` (`development` | `production`); development relaxes App Check + store-cred
    requirements so functions deploy without them.
- **Remote Config** — `ai_proxy_url`, `ai_model`, `maintenance_mode`, `min_version`,
  feature flags, `max_meal_retries`. Read via `RemoteConfigService` (Firestore admin_config
  overrides RC for instant effect).
- **Remote App Config** — Firestore **`app_config/global`** (public-read, admin-write, no secrets)
  is the consolidated remote-config surface: `ai` (model/tokens/temperature/quota), `version`
  (force/soft update), `maintenance`, `announcement`, `features` (kill-switches), `rollout`,
  `limits`, `endpoints`. Client `AppConfigService` (cache-first + 6h TTL) drives version-gating,
  maintenance mode, announcement banner, and feature kill-switches; edited via `AdminAppConfigScreen`.
  `aiProxy` reads the same doc server-side (so model/quota change with **no redeploy**). Consolidates
  the older scattered RC `ai_proxy_url`/`ai_model` (client still reads RC `ai_proxy_url` for
  back-compat; `endpoints.ai_proxy_url` also honored).
- **App Check** — Play Integrity (Android) / App Attest (iOS) / debug; enforced at the proxy
  (gated by `APP_ENV`), real providers required in release.

### 6.1 Server-authoritative trust boundary

The client **renders** state but is never the authority for anything of value or safety-critical.
Premium, AI credits, the referral/commission economy, purchase validation, and account erasure are
**server-only** (the Cloud Functions above + locked Firestore rules — deployed to the `cookrange-app`
project; app not yet publicly launched).

- **Locked Firestore rules** — `users/{uid}` updates are field-locked: clients cannot write
  `subscription_tier`, `ai_credits_*`, `referral_used`, or `is_banned` (server/admin only;
  `user_roles` is intentionally not field-locked because admin power is gated server-side via
  `admin/status`). `ai_credits` / `entitlements` are owner-read + server-write; `processed_purchases`,
  `commissions` (write-only), and `failed_login_attempts` are server-only; `referrals` updates are
  owner/admin-only; content-length caps apply to posts/comments/chat/signals.
- **Client posture** — `AiCreditService` is **read-only** over the server credit ledger; billing and
  referral flows call server callables; `AuthService.deleteAccount` calls the server erasure function;
  the AI proxy is mandatory in release (bundled key is debug-only) with real App Check providers.
- **Hardening on the data path** — Hive boxes are AES-256 encrypted (key in `flutter_secure_storage`);
  Analytics/Crashlytics collection is privacy-by-default OFF, gated on consent; a complete GDPR data
  export, deterministic allergen safety filter on meal plans, prompt-injection guard, null-safe
  parsing of attacker-controlled docs, and a safe URL launcher round it out.
- **Deferred to go-live** (tracked in `TODO.md`): Android cleartext traffic still enabled (only Hive
  encryption done); no root/jailbreak detection, `FLAG_SECURE`, cert-pinning, or obfuscation; Storage
  chat-image scoping + upload scanning/EXIF strip; minimizing the world-readable user doc; fully
  server-authored notifications/friends; point-of-use AI consent; server-side streak/reputation.
  Console/owner-only steps: rotate the leaked Admin SA key, App Check registration + enforcement,
  store accounts + creds + iOS APNs, OpenRouter spend cap.

---

## 7. Cross-Cutting Systems

| Concern | Owner | Notes |
|---|---|---|
| Theming | `ThemeProvider` + `AppTheme` + `AppPalette` | light/dark + live primary color; never hardcode |
| i18n | `AppLocalizations` + `LanguageProvider` | EN/TR JSON, parity test gate; see docs/LOCALIZATION.md |
| Routing | `RouteConfigurationService` + `AppRoutes` + `RouteGuard` | named routes, all guarded except intro |
| Errors | `GlobalErrorHandler` (single `FlutterError.onError`) + `CrashlyticsService` | no silent catches |
| Analytics | `AnalyticsService` + `FirebaseAnalyticsObserver` | event queue, Hive-backed |
| Perf | `RepaintBoundary`, `PerformanceService` HttpMetric | 60fps target |
| Accessibility | `accessibility_utils.dart` | reduce-transparency/motion, semantics |
| Deep links | `DeepLinkService` (`app_links`) | `cookrangeapp.com/{recipe|post|user|...}/{id}` |

---

## 8. Role Model

`UserRole { consumer, gymOwner, coach, admin }` — a user may hold multiple roles
(`userRoles` array on the user doc). Navigation (side menu role cards, home role quick cards)
renders by role. Becoming a coach/gym owner goes through an **application → admin review →
role flip** flow (`coach_applications` / `gym_applications` → `AdminPanelScreen` →
`ApplicationReviewScreen` → role added + profile/gym doc created + notification). Detailed in
`docs/FRONTEND.md` (Business & Admin section).

---

## 9. Package Stack (high level)

Firebase suite · `provider` · `flutter_screenutil` (responsive) · `hive` (local) ·
`shared_preferences` · `cached_network_image` · `flutter_map`+`latlong2` (gym maps) ·
`mobile_scanner` (barcode/QR) · `qr_flutter` · `in_app_purchase` (billing) · `app_links`
(deep links) · `speech_to_text` (voice) · `geolocator` · `image_picker`/`file_picker` ·
`share_plus` · `flutter_local_notifications` · `flutter_dotenv` · `permission_handler`.
Full versioned list in `docs/SERVICES.md` §Dependencies and `pubspec.yaml`.

---

**See also:** `AGENTS.md` (how to work) · `CLAUDE.md` (rules) · `docs/INDEX.md` (doc map).
