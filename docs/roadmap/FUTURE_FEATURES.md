# FUTURE_FEATURES.md — Missing & Future Features (with roadmaps)

> Everything Cookrange does **not** yet do, each with a concrete build plan: problem, scope, data
> model, services, UI, dependencies, risks, and a phased estimate. When one ships, move it to
> `docs/FEATURES.md` and delete it here. Status reflects the codebase as of v0.9.5 consumer-beta.
>
> Priority: 🔴 high (unlocks revenue/retention) · 🟠 medium · 🟢 nice-to-have.
> Effort: S (≤2d) · M (3–6d) · L (1–2wk) · XL (multi-week).
> Many of these are also tracked at a line level in `TODO.md`; this file is the *design* layer.

---

## A. Monetization & Payments

### A1. 🔴 Payout Provider Integration (real money out) — XL
**Problem:** Commissions (referrals, coach sessions, program sales) are *tracked*
(`CommissionService`, `AffiliateEarningsScreen`) but never *paid*. The earnings screen shows an
honest "payouts coming soon" banner.
**Scope:** Wire a payout rail so coaches/affiliates actually receive money.
- **Architect:** Choose provider — **Stripe Connect** (Express accounts, global, KYC handled) is the
  default; for TR-only, **iyzico** marketplace. Money flows: IAP revenue → platform → payout balance →
  provider transfer.
- **Data:** `users/{uid}/payout_accounts/{id}` (provider account id, status, KYC state);
  extend `payout_requests` with provider transfer id + status webhook updates; ledger collection
  `payout_ledger/{id}` (immutable, double-entry: credit/debit, source commission ids).
- **Backend:** Cloud Functions — `createConnectAccount`, `createPayout`, `stripeWebhook`
  (transfer.paid/failed → update ledger + notify). Never trust client for amounts; server computes
  payable balance from approved commissions minus prior payouts.
- **Services:** extend `CommissionService` (payable-balance calc), new `PayoutService`.
- **UI:** Onboarding-to-payouts flow (KYC redirect via `url_launcher`), bank/account status card,
  payout history with provider status, minimum-threshold gate.
- **Compliance:** KYC/AML handled by provider; tax forms (1099/e-invoice) per region; clear ToS on
  commission terms.
- **Risks:** store rules — Apple/Google forbid taking a cut of *digital* goods outside IAP, but
  *real-world coaching services* and physical payouts are allowed; keep digital program sales on IAP,
  route coach-service payouts via the provider. Legal review required.
- **Phasing:** M (Stripe Connect Express + KYC + manual payout) → M (webhooks + automated balance) →
  M (tax/threshold/ledger hardening).
**Unblocks:** the entire coach/affiliate revenue narrative in `README.md`.

### A2. 🟠 Richer Credit & Subscription Tiers — M
**Problem:** Only free/premium/pro + a single credit pack. README envisions +15/+50 packs, extra
regenerations, extra scans.
**Scope:** Multiple consumable SKUs, an annual-vs-monthly upsell experiment, gift/referral credits.
- **Data:** extend `ai_credits` (track per-source bonus buckets); new product IDs in `BillingService`.
- **UI:** `AiCreditsSheet` becomes a small store (pack grid); A/B paywall copy via Remote Config.
- **Effort:** M. **Dep:** Phase 4 store products in `GO_LIVE.md`.

---

## B. Gym Ecosystem Depth

### B1. 🔴 "Gyms Near Me" Map Discovery — M
**Problem:** Gym discovery is name/city/district filtered only; no map, no proximity. (`flutter_map`
+ `latlong2` + `geolocator` are already dependencies; gyms store lat/lng.)
**Scope:** Map view with gym pins, "near me" radius sort (Haversine), tap-pin → gym preview → join.
- **Architect:** Firestore can't geo-query natively without geohashing. Either add a **geohash**
  field to gyms + range query, or client-side Haversine over a city-filtered set (cheaper for MVP).
- **Data:** add `geohash` to `GymModel` (computed on save); index `is_public + geohash`.
- **Services:** `GymService.searchGymsNearby(lat, lng, radiusKm)`.
- **UI:** toggle list/map in `gym_discovery_screen`; `flutter_map` with clustered markers; permission
  primer before GPS; current-location pin; bottom preview sheet.
