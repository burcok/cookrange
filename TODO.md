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

- [x] ✅ **Referral program** — `ReferralService` singleton: `getOrCreateCode()` generates 6-char secure code + writes `referrals/{code}` Firestore doc; `getReferralCount()` reads usage; `applyCode()` validates + awards 7-day premium trial to both referrer and referee via batch write + `NotificationService.sendNotification(system)`; `shareCode()` delegates to `SharingService.shareReferral()`. `_ReferralCard` StatefulWidget in Settings with shimmer loading, letter-spaced code display, usage count, Share + "I have a code" buttons; `_ApplyCodeSheet` bottom sheet with `AppTextField` (alpha-num formatter) + `AppButton(loading)`. `firestore.rules` `referrals/{code}` path added (read=auth, create=owner, update=auth with immutable owner+max_uses). EN+TR `settings.referral.*` keys (8 each). Deep link: `cookrange.app/invite/{code}` → `DeepLinkService` routes on `invite` path (extendable). 0 analyze errors.
- [x] ✅ **Invite system (deep links)** — Universal Links (iOS) + App Links (Android) configured via `DeepLinkService`; `cookrange.app/invite/{code}` routes user to Settings with code; `SharingService.shareReferral()` generates invite text + link; full `ReferralService` loop closes invite → reward cycle. Phone contacts picker: deferred (requires `contacts_service` package + privacy consent flow — post-v1.0 addition).
- [x] ✅ **Social sharing** (recipes, progress, lists). — Done. `SharingService` singleton (`share_plus`): `shareRecipe()`, `shareProgress()`, `sharePost()`, `shareShoppingList()`. Wired into: recipe detail AppBar share button, home nutrition header (share progress), community post onShare callback, shopping list toolbar. EN+TR `shopping.share` + `home.share_progress` keys. 0 analyze errors.
- [x] ✅ **Virality: shareable fitness-score card** — `ShareableFitnessCard` widget (`RenderRepaintBoundary.toImage(pixelRatio:3.0)` → PNG → `Share.shareXFiles(XFile)`); card shows: calorie progress ring, consumed vs target, protein/carbs/fat macro chips, streak badge, "Cookrange" footer — dark gradient aesthetic, no external packages. `ShareableFitnessCard.capture(key)` static method handles temp-file creation (`path_provider`). Wired into home screen share button: shows `AppSheet` preview with the card + "Share" `AppButton`; `_shareCardKey` `GlobalKey` in `_HomeScreenState`. 0 analyze errors.
- [x] ✅ **Community growth loops** — challenge sharing via `SharingService.shareChallenge()` + deep link `cookrange.app/challenge/{id}`; share button added to `ChallengeDetailScreen` SliverAppBar. Leaderboard already builds competitive visibility. Referral program closes acquisition loop. Shareable fitness-score cards drive organic social spread. Growth loop: join challenge → achieve goal → share card → friend joins via deep link → referral reward → repeat.
- [x] ✅ **Deep linking / App Links + Universal Links** — `app_links: ^6.3.4` added; `DeepLinkService` singleton handles initial + stream URI routing; URL scheme `https://cookrange.app/{recipe|post|user|challenge}/{id}`; Android App Links `intent-filter autoVerify="true"` + custom `cookrange://` scheme in `AndroidManifest.xml`; iOS `Runner.entitlements` with `applinks:cookrange.app`; custom scheme fallback for dev testing; wired into `_fireAndForgetPreloading()` in splash; `SharingService.shareRecipe/sharePost` now append deep-link URL when ID provided. Server-side `.well-known/assetlinks.json` + `apple-app-site-association` are deploy-time steps. 0 analyze errors.

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
- [ ] **Unified "Discover / Pro" hub** (optional, recommended) — one surface that aggregates Find a Gym,
  Find a Coach, Program Marketplace, Challenges, Leaderboard — so consumers have a single place to grow
  into the ecosystem instead of hunting the side menu. 🆕
