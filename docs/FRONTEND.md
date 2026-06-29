# FRONTEND.md — Screens, Navigation & Routing

> Map of all 95 screens, the navigation system, and routing. Before editing a screen, find it
> here to know its route, services, and notable UX. Build UI with `docs/DESIGN_SYSTEM.md` tokens.
> Owners: `lib/screens/**`, `lib/main.dart`, `lib/core/utils/app_routes.dart`,
> `lib/core/services/route_configuration_service.dart`.

---

## 1. Navigation & Routing System

- **Entry:** `main.dart` → `MyApp` (Firebase init, `MultiProvider`, `MaterialApp`). Initial route =
  `AppRoutes.splash` (`/`).
- **Route constants:** `lib/core/utils/app_routes.dart`. Named routes:
  `splash /` · `login` · `register` · `verifyEmail` · `forgotPassword` · `resetPassword` ·
  `intro` · `onboarding` · `priorityOnboarding` · `mealPlanGeneration` · `discover` ·
  `home` (legacy) · `main` (primary app root) · `chatList` · `chatDetail` (args ChatModel) ·
  `aiChat` (args String) · `nutritionAnalytics` · `mealPlanHistory` · `favorites` · `userSearch` ·
  `streakSquads`.
- **Route config:** `RouteConfigurationService` (singleton) — `getRoutes()` map; every route
  **except `intro`** is wrapped in **`RouteGuard`**. Typed args extracted for `aiChat`/`chatDetail`.
  Unknown route → `UnknownRouteScreen`.
- **RouteGuard** (`lib/core/utils/route_guard.dart`) checks in order: **ban** (real-time
  `AdminStatusService`) → auth init → logged-out redirect → logged-in redirect → **email verified**
  → **onboarding completed**. Uses cached `UserProvider` state (no per-route Firestore calls).
- **Observers:** `BanCheckNavigatorObserver`, `FirebaseAnalyticsObserver`, `LoggingNavigatorObserver`.
- **Transitions** (`ds/app_transitions.dart`): `slideUp` (detail/modal, 360/280ms), `slideRight`
  (forward flow), `fade` (sibling tabs), `fadeScale` (dialog→fullscreen). All 60fps, no overshoot.
- **Profile nav:** `openUserProfile(context, userId|user)` / `ProfileLink` — standard avatar/name tap;
  self → own editable profile, else public profile (slideUp).

---

## 2. Entry & Onboarding

| Screen | File | Route | Notes |
|---|---|---|---|
| Splash | `splash_screen.dart` | `/` | Orchestrates `AppInitializationService`; staggered logo animation; ≥5s min; ATT request; fire-and-forget preloads; offline banner + retry |
| Login | `auth/login_screen.dart` | `login` | Email/password + Google; live password validation |
| Register | `auth/register_screen.dart` | `register` | Email/pass + confirm; two-tier consent — required Terms/Privacy + required **essential data consent** (health/AI/transfer) + optional opt-in (analytics, marketing); records via `ConsentService.recordInitialConsents` on success |
| Verify Email | `auth/verify_email.dart` | `verifyEmail` | 5s poll, 180s resend cooldown |
| Forgot/Reset Password | `auth/forgot_password_screen.dart` | `forgotPassword` | Email reset link |
| Account Suspended | `auth/account_suspended_screen.dart` | (guard) | Ban screen w/ appeal |
| Intro Tour | `onboarding/intro_onboarding_screen.dart` | `intro` | 5-page feature carousel; replayable from settings |
| Onboarding | `onboarding/onboarding_screen.dart` (+ `steps/`) | `onboarding` | 6-step form; gap-recovery via `initialStep`; per-step screen-time analytics |
| Priority Onboarding | `onboarding/priority_onboarding_screen.dart` | `priorityOnboarding` | Fast 2-step (goals + activity) |
| Meal Plan Generation | `onboarding/meal_plan_generation_screen.dart` | `mealPlanGeneration` | 6-stage animated interstitial (~4.5s), elastic success |

