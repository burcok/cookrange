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
| 🚧 Home dashboard | Real calculated targets + real weekly meal-plan section | **Consumed calories hardcoded `1350`** (`home.dart:477`); streak not surfaced; `_loadHydration()` empty (`home.dart:71`); a non-localized "Regenerate" string |
| 🚧 AI integration | Real OpenRouter client + 3 working features + robust response parsing | **Committed `.env` key is a placeholder** → all AI dead until real key added; fragile unguarded JSON casts; failures swallowed → `null`; single free model, no retry |
| 🚧 Cooking mode | Step-by-step PageView + wakelock + progress ring | Timer is a generic stopwatch, **not step-aware**; "Finish" is a no-op `// TODO` (`cooking_mode_screen.dart:219`); no completion logging |
| 🚧 Shopping list | Local Hive persistence, add/remove/clear, swipe-delete | **Not auto-generated from meal plan**; share button stub; check-state not persisted; local-only (no Firestore sync) |
| 🚧 Profile screen | Rich read-only display (online status, friends, goals) | **Edit has no persistence path**; avatar `onTap: () {}` (`profile_screen.dart:494`); fake stats (`"2"` posts, `"12K"` score); fake report/block |
| 🚧 Settings screen | Dark-mode toggle + color picker + EN/TR work | Privacy toggle stub; notifications/about/help dead rows; premium card dead button; **no account deletion**; change email/password not exposed |
| 🚧 Community feed | All CRUD real | **Image upload fake (random Unsplash)**; no pagination (20 cap); filters cosmetic; report stub; groups stub |
| 🚧 Chat | 1:1 fully real | Group chat is model-only (no creation path); image messages model-only; mock "gym" chat in dead code |
| 🚧 Notifications screen | In-app DB notifications render | Uses one-shot FutureBuilder (no live update); no pagination; **no push/FCM at all** |
| 🚧 Account suspended screen | Polished 889-LOC UI + mailto support | Shows **no real ban data** (static strings); appeal modal is informational-only |
| 🚧 Dark mode | Both themes fully defined | `main_scaffold.dart:113` hardcodes light bg; default is light; effectively **light-only in practice** |
| 🚧 Offline support | Firestore SDK disk cache + 1 cache-source fallback | **No real sync, no write queue/retry, no connectivity-driven UI**; `connectivity_plus` only one-shot |
| 🚧 Error handling | Crashlytics logging works; typed handlers | App-wide error boundary **broken & not wired**; triple `FlutterError.onError` collision |
| 🚧 Navigation | Custom PageView + side menu + quick-actions sheet | Only 2 real tabs (Home + Community); Profile is a pushed-route hack; no standard nav bar |
| 🚧 Voice assistant | Speech-to-text capture works (overlay, visualizer) | **Transcript is discarded** — never sent to AI (`voice_assistant_overlay.dart:397`); a non-functional demo |

### 🟡 Stubs / 📋 Planned-only (skeletons with no real logic)
- 🟡 **Premium card** — styled CTA, `onPressed: () {}` (`settings_screen.dart:441`)
- 🟡 **Priority onboarding screen** — 20-line placeholder, but routed
- 🟡 **Weight tracking** — Hive storage layer exists (`storage_service.dart:67`), **zero UI**, `WeightLog` model is dead code
- 🟡 **Hydration tracking** — storage exists, never wired
- 🟡 **"Remote Config"** — actually reads Firestore `settings/global` (no `firebase_remote_config` dep)

---

## 🔥 MVP BLOCKERS (must fix before any public beta)

These are non-negotiable. Nothing ships to real users until these are done.

