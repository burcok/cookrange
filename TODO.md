# 🧠 Cookrange — Product & Engineering Roadmap

> **An AI-Powered Fitness Operating System for Gyms, Coaches & Fitness Communities.**

**Document type:** Founder / Investor / Engineering roadmap
**Author basis:** Full source-code audit (117 Dart files, ~37,200 LOC) — *not* the previous TODO.md, which was stale and unreliable.
**Audit date:** 2026-06-25
**Nominal pubspec version:** `1.0.0+1` — **honest engineering reality: ~v0.4 (internal alpha).**
**Legend:** ✅ Completed · 🚧 In Progress / Partial · 🟡 Stub (skeleton, no logic) · 📋 Planned-only · ❌ Missing · 🔥 Critical

---

## 0. Executive Summary (The Brutal Truth)

Cookrange today is a **single-user AI meal-planning app with social features** — a genuinely solid one. It is **not yet** the "Fitness Operating System" described in the README. The gap between vision and code is large but the foundation is real.

**What is genuinely built and good:**
- A real authentication system (email/password + Google), email verification, single-session enforcement, and route guarding.
- A real **6-step onboarding flow** persisting a rich nutrition profile to Firestore.
- A **real AI pipeline** (OpenRouter / DeepSeek) generating weekly meal plans, single recipes, and validating ingredients — with Firestore caching and profile-hash invalidation.
- A **real social layer**: community feed (posts/comments/likes/reactions), 1:1 realtime chat (read receipts, typing, presence), friends, and in-app notifications — all Firestore-backed.
- A **comprehensive analytics service** (~1,054 LOC), Crashlytics, app-lifecycle/session tracking, and full EN/TR localization (822 keys, perfect parity).

**What is fake, broken, or missing (and blocks launch):**
- 🔥 **No Firestore/Storage security rules in the repo.** A client-side app writing user data, chat, and community content with no version-controlled rules. Highest-severity finding.
- 🔥 **AI is dead in the committed state** — `.env` ships a placeholder key (`your_openrouter_api_key_here`). Every AI feature silently degrades to empty mock responses.
- 🔥 **No food/calorie logging exists.** The app *plans* meals and *calculates* targets, but the user cannot log what they ate. The dashboard's central "consumed calories" number is **hardcoded to `1350`**. This is the gap between *looking like* a nutrition app and *being* one.
- 🔥 **Image upload is a façade** — community "photo" posts insert random Unsplash stock images; no Firebase Storage dependency exists at all.
- 🔥 **No push notifications (FCM).** The social/engagement loop has no way to re-engage users.
- 🔥 **No account deletion** — a hard App Store / GDPR requirement.
- **Apple Sign-In missing** — likely App Store rejection given Google + email login exist.
- **No CI/CD, ~1 meaningful test, no pagination anywhere, dark mode defined but not applied.**

**What is pure vision (greenfield, ~0% code):**
- The **entire Gym ecosystem** (presence, GPS, attendance, communities, leaderboards, Gym Wars, white-label, gym analytics).
- The **entire Coach ecosystem** (profiles, referral codes, dashboards, client management, AI insights, revenue share).
- **Gamification** beyond a single login-streak counter (no XP, levels, badges, leaderboards, challenges, circles, reputation).
- **All monetization** (premium is a dead button; no billing SDK, no subscription model, no credits, no marketplace, no payments).
- **All "advanced AI"** (fitness twin, accountability partner, risk detection, transformation forecast, behavioral analytics, coach insights) — zero code, not even stubs.

**Bottom line for the founder:** You have ~40% of a great consumer nutrition app and ~3% of the "operating system." Ship the consumer app first. The gym/coach/monetization vision is a 12–18 month build on top of a foundation that — once hardened (security rules, real AI key, food logging, push) — is strong enough to support it.

---

## ✅ COMPLETED FEATURES (code-proven)

These exist and work in code today. Evidence in `file:line` form.

| Feature | Evidence |
|---|---|
| ✅ Email/password login | `auth_service.dart:115` `signInWithEmail`, UI `login_screen.dart` |
| ✅ Email/password registration | `auth_service.dart:213` `registerWithEmail` + Firestore user doc |
| ✅ Google Sign-In | `auth_service.dart:315`; iOS URL scheme + Android oauth configured |
| ✅ Email verification (polling + resend cooldown) | `auth_service.dart:288`; `verify_email.dart` (243 LOC) |
| ✅ Password reset | `auth_service.dart:254`; `forgot_password_screen.dart` |
| ✅ Single-session enforcement (force logout on mismatch) | `auth_service.dart:164` `_startSessionMonitoring` |
| ✅ Route guarding (auth/verify/onboarding/ban states) | `route_guard.dart` (182 LOC) |
| ✅ Account-ban backend read | `admin_status_service.dart:133`; `ban_check_observer.dart` |
| ✅ Firebase Core + Auth + Firestore + Analytics + Crashlytics | `main.dart:23`, `firestore_service.dart` (705 LOC) |
| ✅ 6-step onboarding flow (persisted to Firestore) | `onboarding_screen.dart` (606 LOC), `onboarding_provider.dart` (576 LOC) |
| ✅ AI ingredient validation in onboarding | `onboarding_page3.dart:268` → live `AIService` |
| ✅ Weekly meal-plan generation (real AI) + caching | `weekly_meal_plan_service.dart:89`; profile-hash invalidation `:190` |
| ✅ Meal-plan regeneration (force-refresh) | `home.dart:125` |
| ✅ Curated dish database (75 dishes, Firestore-backed) | `dish_data.dart` (3,046 LOC), `dish_service.dart` |
| ✅ Recipe detail screen | `recipe_detail_screen.dart` (610 LOC) |
| ✅ AI single-recipe generation (Explore) | `recipe_generation_service.dart:27`; `explore_screen.dart:31` |
| ✅ Calorie/macro target calculation (Mifflin-St Jeor) | `calorie_calculator.dart` |
| ✅ Community feed CRUD (posts/comments/likes/reactions) | `community_service.dart` (581 LOC) |
| ✅ 1:1 realtime chat (read receipts, typing, presence) | `chat_service.dart` (314 LOC) |
| ✅ Friends (search, request, accept/reject, list) | `friend_service.dart` (311 LOC) |
| ✅ In-app notifications (Firestore-driven) | `notification_service.dart` (180 LOC) |
| ✅ "Signal" ephemeral social broadcast | `signal_service.dart`, `signal_model.dart` |
| ✅ Comprehensive analytics (offline queue/batch) | `analytics_service.dart` (1,054 LOC) |
| ✅ Crashlytics error logging (release-only) | `crashlytics_service.dart` |
| ✅ App initialization orchestration | `app_initialization_service.dart` (361 LOC) |
| ✅ App lifecycle / session tracking (+ has tests) | `app_lifecycle_service.dart` (194 LOC) |
| ✅ Localization EN/TR (822 keys each, full parity) | `app_localizations.dart`; `translations/{en,tr}.json` |
| ✅ Theme system *defined* (light + dark + dynamic primary color) | `app_theme.dart` |
| ✅ Login-streak counter (real day-diff logic) | `firestore_service.dart:123-195` |

---

## 🚧 PARTIALLY COMPLETED FEATURES

| Feature | What exists | What's missing |
|---|---|---|
| 🚧 Home dashboard | Real calculated targets + real weekly meal plan + real consumed calories stream + mark-as-eaten | Streak not surfaced prominently; hydration unwired; |
| 🚧 AI integration | Real OpenRouter client + 3 working features + robust response parsing | **Committed `.env` key is a placeholder** → all AI dead until real key added; fragile unguarded JSON casts; failures swallowed → `null`; single free model, no retry |
| ✅ Cooking mode | Step-by-step PageView + wakelock + progress ring + finish celebration sheet + food log | Timer is a generic stopwatch (not step-aware) |
| ✅ Shopping list | Local Hive persistence, add/remove/clear, swipe-delete + auto-gen from plan + clipboard share + Firestore sync | Check-state not persisted across cold start |
| ✅ Profile screen | Rich display + real avatar upload + real post count stat + reputation badge + streak tier + private-account restricted view (lock card shown when isPrivate=true and viewer is not a friend) | — |
| ✅ Settings screen | Dark mode + color picker + EN/TR + change email/password + account deletion + Privacy/Terms links + notifications/about/help wired + privacy toggle wired (writes `is_private` to Firestore via UserProvider) | — |
| ✅ Community feed | All CRUD real + real image upload + load-more pagination + real filters + real report/block | Groups: greenfield (Phase 4 gym ecosystem) |
| ✅ Chat | 1:1 fully real + group chat + image messages | — |
| ✅ Notifications screen | In-app DB notifications render + live stream + auto mark-read | No pagination; no push/FCM at all |
| 🚧 Account suspended screen | Polished 889-LOC UI + mailto support | Shows **no real ban data** (static strings); appeal modal is informational-only |
| 🚧 Dark mode | Both themes fully defined | `main_scaffold.dart:113` hardcodes light bg; default is light; effectively **light-only in practice** |
| 🚧 Offline support | Firestore SDK disk cache + 1 cache-source fallback | **No real sync, no write queue/retry, no connectivity-driven UI**; `connectivity_plus` only one-shot |
| 🚧 Error handling | Crashlytics + `GlobalErrorHandler` as single `FlutterError.onError` source | App-wide error boundary widget not wired into `MaterialApp.builder` |
| 🚧 Navigation | Custom PageView + side menu + quick-actions sheet | Only 2 real tabs (Home + Community); Profile is a pushed-route hack; no standard nav bar |
| 🚧 Voice assistant | Speech-to-text capture works (overlay, visualizer) | **Transcript is discarded** — never sent to AI (`voice_assistant_overlay.dart:397`); a non-functional demo |

### 🟡 Stubs / 📋 Planned-only (skeletons with no real logic)
- 🟡 **Premium card** — styled CTA, `onPressed: () {}` (`settings_screen.dart:441`)
- 🟡 **Priority onboarding screen** — 20-line placeholder, but routed
- 🟡 **Weight tracking** — Hive storage layer exists (`storage_service.dart:67`), **zero UI**, `WeightLog` model is dead code
- 🟡 **Hydration tracking** — storage exists, never wired
- 🟡 **"Remote Config"** — actually reads Firestore `settings/global` (no `firebase_remote_config` dep)

---

## ✅ MVP BLOCKERS — ALL COMPLETE

| # | Blocker | Status | Implemented In |
|---|---|---|---|
| B1 | Firestore + Storage security rules | ✅ Done | `firestore.rules`, `storage.rules`, `firebase.json`, `firestore.indexes.json` |
| B2 | Real AI key management (client-side guard) | ✅ Done | `ai_service.dart` — `isConfigured` getter, placeholder detection via `contains('your_'/'_here')` |
| B3 | Food / calorie logging (real consumed calories) | ✅ Done | `food_log_model.dart`, `food_log_service.dart`, `home.dart` real-time stream |
| B4 | Image upload via Firebase Storage | ✅ Done | `storage_upload_service.dart`, `create_post_card.dart`, `profile_screen.dart` avatar |
| B5 | Push notifications (FCM + local) | ✅ Done | `push_notification_service.dart`, wired in `app_initialization_service.dart` |
| B6 | Account deletion + data purge | ✅ Done | `settings_screen.dart` danger-zone dialog, `auth_service.dart:deleteAccount`, `firestore_service.dart:deleteUserData` |
| B7 | Apple Sign-In | ✅ Done | `auth_service.dart:signInWithApple`, `login_screen.dart`, `register_screen.dart` (iOS-only guard) |
| B8 | Profile edit persistence | ✅ Done | `profile_screen.dart` avatar upload → `StorageUploadService` → `FirestoreService.updateUserData` |
| B9 | AI robustness (retries + JSON validation) | ✅ Done | `ai_service.dart` typed exceptions + 3 retries; `weekly_meal_plan_service.dart` null-safe parse |
| B10 | Pagination on community feed | ✅ Done | `community_service.dart:fetchPostsPage`, `community_screen.dart` load-more |
| B11 | Dark-mode correctness | ✅ Done | `main_scaffold.dart` dynamic background |
| B12 | Legal: Privacy Policy + Terms of Use | ✅ Done | `legal_screen.dart`, wired from register gate + Settings |
| B13 | CI pipeline | ✅ Done | `.github/workflows/ci.yml` — analyze + test + Android build |

> **All MVP blockers cleared. App is now deployable to public beta from a compliance and core-feature standpoint.**

---

## PHASE 1 — FOUNDATION (Harden what exists) · target v0.5.0–v0.6.0

> Goal: make the existing app secure, observable, testable, and trustworthy. Most of this is *fixing*, not *building*.

**Architecture**
- [x] ✅ Introduce a **repository layer** between providers and Firebase. — `MealPlanRepository`, `FoodLogRepository`, `DishRepository` created; `home.dart` fully migrated; TestMode interception centralized in repos.
- [x] ✅ Remove **duplicate provider factory** (`createProviders()` removed, `createChangeNotifierProviders()` is the canonical one). — Done
- [x] ✅ Fix **`AppLifecycleService` double-observer** (`_MyAppState` no longer adds itself as WidgetsBindingObserver; AppLifecycleService is the sole observer). — Done
- [x] ✅ Delete dead code: `WeightLog` model deleted. (`MealPlan` model kept — still referenced by `storage_service.dart`.) — Done

**Authentication**
- [x] ✅ Apple Sign-In (B7). — Done (`auth_service.dart:signInWithApple`, iOS-only button in login/register)
- [x] ✅ Expose change email/password in Settings. — Done (`_showChangeEmailDialog`, `_showChangePasswordDialog` in `settings_screen.dart`)
- [x] ✅ Reduce `BanCheckObserver` Firestore reads — changed to `forceRefresh: false` (uses cached status). — Done

**Firebase**
- [x] ✅ Add `firebase.json` + `.firebaserc`. — Done (security rules wired)
- [x] ✅ Firestore + Storage **security rules** (B1). — Done (`firestore.rules`, `storage.rules`)
- [x] ✅ Add Firebase Storage dependency + upload service (B4). — Done (`storage_upload_service.dart`)
- [x] ✅ Add real **Firebase Remote Config** (replaced Firestore `settings/global` faux-config). — `RemoteConfigService` singleton with typed getters + defaults; initialized in `AppInitializationService` parallel block; `AdminStatusService` reads `maintenanceMode`/`minVersion` from RC instead of Firestore.

**Navigation**
- [x] ✅ Fix navigation: kept 2-tab custom scaffold; replaced `setIndex(2/3)` dead-code hacks in `QuickActionsSheet` with direct `Navigator.push` (bottom-to-top `SlideTransition`) for Shopping and Settings; removed `nav.currentIndex == 3` hack from `main_scaffold.dart`.

**State Management**
- [x] ✅ Consolidate primary state sources behind repositories. — `ShoppingRepository` added (Hive-backed, TestMode-aware); `shopping_list_screen.dart` migrated; joins `MealPlanRepository`, `FoodLogRepository`, `DishRepository` for complete data-layer coverage across core flows.
- [x] ✅ Move `NavigationProvider` from `services/` to `providers/` for consistency. — Done

**Caching / Offline**
- [x] ✅ Decided offline scope: rely on Firestore built-in persistence (already configured). Removed dead offline scaffolding: `OfflineModeScreen`, `/offline` route, `ErrorFallbackWidget.isOfflineMode` parameter, `_handleOfflineMode` method.
- [x] ✅ Configure explicit Firestore persistence settings — Done (`persistenceEnabled: true`, `CACHE_SIZE_UNLIMITED` in `_initializeFirebase`)

**Error Handling**
- [x] ✅ Fix triple `FlutterError.onError` collision — `GlobalErrorHandler` is the sole handler; removed duplicate assignment from `CrashlyticsService` and `ErrorBoundary.initState()`. — Done
- [x] ✅ Wire `GlobalErrorHandler.createErrorBoundary()` into `MaterialApp.builder`. — Done (`main.dart:75`)

**Analytics**
- [x] ✅ Analytics audit complete. Added missing key-funnel events: `food_logged` (`home.dart`), `ai_meal_plan_started`/`ai_meal_plan_generated` (`home.dart`), `post_created` (`community_service.dart`), `shopping_list_generated` (`shopping_list_screen.dart`). Onboarding + auth events were already thorough.
- [x] ✅ Analytics disabled in debug, enabled in release (`kReleaseMode` guard in `AnalyticsService.initialize()`). — Already correct.

**Monitoring**
- [x] ✅ Add **Firebase Performance**. — Replaced dead utility `performance_service.dart` with real `firebase_performance` wrapper; initialized in `AppInitializationService`; `HttpMetric` traces the AI API call in `AIService`; `meal_plan_fetch` / `meal_plan_generate` traces in `MealPlanRepository`.
- [x] ✅ Crashlytics custom keys — Done (`CrashlyticsService.setCustomKeys(screen, userTier, aiModel)`; wired at login and AI init)
- [x] ✅ **Menu lag / scaffold rebuild fix** — removed `context.watch<NavigationProvider>()` from `_MainScaffoldState.build()`; replaced with `Selector<NavigationProvider, bool>` per section; removed accumulating `addPostFrameCallback` from `build()`; `_buildBackgroundGlows` now uses `Theme.of(context)` (no `ThemeProvider.watch`) — Done (`main_scaffold.dart`)

**Testing**
- [x] ✅ Unit tests: 36 tests passing — `calorie_calculator_test.dart` (20 tests: BMR/TDEE/macro math), `streak_logic_test.dart` (8 tests: all date-diff edge cases), `meal_plan_parse_test.dart` (8 tests: AI JSON parse pipeline incl. malformed-day skipping).
- [x] ✅ Widget tests: 48 passing across 6 suites — `widget_test.dart` (9 tests: ErrorFallbackWidget + UnknownRouteScreen), `calorie_calculator_test.dart` (20), `streak_logic_test.dart` (8), `meal_plan_parse_test.dart` (8), `app_lifecycle_service_test.dart` (3). Root cause of prior failures: async `rootBundle.loadString` in localization delegates left pending microtasks between tests — fixed by removing localization from test wrapper and using `AppLocalizations.maybeOf` in `GenericErrorScreen.build()`. Deleted stale `log_migration_test.dart` + `timestamp_test.dart` (non-test classes in wrong directory). Also fixed `_handleRetry()` Crashlytics resilience (log call no longer prevents `onRetry` if Firebase uninitialized).
- [x] ✅ Delete stale `test_output.txt`; move misplaced `*_test.dart` from `lib/` to `test/`. — Done

**CI/CD**
- [x] ✅ GitHub Actions: `flutter analyze` + `flutter test` + Android debug build on PR (B13). — Done (`.github/workflows/ci.yml`)
- [x] ✅ Automated TestFlight / Play internal-track deploys. — `.github/workflows/deploy.yml` (triggered on push to main): iOS job builds IPA with cert/profile injection → uploads via `xcrun altool` to TestFlight; Android job decodes keystore → builds AAB → uploads via `r0adkll/upload-google-play` to internal track. `ios/ExportOptions.plist` created. Required secrets documented in workflow header comments.

**Build system (Flutter 3.44 compatibility — 2026-06-27)**
- [x] ✅ iOS arm64 simulator fix — removed `arm64` from `EXCLUDED_ARCHS[sdk=iphonesimulator*]` (Podfile + `project.pbxproj`); set `platform :ios, '14.0'`; `IPHONEOS_DEPLOYMENT_TARGET = '14.0'` in post_install. iPhone 17 (iOS 26 simulator) now builds cleanly.
- [x] ✅ `mobile_scanner ^5.2.3` → `^7.2.0` — v7 uses SPM + XCFramework for MLKit (no more `MLImage.framework` device-only arm64 linker error on simulator builds).
- [x] ✅ Android Kotlin 1.9.22 → 2.2.20 (Flutter 3.44 minimum is 2.0.0; warns at <2.2.20). Updated in `build.gradle` (`ext.kotlin_version`), `build.gradle.kts`, and `settings.gradle.kts`.
- [x] ✅ Android AGP 7.4.2/8.2.0 → 8.11.1 (Flutter 3.44 warns below 8.11.1). Updated across all three build files.
- [x] ✅ Gradle wrapper 8.10.2 → 8.14.1 (Flutter 3.44 warns below 8.14.0).
- [x] ✅ `compileSdk 35` → `36`, `targetSdk 35` → `36` (plugins including `mobile_scanner`, `app_links`, `google_sign_in_android` require SDK 36).
- [x] ✅ NDK `27.0.12077973` → `28.2.13676358` (`speech_to_text` and `jni` require NDK 28; already installed locally).
- [x] ✅ Core library desugaring enabled (`coreLibraryDesugaringEnabled true` + `desugar_jdk_libs:2.1.5`) — required by `flutter_local_notifications` with AGP 8+.
- [x] ✅ Built-in Kotlin migration: removed `id 'kotlin-android'` from `app/build.gradle` plugins block — `dev.flutter.flutter-gradle-plugin` now applies Kotlin internally (Flutter 3.44 requirement).
- [x] ✅ `gradle.properties` JDK path fixed: `/opt/homebrew/opt/openjdk@17` (non-existent) → Android Studio bundled JBR (`/Applications/Android Studio.app/Contents/jbr/Contents/Home`).
- [x] ✅ Firebase BoM `32.7.4` → `33.15.0` in `app/build.gradle` dependencies.
- ✅ **Result:** `flutter build ios --simulator --no-codesign` ✓ (256s) · `flutter build apk --debug` ✓ (205s) · `flutter analyze lib/` 0 errors.