**Onboarding split:** `OnboardingProvider` writes non-PII to public `onboarding_data` and PII
(personal_info, allergies, dietary_restrictions, disliked_foods) to `users/{uid}/private/nutrition`.

---

## 3. Main Hub
- **MainScaffold** `main_scaffold.dart` (route `main`) — `IndexedStack` of 3 tabs (Home/Community/
  Profile) for instant switching; `QuickActionsSheet` bottom bar; `SideMenu` drawer (Offstage,
  zero-rebuild); `VoiceAssistantOverlay`; mesh-glow background. PopScope: close menu → Home → exit.
  Shows "What's New" 800ms after render. Reads `NavigationProvider`.
- **SideMenu** `core/widgets/side_menu.dart` — role-aware: builds Admin/Coach/Gym/Consumer cards from
  `user.hasRole(...)`; pending-count badge (`AdminService.pendingCountStream`); status-aware
  apply/pending/rejected CTAs for becoming coach/gym owner.

---

## 4. Home Tab
| Screen | File | Route | Notes |
|---|---|---|---|
| Home | `home/home.dart` (~1860 LOC) | tab 0 | Core screen: today summary (calorie ring, macros, water), weekly meal plan carousel, meal breakdown, AI insight card, role quick card, exercise log, quick-add sheet, custom glass pull-to-refresh, streak banner, coachmark tips, shareable fitness card. Real-time food/exercise streams. |
| Nutrition Analytics | `home/nutrition_analytics_screen.dart` | `nutritionAnalytics` | Animated 7-day bar chart, macro %, goal adherence; `CalorieCalculator` BMR/TDEE |
| Meal Plan History | `home/meal_plan_history_screen.dart` | `mealPlanHistory` | Past plans, restore dialog, pagination |
| Food Scan | `home/food_scan_screen.dart` | — | AI nutrition estimate from description → log |
| Barcode Scan | `home/barcode_scan_screen.dart` | — | `mobile_scanner` → product lookup → log |

## 5. Community Tab
| Screen | File | Route | Notes |
|---|---|---|---|
| Community | `community/community_screen.dart` | tab 1 | Feed; filters (Latest/Global/Friends/Following/Gym/Saved); topic chips; weekly highlights; `GlassPostCard`; filter-aware pagination |
| Post Detail | `community/post_detail_screen.dart` (~1650 LOC) | push (postId) | Full-screen image carousel (pinch-zoom), comments stream, draggable reactions, inline edit |
| User Search | `community/user_search_screen.dart` | `userSearch` | Debounced (400ms) friend search + status |
| Streak Squads | `community/streak_squad_screen.dart` | `streakSquads` | Create/join squads, leaderboard, mesh-glow |

## 6. Profile Tab
| Screen | File | Route | Notes |
|---|---|---|---|
| Profile | `profile/profile_screen.dart` (~2400 LOC) | tab 2 | Self (editable) vs public (privacy-gated) modes; avatar/bio edit; body metrics; stats; reputation; friend/follow; completeness card |
| Settings | `profile/settings_screen.dart` (~2000 LOC) | push | Language sheet (EN/TR), theme, notif group mutes, privacy toggle, data export, referral, support, version, admin link, replay intro, logout |
| Dietary Preferences | `profile/dietary_preferences_screen.dart` | push | Restrictions/allergies/avoid multi-select |
| Affiliate Earnings | `profile/affiliate_earnings_screen.dart` | push | Earnings summary, payout request, history (tracking layer) |
| Consent Center | `profile/consent_center_screen.dart` | push (Settings → Privacy & Consents) | Per-purpose grant/withdraw toggles (health/location/AI/transfer/analytics/notifications/marketing); records versioned consent via `ConsentService`; stale "needs review" badge on policy bump; links to legal docs. KVKK/GDPR accountability |
| Privacy Requests (DSAR) | `profile/privacy_request_screen.dart` | push (Settings → Privacy Requests) | File a data-subject request (access/rectify/erase/restrict/object/portability/withdraw/other) + track status. Admin: `admin/admin_privacy_requests_screen.dart` (side menu). First-run nudge: `profile/widgets/consent_prompt_sheet.dart` |