| # | Blocker | Why it blocks | Priority | Complexity | Est. | Version |
|---|---|---|---|---|---|---|
| B1 | 🔥 **Firestore + Storage security rules** (version-controlled, deny-by-default, owner/role scoped, tested with emulator) | App writes user/chat/community data with no rules → data breach & abuse risk | Critical | Large | 4–6 d | v0.5.0 |
| B2 | 🔥 **Real AI key management** — remove placeholder, move key server-side (proxy/Cloud Function) so it's never in the client bundle | All AI features dead today; embedding a real key in `.env`/client is a leak risk | Critical | Medium | 3–4 d | v0.5.0 |
| B3 | 🔥 **Food / calorie logging** (log meals → real consumed calories/macros on dashboard) | Core product loop is missing; dashboard number is hardcoded | Critical | Large | 6–9 d | v0.6.0 |
| B4 | 🔥 **Image upload via Firebase Storage** (profile avatar + community posts) | "Photo" posts are random stock images; profile avatar dead | Critical | Medium | 3–5 d | v0.6.0 |
| B5 | 🔥 **Push notifications (FCM)** + local notifications | No re-engagement; chat/friend/community events never reach users | Critical | Large | 5–7 d | v0.6.0 |
| B6 | 🔥 **Account deletion + data export** (in-app) | App Store rejection + GDPR/CCPA legal requirement | Critical | Medium | 3–4 d | v0.5.0 |
| B7 | 🔥 **Apple Sign-In** | App Store requires it when other social login exists | Critical | Medium | 2–3 d | v0.5.0 |
| B8 | 🔥 **Profile edit persistence** (wire existing `updateUserProfile`) | Users can't change their own data | High | Small | 1–2 d | v0.6.0 |
| B9 | 🔥 **AI robustness** — JSON schema validation, retries, graceful failure UI | Single malformed LLM response throws/blanks the core feature | High | Medium | 2–4 d | v0.6.0 |
| B10 | 🔥 **Pagination** on feed/chat/notifications/comments | Lists hard-capped (20/50); breaks at modest scale | High | Medium | 3–4 d | v0.7.0 |
| B11 | 🔥 **Dark-mode correctness** (remove hardcoded light backgrounds) | Half-shipped dark mode looks broken | Medium | Medium | 2–3 d | v0.7.0 |
| B12 | 🔥 **Legal: real Privacy Policy + Terms** (register gate ships placeholder text) | Required for stores; consent gate has "text will go here" | Critical | Small | 1–2 d + legal | v0.5.0 |
| B13 | 🔥 **CI pipeline** (`flutter analyze` + `flutter test` + build on PR) | No safety net; regressions ship silently | High | Medium | 2–3 d | v0.5.0 |

**MVP-blocker total: ~6–8 engineering weeks for a small team before a credible public beta.**

---

## PHASE 1 — FOUNDATION (Harden what exists) · target v0.5.0–v0.6.0

> Goal: make the existing app secure, observable, testable, and trustworthy. Most of this is *fixing*, not *building*.

**Architecture**
- [ ] Introduce a **repository layer** between providers and Firebase (providers currently call services/singletons directly). — High · Large · deps: none · 5–7 d · v0.6.0 · 📋 Planned
- [ ] Remove **duplicate provider factory** (`createProviders()` dead vs `createChangeNotifierProviders()`). — Medium · Small · 0.5 d · v0.5.0 · 🚧
- [ ] Fix **`AppLifecycleService` double-instantiation** (not a singleton; `main.dart` disposes an uninitialized instance). — High · Small · 0.5 d · v0.5.0 · 🚧
- [ ] Delete dead code: `MealPlan` model, `WeightLog` model, duplicate `onboarding_common_widgets.dart`, `_getDumpChats()`, commented mock data. — Medium · Small · 1 d · v0.5.0 · 🚧

**Authentication**
- [ ] Apple Sign-In (B7). — Critical · Medium · 2–3 d · v0.5.0 · ❌
- [ ] Expose change email/password in Settings (service methods exist). — Medium · Small · 1 d · v0.6.0 · 🚧
- [ ] Reduce `BanCheckObserver` Firestore reads (currently force-reads on every navigation). — Medium · Small · 1 d · v0.6.0 · 🚧

