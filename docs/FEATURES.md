# FEATURES.md — Feature Catalog (what exists & where)

> The single answer to "does Cookrange already do X, and where is it?" If a capability is here,
> it's shipped. If it's not, check `docs/roadmap/FUTURE_FEATURES.md`. Keep this in sync when you
> ship or remove a user-facing capability.

Legend: ✅ shipped · 🟡 partial/tracking-only · 🔗 entry point

---

## Nutrition & Food
- ✅ **AI weekly meal plan** — `WeeklyMealPlanService`; hash-cached, allergy-validated, archived to
  history. 🔗 Home meal carousel, `meal_plan_history_screen`.
- ✅ **Food logging** — dish / generated recipe / AI-scanned description / quick-add / barcode.
  `FoodLogService`. 🔗 Home quick-add, `food_scan_screen`, `barcode_scan_screen`.
- ✅ **Recent & frequent foods** — `RecentFoodService` (Hive, ~20). 🔗 quick-add carousel.
- ✅ **Recipe DB** — seeded TR + intl dishes; favorites; notes; cooking mode (step pager + timer +
  wakelock). 🔗 `recipe_detail`, `cooking_mode`, `favorites`, Explore.
- ✅ **AI recipe generation** — credit-gated. 🔗 Explore.
- ✅ **Nutrition analytics** — 7-day bars, macros, adherence; BMR/TDEE via `CalorieCalculator`.
- ✅ **Shopping list** — checklist, cloud sync, generate-from-meal-plan, share. Calendar `.ics` export.
- ✅ **Hydration & weight tracking** — Home `TrackingCard` (Hive-backed).

## AI Intelligence
- ✅ **AI Chat coach** — profile-aware, credit-gated, voice-bridged history. 🔗 `ai_chat_screen`.
- ✅ **AI Fitness Twin** — 30/60/90-day projections, goal date, calorie gap, motivation score;
  persisted + history. 🔗 `ai_fitness_twin_screen`.
- ✅ **AI accountability insight** — daily home card (cached per day/locale).
- ✅ **AI risk detection** — client-side engagement risk (no AI call); risk banner on home.
- ✅ **Voice assistant** — `speech_to_text` overlay bridging into AI chat.
- ✅ **Server-side AI quota** — `aiProxy` Cloud Function (token+AppCheck, transaction quota, 402).
- ✅ **AI credits** — free 2/day, premium 20/day, IAP bonus top-ups; live badge + sheet.

## Social & Community
- ✅ **Community feed** — posts (text/recipe/progress/meal), reactions, comments, image carousel.
- ✅ **Filters & topics** — Global/Friends/Following/Gym/Saved + topic chips.
- ✅ **Friends & follow** — search, requests, following graph, weekly highlights.
- ✅ **@mentions** — autocomplete, highlight, notification fan-out.
- ✅ **Streak Squads** — group accountability, invite codes, leaderboard.
- ✅ **Signals** — ephemeral broadcasts (TTL).
- ✅ **Chat** — 1:1 + group, typing, image send, read status, system/gym chats.
- ✅ **Notifications** — structured + localized render (`NotificationPresenter`), per-group mutes,
  push fan-out (Cloud Functions).
- ✅ **Reputation** — badges/score from activity.
- ✅ **Moderation** — report content, blocked-keyword pre-screen, admin queue + bulk takedown.

## Gym Ecosystem
- ✅ **Gym profiles** — setup, brand color, verification badge, public/discovery.
- ✅ **Membership & check-in** — QR/GPS/manual; join prompt sheet.
- ✅ **Gym community feed** — brand-colored, announcements.
- ✅ **Gym leaderboard** — member rankings.
- ✅ **Gym analytics** — active members, peak hours, retention (owner).
- ✅ **Gym discovery** — city + optional district location filters; 4 sort options: **Highest Rated** (avg_rating), **Popular** (member_count, default), **Newest** (created_at), **Nearest** (near_me — Haversine, KVKK consent-gated, in-memory only). Redesigned filter bar: single-row full-text pills with VerticalDivider between location and sort. Map view (flutter_map/OSM) includes a horizontal gym list panel; tapping shows name, address, description, tags and "View Gym" CTA. 🔗 `gym_discovery_screen`.
- 🟡 **Gym Wars** — model + service exist; competition UI minimal.