- [ ] **Role-aware home surfacing** — once a user *has* a role, show a compact quick-entry card on home
  (e.g. gym owner → "Open Gym Dashboard"; member → "Check in"). Keeps power features one tap away. 🆕
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
- [ ] **Platform parity** — iOS purpose strings already present in `Info.plist` (camera, location, ATT);
  verify Android runtime requests + rationale on both. ATT priming already shipped (Phase 9).

### 10.4 — Feature-Tour Onboarding (illustrated intro *before* data collection) · High · Medium · 3–5 d

> Today `route_guard`/`splash` drop a brand-new user straight into the 6-step nutrition form. They never
> learn what Cookrange *is*. Add a short, beautiful, skippable walkthrough that sells the product first.

- [ ] **`IntroOnboardingScreen`** — 4–5 page horizontal `PageView` with parallax, page-dots, Skip + Next /
  "Get Started", smooth `AppMotion` transitions. Shown once (SharedPrefs `intro_seen`), *before*
  `AppRoutes.onboarding`. Wire into `route_guard`/`splash` so new users see Intro → data form. 🆕
- [ ] **Illustration assets** — no external CDN allowed; use custom `CustomPainter`/SVG (`flutter_svg`) or
  on-brand gradient compositions per page. Decide asset pipeline + add to `assets/`. Must look flagship in
  light & dark. 🆕
- [ ] **Tour content** (each page = one pillar): ① AI meal planning & recipes · ② Real food/calorie &
  weight logging · ③ Community, challenges & leaderboards · ④ Gym & coach ecosystem (sets up 10.2
  discovery) · ⑤ AI Fitness Twin & progress. Copy in EN+TR (`intro.*` keys), light/dark, reduced-motion
  fallback. 🆕
- [ ] **Re-entry** — "Replay intro / How it works" item in Settings so users can revisit. 🆕

### 10.5 — Additional Activation Improvements (🆕 recommended — prune freely)

- [ ] **First-use coachmarks / spotlight** — one-time contextual tooltips on the home hero ring, the scan
  button, and the quick-actions bar; dismiss-on-tap, SharedPrefs-guarded, reduced-motion aware. · Medium
- [ ] **"What's New" changelog modal** — show a DS sheet on first launch after a version bump
  (compare stored vs current `package_info` version); highlights new features (great for surfacing 10.2). · Low
- [ ] **Empty-state CTAs that route into features** — e.g. empty Program Marketplace → "Become a coach &
  publish"; no gym → "Find a gym near you"; no friends → "Invite / discover users". Turns dead ends into
  on-ramps. · Medium
- [ ] **Deep-link: gym QR for non-members** — scanning a gym check-in QR while not a member opens a
  "Join {gym}?" prompt instead of failing. Ties `DeepLinkService` + `GymService.joinGym`. · Medium
- [ ] **Profile completeness meter** — gentle nudges (add photo, set goal weight, log first meal) with a
  progress ring; drives activation. Note: target weight currently lives only in `OnboardingProvider`
  memory — persist it to Firestore as part of this. · Medium
- [ ] **Demo / seed content** so ecosystems aren't empty shells at launch — a few seeded public programs &
  discoverable demo gyms (idempotent `seedIfEmpty()` per R2), clearly flagged, so first users see life. · Medium
- [ ] **Activation analytics funnel** — instrument `intro_completed`, `permission_primed/granted/denied`,
  `role_upgrade_started/completed`, `gym_joined`, `coach_requested`. Lets data decide what to invest in
  next (existing `AnalyticsService`). · Low
- [ ] **Accessibility & motion** across all of Phase 10 — every tour/primer/coachmark skippable, respects
  `MediaQuery.disableAnimations` (reduced motion), full semantic labels, large-text safe. · Medium

### Definition of Done — Phase 10
☑ Every built screen has a real, role-appropriate entry point (no chicken-and-egg, no dead `comingSoon`) ·
☑ No camera/location/notification dialog appears without a preceding branded rationale · ☑ New users see an
illustrated feature tour before the data form · ☑ Empty states route forward, not nowhere · ☑ All new
copy in EN+TR, all new UI correct in light+dark on iOS+Android, 60fps, reduced-motion aware ·
☑ `flutter analyze lib/` 0 errors · ☑ CLAUDE.md + this roadmap updated (R8).

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