**Firebase**
- [ ] Add `firebase.json` + `.firebaserc` + emulator suite. — High · Small · 1 d · v0.5.0 · ❌
- [ ] Firestore + Storage **security rules** (B1). — Critical · Large · 4–6 d · v0.5.0 · ❌
- [ ] Add Firebase Storage dependency + upload service (B4). — Critical · Medium · 3–5 d · v0.6.0 · ❌
- [ ] Add real Remote Config (replace Firestore `settings/global` faux-config) for feature flags. — Medium · Small · 1–2 d · v0.6.0 · 🟡

**Navigation**
- [ ] Decide tab model: finish the 2-tab custom scaffold or adopt a standard nav bar; fix Profile-as-pushed-route hack. — Medium · Medium · 2–3 d · v0.6.0 · 🚧

**State Management**
- [ ] Consolidate state sources (Provider / SharedPreferences / Hive / Firestore) behind repositories. — High · Large · part of architecture item · v0.6.0 · 🚧
- [ ] Move `NavigationProvider` from `services/` to `providers/` for consistency. — Low · Small · 0.25 d · v0.6.0 · 🚧

**Caching / Offline**
- [ ] Decide scope: either implement real offline (local mirror + write queue + connectivity stream) or remove the offline scaffolding/strings. — Medium · Large · 5–8 d (if building) · v0.7.0 · 🚧
- [ ] Configure explicit Firestore persistence settings. — Low · Small · 0.25 d · v0.6.0 · 🚧

**Error Handling**
- [ ] Fix triple `FlutterError.onError` collision; single source of truth. — High · Small · 1 d · v0.5.0 · 🚧
- [ ] Wire a real app-wide error boundary into `MaterialApp.builder`. — High · Medium · 1–2 d · v0.6.0 · 🚧

**Analytics**
- [ ] Audit ~30 analytics events against a defined event taxonomy; ensure key funnels (onboarding, AI gen, post, subscribe) are tracked. — Medium · Medium · 2 d · v0.6.0 · 🚧
- [ ] Verify analytics fire in a release build (disabled in debug by design). — Medium · Small · 0.5 d · v0.5.0 · 🚧

**Monitoring**
- [ ] Add **Firebase Performance** (currently `performance_service.dart` is unused dead code, no backend). — Medium · Medium · 2 d · v0.7.0 · ❌
- [ ] Crashlytics custom keys (user tier, screen, AI model) for triage. — Low · Small · 0.5 d · v0.6.0 · 🚧

**Testing**
- [ ] Real test suite: unit tests for `CalorieCalculator`, `WeeklyMealPlanService` parsing, AI response parsing, streak logic. — High · Medium · 3–4 d · v0.6.0 · 🟡
- [ ] Widget tests for auth + onboarding + home (replace no-op `widget_test.dart`). — High · Medium · 3–4 d · v0.7.0 · 🟡
- [ ] Delete stale `test_output.txt`; move misplaced `*_test.dart` from `lib/` to `test/`. — Low · Small · 0.25 d · v0.5.0 · 🚧

**CI/CD**
- [ ] GitHub Actions / Codemagic: analyze + test + build on PR (B13). — High · Medium · 2–3 d · v0.5.0 · ❌
- [ ] Automated TestFlight / Play internal-track deploys. — Medium · Medium · 2–3 d · v0.7.0 · ❌

**Security**
- [ ] Move AI key off-device behind a proxy/Cloud Function (B2). — Critical · Medium · 3–4 d · v0.5.0 · ❌
- [ ] Restrict committed Firebase API keys in console (App Check, key restrictions). — High · Medium · 2 d · v0.6.0 · ❌
- [ ] Add **Firebase App Check** (abuse protection for Firestore/AI proxy). — High · Medium · 2 d · v0.7.0 · ❌

---

## PHASE 2 — CORE PRODUCT (Complete the nutrition app) · target v0.6.0–v0.7.0 (Beta)

