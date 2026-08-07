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
  `home` (legacy) · `main` (primary app root) · `chatList` · `chatDetail` (args `ChatModel` **or**
  `String` chat id — Faz 0 §0.4) · `aiChat` (args String) · `nutritionAnalytics` · `mealPlanHistory` ·
  `favorites` · `userSearch` · `streakSquads`.
- **Route config:** `RouteConfigurationService` (singleton) — `getRoutes()` map; every route
  **except `intro`** is wrapped in **`RouteGuard`**. Typed args extracted for `aiChat`/`chatDetail`.
  `chatDetail` branches on the argument's runtime type: a `ChatModel` (every in-app navigation) goes
  straight to `ChatDetailScreen`, zero extra fetch; a bare `String` (only a push notification's data
  payload carries this — it has no `ChatModel` to hand over) is resolved through
  `_ChatDetailByIdLoader`, a small private `StreamBuilder` wrapper over `ChatService().getChat(id)`
  with its own skeleton/error states, defined in the same file. Unknown route → `UnknownRouteScreen`.
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
| Community | `community/community_screen.dart` | tab 1 | `ActiveGroupsSection` (Faz 2 §2.5 — most-active-today + city strip, replaces the old dead `getGroups()`-backed carousel) directly below the header; feed filters (Latest/Global/Friends/Following/Gym/Saved); topic chips; weekly highlights; `GlassPostCard`; filter-aware pagination |
| Group Members | `community/groups/group_members_screen.dart` | push (groupId), from `GroupDetailScreen`'s people-icon action | Faz 2 §2.6: member list; owner/group-admin/site-admin kick/ban/mute/unmute/unban (reason prompt, mute duration chips) + moderation-history sheet + premium CSV export (`Entitlements.exportData`, Faz 5 §5.4). "Pending requests" section (this task) — Approve/Decline cards on `CommunityGroupService.getPendingJoinRequestsStream`/`approveJoinRequest`/`declineJoinRequest`, shown only when the group's `join_policy == 'request'` — was the last unwired piece of that flow; `GroupDetailScreen`'s Join button already handles the requesting side |
| Group Info | `community/groups/group_info_screen.dart` (new, Chat Upgrade Faz 5) | push (groupId) — from `GroupDetailScreen`'s app bar AND from tapping the group name/photo in `ChatDetailScreen`'s own header (the WhatsApp header gesture) | Cover image/name/member count/description/creation date/creator, link to Group Members, admin list, shared-media preview (`ChatService.getChatMediaPage`) + "view all" → `MediaGalleryScreen`, mute-notifications toggle, and a real (non-footnote) chat-security disclosure section stating plainly: TLS + AES-256 at rest, **no end-to-end encryption**, because server-side moderation needs to read message content |
| Post Detail | `community/post_detail_screen.dart` (~1650 LOC) | push (postId) | Full-screen image carousel (pinch-zoom), comments stream, draggable reactions, inline edit |
| User Search | `community/user_search_screen.dart` | `userSearch` | Debounced (400ms) friend search + status |
| Streak Squads | `community/streak_squad_screen.dart` | `streakSquads` | Create/join squads, leaderboard, mesh-glow |

