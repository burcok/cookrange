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

functions/index.js             Cloud Functions: aiProxy (+ quota), onInAppNotificationCreated,
                               onChatMessageCreated, executeBroadcast
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
token + App Check, runs `enforceAndConsumeQuota` in a Firestore transaction, returns 402 if
exceeded, else calls OpenRouter with the secret key) → response parsed, credit rolled back on
failure. Server is the quota authority; client is read-only in proxy mode.

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
- **Cloud Functions** (`functions/index.js`):
  - `aiProxy` — HTTPS; token + App Check validation, server-side AI quota, OpenRouter proxy.
  - `onInAppNotificationCreated` — Firestore trigger; push fan-out + mute prefs.
  - `onChatMessageCreated` — Firestore trigger; chat push.
  - `executeBroadcast` — internal helper for admin broadcasts.
- **Remote Config** — `ai_proxy_url`, `ai_model`, `maintenance_mode`, `min_version`,
  feature flags, `max_meal_retries`. Read via `RemoteConfigService` (Firestore admin_config
  overrides RC for instant effect).
- **App Check** — Play Integrity (Android) / DeviceCheck (iOS) / debug; soft-enforced at proxy.

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
