# Cookrange — AI Engineering Guide

> AI-powered nutrition & fitness app. Flutter (iOS + Android) + Firebase backend.

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
| `users/{uid}` | User profile, onboarding data, streak |
| `users/{uid}/meal_plans/current` | Current weekly meal plan |
| `users/{uid}/food_logs/{logId}` | Daily food diary entries |
| `posts/{postId}` | Community posts |
| `posts/{postId}/comments/{commentId}` | Post comments |
| `chats/{chatId}/messages/{msgId}` | Chat messages |
| `notifications/{uid}/items/{id}` | In-app notifications |
| `dishes/{dishId}` | Recipe/dish database (seeded once) |
| `signals/{uid}` | Ephemeral social broadcasts |
| `admin/status/{uid}` | Ban/admin flags |

## Key Services

| Service | File | Notes |
|---|---|---|
| `AuthService` | `auth_service.dart` | Singleton, Firebase Auth wrapper, Google + Apple + email |
| `FirestoreService` | `firestore_service.dart` | User CRUD, activity logging, streak, notifications |
| `AIService` | `ai/ai_service.dart` | OpenRouter client, typed exceptions, 3-retry policy |
| `WeeklyMealPlanService` | `weekly_meal_plan_service.dart` | AI-generated plan, Firestore caching, hash invalidation |
| `FoodLogService` | `food_log_service.dart` | Real-time food diary stream for home dashboard |
| `StorageUploadService` | `storage_upload_service.dart` | Firebase Storage (avatars, post images) |
| `PushNotificationService` | `push_notification_service.dart` | FCM + local notifications |
| `CommunityService` | `community_service.dart` | Posts CRUD + cursor-based pagination |
| `DishService` | `dish_service.dart` | Firestore dish DB, seed on demand |
| `GlobalErrorHandler` | `global_error_handler.dart` | **Single** `FlutterError.onError` owner; wired into `MaterialApp.builder` |

## AI Integration

- Provider: OpenRouter (`https://openrouter.ai/api/v1/chat/completions`)
- Model: `deepseek/deepseek-r1t-chimera:free` (configurable)
- Key stored in `.env` (client-side for MVP; move server-side before GA)
- `AIService.isConfigured` guards all AI calls — returns empty results if key is placeholder
- JSON responses: use `AIService.generateJson()` which returns `Map<String, dynamic>`
- Error hierarchy: `AIRetryableException` → retry up to 3×; `AIFatalException` → abort
- Never add AI features that don't degrade gracefully when `isConfigured == false`

## Localization

- Two locales: `en` (English) and `tr` (Turkish) — **must remain in parity**
- Files: `lib/core/localization/translations/{en,tr}.json`
- Access: `AppLocalizations.of(context).translate('key.path')`
- **When adding any user-visible string, add both EN and TR keys simultaneously**
- Key naming: `screen.section.element` (e.g. `settings.account.change_email`)

## Theme System

- `ThemeProvider` manages `ThemeMode` (light/dark) and `primaryColor` (4 preset colors)
- `AppTheme.lightTheme(primaryColor)` / `AppTheme.darkTheme(primaryColor)` in `app_theme.dart`
- **Never hardcode colors** — always use `Theme.of(context)` or `isDark ? ... : ...`
- Dark background: `Color(0xFF0D1117)` or `Color(0xFF111827)`
- Light background: `Color(0xFFFCFBF9)` or `Color(0xFFFDFDFD)`
- Primary color slot: `themeProvider.primaryColor` — default orange `Color(0xFFF97300)`

## Code Conventions

- No comments unless the WHY is non-obvious
- Singletons for all services: `static final _instance = Foo._internal(); factory Foo() => _instance;`
- `mounted` check before every `setState` or `context` use after `await`
- Use `unawaited()` (with `dart:async` import) for intentional fire-and-forget
- `StatefulBuilder` inside `showDialog` for dialog-local loading state
- Platform guards: `if (Platform.isIOS)` for Apple Sign-In, Apple-specific UI
- Cursor pagination: `DocumentSnapshot startAfter` pattern (see `community_service.dart:fetchPostsPage`)

## MVP Status

All B1-B13 blockers are complete. App is in beta-ready state. See `TODO.md` for current roadmap.

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
5. `lib/core/localization/translations/en.json` — all user-visible strings