## 6. Profile Tab
| Screen | File | Route | Notes |
|---|---|---|---|
| Profile | `profile/profile_screen.dart` (~2400 LOC) | tab 2 | Self (editable) vs public (privacy-gated) modes; avatar/bio edit; body metrics; stats; reputation; friend/follow; completeness card |
| Settings | `profile/settings_screen.dart` (~2000 LOC) | push | Language sheet (EN/TR), theme, notif group mutes, privacy toggle, data export, referral, support, version, admin link, replay intro, logout, **manage devices entry (Chat Upgrade Faz 1)** |
| Device Management | `profile/device_management_screen.dart` (new, Faz 1) | `deviceManagement` | Every device signed in (`DeviceRegistryService.watchMyDevices`), "this device" badge, last-seen, per-device sign-out + "sign out all others" (both go through the `revokeDevice` callable) |
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
| Chat List | `chat/chat_list_screen.dart` | `chatList` | Faz 2 §2.4 rebuild: segmented filter (All/Groups/Gym/DM via `ChatListSegment`, `AppFilterBar`) + independent Unread toggle, search (name + `lastMessage.body`, client-side over the loaded set), pin/archive/mute (per-user `chat_prefs`, pinned-first sort), swipe-to-archive (`Dismissible`, endToStart, toggle-then-snap-back), long-press action sheet (pin/archive/mute/delete), "Archived (N)" entry sheet, delete-for-me (hides until new activity reopens it). Filtering/sorting is the pure, unit-tested `ChatListFilter.apply`. Power FAB (4 actions) unchanged. Every string localized; the old hardcoded demo cards (Faz 0 §0.7) stay gone |
| Chat Detail | `chat/chat_detail_screen.dart` | `chatDetail` | Faz 2 §2.2 rebuild on `lib/core/widgets/ds/chat/` components: cursor-paginated history (`ChatService.getMessagesPage`, live stream + "load more" on scroll), long-press context menu (reply/forward/copy/react/pin/star/edit/delete/report), swipe-to-reply, pinned-message banner, @mention autocomplete, multi-image attach (camera + `pickMultiImage`), in-chat search (bounded 300-message client-side scan), jump-to-date (`getMessagesAround`), group typing indicator (bounded name resolution), reduced-motion + haptics throughout. **Faz 0 §0.2/§0.3**: send is now optimistic — the composer clears synchronously and the send fires unawaited, relying on Firestore's own offline mutation queue rather than a hand-rolled one; a hard-rejected send renders as a synthetic, retryable "failed" bubble (`ChatMessageMerge`) with a reduced long-press menu (retry/delete only); each bubble's tick now reflects a real `MessageSendState` (sending/sent/delivered/read/failed) via `MessageStatusResolver` instead of a delivered/read bool pair with no "sending" or "failed" state at all. **Faz 0 §0.4**: registers itself with `ActiveChatTracker` on open/close so a push for the chat you're already viewing doesn't also bark a local notification. **Chat Upgrade Faz 6**: press-and-hold the composer's mic button (shown in place of send whenever the text field is empty) to record a voice note — slide left to cancel, slide up to lock hands-free, waveform + elapsed timer live via `AppVoiceRecorder`; a received voice message renders via `AppVoicePlayer` (play/pause, static waveform from the sender's own recorded peaks, 1x/1.5x/2x speed) backed by the app-wide `VoicePlaybackService`. **Faz 5**: tapping the group name/photo in the app bar opens `GroupInfoScreen`; sent images now also populate a thumbnail (`StorageUploadService.uploadChatImage`'s new `thumbUrl`/`width`/`height`). **Faz 7**: message bodies now linkify `http(s)://`/`www.` URLs (tap-to-open only, no unfurl/preview — `AppMessageBubble.buildMentionSpans`); an empty search result now repeats the "searching your most recent messages" caveat instead of reading as a flat "not found" |
| Media Gallery | `chat/widgets/media_gallery_screen.dart` | push (from Chat Detail "···") | Faz 2 §2.2 — every image ever sent in a chat, cursor-paginated via the `messages(type,timestamp)` composite index (not just whatever's loaded in the main view); full-screen pinch-zoom viewer |
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
| `gym_dashboard_screen.dart` | Setup CTA or active dashboard (stats grid, 7 quick actions incl. meal-plan templates behind `FeatureFlags.mealPlanTemplates`, weekly attendance chart) | gymOwner |
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
| `coach_dashboard_screen.dart` | Setup CTA or dashboard (client stats, at-risk, active; meal-plan templates action behind `FeatureFlags.mealPlanTemplates`) | coach |
| `coach_application_screen.dart` (~1135 LOC) | Multi-step apply (specializations, certs, references) | consumer |
| `coach_application_pending_screen.dart` | Status (pending/approved/rejected/needsMoreInfo) | consumer |
| `coach_profile_setup_screen.dart` | Profile completion (2-step) | coach |
| `coach_profile_screen.dart` | Public profile (rating, reviews, programs) | all |
| `coach_discovery_screen.dart` (~1270 LOC) | Browse coaches; Top Coaches/Rising Stars; filters; rank badges | all |
| `coach_clients_screen.dart` | Client roster (active/pending/completed) | coach |
| `coach_client_detail_screen.dart` | Client workspace (progress, logs, AI report, rate coach) | coach |

### Meal plan templates (`screens/meal_plan_templates/`) — Faz 3 §3.3, role: gym/coach
Reached from the gym/coach dashboards above (both gated by the same
`FeatureFlags.mealPlanTemplates`, independent of `gym`/`coach` themselves so template generation can be
killed without taking down either dashboard).

| Screen | Purpose | Role |
|---|---|---|
| `template_library_screen.dart` | Search/tag-filter the author's own `meal_plan_templates`; duplicate/export/delete; "+" opens the creator | gym/coach |
| `template_creator_screen.dart` | ONE screen, 3 creation paths (AI-generate / from scratch / fork existing) that all converge into the same live editor: details form, day tabs w/ copy-paste, `TemplateNutritionPanel`, `TemplateAllergenPanel`, `TemplateDayEditor` | gym/coach |
| `widgets/template_day_editor.dart` | One day's breakfast/lunch/dinner/snack sections; add/remove/replace via `DishPickerSheet`; reorder within a section via `ReorderableListView.onReorderItem` | — |
| `widgets/dish_picker_sheet.dart` | Client-side dish search (name/category/tags) + free-text custom-food entry | — |
| `widgets/template_nutrition_panel.dart` | Day/week toggle over `AppCalorieRing` + macro bars + `PlanNutritionCalculator.classifyDeviation`-driven colored badge | — |
| `widgets/template_allergen_panel.dart` | Red-warning banner via `AllergenSafety`, checked against the signed-in author's own profile only — see the file's doc comment for why a per-member preview picker was investigated and NOT built (the data it would need lives in the owner-only `private/nutrition`, with no admin/coach override and no Faz 4 consent gate yet) | — |
| `widgets/template_source_picker_sheet.dart` | Fork source picker: Mine / My gym's shared pool / Public, backed by `MealPlanTemplateService`'s three query shapes | — |

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