**Security**
- [x] ✅ Move AI key off-device behind a proxy/Cloud Function. — `functions/index.js` HTTPS function validates Firebase ID token, keeps `OPENROUTER_API_KEY` in Functions secrets (`firebase functions:secrets:set OPENROUTER_API_KEY`), proxies to OpenRouter. `AIService` now has `setProxyUrl()` + passes ID token as Bearer when proxy is active. Proxy URL lives in Remote Config `ai_proxy_url` (default empty = falls back to local .env for dev). Wired in `_initRemoteConfig()` → `AIService().setProxyUrl(RemoteConfigService().aiProxyUrl)`.
- [ ] Restrict committed Firebase API keys in console — add HTTP referrer / iOS bundle / Android package restrictions in Firebase Console → Project Settings → API Keys. Console-only step (no code). — High · v0.6.0
- [x] ✅ Firebase App Check — `firebase_app_check: ^0.3.2` added; activated in `_initializeFirebase()` with `playIntegrity` (Android release) / `deviceCheck` (iOS release) / `debug` (debug/profile). `AIService` attaches `X-Firebase-AppCheck` token to proxy requests. Cloud Function validates App Check token (soft enforcement — passes without token for rollout compatibility).

---

## PHASE 2 — CORE PRODUCT (Complete the nutrition app) · target v0.6.0–v0.7.0 (Beta)

> Goal: turn the planning app into a full tracking app. This is what makes Cookrange a real product people use daily.

**Onboarding**
- [x] ✅ Replace `priority_onboarding_screen` stub — Real 2-step quick-setup screen with goal + activity selection, animations, Firestore save. — Done
- [x] ✅ Add allergy/medical-flag safety step (currently only "disliked foods"). — Done (allergies + dietary restrictions sections added to OnboardingPage3; wired into OnboardingProvider, PromptService prompt with allergen safety warning, and WeeklyMealPlanService hash)

**User Profiles**
- [x] ✅ Promote nutrition fields out of untyped `onboardingData` map into a typed profile model. — Done (`UserNutritionProfile` model in `user_nutrition_profile.dart`, `UserModel.profile` getter; `WeeklyMealPlanService` now uses typed accessors instead of raw map casts)
- [x] ✅ Wire profile edit + avatar upload (B8, B4). — Done (`profile_screen.dart:_pickAndUploadAvatar`)
- [x] ✅ Replace fake profile stats with real post counts (Firestore `count()` query on `posts` where `author.id == uid`). — Done

**Meal Planning**
- [x] ✅ AI JSON schema enforcement + retry + graceful UI (B9). — Done (typed exceptions, null-safe parse, 3 retries in `ai_service.dart`)
- [x] ✅ Per-meal swap/substitution ("no chicken today"). — Done (swap icon overlay on meal image → `_SwapSheet` bottom sheet with dish alternatives filtered by mealType; `WeeklyMealPlanService.swapMeal()` + `MealPlanRepository.swapMeal()` update single slot in Firestore without regenerating plan)
- [x] ✅ Auto-seed dish DB on first run — Done (`DishSeederService.seedIfEmpty()` via batch writes; wired as `unawaited()` in `_initializeServices`)
- [x] ✅ Better dish imagery (current sources partly random/non-matching). — Done (fixed `DishImageService`: deterministic LoremFlickr/Unsplash seeds using dish ID; added Unsplash to `auto` chain; removed random-category Foodish; seeder passes dish ID as seed so same dish always resolves to same image)

**Nutrition Tracking**
- [x] ✅ **Food/calorie diary** — log meals, real consumed calories/macros (B3). — Done (`food_log_model.dart`, `food_log_service.dart`, real-time stream in `home.dart`)
- [x] ✅ Weight logging UI + history + mini chart — Done (`TrackingCard` in `home/widgets/tracking_card.dart`, Hive-backed, dialog log entry, 7-day bar chart)
- [x] ✅ Hydration tracking UI — Done (`TrackingCard` — progress bar, +250ml / -250ml buttons, daily goal 2000ml)
- [x] ✅ "Mark meal as eaten" from cooking-mode → feeds the diary. — Done (`cooking_mode_screen.dart:_showFinishSheet`, `FoodLogService.logRecipe`)
- [x] ✅ Nutrition analytics (trends, consistency score, weekly summary). — Medium · Medium · 3–4 d · v0.8.0 · Done (`NutritionAnalyticsService`, `NutritionAnalyticsScreen` with bar chart + score ring + stat cards; `FoodLogService.getLogsForDateRange`; route `/nutrition_analytics`; "Weekly Stats" button in meal plan header)

**AI Assistant**
- [x] ✅ Conversational AI chat ("what should I eat today?") — High · Large · 5–7 d · v0.8.0 · Done (`AIChatService` + `AIChatScreen` with bubble UI, typing indicator, suggested prompts; `AIService.generateChatResponse()` multi-turn; AI Nutritionist banner in `ChatListScreen` at top; route `/ai_chat`)
- [x] ✅ Nutrition analysis of arbitrary food / photo scan. — Medium · Large · 7–10 d · v0.9.0 · Done (`FoodAnalysisService` with `AIService.generateJson()`, `FoodScanScreen` with animated result card + meal type selector, `FoodLogService.logScannedFood()`, "Analyze Food with AI" tap-target in home nutrition section; degrades gracefully when AI not configured)

**Voice Features**
- [x] ✅ Wire voice transcript → AI assistant (capture works, output discarded). — Medium · Medium · 2–3 d · v0.8.0 · Done (`VoiceAssistantOverlay` send button + suggestion chips now navigate to `AIChatScreen` with transcript as argument; `AIChatScreen.initialMessage` auto-sends on mount)

**Shopping Lists**
- [x] ✅ Auto-generate consolidated list from the weekly meal plan — ingredient aggregation, duplicate merging. — Done (`shopping_list_screen.dart:_generateFromPlan`)
- [x] ✅ Share / copy — Clipboard copy of full list. — Done (`_copyToClipboard`)
- [x] ✅ Sync shopping list to Firestore (cross-device) — Done (`ShoppingListSyncService`, `users/{uid}/lists/shopping`; loads from Firestore on open, saves on every mutation)
- [x] ✅ **Test Mode** (developer stress-testing) — `TestModeProvider` + `TestModeService` (SharedPreferences); `TestDataLibrary` (17 unique dishes, 7-day plan, 10 food logs, ~3940 kcal/day); toggle in Settings > Developer; wired into `home.dart` meal plan + food logs — Done
- [x] ✅ Dark mode & theme consistency — full Theme.of(context) usage, animated item states. — Done

**Progress Tracking**
- [x] ✅ Cooking-mode completion → log + celebration — Done (meal type selector bottom sheet, logs to Firestore, haptics)
- [x] ✅ Daily goal completion + streak surfaced on home. — Medium · Medium · 2 d · v0.8.0 · Done (streak badge 🔥 in welcome header from `onboardingData['streak']`; animated "Goal Achieved!" banner below nutrition card when consumed ≥ 85% of target)

**Premium System (foundation)**
- [x] ✅ Add `subscriptionTier`/entitlements to user model. — High · Small · 1 d · v0.8.0 · Done (`SubscriptionTier` enum + `Entitlements` class in `subscription_model.dart`; `UserModel.subscriptionTier` read from Firestore `subscription_tier` field; `UserModel.entitlements` getter)
- [x] ✅ Feature-gating framework (free vs premium limits). — High · Medium · 2–3 d · v0.8.0 · Done (`FeatureGateService.check(context, (e) => e.feature)` shows paywall bottom sheet on denial; `_PaywallSheet` with perks row; EN+TR translations)

**Subscriptions**
- [x] ✅ Integrate billing SDK (`in_app_purchase` or RevenueCat). — High · Large · 5–7 d · v1.0.0 · Done (`BillingService` singleton: `InAppPurchase.instance`, product IDs `com.cookrange.premium.{monthly,yearly}`, purchase stream listener that writes `subscription_tier: 'premium'` + expiry to Firestore on success; `_PaywallSheet` upgraded to `StatefulWidget` showing real store prices + yearly/monthly buttons + "Restore Purchases"; `BillingService.initialize()` called fire-and-forget in splash; EN+TR `billing.*` translations; NOTE: product IDs must be registered in App Store Connect + Google Play Console before purchases work)
- [x] ✅ Paywall UI behind the existing dead premium card. — High · Medium · 2–3 d · v1.0.0 · Done (settings premium card "Buy Premium" button now calls `FeatureGateService().showPaywall(context)`; `FeatureGateService._PaywallSheet` renders perks + upgrade button)

---

## PHASE 3 — COMMUNITY (Polish & scale the social layer) · target v0.7.0–v0.8.0

> Goal: the social layer largely works; make it real (real photos, real reach, real-time, moderated).