> Goal: turn the planning app into a full tracking app. This is what makes Cookrange a real product people use daily.

**Onboarding**
- [ ] Replace `priority_onboarding_screen` stub with real fast-track or remove. — Medium · Small · 1 d · v0.6.0 · 🟡
- [ ] Add allergy/medical-flag safety step (currently only "disliked foods"). — Medium · Small · 1 d · v0.7.0 · 📋

**User Profiles**
- [ ] Promote nutrition fields out of untyped `onboardingData` map into a typed profile model. — High · Medium · 2–3 d · v0.6.0 · 🚧
- [ ] Wire profile edit + avatar upload (B8, B4). — Critical · Medium · 2–3 d · v0.6.0 · 🚧
- [ ] Replace fake profile stats with real counts. — Medium · Small · 1 d · v0.7.0 · 🚧

**Meal Planning**
- [ ] AI JSON schema enforcement + retry + graceful UI (B9). — High · Medium · 2–4 d · v0.6.0 · 🚧
- [ ] Per-meal swap/substitution ("no chicken today"). — High · Medium · 3–4 d · v0.7.0 · 📋
- [ ] Auto-seed dish DB on first run (currently a manual script). — Medium · Medium · 1–2 d · v0.6.0 · 🚧
- [ ] Better dish imagery (current sources partly random/non-matching). — Medium · Medium · 2 d · v0.7.0 · 🚧

**Nutrition Tracking**
- [ ] **Food/calorie diary** — log meals, real consumed calories/macros (B3). — Critical · Large · 6–9 d · v0.6.0 · ❌
- [ ] Weight logging UI + history + chart (storage layer already exists). — High · Medium · 3–4 d · v0.7.0 · 🟡
- [ ] Hydration tracking UI (storage exists, unwired). — Medium · Small · 1–2 d · v0.7.0 · 🟡
- [ ] "Mark meal as eaten" from plan/cooking-mode → feeds the diary. — High · Medium · 2 d · v0.7.0 · 🚧
- [ ] Nutrition analytics (trends, consistency score, weekly summary). — Medium · Medium · 3–4 d · v0.8.0 · ❌

**AI Assistant**
- [ ] Conversational AI chat ("what should I eat today?") — currently chat is human-to-human only. — High · Large · 5–7 d · v0.8.0 · ❌
- [ ] Nutrition analysis of arbitrary food / photo scan. — Medium · Large · 7–10 d · v0.9.0 · ❌

**Voice Features**
- [ ] Wire voice transcript → AI assistant (capture works, output discarded). — Medium · Medium · 2–3 d · v0.8.0 · 🟡

**Shopping Lists**
- [ ] Auto-generate consolidated list from the weekly meal plan. — High · Medium · 2–3 d · v0.7.0 · ❌
- [ ] Sync shopping list to Firestore (cross-device). — Medium · Small · 1 d · v0.7.0 · 🚧
- [ ] Persist checked state; implement share. — Low · Small · 1 d · v0.7.0 · 🟡

**Progress Tracking**
- [ ] Cooking-mode completion → log + celebration (currently no-op). — Medium · Small · 1 d · v0.7.0 · 🚧
- [ ] Daily goal completion + streak surfaced on home. — Medium · Medium · 2 d · v0.8.0 · 🚧

**Premium System (foundation)**
- [ ] Add `subscriptionTier`/entitlements to user model. — High · Small · 1 d · v0.8.0 · ❌
- [ ] Feature-gating framework (free vs premium limits). — High · Medium · 2–3 d · v0.8.0 · ❌

**Subscriptions**
- [ ] Integrate billing SDK (`in_app_purchase` or RevenueCat). — High · Large · 5–7 d · v1.0.0 · ❌
- [ ] Paywall UI behind the existing dead premium card. — High · Medium · 2–3 d · v1.0.0 · 🟡

---

## PHASE 3 — COMMUNITY (Polish & scale the social layer) · target v0.7.0–v0.8.0

