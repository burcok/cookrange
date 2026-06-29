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

### B1. ✅ "Gyms Near Me" Map Discovery — SHIPPED
Already built in `gym_discovery_screen.dart`: "Near Me" sort chip, `_GymMapView` (flutter_map +
OpenStreetMap), client-side **Haversine** distance sort over a city-filtered set, `_DistanceBadge`,
in-memory `_userLat/_userLon` (location **never persisted** — data-minimized). **KVKK/GDPR consent
gate added** (`_activateNearMe` shows a `PermissionPrimer` stating location is on-device + not stored
+ declinable, before the OS prompt — `gym.nearby_consent_*` keys). See `docs/FEATURES.md` + `COMPLIANCE.md` §6.
**Optional later (🟢 S–M):** geohash + server-side radius query if the city-filtered client sort
becomes too coarse at scale; marker clustering for dense cities.

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

## L. Legal & Compliance (🔴 founder priority — legal-first)

> The app must proceed within a legal framework end-to-end. Framework lives in `docs/COMPLIANCE.md`;
> these are the build-outs to reach full KVKK + GDPR compliance. **All drafted documents require a
> qualified lawyer's review before launch — engineering produces mechanisms + drafts, not legal advice.**

### L1. ✅ Comprehensive Legal Documents (EN+TR) — DRAFTED (pending lawyer review)
**Done:** Privacy Policy, Terms of Use, KVKK Aydınlatma Metni, and Açık Rıza Beyanı drafted in EN+TR as
markdown assets (`assets/legal/`), rendered by a dependency-free renderer in `legal_screen.dart`, wired
into Settings + Register. Cookie/SDK + AI disclosures are sections of the Privacy Policy. See
`docs/COMPLIANCE.md` §8. **⚠️ Drafts require qualified-lawyer review before launch.** Remaining:
Coach/Gym/Marketplace agreements ship with payments (L7). Original scope below for reference:
1. **Privacy Policy / Gizlilik Politikası** — every data point, purpose, legal basis, sub-processors
   (Firebase, OpenRouter, stores, PSP, OSM), retention, cross-border transfer, rights + contact/DPO.
2. **Terms of Use / Kullanım Koşulları** — accounts, acceptable use, UGC/moderation, marketplace,
   subscriptions/credits, refunds, disclaimers (health is not medical advice), liability, governing law.
3. **KVKK Aydınlatma Metni** — standalone Turkish clarification text (controller, purposes, recipients,
   collection method + legal cause, Art. 11 rights).
4. **Açık Rıza Beyanı** — explicit, separate, opt-in, withdrawable consent for **health data**,
   **location**, **marketing**.
5. **Cookie/SDK & Tracking notice** — Firebase Analytics, Crashlytics, ATT, OpenStreetMap tiles.
6. **AI/automated-processing disclosure** — what's sent to the LLM, that outputs are estimates, no
   solely-automated decisions with legal effect.
- **Approach:** tailor wording to our real practices (do **not** copy other apps' contracts — copyright
  + mismatch risk); use comparable apps only as *structure* reference. Health-app specifics
  (no medical claims). Render in `legal_screen.dart` with new `LegalDocumentType` entries + i18n.
- **Effort:** L (drafting) + lawyer review. **Dep:** none to draft; review before launch.

### L2. ✅ Consent Management Center — SHIPPED
**Done:** Settings → **Privacy & Consents** (`consent_center_screen.dart`) — per-purpose grant/withdraw
toggles (health, location, AI, cross-border, analytics, notifications, marketing), each with what/why,
status + recorded date, and a **"needs review"** badge when the policy version bumped. `ConsentService`
writes versioned, timestamped, owner-only records to `users/{uid}/consents/{purpose}` (demonstrable
consent) and exposes `hasConsent()` for gating. `kLegalPolicyVersion` constant triggers re-consent on
bump. Firestore rule added; EN+TR copy. **Remaining (follow-up):** per-purpose *enforcement* (each
consumer checks `ConsentService.hasConsent`) + first-run consent prompt — fold into L3 / app-entry.

### L3. ✅ Data Subject Request (DSAR) Channel — SHIPPED
`PrivacyRequestModel` + `PrivacyRequestService` + `privacy_requests/{id}` (owner create/read, admin
read/update; 2 indexes). User flow: `privacy_request_screen.dart` (type chips + message + my-requests
list, Settings → Privacy Requests). Admin: `AdminService.privacyRequestsStream/updatePrivacyRequest` +
`admin_privacy_requests_screen.dart` (side menu → Privacy Requests; resolve with status + note + audit
log). Self-service export/delete still cover access/erasure instantly. EN+TR.

### L4. ✅ Age Gating & Children's Data — SHIPPED
`AgeGate` util (`kMinimumAgeYears = 16`, GDPR Art. 8 conservative default — adjust per counsel). The
onboarding birth-date picker's `maxDate` blocks under-age selection + defensive `isUnderMinimumAge`
re-check with a localized message (`onboarding.age_gate`). Privacy Policy children's section already
present.

### L5. ✅ Cross-Border Transfer & VERBİS — ENGINEERING DONE (legal-ops open)
Transfer register + mechanism documented in `docs/COMPLIANCE.md` §11; disclosed in Privacy Policy §8 +
KVKK Aydınlatma §5; dedicated `crossBorderTransfer` consent purpose in the Consent Center. **Open
(counsel):** VERBİS obligation assessment, signing processor DPAs, finalising the transfer mechanism.

### L6. ✅ Breach Response Runbook — SHIPPED (doc)
Documented in `docs/COMPLIANCE.md` §12: detect → contain → assess → notify (KVKK Board / GDPR 72h) +
affected users → remediate, with roles, contact, pre-reqs, and an incident log.

### L7. ⏳ Marketplace / Payout Legal Terms — DRAFTED (activates with A1 payouts)
Coach & Marketplace Agreement drafted EN+TR (`assets/legal/marketplace_terms_{en,tr}.md`): provider
status, listings, fees/commission, payouts/KYC, taxes, refunds/chargebacks, conduct, termination,
liability. **Wires into the UI when payments/payouts ship (A1).** Lawyer review required.

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
0. **Legal track L1–L6 shipped** ✅ (docs, consent center, DSAR, age-gating, transfer register, breach
   runbook). Remaining before public launch: **qualified-lawyer review** of all drafts, processor DPAs +
   VERBİS assessment (L5 legal-ops), and per-purpose consent enforcement. L7 marketplace terms drafted,
   activates with payments (A1).
1. ~~B1 Gyms-near-me~~ ✅ shipped (with KVKK consent) + **D1 Rich composer** (M).
2. **A1 Payouts** (XL, unlocks coach/affiliate revenue) — start KYC/provider early.
3. **D3 Gamification** (M) + **B2 Gym Wars UI** (M) for engagement.
4. **C1 Analytics export** turned on *now* (cheap) so **C1/C2 ML** can follow once data accrues.
5. **A2 credit tiers**, **E2 sponsorship**, **F1 locales** as growth/market demands.
6. **B3 white-label**, **E1 supplements** when partnerships/business justify them.

Each item above maps to (or extends) a `TODO.md` line; keep both in sync as scope firms up.