- **Effort:** M. **Risk:** location permission UX (use `PermissionPrimer`), battery (one-shot fix).

### B2. 🟠 Gym Wars — Full Competition UI — M
**Problem:** `GymWarModel` + `gym_wars/` collection + service exist, but the competition experience
(create challenge, live scoreboard, results, rewards) is minimal.
**Scope:** Challenge creation flow (pick rival gym, metric, dates), live dual-scoreboard (check-ins/
calories/consistency), countdown, winner celebration + shareable result card.
- **Data:** aggregate scores via Cloud Function (scheduled or onCheckin trigger) into `gym_wars/{id}`
  to avoid expensive client reads.
- **UI:** war detail screen (animated dual progress), home/gym-dashboard war banner, push on start/end.
- **Effort:** M. **Dep:** check-in data (exists).

### B3. 🟢 White-Label Gym Branding — L
**Problem:** README promises gyms can fully brand the app (logo, colors, onboarding). Today only a
gym brand *color* + logo on gym surfaces.
**Scope:** Per-gym theming for members (gym logo in nav, gym primary color, branded onboarding for
members who join via a gym code/QR), optional gym-scoped home.
- **Architect:** member's "active gym" drives a theme override layer on top of `ThemeProvider`;
  guard so it never breaks the global DS. Full white-label (separate app binary) is **out of scope**
  — this is in-app co-branding.
- **Data:** gym branding fields (already have brandColor/logo); member `active_gym_id`.
- **Effort:** L. **Risk:** theming complexity, DS token discipline (must still use `AppPalette`).

---

## C. AI Intelligence

### C1. 🟠 Behavioral Analytics → ML Features Pipeline — XL (deferred until data)
**Problem:** No event→feature pipeline; AI personalization is prompt-based only. Deferred because it
needs months of real behavioral data.
**Scope:** Stream Firestore/Analytics events to BigQuery, build features (adherence, churn-risk,
best-meal-time), feed back into AI prompts + risk detection.
- **Architect:** Firebase → BigQuery export (Analytics + Firestore export extension); scheduled
  feature jobs; results written to `users/{uid}/ml_features`. Keep it privacy-safe (aggregate, opt-in).
- **Phasing:** enable exports now (cheap) → accumulate → build features once volume exists.
- **Effort:** XL. **Dep:** real user base. **Note:** start the *export* early so data accrues.

### C2. 🟠 Dynamic Plan Adaptation — M
**Problem:** README's "plans evolve based on progress/compliance"; today plans regenerate on profile
change, not on *behavior*.
**Scope:** Nightly job adjusts targets from adherence (e.g. consistently under protein → nudge);
"your plan adapted because…" insight card.
- **Services:** extend `AiInsightService` + `WeeklyMealPlanService` with an adaptation pass.
- **Dep:** some of C1's adherence signals. **Effort:** M.

### C3. 🟢 AI Photo Food Logging — M
**Problem:** Food scan is text-description based; no photo→nutrition.
**Scope:** Image → multimodal model → estimated dish + macros → log. (`image_picker` exists; needs a
vision-capable model via the proxy.)
- **Risk:** accuracy + cost; gate behind credits; show "estimate" disclaimer.
- **Effort:** M. **Dep:** vision model on OpenRouter + proxy passthrough.

---

## D. Community & Retention

### D1. 🟠 Rich Post Composer — M
**Problem:** Composer is text + images + tags + mentions; no rich formatting, polls, or recipe/meal
embeds beyond basic post types.
**Scope:** Inline recipe/meal-plan attach, progress-photo before/after, simple polls.
- **Data:** extend `CommunityPost.metadata` (attachment refs, poll options/votes subcollection).
- **UI:** composer attachment bar; `GlassPostCard` renders embeds. **Effort:** M.

### D2. 🟢 Challenges 2.0 (re-introduce, purpose-built) — L
**Problem:** Legacy challenges were sunset; Streak Squads replaced part of it. README still wants
structured challenges (7-day reset, 30-day fat loss, sponsored).
**Scope:** Templated challenges with join/progress/leaderboard, optional sponsor, completion rewards
(badges/bonus credits). Build on the squad infrastructure.
- **Data:** revive a lean `challenges/` schema (template, metric, dates, sponsor, participants subcol).
- **Effort:** L. **Dep:** sponsor/reward economics.