> Goal: the social layer largely works; make it real (real photos, real reach, real-time, moderated).

- [ ] **Posts** — real image upload (depends B4); video later. — High · Medium · 2 d · v0.7.0 · 🚧
- [ ] **Comments** — pagination + real-time updates. — Medium · Medium · 2 d · v0.7.0 · 🚧
- [ ] **Likes / reactions** — already real; add notification fan-out. — Low · Small · 1 d · v0.7.0 · ✅→🚧
- [ ] **Feed pagination** (`startAfter` + load-more). — High · Medium · 2 d · v0.7.0 · ❌
- [ ] **Feed filters** make functional (Regional/Global/Friends/Gym currently cosmetic). — Medium · Medium · 2–3 d · v0.8.0 · 🟡
- [ ] **Report/moderation** — real reports collection + admin review + block enforcement. — High · Medium · 3–4 d · v0.8.0 · 🟡
- [ ] **Group chat** creation flow (model exists, no creation path). — Medium · Medium · 3–4 d · v0.8.0 · 🟡
- [ ] **Image messages** in chat (model exists). — Medium · Medium · 2 d · v0.8.0 · ❌
- [ ] **Notifications screen** → switch to live stream; add push (depends B5). — High · Small · 1 d · v0.7.0 · 🚧
- [ ] **Challenges** (community) — full feature: create/join/track. — High · Large · 6–8 d · v0.9.0 · ❌
- [ ] **Streaks** surfaced socially + milestones/rewards. — Medium · Medium · 2–3 d · v0.9.0 · 🚧
- [ ] **Leaderboards** (global/friends). — Medium · Large · 4–5 d · v0.9.0 · ❌
- [ ] **Reputation system** (community trust/score). — Low · Large · 5–7 d · v1.1.0 · ❌
- [ ] Recursive subcollection cleanup on post delete (Cloud Function). — Medium · Small · 1 d · v0.8.0 · 🚧
- [ ] Optimize `getFriendsStream` N+1 reads. — Low · Small · 1 d · v0.8.0 · 🚧

---

## PHASE 4 — GYM ECOSYSTEM (Core differentiator — greenfield) · target v1.1.0–v1.4.0

> Status: ❌ ~0% built (only `SignalType.gym_help` + a mock gym chat + a filter tab exist). This is the strategic moat — but it's a from-scratch build. **Do not start before the consumer MVP is validated.**

- [ ] **Gym data model + profiles** (entity, members, branches). — Critical · Large · 5–7 d · v1.1.0 · ❌
- [ ] **Gym onboarding** (gym signs up, configures). — High · Large · 5–7 d · v1.1.0 · ❌
- [ ] **Gym discovery** (search/join a gym). — High · Medium · 3–4 d · v1.1.0 · ❌
- [ ] **Gym communities** (per-gym feed/chat/announcements). — High · Large · 6–8 d · v1.2.0 · ❌
- [ ] **GPS presence / check-in** (needs `geolocator`/geofence SDK — none present). — High · Large · 7–10 d · v1.2.0 · ❌
- [ ] **Attendance tracking**. — Medium · Medium · 3–4 d · v1.2.0 · ❌
- [ ] **Gym leaderboards / "Gym Wars" competitions**. — Medium · Large · 6–8 d · v1.3.0 · ❌
- [ ] **Gym analytics dashboard** (retention, engagement). — Medium · Large · 7–10 d · v1.3.0 · ❌
- [ ] **White-label** (logo/colors/onboarding per gym). — Medium · Epic · 15–25 d · v1.4.0 · ❌

**Phase 4 realistic effort: 3–5 months for a dedicated squad.**

---

## PHASE 5 — COACH ECOSYSTEM (greenfield) · target v1.4.0–v1.6.0

> Status: ❌ 0% built (no role/coach fields anywhere; only flavor text in an AI prompt). Depends on premium (Phase 2) and gym (Phase 4) foundations.