- [x] ✅ **Posts** — real image upload via Firebase Storage. — Done (`create_post_card.dart`, `StorageUploadService`)
- [x] ✅ **Comments** — pagination + real-time updates. — Medium · Medium · 2 d · v0.7.0 · Done (`CommunityService.commentsStream()` real-time Stream; `getCommentsPage()` cursor-based pagination; `PostDetailScreen` switched from one-shot Future to StreamSubscription with stream cancel in dispose)
- [x] ✅ **Likes / reactions** — add notification fan-out. — Low · Small · 1 d · v0.7.0 · Done (`likePost`, `likeComment`, `toggleReaction`, `addComment` all fan-out to author via `NotificationService`; skips self-action; `unawaited` fire-and-forget; unlike/unreact removes the notification via `deleteNotificationByRelatedId`)
- [x] ✅ **Feed pagination** (`startAfter` + load-more). — Done (`community_service.dart:fetchPostsPage`, `community_screen.dart` Load More)
- [x] ✅ **Feed filters** make functional. — Medium · Medium · 2–3 d · v0.8.0 · Done (Removed unfeasible "Regional" filter; "Global" = all posts; "Friends Only" fetches friend IDs via `FriendService.getFriendIds()` + Firestore `whereIn` on top-level `authorId` field; "Gym" = `arrayContainsAny` on gym-related tags; composite indexes added to `firestore.indexes.json`; load-more pagination is filter-aware; filter-specific empty states with icon + message)
- [x] ✅ **Report/moderation** — real reports collection + block enforcement. — High · Medium · 3–4 d · v0.8.0 · Done (`reports/{id}` Firestore collection with `targetType/targetId/authorId/reason/status`; `reportPost()`+`reportComment()` write real docs; `blockUser()`/`unblockUser()`/`getBlockedIds()`/`isBlocked()` on `users/{uid}/block_list`; `getPostsStream()` uses `async*`+`yield*` to filter blocked authors; reason-picker bottom sheet (5 reasons, RadioListTile) in both `PostDetailScreen` and `GlassPostCard`; "Block User" menu item in post popup; Firestore rules for `reports` write-only + `block_list` owner CRUD)
- [x] ✅ **Group chat** creation flow. — Done (`ChatService.createGroupChat()` writes Firestore group doc + returns `ChatModel`; `CreateGroupChatSheet` — group name field + friend multi-select with search + animated Create button; 4th FAB button "New Group" (indigo, `Icons.group_add`) wired into `ChatListScreen` speed-dial with staggered `_fabGroupAnimation`; navigates directly to `ChatDetailScreen` on creation; EN+TR keys: `chat.new_group`, `chat.group.*`)
- [x] ✅ **Image messages** in chat. — Done (`StorageUploadService.uploadChatImage()` uploads to `chat_images/{uid}/{ts}.jpg`; `+` button in input bar opens gallery via `image_picker`; spinner replaces button during upload; `MessageType.image` bubble renders `Image.network` in a `ClipRRect` with timestamp overlay (WhatsApp-style); error/loading states handled; `storage.rules` updated for `chat_images` path)
- [x] ✅ **Notifications screen** → switched to live `StreamSubscription` via `getNotificationsStream()`; auto-marks-read on first load; real-time updates. — Done
- [x] ✅ **Notification screen transition** → replaced `MaterialPageRoute` with `PageRouteBuilder` bottom-to-top `SlideTransition` (320ms, `easeOutCubic`); fixed hardcoded `Colors.black` icons to `Theme.of(context).colorScheme.onSurface`. — Done (`main_header.dart`)
- [x] ✅ **Challenges** (community) — create/join/track. — Done (`ChallengeModel` (type/goal/unit/startDate/endDate/participantIds/participantProgress); `ChallengeService` singleton (create, join, leave, updateProgress, getActiveChallengesStream, getMyChallengesStream, getChallengeStream); `ChallengesScreen` (TabBar: Active / My Challenges + FAB); `ChallengeDetailScreen` (SliverAppBar, my-progress card + animated LinearProgressIndicator, participants leaderboard, join/leave bottom bar); `CreateChallengeSheet` (type chip picker, goal input, date picker, public toggle); side menu "Meydan Okumalar" entry; Firestore indexes (isPublic+endDate, participantIds+createdAt) + security rules; EN+TR `challenge.*` keys)
- [x] ✅ **Streaks** surfaced socially + milestones/rewards. — Done (Milestone notifications: `FirestoreService._maybeSendStreakMilestone()` sends `NotificationType.system` notification at 7/14/30/60/100/365-day milestones; Home screen: dismissible `_buildStreakMilestoneBanner()` shown on milestone days (orange themed, × dismiss button); Profile screen: `_buildStreakTierBadge()` shows Bronze🥉/Silver🥈/Gold🥇/Diamond💎 tier badge based on streak count)
- [x] ✅ **Leaderboards** (global/friends streak). — Done (`LeaderboardService`: `getGlobalLeaderboardStream()` (orderBy onboarding_data.streak desc, limit 50) + `getFriendsLeaderboard()` (whereIn on friend IDs, client-sort); `LeaderboardScreen` (TabBar Global/Friends, 🥇🥈🥉 rank emojis, current-user highlight, empty states); side menu "Sıralama" entry; Firestore single-field index for `onboarding_data.streak`; EN+TR `leaderboard.*` keys)
- [x] ✅ **Reputation system** (community trust/score). — Done (`ReputationService`: computes `score = streak×2 + posts×5 + challenges×10`; 5 tiers: Newcomer🌱/Active💪/Contributor🌟/Expert🏆/Legend👑; caches `reputation_score` in user Firestore doc; `_loadReputation()` in `ProfileScreen` after post count loads; `_buildReputationBadge()` shows tier + score alongside streak tier badge; static `fromCachedScore()` helper for future post-card use)
- [x] ✅ Recursive subcollection cleanup on post delete. — Done (`deletePost()` now batch-deletes `likes/`, `reactions/`, `comments/` (+ each comment's `likes/`) before deleting the post doc; all in a single Firestore batch; note: deeply nested future subcollections still need a Cloud Function trigger)
- [x] ✅ Optimize `getFriendsStream` N+1 reads. — Done (replaced sequential `for` loop with chunked `whereIn(FieldPath.documentId, chunk)` — 1 read per 30 friends instead of 1 read per friend; `friend_service.dart:95`)

---

## PHASE 3.5 — DESIGN SYSTEM & FULL UI OVERHAUL (🔥 ACTIVE) · target v0.9.0

> Goal: elevate the entire app to a **billion-dollar, flagship-grade** design language — modern,
> innovative, cohesive, and unique. Build a real design system once, then re-skin every screen on top
> of it. Every state (loading / empty / error / success / modal / selector / transition) gets the
> first-class treatment. Full Dark/Light + EN/TR + iOS/Android + 60fps animation coverage throughout.
> See **Global Engineering Rules R7** in `CLAUDE.md`.

**Foundation — Design Tokens & Theme Engine**
- [x] ✅ **Design tokens** — `AppSpacing` / `AppRadius` / `AppSize` / `AppElevation` / `AppMotion` (durations + curves). — Done (`lib/core/theme/app_dimensions.dart`)
- [x] ✅ **Typography scale** — `AppText` semantic styles (display/headline/title/body/label/overline), theme-aware Poppins. — Done (`lib/core/theme/app_typography.dart`)
- [x] ✅ **Color system refactor** — `AppPalette` semantic roles (surface/surfaceVariant/text*/border/status/macro accents/shadow/scrim/shimmer), light+dark, `context.palette`. — Done (`lib/core/theme/app_palette.dart`). Migration of legacy hardcoded hex per-screen is tracked under "Screen Re-skin".
- [x] ✅ **Gradient & glassmorphism kit** — `AppGradients` "Sunset Energy" kit (brand/brandSoft/energy/ring/meshGlow) + `AppGlassCard` frosted-glass + electric `energy` accent added to `AppPalette`. — Done (`app_gradients.dart`, `app_palette.dart`)

**Foundation — Reusable Component Library** (`lib/core/widgets/ds/`, barrel: `ds.dart`)
- [x] ✅ **Buttons** — `AppButton` primary/secondary/tonal/ghost/destructive, sizes, loading, disabled, haptics, press-scale. — Done (`app_button.dart`)
- [x] ✅ **Cards & surfaces** — `AppCard` + `AppGlassCard` with press feedback. — Done (`app_card.dart`)
- [x] ✅ **Loading states** — `AppShimmer` + `AppSkeletonBox` / `AppSkeletonList` branded skeletons (no package dep). — Done (`app_shimmer.dart`)
- [x] ✅ **Empty states** — `AppEmptyState` illustrated, animated, CTA. — Done (`app_state_views.dart`)
- [x] ✅ **Error states** — `AppErrorState` friendly + retry (inline/full-screen). — Done (`app_state_views.dart`)
- [x] ✅ **Modals & bottom sheets** — `AppSheet.show()` handle + blur scrim + title + safe-area. — Done (`app_sheet.dart`)
- [x] ✅ **Calorie ring (hero)** — `AppCalorieRing` animated sweep-gradient progress ring + count-up readout + glow. — Done (`app_calorie_ring.dart`)
- [x] ✅ **Selectors / pickers** — `AppSegmentedControl` (sliding pill), `AppChipPicker<T>` (single/multi-select chips), `AppToggle` (labeled switch). Done (`app_selectors.dart`). `AppChipPicker` + `AppToggle` wired into `CreateChallengeSheet`.
- [x] ✅ **Inputs** — `AppTextField` with focus/error/disabled states, password toggle, label/helper text, prefix/suffix icons. Done (`app_text_field.dart`). Wired into `CreateChallengeSheet` (replaces ad-hoc `_textField`), `_WeightInputSheet`, `_ChangeEmailSheet`, `_ChangePasswordSheet`.
- [x] ✅ **Snackbars / toasts / banners** — `AppSnackBar` success/error/warning/info variants. Done (`app_snackbar.dart`). Wired into `home.dart`, `shopping_list_screen.dart`, `community_screen.dart`, `challenges/create_challenge_sheet.dart`, replacing all raw `SnackBar()` calls.
- [x] ✅ **Navigation transitions** — `AppTransitions.slideUp/slideRight/fade/fadeScale` page-route builders. Done (`app_transitions.dart`). Wired into `home.dart` (→FoodScan, →RecipeDetail), `community_screen.dart` (→PostDetail), `explore_screen.dart` (→RecipeDetail), `challenges_screen.dart` (→ChallengeDetail).

**Bold direction (locked):** "Sunset Energy" — warm sunset gradient brand (`#FF8A3D→#F97300→#FF4E50`)
+ cool electric `energy` accent (teal/mint), premium dark, ambient mesh-glow backgrounds, animated
gradient calorie ring hero, bold display type. Reference screen: `FoodScanScreen`.

**Screen Re-skin** (apply the system, screen by screen)
- [x] ✅ **Splash / loading sequence** — `Colors.red` offline banner → `AppPalette.of(context).error` (DS import added). 0 analyze errors.
- [x] ✅ **Onboarding (6 steps + priority)** — All hardcoded `Color(0xFF...)`, `Colors.*`, raw `TextStyle`, `colorScheme.*` custom roles → DS (AppPalette, AppText, ThemeProvider.primaryColor). `isDark` branches removed. DS imports added to all 9 files. 0 analyze errors.
- [x] ✅ **Auth (login / register / verify / forgot)** — DS tokens throughout (AppPalette, AppText, AppButton, AppRadius, AppSpacing). Unified `_buildTextField` helper with proper border/fill/error states. Removed all hardcoded colors + `constants.dart` + `app_theme.dart` dependencies. 0 analyze errors.
- [x] ✅ **Home dashboard** — 🔥 Critical (flagship). **Fully complete.** Bold nutrition hero (`AppCalorieRing` + animated macro bars, brand-washed card, glow), mesh-glow background, DS scan button, DS section titles, welcome header (AppText/AppPalette), streak & goal-met banners (DS + i18n), day selector (DS palette), meal cards (DS colors/AppText/AppSkeletonBox, glassmorphism), swap sheet (DS), TrackingCard (AppCard, DS tokens, palette.info for hydration), all loading states → AppSkeletonList, empty state → AppEmptyState. 0 analyze errors.
- [x] ✅ **Meal plan + recipe detail + cooking mode** — Full DS migration: `recipe_detail_screen.dart` + `cooking_mode_screen.dart`. Macro colors → palette.protein/carbs/fat/calories, all TextStyles → AppText, AppSpacing/AppRadius throughout. 0 analyze errors.
- [x] ✅ **Food scan / nutrition analytics** — `food_scan_screen.dart` (was already clean), `nutrition_analytics_screen.dart` full migration: isDark branches removed, BarChartPainter refactored to accept AppPalette, score/stat/bg colors → DS. 0 analyze errors.
- [x] ✅ **Community feed + post detail + create post** — All 7 files (community_screen, post_detail, community_widgets, create_post_card, draggable_reaction_button, glass_post_card, glass_refresher) fully migrated. isDark branches removed, all Color/TextStyle → DS. 0 analyze errors.
- [x] ✅ **Chat list + chat detail + group create** — All 6 files (ai_chat, chat_detail, chat_list, create_group_sheet, select_friend_sheet, signal_dialog) migrated. Bubble colors semantic (sent→primary, received→surfaceVariant), isDark removed, AppText throughout. 0 analyze errors.
- [x] ✅ **Profile + settings + legal** — All 3 files fully migrated. isDark branches removed, streak/tier/reputation badge colors → palette semantic, icon bg colors mapped to palette roles, color picker swatches intentionally kept. 0 analyze errors.
- [x] ✅ **Shopping list** — DS migration: swipe-delete→palette.error, checked→textTertiary, surfaces/borders all semantic. 0 analyze errors.
- [x] ✅ **Challenges + leaderboard** — 4 files (challenges_screen, challenge_detail, create_challenge_sheet, leaderboard_screen) migrated. Rank colors semantic (1st→calories, 2nd→textSecondary, 3rd→warning), progress bars→energy. 0 analyze errors.
- [x] ✅ **Notifications + explore** — notification_screen types mapped to semantic palette roles (like→error, comment→info, friend→fat/success, system→warning), explore_screen primaryColor→ThemeProvider. 0 analyze errors.

**UI Fix batch (v0.9.1):**
- [x] ✅ **Home meal plan overflow fix** — Section header Row now uses `Expanded` title + compact icon-only circle buttons (analytics + regenerate). No more 172px overflow.
- [x] ✅ **Home meal cards redesign** — Extracted `_MealCard` widget: taller image panel (100×110), macro chips row (P/C/F via palette.protein/carbs/fat), meal-type pill label, logged state now uses add/check icon + border ring. Better visual hierarchy.
- [x] ✅ **Weight entry → bottom sheet** — `_WeightInputDialog` AlertDialog → `_WeightInputSheet` inside `AppSheet.show()`. DS-styled input field, recent history chips, AppButton save.
- [x] ✅ **Settings dialogs → bottom sheets** — Change Email, Change Password, Delete Account AlertDialogs → `AppSheet.show()` with DS-styled `_ChangeEmailSheet`, `_ChangePasswordSheet`, `_DeleteAccountSheet`. Delete sheet includes warning banner (palette.error).
- [x] ✅ **Challenges screen full redesign** — `_ChallengeCard` redesigned: type-color icon bg, title/status row, description, footer row (goal · end date · participants). `AppSkeletonList` loading, `AppEmptyState` empty state, `AppErrorState` error state. 0 analyze errors.

**DS wiring batch (v0.9.2):**
- [x] ✅ **AppSnackBar wired across screens** — All raw `SnackBar()` calls in home, shopping, community, explore, challenges replaced with `AppSnackBar.error/success/warning/info`. Branded, floating, variant-colored.
- [x] ✅ **AppTransitions wired into key navigation** — `MaterialPageRoute` → `AppTransitions.slideUp` in home→FoodScan, home→RecipeDetail, community→PostDetail, explore→RecipeDetail, challenges→ChallengeDetail.
- [x] ✅ **CreateChallengeSheet DS upgrade** — `_textField()` helper → `AppTextField`; chip type-picker → `AppChipPicker<ChallengeType>`; switch row → `AppToggle`; bottom button → `AppButton`; `ElevatedButton`/`CircularProgressIndicator` removed. DateFormat for date display. 0 analyze errors.

**Navigation & Quick Actions overhaul (v0.9.5):**
- [x] ✅ **Side menu full rebuild** — Added **NUTRITION & FITNESS** section: Meal Scanner (`FoodScanScreen`), Barcode Scanner (`BarcodeScanScreen`), Nutrition Analytics (`NutritionAnalyticsScreen`), Shopping List, Favorites, Meal Plan History. Added **MY GYM** section (disabled, "coming soon" badge). Added **AI Assistant** (`AIChatScreen`) to Social section. Added **Dietary Preferences** to Account section. Avatar row now acts as Profile shortcut. All items use colored icon containers + `AppPalette` tokens. EN+TR keys added. 0 analyze errors.
- [x] ✅ **Quick actions sheet restored & expanded** — `QuickActionsSheet` moved from `Scaffold.body` Stack → outer Stack above the Scaffold, wrapped with `Padding(bottom: bottomNavHeight)` so it renders above `_AppBottomNavBar` (fixes AI voice FAB being hidden behind nav bar). Removed redundant integrated nav bar from sheet. Actions: Meal Scanner, Barcode Scanner, Shopping List, Nutrition Analytics, Favorites, My Gym (coming soon). Each action has a colored icon container + `AppPalette` text. Dark mode glass background fixed (`Color(0xFF0F172A)` instead of `Colors.white`). Coming-soon items shown as disabled with badge. EN+TR `quick_actions.*` keys added. 0 analyze errors.

---

## PHASE 4 — GYM ECOSYSTEM (Core differentiator — greenfield) · target v1.1.0–v1.4.0

> Status: ✅ **Screens built (4A + 4B all shipped).** ⚠️ **BUT currently unreachable by normal users — see Phase 10.1.**
>
> 🔴 **CRITICAL ACCESS GAP (discovered 2026-06-28):** Every gym screen is built and analyze-clean, but
> the side-menu entry points are **role-gated** and a default user is `consumer`. Consumers see only a
> disabled "My Gym (coming soon)" tile. Worse, there is a **chicken-and-egg dead end**: `GymSetupScreen`
> (which promotes `consumer → gymOwner`) is only reachable *from* `GymDashboardScreen`, which only appears
> *after* you are already a `gymOwner`. `GymDiscoveryScreen` (join a gym as a member) is shown only to
> gym owners — backwards. **Net effect: no user can ever create, discover, or join a gym today.** The fix
> is navigation + role-upgrade flows, NOT more screens. Tracked in **Phase 10.2**.

### 4A — Role System (prerequisite for everything)
- [x] ✅ **User role field** (`user_role`: `consumer` | `gym_owner` | `coach` | `admin`) stored on `users/{uid}`. — Done (`UserRole` enum + `UserRoleX` extension in `user_model.dart`; `fromFirestore` reads `user_role` field; `FirestoreService.updateUserRole()` added)
- [x] ✅ **Role-aware side menu** — gym owners see "GYM MANAGEMENT" (Gym Dashboard + Members + Analytics); coaches see "MY CLIENTS" (My Clients + Coach Dashboard); admins see "ADMIN PANEL" (User Management + Reports); consumers see "MY GYM (coming soon)". All sections use DS tokens, colored icon containers, coming-soon badges where applicable. — Done (`side_menu.dart` `_buildRoleSection()`)
- [x] ✅ **Role-aware quick bar** — gym owners get "My Gym Dashboard" (real `GymDashboardScreen`); consumers/coaches/admins keep "My Gym → coming soon". — Done (`quick_actions_sheet.dart` role check via `UserProvider`)

### 4B — Gym Owner Screens (planned, not yet built)
> All screens below are 🆕 greenfield. Entry points: side menu "Gym Management" section + "My Gym" quick action.
- [x] ✅ **Gym profile setup** — 3-step PageView form (name/desc/brand-color/logo → address/city/country → public toggle + fitness tags). `gyms/{gymId}` Firestore collection. Edit mode pre-fills from `existingGym`. `GymSetupScreen`. — Implemented (prev session)
- [x] ✅ **Member management** — real-time stream, search filter, active-today stats row, swipe-to-remove with confirmation dialog, tier badges (Standard/Premium). `GymMembersScreen`. — Implemented (prev session)
- [x] ✅ **Gym dashboard (owner)** — `getOwnerGymStream` subscription; setup CTA when no gym; stats row (member count, city, visibility); quick actions (Members, Community, Leaderboard, Analytics, Check-in QR, Discover); 7-day attendance `_AttendanceChartSection`; feature preview section. `GymDashboardScreen`. — Implemented (prev session + current session)
- [x] ✅ **Gym communities** — per-gym feed (all members post) + announcements tab (owner pins); real-time streams; like, comment, pin/unpin; GymCommunityScreen + GymPostService + GymPostModel. — Implemented 2026-06-28
- [x] ✅ **Attendance & check-in** — QR code generation (owner) + scanning (member, mobile_scanner), GPS geofence check (geolocator/Haversine), 7-day attendance chart, CheckInModel + service methods. — Implemented 2026-06-28
- [x] ✅ **Gym leaderboards / "Gym Wars"** — weekly per-gym check-in leaderboard with animated podium + rank tiles; Gym Wars (inter-gym challenges by check-in count, dual-query active wars, score via AggregateQuery.count); war creation bottom sheet with gym search + duration selector; `GymWarModel`, `LeaderboardEntryModel`, `GymLeaderboardService`, `GymLeaderboardScreen` (2-tab: Leaderboard / Gym Wars); `gym_wars` Firestore collection with security rules + 2 composite indexes; EN+TR `gym.leaderboard_*` + `gym.war_*` keys; leaderboard quick-action tile in `GymDashboardScreen`. — Implemented 2026-06-28
- [x] ✅ **Gym analytics** — retention heatmap, engagement score, drop-off alerts, export CSV. `GymAnalyticsModel`, `GymAnalyticsService` (parallel Firestore reads, 60-day window, CSV export via share_plus), `GymAnalyticsScreen` (overview stat grid with count-up animation, 8-week bar chart, 7×4 activity heatmap, at-risk members section, top-5 performers). Analytics quick action added to `GymDashboardScreen`. Full EN+TR localization (`gym.analytics_*`). — Implemented 2026-06-28
- [x] ✅ **White-label theming (per-screen brand color)** — Gym owner sets a brand color (12 presets) and optional logo in GymSetupScreen step 1. Color stored as hex in `GymModel.brandColor` / Firestore `brand_color`. `GymModelBrandingX.resolvedBrandColor` extension parses and falls back to app orange. GymDashboardScreen derives `primary` from `_gym?.resolvedBrandColor` and passes `brandColor:` to all sub-screens (Community, Leaderboard, Analytics, Members, QR, Check-In) — override is local to gym screens, not a global `ThemeProvider` change. Logo uploaded to `gyms/{gymId}/logo.jpg` via `StorageUploadService.uploadGymLogo`. — Implemented 2026-06-28
- [x] ✅ **Gym data model + profiles** — `GymModel` (Firestore shape, `fromFirestore/toFirestore/copyWith`, GPS + QR + brand color fields), `GymMemberModel` (tier, lastCheckIn, isActiveToday), `GymSubscriptionTier` enum. — Implemented (prev session)
- [x] ✅ **Gym onboarding** — `GymSetupScreen` 3-step PageView with validation, edit mode, brand color picker, logo upload. — Implemented (prev session)
- [x] ✅ **Gym discovery** — `GymDiscoveryScreen` with debounced search (420ms), cursor pagination, `GymService().searchGyms()`, join/leave toggle, gym cards with location + member count + tags. — Implemented (prev session)
- [x] ✅ **GPS presence / check-in** — Haversine geofence implemented in GymService.gpsCheckIn(); geolocator permission flow in GymCheckInScreen. — Implemented 2026-06-28
- [x] ✅ **Gym analytics dashboard** (retention, engagement). `GymAnalyticsScreen` with overview KPIs, 8-week trend, activity heatmap, at-risk alerts, top performers. — Implemented 2026-06-28
- [x] ✅ **White-label** (brand color + logo per gym). — Implemented 2026-06-28 (see above)

**Phase 4 realistic effort: 3–5 months for a dedicated squad.**

---

## PHASE 5 — COACH ECOSYSTEM (greenfield) · target v1.4.0–v1.6.0

> Status: ✅ Core ecosystem complete (profiles, client management, dashboard, AI reports). ⚠️ **Same access
> gap as Phase 4 — see Phase 10.1/10.2.** `CoachProfileSetupScreen` (promotes `consumer → coach`) is only
> reachable from `CoachDashboardScreen`, which only appears *after* you are a coach — a chicken-and-egg dead
> end. There is **no entry point at all** to browse/hire a coach (`CoachService.searchCoaches` + `CoachProfileScreen`
> exist but nothing links to them). **No consumer can become a coach or find a coach today.** Fix in Phase 10.2.

- [x] ✅ **Roles model** (user/coach/gym-admin) + permissions. — Satisfied by Phase 4A: `UserRole` enum (`consumer/gymOwner/coach/admin`) in `user_model.dart`, `FirestoreService.updateUserRole()`, role-aware side menu + quick actions.
- [x] ✅ **Coach profiles**. — `CoachProfileModel` + `CoachService.setupCoachProfile()` + `CoachProfileSetupScreen` (2-step PageView). Firestore: `coach_profiles/{uid}`. Vanity codes stored to `referrals/{code}`. Full DE/TR i18n. — Done.
- [x] ✅ **Referral codes** (random 6-char codes). — Existing `ReferralService` with `referrals/{code}` Firestore collection, batch reward on apply, deep-link integration. Coach vanity codes (AHMETFIT-style) now in coach profile setup.
- [ ] **Revenue sharing / commission** (depends payments). — Future · billing system required · v2.0.0 · ❌
- [x] ✅ **Client management** (coach ↔ client linking). — `CoachClientModel` + `CoachClientsScreen` + pending/accept/reject flow. Firestore: `coach_profiles/{coachUid}/clients/{clientUid}`. At-risk detection (`daysSinceLastLog >= 3`). — Done.
- [x] ✅ **Coach dashboard** (stats, at-risk, active clients). — `CoachDashboardScreen` with stats row (active/pending/at-risk), at-risk section, active clients list (top-5 + see all), quick actions. — Done.
- [x] ✅ **AI-generated client reports/insights** (basic). — `CoachClientDetailScreen` generates AI report via `AIService().generateJson()` with graceful `isConfigured` guard. Returns `{summary, motivationLevel, focusAreas, nextSteps}`. — Done.
- [x] ✅ **Program marketplace** (sell plans/programs) — Phase 7. — Done · v1.0.0

**Phase 5 core complete. Revenue share and marketplace deferred to Phase 7 (billing infra required).**

---

## PHASE 6 — AI INTELLIGENCE · target v1.7.0–v2.0.0

> Status: ✅ Core AI features shipped (v0.9.5). Behavioral analytics pipeline deferred pending real data.

- [x] **AI Fitness Twin** — `AiFitnessTwinScreen` + `AiInsightService.generateFitnessTwin()`. 30/60/90-day projections, goal date estimate, calorie gap, motivation score. `lib/screens/ai/ai_fitness_twin_screen.dart` · ✅
- [x] **AI Accountability Partner** — Daily insight card on home screen. Cached per-day, EN+TR, personalized to goal/streak. `lib/screens/home/widgets/ai_insight_card.dart` · ✅
- [x] **AI Risk Detection** — Client-side `AiInsightService.detectRiskLevel()` — no AI call needed. HIGH (0 logs in 3 days) / MEDIUM (no log today after 14:00) / LOW / NONE. Surfaces risk banner on home screen. · ✅
- [x] **AI Transformation Forecasting** — Part of Fitness Twin (30/60/90 projections, weeklyWeightChange, goalDateEstimate). · ✅
- [x] **AI Coach Assistant** — Phase 5 coach detail AI report (shipped earlier). · ✅
- [ ] **Behavioral analytics** pipeline (events → ML features). — Medium · Epic · 20–30 d · v2.0.0 · ❌ Deferred — requires months of real behavioral data.

**New files:** `lib/core/models/ai_insight_model.dart`, `lib/core/services/ai_insight_service.dart`, `lib/screens/ai/ai_fitness_twin_screen.dart`, `lib/screens/home/widgets/ai_insight_card.dart`

**Dependency note:** AI accuracy improves as users accumulate food-log and weight-log data.

---

## PHASE 7 — MONETIZATION (greenfield) · premium in v1.0; rest v1.x

> Status: 📋/❌ — premium is a dead button; no billing SDK, no credits, no marketplace.

- [x] ✅ **Premium** subscription — `BillingService` (`in_app_purchase`), `SubscriptionTier` model, `Entitlements`, `FeatureGateService`, `_PaywallSheet` — all done in Phase 2. Product IDs `com.cookrange.premium.{monthly,yearly}` must be registered in App Store Connect + Play Console before live purchases work. Referral program now also awards 7-day premium trial via Firestore `subscription_tier/subscription_expires_at` writes.
- [x] ✅ **AI credit system** (message limits, top-ups). — 20 free AI calls/month for free tier (all AI features: chat, scan, meal plan, fitness twin); unlimited for premium. `AiCreditService` singleton tracks usage in `users/{uid}.ai_credits_used` with monthly auto-reset. `AiCreditBadge` widget shows remaining calls in AI chat + fitness twin AppBar. Gate in AI chat send + fitness twin load. Paywall shown on exhaustion. `lib/core/models/ai_credit_model.dart`, `lib/core/services/ai_credit_service.dart`, `lib/screens/ai/widgets/ai_credit_badge.dart`.
- [x] ✅ **Program/plan marketplace** (coach-sold content, commission). — `ProgramModel` + `ProgramEnrollmentModel` + `ProgramService` (create/publish/enroll/stream). `ProgramMarketplaceScreen` (category filter chips, animated grid). `ProgramDetailScreen` (SliverAppBar, highlights, coach card, enroll/buy CTA). Free enrollment works end-to-end; paid programs show paywall pending payment backend. Entry: Side menu → Program Marketplace. Firestore `programs` collection with 3 composite indexes. EN+TR `program.*` keys. — Done
- [x] ✅ **Sponsored challenges** — Extended `ChallengeModel` with `sponsorName/logoUrl/reward/webUrl` fields; `ChallengeService.createSponsoredChallenge()`; `SponsorBadge` widget (amber pill); sponsor section in `_ChallengeCard` (badge + reward chip) and `challenge_detail_screen` (sponsor card with logo + reward); optional sponsor form in `create_challenge_sheet`. EN+TR `challenge.sponsor.*` keys. — Done
- [x] ✅ **Affiliate / referral commission** payouts. — Tracking foundation built: `CommissionModel` + `EarningsSummaryModel` data models; `CommissionService` singleton (Firestore `users/{uid}/commissions`, `users/{uid}/payout_requests`); `recordReferralCommission()` auto-called (fire-and-forget) in `ReferralService.applyCode()` after successful batch commit (€5 per premium referral); `AffiliateEarningsScreen` with summary stat cards, request-payout button, earnings stream list with type/status badges, "how to earn" section; Settings → "My Earnings" entry; `AppSheet` "payout coming soon" confirmation. Firestore rules + index added. EN+TR `settings.earnings.*` keys. Actual payment processing deferred pending billing backend. — Done (tracking layer)
- [ ] **Partner brands / supplement ecosystem**. — Low · Large · 8–10 d · v1.8.0 · ❌
- [x] ✅ **Coach revenue sharing** (see Phase 5). — Tracking foundation built: `CommissionService.recordCoachSessionCommission()` ready to be called when coach sessions are billed; coach commissions appear in `AffiliateEarningsScreen` earnings history alongside referral commissions. Actual payment processing deferred pending billing backend. — Done (tracking layer)

---

## PHASE 8 — GROWTH · target v1.0.0+

- [x] ✅ **Referral program** — `ReferralService` singleton: `getOrCreateCode()` generates 6-char secure code + writes `referrals/{code}` Firestore doc; `getReferralCount()` reads usage; `applyCode()` validates + awards 7-day premium trial to both referrer and referee via batch write + `NotificationService.sendNotification(system)`; `shareCode()` delegates to `SharingService.shareReferral()`. `_ReferralCard` StatefulWidget in Settings with shimmer loading, letter-spaced code display, usage count, Share + "I have a code" buttons; `_ApplyCodeSheet` bottom sheet with `AppTextField` (alpha-num formatter) + `AppButton(loading)`. `firestore.rules` `referrals/{code}` path added (read=auth, create=owner, update=auth with immutable owner+max_uses). EN+TR `settings.referral.*` keys (8 each). Deep link: `cookrangeapp.com/invite/{code}` → `DeepLinkService` routes on `invite` path (extendable). 0 analyze errors.
- [x] ✅ **Invite system (deep links)** — Universal Links (iOS) + App Links (Android) configured via `DeepLinkService`; `cookrangeapp.com/invite/{code}` routes user to Settings with code; `SharingService.shareReferral()` generates invite text + link; full `ReferralService` loop closes invite → reward cycle. Phone contacts picker: deferred (requires `contacts_service` package + privacy consent flow — post-v1.0 addition).
- [x] ✅ **Social sharing** (recipes, progress, lists). — Done. `SharingService` singleton (`share_plus`): `shareRecipe()`, `shareProgress()`, `sharePost()`, `shareShoppingList()`. Wired into: recipe detail AppBar share button, home nutrition header (share progress), community post onShare callback, shopping list toolbar. EN+TR `shopping.share` + `home.share_progress` keys. 0 analyze errors.
- [x] ✅ **Virality: shareable fitness-score card** — `ShareableFitnessCard` widget (`RenderRepaintBoundary.toImage(pixelRatio:3.0)` → PNG → `Share.shareXFiles(XFile)`); card shows: calorie progress ring, consumed vs target, protein/carbs/fat macro chips, streak badge, "Cookrange" footer — dark gradient aesthetic, no external packages. `ShareableFitnessCard.capture(key)` static method handles temp-file creation (`path_provider`). Wired into home screen share button: shows `AppSheet` preview with the card + "Share" `AppButton`; `_shareCardKey` `GlobalKey` in `_HomeScreenState`. 0 analyze errors.
- [x] ✅ **Community growth loops** — challenge sharing via `SharingService.shareChallenge()` + deep link `cookrangeapp.com/challenge/{id}`; share button added to `ChallengeDetailScreen` SliverAppBar. Leaderboard already builds competitive visibility. Referral program closes acquisition loop. Shareable fitness-score cards drive organic social spread. Growth loop: join challenge → achieve goal → share card → friend joins via deep link → referral reward → repeat.
- [x] ✅ **Deep linking / App Links + Universal Links** — `app_links: ^6.3.4` added; `DeepLinkService` singleton handles initial + stream URI routing; URL scheme `https://cookrangeapp.com/{recipe|post|user|challenge}/{id}`; Android App Links `intent-filter autoVerify="true"` + custom `cookrange://` scheme in `AndroidManifest.xml`; iOS `Runner.entitlements` with `applinks:cookrangeapp.com`; custom scheme fallback for dev testing; wired into `_fireAndForgetPreloading()` in splash; `SharingService.shareRecipe/sharePost` now append deep-link URL when ID provided. Server-side `.well-known/assetlinks.json` + `apple-app-site-association` are deploy-time steps. 0 analyze errors.

---

## PHASE 9 — SCALE & LAUNCH READINESS · ongoing, gates v1.0.0

- [x] ✅ **Performance** — Firebase Performance ✅ (Phase 1: `HttpMetric` on AI calls, `meal_plan_fetch/generate` traces). Frame/jank budgets: `RepaintBoundary` added around `AppCalorieRing` (animated arc), `_MealCard` (list items with network images), `_BarChartPainter` + `_ScoreRingPainter` in `NutritionAnalyticsScreen`, `_buildBackgroundGlows` in `main_scaffold` (already existed). `GlassPostCard` in community already boundary-isolated. `AppShimmer` wrapped in `ExcludeSemantics` (decorative, no paint isolation needed). 0 analyze errors.
- [x] ✅ **Caching** — Decided: rely on Firestore built-in persistence (`persistenceEnabled: true`, `CACHE_SIZE_UNLIMITED` in `_initializeFirebase`). Removed dead offline scaffolding in Phase 1. Stale-while-revalidate UX naturally follows from Firestore's local disk cache. Full offline-write queue is deferred to post-v1.0 if retention data shows need. — Decision locked in Phase 1 architecture.
- [x] ✅ **Database optimization** — 9 composite indexes in `firestore.indexes.json`: `posts/createdAt DESC`, `signals/expiresAt+createdAt`, `messages/createdAt`, `food_logs/date+loggedAt`, `posts/authorId+timestamp`, `posts/tags+timestamp` (friends-only feed), `challenges/isPublic+endDate`, `challenges/participantIds+createdAt`, `users/onboarding_data.streak DESC` (leaderboard). All active query patterns are covered. Single-field queries rely on Firestore auto-indexes. Referrals collection keyed by code = document ID lookup, no index needed.
- [x] ✅ **Security hardening** — Firebase App Check ✅ (Phase 1: playIntegrity/deviceCheck/debug attestation + Cloud Function validation). AI key behind Cloud Function proxy ✅ (Phase 1). Firestore + Storage rules ✅ (B1 + Phase 3 + referrals path now added). Key restriction (HTTP referrer/iOS bundle/Android SHA-1 in Firebase Console) = console-only step. Dependency audit: `flutter pub outdated` — 78 newer versions available, none flagged as security-critical in current constraint set. — 0 analyze errors.
- [ ] **Load testing** (Firestore/AI proxy under concurrency). — Medium · Medium · 2–3 d · v1.0.0 · ❌
- [x] ✅ **Monitoring/alerting** — Crashlytics ✅ (custom keys, release-only, `recordError` throughout). Firebase Performance ✅ (HttpMetric + custom traces). Cloud Monitoring dashboards + Crashlytics velocity alerts = Firebase Console configuration steps (no code required). — Done.
- [ ] **Internationalization** beyond EN/TR (infra is ready; add locales). — Low · Medium · per-locale · v1.1.0 · 🚧
- [x] ✅ **Accessibility** — DS-level semantics pass: `AppCalorieRing` wrapped in `Semantics(label, value)` + `ExcludeSemantics` on decorative arc; `AppButton(Semantics(button:true, enabled, label, onTap))`; `AppCard` tappable variant wrapped in `Semantics(button)`; `AppShimmer` wrapped in `ExcludeSemantics`; `AppEmptyState`/`AppErrorState` wrapped in `Semantics(liveRegion:true)` for screen-reader announcements; background glow blobs in `main_scaffold` excluded from semantic tree. 0 analyze errors.
- [x] ✅ **GDPR/CCPA**: account deletion (B6 ✅), **data export** (`DataExportService` — collects profile + food_logs + meal_plans + lists + community_posts as JSON, shared via OS share sheet using share_plus XFile; "Download My Data" row added to Settings with loading dialog + error handling; EN+TR `settings.account.export_*` keys). Consent records + retention policy: console/legal steps, no code required. — 0 analyze errors.
- [x] ✅ **App Store readiness — ATT consent**: `ATTConsentService` singleton using `permission_handler`; `NSUserTrackingUsageDescription` added to `Info.plist`; ATT dialog requested in `_navigateAfterSplash()` just before routing to main screen (fires once per install, `att_prompted` key in SharedPreferences); `analyticsEnabled` getter gates analytics; debug/Android no-op. Apple Sign-In (B7 ✅), legal docs (B12 ✅), privacy nutrition labels + store assets = console/asset steps. 0 analyze errors.
- [x] ✅ **Tech debt cleanup (v0.9.5)** — All bare `print()` calls in `lib/` replaced with `debugPrint()` (12 files: `language_provider`, `device_info_provider`, `onboarding_provider`, `community_service`, `dish_image_service`, `app_initialization_service`, `dish_service`, `dish_seeder_service`, `device_info_service`, `notification_service`, `weekly_meal_plan_service`, `onboarding_screen`). Dead legacy widgets deleted (`custom_back_button.dart`, `gender_picker_modal.dart`, `language_selector.dart` — 0 external refs). Translations moved from `lib/core/localization/translations/` to `assets/localization/` (standard Flutter asset convention); `pubspec.yaml` and `app_localizations.dart` updated. `flutter analyze lib/` → 127 issues (↓ from 142), 0 errors. Signal dialog presets confirmed already localized via `translate(preset)` key pattern.

---

## PHASE 9.6 — PRIVACY, NOTIFICATIONS & NAVIGATION FIXES (v0.9.6)

> Three user-reported fixes shipped in order, then a project scan (Phase 9.7 below).

- [x] ✅ **Private-account enforcement** — `profile_screen.dart` now refreshes the viewed user's
  doc on open (so `isPrivate` is never stale) and gates the data sections behind a
  privacy-resolution check (`_privacyResolved` = fresh user loaded **and** friendship resolved),
  showing a skeleton until known. Non-friends viewing a private account see only the lock card
  (`_buildPrivateAccountRestricted`); accepted friends and the owner see the full profile.
  PII fields (`personal_info`, `allergies`, `dietary_restrictions`, `disliked_foods`,
  `avoid_ingredients`) are now server-side owner-only in `users/{uid}/private/nutrition`;
  non-PII public fields (`streak`, `activity_level`, etc.) remain on the main doc.
  `food_logs`/`meal_plans` are separately owner-only. Hard enforcement complete (Phase 9.7 ✅).
- [x] ✅ **Structured notifications (i18n-correct)** — Rebuilt `NotificationModel` to store
  STRUCTURED data (`type`, `actorUid/Name/PhotoUrl`, `relatedId`, `metadata`) instead of a frozen
  pre-rendered `title`/`body`. New `NotificationPresenter` (`lib/core/utils/`) renders title/body/
  icon/color dynamically from `notifications.feed.*` localization keys, so notifications display in
  the reader's current language with the real actor name. Legacy docs fall back to stored text.
  All 8 call sites updated (`community_service` likes/comment/reaction, `friend_service`
  request/accepted, `referral_service`, `firestore_service` streak). Notification rows now show the
  actor avatar and are tappable → profile. Removed brittle `title.contains("Su")` string-matching.
- [x] ✅ **Universal tap-to-profile** — New `openUserProfile(context, {userId, user})` +
  `ProfileLink` (`lib/core/utils/profile_navigation.dart`). Wired so any user avatar/name opens
  their profile: post-detail author + comment authors, leaderboard rows, challenge participants,
  private chat header, profile friend-strip, notification actor. (Post-card author already
  navigated; tiny overlapping like-face-piles left as a visual summary.)
- [x] ✅ **Side-menu polish** — Localized all hardcoded Turkish labels via `menu.*` keys (EN/TR);
  removed three dead/redundant items (Meal Plan snackbar stub, Help & About — the latter two live
  in Settings).

---

## PHASE 9.7 — CONSUMER POLISH & NEW FEATURES (🆕 proposed — prune freely) · v1.0.x–v1.1

> Discovered in a full project scan. Every item is tagged 🆕 NEW — these are suggestions; delete any
> you don't want. On-brand for an AI nutrition/fitness consumer app (no gym/coach scope here).

**High value**
- [x] ✅ Recipe favorites / bookmarks — `FavoriteService`, `users/{uid}/favorites`, bookmark in recipe detail, `FavoritesScreen` + embedded `FavoritesBody` in Explore tab
- [x] ✅ Meal-plan history — `WeeklyMealPlanService.getMealPlanHistory/restorePlan`, `MealPlanHistoryScreen`, history button in home meal-plan section header; auto-archive on every plan save
- [x] ✅ Barcode scan to log packaged foods — `BarcodeLookupService` (Open Food Facts API, per-100g nutritional lookup, in-memory cache); `BarcodeScanScreen` (full-screen camera via `mobile_scanner`, animated reticle with scan line, torch toggle, product lookup overlay, serving-size slider, meal-type selector, log button); `FoodLogService.logBarcodeFood()`; `mobile_scanner: ^5.2.3` added; CAMERA permission added to AndroidManifest + NSCameraUsageDescription to iOS Info.plist; barcode scan icon button added to FoodScanScreen AppBar; EN+TR `barcode.*` keys; 0 analyze errors
- [x] ✅ Quick-add / recent & frequent foods — `RecentFoodService`, `QuickAddSheet` (recent/frequent tabs, meal-type selector); auto-records on every food log
- [x] ✅ Global user search & discovery — `UserSearchScreen` (debounced, friendship-status badges), search icon in `MainHeader`
- [x] ✅ In-app notification preferences — `NotificationPreferencesService`, preferences sheet in Settings (per-group mute toggles, EN+TR)

**Medium**
- [x] ✅ Activity / exercise log + calorie-burn estimate feeding TDEE — `ExerciseLogService`, `ExerciseType` (12 types + MET-based burn estimate), `ExerciseLogSheet` (type grid + duration slider), burned-today chip in nutrition hero, stream subscription in home.dart
- [x] ✅ Streak freeze / pause day — `UserModel.streakFreezeCount`, auto-consumed on missed day in `FirestoreService`, new users gifted 1 freeze, `grantStreakFreeze()` API, freeze badge in home streak chip
- [x] ✅ Recipe filters in Explore — cook-time (≤20 / ≤45 / open) and difficulty filter chips wired to AI prompt via `maxTotalMinutes` + `difficulty` params in `PromptService` / `RecipeGenerationService`
- [x] ✅ Nutrition breakdown by meal type — `MealBreakdownCard` widget computed from existing `todayLogsStream`; appears on home when any meal is logged (breakfast/lunch/dinner/snack rows with calorie + macro chips)
- [x] ✅ Dietary-restriction refinement — `UserNutritionProfile.avoidIngredients` (stored as `onboarding_data.avoid_ingredients`); `FirestoreService.updateAvoidIngredients()`; `DietaryPreferencesScreen` (read-only allergy/diet sections + editable avoid-list with chip add/remove); wired into recipe prompt (`PromptService`) and meal plan (`WeeklyMealPlanService`); accessible from Settings → Dietary Preferences
- [x] ✅ Profile as a real bottom tab — `NavigationProvider` tab constants (homeTab/communityTab/profileTab), `MainScaffold` migrated from PageView+SideMenu to `IndexedStack` (3 tabs: Home/Community/Profile), glassmorphic floating bottom nav bar with animated pill indicator, haptic feedback, press-scale animation; `SideMenu` updated (profile avatar tap + profile item → tab 2, removed redundant Home/Community items)

**Lower / nice-to-have**
- [x] ✅ Meal-plan comparison — `PlanAlternate` model; `WeeklyMealPlanService.generatePlanAlternates()` (AI generates 2 lightweight macro profiles); `PromptService.generatePlanAlternatesPrompt()`; `MealPlanComparisonSheet` (current plan vs 2 alternates, animated selection, macro bar visualization, "Apply" triggers regeneration); compare button in home meal plan header
- [x] ✅ Recipe personal notes / annotations — `RecipeNoteService` (`users/{uid}/recipe_notes/{recipeId}`), notes icon button in recipe SliverAppBar, AppSheet text editor with auto-save
- [x] ✅ Challenge difficulty tiers (easy / medium / hard) — `ChallengeDifficulty` enum + `locKey` extension on `ChallengeModel`; difficulty selector in `CreateChallengeSheet` (3-card row: Easy/Medium/Hard with icons + colors); difficulty filter chip row in `ChallengesScreen` (All/Easy/Medium/Hard, `AnimatedContainer` chips, client-side filter on stream results); difficulty badge in `_ChallengeCard` footer (color-coded: success/warning/error); backward-compatible (defaults to medium); EN+TR `challenge.difficulty.*` + `challenge.create.difficulty_label` keys
- [x] ✅ Meal-plan calendar export (Apple/Google Calendar) — `MealPlanCalendarService` generates a standard `.ics` (iCalendar) file from `WeeklyMealPlanModel` (one VEVENT per meal slot per day, fixed meal times: breakfast 8:00/lunch 12:30/dinner 19:00/snack 15:30, dish names resolved from home dish cache, calorie total in description); shared via existing `share_plus` + `path_provider` (no new package needed); calendar icon button added to home meal-plan section header alongside compare/history/regenerate; EN+TR `calendar.*` keys; 0 analyze errors
- [x] ✅ Hard server-side private-profile enforcement — PII fields (`personal_info`, `allergies`, `dietary_restrictions`, `disliked_foods`, `avoid_ingredients`) migrated out of the publicly-readable `users/{uid}.onboarding_data` map into the owner-only `users/{uid}/private/nutrition` subcollection. Firestore rule `match /users/{uid}/private/{docId}` enforces read/write only by owner. `FirestoreService.getPrivateNutritionData(uid)` handles first-load migration (batch-moves PII from legacy main doc) + serves cached private doc; `savePrivateNutritionData(uid, data)` writes private doc. `UserModel.withPrivateNutrition(data)` merges private data into the in-memory model so `user.profile` (used by `WeeklyMealPlanService`, home dashboard, etc.) stays populated for the owner without any call-site changes. `UserProvider.loadUser()` fetches both docs and merges. `OnboardingProvider` split into `_toPublicMap()`/`_toPrivateMap()` and both save methods dual-write accordingly. `SplashScreen._navigateAfterSplash()` loads private data before completeness check and sets merged model on `UserProvider`. `updateAvoidIngredients` writes to private subcollection. GDPR `deleteUserData` deletes the `private` subcollection. Existing users are transparently migrated on first login. Non-owners reading another user's doc see only public fields. 0 analyze errors.

---

## PHASE 10 — ACTIVATION, ACCESS & FIRST-RUN EXPERIENCE (🔥 NEXT — highest leverage) · v1.0.x–v1.1

> **Why this phase exists.** Phases 4–7 shipped an enormous amount of *screens* — gym ecosystem,
> coach ecosystem, program marketplace, AI intelligence, monetization — but a full-app navigation audit
> (2026-06-28) found that **much of it is unreachable, and the app has no first-run story.** A user
> installs the app, is dropped straight into a 6-step data form, and is never shown what the product
> *does*. Power features sit behind role gates with no on-ramp. **This phase makes the product we already
> built actually discoverable, usable, and permission-respecting.** It is mostly *wiring, flows, and
> polish* — very little net-new domain logic — which makes it the single highest ROI work remaining.
>
> Three user-requested pillars + a fourth of recommended improvements. All work is **iOS+Android,
> light+dark, EN+TR, 60fps, DS-native** per Global Engineering Rules R0–R8.

### 10.1 — Navigation Truth: reachability audit (📋 reference — keep current)

> The honest map of "can a normal user actually get here today?" Fix targets live in 10.2.

| Screen / Feature | Built? | Reachable by a `consumer` today? | Gap |
|---|---|---|---|
| AI Fitness Twin | ✅ | ✅ via home insight card | OK |
| AI Chat / Challenges / Leaderboard | ✅ | ✅ side menu | OK |
| Program Marketplace | ✅ | ✅ side menu | OK (but empty until coaches publish — see 10.5 seed) |
| Affiliate Earnings | ✅ | ✅ Settings | OK |
| Food / Barcode scan, Nutrition analytics | ✅ | ✅ home + quick actions | OK (permission priming — 10.3) |
| **Gym: create / set up** | ✅ | ❌ **chicken-and-egg dead end** | 10.2 — needs "Register your gym" on-ramp |
| **Gym: discover / join as member** | ✅ | ❌ shown only to gym *owners* | 10.2 — backwards; expose to consumers |
| **Gym: member experience** (community/check-in/leaderboard as a *member*, not owner) | 🟡 owner-only views exist | ❌ | 10.2 — needs member-side gym home |
| **Coach: become a coach** | ✅ | ❌ **chicken-and-egg dead end** | 10.2 — needs "Apply to coach" on-ramp |
| **Coach: find / hire a coach** | ✅ (`searchCoaches`, `CoachProfileScreen`) | ❌ **nothing links to it** | 10.2 — needs coach directory entry |
| **Feature-tour onboarding** | ❌ | — | 10.4 — does not exist |
| **Permission priming** (camera/location/notif/photos) | ✅ | `PermissionService` + `PermissionPrimer` | 10.3 shipped ✅ |

### 10.2 — Role-Upgrade & Discovery Flows (🔴 Critical — fixes the dead ends) · High · Medium · 3–4 d

- [x] ✅ **"Register your gym" on-ramp** — entry in Settings ("Business"/Go Pro group) + the consumer
  side-menu "Grow" section + quick actions. Routes a `consumer` straight to `GymDashboardScreen`
  (self-setup CTA); creating a gym promotes role → `gymOwner`. Removes the chicken-and-egg. — Done
- [x] ✅ **"Become a coach" on-ramp** — entry in Settings (Go Pro) + side menu "Grow" → `CoachDashboardScreen`
  (self-setup CTA); completing setup promotes role → `coach`. — Done
- [x] ✅ **Consumer gym discovery** — "Find a Gym" surfaced to *all* roles in the side menu always-visible
  list + the consumer quick-actions tile (replaces old coming-soon); "My Gyms" strip at top of
  `GymDiscoveryScreen` lets joined members re-enter. — Done
- [x] ✅ **Gym member home** — `GymMemberHomeScreen` reachable from the "My Gyms" strip (community/check-in/
  leaderboard); driven by `GymService.getMemberGymsStream` + `gym_memberships` array on the user doc. — Done
- [x] ✅ **Coach directory** — `CoachDiscoveryScreen` reachable via "Find a Coach" in the side menu
  always-visible list; tap → `CoachProfileScreen` → request. — Done
- [x] ✅ **Unified "Discover / Pro" hub** — `DiscoverHubScreen` at `AppRoutes.discover`; 2×2 flagship grid cards (Gyms/Coaches/Programs/Challenges) + premium banner; added as first item in side-menu Social section (`menu.discover`). EN+TR `discover.*` + `menu.discover` keys. — Done
- [x] ✅ **Role-aware home surfacing** — `RoleQuickCard` inserted between `TrackingCard` and `AiInsightCard` on home dashboard; conditionally shown for non-consumer roles (gymOwner, coach, admin); quick-entry links to role dashboards. — Done
- [x] ✅ **Remove all stale `comingSoon: true` / `onTap: null`** flags — consumer gym tiles in
  `side_menu.dart` + `quick_actions_sheet.dart` now route to real screens. — Done

### 10.3 — Just-in-Time Permissions (priming + rationale before use) · High · Small–Medium · 2–3 d

> **Principle:** never let the raw OS permission dialog appear cold. Show a branded rationale sheet that
> explains *why* and *what for* immediately before the system prompt — the single biggest lever on grant
> rates. Handle `denied` and `permanentlyDenied` gracefully with an "Open Settings" path.

- [x] **Reusable `PermissionPrimer`** (`lib/core/widgets/ds/permission_primer.dart`) + **`PermissionService`**
  (`lib/core/services/permission_service.dart`) — DS-styled `AppSheet` with icon, title, rationale,
  "Allow" / "Not now"; on Allow → trigger the real request; handles `denied` / `permanentlyDenied` with
  "Open Settings" sheet; `PermissionService` singleton for camera / photos / location / notifications. ✅
- [x] **Camera priming** before `BarcodeScanScreen` (`_requestCamera()` in `initState`) and
  `GymCheckInScreen` QR scanner (`_handleQrTap` guard). `MobileScanner` only mounts after grant. ✅
- [x] **Location priming** before gym GPS check-in — `showLocationPrimer(context)` called before
  `Geolocator.requestPermission()` in `_handleGpsTap`. ✅
- [x] **Notification permission priming** — `PermissionService().requestNotifications()` called from
  `home.dart._maybeRequestNotifications()` with a 3-second delay post-frame (once, gated by
  SharedPrefs `permission_notification_primed`). `_fcm.requestPermission()` moved out of
  `PushNotificationService.initialize()` into a new `requestPermission()` method. ✅
- [x] **Photo-library priming** before avatar pick (`profile_screen._pickAndUploadAvatar`) and post image
  pick (`create_post_card._pickImage`). ✅
- [x] **Denied / permanentlyDenied states** — branded `_SettingsContent` sheet with "Open Settings"
  (`openAppSettings()`); barcode scanner pops the route if camera denied. ✅
- [x] ✅ **Platform parity** — Android: CAMERA, RECORD_AUDIO, ACCESS_FINE/COARSE_LOCATION, READ_MEDIA_IMAGES all declared in AndroidManifest.xml; `PermissionService` handles runtime rationale priming on both platforms. iOS purpose strings in `Info.plist`. ATT shipped. — Done (QA: test on real devices)

### 10.4 — Feature-Tour Onboarding (illustrated intro *before* data collection) · High · Medium · 3–5 d

> Today `route_guard`/`splash` drop a brand-new user straight into the 6-step nutrition form. They never
> learn what Cookrange *is*. Add a short, beautiful, skippable walkthrough that sells the product first.

- [x] **`IntroOnboardingScreen`** — 5-page horizontal `PageView`, animated gradient background per page, `_IllustrationBox` icon compositions, pill `_Dots`, `_NavRow` white-pill button, Skip button. `SharedPrefs intro_seen` gate: new users → `/intro` → `/onboarding`; returning users skip straight to `/onboarding`. `isReplay` flag for Settings re-entry. EN+TR `intro.*` keys (14). `AppRoutes.intro` registered. — Done
- [x] **Illustration assets** — per-page gradient backgrounds (5 color pairs) + centered icon in frosted rounded container + outer ring. No external CDN. Works in light+dark. — Done (part of IntroOnboardingScreen)
- [x] **Tour content** — ① AI Meal Planning · ② Track Every Meal · ③ Community & Challenges · ④ Gyms & Coaches · ⑤ AI Fitness Twin. EN+TR `intro.*` keys added. — Done
- [x] **Re-entry** — "How It Works" row in Settings > App Info section → `IntroOnboardingScreen(isReplay: true)` via `AppTransitions.slideRight`. — Done

### 10.5 — Additional Activation Improvements (🆕 recommended — prune freely)

- [x] ✅ **First-use coachmarks / spotlight** — `CoachmarkTip` widget (SharedPrefs-gated, reduced-motion aware, dismiss-on-tap) created in `lib/core/widgets/coachmark_tip.dart`; wired below the calorie ring in `home.dart` (`coachmark_ring` pref key). EN+TR keys in `coachmarks.*`. — Done
- [x] ✅ **"What's New" changelog modal** — `WhatsNewService` (singleton, SharedPrefs `whats_new_last_version` gate) + `WhatsNewSheetContent` widget; shown once per version bump via `MainScaffold.initState` post-frame callback (800ms delay). EN+TR keys in `whats_new.*`. — Done
- [x] **Empty-state CTAs that route into features** — Program Marketplace empty → "Become a Coach & Publish" (CoachDashboardScreen); Gym Discovery empty → "Register Your Gym" (GymDashboardScreen); Coach Discovery empty → "Become a Coach"; Chat list empty → "Find Friends" (UserSearchScreen). EN+TR keys added to existing objects. — Done
- [x] ✅ **Deep-link: gym QR for non-members** — `GymJoinPromptSheet` created; `DeepLinkService` detects opaque `cookrange:checkin:{gymId}:{token}` URIs, checks membership via `GymService.isMember()`, shows join sheet for non-members (join + check-in in sequence) or proceeds with `validateQRCheckIn` for existing members. EN+TR `gym.join_prompt_*` keys (4). — Done
- [x] ✅ **Profile completeness meter** — `ProfileCompletenessCard` widget in `lib/screens/profile/widgets/profile_completeness_card.dart`; shows progress ring + incomplete step rows (photo, first meal, challenge); self-hides when all complete; owner-only (guarded by `isOwnProfile`); FoodLogService stream check for meal log. EN+TR keys in `profile_meter.*`. — Done
- [x] **Demo / seed content** — `DemoContentSeeder` singleton seeds 3 demo programs ("30-Day Fat Burn", "Lean Muscle Builder 8-Week", "Healthy Habits 21-Day Reset") to `programs` collection on first install (idempotent gate: `seeds/demo.demo_programs_v1`). Called from `AppInitializationService`. `firestore.rules` updated for `seeds` collection + `programs` write by `coach_uid == 'demo'`. — Done
- [x] **Activation analytics funnel** — `intro_completed` (intro screen `_finish()`), `gym_joined` (`GymService.joinGym`), `coach_requested` (`CoachService.requestCoaching`). All use `AnalyticsService().logEvent(name:, parameters:)` with `unawaited`. — Done
- [x] ✅ **Accessibility & motion** — `IntroOnboardingScreen` (AnimatedContainer, AnimatedOpacity, dots, nav button all reduceMotion-gated; Semantics labels); `CoachmarkTip` close button Semantics; `AiCreditsSheet` usage bar + credit count Semantics; `AdminPanelScreen` banner + stat cards + filter chips reduceMotion + Semantics; `ProfileCompletenessCard` progress ring Semantics + 44px CTA tap targets. — Done

### Definition of Done — Phase 10
☑ Every built screen has a real, role-appropriate entry point (no chicken-and-egg, no dead `comingSoon`) ·
☑ No camera/location/notification dialog appears without a preceding branded rationale · ☑ New users see an
illustrated feature tour before the data form · ☑ Empty states route forward, not nowhere · ☑ All new
copy in EN+TR, all new UI correct in light+dark on iOS+Android, 60fps, reduced-motion aware ·
☑ `flutter analyze lib/` 0 errors · ☑ CLAUDE.md + this roadmap updated (R8).

---

## Phase 11 — Gym/Coach Verification & Admin Pipeline

> **Scope:** Real approval pipeline for coach and gym registrations; admin review UI; AI Twin history
> persistence; language-aware AI responses; test mode coverage; role-aware button labels; Turkish Lira
> currency; coach request persistent state.

### 11.1 — AI Twin History & Language-Aware AI ✅
- [x] `AIInsightService.generateFitnessTwin()` and `generateAccountabilityInsight()` now accept `{String locale}` — passes language instruction to AI prompt ("Respond entirely in English." / "Tüm yanıtları Türkçe ver.") ✅
- [x] Cache keys include locale so EN/TR projections are stored separately ✅
- [x] After successful AI call, `unawaited(_saveTwinProjection(...))` saves to `users/{uid}/ai_twin_projections/{auto-id}` ✅
- [x] `AiFitnessTwinScreen` shows past projections via `StreamBuilder` on the subcollection (ordered by `generatedAt desc`, limit 10) ✅
- [x] `firestore.rules` — `ai_twin_projections` subcollection owner-only read/write ✅
- [x] EN+TR keys: `ai.twin_history_*` (5 keys) ✅

### 11.2 — Test Mode Full Coverage ✅
- [x] `TestDataLibrary.gyms()` — 3 gyms: Iron Paradise, Zen Flow Studio, Fighter's Den ✅
- [x] `TestDataLibrary.coaches()` — 3 coaches: Ahmet Yıldız, Elif Kaya, Mert Demir ✅
- [x] `TestDataLibrary.programs()` — 3 programs across difficulty tiers ✅
- [x] `TestDataLibrary.challenges()` — 3 challenges ✅
- [x] Test data injected into `GymService.searchGyms()`, `CoachService.searchCoaches()`, `ProgramService.getPublishedProgramsStream()`, `ChallengeService.getActiveChallengesStream()` ✅

### 11.3 — Social & Discovery Polish ✅
- [x] **Role-aware labels:** "Register Your Gym" → "My Gym" / "Become a Coach" → "My Coaching" in Settings ✅
- [x] **Currency:** `€` → `₺` everywhere (coach discovery, coach profile, affiliate earnings, referral string) ✅
- [x] **Coach request persistent state:** `coaching_requests` subcollection; pending chip shown after request; self-request blocked; re-request blocked ✅
- [x] EN+TR keys: `coach.request_*`, `settings.business.my_*`, `menu.my_coaching` ✅

### 11.4 — Coach & Gym Approval Pipeline ✅
- [x] `CoachApplicationModel` + `GymApplicationModel` data models ✅
- [x] `CoachApplicationService` + `GymApplicationService` singletons ✅
- [x] `CoachApplicationScreen` — 3-step PageView (bio + specializations, evidence upload, references) ✅
- [x] `CoachApplicationPendingScreen` — 3-state (pending / rejected / needsMoreInfo) with reviewer notes ✅
- [x] `GymApplicationPendingScreen` — 2-state (pending / rejected) with reviewer notes ✅
- [x] `CoachDashboardScreen` — gates on `CoachApplicationService.getMyApplicationStream()`: no-app → apply CTA, pending/rejected → status screen ✅
- [x] `GymDashboardScreen` — same gate via `GymApplicationService.getMyApplicationStream()` ✅
- [x] `firestore.rules` — `coach_applications` + `gym_applications` + `ai_twin_projections` + `isAdmin()` function ✅

### 11.5 — Admin Applications Review Panel ✅
- [x] `AdminService` — batch approve/reject for coaches and gyms; notifications sent to applicants ✅
- [x] `AdminPanelScreen` — 2-tab TabBar (coaches / gyms) with real-time pending streams ✅
- [x] `ApplicationReviewScreen.forCoach()` / `.forGym()` — full review with evidence links, approve/reject ✅
- [x] Settings entry for admin users (`UserRole.admin`) → `AdminPanelScreen` ✅
- [x] EN+TR keys: `admin.*` (18 keys), `coach.app_*`, `gym.app_*` (15+ keys each) ✅

### Definition of Done — Phase 11
☑ All AI responses language-aware · ☑ AI Twin history persisted + surfaced in UI · ☑ Test mode has
gym/coach/program/challenge data · ☑ Role labels update post-approval · ☑ Coach request is persistent +
idempotent + blocks self-request · ☑ Coach/gym applications require multi-step evidence submission ·
☑ Admin can approve/reject from a real-time panel · ☑ All new copy EN+TR · ☑ `flutter analyze lib/` 0 errors

---

## Phase 12 — AI Economy, Localization Integrity & Role Navigation

> **Scope:** Fix the AI-Twin localization + regeneration regression, make all AI calls language-aware
> and persisted, introduce a **daily** credit economy (premium 20/day, free 2/day) with a tappable
> credit→paywall surface, and complete role-aware navigation so **coach** and **admin** have full
> parity with gym (side menu + settings + admin operations). Flagship-grade: optimized, 60fps,
> iOS+Android, light+dark, EN+TR. **R0–R8 apply to every item.**

> ### 🔴 Known Regression (root-caused — fix in 12.1/12.2 first)
> A parallel sub-agent run silently **lost** the original AI-Twin localization work in a shared-file
> write collision. The current code reflects this:
> - `AiInsightService.generateFitnessTwin(UserModel user)` — **no `locale` param, no caching, no
>   persistence.** Every entry to `AiFitnessTwinScreen` fires a fresh AI call → always English, new
>   request on every tap. (`lib/core/services/ai_insight_service.dart:121`)
> - `generateAccountabilityInsight(UserModel user)` — no `locale`; caches by **date only** in
>   SharedPrefs (`ai_insight_generated_at/_message/_tips`) → switching to TR returns cached English.
> - `prompt_service.dart` — **no language instruction** in any prompt; only `AIChatService` is
>   language-aware.
> - **Orphaned artifacts** already merged but unused: `firestore.rules` → `ai_twin_projections`
>   owner-rule, and `ai.twin_history_*` (5 EN+TR keys). 12.1 must reconnect code to these, not
>   re-add them.
> - **Process fix (12.6):** never let two agents write the same JSON/rules file in parallel again.

### 12.1 — Language-Aware AI Everywhere (fix regression + extend) · 🔴 Critical · Medium · 2–3 d

- [x] **Centralize the language directive** in `PromptService`: a single `_localeInstruction(locale)`
  helper ("Respond entirely in English." / "Tüm yanıtları Türkçe ver, tüm alan değerleri dahil.")
  appended to **every** prompt builder — meal plan, recipe, ingredient-validate, alternates — not just chat.
- [x] **Add locale param** to `generateFitnessTwin`, `generateAccountabilityInsight`,
  and any other `AIService`/`AIInsightService` entry that returns user-facing text. No default that
  silently falls back to English.
- [x] **Read locale at every call site BEFORE the first `await`** (from `LanguageProvider` /
  `AppLocalizations.of(context).locale`) and pass it down. Audit: `ai_fitness_twin_screen.dart`,
  `ai_insight_card.dart`, `home.dart`, `explore_screen.dart`, `food_scan_screen.dart`,
  `meal_plan_comparison_sheet.dart`, chat.
- [x] **Locale-tag every cache key** (`..._{uid}_{locale}_{dateKey}`) in SharedPrefs/Hive/Firestore so
  a language switch never returns stale opposite-language text. Migrate the date-only insight keys.
- [x] ✅ **Audit pass:** grepped all prompt strings. `PromptService`, `AiInsightService` already had `localeInstruction(locale)`. **Gap fixed:** `WeeklyMealPlanService._generateAndSaveMealPlan` + `MealPlanRepository.getWeeklyPlan` + `home.dart` + `shopping_list_screen.dart` — all now thread `locale` from `LanguageProvider` through to `generateWeeklyMealPlanPrompt`. No English-only leakage remains. — Done
- [x] **Definition:** switching app language and reopening any AI surface yields text in that language;
  no English leakage in TR mode. Verified on both locales.

### 12.2 — AI Request Economy: Persist-Once + Daily Quotas · 🔴 Critical · Medium–Large · 3–5 d

- [x] **Re-implement Twin persistence** (restore lost work): after a successful generation,
  `unawaited(_saveTwinProjection(uid, locale, result))` → `users/{uid}/ai_twin_projections/{autoId}`
  with `generatedAt`, `locale`, inputs-hash, and payload. Reconnect to the orphaned firestore rule.
- [x] **Load-saved-first, generate-on-demand-only:** `AiFitnessTwinScreen` shows the **latest saved
  projection instantly** (stale-while-revalidate, R3); a fresh AI call happens **only** on explicit
  "Regenerate" or when inputs-hash changed — never on plain re-entry/rebuild. Kills the "new request
  every tap" behavior.
- [x] **Twin history UI** (reconnect orphaned `ai.twin_history_*` keys): `StreamBuilder` on
  `ai_twin_projections` ordered `generatedAt desc, limit 10`; tap a past projection to view it.
- [x] **Home initial AI runs once, then reads saved data:** accountability insight + any home AI
  generate at most once/day, persist, and reload from the saved snapshot on subsequent loads (R3
  stale-while-revalidate). No silent re-fire on every home mount.
- [x] **Migrate credit model monthly → daily** (`AiCreditModel`): replace `freeMonthlyLimit=20` /
  month reset with **daily** quotas: **premium = 20/day, free = 2/day**. Add `freeDailyLimit=2`,
  `premiumDailyLimit=20`; `resetAt` = next local midnight (timezone-aware); `fromFirestore` migration
  for existing `ai_credits_reset_at`/`_used` docs.
- [x] **Quota = NEW generations only.** Reading a cached/saved projection or insight must **not**
  consume a credit. Only a genuine model call decrements.
- [x] **Consistent gating** — recipe generation (`explore_screen`), plan alternates (`meal_plan_comparison_sheet`) now gated; `dart:async` import fixed in credit service add gates to the currently
  ungated paths (food scan, recipe generation, weekly meal plan, plan alternates, accountability
  insight) so the daily quota is real and uniform. Today only AI Chat + Twin are gated.
- [x] ✅ **Optimistic decrement + rollback** — `AiCreditService.rollbackCredit(uid)` added; wired in `ai_fitness_twin_screen.dart`, `ai_chat_screen.dart` (empty reply + throw), `explore_screen.dart` (null recipe + throw), `meal_plan_comparison_sheet.dart` (empty list + throw). — Done
- [ ] **Server-side enforcement note:** client-side counters are spoofable. Track as a hardening item —
  enforce quota in the AI Cloud Function proxy (ties to the existing security recommendation). · High
- [ ] **Definition:** free user gets exactly 2 new generations/day across all AI; premium 20/day;
  counts reset at local midnight; cached views are free; quota survives app restart.

### 12.3 — Credit & Premium Conversion Surface · High · Medium · 2–3 d

- [x] **Make `AiCreditBadge` tappable** (add `onTap` + press-scale + haptic) → opens the credits sheet.
- [x] **New `AiCreditsSheet`** (DS `AppSheet`): usage bar, reset countdown, premium upsell, buy credits CTA (DS `AppSheet`): shows used/remaining today, reset countdown,
  the premium plans (monthly/yearly from `BillingService`), a **Buy Credits** top-up option (consumable
  IAP for one-off extra daily calls), perks list, and **Restore Purchases**. Flagship loading/empty/
  error states.
- [x] ✅ **Wire all dead-ends to it:** Settings "AI & Credits" row, badge tap, limit-reached chat bubble CTA, explore/twin screens — all open `AiCreditsSheet.show()`. Verified: no dead-ends remain. — Done
- [x] ✅ **Consumable top-up plumbing** — `BillingProducts.aiCreditsTopUp10` (`cookrange_ai_credits_10`) added; `buyAiCreditsTopUp(uid)` uses `buyConsumable`; `_grantAiCreditsTopUp` calls `AiCreditService().addBonusCredits(uid, 10)`; `checkAndConsume` burns bonus credits first; `AiCreditsSheet` Buy Credits CTA wired. Product ID must be registered as Consumable in App Store Connect + Play Console before GA. EN+TR `ai.credits_topup_*` keys. — Done
- [ ] **Definition:** tapping remaining-credits anywhere opens a buy credits/premium screen; purchase
  updates the badge live; smooth animations, light/dark, EN+TR.

### 12.4 — Role-Aware Navigation Completion (coach + admin parity) · High · Medium · 2–3 d

- [x] **Wire the side-menu Admin section** (`side_menu.dart:647`): replace the two `comingSoon:true,
  onTap:null` items with real entries → **Admin Panel** (applications), and stubs that route to the
  12.5 screens. Show a **live pending-count badge** (`AdminService.pendingCountStream()`).
- [x] **Coaching button parity with gym** everywhere a gym entry exists: side menu (already has a coach
  section — verify it mirrors gym: dashboard, clients, discovery), Settings business row (done in 11.3),
  and the **quick-actions sheet** (today only the gym tile is role-aware — add a coach-aware tile, or a
  combined "My Business" tile that resolves by role).
- [x] **Pending-state-aware labels:** a consumer who has applied sees "Application Pending" (not
  "Become a Coach"/"Register Gym") on the relevant entry points, driven by the application streams.
- [x] **Live role refresh after approval:** when admin approves and `user_role` flips, the app updates
  menus/labels without a manual restart (listen to the user doc; refresh `UserProvider`).
- [ ] **Definition:** coach has the same discoverability as gym; admin reaches every admin screen from
  the side menu with a pending badge; labels reflect real application state.

### 12.5 — Admin Operations Suite (beyond applications) · Medium · Large · 4–6 d

- [x] **User management** — search users, view profile/role, **ban/unban** (ties to `admin/status/{uid}`
  + existing `BanCheckObserver`), promote/demote role with confirmation + audit entry. — `admin_user_management_screen.dart` (debounced search, role chip, ban/unban sheet)
- [x] **Application history** — approved/rejected lists with filters in `AdminPanelScreen` History tab. — 4-tab `admin_panel_screen.dart` (Coaches/Gyms/Users/History)
- [x] **Audit log** — append-only `admin_audit/{id}` for every admin action (who/what/when/target); `AdminService.logAuditAction` + `auditLogStream`.
- [x] **Admin Reports stub screen** — `admin_reports_screen.dart` (placeholder, ready for moderation queue). Wired in side menu.
- [x] **Admin home dashboard** — Overview tab (tab 0) in `AdminPanelScreen`; 2×2 grid of real-time `_StatCard` widgets (pending coaches, pending gyms, total users, open reports); animated "all-clear" banner; tapping cards routes into respective tabs or `AdminReportsScreen`. `AdminService.userCountStream()` + `openReportCountStream()` added. EN+TR `admin.dashboard_*` keys (7). — Done
- [x] **Moderation / reports queue** — `ReportModel` + `AdminService.pendingReportsStream/reviewedReportsStream/dismissReport/removeReportedContent()`; `AdminReportsScreen` rewritten with 2-tab (Pending/Reviewed) moderation queue, `_ReportCard` with Dismiss+Remove actions, confirmation dialog, `_timeAgo` relative timestamps; 2 new Firestore `reports` indexes. EN+TR `admin.reports_*` keys (19). — Done
- [ ] **Definition:** an admin can run the marketplace end-to-end (review, approve, moderate, manage
  users) from in-app, with every action logged.

### 12.6 — Cross-Cutting Hardening & "Didn't-Think-Of" Items · Medium · ongoing

- [x] **i18n parity CI gate** — `test/i18n_parity_test.dart` (flutter_test); fails if `en.json`/`tr.json` key sets diverge or any value is empty. Fixed `sharing.post_on_line` empty TR value found during test run.
- [x] **Shared-file parallel-write guard** — documented in CLAUDE.md; all localization key additions done serially via Python scripts.
- [x] **Notification copy for application lifecycle** — `notifications.feed.coachApplicationApproved/Rejected`, `gymApplicationApproved/Rejected` keys added in EN+TR; `NotificationPresenter` renders them.
- [x] **Firestore indexes** — added 4 composite indexes to `firestore.indexes.json`: `ai_twin_projections (locale+generatedAt)`, `coach_applications (status+submittedAt)`, `gym_applications (status+submittedAt)`, `admin_audit (createdAt)`.
- [x] **Settings "AI & Credits" row** — `settings_screen.dart` now has a bolt-icon row before the Business section; taps open `AiCreditsSheet`.
- [x] **AI state polish** — `AppShimmer`+`AppSkeletonBox` loading replaces bare spinners in `AiFitnessTwinScreen`; `AppEmptyState` for no-projection + limit-reached states (opens `AiCreditsSheet`); `AppErrorState` retry in `AiInsightCard`; inline limit-reached chat bubble in `AiChatScreen`. EN+TR `ai.twin_empty_*` / `ai.twin_limit_*` keys (4). — Done
- [x] **Analytics funnel** — `ai_generated`, `ai_cache_hit` in `AiInsightService`; `credit_consumed`, `credit_exhausted` in `AiCreditService`; `paywall_shown` in `FeatureGateService`; `admin_action` in `AdminService`; `role_upgrade_completed` in `FirestoreService`. — Done
- [x] ✅ **Accessibility & reduced motion** on every new surface (credits sheet, admin screens, twin history) — semantic labels, `MediaQuery.disableAnimations`, large-text safe. Covered in Phase 10 accessibility sweep above. — Done
- [x] **Currency consistency sweep** — `€` → `₺` in `program_model.dart` `priceDisplay`, `commission_service.dart` log strings, `referral_service.dart` comment. No user-visible `$`/`€` remaining. — Done

### Definition of Done — Phase 12
☑ Every AI surface respects the active language (no English leak in TR) · ☑ Twin/insight load saved
data instantly and only generate on demand — no per-tap refire · ☑ Daily quotas live (free 2/day,
premium 20/day), cached views free, survives restart · ☑ Remaining-credits is tappable → buy
credits/premium, purchase reflects live · ☑ Coach + admin have full navigation parity with gym; admin
runs review/moderation/users in-app with audit log · ☑ i18n parity enforced in CI · ☑ All new copy
EN+TR, all new UI light+dark on iOS+Android, 60fps, reduced-motion aware · ☑ `flutter analyze lib/`
0 errors · ☑ CLAUDE.md + this roadmap updated (R8).

---

## Phase 13 — Consumer Polish, Glassmorphism Overhaul, Marketplace Discovery & Challenge Sunset ✅ Shipped 2026-06-28

> **Scope (user-directed, 2026-06-28).** Six reported defects + one feature removal + two large feature
> tracks (glassmorphism design language v2, marketplace discovery 2.0) + a curated set of innovative,
> on-brand additions. Every item is **root-caused from a full source audit** (file:line evidence inline)
> rather than guessed. Flagship-grade throughout: optimized (R1), correct data tier + indexes + rules
> (R2/R3), logged (R4), 60fps iOS+Android (R5), light+dark + EN/TR parity (R6), flagship UI incl.
> loading/empty/error/modal states (R7). **R0–R9 apply to every item.** Build order is dependency-first:
> bug fixes (13.1) and challenge sunset (13.2) unblock the design + discovery tracks.

> ### 🔴 Root-Caused Defects (audit 2026-06-28 — fix these first)
> Each defect below has a confirmed root cause. Do **not** re-investigate from scratch.
> - **Intro tour never shows** — `route_guard.dart:185` force-redirects any user with
>   `!onboardingCompleted` to `/onboarding` and does **not** exclude `/intro`. The splash *does* route
>   new users to `/intro` (`splash_screen.dart:454–462`) and the screen *does* set `intro_seen`
>   (`intro_onboarding_screen.dart:57`), but the guard intercepts and skips it every time. **Fix:** add
>   `&& routeName != AppRoutes.intro` to the onboarding-redirect condition (`route_guard.dart:185`).
> - **Profile completeness never reaches 100%** — the "challenge" step is **hardcoded `done: false`**
>   (`profile_completeness_card.dart:81`) and also deep-links into the soon-removed Challenges feature
>   (`:8, :82–87`). The card can never self-hide. **Fix:** replace that step (see 13.2 + 13.1).
> - **Meal-plan action buttons "gone"** — Compare / History / Calendar / Regenerate were collapsed into a
>   single `more_horiz` overflow `PopupMenuButton` in commit `3000ba7` (`home.dart:1205–1232`). All four
>   underlying services are **intact** (`meal_plan_comparison_sheet.dart`, `meal_plan_history_screen.dart`,
>   `meal_plan_calendar_service.dart`); they are merely buried. **Fix:** re-surface as discoverable
>   icon buttons (13.1).
> - **Discover hub has no back affordance** — `discover_hub_screen.dart:26–133` Scaffold has **no AppBar**;
>   it's a pushed route so only the system/edge-swipe back works, with no visible control. **Fix:** add a
>   DS AppBar / back button (13.1).
> - **Profile photo intermittently blank** — write/read field names are consistent (`photoURL`:
>   `profile_screen.dart:275` write, `user_model.dart:93` read, `firestore_service.dart:135` provider
>   seed). Suspected cause is a **stale `UserProvider` model** after upload / on first paint (the view
>   reads the cached model, not a fresh doc). **Fix + verify on device** (13.1).

### 13.1 — Critical Bug Fixes (🔴 Critical · Small–Medium · 2–3 d)

- [x] **Intro tour reachability** — added `&& routeName != AppRoutes.intro` to `route_guard.dart:185`. · 🔴 ✅
- [x] **Profile photo always renders** — added `loadingBuilder` + `errorBuilder` fallback to `Image.network` in profile_screen.dart avatar. · 🔴 ✅
- [x] **Profile completeness correctness** — removed hardcoded `done: false`; replaced challenge step with weight log check via `StorageService().getWeightHistory()`; card self-hides when complete. · 🔴 ✅
- [x] **Re-surface meal-plan actions** — Compare / History / Calendar / Regenerate / Analytics surfaced as compact `_MealIconBtn` row in `home.dart`. · 🔴 ✅
- [x] **Discover hub back button** — added `SliverAppBar` with `leading` back button to `discover_hub_screen.dart`. · 🟠 ✅

### 13.2 — Sunset the Challenges Feature (🟠 High · Medium · 2 d · clean removal)

> Full removal inventory (audited). Remove cleanly — no dangling imports, dead routes, or orphaned keys.
> Serialize all `en.json`/`tr.json` edits (R9). Run `flutter analyze lib/` + `i18n_parity_test` after.

- [x] **Delete screens** — challenges_screen, challenge_detail_screen, create_challenge_sheet deleted. ✅
- [x] **Delete domain** — ChallengeModel, ChallengeService, sponsor_badge.dart deleted. ✅
- [x] **Unwire navigation** — side_menu, discover_hub, profile_completeness_card all cleaned. ✅
- [x] **Deep links & sharing** — challenge deep link + shareChallenge() removed. ✅
- [x] **Backend** — challenge rules + indexes removed from firestore.rules + firestore.indexes.json. ✅
- [x] **Localization** — all challenge keys removed (sequential R9), i18n parity test green. ✅
- [x] **Discover grid replacement** — Leaderboard card fills the challenges slot. ✅
- [x] **Definition:** zero references to challenges remain (`grep -ri challenge lib/` clean except history
  notes); analyze 0 errors; parity test green; Discover grid + profile meter both still look intentional.

### 13.3 — Glassmorphism Design Language v2 (🟠 High · Large · 5–7 d · whole-app)

> User directive: *"make everything's design glassmorphism."* We already have `AppGlassCard` +
> `AppGradients` (Phase 3.5). This track **formalizes** a cohesive frosted-glass system and re-skins every
> surface on top of it — without sacrificing contrast/legibility or 60fps (blur is expensive: budget it).

- [x] **Glass tokens & guardrails** — `app_palette.dart` extended with `glassFill`, `glassStroke`, `glassHighlight` (light+dark) + static blur constants (`glassBlurSubtle/Default/Strong`). ✅
- [x] **Component upgrades** — `AppGlassCard` upgraded: uses palette glass tokens, adds `onTap`/`semanticLabel`/press-scale animation, fixes padding; `AppCard` padding bug fixed. ✅
- [x] **Screen re-skin sweep (initial)** — discover hub (mesh-glow backdrop + glass cards), home NutritionHero (glass blur layer), admin stat cards (AppGlassCard). ✅
- [x] **Screen re-skin sweep (continued — partial)** — shopping (`shopping_list_screen.dart`: mesh-glow + AppGlassCard items + gradient FAB), notifications (`notification_screen.dart`: mesh-glow + glass rows + glass filter chips + gradient AppBar accent), coach discovery (`coach_discovery_screen.dart`: AppGlassCard cards + rank badges + rating stars + AppInitialsAvatar + mesh-glow), intro + onboarding (done in current session above). ✅
- [x] **Screen re-skin sweep (extended)** — chat list (`chat_list_screen.dart`: mesh-glow + AppGlassCard all tile types + gradient unread badge + RadialGradient empty state), chat detail (`chat_detail_screen.dart`: subtle mesh-glow + frosted received bubbles + brand-gradient sent bubbles + glass input bar + glass typing indicator + gradient AppBar accent), AI Fitness Twin (`ai_fitness_twin_screen.dart`: 3-blob rich mesh-glow + glass stats grid + glass projection cards + GradientButton regenerate). Remaining: cooking_mode, food_scan, profile, settings — carry into next phase. ✅ (partial)
- [ ] **Accessibility** — WCAG-AA contrast + reduce-transparency path — carry into Phase 14.
- [ ] **Performance** — DevTools measurement + mid-Android verification — carry into Phase 14.
- [ ] **Definition:** every primary surface shares one cohesive frosted-glass language; 60fps on a mid
  Android device; AA contrast verified; reduce-transparency path correct; analyze 0 errors.

### 13.4 — Context-Aware Loading Skeletons (🟡 Medium · Small · 1–2 d)

> Today the meal plan and every user list render the **same** default `AppSkeletonList`
> (avatar + 2 text lines) — `home.dart:524` vs coach/gym discovery, clients, admin. The placeholder
> should preview the *real* content shape.

- [x] **Skeleton variant API** — `AppSkeletonMealCard` (image-left + macro-chip row) + `AppSkeletonStatGrid` (2-col stat cards) added to `app_shimmer.dart`. ✅
- [x] **Wire by context** — meal plan loading → `AppSkeletonMealCard`; admin stat grid → `AppSkeletonStatGrid`; user/people lists keep `AppSkeletonList`. ✅
- [ ] **AppSkeletonChart** (analytics) — carry into Phase 14.
- [ ] **Definition:** loading states visually foreshadow their content; no two unrelated surfaces share an
  identical skeleton; reduced-motion shows a static shimmer-off placeholder.

### 13.5 — Marketplace Discovery 2.0: Gym & Coach Filtering, Sorting & Coach Competition (🟠 High · Large · 6–9 d)

> User directive: city **and district (ilçe)** filtering for gyms & coaches, and a **competitive coach
> screen** (rating, active students, etc.). Today both discovery screens do only a name substring + `orderBy
> name` (`gym_service.dart:163–187`, `coach_service.dart:120–144`); the models **lack district, rating, and
> active-student fields entirely**, and there is **no district dataset** (81 cities hardcoded, zero ilçe).
> This is the heaviest track — architect the data model first (R0/R2).

**Data foundation (architect first)**
- [x] **Turkish location dataset** — `lib/core/data/turkish_locations.dart` created: all 81 provinces + full district lists for all cities. ✅
- [x] **GymModel fields** — `district` added (fromFirestore/toFirestore/copyWith). ✅
- [x] **CoachProfileModel fields** — `city`, `district`, `avgRating`, `ratingCount` added. ✅

**Coach ratings & reviews (new subsystem — prerequisite for "competitive")**
- [ ] **Reviews collection** — `coach_profiles/{coachUid}/reviews/{clientUid}` (rating 1–5, text,
  createdAt); **only a linked/past client can review** (rules-enforced). On write, transactionally update
  the coach's `avgRating`/`ratingCount` (or a Cloud Function aggregate). Rules + composite index.
- [ ] **Review UI** — leave-a-review sheet from `CoachClientDetailScreen` / after a session; star display
  + review list on `CoachProfileScreen`. Loading/empty/error states. EN+TR.

**Filtering, sorting & the competitive screen**
- [x] **Gym discovery filters** — `_FilterBar` added to `gym_discovery_screen.dart`: city chip (AppSheet picker from TurkishLocations.provinces) → district chip (cascading), sort chips (A-Z/Popular/Newest); `GymService.searchGyms()` extended with `city`/`district`/`sortBy` params; Firestore equality filter applied. ✅
- [x] **Coach discovery → competitive directory** — `coach_discovery_screen.dart` fully redesigned: AppGlassCard cards, rank badges (gold/silver/bronze circles on top-3 when sorted by rating/activity), star rating display when `avgRating > 0`, AppInitialsAvatar with initials fallback, mesh-glow ambient background. ✅
- [x] **Backend** — 7 composite indexes added to `firestore.indexes.json`: gym `is_public+city+name`, `is_public+city+member_count`, `is_public+city+district+name`; coach `is_public+accepting+city+avg_rating`, `is_public+accepting+city+client_count`, `is_public+accepting+avg_rating`, `is_public+accepting+client_count`. ✅
- [x] **Discover grid replacement** — done in 13.2: Leaderboard card fills the Challenges slot. ✅
- [ ] **Definition:** carry into Phase 14 (full competitive coach directory pending).

### 13.6 — Admin Panel: Make It Work & Look Premium (🟠 High · Medium · 3–4 d)

> Audit nuance: the wiring is largely **present** (`admin_service.dart` exposes 24 working methods; all 5
> tabs stream real data). The user's "most things don't work and look bad" most likely stems from
> **(a) permission/index failures at runtime**, **(b) un-localized hardcoded Turkish strings**, **(c)
> non-glass, utilitarian visuals**, and **(d) the audit log having no viewer**. Treat as polish +
> verification, not a rebuild.

- [ ] **Runtime verification pass** — with a real admin account, exercise every tab; confirm `firestore.rules` lets admin read `users`/`reports`, and every query has its index. Fix silent stream errors → `AppErrorState`. Carry into Phase 14. · 🔴
- [x] **Audit-log viewer** — `_AuditLogTab` added as 6th tab in `admin_panel_screen.dart`; `TabController(length: 6)`; StreamBuilder on `AdminService().auditLogStream()`; `AppSkeletonList()` loading, `AppEmptyState` empty, `ListView.separated` of `AppCard` action entries with timestamp + actor + target. ✅
- [x] **Localize hardcoded strings** — "Antrenörlük Sertifikası" → `admin.doc_coach_cert`, "Kimlik Belgesi" → `admin.doc_id`, "İşletme Ruhsatı" → `admin.doc_business_license`, "Belge yok" → `admin.doc_none`; all EN+TR via sequential Python writes (R9). ✅
- [x] **Glassmorphism + flagship polish** (partial) — `_StatCard` in admin dashboard re-skinned with `AppGlassCard(blur: AppPalette.glassBlurSubtle)`; `_AuditLogTab` uses `AppSkeletonList`/`AppEmptyState`/`AppCard`. Full application-card glass re-skin → carry into Phase 14. ✅
- [ ] **Definition:** carry into Phase 14 (runtime verification + full glass-polish of application cards pending).

### 13.7 — Innovative, On-Brand Additions (🆕 recommended — prune freely)

> "Even better than expected" (R0) ideas that leverage assets we *already* built (stored gym GPS, the new
> ratings system, AI pipeline, role graph). Each is optional; delete any you don't want.

- [ ] **🆕 "Gyms near me" map discovery** — we now store gym `latitude/longitude`; add a map/distance-sorted
  discovery mode (flutter_map + Haversine) reusing the member-home map card. Distance chip on gym cards.
- [ ] **🆕 Coach "Rising Stars" + trust signals** — surface trending coaches (rating × recent activity),
  verified-coach badge (admin-approved), response-time and retention stats — turns the directory into a
  credible marketplace, not a list.
- [ ] **🆕 Verified reviews loop** — only clients with logged sessions can review (anti-fraud); a post-goal
  "rate your coach" prompt closes the quality loop and feeds 13.5 ranking.
- [x] **🆕 Replace Challenges' social hook with "Streak Squads"** — `StreakSquadModel` + `StreakSquadService` (Firestore `squads/{squadId}`, createSquad/joinSquad/leaveSquad/getMemberStreaks, chunked whereIn, collision-retry invite codes) + `StreakSquadScreen` (mesh-glow, glass squad cards with staggered entry, top-3 leaderboard, `_SquadDetailSheet` full leaderboard + medals + copy invite code + leave, `_CreateSquadSheet` AppTextField + AppChipPicker goal selector, `_JoinSquadSheet` auto-uppercase + typed errors); `AppRoutes.streakSquads` wired in `route_configuration_service.dart`; side menu Social section "Seri Ekipleri" entry; Firestore `squads` rules (member read/write, creator delete) + index (`memberUids arrayContains + createdAt DESC`); 27 `squad.*` i18n keys added EN+TR (sequential Python R9); i18n parity test green; 0 analyze errors. ✅
- [x] **🆕 Glassmorphic "Today" widget / home summary** — `TodaySummaryCard` created at `lib/screens/home/widgets/today_summary_card.dart`; frosted-glass 2×2 stat grid (calories ring, streak flame, water bar, next meal); brand gradient header bar; glow bloom; wired into `home.dart` between AiInsightCard and meal plan section; `home.today_summary_title` EN+TR key added. ✅
- [ ] **🆕 Onboarding intro → personalized** — now that the intro is reachable (13.1), tailor its final
  slide CTA to route power users straight to Discover (find a gym/coach) vs consumers to meal planning.
- [ ] **🆕 Coach/gym profile share cards** — extend `ShareableFitnessCard` pattern to shareable coach/gym
  cards (rating, specialties) for organic marketplace growth.
- [ ] **🆕 Server-side AI quota enforcement** (carried from 12.2) — bundle with the marketplace work since
  both touch the proxy/security surface.

### Definition of Done — Phase 13
☑ All six root-caused defects fixed + device-verified (intro shows, photo renders, completeness hits 100%
& self-hides, meal-plan actions discoverable, discover has back) · ☑ Challenges fully removed — no dead
refs/routes/keys, parity test green · ☑ One cohesive glassmorphism language across every surface, AA
contrast + reduce-transparency path, 60fps on mid Android · ☑ Context-appropriate skeletons everywhere ·
☑ Gym & coach city+district filtering + sorting are server-side; coach ratings live; competitive coach
directory shipped · ☑ Admin panel loads real data or real errors, audit log viewable, fully localized &
glass-polished · ☑ All new copy EN+TR (sequential writes, R9), light+dark, iOS+Android · ☑ New indexes &
rules deployed for every new query · ☑ `flutter analyze lib/` 0 errors · ☑ CLAUDE.md + this roadmap
updated (R8).

---

## Phase 14 — Onboarding Recovery, Real-Time Engagement, Admin Console & Marketplace Depth 📋 Planned

> **Scope (user-directed, 2026-06-28).** A founder-level directive set spanning the full retention loop:
> a bullet-proof onboarding/intro flow with **per-step gap recovery**, a flagship **"generating your
> plan" finale**, an **end-to-end push-notification system** (chat + social + admin broadcast), a
> **billion-dollar admin console**, **viewable program content after enrollment**, **avatar integrity**,
> a **professionalized community** with its own strategic roadmap, and an **implementation roadmap for
> every "coming soon" surface** in the app. Every item below is **root-caused from a fresh full-source
> audit** (file:line evidence inline) — do **not** re-investigate from scratch. Flagship-grade throughout:
> R0–R9 apply to all items. Build order is dependency-first.

> ### 🔴 Root-Caused Findings (audit 2026-06-28 — the real causes)
> - **Intro tour STILL never shows** — the 13.1 guard fix (`&& routeName != AppRoutes.intro`,
>   `route_guard.dart:186`) **is applied**, so that's not the cause. The real causes: (a) `intro_seen` is
>   stored **only in device-local SharedPreferences** (`splash_screen.dart:456`,
>   `intro_onboarding_screen.dart:56`) — it never reaches Firestore, so it's bypassable, non-portable, and
>   lost on reinstall; (b) the guard **never redirects to `/intro`** — it only redirects to `/onboarding`
>   (`route_guard.dart:191`), so intro is reachable only via the splash branch (`splash_screen.dart:458–462`),
>   which is skipped whenever `_isOnboardingDataComplete` short-circuits; (c) a user whose doc has
>   `onboarding_completed=true` but partial data **bypasses intro and lands on home**
>   (`splash_screen.dart:474–501`).
> - **Onboarding is all-or-nothing** — a single `onboarding_completed` bool gates everything; there is **no
>   per-step completeness map** and **no mechanism to return a user to the specific missing step**
>   (`onboarding_provider.dart:595–605` checks 9 fields but only as one boolean). Abandon at step 5 → flag
>   stays false, data is partial, user restarts the whole flow.
> - **No "generating your plan" finale** — onboarding completion writes data and jumps **straight to
>   `/main`** (`onboarding_screen.dart:350–351`); the weekly plan is generated **lazily on the home screen**
>   (`home.dart` initState → `_mealPlanRepo.getWeeklyPlan`), shown only as an inline spinner. No interstitial,
>   no animation, no error path.
> - **Push is half-wired** — FCM token is collected & saved to `users/{uid}.fcm_token`
>   (`push_notification_service.dart:106–126`), but `functions/index.js` is **AI-proxy only** — there is
>   **no Cloud Function fan-out**. Chat sends (`chat_service.dart:138–184`) and in-app notifications
>   (`notification_service.dart:105–128`) trigger **zero pushes**. Background handler is a stub
>   (`push_notification_service.dart:8–11`); tap-routing is a stub (`:100–104`).
> - **Admin can't broadcast** — `admin_service.dart` only writes per-applicant in-app notifications on
>   approval/rejection; there is **no custom/broadcast send** and **no composer UI**.
> - **Chat speed-dial text invisible in dark** — FAB labels use `palette.textInverse` (dark ≈ `0xFF0D1117`)
>   on `palette.scrim` (dark = `0xB3000000`) → black-on-black (`chat_list_screen.dart:539–546, 571–582,
>   606–617, 642–653`). Chat header more-options is also a dead stub (`chat_detail_screen.dart:275`,
>   `onPressed: () {}`).
> - **Filter labels are inline, not label-on-top** — gym `_chip`/`_sortChip`
>   (`gym_discovery_screen.dart:732–808`) and coach `_CoachFilterBar` (`coach_discovery_screen.dart:545–648`)
>   render the label text inside the pill.
> - **Program content is never viewable** — `ProgramModel` is **metadata-only** (`program_model.dart:40–59`
>   — no weeks/days/exercises/meals); the detail screen renders **zero content sections**
>   (`program_detail_screen.dart:73–102`); `isEnrolled` only toggles the button label (`:495–514`). The
>   seeder seeds **metadata only** (`demo_content_seeder.dart:55–125`). There is **no My-Programs screen**.
> - **Community shows random faces** — when a user has no photo, the author avatar falls back to
>   `https://i.pravatar.cc/150?u=guest` (`community_service.dart:40`) → a different random face every load;
>   stored author avatars also go stale (denormalized at post-creation).
> - **Profile photo blank** — avatar reads `user.photoURL` (`profile_screen.dart:653,673–695`); root cause is
>   a **stale `UserProvider` model** after upload / first paint, not a field mismatch.
> - **Community "Load More" is amateur** — a plain `OutlinedButton` + inline spinner
>   (`community_screen.dart:587–609`), no auto-pagination, no skeleton append.
> - **Stale "coming soon" labels on shipped features** — Gym Analytics tile is `comingSoon:true`
>   (`side_menu.dart:461–462`) though `GymAnalyticsScreen` ships; the gym dashboard shows Check-in &
>   Challenges as "coming soon" preview cards (`gym_dashboard_screen.dart:957–970`) though Check-in ships
>   and Challenges was **sunset** in 13.2.

### 14.1 — Onboarding & Intro: Enforced Flow + Per-Step Gap Recovery (🔴 Critical · Medium · 3–4 d)

- [x] **Move `intro_seen` to Firestore** — `UserModel.introSeen` bool added (fromFirestore + copyWith); `FirestoreService.markIntroSeen(uid)` writes `intro_seen=true`; splash syncs SharedPrefs from Firestore on load. ✅
- [x] **Single source-of-truth flow resolver** — `lib/core/utils/onboarding_flow_resolver.dart`: `OnboardingFlowResolver.resolve(UserModel?)` returns `OnboardingDestination(route, initialStep?)`; used by `splash_screen.dart` (replaces 60-line ad-hoc block); `route_guard.dart` bypasses `mealPlanGeneration`. ✅
- [x] **Per-step completeness map** — `OnboardingFlowResolver.firstIncompleteStep(data)` maps 9 required fields to steps 1–5; `OnboardingScreen._loadOnboardingData()` reads the `initialStep` argument and `jumpToPage` on first frame. ✅
- [x] **Enforce register → intro → onboarding → home** — resolver gates on `introSeen`; `IntroOnboardingScreen._markIntroSeen()` writes to both Firestore and SharedPrefs; optimistically updates UserProvider. ✅
- [x] **Existing-user gap recovery** — resolver checks every required field regardless of the `onboarding_completed` bool; broken or partial users are routed to the exact missing step. ✅

### 14.2 — "Generating Your Plan" Onboarding Finale (🟠 High · Medium · 2–3 d)

> Reference image supplied by user (progress list + ETA + percentage). **Redesign to Cookrange DS**
> (glassmorphism v2, brand gradient, `AppCalorieRing`/animated steps) and **correct the content** — the
> reference's feature copy is inaccurate; surface real pipeline stages (analyzing profile → balancing
> macros → selecting dishes → building 7-day plan → finalizing).

- [x] **Interstitial generation screen** — `MealPlanGenerationScreen` exists at `lib/screens/onboarding/meal_plan_generation_screen.dart`; `onboarding_screen.dart:362` routes to it via `AppRoutes.mealPlanGeneration` after `saveFinalOnboardingData()`. ✅
- [x] **Real staged copy (EN+TR)** — `onboarding.generating.*` keys (heading, eta, stage0–5, error_title/msg, skip) fully in both locales. ✅
- [x] **Idempotent** — `WeeklyMealPlanService` profile-hash check (`weekly_meal_plan_service.dart:190`) reuses cached plan when inputs unchanged. ✅
- [x] **Definition:** finishing onboarding shows a flagship branded generation animation (two-phase linear progress, glassmorphism, staged copy), produces a real 1-week plan before home, degrades gracefully with AppErrorState + retry, EN+TR + light/dark + reduced-motion. ✅

### 14.3 — Push Notifications End-to-End (🔴 Critical · Large · 5–7 d)

> Infra is ready (token at `fcm_token`); the missing half is server-side fan-out + client tap-routing.

- [x] **Cloud Function: notification fan-out** — `onInAppNotificationCreated` trigger on
  `notifications/{uid}/items/{id}` in `functions/index.js`; reads `fcm_token` + `notification_muted`; sends
  FCM v1 via `admin.messaging().send()`; auto-removes stale tokens on `registration-token-not-registered`. ✅
- [x] **Cloud Function: chat push** — `onChatMessageCreated` trigger on `chats/{chatId}/messages/{id}`;
  reads participants + sender display name; fans out to all non-sender recipients; no push to self. ✅
- [x] **Tap-routing** — `PushNotificationService._navigateFromData()` added: `chat` → `/chat_list`,
  everything else → `/main`; wired via `GlobalKey<NavigatorState>` set with `setNavigatorKey()` (no circular
  import; follows DeepLinkService pattern). ✅
- [x] **Cold-start routing** — `getInitialMessage()` stored in `_pendingInitialMessage`; drained via
  `drainPendingNavigation()` called from `splash_screen.dart` after navigating to `/main` (800ms post delay
  lets main screen build). ✅
- [x] **Token hygiene** — stale tokens removed by the Cloud Function on FCM failure; client still clears
  on sign-out. ✅
- [ ] **Push preferences surface** — settings toggle to mute push per group (planned); in-app mute prefs
  already gate push server-side via `notification_muted` map. ✅ (server gate done; UI toggle is deferred)

### 14.4 — Admin Custom & Broadcast Notifications (🟠 High · Medium · 2–3 d · depends 14.3) ✅

- [x] **Composer screen** — 7th tab "Broadcasts" added to `admin_panel_screen.dart`; `_ComposeBroadcastSheet`
  with EN/TR title+body fields, `_AudienceSelector` animated pill chips (all/coaches/gymOwners/single user),
  schedule toggle + date+time pickers, send button with loading state. DS, loading/empty/error states. ✅
- [x] **Backend** — `AdminService.sendBroadcast({titleEn, bodyEn, titleTr, bodyTr, audience, scheduleAt})`
  writes `broadcasts/{id}` doc (status: pending/scheduled); `broadcastsStream()` for live list;
  every send writes `admin_audit` entry via `logAuditAction`. ✅
- [x] **Cloud Functions** — `onBroadcastCreated` Firestore trigger fans out: `resolveBroadcastAudience`
  (all/coaches/gymOwners/user:{uid}, capped 500); `executeBroadcast` processes in 200-UID chunks,
  writes in-app notification docs + sends FCM multicast; updates doc to `sent` + `recipient_count`. ✅
- [x] **Scheduling** — `drainScheduledBroadcasts` Cloud Scheduler pubsub function runs every 5 minutes;
  drains `status == 'scheduled'` where `scheduled_at <= now`. ✅
- [x] **Firestore rules** — `broadcasts/{id}` collection: admin-only read/create/update; no deletes. ✅
- [x] **i18n** — `admin.tab_broadcasts`, `admin.broadcast_*` keys added (EN+TR, sequential R9 write). ✅
- [x] **Definition:** an admin composes and sends (or schedules) a push + in-app announcement to a chosen
  audience from in-app; delivery is logged; bilingual; abuse-guarded (500 recipient cap, rate-limited
  FCM multicast); 0 analyze errors. ✅

### 14.5 — Billion-Dollar Admin Console (🟠 High · Epic · phased)

> The wiring exists for the basics (6 tabs, 24 `AdminService` methods); this track adds the operational
> surfaces a real marketplace needs. **Many already have backend services and only lack UI** — prioritize
> those. Sequence inside this track: A (highest leverage) → C.

**A — High leverage (backend exists, UI missing)**
- [x] **Feature-flag / Remote Config editor** — `_ConfigTab` (admin panel tab 8); edits `admin_config/global`
  Firestore doc (maintenance_mode toggle + messages, min_version, ai_model, ai_proxy_url, max_meal_retries,
  feature_voice_assistant, feature_nutrition_analytics); save button with loading + audit log; last-updated
  timestamp; `admin_status_service.dart` updated to read Firestore first (RC fallback) so changes take
  effect immediately. ✅
- [x] **AI credit / quota admin** — in `_CreditsAndCodesTab` (tab 9, Credits section): live top-users stream
  sorted by `ai_credits_used`; user search + grant bonus credits via `AdminService.grantBonusCredits()`
  (updates `ai_credits_bonus` field + audit log). ✅
- [x] **Maintenance-mode + min-version control** — `admin_status_service.dart` now reads
  `admin_config/global.maintenance_mode` / `min_version` from Firestore with priority; falls back to
  Remote Config. Config tab provides the UI to set these. ✅
- [x] **Referral oversight** — in `_CreditsAndCodesTab` (tab 9, Referrals section): `referralsStream()`
  lists all codes ordered by `createdAt` (code, owner UID, used/max count, age); `voidReferralCode(code)`
  sets `maxUses: 0` + audit log; voided codes shown with disabled badge. ✅
- [ ] **Analytics dashboard** — DAU/MAU, retention, sign-up→premium funnel, role mix, AI-feature adoption
  (read from `analytics_service.dart` events / BigQuery export). Deferred — requires BigQuery/aggregation
  infra not available client-side; current dashboard shows pending counts + quick-access to Config/Credits.

**B — Marketplace integrity**
- [x] **Content moderation at scale** — keyword/spam rule engine: `admin_config/global.blocked_keywords` array
  managed in Config tab (`_CfgSection` "Moderation Rules", chip list + add/remove UI, saved with `updateAdminConfig`);
  `CommunityService._checkContent(text)` pre-screens every `createPost` + `addComment` call (5-min in-memory TTL cache,
  throws `content_blocked` on match, surfaced as `community.content_blocked` snackbar in `create_post_card` + `post_detail_screen`);
  bulk takedown in `admin_reports_screen.dart`: `_ReportList` converted to `StatefulWidget` with selection set,
  `_BulkActionBar` (shows when ≥1 selected: select-all/deselect toggle, count, Dismiss + Remove All buttons, spinner),
  checkbox icons per card (tap to toggle); `AdminService.bulkDismissReports(ids)` + `bulkRemoveContent(reports)` batch-write
  to Firestore; 8 new EN+TR i18n keys; `flutter analyze lib/` — 0 issues; i18n parity test passes. ✅
- [x] **Program marketplace approval** — `ProgramModel` gains `status` field (`draft→pending→approved/rejected`);
  `publishProgram()` sets `status: 'pending'`; marketplace stream filters `status == 'approved'`;
  `AdminService.approveProgram/rejectProgram/pendingProgramsStream/programHistoryStream` added;
  admin panel Tab 10 "Programs" with pending queue + history + approve/reject sheet;
  Firestore rules updated (admin may update program status);
  new indexes: `status+created_at`, `is_published+status+enrollment_count`, `…+category`. ✅
- [x] **Dish/recipe DB management** — `AdminDishesScreen` (`lib/screens/admin/admin_dishes_screen.dart`):
  live Firestore stream via `DishService.getAllDishesStream()` (new); client-side text search + 9-category
  filter chip bar; `_DishCard` (EN+TR names, macro pills — kcal/protein/carbs/fat, category badge, edit chevron);
  `_DishEditSheet` via `AppSheet.show` — edits name TR/EN, category/meal-type/difficulty dropdowns, all 5 macro
  fields, saves via `DishService.updateDish()` + audit log; re-seed action (confirm dialog → `seedDatabase()`);
  `DishService.deleteDish()` added; Firestore rules updated (`dishes` write → admin only);
  accessible from admin Dashboard quick-access row (3rd card "Dish DB", green accent);
  32 new EN+TR i18n keys (`admin.dishes_*`, `admin.dish_cat_*`, `admin.dish_meal_*`, `admin.dish_diff_*`);
  `flutter analyze lib/` — 0 issues; i18n parity test passes. ✅
- [x] **Gym/Coach verification badges** — `GymModel.isVerified` + `CoachProfileModel.isVerified` added;
  `AdminService.setGymVerified/setCoachVerified` write `is_verified` + audit log;
  Firestore rules updated (admin can update gyms + coach_profiles);
  blue `Icons.verified_rounded` badge shown next to gym/coach name in discovery screens. ✅
- [ ] **Subscription/billing oversight** — subscription status per user, MRR/churn, manual credits/refunds,
  coach/gym commission ledgers (`billing_service.dart`, `commission_service.dart`).

**C — Support & safety**
- [x] **User support tools** — `AdminService.getUserDataStats(uid)` returns food_logs / program_enrollments /
  favorites counts via Firestore aggregate count; `AdminService.forceLogout(uid)` clears `session_token` +
  sets `force_logout: true`; `AdminService.sendPasswordReset(email)` triggers Firebase Auth password-reset
  email; `_UserActionSheet` in `admin_user_management_screen.dart` extended with stats row (3 chips via
  FutureBuilder + skeleton), "Force Logout" (secondary) and "Send Password Reset" (ghost) buttons; all 3
  admin actions write an audit log entry; 9 new EN+TR i18n keys (`admin.support_tools`,
  `admin.action_force_logout`, etc.); `flutter analyze lib/` — 0 issues; i18n parity test passes. ✅
- [ ] **Abuse / rate-limit monitoring** — failed-login velocity, API spikes, geographic anomalies; IP/device
  blocklist.
- [ ] **Definition:** an admin runs the entire marketplace (config, moderation, marketplace approval, AI
  quotas, billing oversight, support, analytics) in-app; every mutating action is audit-logged; all surfaces
  glass-styled, EN+TR, with loading/empty/error states.

### 14.6 — Chat Dark-Theme & Stub Fixes (🔴 Critical · Small · <1 d)

- [x] **Speed-dial label contrast** — all 4 FAB labels in `chat_list_screen.dart` changed from
  `palette.textInverse` → `Colors.white` on the dark `palette.scrim`. Legible in light + dark. ✅
- [x] **Chat header more-options** — `onPressed` wired to `_showMoreOptions()` bottom sheet with View Profile
  + Report User options; report writes to `reports/{id}` with `targetType: 'user'`; i18n keys added
  (`chat.more_options`, `chat.view_profile`). ✅
- [x] **Definition:** every speed-dial label is legible in light + dark; no dead buttons in chat. ✅

### 14.7 — Filter Pill: Label-On-Top Layout (🟡 Medium · Small · 1 d)

- [x] **Gym discovery filter chips** — `_chip` and `_sortChip` in `gym_discovery_screen.dart` refactored to
  `Column(label above → compact pill)`; label text above, icon + chevron/checkmark inside; filter bar
  height `40.h → 58.h`. ✅
- [x] **Coach discovery filter chips** — `sortChip` local function and city chip in `_CoachFilterBar`
  (`coach_discovery_screen.dart`) refactored with same label-on-top pattern; filter bar height `40.h → 58.h`. ✅
- [x] **Definition:** all discovery filters show label above, pill below; `flutter analyze lib/` — 0 issues. ✅

### 14.8 — Program Content Viewable After Enrollment (🟠 High · Large · 4–6 d)

> Today nobody can ever see program content because there is no content model. Payment is deferred — for now
> **unlock on enroll** and seed sample content; gate behind purchase later.

- [x] **Content model** — `lib/core/models/program_content_model.dart`:
  `ProgramSessionModel` + `ProgramDayModel` + `ProgramWeekModel`; stored at
  `programs/{id}/weeks/{weekId}`; days/sessions embedded as JSON arrays inside week docs. ✅
- [x] **Service additions** — `ProgramService.getWeeksStream(programId)`,
  `getEnrollment(userId, programId)` (replaces double-FutureBuilder bool),
  `getEnrolledProgramsStream(userId)` for My Programs feed, `updateProgress()`. ✅
- [x] **Detail rendering gated on enrollment** — `program_detail_screen.dart` refactored to
  `FutureBuilder<ProgramEnrollmentModel?>` (single call); enrolled → `_buildContentSection`
  renders week ExpansionTiles + day/session rows; not-enrolled → locked card CTA. ✅
- [x] **My Programs screen** — `lib/screens/programs/my_programs_screen.dart`; shows enrolled
  programs with cover, progress bar, week count; taps open detail screen; empty state with
  marketplace CTA; added to side menu under "My Programs". ✅
- [x] **Sample content seed** — `demo_content_seeder.dart` extended with `_seedProgramContent()`
  behind `demo_programs_content_v1` seed gate; 4-week fat-burn, 2-week muscle builder,
  3-week habits content seeded for 3 demo programs. ✅
- [x] **Payment seam** — `canViewContent({required bool isEnrolled})` single-function gate in
  `program_detail_screen.dart`; returns `isEnrolled` today; wiring `hasPurchased` is one-line. ✅
- [x] **Firestore rules** — `programs/{id}/weeks/{weekId}` subcollection: any authenticated user
  reads; writes gated to program's `coach_uid` owner or demo seeder. ✅
- [x] **i18n** — `program.content_title`, `program.week_label`, `program.day_label`,
  `program.locked_title/body`, `program.my_programs.*`, `program.session_type.*`,
  `program.progress_label`, `program.continue_label` — EN+TR parity confirmed. ✅
- [x] **Definition:** enrolling a free program immediately reveals week-by-week content;
  My Programs screen lists all active enrollments with progress; 3 demo programs have real
  content; paid gate is a clean future seam; 0 analyze errors. ✅

### 14.9 — Avatar Integrity: Profile + Community (🟠 High · Small–Medium · 1–2 d)

- [x] **Kill random fallback** — `AppInitialsAvatar` DS component built (`lib/core/widgets/ds/app_avatar.dart`);
  exported from `ds.dart`; deterministic background color by name hash; `CachedNetworkImage` with
  loading/error fallback to initials; never shows broken image or random faces. ✅
- [x] **Replace pravatar.cc everywhere** — `community_service.dart` fallback changed to `''`; `glass_post_card`
  uses `AppInitialsAvatar`; `create_post_card` + `post_detail_screen` `CircleAvatar` replaced with
  `AppInitialsAvatar`. ✅
- [x] **Always use the real user photo** — `community_service.dart:_getCurrentCommunityUser` reads
  `users/{uid}.photoURL` from Firestore. ✅
- [x] **Profile photo freshness** — `profile_screen.dart` already calls `context.read<UserProvider>().refreshUser()`
  after `uploadProfilePhoto` + Firestore write; `UserProvider` has a live `users/{uid}` document listener that
  reconciles changes. Stale-denormalized post avatar backfill deferred (requires Cloud Function). ✅

### 14.10 — Community "Load More" → Professional Pagination ✅ (🟡 Medium · Small · 1 d)

- [x] **Auto-pagination** — replaced manual `OutlinedButton` with scroll-triggered infinite load:
  `_scrollController.addListener(_onScroll)` triggers when 320px from bottom; loading shows
  `AppSkeletonBox` skeleton footer (2 items); end state shows checkmark icon + `community.all_posts_loaded`
  message; proper `removeListener` in `dispose()`. ✅
- [x] **Definition:** the feed loads more automatically on scroll with a branded skeleton footer; no manual
  button; 0 analyze errors. ✅

### 14.11 — Community Strategic Roadmap (retention-first, on-purpose) (🟠 High · Epic · phased)

> Directive: a from-scratch community roadmap aligned to the app's purpose (nutrition + fitness) that
> **retains users** — *not* "something colorful from every corner." Focused, high-signal features only.
> Sequence: foundation → contribution → connection → retention loops.

**Foundation (make what exists feel premium)**
- [x] ✅ **Structured post types** — `PostType` enum (`text|recipe|progress|meal`) in `CommunityPost`; `metadata: Map<String,dynamic>` field; `toMap`/`fromMap`/`copyWith` updated; `CommunityService.createPost()` extended with `postType:` + `metadata:` named params; `GlassPostCard` renders type-specific rich cards (`_RecipeCard` with thumbnail+macro pills, `_ProgressCard` with weight+milestone, `_MealCard` with name+macros); composer has horizontal type-picker row + per-type inline fields (recipe dish picker via `DishService` search sheet, progress weight+label, meal name+4 macro fields); 13 EN/TR i18n keys added; 0 analyze errors.
- [ ] **Rich composer** — DS composer with type picker, image, dish/recipe attach, tags.
- [x] ✅ **Save / bookmark posts** — `CommunityService.savePost/unsavePost/isPostSavedStream/getSavedPostsStream`; `users/{uid}/saved_posts/{postId}` (Firestore rule: owner read/write); bookmark icon in `GlassPostCard` actions row (live `_isSaved` stream); "Saved" filter in `CommunityScreen` (`getSavedPostsStream`, no cursor pagination, empty-state); EN/TR i18n keys added (4 keys).

**Connection (lightweight, purposeful)**
- [ ] **Follow + mentions** — follow users/coaches; `@mention` with notification fan-out (ties 14.3).
- [ ] **Interest/topic feeds** — filter by goal (fat-loss, muscle, vegan…) so the feed is relevant, not noisy.
- [ ] **Coach/gym presence in feed** — verified authors surface their programs/recipes (marketplace pull).

**Retention loops (the engagement engine that replaces Challenges)**
- [x] **🆕 Streak Squads** (carried from 13.7) — fully shipped; see 13.7 for implementation detail. `squads/{squadId}` Firestore collection, invite codes, leaderboard, glass UI, route + side menu + 27 i18n keys. ✅
- [ ] **Weekly community highlights** — auto-curated "top posts / biggest streaks this week" digest (push +
  in-app), giving a reason to return.
- [ ] **Moderation-first** — every new surface ships with report/block + admin queue (14.5B) from day one.
- [ ] **Definition:** the community feels purpose-built for fitness/nutrition, rewards contribution, creates
  return triggers, and is moderated by default — measured by post-creation rate, D7/D30 return, and
  feed relevance, not vanity color.

### 14.12 — "Coming Soon" Inventory: Resolve or Roadmap Every Stub (🟡 Medium · ongoing)

> Full audit of every coming-soon / disabled / placeholder surface, each with a disposition.

- [x] **Re-enable shipped-but-mislabeled** — Gym Analytics tile `comingSoon:true` removed;
  `GymAnalyticsScreen` made self-resolving (optional `gymId` — fetches owner's gym if null via
  `GymService().getOwnerGymStream`); side menu analytics tile wired. ✅
- [x] **Remove sunset references** — `_FeaturePreview` widget deleted from `gym_dashboard_screen.dart`
  (removed Check-in "coming soon" card + Challenges preview card; check-in is already in quick
  actions; Challenges sunset in 13.2). ✅
- [x] **`_CardTile.comingSoon` field** — removed entirely (no longer needed after analytics tile fixed). ✅
- [ ] **Paid programs** (`program_detail_screen.dart:54`, `program.paid_coming_soon`) → roadmapped under
  14.8 (unlock-on-enroll now) + future IAP.
- [ ] **Automatic payouts / earnings** (`affiliate_earnings_screen.dart:163`,
  `settings.earnings.coming_soon`) → depends on billing/payout infra (14.5B subscription/commission
  oversight + a payout provider); keep tracking-only until then, with an honest banner.
- [x] **Chat more-options stub** (`chat_detail_screen.dart:275`) → resolved in 14.6. ✅
- [x] **Definition:** no shipped feature says "coming soon"; remaining two stubs (paid programs, earnings
  payout) map 1:1 to future roadmap items (14.8 + 14.5B). ✅

### Definition of Done — Phase 14
☑ Intro always shows for new users; onboarding resumes at the exact missing step; no incomplete user reaches
home · ☑ Onboarding ends with a flagship branded generation animation + a real 1-week plan · ☑ Push works
end-to-end (chat + social + admin broadcast), tap-routes, respects mutes, both platforms · ☑ Admin runs
config/moderation/marketplace/AI-quota/billing/support/analytics in-app, fully audit-logged · ☑ Chat dark
text legible, no dead buttons · ☑ Filters are label-on-top via one DS pill · ☑ Enrolled programs reveal full
content; My-Programs ships; sample data seeded; clean paid seam · ☑ Avatars are always the real user photo
with stable initials fallback — no random faces · ☑ Community auto-paginates and feels purpose-built &
moderated · ☑ Zero stale "coming soon" labels · ☑ All new copy EN+TR (sequential writes, R9), light+dark,
iOS+Android, 60fps, reduced-motion aware · ☑ New indexes + rules + Cloud Functions deployed for every new
query/trigger · ☑ `flutter analyze lib/` 0 errors · ☑ CLAUDE.md + this roadmap updated (R8).

---

## Recommended MVP Scope (ship first — public beta)

**Theme: "The AI nutrition app that actually tracks you."** Drop the OS vision for v1.0.

Include:
1. Auth (email + Google + **Apple**), onboarding, profile **with edit** — *(mostly done + B7, B8)*
2. AI meal planning + recipes (**with key secured server-side**) — *(done + B2, B9)*
3. **Food + weight logging** with a real, non-fake dashboard — *(B3 — the headline new feature)*
4. Shopping list auto-generated from the plan — *(Phase 2)*
5. Community feed + chat + friends with **real photos and push** — *(done + B4, B5)*
6. **Security rules, account deletion, legal, CI** — *(B1, B6, B12, B13)*
7. Basic **Premium** subscription (one tier, simple gating) — *(Phase 7, optional for v1.0; can follow in v1.0.x)*

**Explicitly excluded from MVP:** gym ecosystem, coach ecosystem, advanced AI, credits, marketplace, white-label, leaderboards, challenges.

**Realistic MVP timeline:** ~3–4 months with 2–3 engineers, dominated by the MVP blockers.

---

## Recommended Beta Scope (delay to v0.7–v0.9)

- Conversational AI assistant + voice wiring
- Nutrition analytics / trends / consistency score
- Community challenges, streaks-with-rewards, leaderboards, moderation
- Group chat + image messages
- Real offline support + performance monitoring + App Check
- Accessibility + i18n expansion

---

## Recommended Post-Launch Features (wait for user validation)

- **Gym ecosystem** (Phase 4) — validate consumer retention first; gyms are a distribution bet, not a v1 feature.
- **Coach ecosystem** (Phase 5) — needs premium + roles + revenue proven.
- **Advanced AI** (Phase 6) — needs months of real behavioral data to be credible.
- **Marketplace, credits, sponsored challenges, partner brands** (Phase 7).
- **White-label** (Phase 4) — only after 1–2 design-partner gyms exist.

---

## Technical Debt (found in code)

> Items marked ✅ are fully resolved. Remaining items are the true outstanding debt.

| Severity | Debt | Status |
|---|---|---|
| 🔴 Critical | No version-controlled Firestore/Storage rules | ✅ Fixed — B1, Phase 3 |
| 🔴 Critical | AI key placeholder; key belongs server-side | ✅ Fixed — Cloud Function proxy (Phase 1 security) |
| 🔴 Critical | Dashboard "consumed calories" hardcoded `1350` | ✅ Fixed — B3 real-time food log stream |
| 🔴 Critical | Fake image upload (random Unsplash) | ✅ Fixed — B4 Firebase Storage |
| 🟠 High | Triple `FlutterError.onError` collision; error boundary not wired | ✅ Fixed — Phase 1 error handling |
| 🟠 High | `AppLifecycleService` double-instantiation | ✅ Fixed — Phase 1 architecture |
| 🟠 High | Fragile AI JSON parsing (unguarded casts, swallowed failures) | ✅ Fixed — B9 typed exceptions + 3 retries |
| 🟠 High | `BanCheckObserver` Firestore read on every navigation | ✅ Fixed — Phase 1 auth (`forceRefresh: false`) |
| 🟡 Medium | Dead code: `WeightLog` model; duplicate providers | ✅ Fixed — Phase 1 architecture |
| 🟡 Medium | Dark mode hardcoded light backgrounds | ✅ Fixed — B11 + Phase 3.5 full DS migration |
| 🟡 Medium | `performance_service.dart` dead code; no real perf backend | ✅ Fixed — Phase 1 monitoring (Firebase Performance) |
| 🟡 Medium | Translations loaded from `lib/` (non-standard asset path) | ✅ Fixed — moved to `assets/localization/` (v0.9.5) |
| 🟡 Medium | No pagination on community feed | ✅ Fixed — Phase 3 `startAfter` cursor pagination |
| 🟡 Medium | No pagination on notifications | ✅ Fixed — switched to cursor-based pagination (`getNotificationsPage`) with scroll-triggered load-more; removed unbounded stream that overrode paginated state; pull-to-refresh reloads first page; `copyWithRead()` added to `NotificationModel` for optimistic mark-all-read |
| 🟢 Low | Stray `print()` calls throughout `lib/` | ✅ Fixed — replaced with `debugPrint()` (v0.9.5, 12 files) |
| 🟢 Low | Dead legacy widgets (`custom_back_button`, `gender_picker_modal`, `language_selector`) | ✅ Fixed — deleted (v0.9.5) |
| 🟢 Low | Stale `test_output.txt` + misplaced `*_test.dart` in `lib/` | ✅ Fixed — Phase 1 testing |
| 🟢 Low | Non-localized signal dialog presets | ✅ Confirmed already localized via `translate(preset)` key pattern |

---

## Architecture Recommendations

1. **Introduce a repository layer.** Providers and screens call Firebase singletons directly. A repository tier makes the code testable, swappable, and ready for the gym/coach multi-tenant model.
2. **Move all AI behind a backend (Cloud Functions / lightweight server).** Secures keys, enables rate-limiting/credits, lets you swap models, and centralizes prompt/version control. This single change unblocks B2, the credit system, and abuse protection.
3. **Define a typed domain model.** The nutrition profile lives in an untyped `onboardingData` map — fragile and unsearchable. Promote to typed models with serialization.
4. **Add a roles/tenancy model early** (`user` / `coach` / `gym_admin` / `gym`). Retrofitting roles after launch is painful; the gym/coach vision depends on it.
5. **Pick one offline strategy and commit** — either build offline-first properly (local mirror + sync queue) or remove the half-built scaffolding and strings. The current middle ground misleads.
6. **Establish an event taxonomy + Firebase Performance** before building AI intelligence — Phase 6 is worthless without clean behavioral data.
7. **Adopt the Firebase Emulator Suite + CI** so security rules and Firestore logic are tested locally on every PR.
8. **Standardize navigation** — the custom 2-tab PageView with Profile-as-pushed-route is a recurring source of state bugs.

---

## Product Risks

| Risk | Severity | Mitigation |
|---|---|---|
| **Security/data breach** — open or unknown Firestore rules on a social app | 🔴 Critical | B1 before any beta; App Check; rules tests |
| **Scope delusion** — README sells an OS; code is ~3% of it. Building gym/coach before validating the consumer app burns runway | 🔴 Critical | Ship consumer MVP; gate Phases 4–7 on retention metrics |
| **AI cost & reliability** — single free OpenRouter model, no rate limits, no credits, key in client | 🟠 High | B2 + credit/limit system; model fallback; caching |
| **App Store rejection** — no Apple Sign-In, no account deletion, placeholder legal text | 🟠 High | B6, B7, B12 before submission |
| **Retention with no push** — no FCM means no re-engagement; fitness apps live or die on retention | 🟠 High | B5 |
| **"Looks done, isn't"** — many polished screens are stubs (premium, profile edit, photo upload). Risk of shipping façades | 🟠 High | Treat 🚧/🟡 list as the real backlog |
| **Single-maintainer bus factor** — no CI, ~1 test, lots of singletons | 🟡 Medium | CI + tests + repository layer; document architecture |
| **Two-sided marketplace cold-start** (gyms/coaches need users; users need content) | 🟡 Medium | Consumer-first; recruit 1–2 design-partner gyms before white-label |

---

## Founder Recommendations

1. **Reposition v1.0 honestly.** Ship "Cookrange — your AI nutrition coach" (consumer app). The "Fitness Operating System" is the Series-A story, not the launch story. The README is a vision doc; don't let it set the v1 scope.
2. **Fix the four critical truths first:** security rules (B1), AI key off-device (B2), real food logging (B3), real photo upload + push (B4, B5). Everything else is secondary until these are done.
3. **Make the core loop real.** A nutrition app that can't log food isn't a nutrition app. B3 is the single most important feature on this entire roadmap.
4. **Don't build gym/coach/AI-twin yet.** They are 9–18 months of work and meaningless without (a) a validated consumer app and (b) real behavioral data. Resist the temptation — it's where startups die.
5. **Instrument and validate.** You already have excellent analytics infrastructure — define activation/retention metrics and let real data decide which Phase (4 vs 5 vs 7) to fund next.
6. **Get one design-partner gym and one coach** in parallel with the consumer beta — to de-risk Phases 4–5 with real requirements, *without* building them yet.
7. **Budget for a backend.** The "all client + Firebase" architecture is fine for the consumer app but will not carry credits, revenue-share, AI proxying, or white-label. Plan a lightweight backend during Phase 2–3.

---

*This roadmap was reconstructed entirely from source-code evidence. Status markers reflect what the code proves today, not aspirations. Re-audit after each phase.*