## 7. Recipe / Shopping / Explore
| Screen | File | Notes |
|---|---|---|
| Recipe Detail | `recipe/recipe_detail_screen.dart` | Sliver hero image, glass nutrition card, ingredients/instructions tabs, favorite/share/cook |
| Cooking Mode | `recipe/cooking_mode_screen.dart` | Full-screen step pager, timer, wakelock, finish→log |
| Favorites | `recipe/favorites_screen.dart` (route `favorites`) | Saved recipes; also embedded in Explore |
| Shopping List | `shopping/shopping_list_screen.dart` | Checklist, cloud sync, generate-from-plan, share |
| Explore | `explore/explore_screen.dart` | Recipe browse + AI generation (credit-gated), Browse/Favorites tabs |

## 8. AI / Chat / Notifications / Misc
| Screen | File | Route | Notes |
|---|---|---|---|
| AI Chat | `chat/ai_chat_screen.dart` | `aiChat` | Nutrition coach chat, credit-gated, typing indicator, history singleton |
| AI Fitness Twin | `ai/ai_fitness_twin_screen.dart` | push | 30/60/90-day projection; credit-gated; fade reveal |
| Chat List | `chat/chat_list_screen.dart` | `chatList` | DM/group filters, power FAB (4 actions), search |
| Chat Detail | `chat/chat_detail_screen.dart` | `chatDetail` | Messages, typing, image send, read status |
| Notifications | `notifications/notification_screen.dart` | push | Filtered, paginated, auto-mark-read, glass refresh |
| Leaderboard | `leaderboard/leaderboard_screen.dart` | push | Global/Friends tabs, current-user highlight |
| Discover Hub | `discover/discover_hub_screen.dart` | `discover` | 2×2 grid (Gym/Coach/Programs/Leaderboard) + premium banner |
| Legal | `legal/legal_screen.dart` | push (type) | Renders 4 docs (Privacy / Terms / KVKK Aydınlatma / Açık Rıza) from localized `assets/legal/*.md` via a dependency-free markdown renderer; EN+TR. See `docs/COMPLIANCE.md` §8 |
| Generic Error | `common/generic_error_screen.dart` | — | Error boundary fallback |

---

## 9. Business & Admin (role-gated)

### Gym (`screens/gym/`) — role: gymOwner / member / consumer-applying
| Screen | Purpose | Role |
|---|---|---|
| `gym_dashboard_screen.dart` | Setup CTA or active dashboard (stats grid, 6 quick actions, weekly attendance chart) | gymOwner |
| `gym_setup_screen.dart` (~1880 LOC) | Create/edit gym (name, location, tags, logo, brand color) | gymOwner |
| `gym_members_screen.dart` | Member list + details | gymOwner |
| `gym_discovery_screen.dart` (~1280 LOC) | Browse gyms; city/district/sort filters | all |
| `gym_community_screen.dart` | Gym-scoped feed (brand-colored) | owner/member |
| `gym_qr_screen.dart` | Display/share check-in QR | gymOwner |
| `gym_leaderboard_screen.dart` (~1320 LOC) | Member rankings | owner/member |
| `gym_analytics_screen.dart` | Active members, peak hours, retention (self-resolves owner gym) | gymOwner |
| `gym_member_home_screen.dart` | Member view (announcements, challenges) | member |
| `gym_checkin_screen.dart` | QR scan check-in | member |
| `gym_application_pending_screen.dart` | Application status | consumer-applying |
| `gym_join_prompt_sheet.dart` | Join prompt on QR scan (`GymJoinPromptSheet.show`) | non-member |