- [ ] **Roles model** (user/coach/gym-admin) + permissions. — Critical · Medium · 3–4 d · v1.4.0 · ❌
- [ ] **Coach profiles**. — High · Medium · 3–4 d · v1.4.0 · ❌
- [ ] **Referral codes** (`AHMETFIT`-style) + attribution. — High · Medium · 3–5 d · v1.4.0 · ❌
- [ ] **Revenue sharing / commission** (depends payments). — High · Large · 6–8 d · v1.5.0 · ❌
- [ ] **Client management** (coach ↔ client linking, consent). — High · Large · 6–8 d · v1.5.0 · ❌
- [ ] **Coach dashboard** (adherence, consistency, progress). — High · Large · 7–10 d · v1.5.0 · ❌
- [ ] **AI-generated client reports/insights**. — Medium · Large · 7–10 d · v1.6.0 · ❌
- [ ] **Program marketplace** (sell plans/programs) — see Phase 7. — Medium · Epic · v1.6.0 · ❌

**Phase 5 realistic effort: 3–4 months.**

---

## PHASE 6 — AI INTELLIGENCE (greenfield) · target v1.7.0–v2.0.0

> Status: ❌ Entirely vapor today (zero code/stubs). Requires a real tracking-data history (Phase 2 food/weight logging) before any of it is meaningful.

- [ ] **AI Fitness Twin** (predict weight/fat/muscle/goal date). — High · Epic · 15–20 d · v1.7.0 · ❌
- [ ] **AI Accountability Partner** (proactive nudges). — High · Large · 8–10 d · v1.7.0 · ❌
- [ ] **AI Risk Detection** (drop-off / adherence decline → alerts). — High · Large · 8–10 d · v1.8.0 · ❌
- [ ] **AI Transformation Forecasting** (30/60/90-day projections). — Medium · Large · 7–10 d · v1.8.0 · ❌
- [ ] **AI Coach Assistant** (insights for coaches; depends Phase 5). — Medium · Large · 8–10 d · v1.9.0 · ❌
- [ ] **Behavioral analytics** pipeline (events → ML features). — Medium · Epic · 20–30 d · v2.0.0 · ❌

**Dependency note:** all of Phase 6 is only as good as the behavioral data collected — prioritize logging + analytics taxonomy first.

---

## PHASE 7 — MONETIZATION (greenfield) · premium in v1.0; rest v1.x

> Status: 📋/❌ — premium is a dead button; no billing SDK, no credits, no marketplace.

- [ ] **Premium** subscription (entitlements + paywall + billing). — Critical · Large · 7–10 d · v1.0.0 · 📋
- [ ] **AI credit system** (message limits, top-ups). — High · Large · 6–8 d · v1.2.0 · ❌
- [ ] **Program/plan marketplace** (coach-sold content, commission). — Medium · Epic · 15–20 d · v1.6.0 · ❌
- [ ] **Sponsored challenges**. — Low · Large · 6–8 d · v1.7.0 · ❌
- [ ] **Affiliate / referral commission** payouts. — Medium · Large · 6–8 d · v1.5.0 · ❌
- [ ] **Partner brands / supplement ecosystem**. — Low · Large · 8–10 d · v1.8.0 · ❌
- [ ] **Coach revenue sharing** (see Phase 5). — High · Large · v1.5.0 · ❌

---

## PHASE 8 — GROWTH · target v1.0.0+

- [ ] **Referral program** (invite → reward). — High · Medium · 3–4 d · v1.0.0 · ❌
- [ ] **Invite system** (contacts / deep links). — Medium · Medium · 3 d · v1.1.0 · ❌
- [ ] **Social sharing** (recipes, progress, plans). — Medium · Small · 2 d · v1.0.0 · 🟡 (share stubs exist)
- [ ] **Virality: shareable transformation reports / fitness-score cards**. — Medium · Large · 5–7 d · v1.2.0 · ❌
- [ ] **Community growth loops** (leaderboards/challenges as acquisition). — Medium · Medium · depends Phase 3 · v1.2.0 · ❌
- [ ] **Deep linking / App Links + Universal Links**. — Medium · Medium · 2–3 d · v1.0.0 · ❌