### D3. 🟢 Gamification Layer (XP / Levels / Badges) — M
**Problem:** README describes XP/levels (Rookie→Legend); only streaks + reputation exist today.
**Scope:** XP from actions (log, post, streak, challenge), level thresholds, badge cabinet, profile
level chip.
- **Data:** `users/{uid}.xp`, `level`, `users/{uid}/badges/{id}`; server-side XP grant to prevent
  cheating (Cloud Function on qualifying events).
- **Effort:** M. **Risk:** anti-abuse (grant server-side, not client).

---

## E. Marketplace & Partnerships

### E1. 🟢 Supplement / Partner-Brand Ecosystem — L (business-gated)
**Problem:** README's supplement recommendations + partner brands. Deferred pending partnerships.
**Scope:** AI recommends supplements from nutrition gaps; partner catalog; affiliate-linked products.
- **Data:** `products/{id}` (partner catalog), `users/{uid}/recommendations`.
- **Risk:** health-claim compliance (no medical claims), store policy on external purchase links.
- **Effort:** L. **Dep:** signed brand partnerships (business, not code).

### E2. 🟠 Challenge / Program Sponsorship Marketplace — M
**Scope:** Brands fund challenges/programs; sponsor placement; reporting dashboard.
- **Dep:** A1 payouts + D2 challenges. **Effort:** M.

---

## F. Platform & Reach

### F1. 🟠 Additional Locales (beyond EN/TR) — M per locale
**Problem:** Infra ready (JSON + parity test + scalable picker), but only EN/TR ship.
**Scope:** Add a locale by dropping `assets/localization/{code}.json` (full parity), registering it
in `supportedLocales` + delegate + `LanguageProvider`, extending the parity test.
- **Effort:** M per locale (mostly translation). **Dep:** human translators or vetted MT + review.

### F2. 🟢 Tablet / Large-Screen Layouts — M
**Problem:** Portrait-phone optimized; iPad/large Android underuse space.
**Scope:** Responsive master-detail for lists (community, chat, admin), `flutter_screenutil`
breakpoints. **Effort:** M.

### F3. 🟢 Offline-Write Queue — M
**Problem:** Firestore persistence gives offline *reads*; no robust offline *write* queue (decided
deferred in Phase 9).
**Scope:** Queue mutations (food logs, posts) when offline, replay on reconnect with conflict policy.
- **Effort:** M. **Dep:** retention data showing real need.

---

## G. Hardening (ongoing)

### G1. 🟠 Widget/Integration Test Coverage — M
**Problem:** Tests cover calc/parse/streak/parity + a basic widget test; no broad widget/integration
coverage of critical flows (auth, onboarding, logging, purchase).
**Scope:** Golden tests for DS components; integration tests for auth→onboarding→home and
log-food→analytics; mock Firebase. **Effort:** M.

### G2. 🟢 Performance Budget Automation — S
**Scope:** CI step or manual harness to catch jank regressions (frame timings on key screens);
extend `scripts/` with a perf check. **Effort:** S.

### G3. 🟢 Crash-Free & Funnel Dashboards — S (console)
**Scope:** Stand up Crashlytics velocity alerts + Analytics funnels (onboarding completion, paywall
conversion, D1/D7/D30 retention). Mostly console (see `GO_LIVE.md` §5.5). **Effort:** S.

---

## Suggested Sequencing (after launch)
1. **B1 Gyms-near-me** (M, high retention, deps already present) + **D1 Rich composer** (M).
2. **A1 Payouts** (XL, unlocks coach/affiliate revenue) — start KYC/provider early.
3. **D3 Gamification** (M) + **B2 Gym Wars UI** (M) for engagement.
4. **C1 Analytics export** turned on *now* (cheap) so **C1/C2 ML** can follow once data accrues.
5. **A2 credit tiers**, **E2 sponsorship**, **F1 locales** as growth/market demands.
6. **B3 white-label**, **E1 supplements** when partnerships/business justify them.

Each item above maps to (or extends) a `TODO.md` line; keep both in sync as scope firms up.