### Coach (`screens/coach/`) — role: coach / consumer-applying
| Screen | Purpose | Role |
|---|---|---|
| `coach_dashboard_screen.dart` | Setup CTA or dashboard (client stats, at-risk, active) | coach |
| `coach_application_screen.dart` (~1135 LOC) | Multi-step apply (specializations, certs, references) | consumer |
| `coach_application_pending_screen.dart` | Status (pending/approved/rejected/needsMoreInfo) | consumer |
| `coach_profile_setup_screen.dart` | Profile completion (2-step) | coach |
| `coach_profile_screen.dart` | Public profile (rating, reviews, programs) | all |
| `coach_discovery_screen.dart` (~1270 LOC) | Browse coaches; Top Coaches/Rising Stars; filters; rank badges | all |
| `coach_clients_screen.dart` | Client roster (active/pending/completed) | coach |
| `coach_client_detail_screen.dart` | Client workspace (progress, logs, AI report, rate coach) | coach |

### Programs (`screens/programs/`)
| Screen | Purpose | Role |
|---|---|---|
| `program_marketplace_screen.dart` | Browse approved programs, category filter | all |
| `my_programs_screen.dart` | Coach library (draft/published/archived) | coach |
| `program_detail_screen.dart` | Weeks/sessions, enroll (free) or paid-coming-soon banner, reviews | all |

### Admin (`screens/admin/`) — role: admin
- **AdminPanelScreen** `admin_panel_screen.dart` (~4770 LOC) — 13-tab control center:
  0. **Dashboard** — 2×2 live stat grid + weekly activity chart + quick access (`pendingCountStream`, `userCountStream`, `openReportCountStream`)
  1. **Coach Applications** — pending list → `ApplicationReviewScreen.forCoach`
  2. **Gym Applications** — pending list → `ApplicationReviewScreen.forGym`
  3. **Users** — CTA → `AdminUserManagementScreen`
  4. **History** — coach/gym approved/rejected filters
  5. **Audit Log** — `auditLogStream`
  6. **Broadcasts** — compose (audience, EN+TR, schedule) + history (`sendBroadcast`)
  7. **Config** — maintenance, min version, AI model/proxy, feature flags, blocked keywords (`updateAdminConfig`)
  8. **Credits & Codes** — grant bonus credits (user search), referral oversight/void
  9. **Programs** — pending review (approve/reject) + history
  10. **Billing** — premium count, estimated MRR, subscriber list (`premiumUsersStream`)
  11. **Abuse** — banned users (unban) + top AI users (quota bars; red if ≥2× limit)
  12. **Analytics** — KPI grid + animated role distribution + top-5 AI (`fetchAnalyticsSnapshot`)
- **ApplicationReviewScreen** `application_review_screen.dart` — glass-polished review; approve/reject
  with notes; doc links; audit + notification on action. `.forCoach()` / `.forGym()`.
- **AdminUserManagementScreen** — search, ban/unban, set role, force logout, password reset, data stats.
- **AdminReportsScreen** — moderation queue (pending/reviewed; dismiss/remove; bulk).
- **AdminDishesScreen** — dish DB CRUD + re-seed.

**Role flow:** consumer applies (`coach_applications`/`gym_applications`) → admin reviews in panel
→ approve adds role to `userRoles` + creates `coach_profiles`/`gyms` doc + audit + notification →
`UserProvider` live listener flips menus/gates **without restart**.

---

## 10. Shared UX Patterns (all screens)
- **States:** loading = `AppShimmer`/`AppSkeleton*`; empty = `AppEmptyState`; error =
  `AppErrorState(title, onRetry)`; never a bare spinner.
- **Streams:** `StreamBuilder` → waiting=skeleton, hasError=error state, data=content.
- **Sheets:** `AppSheet.show()`. **Cards:** `AppCard`/`AppGlassCard`. **Buttons:** `AppButton`.
- **Performance:** `RepaintBoundary` on heavy list items (community posts, favorites, day selector,
  admin stat grid, coach/gym lists).
- **Responsive:** `flutter_screenutil` (`.r/.w/.h/.sp`).