## Coach Ecosystem
- ✅ **Coach profiles** — bio, specializations, certs, rates, reviews, verification, vanity code.
- ✅ **Coach application → admin approval → role flip**.
- ✅ **Coach discovery** — Top Coaches/Rising Stars, rank badges; 4 sort options: **Highest Rated** (avg_rating), **Popular** (client_count, default), **Newest** (created_at), **Nearest** (near_me — KVKK consent-gated); city + optional district location filters; same redesigned filter bar as gym. 🔗 `coach_discovery_screen`.
- ✅ **Client management** — link requests, roster, at-risk detection, client detail + AI report.
- ✅ **Coach reviews** — immutable, transaction-updated avg rating.

## Programs / Marketplace
- ✅ **Program marketplace** — browse approved, category filter, enroll (free), progress tracking.
- ✅ **Coach program authoring** — draft/publish; admin approval queue.
- 🟡 **Paid programs** — gated with honest roadmap banner; payment deferred (see roadmap).

## Monetization
- ✅ **Premium subscription** — `in_app_purchase` (monthly/yearly); paywall; entitlements/feature gates.
- ✅ **AI credit top-ups** — consumable IAP (`cookrange_ai_credits_10`).
- ✅ **Referral program** — 6-char codes, deep links, 7-day premium trial both sides.
- 🟡 **Affiliate/coach commissions** — tracking layer (`CommissionService`, earnings screen);
  payout processing deferred.

## Growth & Retention
- ✅ **Deep links** — universal + custom scheme (`cookrangeapp.com/{recipe|post|user|...}/{id}`).
- ✅ **Social sharing** — recipes, progress, posts, lists, referral; shareable fitness card (PNG).
- ✅ **Streaks** — daily streak + milestone banners.
- ✅ **Leaderboards** — global + friends.
- ✅ **"What's New"** — once-per-version changelog sheet.
- ✅ **Coachmark tips** — one-time contextual tooltips.
- ✅ **Profile completeness** — guided card.

## Admin & Ops
- ✅ **13-tab admin panel** — apps, users, history, audit, broadcasts, config, credits/codes,
  programs, billing, abuse, analytics (see `docs/FRONTEND.md` §9).
- ✅ **Remote App Config** — `app_config/global` drives AI models/limits, force + soft update gates
  (per-platform min/latest version, store URLs, i18n message), maintenance mode, announcement banner,
  feature kill-switches (default-ON), and % rollout — all without a redeploy; `aiProxy` reads the same
  doc server-side. Edited from `AdminAppConfigScreen`. 🔗 Admin → App Config.
- ✅ **Real AI cost tracking** — `aiProxy` logs per-request token usage × model price to
  `ai_usage_logs` / `ai_usage_stats`; `AdminCostAnalyticsScreen` shows actual AI spend (total
  cost/requests/tokens, by-model, by-type) + per-user usage lookup.
- ✅ **Feature flags / Remote Config** — maintenance mode, min version, AI model, blocked keywords.
- ✅ **Audit log** — append-only admin actions.
- ✅ **User management** — ban/unban, role, force logout, password reset.

## Platform & Compliance
- ✅ **EN/TR localization** — parity-gated. ✅ **Dark/Light** themes + live brand color.
- ✅ **iOS + Android** — Apple/Google sign-in, ATT consent, platform guards, safe areas, haptics.
- ✅ **KVKK + GDPR legal-first** — data export + account deletion; consent-gated sensitive data
  (health, location) with on-device/not-stored disclosures; data minimization. Framework:
  `docs/COMPLIANCE.md`. ✅ **In-app legal docs** (Privacy Policy, Terms, KVKK Aydınlatma Metni, Açık
  Rıza) drafted EN+TR (`assets/legal/`, lawyer-review pending). ✅ **Consent Center** (Settings →
  Privacy & Consents) — per-purpose, versioned, withdrawable consent records (`ConsentService`),
  captured at registration (two-tier: required essentials + optional opt-ins), managed/withdrawn in
  the center. ✅ **DSAR channel** (Settings → Privacy Requests; admin queue). ✅ **Age
  gating** (min 16, onboarding birth-date). ✅ **Breach runbook** + **transfer register** (COMPLIANCE
  §11–§12). 🟡 Per-purpose enforcement + marketplace payout terms (ship with payments).
  ✅ **Accessibility** — semantics, reduce-motion/transparency. ✅ **Security** — App Check, AI key
  proxied, full Firestore/Storage rules.
- ✅ **Monitoring** — Crashlytics, Performance (HttpMetric), Analytics. ✅ **Offline** — Firestore
  persistence (unlimited cache) + Hive.

---

**Not yet built / deferred:** white-label gym branding, supplement ecosystem, behavioral-analytics
ML pipeline, additional locales, payout provider, gym-wars full UI, "gyms near me" map discovery.
Each has a roadmap in `docs/roadmap/FUTURE_FEATURES.md`.