---

## PHASE 9 — SCALE & LAUNCH READINESS · ongoing, gates v1.0.0

- [ ] **Performance**: real Firebase Performance + frame/jank budgets. — High · Medium · 2–3 d · v0.9.0 · ❌
- [ ] **Caching**: real offline-first layer (if committed). — Medium · Large · 5–8 d · v0.9.0 · 🚧
- [ ] **Database optimization**: Firestore composite indexes (signals/feed already flagged), denormalization, read-cost audit. — High · Medium · 3–4 d · v0.9.0 · ❌
- [ ] **Security hardening**: App Check, key restriction, rules pen-test, dependency audit. — Critical · Medium · 3–4 d · v0.9.0 · ❌
- [ ] **Load testing** (Firestore/AI proxy under concurrency). — Medium · Medium · 2–3 d · v1.0.0 · ❌
- [ ] **Monitoring/alerting** (Crashlytics velocity, Cloud Monitoring dashboards). — Medium · Medium · 2 d · v1.0.0 · 🚧
- [ ] **Internationalization** beyond EN/TR (infra is ready; add locales). — Low · Medium · per-locale · v1.1.0 · 🚧
- [ ] **Accessibility** (semantics, contrast, dynamic type, screen-reader). — Medium · Medium · 3–4 d · v1.0.0 · ❌
- [ ] **GDPR/CCPA**: account deletion (B6), data export, consent records, retention policy. — Critical · Medium · 3–4 d · v0.9.0 · ❌
- [ ] **App Store readiness**: Apple Sign-In (B7), privacy nutrition labels, ATT, real legal docs (B12), store assets. — Critical · Medium · 3–5 d · v1.0.0 · ❌

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

| Severity | Debt | Location |
|---|---|---|
| 🔴 Critical | No version-controlled Firestore/Storage rules | repo root (absent) |
| 🔴 Critical | AI key placeholder; key belongs server-side, not client | `.env`, `ai_service.dart` |
| 🔴 Critical | Dashboard "consumed calories" hardcoded `1350` | `home.dart:477` |
| 🔴 Critical | Fake image upload (random Unsplash) | `create_post_card.dart:172` |
| 🟠 High | Triple `FlutterError.onError` collision; error boundary not wired | `crashlytics_service.dart:31`, `global_error_handler.dart:251` |
| 🟠 High | `AppLifecycleService` double-instantiation / disposes uninitialized instance | `main.dart:38,53` |
| 🟠 High | Fragile AI JSON parsing (unguarded casts, swallowed failures) | `weekly_meal_plan_service.dart:98` |
| 🟠 High | `BanCheckObserver` Firestore read on every navigation | `ban_check_observer.dart:41` |
| 🟡 Medium | Dead code: `MealPlan`, `WeightLog` models; duplicate onboarding widgets; dump chats | multiple |
| 🟡 Medium | Duplicate provider factories (one dead) | `provider_initialization_service.dart` |
| 🟡 Medium | Dark mode hardcoded light backgrounds | `main_scaffold.dart:113,171` |
| 🟡 Medium | `performance_service.dart` is unused dead code; no real perf backend | `performance_service.dart` |
| 🟡 Medium | Translations loaded from `lib/` (non-standard asset path) | `app_localizations.dart:50` |
| 🟡 Medium | No pagination anywhere (20/50 hard caps) | feed/chat/notifications |
| 🟢 Low | Stray `print()`/debug logging; non-localized "Regenerate"; signal preset uses raw key not `.translate()` | multiple, `signal_dialog.dart:116` |
| 🟢 Low | Stale `test_output.txt` (wrong machine path, dead test) | repo root |
| 🟢 Low | Misplaced `*_test.dart` files inside `lib/` | `lib/core/services/` |

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
