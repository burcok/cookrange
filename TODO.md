# TODO.md — Cookrange Engineering Backlog

> **THE SINGLE SOURCE OF TRUTH.** This document replaces every prior TODO, roadmap, backlog, phase
> plan, audit list and issue tracker in this repository. Nothing lives outside it. If a task is not in
> here, it is not planned. If a task is in here, it is real, actionable, and owned.

**Document type:** Engineering backlog · product roadmap · technical-debt register · release plan
**Supersedes:** the previous `TODO.md` (Phases 1–16), `docs/roadmap/GO_LIVE.md` §5S, `docs/roadmap/FUTURE_FEATURES.md`, `docs/roadmap/COMMUNITY_GROUPS.md` §5–6, `docs/roadmap/ONBOARDING_V2.md` §7–8, `docs/roadmap/PHASE_15_ENGAGEMENT.md`
**Basis:** Full source audit of commit `e06ca0d` — 329 Dart files / 115,129 LOC in `lib/`, 7 Cloud Function files / 1,692 LOC, `firestore.rules` (684 lines / 71 match blocks), `firestore.indexes.json` (65 composite indexes), both platform manifests, both CI workflows, 2,722 × 2 localization keys. Verified by **running** `flutter analyze`, `flutter test`, `dart format`, and cross-checking every Firestore/Storage path written by code against the rule that governs it.
**Audit date:** 2026-07-31
**Nominal version:** `1.0.0+1` (`pubspec.yaml`) — **honest engineering reality: `v0.9.6` internal alpha. Not launchable.**

---

## §0 — How To Use This Document

### 0.1 Legend — Status

| Marker | Meaning |
|---|---|
| ✅ **Completed** | Shipped, code-proven, and verified functional |
| 🚧 **Partial** | Real code exists but the feature is incomplete or unverified end-to-end |
| ❌ **Missing** | No implementation exists |
| 🟡 **Stub** | UI or skeleton exists with no working logic behind it |
| 📋 **Planned** | Specified, scheduled, not started |
| 🔥 **Critical** | Blocks launch, breaks users, or is a live security/legal exposure |

> ⚠️ **A note on `✅` in this document.** The previous roadmap marked many items `✅` that this audit
> proved non-functional (challenge sunset, push fan-out, meal-plan history, gym logo upload). In this
> document `✅` means **verified working**, not "code was written." Anything written-but-unverified is
> `🚧`. Where the old roadmap claimed `✅` and the code disagrees, the discrepancy is recorded explicitly
> in the task card so the history is not lost.

### 0.2 Legend — Complexity & Estimates

| Complexity | Meaning | Rough time (1 engineer) |
|---|---|---|
| **XS** | One file, one obvious change | < 2 h |
| **S** | One subsystem, no data model change | 0.5–1 d |
| **M** | Multiple files, may touch rules/indexes | 2–4 d |
| **L** | New subsystem or cross-cutting refactor | 1–2 w |
| **XL** | New domain + backend + UI + compliance | 3–6 w |
| **Epic** | Multi-track programme, must be decomposed further | 2 mo+ |

### 0.3 Task card format

Two formats, both carrying the full required field set:

- **Full card** — used for every `Critical` and `High` priority task. All fields written out.
- **Compact row** — used for `Medium`, `Low`, Research and Icebox items. The same fields, as table columns.

Every task has a stable **ID**. IDs are permanent — never renumber, never reuse. Cross-references
(`Depends on`, `Blocking`, traceability matrix in §50) rely on them.

### 0.4 Field definitions

| Field | Meaning |
|---|---|
| **Status / Priority / Complexity / Est** | Per §0.1–0.2 |
| **Dependencies** | Task IDs that must land first |
| **Required before** | Task IDs that cannot start until this lands |
| **Blocking** | Business/release outcome this is holding up |
| **Modules** | Backend · Frontend · Firebase · AI · Security · Database · UX · Analytics · Testing · DevOps · Store · Documentation · Legal · Monetization · Product |
| **Files** | Concrete paths (with line numbers where the defect is pinpointed) |
| **Owner** | Role that owns delivery (single-dev project today — role indicates the hat, not a person) |
| **Version / Milestone** | Target release train (§1.8) |
| **Labels** | Free-form tags for filtering |
| **Acceptance Criteria** | Observable, testable outcomes. If you cannot demo it, it is not done. |
| **DoD** | Project-wide Definition of Done (§0.5) plus task-specific gates |
| **Technical Notes** | Root cause, chosen approach, gotchas |
| **Risks** | What can go wrong shipping this |
| **Future improvements** | Deliberately deferred follow-ups (each becomes its own Icebox ID) |

### 0.5 Project-wide Definition of Done

Every task must satisfy all of these before it is marked `✅`:

☑ Multi-role reasoning applied (PM → Architect → Dev) · ☑ Optimised: no unbounded `.snapshots()`/`.get()`,
no N+1, `const` constructors, subscriptions cancelled in `dispose()` · ☑ Correct data tier + composite
indexes + security rules + seed/migration where needed · ☑ Meaningfully logged; **errors routed to
`CrashlyticsService`, never swallowed** · ☑ 60 fps, iOS + Android verified **on a physical device** ·
☑ Light + dark correct, no hardcoded colours · ☑ EN + TR keys added in the same change, `test/i18n_parity_test.dart`
green · ☑ Flagship-grade loading / empty / error / success states — **no raw `CircularProgressIndicator`** ·
☑ `flutter analyze lib/` 0 errors · ☑ `dart format lib/` clean · ☑ `flutter test` green ·
☑ This `TODO.md` + the owning `docs/` file + `CLAUDE.md` updated in the same task.

### 0.6 The rule that would have prevented most of this backlog

> **Never mark a feature done until you have exercised it against a live backend on a physical device.**

Seven separate shipped, documented features in this repository are dead because a write path, a security
rule, a storage prefix or a trigger path did not match its counterpart — and every failure was hidden by
`catch → debugPrint`, which compiles to nothing in release. See `DEBT-01`. Fix that pattern and the
codebase starts telling you the truth.

---

## §1 — Executive Summary

### 1.1 Project health

| Dimension | Score | One-line reality |
|---|---|---|
| Architecture | 6.5 / 10 | Clean layering and conventions; god objects, abandoned repository layer, no DI seam |
| Flutter craft | 7.0 / 10 | Analyzer-clean at 115k LOC, real design system; 87 raw spinners, 334 hardcoded colours |
| Firebase | 6.0 / 10 | 684-line rules with real field-locking; 7 path/rule mismatches, 8 open-write holes |
| AI | 5.5 / 10 | Best-in-class quota/cost/injection/allergen layers; **fatal mock-data default** |
| Security | 4.0 / 10 | Sophisticated design; **all 18 of its own gates unchecked**, App Check unenforced |
| Performance | 6.0 / 10 | Cached images, `pollCount`, pagination; **zero measurement anywhere** |
| UX | 6.5 / 10 | Design system + motion + flawless i18n; accessibility 3/10, loading states 4/10 |
| Scalability | 5.0 / 10 | Fine to ~100k with known work; hard **180-dish prompt ceiling** |
| Code quality | 6.5 / 10 | Readable, consistent, null-safe; **swallow-and-log is the systemic defect** |
| Maintainability | 5.5 / 10 | 40 files > 800 LOC, no interfaces, no test seam |
| Documentation | 5.5 / 10 | 486 KB, well-organised — and **it asserts features that do not exist** |
| Testing | 3.0 / 10 | **~1 % coverage** (unchanged) — but `test/` tracked, 0 failing, and **all 4 CI jobs confirmed green** (first time ever) |
| Business readiness | 2.0 / 10 | **Zero revenue capability**; premium bypassable |
| Production readiness | 2.5 / 10 | Two hard ship blockers, CI red, no monitoring, no backups |
| **Weighted composite** | **5.4 / 10** | Strong design instincts, high velocity, **no verification discipline** |

### 1.2 Current version

| | |
|---|---|
| `pubspec.yaml` | `1.0.0+1` |
| Honest state | **v0.9.6 internal alpha** |
| Next milestone | **M1 — Truth** (make what exists actually work) |
| First shippable | **v1.0.0-beta1**, consumer-only scope, after M1 + M2 + M3 |
| Store presence | None. Neither developer programme is enrolled. |

### 1.3 Progress

| Dimension | % |
|---|---|
| Feature surface **written** | ~84 % |
| Feature surface **verified functional** | ~45 % (7 confirmed dead paths; no integration tests to bound the real number) |
| Backend / infrastructure configured | ~30 % |
| Security gates closed | **0 %** (`S0`–`S17` all open) |
| Store readiness | ~10 % |
| Monetization functional | **0 %** |
| Test coverage | ~1 % |
| Accessibility | ~15 % |
| **Overall, to a public v1** | **~30–35 %** |

### 1.4 Completed systems — verified working

These are code-proven **and** believed functional. Full archive with evidence in §47.

| System | Evidence |
|---|---|
| ✅ Email / Google / Apple auth, verification, reset, session monitoring | `auth_service.dart` (27 KB) |
| ✅ Onboarding V2 — pre-registration intro + 14 personalised pages | `screens/onboarding/v2/` (16 files) |
| ✅ Onboarding projections — BMI, macros, safe-clamped rate, ETA | `onboarding_projection_service.dart`, unit-tested |
| ✅ Calorie / macro maths (Mifflin-St Jeor) | `calorie_calculator.dart`, 20 unit tests |
| ✅ Streak logic incl. freeze consumption | `firestore_service.dart`, 8 unit tests |
| ✅ Food diary + real-time consumed-calorie stream | `food_log_service.dart`, `home.dart` |
| ✅ Recent / frequent foods, favourites, recipe notes | `recent_food_service.dart`, `favorite_service.dart`, `recipe_note_service.dart` |
| ✅ Water reminders — timezone-correct multi-time scheduling | `push_notification_service.dart`, unit-tested |
| ✅ Weight + hydration + exercise logging | `tracking_card.dart`, `exercise_log_service.dart` |
| ✅ Shopping list — Hive + auto-gen + source-meal attribution + Firestore sync | `shopping_list_screen.dart`, `shopping_list_sync_service.dart` |
| ✅ Cooking mode + wakelock + finish→log | `cooking_mode_screen.dart` |
| ✅ Community feed, comments, reactions, save/bookmark, topics, mentions, follow | `community_service.dart` (37.6 KB) |
| ✅ 1:1 + group chat with image messages (**push works here**) | `chat_service.dart`, `onChatMessageCreated` |
| ✅ In-app notifications with locale-rendered presenter | `notification_service.dart`, `notification_presenter.dart` |
| ✅ Achievements — 11 badges, idempotent grant, backfill | `achievement_service.dart` |
| ✅ AI daily insight / Fitness Twin / weekly recap (**all guard `isConfigured`**) | `ai_insight_service.dart` (23 KB) |
| ✅ AI proxy security core — allowlist, fail-closed quota, rate limit, cost accounting | `functions/index.js:285-460` |
| ✅ Deterministic allergen pre-filter | `utils/allergen_safety.dart`, unit-tested |
| ✅ Prompt-injection guard + guillemet fencing | `prompt_service.dart` |
| ✅ Hive AES-256 encryption + plaintext migration | `storage_service.dart:60-119` |
| ✅ Consent registry — versioned, timestamped, withdrawable, gates collection | `consent_service.dart` |
| ✅ Design system — 14 components over semantic token layers | `core/widgets/ds/`, `core/theme/` |
| ✅ EN/TR localization — 2,722 keys, exact parity, CI-enforced | `assets/localization/`, `test/i18n_parity_test.dart` |
| ✅ Maintenance mode + force-update gates | `route_guard.dart`, `app_config_service.dart` |
| ✅ Feature kill-switches with default-on fail-safe | `app_config_service.dart` |
| ✅ Remote app config editable without redeploy (client **and** `aiProxy`) | `app_config/global` |
| ✅ Uploads — resize, JPEG q82, EXIF/GPS strip, off-thread isolate | `storage_upload_service.dart` |
| ✅ Image display — 48 `CachedNetworkImage` + 14 `AppImage`, only 3 raw | codebase-wide |
| ✅ Count discipline — `pollCount()` in 28 sites, zero count anti-patterns | `utils/firestore_count.dart` |
| ✅ `flutter analyze lib/` — 0 errors, 0 warnings, 25 infos | verified 2026-07-31 |
| ✅ CI/CD — all 4 jobs green (`analyze-and-test`, `firestore-rules`, `secret-scan`, `build-android`) | [run #46](https://github.com/burcok/cookrange/actions/runs/30690211684), verified 2026-08-01, `BLK-13`/`CI-11`/`CI-12` |
| ✅ AI meal planning / recipe generation — no longer fabricates when unconfigured; throws + branded error state | `BLK-01`, closed 2026-08-01. Real end-to-end generation still depends on `BE-01` (proxy deployment) |
| ✅ iOS photo picker — usage string present, all 6 gallery sites prime consistently, permanent CI guard | `BLK-02`, closed 2026-08-01. Physical-device confirmation still owed (Simulator-verified only) |
| ✅ Meal plan history — rule deployed, both read/write paths report to Crashlytics on failure | `BLK-06`, closed 2026-08-01. Rules test passing in CI ([run #50](https://github.com/burcok/cookrange/actions/runs/30697804480)); end-to-end device walkthrough still owed |

### 1.5 Partially completed systems

| System | What exists | What is missing / broken |
|---|---|---|
| 🚧 **Push notifications** | FCM token capture, mute groups, presenter, 2 cron producers | **`BLK-03`** — fan-out trigger listens on a path nothing writes |
| 🚧 **Admin surface** (~7,400 LOC, 9 screens) | Hub, users, applications, dishes, reports, cost, config, audit, privacy | **`BLK-05`** — `admin_roles/{uid}` created by nothing |
| 🚧 **Monetization** | IAP client, server validation, entitlement ledger, paywall, credits sheet | **`BLK-04`** — no store products, no store credentials |
| 🚧 **Gym ecosystem** (11 screens) | Discovery, map, setup, dashboard, analytics, QR, members, community, leaderboard | `BLK-05` + `BLK-03` + `BLK-07` (logo upload denied) |
| 🚧 **Coach ecosystem** (8 screens) | Discovery, application, profile, dashboard, clients, reviews | `BLK-05` + `BLK-03`; paid programs and payouts absent |
| 🚧 **Program marketplace** | Model, content weeks, enrolment, My Programs | `BLK-09` open-write hole; paid gate stubbed |
| 🚧 **Dish catalog** | 75 dishes, seeder, admin editor | **`BLK-11`** — unseedable in-app; 75 is too few; 180-dish prompt ceiling |
| 🚧 **Moderation** | Keyword filter, report queue, Vision SafeSearch function | Scans the wrong prefix; admin queue unreachable (`BLK-05`) |
| 🚧 **Analytics** | ~35 typed events, offline queue, consent-gated | No BigQuery export, no funnels, no dashboards, no taxonomy doc |
| 🚧 **Crashlytics** | Correct single-owner wiring, custom keys, consent gate | **Blinded** by swallow-and-log (`DEBT-01`); no release symbol upload |
| 🚧 **Offline** | Firestore persistence, one cache-first read, Hive domains | No write queue, no conflict resolution, no sync-status UI |
| 🚧 **Challenge sunset** | Screens, model, service, deep links, lib refs removed | **`DEBT-11`** — rules block + 2 indexes + 4 orphan i18n keys survive; old roadmap claimed complete |
| 🚧 **Accessibility** | DS-level semantics on ~6 components, reduced-motion in 2 widgets | 32 sites across 329 files; no screen-reader / contrast / touch-target pass |
| 🚧 **Dark mode** | Both themes fully defined, `ThemeProvider` live | 120 hex + 214 `Colors.white/black` literals in `lib/screens` |
| 🚧 **CD (deploy workflow)** | Full TestFlight/Play deploy workflow (CI itself moved to §1.4 — all 4 jobs green) | `BLK-16` — no signing identity, no store secrets set; has never run |

### 1.6 Missing systems — no implementation exists

| System | ID |
|---|---|
| ❌ Integration + widget test coverage of real flows | `TEST-02`, `TEST-03` |
| ❌ Firestore rules tests **in version control** | `TEST-01` |
| ❌ Monitoring, alerting, SLOs, dashboards | `OBS-01`–`OBS-04` |
| ❌ Structured production logging (`debugPrint` is a release no-op) | `OBS-05` |
| ❌ Staging / dev environment separation | `INF-01` |
| ❌ Backups, PITR, restore runbook, DR plan | `DR-01`–`DR-03` |
| ❌ Dependency injection / service interfaces | `ARCH-04` |
| ❌ Full-text search (users, dishes, coaches, gyms) | `PERF-08` |
| ❌ Payout rail (Stripe Connect / iyzico) | `REF-04` |
| ❌ Challenges (deliberately sunset; re-introduction is a future item) | `CHL-01` |
| ❌ XP / levels gamification layer | `GAM-01` |
| ❌ White-label beyond per-gym brand colour | `PTR-02` |
| ❌ Auth rate limiting / lockout / MFA | `AUTH-04`, `AUTH-05` |
| ❌ Server-authoritative streak + reputation | `SEC-14` |
| ❌ Data-migration framework (versioned, idempotent, logged) | `ARCH-06` |
| ❌ Load testing of `aiProxy` under real concurrency | `PERF-10` |
| ❌ API versioning on the proxy contract | `BE-07` |
| ❌ Release obfuscation + symbol upload | `CI-05` |
| ❌ Tablet / large-screen layouts | `UI-09` |
| ❌ Offline write queue | `ARCH-07` |
| ❌ Behavioural analytics → ML pipeline | `AI-14` |

### 1.7 Critical blockers

**Nothing ships until every one of these is closed.** Full cards in §2.

| ID | Blocker | Why it blocks |
|---|---|---|
| `BLK-03` | 🔥 Push fan-out wired to a path nothing writes; admin path has no rule | Zero social push; gym/coach approval batches fail |
| `BLK-04` | 🔥 Monetization non-functional end to end | Zero revenue capability |
| `BLK-05` | ⚠️ Admin surface — client + rules + function **written**, `syncAdminClaim` **not deployed** | No moderation, no approvals, no cost visibility until deployed |
| `BLK-07` | 🔥 Gym logo upload writes to an unruled Storage prefix | Gym setup broken; NSFW scanner watches the wrong prefix |
| `BLK-08` | 🔥 Any user can mutate any post's non-content fields | Like-count / announcement / group integrity |
| `BLK-09` | 🔥 `coach_uid == 'demo'` lets any user publish to the public marketplace | Content injection into a live storefront |
| `BLK-10` | 🔥 User doc world-readable with `email`, `last_login_ip`, device fingerprints | GDPR / KVKK exposure in the primary market |
| `BLK-11` | 🔥 Dish catalog unseedable in-app; only 75 dishes | Core feature has no content on a fresh project |
| `BLK-12` | 🔥 GDPR erasure + export incomplete | Art. 17 / Art. 20 non-compliance |
| `BLK-13` | ✅ Closed — all four CI jobs confirmed green in real CI, first time in this repo's history | `CI-11` (3 root causes) and `CI-12` (1 root cause) both fixed and confirmed |
| `BLK-14` | 🔥 App Check not enforced (`APP_ENV=development`) | Proxy and Functions open to unattested clients |
| `BLK-15` | 🔥 Live OpenRouter key bundled as a Flutter asset + shipped in CI artifacts | Key extraction / denial-of-wallet |
| `BLK-16` | 🔥 No Apple / Google developer programme enrolment, no signing identity | Cannot produce a distributable build |
| `BLK-17` | 🔥 No monitoring, no alerting, no backups, single environment | Cannot operate or recover a production service |

### 1.8 Release trains & milestones

| Milestone | Version | Theme | Exit criterion | Est (solo) |
|---|---|---|---|---|
| **M1 — Truth** | `v0.9.7` | Make what exists actually work | Every consumer-path feature demonstrated working on a **physical iPhone and Android** against a production-configured backend. All 17 blockers closed. CI green. | 4–6 w |
| **M2 — Legal** | `v0.9.8` | Make it lawful | `S0`–`S17` green. User doc split. Erasure + export complete. Privacy labels + Data Safety filed. DPA executed. Backups live. | 3–4 w (parallel) |
| **M3 — Commerce** | `v0.9.9` | Make it sellable | Both stores enrolled. 3 products live. One real sandbox purchase → real entitlement. Premium gating server-side. | 3–4 w (parallel, gated on enrolment) |
| **M4 — Beta** | `v1.0.0-beta1` | Prove retention | 50–100 real users on TestFlight + Play internal. Dish catalog ≥ 300. D7 measured. Crash-free > 99 %. Accessibility pass on 10 primary flows. | 4 w |
| **M5 — Launch** | `v1.0.0` | Consumer-only public launch | Live on both stores, staged rollout, alerting on, rollback lever tested. | 2–3 w |
| **M6 — Ecosystem** | `v1.1.0` | Reopen gym + coach deliberately | 5–10 pilot gyms/coaches. Payout rail live. `BLK-09` closed. | 6–8 w |
| **M7 — Scale** | `v1.2.0`+ | Search, leaderboards, BigQuery, Cloud Tasks fan-out | Supports 10k → 100k users | ongoing |

**Team-scaled estimates to M5 (public launch):** solo **4–6 months** · 2 engineers **2.5–3.5 months** ·
5 engineers **1.5–2.5 months** (store review is an irreducible 1–2 weeks of wall clock).
**With the consumer-only scope cut applied (§1.9):** solo **2.5–3.5 months** · 2 engineers **1.5–2 months**.

### 1.9 Locked scope decision — consumer-only v1

**Decision:** cut **gym, coach, programs, marketplace, commissions and payouts** from v1.0.

**Rationale.** Those five domains are ~25,000 LOC across 19 screens, blocked on the same two defects
(`BLK-05`, `BLK-03`), serving zero validated demand. Cutting them removes `BLK-07`, `BLK-09`, the payout
gap, and most of `BLK-05`'s blast radius — turning a 4–6 month solo path into 2.5–3.5 months.

The gym and coach ecosystems are the **most strategically valuable assets in this codebase** — a
three-sided marketplace consumer trackers do not attempt. That is exactly why they should launch *after*
the consumer product has proven retention, in **M6**, not alongside an unvalidated one.

**In v1.0:** auth · onboarding · AI meal planning · food/weight/water/exercise logging · nutrition
analytics · recipes · cooking mode · shopping list · community feed · chat · notifications · achievements ·
streaks · premium subscription · referral.
**Deferred to M6+:** everything gym, coach, program, marketplace, commission, payout, white-label.
Those screens stay in the codebase behind kill-switches (`AppConfigService.isFeatureEnabled`) — not deleted.

---

## §2 — CRITICAL BLOCKERS

---

#### `BLK-01` ✅ Closed — Release builds silently served hardcoded fake AI meal plans and recipes

**Status** ✅ Closed 2026-08-01 · **Priority** Critical · **Complexity** S · **Est** 1–2 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** AI Architect
**Labels** `ai` `data-integrity` `release-blocker` `health-safety` `silent-failure`
**Modules** AI · Frontend · Product · Security
**Files** `lib/core/services/ai/ai_service.dart` · `lib/core/services/weekly_meal_plan_service.dart` ·
`lib/core/services/recipe_generation_service.dart` · `lib/core/services/app_initialization_service.dart` ·
`lib/screens/home/home.dart` · `lib/screens/explore/explore_screen.dart` ·
`test/meal_plan_ai_unavailable_test.dart` (new)
**Dependencies** — · **Required before** `BLK-04`, `STORE-01`, `AI-02`, everything in M4
**Blocking** Was the entire v1 launch. The single most serious defect in the repository.

**What was wrong**

`isConfigured` is defined as `_proxyUrl != null || (_apiKey != null && kDebugMode)`. `_proxyUrl` is
populated from `RemoteConfigService().aiProxyUrl` (defaults `''`) and `AppConfig.aiProxyUrl` (defaults
`''`). So **in a release build with default configuration `isConfigured == false`**, and
`generateCompletion` returned 135 lines of hardcoded JSON: seven identical days of
`geleneksel_menemen` / `somonlu_kinoa_bowl` / `izgara_somon_sebze` / `smoothie_bowl_protein`, and a
"Mock Healthy Stir Fry" recipe. All four mock dish IDs **exist in `dish_data.dart`**, so the fabricated
plan rendered as a completely plausible real one. `weekly_meal_plan_service.dart` and
`recipe_generation_service.dart` had **zero** `isConfigured` checks (`ai_insight_service.dart`,
`food_analysis_service.dart`, `coach_client_detail_screen.dart` already guarded correctly).

**What changed**
- The 135-line mock JSON block **deleted** from `ai_service.dart` (not disabled, not flag-gated).
  `generateCompletion` now throws `AIFatalException` when `!isConfigured`.
- `WeeklyMealPlanService._generateAndSaveMealPlan` / `.generatePlanAlternates` and
  `RecipeGenerationService.generateRecipe` guard `isConfigured` up front and `rethrow` on
  `AIFatalException` past their generic catch, instead of swallowing it into a silent `null`/`[]`.
- `home.dart` (`_loadWeeklyPlan`, `_generateWeeklyPlan`) catches `AIFatalException` specifically,
  logs a `CrashlyticsService` error, and renders a branded `AppErrorState` (title/message/retry) in
  place of the meal-plan section — never a plan, never a blank screen.
- `explore_screen.dart`'s recipe generation catches `AIFatalException` specifically, rolls back the
  AI credit, and shows the same branded error copy.
- `meal_plan_comparison_sheet.dart` needed **no change** — its existing generic `catch (_)` already
  rolls back the credit and shows a real error state for any exception, `AIFatalException` included.
- `AppInitializationService` logs a `CrashlyticsService` **error** (not a warning) at startup when
  `kReleaseMode && !AIService().isConfigured` — a misconfigured release build is now loud on launch,
  not discovered from a user report.
- 4 new EN/TR key pairs (`home.ai_unavailable_title/message`, `explore.ai_unavailable`, reusing
  `common.retry`); `i18n_parity_test.dart` passes.

**Acceptance criteria — verified**
- ✅ Mock JSON block deleted: `grep -c "Mock Healthy Stir Fry\|geleneksel_menemen" lib/core/services/ai/ai_service.dart` → `0`.
- ✅ `generateCompletion` throws `AIFatalException` when `!isConfigured` (read + `flutter analyze lib/` 0 errors).
- ✅ Both services guard `isConfigured` and surface a real error state.
- ✅ `AppInitializationService` startup Crashlytics assertion added.
- ✅ Widget test: `test/meal_plan_ai_unavailable_test.dart` asserts the exact `AppErrorState` copy
  `home.dart` falls back to renders correctly and no plan/button artifact leaks through.
  **Scope note:** the test exercises `AppErrorState` directly with `onRetry` omitted, not a fully
  mounted `HomeScreen` — `AppButton` (rendered whenever `onRetry` is set) reads `ThemeProvider`, whose
  constructor touches `FirebaseAuth.instance` synchronously, and this repo has no Firebase platform
  mocks (ADR-004). Full-screen mounting and the retry-tap path remain unverified by automated test;
  the retry callback itself is a one-line `_generateWeeklyPlan(user)` call, confirmed by reading.
- ⚠️ **Partial manual verification** — ran the app on the iOS Simulator (debug build; a true
  `--release` run isn't possible on any Simulator, Flutter hard-blocks it there regardless of app)
  with `AIService.isConfigured` temporarily forced to `false` (reverted before commit — confirmed via
  `git diff`). `kDebugMode` is a framework compile-time constant the fix doesn't re-derive at runtime,
  so forcing `isConfigured` false exercises the identical downstream branch a release build would
  take. The debug console confirmed no crash and no fabricated content at any point. What it did
  **not** confirm: the live-rendered `AppErrorState` on `home.dart`, because this dev account has a
  pre-existing cached meal plan — `weekly_meal_plan_service.dart:37`'s `Using cached meal plan for
  user ...` log line fired, which is correct, intentional cache-hit behaviour that returns before ever
  reaching the `isConfigured` guard. Reaching the guard live would need either a fresh account with no
  cached plan or invalidating this real account's cached data — deliberately not done here to avoid
  mutating real user state without cause. Separately (and unrelated to this fix): `ExploreScreen`
  (recipe generation) has no navigation route anywhere in the app currently — `grep -rn
  "ExploreScreen("` finds only its own constructor — so its guard couldn't be exercised live either;
  flagged as a pre-existing dead-code condition, not something this task introduced or should fix.
  The static verification above (guard → throw → catch → `AppErrorState`, confirmed by reading every
  link in the chain) and the widget test stand as the verification of record for this closure.
- ✅ `flutter analyze lib/` — 0 errors, 25 infos (unchanged baseline). `flutter test` — 79/79 pass
  (78 pre-existing + 1 new).

**Residual / explicitly not in this closure**
- `BE-01` — deploy `aiProxy`, set `ai_proxy_url` in `app_config/global`. **Now a hard launch
  dependency**: without it every release build shows the honest error state forever, never a working
  plan. Removing the fabrication fallback makes this visible instead of silently degraded — that is
  the point of this fix, not a new problem it created.
- `AI-07` — a deterministic, catalog-based fallback plan (clearly labelled non-AI) when the model is
  unavailable, as an alternative to the bare error state. Not built; out of scope here.
- `AI-08` — `AiChatService`'s fallback still leaks a "need an API key" string to end users. Untouched;
  different call path, different exception shape, tracked separately.
- `TEST-03` — the broader 10-screen widget-test suite (loading/empty/error/success with faked
  services) remains open; only the BLK-01 meal-plan-unavailable slice is covered now.

**Future improvements** `AI-11` provider abstraction so a second provider can serve as a real fallback.

---

#### `BLK-02` ✅ Closed (code) — `NSPhotoLibraryUsageDescription` missing — iOS crash and guaranteed App Store rejection

**Status** ✅ Closed 2026-08-01 (code-complete; device verification blocked on `BLK-16`) · **Priority** Critical · **Complexity** XS · **Est** 1 h
**Version** v0.9.7 · **Milestone** M1 · **Owner** Staff Flutter Engineer
**Labels** `ios` `store-blocker` `crash` `permissions`
**Modules** Frontend · Store · Legal
**Files** `ios/Runner/Info.plist` · `scripts/check_ios_permissions.sh` (new) · `.github/workflows/ci.yml` ·
`lib/screens/profile/profile_screen.dart:333` (already correct) · `lib/screens/chat/chat_detail_screen.dart:119` ·
`lib/screens/community/widgets/create_post_card.dart:388` (already correct) · `lib/screens/gym/gym_setup_screen.dart:887` ·
`lib/screens/coach/coach_application_screen.dart:246` (already correct) · `lib/screens/home/food_scan_screen.dart:514`
**Dependencies** — · **Required before** `STORE-03`, `CI-04`, all of M4
**Blocking** Was any iOS distribution whatsoever.

**What was wrong**

`Info.plist` declared `NSCameraUsageDescription`, `NSLocationWhenInUseUsageDescription`,
`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription`, `NSUserTrackingUsageDescription`
— and **no photo-library string**. `ImageSource.gallery` is used in six screens. On iOS the app
terminates immediately when the picker is invoked, and App Review rejects binaries that touch the photo
library without a purpose string.

A second, related gap found during verification (not previously tracked): three of the six gallery
call sites — `chat_detail_screen.dart`, `gym_setup_screen.dart`, and `food_scan_screen.dart` — called
`ImagePicker().pickImage()` directly with **no** `PermissionService` import or call anywhere in the
file. The other three (`profile_screen.dart`, `coach_application_screen.dart`, `create_post_card.dart`)
already primed correctly. Confirmed by grep, not assumed: `grep -rn "PermissionService"` on all three
files returned nothing before this fix.

Android declares `READ_MEDIA_IMAGES` and `READ_EXTERNAL_STORAGE`, so this was iOS-only.

**What changed**
- `NSPhotoLibraryUsageDescription` added to `Info.plist`, honest copy covering all six real use cases
  (profile picture, food logging, community posts, gym logos, coach applications). Validated with
  `plutil -lint` — well-formed.
- `NSPhotoLibraryAddUsageDescription` **not** added — confirmed by grep (`PHPhotoLibrary`,
  `image_gallery_saver`, `package:gal` all absent from `lib/`, `pubspec.yaml`) that no flow writes to
  the library. Documented here per the acceptance criterion, not added speculatively.
- `chat_detail_screen.dart`'s `_pickAndSendImage`, `gym_setup_screen.dart`'s `_LogoPickerSection._pickImage`,
  and `food_scan_screen.dart`'s `_pickPhoto` now call `PermissionService().requestPhotos(context)` (or
  `.requestCamera()` for `food_scan_screen.dart`'s shared camera/gallery method, branched on `source`)
  before the picker, matching the pattern already used correctly elsewhere. All six sites now prime
  consistently.
- New `scripts/check_ios_permissions.sh`: greps `pubspec.yaml` for `image_picker`, `mobile_scanner`,
  `geolocator`, `speech_to_text` and fails if `Info.plist` is missing the usage-description key(s)
  each implies. Wired into `ci.yml`'s `analyze-and-test` job, right after checkout (no Flutter/Java
  needed, so it fails fast). Verified it actually catches the original defect: wrote and ran the
  script **before** touching `Info.plist` — it failed with the exact missing-key message against the
  real, still-broken file; added the fix; re-ran — passed.

**Acceptance criteria — verified**
- ✅ `NSPhotoLibraryUsageDescription` added with honest, specific copy.
- ✅ `NSPhotoLibraryAddUsageDescription` — confirmed unnecessary, documented above.
- ⚠️ **Not verified on a physical iPhone** — none available. Verified instead on the iOS Simulator
  (fresh debug build): reset the app's photo permission (`xcrun simctl privacy ... reset photos`),
  triggered the avatar picker on `profile_screen.dart` — the in-app `PermissionPrimer` ("Fotoğraf
  Kitaplığı") fired correctly, then the OS-level request resolved to permanently-denied (a
  Simulator-specific quirk — no seeded Photos library — not a crash), and `PermissionService`
  correctly routed to its Settings-redirect sheet; "Ayarları Aç" opened iOS Settings with Cookrange
  still alive underneath. **No crash at any point** — this is the literal defect BLK-02 fixes, and
  it's gone. The native "Allow full access / Select Photos / Don't Allow" sheet itself wasn't
  observed on Simulator; physical-device confirmation is still owed once one is available.
- ✅ `PermissionService` photo priming fires before the OS dialog on iOS — now true for all six sites
  (three already were; three fixed here).
- ✅ Preflight script added, wired into CI, verified to actually fail on the original defect and pass
  after the fix (not just written and assumed correct).

**DoD** §0.5 plus: `flutter build ipa` succeeds and photo pick works on device — **not done**. Building
a signed `.ipa` needs an Apple signing identity, which doesn't exist yet (`BLK-16`). `flutter analyze
lib/` (0 errors, 25 infos, unchanged baseline) and `flutter test` (79/79) both pass; that's the DoD
that's actually achievable before `BLK-16` closes.

**Technical Notes**
The preflight check is the real fix. The missing string was a symptom of never having run the app on
an iOS device through the photo flow. The check table currently covers `speech_to_text`,
`image_picker`, `geolocator`, `mobile_scanner` — a new plugin needing a new `NS*UsageDescription` still
needs a manual addition to both `Info.plist` and `scripts/check_ios_permissions.sh`.

**Risks** None realized. The one bit of scope growth (priming the three missed call sites) was a
same-category fix using an already-proven pattern, not a new one — low risk, and leaving it
inconsistent would have meant three screens still skipping the app's own rationale sheet.

---

#### `BLK-03` 🔥 Push notification fan-out is wired to a path nothing writes; admin writes to a path with no rule

**Status** 🔥 Critical · **Priority** Critical · **Complexity** M · **Est** 2–3 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** Firebase Architect
**Labels** `push` `notifications` `retention` `firestore-rules` `security` `silent-failure`
**Modules** Backend · Firebase · Frontend · Security
**Files** `functions/index.js:586` (trigger path) · `lib/core/services/notification_service.dart:14` (client write path) · `lib/core/services/admin_service.dart:234`, `:316`, `:353`, `:387`, `:546` · `firestore.rules:94-99`
**Dependencies** — · **Required before** `NOTIF-02`, `GYM-02`, `COA-02`, all retention work in M4
**Blocking** Every retention loop that depends on push. Gym and coach approval entirely.

**What exists / what is missing**

There are **two divergent notification paths and each is broken differently**:

1. `NotificationService` writes to `users/{uid}/notifications` — this path **has** a rule
   (`firestore.rules:94`) and in-app notifications work. But **no Cloud Function listens to it**, so
   likes, comments, reactions, friend requests, follows, referrals and streak milestones send **zero
   push**.
2. `onInAppNotificationCreated` (`functions/index.js:586`) listens on **`notifications/{uid}/items/{docId}`**.
   `AdminService` writes there for coach/gym approval and rejection. That path has **no security rule at
   all** → catch-all deny (`firestore.rules:680-682`) → the write fails → and because it is part of a
   **batch** that also grants the role, **the entire approval transaction fails**.

`onChatMessageCreated` uses the correct path (`chats/{chatId}/messages/{msgId}`), which is why chat push
is the one thing that works.

**Acceptance Criteria**
- One canonical path chosen and documented. **Recommended:** `notifications/{uid}/items/{id}` (matches the existing trigger and `CLAUDE.md`).
- A security rule exists for the chosen path.
- `NotificationService` and `AdminService` both write the chosen path.
- Notification creation moved **server-side** into a callable/trigger that derives `actorUid` from `request.auth` and re-fetches `actorName` — closing the forgery hole in the same change (`SEC-06`).
- Client `create` on the notification path set to `if false`.
- Verified on **two physical devices**: like a post → recipient receives push in their locale with the correct actor name.
- Mute groups respected; a muted group receives in-app but no push.
- Stale-token removal verified.
- Coach and gym approval completes end to end and the applicant receives both in-app and push.
- Tap-routing works from cold start, background and foreground.

**DoD** §0.5 plus: a Firestore rules test asserts a client cannot write another user's notification.

**Technical Notes**
Do **not** just add a permissive rule for the second path — that would open push forgery (`SEC-06`).
Fix the path mismatch and move authorship server-side in one change. This is the cleanest opportunity to
close both defects at once.

**Risks**
Migration: existing in-app notifications live at `users/{uid}/notifications`. Either backfill-copy them
to the new path or have the reader stream both during a deprecation window. Choose and document.

**Future improvements** `NOTIF-05` notification grouping/collapsing; `NOTIF-06` rich push with images.

---

#### `BLK-04` 🔥 Monetization is non-functional end to end

**Status** 🔥 Critical · **Priority** Critical · **Complexity** L · **Est** 1–2 w engineering + store latency
**Version** v0.9.9 · **Milestone** M3 · **Owner** CTO + Product Manager
**Labels** `monetization` `iap` `store-blocker` `revenue`
**Modules** Monetization · Backend · Store · Frontend · Legal
**Files** `functions/.env` (`APP_ENV=development`, all store creds commented) · `functions/purchases.js:59-66` (`appleConfigured()`) · `lib/core/services/billing_service.dart:13` (TODO) · `:72-75`, `:104-113` (contract violation) · `:206-209` (singleton dispose)
**Dependencies** `BLK-16` (developer programmes) · **Required before** `MON-04`, M4 pricing validation
**Blocking** All revenue. The business case.

**What exists / what is missing**

The *design* is sound and largely built: `entitlements/{uid}` server-only ledger, receipt validation
against the App Store Server API and Google Play Developer API, token dedupe via
`processed_purchases`, refund/chargeback revocation webhooks, a paywall that correctly refuses to show
products it cannot load.

None of it can execute:
- `functions/.env` sets `APP_ENV=development`; every Apple/Google credential is commented out. `appleConfigured()` returns false → `verifyApple` throws `apple_not_configured` → **fails closed**. Correct behaviour; non-functional state.
- No products registered in either store. `_loadProducts()` will return all three IDs in `notFoundIDs`.
- `purchase()` and `buyAiCreditsTopUp()` use `firstWhere(orElse: () => throw StateError(...))` while their doc comments promise "Returns `false`" — an uncaught `StateError` reaches the UI.
- `BillingService.dispose()` disposes a **singleton's** `ValueNotifier`; any re-initialisation afterwards crashes.
- Apple JWS `x5c` certificate chain is not verified (acknowledged at `purchases.js:90-93`).

**Acceptance Criteria**
- Three products live in App Store Connect **and** Google Play: `com.cookrange.premium.monthly`, `com.cookrange.premium.yearly`, `cookrange_ai_credits_10` (Consumable in both).
- Apple `.p8` + Key ID + Issuer ID + Bundle ID and Google Play service-account JSON stored as Function secrets (**not** `functions/.env`).
- `APP_ENV=production`.
- `purchase()` returns `false` instead of throwing when a product is absent; doc comment and behaviour agree.
- `dispose()` no longer disposes singleton state (or the singleton is made disposable-safe).
- Apple JWS chain verified via `@apple/app-store-server-library`.
- **A real sandbox purchase on each platform grants a real `entitlements/{uid}` record and mirrors `subscription_tier`.** This is the gate.
- Refund in sandbox revokes the entitlement via `appStoreNotifications` / `playRtdn`.
- Restore Purchases verified on a second device.
- Credit top-up grants exactly 10 bonus credits, server-side, once per transaction.

**DoD** §0.5 plus a recorded sandbox purchase→entitlement→revoke cycle on both platforms.

**Technical Notes**
Store review and product-approval latency is wall-clock, not headcount. Start `BLK-16` and product
registration on day one of M1 even though the code work lands in M3.

**Risks**
Apple/Google reject digital-goods revenue routed outside IAP. Keep program sales on IAP; route only
real-world coaching services through a payout provider (`REF-04`). Legal review required.

**Future improvements** `MON-07` richer credit packs; `MON-08` annual-vs-monthly paywall experiment; `MON-09` family sharing; `MON-10` billing-retry / grace-period handling; `MON-11` promo codes and offer codes.

---

#### `BLK-05` ⚠️ Code complete, `syncAdminClaim` NOT DEPLOYED — the entire admin surface is unreachable

**Status** ⚠️ Code + tests + docs done 2026-08-01 — **Cloud Function not yet deployed**, held for
explicit go-ahead (deploying live, privileged, auto-triggered code is a bigger risk than a rules-only
change; asked separately from this pass) · **Priority** Critical · **Complexity** S · **Est** 1–2 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** Security Engineer
**Labels** `admin` `authorization` `security` `operations` `doc-drift`
**Modules** Security · Firebase · Frontend · Documentation
**Files** `firestore.rules:27-35,45-60` (`isAdmin()` + corrected comment) · `functions/admin.js` (new —
`syncAdminClaim`) · `functions/index.js` (export) · `lib/core/providers/user_provider.dart` (`isAdmin`
state) · `lib/core/widgets/side_menu.dart:401`, `lib/screens/home/widgets/role_quick_card.dart:25`,
`lib/screens/profile/settings_screen.dart:1328` (3 client gates, re-pointed) ·
`lib/core/services/admin_status_service.dart` (dead reads removed) · `docs/SECURITY.md` §4 (runbook +
corrected path) · `docs/DATABASE.md`, `docs/API.md` (schema/surface entries) ·
`test/firestore_rules/rules.test.mjs` (3 new tests)
**Dependencies** — · **Required before** `BLK-03`, `MOD-01`, `GYM-02`, `COA-02`, `ADM-*`
**Blocking** All moderation, all application review, all cost visibility, all operational capability —
**still blocking in production** until `syncAdminClaim` is deployed; see below.

**What was wrong**

`isAdmin()` requires `admin_roles/{uid}.is_admin == true`. `grep -rn "admin_roles" lib/ functions/`
returned **zero results** — nothing in the client or in any Cloud Function created that document.

Meanwhile the client showed the admin UI based on `user.hasRole(UserRole.admin)`, reading `user_roles`
from the **client-writable** user doc — confirmed at **three** call sites, not just the one originally
named (`side_menu.dart`, plus `role_quick_card.dart` and `settings_screen.dart`, found while fixing the
first). The rules deliberately leave `user_roles` unlocked (documented at `firestore.rules:45-56` with
the reasoning that real admin power is server-gated, so a self-written `user_roles: ['admin']` is
"cosmetic").

Net effect: **anyone could summon the admin UI; nobody could use it.** ~7,400 LOC across 9 admin
screens presented a fully-populated interface that failed with permission-denied on every read.

Compounding: the "wrong path" documentation drift wasn't in `CLAUDE.md` (checked — it doesn't mention
either path currently, so that specific claim in this card was already stale by the time this pass
started). It **was** live in two other places: `firestore.rules`'s own comment at line 53, and
`docs/SECURITY.md` §4 — both said admin power was gated by `admin/status/{uid}` (actually ban state,
an unrelated concept) when `isAdmin()` has always checked `admin_roles/{uid}`. Both fixed.
`AdminStatusService._firestoreMaintenanceMode()`/`_firestoreMinVersion()` read `admin_config/global`,
which is admin-read-only, so every normal user's call was denied and swallowed by `catch (_) {}` — a
permanently dead code path silently falling back to Remote Config.

**What changed**
- New Cloud Function `syncAdminClaim` (`functions/admin.js`): Firestore `onWrite` trigger on
  `admin_roles/{uid}` that mirrors `is_admin` onto a Firebase Auth custom claim (`admin: true`, or
  cleared entirely on non-admin/delete) via `admin.auth().setCustomUserClaims()`. No other custom
  claims exist anywhere in this codebase (confirmed by grep), so a full replace is safe — noted in
  the function's own comment in case that ever changes.
- `UserProvider` gained `isAdmin`, populated from `getIdTokenResult().claims['admin']` after every
  `loadUser()` (not force-refreshed — a newly-granted admin sees it after their next natural hourly
  token refresh or a sign-out/in, not instantly; documented as a real, acceptable limitation, not a
  bug). Fails closed on any error.
- All three client-side gates switched from `user.hasRole(UserRole.admin)` to
  `context.watch<UserProvider>().isAdmin` (or the already-in-scope `userProvider.isAdmin` in
  `settings_screen.dart`). `profile_screen.dart`'s role chip and `create_post_card.dart`'s
  author-badge exclusion are display-only, not security gates — confirmed by reading, left alone.
- `AdminStatusService`'s two dead `admin_config/global` reads deleted outright; `checkStatus` now
  reads Remote Config directly, matching what every real call already fell back to.
- `docs/SECURITY.md` §4 gained the bootstrap runbook: `admin_roles/{uid}` is `write: false`
  unconditionally (even for an admin) — the console is the **only** way to create it. No
  `functions:shell` callable was built; a function that can grant admin is itself a
  privilege-escalation surface, and the acceptance criteria only asked for one **or** the other.
- 3 new rules tests: `admin_roles` denies client writes even from a seeded admin; a
  console-provisioned admin (`admin_roles/{uid}` seeded directly, the only way it's ever created for
  real too) can read `admin_audit`/`ai_usage_logs`/`admin_config`; a non-admin is denied on all three.

**Acceptance criteria — status**
- ✅ `admin_roles/{uid}` documented with a runbook (`docs/SECURITY.md` §4).
- ✅ Bootstrap path: console step only, by design (see Technical Notes below for why not a callable).
- ✅ Client admin UI gated on the `admin` custom claim, all three call sites.
- ✅ `syncAdminClaim` written — sets the claim when `admin_roles/{uid}` is written.
  **⚠️ Not deployed** — see Residual below.
- ✅ `AdminStatusService`'s dead reads removed.
- ✅ `CLAUDE.md` — no change needed, confirmed it doesn't currently reference either path.
- ⚠️ **Not verified end-to-end** (provisioned admin can list users / review / cost dashboard / edit
  config; non-admin sees no UI) — this needs `syncAdminClaim` live and a real admin session, neither
  possible before the deploy. The client-gate logic is verified by reading and by `flutter analyze`;
  the rule logic is verified by the new rules tests (CI-confirmed once pushed).

**DoD** §0.5 plus a rules test asserting a non-admin is denied on `admin_audit`, `ai_usage_logs`,
`admin_config` — **met**, see above.

**Technical Notes**
Three parallel admin/config identity concepts existed (`admin_roles`, `admin/status`, `user_roles`).
Collapsed to two: `admin_roles/{uid}` (server truth) + a mirrored custom claim (client truth). Ban
state stays separate at `admin/status/{uid}` — confirmed still correctly used only for that, by
`admin_service.dart`'s ban-flag read/write.

No bootstrap callable was built. A `functions:shell`/HTTPS callable that can grant admin is a new
privilege-escalation surface with its own hard design questions (self-destruct after first use? IP
allowlist? time-boxed?) — the acceptance criteria explicitly offered a console step as an alternative,
and it's simpler and has no new attack surface. If a fresh-environment bootstrap becomes a recurring
pain point, revisit as a separate, carefully-scoped follow-up.

**Residual — the actual production fix is not live yet**
`syncAdminClaim` has zero effect until deployed (`firebase deploy --only functions`). Until then,
`admin_roles/{uid}` can still be created via the Console (per the runbook), but the custom claim
won't sync automatically — the client would need `user.getIdTokenResult(true)` forced after a manual
claim-setting workaround, which defeats the point. **This is intentionally the one piece of BLK-05
left for a human decision**: deploying a new, automatically-triggered Cloud Function that grants
admin access is a materially bigger risk than a declarative rules change (arbitrary code execution
with full Admin SDK privileges vs. a syntax-checked, easily-diffed rules file), so it's flagged
separately rather than folded into this pass. Once deployed and confirmed, the ~30 downstream
`ADM-*`/`MOD-01`/`GYM-02`/`COA-02`/etc. cards that are "code-verified, unreachable until `BLK-05`"
should be revisited in one pass — not done here to avoid a premature update that would need
re-walking if the deploy surfaces something.

**Risks**
Granting the first admin is a manual console step by design (see Technical Notes). Document it
precisely or a fresh environment is un-administrable — the runbook in `docs/SECURITY.md` §4 is that
documentation.

---

#### `BLK-06` ✅ Closed — `meal_plan_history` has a composite index but no security rule

**Status** ✅ Closed 2026-08-01 — rule written, tested in CI, and deployed to the live project · **Priority** Critical · **Complexity** XS · **Est** 2 h
**Version** v0.9.7 · **Milestone** M1 · **Owner** Firebase Architect
**Labels** `firestore-rules` `silent-failure` `dead-feature`
**Modules** Firebase · Backend
**Files** `firestore.rules` (rule added) · `lib/core/services/weekly_meal_plan_service.dart:191-200` (write, now also reports to `CrashlyticsService`) · `:318-333` (read, same) · `lib/screens/home/meal_plan_history_screen.dart` (298 LOC, two more catch sites given the same treatment) · `firestore.indexes.json` (index already existed) · `test/firestore_rules/rules.test.mjs` (new test)
**Dependencies** — · **Required before** `NUT-05`
**Blocking** Was a shipped, documented, indexed feature that has never worked.

**What was wrong**

`users/{uid}/meal_plan_history/{key}` is written on every plan save and read by a 298-line screen. It
has a composite index. It had **no rule** → catch-all deny. Both sides swallowed the failure:
`unawaited(...).catchError((e) => debugPrint(...))` on write, `catch (e) { ... return []; }` on read.
The screen therefore rendered `AppEmptyState` forever, and in release `debugPrint` produced no output
at all.

**What changed**
- Added `match /meal_plan_history/{historyId} { allow read, write: if isOwner(uid); }` to
  `firestore.rules`, as a sibling to the existing `meal_plans/{planId}` block — same shape, same
  `isOwner(uid)` guard already used by a dozen other subcollections in this file.
- Both named call sites in `weekly_meal_plan_service.dart` now report to `CrashlyticsService` in
  addition to `debugPrint` (matching the established `coach_review_service.dart` idiom — dev visibility
  *and* production signal, not one replacing the other).
- Went a little further than the literal acceptance criteria while in the file: `meal_plan_history_screen.dart`
  had two of its own catch sites in the same state — `_loadHistory`'s catch had no Crashlytics call, and
  `_restorePlan`'s `await _service.restorePlan(...)` had **no catch at all**. Both now report. No new
  user-facing copy/UI added — this is an observability fix, not a UX feature; flagging the scope
  addition explicitly rather than leaving it unmentioned.
- New rules test in `test/firestore_rules/rules.test.mjs`: seeds a doc, asserts a non-owner is denied
  both read and write, asserts the owner succeeds at both.

**Acceptance criteria — status**
- ✅ Rule added and **deployed** — `firebase deploy --only firestore:rules --project cookrange-app`,
  confirmed by the CLI's own output ("released rules firestore.rules to cloud.firestore"). Two
  pre-existing compiler warnings shown (`hasNoExtraFields` unused, `request` an invalid variable
  name) are on lines this change didn't touch — unrelated, not introduced here.
- ✅ Both named call sites route to `CrashlyticsService` (plus two adjacent ones, see above).
- ⚠️ **Not verified end-to-end on a device** (generate → regenerate → history lists it → restore) —
  the rule itself is proven correct (rules test, below) and now live, but the full user-facing flow
  through a real AI-generated plan wasn't walked on a simulator or device. Reasonable next
  verification step if this needs a final sign-off, not blocking given the rule-level proof.
- ✅ Rules test written **and confirmed passing for real**: CI's `firestore-rules` job (run
  [#50](https://github.com/burcok/cookrange/actions/runs/30697804480), commit `7f421b3`) — 45s,
  part of an all-green run. Not run locally first — this machine has no local Java, so the emulator
  can't start here (same pre-existing constraint as the rest of this suite, `BLK-13`/`docs/TESTING.md`)
  — CI was the first real execution, and it passed.

**DoD** §0.5 — met. Code, test, and deploy all done; the CLI confirmed the rule is live.

**Technical Notes**
This is the cleanest illustration of `DEBT-01`. The rule was simply never added, and nothing in the
system was capable of reporting that. The rule fix is here; `DEBT-01` (the systemic swallow-and-log
pattern) remains its own, much larger, separately-tracked item.

**Deploy note:** deployed 2026-08-01 with explicit user go-ahead (asked first — rules changes are a
live, shared-infrastructure action). Per `ADR-008`'s "server write paths ship before rules lock"
ordering: this rule only *added* an owner-only allow on a path nothing else touched, so there was no
sequencing hazard.

---

#### `BLK-07` 🔥 Gym logo upload writes to `gyms/…`; Storage rules only permit `gym_logos/…`

**Status** 🔥 Critical · **Priority** Critical · **Complexity** XS · **Est** 4 h
**Version** v1.1.0 · **Milestone** M6 (deferred with gym scope) · **Owner** Firebase Architect
**Labels** `storage-rules` `silent-failure` `gym` `security`
**Modules** Firebase · Backend · Security
**Files** `lib/core/services/storage_upload_service.dart:145` (`gyms/$gymId/logo.jpg`) · `storage.rules` (`gym_logos/{gymId}/{fileName}`) · `functions/media.js` `SCAN_PREFIXES` (watches `gyms/`)
**Dependencies** — · **Required before** `GYM-03`
**Blocking** Gym profile setup.

**What exists / what is missing**

Three components disagree on one path:
- Upload writes `gyms/{gymId}/logo.jpg`.
- `storage.rules` grants only `gym_logos/{gymId}/{fileName}` → `gyms/` hits the catch-all `allow read, write: if false` → **upload always denied**.
- `media.js SCAN_PREFIXES` includes `'gyms/'` — matching the broken upload path, so if the upload is fixed by changing the *rules*, scanning works; if fixed by changing the *upload*, scanning silently stops.

Worse, the dead `gym_logos` rule contains a real hole: `allow write: if isAuthenticated()` **and**
`allow delete: if isAuthenticated()` — any authenticated user could overwrite or delete any gym's logo.
It is inert today only because nothing writes there.

**Acceptance Criteria**
- One canonical prefix chosen: **`gyms/{gymId}/logo.jpg`** (matches upload and scanner).
- `storage.rules` grants that prefix, scoped to the gym owner — resolved via a Firestore-independent scheme (owner uid embedded in the path, or a signed-upload callable, since Storage rules cannot query Firestore).
- The `isAuthenticated()` write/delete hole is closed, not carried over.
- The dead `gym_logos` rule deleted.
- `media.js SCAN_PREFIXES` verified against the final prefix.
- Verified on device: a gym owner uploads a logo, sees it render; a non-owner is denied.

**DoD** §0.5 plus a Storage rules test for owner-vs-other.

**Technical Notes**
Storage rules cannot perform Firestore lookups. Either encode `ownerUid` in the path
(`gyms/{ownerUid}/{gymId}/logo.jpg`) or move uploads behind a callable that mints a short-lived signed
URL after checking ownership server-side. The callable is the better long-term answer and also fixes the
gym/coach application-document admin-access gap noted in `storage.rules`.

---

#### `BLK-08` 🔥 Any authenticated user can mutate any post's non-content fields

**Status** 🔥 Critical · **Priority** Critical · **Complexity** S · **Est** 1 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** Security Engineer
**Labels** `firestore-rules` `integrity` `abuse` `community`
**Modules** Security · Firebase · Backend
**Files** `firestore.rules:195-199`
**Dependencies** — · **Required before** `COM-04`, `GAM-01`
**Blocking** Community integrity; any leaderboard or ranking derived from post metrics.

**What exists / what is missing**

```
allow update: if isAuthenticated()
  && (isPostOwner(resource.data)
    || (!request.resource.data.diff(resource.data).affectedKeys()
         .hasAny(['authorId', 'content', 'imageUrls', 'tags'])));
```

The intent was "let anyone bump like/reaction counters." The effect is that **any authenticated user can
write any field not in that four-item deny-list** — `likeCount`, `commentCount`, `groupId`,
`is_announcement`, `timestamp`, `createdAt`, `authorRole`, `metadata`. A user can inflate their own like
counts, move another user's post into a group, or mark it as an announcement.

**Acceptance Criteria**
- Counter updates restricted with `affectedKeys().hasOnly(['likeCount','commentCount','reactionCount'])` **and** a delta constraint (`request.resource.data.likeCount == resource.data.likeCount + 1` style), or moved entirely to a Cloud Function.
- **Preferred:** counters maintained by a Firestore trigger on the `likes`/`reactions`/`comments` subcollections; client `update` on counters set to `if false`.
- All other fields owner-only.
- Rules tests: non-owner cannot change `groupId`, `is_announcement`, `timestamp`, or set `likeCount` to an arbitrary value.
- Existing inflated counters reconciled by a one-off backfill Function (`ARCH-06` migration framework).

**DoD** §0.5 plus rules tests for each forbidden field.

**Technical Notes**
Server-maintained counters also fix the group `member_count` client-increment noted in the Phase 13
follow-ups, and the `checkins`/`achievement`/`squad`/`referral` counter gaps in `S23`. Do them together
as one "counters are server-authoritative" change.

**Risks** A trigger per like is a write amplification cost. Use sharded counters or debounced aggregation if volume warrants — see `PERF-06`.

---

#### `BLK-09` 🔥 `coach_uid == 'demo'` lets any authenticated user publish to the public marketplace

**Status** 🔥 Critical · **Priority** Critical · **Complexity** XS · **Est** 4 h
**Version** v1.1.0 · **Milestone** M6 (deferred with marketplace scope) · **Owner** Security Engineer
**Labels** `firestore-rules` `content-injection` `marketplace` `abuse`
**Modules** Security · Firebase · Backend
**Files** `firestore.rules:458-460` · `lib/core/services/demo_content_seeder.dart` · `lib/core/services/app_initialization_service.dart:322`
**Dependencies** `BLK-11` (move seeding server-side) · **Required before** `MKT-01`
**Blocking** Marketplace launch.

**What exists / what is missing**

```
allow create: if isAuthenticated()
  && (request.resource.data.coach_uid == request.auth.uid
      || request.resource.data.coach_uid == 'demo');
```

The `'demo'` exemption exists so `DemoContentSeeder` — which runs on **every client at app start** — can
seed three demo programs. It also lets any authenticated user write arbitrary documents into the public
`programs` collection.

Separately: seeding fake marketplace content into production from a user's phone is wrong independent of
the security hole.

**Acceptance Criteria**
- The `'demo'` exemption removed from `firestore.rules`.
- `DemoContentSeeder` removed from the client startup path.
- Demo content seeded by an **admin-invoked callable** or a one-off script in `lib/scripts/`, gated on a non-production environment (`INF-01`).
- Production contains **no** `coach_uid == 'demo'` programs; any existing ones are purged.
- Rules test: a non-owning user cannot create a program.

**DoD** §0.5.

**Technical Notes**
Same root cause as `BLK-11` — global reference data being seeded from clients. Fix both with one pattern:
reference/demo data is seeded server-side, never by the app.

---

#### `BLK-10` 🔥 User document is world-readable and contains email, IP address and device fingerprints

**Status** 🔥 Critical · **Priority** Critical · **Complexity** M · **Est** 3–5 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** DevSecOps + Legal
**Labels** `privacy` `gdpr` `kvkk` `firestore-rules` `pii` `legal-blocker`
**Modules** Security · Firebase · Legal · Backend · Frontend
**Files** `firestore.rules:68` · `lib/core/services/firestore_service.dart:102-106`, `:134`, `:144-150`, `:277`, `:309`, `:599-626`
**Dependencies** — · **Required before** `LEG-02`, `STORE-04`, all of M5
**Blocking** Lawful public launch in the primary market. Escalate to the board.

**What exists / what is missing**

`match /users/{uid} { allow read: if isAuthenticated(); }` — every authenticated user can read every
other user's document. Those documents contain:

| Field | Written at |
|---|---|
| `email` | `firestore_service.dart:134`, `:277`, `:309` |
| `last_login_ip` | `:102`, `:603` |
| `last_login_device`, `_device_type`, `_device_model`, `_device_os`, `device_brand`, `device_locale` | `:103-106`, `:606-626` |
| `login_devices[]`, `login_device_types[]`, `login_device_models[]`, `login_device_os[]` | `:144-150` |
| `fcm_token` | `push_notification_service.dart` |

IP address and email are personal data under both GDPR and KVKK. Device fingerprint arrays are a
tracking-grade identifier set. This is a health application handling body metrics, dietary restrictions
and allergy data, in a KVKK jurisdiction, in a repository whose own guide opens *"Legal-first is
non-negotiable."*

Health PII was already correctly isolated to `users/{uid}/private/nutrition` (Phase 9.7). This task
completes the job for identity and telemetry PII.

**Acceptance Criteria**
- A minimal **public** profile shape defined and documented: `displayName`, `photoURL`, `is_private`, `user_roles`, `streak`, `reputation_score`, `subscription_tier` (display only), `created_at`.
- Everything else moved to `users/{uid}/private/profile` (owner-only) or `users/{uid}/internal/telemetry` (server-only).
- `email` removed from the readable doc; searches that relied on it (`firestore_service.dart:697`) move to a callable or an admin-only path.
- `fcm_token` moved to a server-only doc.
- `last_login_ip` and device history moved to a server-only doc **with a retention policy** (`LEG-05`).
- `firestore.rules:68` read rule narrowed to the public shape.
- Backfill migration written, idempotent, logged (`ARCH-06`).
- Rules tests: user A cannot read user B's email, IP, device history or FCM token.
- `docs/DATABASE.md` + `docs/COMPLIANCE.md` updated; privacy policy re-checked against the new shape.

**DoD** §0.5 plus a rules test suite covering every relocated field.

**Technical Notes**
This is `S10` from `GO_LIVE.md` §5S P1, raised to blocker status. Sequence: create the new docs and
dual-write → migrate existing users → narrow the read rule → remove dual-write. Narrowing the rule
before the migration completes will break profile rendering for un-migrated users.

**Risks**
Many call sites read the user doc. Audit every `collection('users').doc(...)` read before narrowing.
`AdminService.searchUsers` and the admin user list are the highest-risk consumers.

**Future improvements** `SEC-15` retention/TTL job for telemetry; `SEC-16` PII-redacting logger.

---

#### `BLK-11` 🔥 The dish catalog cannot be seeded in-app, and 75 dishes is too few

**Status** 🔥 Critical · **Priority** Critical · **Complexity** M · **Est** 1 w + content
**Version** v0.9.7 · **Milestone** M1 · **Owner** Firebase Architect + Product Manager
**Labels** `data` `content` `bootstrap` `silent-failure` `ai`
**Modules** Database · Backend · AI · Product
**Files** `lib/core/services/app_initialization_service.dart:320` · `lib/core/services/dish_seeder_service.dart` · `firestore.rules:178` (`dishes` write requires `isAdmin()`) · `lib/core/data/dish_data.dart` (75 dishes, 3,046 LOC) · `lib/core/services/dish_service.dart:17`, `:56` · `lib/scripts/seed_db.dart`
**Dependencies** `BLK-05` (for the admin path) · **Required before** `AI-02`, `NUT-01`, all of M4
**Blocking** The core product feature on any fresh Firebase project.

**What exists / what is missing**

Three compounding problems:

1. **Unseedable.** The only in-app seeding path is `DishSeederService().seedIfEmpty()`, fired from
   `AppInitializationService` on **every client's** cold start. `dishes` write requires `isAdmin()`, and
   no admin exists (`BLK-05`) → the write is denied for every user, forever. There is **no local
   fallback**: `DishService.getAllDishes()` reads Firestore only. On a fresh project, meal planning is
   dead.
2. **Too small.** 75 dishes must fill 28 meal slots per week under dietary restrictions, allergen
   filtering and dislike exclusion. Users will see visible repetition within days.
3. **Capped.** `PromptService.generateWeeklyMealPlanPrompt` inlines the **entire catalog** at ~120 chars
   per dish. `functions/index.js:45` enforces `MAX_TOTAL_CHARS = 24000`. **Ceiling ≈ 180 dishes** before
   every request returns HTTP 413. Growing the catalog to fix (2) breaks the prompt. See `AI-03`.

Also: `dish_service.dart:17` is an unbounded `.get()` on the whole collection, called on every plan
generation; `:56` is an unbounded `.snapshots()` listener. Both violate the repo's own Performance
Playbook.

**Acceptance Criteria**
- Seeding removed from the client startup path.
- Seeding performed by an **admin callable** or a documented one-off script, idempotent, logged.
- `AI-03` (candidate pre-filter) landed **first**, so the catalog can grow past 180.
- Catalog expanded to **≥ 300 dishes** with correct macros, Turkish + English names, categories, meal types, tags and allergen data.
- `DishService.getAllDishes()` replaced with a bounded, filtered query.
- `getAllDishesStream()` paginated or replaced.
- A documented bootstrap runbook exists for a fresh environment.
- Verified on a **clean Firebase project**: run the seeder → generate a plan → 7 distinct days with no repeats.

**DoD** §0.5 plus a fresh-project bootstrap verified end to end.

**Technical Notes**
Reference data seeded from clients is an anti-pattern regardless of the rule outcome — it burns a
server-source read on every cold start for every user. Same fix pattern as `BLK-09`.

**Risks**
Content production for 225 additional dishes is real work — nutritionist review, photography or image
sourcing, TR/EN copy. Budget it as a content track, not an engineering task. Do not let it silently
block M1; land the mechanism in M1 and the volume in M4.

**Future improvements** `NUT-08` user-submitted dishes with moderation; `NUT-09` regional catalogs per locale.

---

#### `BLK-12` 🔥 GDPR erasure and export are both incomplete

**Status** 🔥 Critical · **Priority** Critical · **Complexity** M · **Est** 3–4 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** DevSecOps + Legal
**Labels** `gdpr` `kvkk` `privacy` `legal-blocker` `erasure` `export`
**Modules** Backend · Legal · Firebase · Security
**Files** `functions/account.js` (`deleteStoragePrefixes`) · `lib/core/services/storage_upload_service.dart:100` (real chat path) · `lib/core/services/data_export_service.dart:122` (same wrong prefix) · `functions/index.js:103-107` (`ai_usage_logs` retains `uid`)
**Dependencies** — · **Required before** `LEG-02`, `STORE-04`, M5
**Blocking** Lawful launch. Art. 17 and Art. 20 compliance.

**What exists / what is missing**

Server-side recursive erasure exists and is genuinely good — it deletes the whole `users/{uid}` subtree,
server-only docs, authored posts and signals, coach profile, referrals, and the Auth identity. Gaps:

1. **Chat images ~50 % survive.** `deleteStoragePrefixes` uses `chat_images/${uid}`. The real path is
   `chat_images/{sortedUidPair}/…` (`storage_upload_service.dart:100`). `deleteFiles({prefix})` is a
   string-prefix match, so it succeeds only when the deleting user's uid **sorts first** in the pair.
   `data_export_service.dart:122` repeats the identical mistake, so the export is also incomplete.
2. **`ai_usage_logs` retains `uid` indefinitely** and is never touched by erasure — residual personal
   data after a deletion request.
3. **Cross-user artefacts survive:** comments the user authored in others' posts, `friends` and
   `friend_requests` entries in other users' subtrees, `gyms/*/members/{uid}`, coach `clients/{uid}`,
   `community_groups/*/members/{uid}`, `chats` participation and their messages, `reports` they filed.

**Acceptance Criteria**
- Chat image erasure iterates the user's actual chat documents and deletes each `chat_images/{scopeId}/` prefix — no string-prefix assumption.
- `data_export_service.dart` uses the same corrected enumeration.
- `ai_usage_logs` for the uid are deleted **or** irreversibly anonymised (uid → `deleted_<hash>`), with the retention decision documented in `docs/COMPLIANCE.md`.
- Authored comments in other users' posts anonymised or deleted (product decision — document it).
- `friends` / `friend_requests` / gym members / coach clients / group members / chat participation all cleaned.
- Export includes `private/nutrition`, every subcollection, and a Storage manifest.
- An end-to-end test account is created, populated across every surface, erased, and **verified empty** by an admin query — with a written checklist.
- `docs/COMPLIANCE.md` records exactly what is erased, what is retained, why, and for how long.

**DoD** §0.5 plus a signed-off erasure verification checklist.

**Technical Notes**
This is `S7` + `S11` from `GO_LIVE.md` §5S. The prefix bug is subtle and would pass any test that only
checks "the function ran without error" — verify by **querying for leftovers**, not by checking exit
status.

**Risks**
Anonymising vs deleting authored community content is a product decision with UX consequences (orphaned
comment threads). Decide explicitly and write it into the privacy policy.

---

#### `BLK-13` ✅ CI is red on `main` and `test/` is gitignored

**Status** ✅ Closed — **all four CI jobs confirmed green in a real run**
([run #46](https://github.com/burcok/cookrange/actions/runs/30690211684), commit `091429e`) · **Priority**
Critical · **Complexity** S (actual: grew into a multi-session diagnosis across `CI-11`/`CI-12`) ·
**Est** 4 h (actual: ~10 h across this card + `CI-11` + `CI-12`)
**Version** v0.9.7 · **Milestone** M1 · **Owner** DevOps Lead
**Labels** `ci` `testing` `quality-gate` `git-hygiene`
**Modules** DevOps · Testing
**Files** `.gitignore` · `test/app_lifecycle_service_test.dart` · 44 files in `lib/` · `.github/workflows/ci.yml` · `test/firestore_rules/rules.test.mjs` · `android/gradle.properties`
**Dependencies** — · **Required before** every other task's DoD
**Blocking** Any trustworthy statement about code quality — **fully unblocked**.

**What exists / what is missing**

Fixed and verified — both locally and in a real CI run on `main`
([run #40](https://github.com/burcok/cookrange/actions/runs/30667024406), commit `d944828`):

| Check | Result |
|---|---|
| `test/` tracked in git (was gitignored) | ✅ 14 files; `test/firestore_rules/node_modules/` scoped-excluded |
| `dart format --output=none --set-exit-if-changed lib/` | ✅ 44 files reformatted (whitespace-only, verified) |
| `flutter test` (3 `app_lifecycle_service_test` failures) | ✅ fixed — `MockFirestoreService` was missing `syncDeviceContext`/`verifyAndRepairUserData` overrides added after the mock was written. 78/78 pass |
| `firestore-rules` CI job | ✅ **green in real CI** — was failing at "Install rules-test deps" (directory didn't exist); now installs, runs, and passes 15/15 |
| `secret-scan` (gitleaks) CI job | ✅ green |
| `pubspec.lock` gitignore contradiction (`DEBT-51`) | ✅ fixed — un-ignored; was already tracked anyway |
| `lib/firebase_options.dart` generation undocumented (`DEBT-52`) | ✅ mostly — generation step documented in `docs/DEVOPS.md` §4; CI's placeholder was a bare comment (not valid Dart), which turned out to break `flutter analyze` outright — fixed with a real stub as part of `CI-11`. File stays gitignored by choice; a device build straight from CI's config still can't reach a real Firebase project |

Two defects surfaced getting the rules job to actually run for what is very likely the first time in
this repo's history — both **fixed and reverified 15/15 locally + confirmed green in CI**:
1. `ci.yml` pinned Java 17; `firebase-tools` (installed at `latest`) hard-requires 21+ and refused to
   start the emulator below that. Bumped to 21.
2. `rules.test.mjs`'s `admin/status` test passed `doc(db('u1'), 'admin/status/u1')` — 3 segments, an
   **invalid** Firestore document reference (`doc()` requires an even count). No match block for this
   path exists in `firestore.rules` at all (only `admin_roles`/`admin_audit`/`admin_config` do), so
   fixed to the valid 4-segment form `firestore.rules:32`'s own comment already describes
   (`admin/status/{uid}/flags`) — exercises the same real implicit default-deny.

**Was out of this card's scope, tracked and fixed separately as `CI-11` and `CI-12`:**
`analyze-and-test` failed across **three independent, stacked root causes**, each hiding the next
until the previous was fixed: a stale Flutter CI pin (`pub get` failed), a `firebase_options.dart`
CI placeholder that was never valid Dart (`analyze` failed with undefined-name errors), and a
repo-wide `assets/Fonts/` vs `assets/fonts/` case mismatch invisible on macOS's case-insensitive
filesystem for the project's entire life (`analyze` failed on a missing-asset-directory warning).
Then, once `analyze-and-test` finally passed for the first time, `build-android` ran its actual APK
build for the first time ever and hit a **fourth**: `android/gradle.properties` hardcoded
`org.gradle.java.home` to an absolute macOS-only path (Android Studio's bundled JBR) — worked
silently on the one machine that happened to have Android Studio installed exactly there, invalid
everywhere else including every CI runner. All four fixed; `analyze-and-test` verified in a real
`ubuntu:24.04` container matching CI's architecture before pushing, `build-android` confirmed
directly against real CI after a real Android SDK (platform 36, NDK 28.2, build-tools 36.0.0) was
set up in a container to reproduce it first. See `CI-11` and `CI-12` for the full diagnoses — both
are genuinely worth reading, not routine.

**Acceptance Criteria**
- ✅ `test/` removed from `.gitignore`; all 14 files (11 Dart + 3 `firestore_rules/`) committed.
- ✅ `test/firestore_rules/node_modules` excluded specifically.
- ✅ `dart format lib/` applied; formatting job green.
- ✅ The 3 `app_lifecycle_service_test` failures fixed.
- ✅ **All four CI jobs green on `main`** — confirmed in a real run
  ([run #46](https://github.com/burcok/cookrange/actions/runs/30690211684)): `analyze-and-test`,
  `firestore-rules`, `secret-scan`, `build-android` all `success`. **First time in this repo's
  history all four have passed.**
- 📋 Branch protection requiring all four — not yet done. Now achievable; recommend as the immediate
  next step, but it's a repository-settings change and wasn't asked for as part of this card, so
  flagged rather than done unprompted.
- ✅ `pubspec.lock` tracking made deliberate — see `DEBT-51`, now closed.
- 🚧 `lib/firebase_options.dart` generation documented — see `DEBT-52`, mostly closed (the CI
  placeholder itself is now fixed as part of `CI-11`; committing the real file remains open).

**DoD** §0.5 — met. Green CI run linked above, all four jobs, confirmed by observation, not assumed.

**Technical Notes**
`.gitignore` also lists `macos/` and `/lib/firebase_options.dart` (deliberately, unrelated to this
card). `pubspec.lock` is now committed on purpose, matching reality.

---

#### `BLK-14` 🔥 App Check is not enforced — `APP_ENV=development` in the deployed configuration

**Status** 🔥 Critical · **Priority** Critical · **Complexity** S · **Est** 1 d + console
**Version** v0.9.7 · **Milestone** M1 · **Owner** DevSecOps
**Labels** `app-check` `security` `abuse` `console`
**Modules** Security · Backend · DevOps
**Files** `functions/.env` (`APP_ENV=development`) · `functions/config.js` (`APP_CHECK_ENFORCE`) · `lib/core/services/ai/ai_service.dart:345-350`, `:520-525`, `:598-603` (client swallows token failure) · `lib/core/services/app_initialization_service.dart:205-209`
**Dependencies** `BLK-16` (console access) · **Required before** `BLK-04`, M5
**Blocking** Abuse protection on the AI proxy and every callable.

**What exists / what is missing**

The client does the right thing: real providers in release (`AndroidProvider.playIntegrity`,
`AppleProvider.appAttest`), debug provider only in debug. The server does the right thing structurally:
`aiProxy` refuses requests without an App Check token when `APP_CHECK_ENFORCE` is true.

But `functions/.env` sets `APP_ENV=development`, and `config.js` relaxes `APP_CHECK_ENFORCE` in
development. Combined with the client's `catch (_) {}` around `FirebaseAppCheck.instance.getToken()`, a
request with no App Check header proceeds and is accepted.

`GO_LIVE.md` also notes `aiProxy` needs the public-invoker role granted or the platform returns 401
before the in-code auth runs.

**Acceptance Criteria**
- Play Integrity and App Attest registered in the Firebase console.
- App Check **enforcement enabled** for Cloud Functions, Firestore and Storage.
- `APP_ENV=production` in the deployed Functions environment.
- The client's `catch (_) {}` around App Check replaced with a logged failure; a release build that cannot obtain a token surfaces an error rather than silently proceeding.
- `aiProxy` granted the public-invoker role; verified a real client call succeeds and a `curl` without a token returns 401.
- Debug tokens registered for developer devices so local work still functions.

**DoD** §0.5 plus a recorded 401 from an unattested request against production.

**Technical Notes**
`APP_ENV` is a two-value switch with no staging tier. `INF-01` (environment separation) should land with
this so `production` can be set without breaking local development.

---

#### `BLK-15` 🔥 A live OpenRouter key is bundled as a Flutter asset and shipped in CI artifacts

**Status** 🔥 Critical · **Priority** Critical · **Complexity** S · **Est** 1 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** DevSecOps
**Labels** `secrets` `key-leak` `ci` `denial-of-wallet`
**Modules** Security · DevOps · AI
**Files** `pubspec.yaml:167` (`- .env` in assets) · `.env` (live `sk-or-…` key present now) · `.github/workflows/ci.yml` (`build-android` writes the key then uploads the APK as an artifact) · `.github/workflows/deploy.yml` (writes the key for release builds)
**Dependencies** — · **Required before** M4
**Blocking** Safe distribution of any build.

**What exists / what is missing**

`pubspec.yaml` declares `.env` as a Flutter asset, so the file is packed into **every** built binary.
A live OpenRouter key is in the working-tree `.env` right now. The CI `build-android` job writes the key
into `.env`, builds a debug APK, and **uploads that APK as a 7-day GitHub artifact** — anyone with repo
read access can download a build containing a live key.

The release *code path* is correctly hard-blocked (`if (kReleaseMode) throw const AIFatalException(...)`
in all three call sites). The *key material* still ships.

`GO_LIVE.md` `S0` additionally records a **leaked Firebase Admin service-account key that has not been
rotated**.

**Acceptance Criteria**
- `.env` removed from the `pubspec.yaml` assets list.
- Client configuration moved to `--dart-define` (or the proxy URL fetched from `app_config/global`, which already happens — the client needs **no** AI key at all once `BLK-01` lands).
- CI stops writing `OPENROUTER_API_KEY` into `.env` for client builds.
- The `build-android` artifact upload either removed or verified key-free.
- The OpenRouter key **rotated**.
- The leaked Firebase Admin service-account key **rotated** (`S0`); `secret/` purged from every machine; confirm Functions use Application Default Credentials.
- `gitleaks` CI job verified to actually fail on a planted test secret.
- A hard spend cap set on the OpenRouter account.

**DoD** §0.5 plus `unzip -p app-release.aab | grep -c 'sk-or-'` returns 0.

**Technical Notes**
Once `BLK-01` removes the direct-key path, the client has no legitimate need for the key in any build
mode. Debug can point at the deployed proxy or a local emulator. This is a net simplification.

**Risks** Rotating the key breaks any local debug build still reading `.env`. Communicate and land together with `BE-01`.

---

#### `BLK-16` 🔥 No developer programme enrolment, no signing identity, no store records

**Status** ❌ Missing · **Priority** Critical · **Complexity** M · **Est** 1–2 w wall clock (mostly waiting)
**Version** v0.9.9 · **Milestone** M3 · **Owner** CTO (founder action — cannot be done by engineering)
**Labels** `store` `signing` `console` `founder-action` `blocking`
**Modules** Store · DevOps · Legal
**Files** `.github/workflows/deploy.yml` (documents every required secret) · `ios/ExportOptions.plist`
**Dependencies** — · **Required before** `BLK-02` verification, `BLK-04`, `CI-04`, M4, M5
**Blocking** Any distributable build. This is on the critical path and has the longest lead time.

**What exists / what is missing**

The deploy workflow is genuinely well built — P12 certificate import into a temporary keychain,
provisioning-profile installation, team-ID injection, `xcrun altool` upload to TestFlight, keystore
decode and `upload-google-play` to the internal track. It has never run because none of the inputs
exist.

Missing entirely: Apple Developer Program ($99/yr), Google Play Developer ($25 one-time), App ID
registration, APNs auth key, distribution certificate, provisioning profile, App Store Connect record,
Play Console listing, upload keystore, Play App Signing enrolment, SHA-1/256 registered in Firebase,
all GitHub secrets.

**Acceptance Criteria**
- Apple Developer Program enrolled; Google Play Developer enrolled.
- App ID registered; APNs auth key uploaded to Firebase (required for iOS push — `BLK-03` cannot be verified on iOS without it).
- Distribution certificate + App Store provisioning profile created.
- Upload keystore created, backed up **securely and redundantly** (losing it is unrecoverable), Play App Signing enrolled.
- SHA-1 + SHA-256 registered in Firebase (required for Google Sign-In on Android).
- App Store Connect record + Play Console listing created with metadata.
- All 12 GitHub secrets set per the `deploy.yml` header.
- One successful TestFlight upload and one successful Play internal-track upload.

**DoD** A build installed from TestFlight and from Play internal on physical devices.

**Technical Notes**
Start this on **day one of M1**. Enrolment, review and product approval are wall-clock delays that no
amount of engineering parallelism compresses. Everything in M3 and M4 is gated on it.

**Risks** Apple enrolment can take days to weeks for business entities requiring D-U-N-S verification. Begin immediately.

---

#### `BLK-17` 🔥 No monitoring, no alerting, no backups, single environment

**Status** ❌ Missing · **Priority** Critical · **Complexity** M · **Est** 3–5 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** DevOps Lead
**Labels** `observability` `monitoring` `backups` `dr` `operations`
**Modules** DevOps · Backend · Firebase
**Files** `firebase.json` · `.firebaserc` (single project `cookrange-app`) · `lib/core/services/performance_service.dart` (wrapper exists, no traces instrumented)
**Dependencies** — · **Required before** M4, M5
**Blocking** Operating a production service at all.

**What exists / what is missing**

`firebase_performance` is a dependency and `PerformanceService` wraps it, but the only instrumented
metric is an HTTP metric on the AI call. There is no startup trace, no frame-timing data, no dashboard,
no alert policy, no uptime check, no error-rate SLO, no Firestore backup schedule, no restore runbook,
and exactly one Firebase project serving as dev, staging and prod simultaneously.

There is also **no production log output** from the swallowed error paths, because `debugPrint` compiles
to nothing in release (`DEBT-01`).

**Acceptance Criteria**
- Crashlytics velocity alerts configured; crash-free-users SLO defined (target > 99 %).
- Cloud Monitoring dashboard: `aiProxy` invocation count / error rate / p95 latency / quota-exceeded rate, Firestore read volume, Storage egress, Functions error rate.
- Alert policies with a real notification channel for: crash spike, `aiProxy` 5xx rate, quota-store failures (`quota_unavailable`), purchase-validation failure rate, Firestore denied-permission spike.
- Firebase Performance startup trace + traces on the 5 primary screens.
- Scheduled Firestore export (daily) to a GCS bucket with lifecycle rules.
- **A documented, rehearsed restore** — an untested backup is not a backup (`DR-02`).
- Budget alerts on the GCP project and a hard spend cap on OpenRouter.
- `INF-01` staging environment stood up.

**DoD** §0.5 plus a rehearsed restore recorded in `docs/`.

**Technical Notes**
The denied-permission spike alert deserves emphasis: it is the signal that would have surfaced
`BLK-03`, `BLK-06` and `BLK-07` in production within minutes. Wire it early.

**Future improvements** `OBS-06` BigQuery export + funnel dashboards; `OBS-07` synthetic canary journey.

---

## §3 — Security & Privacy

> Traceability: this section absorbs **every** item from `docs/roadmap/GO_LIVE.md` §5S (`S0`–`S23`) and
> the audit findings they reference (`C1`–`C11`, `H1`–`H31`, `M1`). The `S`/`C`/`H` IDs are preserved in
> each card so no prior finding is orphaned. **All 18 gates `S0`–`S17` were unchecked at audit time.**

### 3.1 Security blockers already carded in §2

| Prior ID | New ID | Title |
|---|---|---|
| `S0` | `BLK-15` | Rotate leaked keys; stop bundling the AI key |
| `S1` | `BLK-10` | Lock and minimise the `users/{uid}` document |
| `S5` (partial) | `BLK-03` | Close open notification creates (server-authored) |
| `S3` | `BLK-04` | Server-side purchase validation live |
| `S6` (partial) | `BLK-14` | App Check enforcement |
| `S7` + `S11` | `BLK-12` | Complete erasure + export |
| `S9` (partial) | `BLK-07` | Storage prefix + access control for gym logos |
| `S13` (partial) | `BLK-08`, `BLK-09` | Post-field mutation; marketplace injection |
| `S10` | `BLK-10` | Minimise readable user doc |

### 3.2 Authentication security

#### `SEC-01` 🔥 Login throttling, lockout and enumeration-safe errors *(`S12`, `H8`, `H9`, `M1`)*

**Status** ❌ Missing · **Priority** Critical · **Complexity** M · **Est** 3–4 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** DevSecOps
**Labels** `auth` `brute-force` `enumeration` `abuse` `rate-limiting`
**Modules** Security · Backend · Frontend
**Files** `lib/core/services/auth_service.dart` (no throttle logic present) · `firestore.rules:166-171` (`failed_login_attempts` correctly closed to clients, replacement never built) · `lib/core/utils/auth_error_handler.dart`
**Dependencies** — · **Required before** M5 · **Blocking** Credential-stuffing resistance

**What exists / what is missing**
`grep` for throttle/lockout logic in `auth_service.dart` returns nothing. The `failed_login_attempts`
collection was correctly closed to unauthenticated writes — the rule comment states monitoring belongs in
Identity Platform or an Auth blocking function — but **neither was implemented**. Brute-force resistance
today is entirely Firebase Auth's built-in throttling. Error messages are also not audited for account
enumeration.

**Acceptance Criteria**
- Identity Platform Auth blocking function (`beforeSignIn`) records failures server-side and rejects after N attempts in a window, with exponential backoff.
- reCAPTCHA Enterprise or App Check enforced on the auth path.
- All auth error copy audited: "invalid email or password" — never "no account with that email".
- Registration does not reveal whether an email is already in use through timing or message.
- Lockout state visible to admins (`ADM-08`) and self-clearing after the window.
- A scripted attempt of 50 bad logins is blocked and alerted (`BLK-17`).

**DoD** §0.5 plus a documented brute-force test result.
**Risks** Over-aggressive lockout is a denial-of-service against legitimate users. Use per-IP + per-account windows, not per-account only.
**Future** `SEC-02` MFA.

---

#### `SEC-02` MFA / two-factor authentication

**Status** ❌ Missing · **Priority** Medium · **Complexity** L · **Est** 1–2 w · **Version** v1.2.0 · **Milestone** M7 · **Owner** DevSecOps
**Labels** `auth` `mfa` · **Modules** Security · Backend · Frontend · UX
**Files** `lib/core/services/auth_service.dart` · **Dependencies** `SEC-01` · **Blocking** Enterprise/gym-owner trust
**Acceptance** TOTP or SMS second factor available and optional; enforced for `admin` and `gymOwner` roles; recovery codes issued; enrolment and removal flows in Settings; EN+TR.
**DoD** §0.5. **Notes** Firebase Auth multi-factor requires Identity Platform upgrade. **Risks** SMS cost and SIM-swap; prefer TOTP. **Future** WebAuthn/passkeys.

---

#### `SEC-03` Session management: revoke on credential change, mid-session ban enforcement

**Status** 🚧 Partial · **Priority** High · **Complexity** M · **Est** 2–3 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** DevSecOps
**Labels** `auth` `session` `ban` `account-takeover`
**Modules** Security · Backend · Frontend
**Files** `lib/core/services/auth_service.dart` (single-session monitoring exists) · `lib/core/services/admin_status_service.dart` (`_cachedBanStatus` never invalidated) · `lib/core/utils/route_guard.dart` (`_realtimeAdminStatus` starts `null`) · `lib/core/utils/ban_check_observer.dart`
**Dependencies** `BLK-05` · **Required before** `MOD-02` · **Blocking** Effective banning; takeover containment

**What exists / what is missing**
Single-session enforcement (force logout on session-token mismatch) works. Missing: `revokeRefreshTokens`
on password/email change; a banned user is not blocked by `RouteGuard` on cold start because
`_realtimeAdminStatus` is `null` until the stream fires; `AdminStatusService._cachedBanStatus` is cached
for the process lifetime and never invalidated, so a mid-session ban is not observed by that path.

**Acceptance Criteria**
- `admin.auth().revokeRefreshTokens(uid)` called server-side on password change, email change, ban, and admin force-logout.
- Ban state moved to a custom claim so it is enforced by Firebase Auth itself, not only by client routing.
- `_cachedBanStatus` given a TTL or replaced by the live listener.
- `RouteGuard` resolves ban state before rendering the first authenticated route (fail-safe: unknown → allow, but resolve fast and re-gate).
- Verified: ban a signed-in user on device B → device A is ejected within 60 s without a restart.

**DoD** §0.5 plus a two-device ban test.
**Risks** Custom-claim propagation requires a token refresh; force it explicitly.

---

### 3.3 Authorization security

#### `SEC-04` Move admin authority to custom claims; stop trusting the writable user doc *(`S1`, `C2`)*

**Status** 🚧 Partial · **Priority** Critical · **Complexity** M · **Est** 2 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** Security Engineer
**Labels** `authorization` `privilege-escalation` `admin`
**Modules** Security · Backend · Firebase · Frontend
**Files** `firestore.rules:27-35`, `:45-56` · `lib/core/widgets/side_menu.dart:401` · `lib/core/models/user_model.dart:81`
**Dependencies** `BLK-05` · **Required before** `ADM-*` · **Blocking** Any claim that admin UI is access-controlled

**What exists / what is missing**
`user_roles` is deliberately unlocked; the rules comment argues a self-written `['admin']` is cosmetic
because real power is server-gated. That reasoning is correct **today** and fragile **tomorrow** — it
depends on every future rule and every future Function remembering not to trust `user_roles`. Also, a
self-granted admin UI that then fails with permission errors is a support and confusion cost.

**Acceptance Criteria**
- A Cloud Function mirrors `admin_roles/{uid}.is_admin` into a custom claim.
- The client gates admin UI on the claim.
- `coach` / `gymOwner` self-service role writes remain allowed (they are ownership-gated by design) but are documented as **UI-affordance only** with a test asserting no capability follows from them.
- `firestore.rules` comment updated to state the claim is now the client gate.

**DoD** §0.5 plus a rules + claim test.
**Future** `SEC-05` role hierarchy with granular admin scopes (moderator vs finance vs support).

---

#### `SEC-05` Granular admin scopes (moderator / finance / support / superadmin)

**Status** ❌ Missing · **Priority** Low · **Complexity** M · **Est** 3–4 d · **Version** v1.2.0 · **Milestone** M7 · **Owner** Security Engineer
**Labels** `authorization` `least-privilege` · **Modules** Security · Firebase · Frontend
**Files** `firestore.rules`, `lib/screens/admin/admin_sections.dart` · **Dependencies** `SEC-04` · **Blocking** Hiring non-engineer moderators safely
**Acceptance** `admin_roles/{uid}.scopes[]`; `isAdmin(scope)` rule helper; `AdminSectionMeta` carries a required scope; sections hidden and denied without it; audit log records the scope used.
**DoD** §0.5. **Notes** Needed before any non-founder gets admin. **Risks** Rule complexity; add tests per scope.

---

#### `SEC-06` Server-author all social writes: notifications, friends, friend requests *(`S5`, `C9`)*

**Status** ❌ Missing · **Priority** Critical · **Complexity** M · **Est** 3–4 d
**Version** v0.9.7 · **Milestone** M1 (with `BLK-03`) · **Owner** Security Engineer
**Labels** `firestore-rules` `spam` `impersonation` `push-forgery`
**Modules** Security · Backend · Firebase
**Files** `firestore.rules:78-80` (`friends` create/update by any authenticated user) · `:86-87` (`friend_requests` same) · `:96` (`notifications` create by any authenticated user)
**Dependencies** — · **Required before** M5 · **Blocking** Anti-spam; anti-impersonation

**What exists / what is missing**
Three subcollections under `users/{uid}` accept writes from **any** authenticated user. Combined with the
push fan-out (once `BLK-03` is fixed), an attacker can inject arbitrary notification documents with an
arbitrary `actorName` into any user's inbox and have it delivered as a push notification with attacker-
controlled text. They can also write into anyone's friends list and friend-request queue.

**Acceptance Criteria**
- `create` on all three set to `if false` for clients.
- Callables (`sendFriendRequest`, `respondToFriendRequest`, `follow`) derive the actor from `request.auth`, verify the underlying edge exists, re-fetch `actorName` server-side, and write both sides atomically.
- Notification creation happens only inside Functions.
- Rules tests: user A cannot write user B's `friends`, `friend_requests` or `notifications`.
- Verified: a crafted client write is rejected; the legitimate UI flow still works end to end.

**DoD** §0.5 plus rules tests per path.
**Technical Notes** Land with `BLK-03` — same files, same deploy, and `BLK-03` opens this hole if fixed alone.
**Risks** Latency: a callable round-trip is slower than a direct write. Use optimistic UI with rollback.

---

#### `SEC-07` Gym post membership enforcement *(`S13`, `H25`)*

**Status** 🚧 Partial · **Priority** High · **Complexity** S · **Est** 1 d · **Version** v1.1.0 · **Milestone** M6 · **Owner** Security Engineer
**Labels** `firestore-rules` `gym` `abuse` · **Modules** Security · Firebase
**Files** `firestore.rules:378-381` · **Dependencies** — · **Blocking** Gym community integrity
**What exists** `allow create: if isAuthenticated()` on `gyms/{gymId}/posts` with the comment "membership enforced app-side" — i.e. not enforced.
**Acceptance** Rule requires `exists(/gyms/$(gymId)/members/$(request.auth.uid))`; author pinned to `request.auth.uid`; length caps; rules test for non-member denial.
**DoD** §0.5. **Risks** An `exists()` per post write is 1 extra read — acceptable at gym-post volume.

---

#### `SEC-08` Check-in integrity: membership + geofence + rate limit *(`S13`, `H26`)*

**Status** 🚧 Partial · **Priority** High · **Complexity** M · **Est** 2–3 d · **Version** v1.1.0 · **Milestone** M6 · **Owner** Security Engineer
**Labels** `gym` `fraud` `geofence` `leaderboard-integrity` · **Modules** Security · Backend · Firebase
**Files** `lib/core/services/gym_service.dart` (`gpsCheckIn`, Haversine client-side) · `firestore.rules` (`checkins`) · **Dependencies** `BLK-08` (server counters) · **Blocking** Gym leaderboards and Gym Wars meaning anything
**What exists** Client-side Haversine geofence and client-written check-ins. A repackaged client can fabricate location and check-in count freely.
**Acceptance** Check-in written only by a callable that verifies membership, recomputes the geofence server-side from the gym's stored coordinates, enforces one check-in per gym per day, and rate-limits; QR token validated server-side with a short expiry; leaderboard reads only server-written check-ins.
**DoD** §0.5 plus a fraud attempt test. **Risks** GPS spoofing is still possible at the OS level; combine QR + geofence + time window for defence in depth.

---

#### `SEC-09` Coach review integrity — require a real client relationship *(`S13`, `H4`–`H7`)*

**Status** ✅ Partial-verified · **Priority** Medium · **Complexity** S · **Est** 1 d · **Version** v1.1.0 · **Milestone** M6 · **Owner** Security Engineer
**Labels** `marketplace` `fraud` `reviews` · **Modules** Security · Firebase
**Files** `lib/core/services/coach_review_service.dart` (`canReview` checks client linkage + food-log anti-fraud gate) · `firestore.rules` (`reviews`: linked clients create, 1–5 enforced)
**Dependencies** — · **Blocking** Marketplace trust
**What exists** Client-side `canReview` plus a rule requiring a client link and a 1–5 rating — genuinely better than most. **What is missing:** `avgRating`/`ratingCount` are updated by a **client transaction**, so a determined client could still skew them; no review edit/delete audit; no review reporting.
**Acceptance** Rating aggregates written only by a Function triggered on review create; review reporting wired to `reports/`; one review per client per coach enforced server-side.
**DoD** §0.5. **Risks** Trigger latency makes the average briefly stale — acceptable; show "updating" state.

---

### 3.4 API & abuse resistance

#### `SEC-10` 🔥 AI abuse: global spend circuit breaker and per-account anomaly detection

**Status** 🚧 Partial · **Priority** Critical · **Complexity** M · **Est** 2–3 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** AI Architect + DevSecOps
**Labels** `ai` `denial-of-wallet` `cost-control` `abuse`
**Modules** Security · Backend · AI · Analytics
**Files** `functions/index.js:30-56` (limits), `:197-252` (`enforceRateLimitAndQuota`), `:62-73` (`MODEL_PRICING`) · `app_config/global.ai`
**Dependencies** `BLK-14` · **Required before** M5 · **Blocking** Safe public exposure of a paid AI endpoint

**What exists / what is missing**
Per-user protection is strong: fail-closed transactional daily quota (free 2 / premium 20), a 12-per-60s
sliding window, a model allowlist, `MAX_MESSAGES=30`, `MAX_TOTAL_CHARS=24000`, `MAX_OUTPUT_TOKENS=8192`
capped at 32,000, and real per-request cost accounting.

Missing: a **global** ceiling. `app_config/global.ai.free_daily_limit`, `max_tokens` and `model` are
admin-editable **without a redeploy** — a single mistaken edit (or a compromised admin account) raises
limits platform-wide with no circuit breaker. `MODEL_PRICING` covers only 3 models; anything else records
`unpriced: true` with cost 0, so cost reporting silently under-reports. There is no OpenRouter account
spend cap set, and no anomaly alert on a single account burning unusual volume.

**Acceptance Criteria**
- A hard-coded server-side maximum that `app_config` **cannot exceed** for `max_tokens`, `free_daily_limit`, `premium_daily_limit`.
- A global daily spend ceiling read from `ai_usage_stats/day_*`; `aiProxy` returns 503 when exceeded and alerts.
- Hard spend cap configured on the OpenRouter account itself.
- Alert when any single uid exceeds N× the median daily cost.
- `MODEL_PRICING` externalised to `app_config/global`; an alert fires on any `unpriced: true` write.
- `app_config/global` writes audited to `admin_audit` (verify: `AdminService.updateAppConfig` already logs — confirm and test).
- Verified: a synthetic burst is rate-limited, then quota-limited, then globally capped.

**DoD** §0.5 plus a recorded load test (`PERF-10`).
**Risks** A global cap is a shared-fate denial of service — set it generously and alert well before it trips.

---

#### `SEC-11` Prompt injection, prompt leaking and model abuse hardening

**Status** 🚧 Partial · **Priority** High · **Complexity** M · **Est** 2–3 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** AI Architect
**Labels** `ai` `prompt-injection` `prompt-leaking` `jailbreak`
**Modules** Security · AI
**Files** `lib/core/services/ai/prompt_service.dart` (guard + fencing, 4 prompts) · `lib/core/services/ai_insight_service.dart` (~9 **unguarded** inline prompts) · `lib/core/services/food_analysis_service.dart` (2) · `lib/core/services/recipe_generation_service.dart` (1) · `lib/core/services/ai/ai_chat_service.dart` (1)
**Dependencies** — · **Required before** `AI-09` · **Blocking** Safe handling of user-authored text in prompts

**What exists / what is missing**
`PromptService.injectionGuard` + `fence()` (guillemet wrapping with escape-stripping) is genuinely good
work with a real threat model. It is applied to **4 prompts**. Roughly **9 inline prompts in
`ai_insight_service.dart`** plus 4 more across three other services do **not** use it — and several embed
user-controlled free text (goals, notes, food descriptions, chat history).

There is no output-side guard: no check that the model has not echoed the system prompt, no refusal
detection, no scrubbing of prompt content from responses shown to users.

**Acceptance Criteria**
- Every prompt in the codebase routed through `PromptService` (see `AI-09` consolidation) with the guard applied.
- All user-controlled interpolation passes through `fence()`.
- Output-side check: responses containing system-prompt markers or the security directive are rejected and retried.
- Chat history sanitised before resend — a prior assistant turn cannot smuggle instructions.
- A red-team test suite of ≥ 20 injection payloads (instruction override, prompt exfiltration, dietary-safety bypass, language override) with asserted-safe outcomes, run in CI.
- **Allergen bypass specifically tested:** an injection attempting to unlock an allergen must still fail because `allergen_safety.dart` filters the pool pre-prompt.

**DoD** §0.5 plus the red-team suite green in CI.
**Technical Notes** The deterministic allergen pre-filter is the correct architectural answer and must stay the primary control — never rely on prompt instructions for a safety constraint.
**Risks** Guard text costs input tokens on every call. Measure; consider a shortened directive for non-free-text prompts.

---

#### `SEC-12` UGC rate limits, spam and bot protection *(`S13`, `H27`)*

**Status** 🚧 Partial · **Priority** High · **Complexity** M · **Est** 3–4 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** Security Engineer
**Labels** `spam` `bot` `rate-limiting` `community` `abuse`
**Modules** Security · Backend · Firebase
**Files** `firestore.rules:194` (5,000-char post cap exists) · `lib/core/services/community_service.dart` (`_checkContent` keyword filter) · `settings/content_filter`
**Dependencies** `BLK-14` · **Required before** M5 · **Blocking** Community usable at scale

**What exists / what is missing**
Content-length caps on posts, comments, chat and signals **are** in the rules — good. A keyword filter
reads `settings/content_filter` (public-read, admin-mirrored) and pre-screens posts and comments; the
earlier fail-open bug (reading admin-only `admin_config/global`) is fixed.

Missing: any **rate limit** on UGC creation. A script can create unlimited posts, comments, reactions,
follows, chats, groups and reports. No bot protection beyond App Check. No duplicate-content detection.
No new-account trust ramp.

**Acceptance Criteria**
- Per-uid sliding-window limits on post / comment / reaction / follow / chat / group / report creation, enforced server-side (reuse the `aiProxy` window pattern in a shared helper).
- Group creation rate-limited specifically (`COMMUNITY_GROUPS` P3 anti-abuse item).
- Duplicate-content detection (same text within N minutes) rejected.
- New accounts (< 24 h, unverified) subject to tighter limits.
- App Check enforced on all callables (`BLK-14`).
- Verified: a scripted 100-post burst is throttled with a clear client error.

**DoD** §0.5 plus a scripted abuse test.
**Risks** Legitimate power users hitting limits. Log every throttle to analytics and tune from data.

---

#### `SEC-13` Storage abuse: upload scanning, quotas, and application-document access

**Status** 🚧 Partial · **Priority** High · **Complexity** M · **Est** 3–4 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** DevSecOps
**Labels** `storage` `nsfw` `csam` `abuse` `egress-cost`
**Modules** Security · Backend · Firebase · Legal
**Files** `storage.rules` · `functions/media.js` (`SCAN_PREFIXES`, `VISION_DAILY_CAP=1000`) · `lib/core/services/storage_upload_service.dart`
**Dependencies** `BLK-07` · **Required before** M5 · **Blocking** Legal exposure from user-uploaded imagery

**What exists / what is missing**
Uploads are handled well: resize (≤1440 photos / ≤512 avatars), JPEG q82, **EXIF/GPS stripped**,
off-thread isolate. `media.js` runs Cloud Vision SafeSearch on public prefixes and deletes
adult/violent/racy uploads, with a hard daily cost cap that **fails safe** (skips the scan rather than
risking runaway spend).

Gaps:
- `SCAN_PREFIXES` includes `'gyms/'` but the rule grants `gym_logos/` (`BLK-07`) — the scanner and the rules disagree.
- Cloud Vision must be **enabled in the console**; today the function logs a warning and keeps the image.
- **No CSAM/NCMEC reporting path** — a legal obligation in most jurisdictions once user-uploaded imagery is public.
- Group chat images (`chat_images/{chatId}/…` with no `_`) are readable by **any** authenticated user; the rule comment concedes this and relies on an unguessable filename — security by obscurity, written down as such.
- Gym/coach **application documents** (business licence, ID) cannot be read by admins because Storage rules cannot query Firestore; the noted workaround (Admin SDK) is unimplemented, so approvals cannot verify evidence.
- No per-user storage quota → unbounded egress and cost.

**Acceptance Criteria**
- Cloud Vision API enabled; scan verified deleting a test unsafe upload.
- `SCAN_PREFIXES` aligned with the final rule prefixes and asserted by a test.
- A CSAM detection + NCMEC reporting path documented and implemented (or a vendor engaged) before public UGC.
- Group chat images scoped to actual participants via a members-check callable or a participant-derived path.
- An `isAdmin` callable that mints short-lived signed URLs for application documents; admin review UI uses it.
- Per-user upload quota (count + bytes/day) enforced server-side.
- Public download tokens **not** minted for ID/business documents.

**DoD** §0.5 plus a verified unsafe-upload deletion and an admin document view.
**Risks** CSAM handling has strict legal requirements; get counsel before implementing detection or storage of hashes.

---

### 3.5 Business-logic abuse

#### `SEC-14` Server-authoritative streak and reputation

**Status** ❌ Missing · **Priority** High · **Complexity** M · **Est** 1 w
**Version** v1.0.0 · **Milestone** M4 · **Owner** Backend
**Labels** `integrity` `gamification` `leaderboard` `abuse`
**Modules** Security · Backend · Firebase
**Files** `lib/core/services/firestore_service.dart` (streak computed and written client-side) · `lib/core/services/reputation_service.dart` (`score = streak×2 + posts×5 + challenges×10`, cached to the user doc) · `lib/core/services/leaderboard_service.dart`
**Dependencies** `BLK-08` · **Required before** `GAM-01` · **Blocking** Leaderboards meaning anything

**What exists / what is missing**
Both streak and reputation are computed and written by the client. `firestore.rules` deliberately does
**not** lock `streak` or `reputation` (`GO_LIVE.md` lists this as deferred). Any user can set an arbitrary
streak and top the global leaderboard. Since `LeaderboardService` orders by
`onboarding_data.streak`, the leaderboard is trivially gameable — as is the achievement catalogue and
reputation tier that derive from it.

**Acceptance Criteria**
- Streak advanced by a Function on the day's first qualifying event (login or food log), using server time.
- Streak-freeze consumption server-side.
- Reputation recomputed by a Function from server-counted posts/logs/achievements.
- `streak`, `reputation_score`, `streak_freeze_count` added to `touchesProtectedUserFields()`.
- A one-off reconciliation pass recomputes every existing user's values and logs corrections.
- Rules tests: client cannot write any of the three fields.
- Verified: a crafted client write is rejected; the legitimate flow still advances the streak.

**DoD** §0.5 plus a rules test and a reconciliation report.
**Technical Notes** Land with `BLK-08` — both are "counters and progression are server-authoritative."
**Risks** Timezone semantics. Streaks are user-perceived in local time; store the user's timezone and evaluate against it, not UTC, or users lose streaks at midnight UTC.

---

#### `SEC-15` Referral, commission and payout fraud resistance *(`S4`, `C8`)*

**Status** ✅ Partial-verified · **Priority** High · **Complexity** M · **Est** 2–3 d
**Version** v1.1.0 · **Milestone** M6 · **Owner** Security Engineer
**Labels** `fraud` `economy` `referral` `payout`
**Modules** Security · Backend · Monetization
**Files** `functions/economy.js` (`applyReferral` — server-validated) · `firestore.rules` (`commissions` server-write-only, `referrals` owner/admin update with `owner_uid` pinned) · `lib/core/services/commission_service.dart`
**Dependencies** `REF-04` · **Required before** any real payout · **Blocking** Turning on payouts safely

**What exists / what is missing**
The server-side foundation is real: `applyReferral` rejects self-referral, enforces one-per-account and
`max_uses`, grants both sides, and writes the commission ledger. `commissions` is server-write-only.

Missing for real money movement: no velocity limits (one device creating many accounts), no device or
payment fingerprinting, no manual-review queue for suspicious referral clusters, no clawback mechanism
when a referred account is refunded or banned, no double-entry ledger, and the payout balance is not yet
computed server-side from approved commissions minus prior payouts (that arrives with `REF-04`).

**Acceptance Criteria**
- Referral velocity limits per device/IP; clusters flagged for review.
- Clawback on refund, chargeback or ban of the referred account.
- Immutable double-entry `payout_ledger/{id}`.
- Payable balance computed **server-side only**; the client never proposes an amount.
- Suspicious-activity queue in the admin panel (`ADM-08`).
- Fraud playbook documented.

**DoD** §0.5 plus a documented fraud walkthrough.
**Risks** Payout fraud is unrecoverable once money leaves. Do not enable `REF-04` until this is complete.

---

#### `SEC-16` Server-side premium enforcement for non-AI features *(`C1` residual)*

**Status** 🚧 Partial · **Priority** High · **Complexity** M · **Est** 1 w
**Version** v0.9.9 · **Milestone** M3 · **Owner** Backend
**Labels** `monetization` `entitlement` `bypass`
**Modules** Security · Monetization · Backend · Frontend
**Files** `lib/core/services/feature_gate_service.dart:37-44` (reads `user.entitlements` from the local model) · `lib/core/models/subscription_model.dart`
**Dependencies** `BLK-04` · **Required before** M5 · **Blocking** Premium revenue integrity

**What exists / what is missing**
AI is properly enforced server-side (`aiProxy` reads `entitlements/{uid}`). Every **other** premium
feature is gated by `FeatureGateService.check()`, which reads the entitlement from the in-memory
`UserModel` — mirrored from the user doc. The mirror is not client-writable (good), but the *gate* is
client-side, so a repackaged build bypasses it entirely.

**Acceptance Criteria**
- Every premium feature with a real server cost validates `entitlements/{uid}` server-side.
- Purely cosmetic premium features (themes, badges) may remain client-gated — documented explicitly as accepted risk.
- An inventory table in `docs/` lists every gated feature, its enforcement point, and whether bypass is materially harmful.
- Verified: a build with the gate patched out still cannot consume a server-cost premium feature.

**DoD** §0.5 plus the enforcement inventory.
**Risks** Adding a server round-trip to feature entry hurts UX. Cache the entitlement with a short TTL and enforce at the cost boundary, not the UI boundary.

---

### 3.6 Transport, device and build hardening

| ID | Status | Title | Prior | Priority | Cx | Est | Version | Owner | Modules | Files | Deps | Acceptance / DoD summary | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `SEC-17` | ❌ | Disable cleartext traffic + `network_security_config.xml` | `S14`, `H14` | Critical | XS | 2 h | v0.9.7 / M1 | DevSecOps | Security, DevOps | `android/app/src/main/AndroidManifest.xml:25` | — | `usesCleartextTraffic="false"`; add a network security config only if an HTTP endpoint is genuinely required (audit says none is); verify all traffic is HTTPS; §0.5 | A forgotten HTTP dependency breaks silently — test every network path |
| `SEC-18` | ❌ | Release obfuscation + split debug info + symbol upload | `S15`, `H16` | High | S | 1 d | v0.9.9 / M3 | DevOps | DevOps, Security | `.github/workflows/deploy.yml` | `BLK-16` | `--obfuscate --split-debug-info=build/symbols` on both release builds; symbols uploaded to Crashlytics; stack traces verified readable in the console; debug APK never distributed; §0.5 | Unreadable crash reports if symbol upload is skipped — verify before relying on it |
| `SEC-19` | ❌ | Encrypt the `analytics_cache` Hive box | `S14` residual | Medium | XS | 2 h | v0.9.8 / M2 | DevSecOps | Security | `lib/core/services/analytics_service.dart:144`, `:156` | — | Box opened with the same `HiveAesCipher` as the other seven; migration for existing plaintext boxes reuses `_migratePlaintextBoxes`; §0.5 | Migration must not lose queued events |
| `SEC-20` | ❌ | `FLAG_SECURE` / iOS screenshot protection on PII screens | `S18` | Low | S | 1 d | v1.2.0 / M7 | Security | Security, Frontend | health-PII screens, QR check-in, password sheets | — | Screenshot and screen-recording blocked on the enumerated screens; verified on both platforms; §0.5 | Hurts legitimate user screenshots — scope narrowly |
| `SEC-21` | ❌ | Root / jailbreak / emulator / Frida detection; refuse payment on compromised devices | `S19` | Low | M | 3–4 d | v1.2.0 / M7 | Security | Security, Monetization | new service | `BLK-04` | Detection signal available to the app; purchases refused on compromised devices; false-positive rate measured; §0.5 | High false-positive risk on rooted-but-legitimate devices; do not block non-payment functionality |
| `SEC-22` | ❌ | PII-redacting logger; strip `debugPrint` PII in release | `S20` | Medium | S | 1 d | v0.9.8 / M2 | Security | Security, Observability | `lib/core/services/log_service.dart`, codebase-wide | `DEBT-01` | A single logging entry point that redacts email/uid/IP/token patterns; lint or CI grep forbids raw `debugPrint` of user data; §0.5 | Over-redaction hides useful debugging — allow explicit opt-in for non-PII fields |
| `SEC-23` | ❌ | Certificate / public-key pinning for Firebase + the AI proxy | `S21` | Low | M | 2–3 d | v1.2.0 / M7 | Security | Security, Backend | `lib/core/services/ai/ai_service.dart` | endpoints stable | Pins configured with a documented rotation plan and a kill-switch via `app_config`; verified MITM attempt fails; §0.5 | **A bad pin bricks the app.** Requires a remote kill-switch and a tested rotation runbook before shipping |
| `SEC-24` | ❌ | Replay protection audit across all callables | new | Medium | S | 1 d | v0.9.9 / M3 | Security | Security, Backend | `functions/*.js` | — | Every mutating callable is idempotent or nonce-protected; `processed_purchases` pattern extended to referral apply and credit grant; verified by replaying a captured request; §0.5 | Idempotency keys add state — use short TTL documents |
| `SEC-25` | ❌ | Injection / XSS review of every rendered string | new | Low | S | 1 d | v1.0.0 / M4 | Security | Security, Frontend | community, chat, profile renderers | — | Flutter does not interpret HTML, so classic XSS does not apply; audit confirms no `WebView`, no `Html` widget, no `url_launcher` call built from unsanitised UGC; `safe_url_launcher.dart` verified as the only launch path; deep-link parameters validated before routing; §0.5 | Low residual risk today; re-audit if a WebView is ever introduced |
| `SEC-26` | ❌ | DoS / DDoS posture review | new | Medium | S | 1 d | v1.0.0 / M4 | DevOps | Security, DevOps, Backend | `functions/*`, Firebase console | `SEC-10`, `SEC-12` | Documented posture: Firebase/GCP absorbs L3/L4; app-layer protection is App Check + per-uid rate limits + `maxInstances` + global spend cap; `maxInstances` set on **every** Function (today only `aiProxy` has it); Cloud Armor evaluated for the proxy; budget alerts wired | Uncapped Functions are a cost-amplification vector — set `maxInstances` everywhere |
| `SEC-27` | ❌ | Account-takeover response runbook | new | Medium | S | 1 d | v0.9.9 / M3 | Security | Security, Documentation, Legal | `docs/` | `SEC-03`, `ADM-08` | Runbook: detect → revoke tokens → force logout → reset credentials → audit the account's writes → notify the user → report if a breach; admin tooling supports every step; rehearsed once | Untested runbooks fail under pressure — rehearse |
| `SEC-28` | ❌ | Dependency and supply-chain hygiene | `S16`, `H12`, `H13` | Medium | S | 1 d | v0.9.8 / M2 | DevOps | DevOps, Security | `pubspec.yaml`, `functions/package.json` | `BLK-13` | `uuid: any` pinned; `dependency_overrides` (incl. `analyzer: 6.4.1`) documented or removed; `pubspec.lock` + `functions/package-lock.json` committed deliberately; Dependabot enabled; `flutter pub outdated` reviewed each release | An unbounded `any` constraint is a live supply-chain risk |

---

## §4 — Architecture

#### `ARCH-01` 🔥 Eliminate swallow-and-log error handling

> This is the same task as `DEBT-01`. It is listed here because it is an **architectural** decision, not
> a cleanup chore, and because it is the single highest-leverage change in the entire backlog.

**Status** 🔥 Critical · **Priority** Critical · **Complexity** M · **Est** 1 w
**Version** v0.9.7 · **Milestone** M1 · **Owner** Principal Engineer
**Labels** `error-handling` `observability` `silent-failure` `architecture`
**Modules** Backend · Frontend · Observability
**Files** 25 literal `catch (_) {}` / `catch (e) {}` sites in `lib/` plus dozens of `catch → debugPrint → return null/[]/false`. Representative: `weekly_meal_plan_service.dart:200`, `:332` · `admin_status_service.dart` (two swallowed config reads) · `ai_service.dart:350`, `:525`, `:603` (App Check) · `dish_service.dart:21`, `:33`, `:48`
**Dependencies** — · **Required before** every verification-dependent task · **Blocking** Any trustworthy statement about what works

**What exists / what is missing**
`debugPrint` is a **no-op in release builds**. Every one of these paths therefore produces **zero signal**
in production — not in logs, not in Crashlytics, not in the UI. This pattern is the direct and sole
reason `BLK-03`, `BLK-06`, `BLK-07` and `BLK-11` were invisible: each is a permission-denied write or read
that the code catches, logs to nowhere, and papers over with an empty state.

`CrashlyticsService` is correctly wired and `GlobalErrorHandler` is the single `FlutterError.onError`
owner. The infrastructure is there. It just is not used on the failing paths.

**Acceptance Criteria**
- Every `catch` in `lib/` either: (a) reports to `CrashlyticsService` with `reason` + context, (b) re-throws, or (c) carries an inline comment justifying why the failure is genuinely ignorable.
- Zero bare `catch (_) {}` / `catch (e) {}` remain. Enforced by a CI grep.
- A permission-denied failure surfaces an `AppErrorState`, **never** an `AppEmptyState`. Users must be able to distinguish "you have no history" from "history is broken."
- `FirebaseException` with `code == 'permission-denied'` gets a distinct severity and a dedicated Crashlytics key so rules gaps are immediately visible.
- A denied-permission-rate alert exists (`BLK-17`).
- Verified: temporarily break one rule in the emulator → an error state renders and Crashlytics receives the report.

**DoD** §0.5 plus the CI grep gate active.

**Technical Notes**
Do this **before** the other blockers if sequencing allows — it converts the remaining unknown-unknowns
into visible failures. It is the difference between an audit finding seven dead paths and the system
reporting them itself.

**Risks**
A flood of newly-visible errors on first release. That is a feature. Triage by volume; expect to discover
additional broken paths beyond the seven already found.

---

#### `ARCH-02` Decompose god objects

**Status** ❌ Missing · **Priority** Medium · **Complexity** L · **Est** 2–3 w
**Version** v1.1.0 · **Milestone** M6 · **Owner** Principal Engineer
**Labels** `refactor` `maintainability` `complexity`
**Modules** Frontend
**Files** `lib/screens/admin/admin_panel_screen.dart` (3,372 LOC, **42 classes in one file**, 29 `setState`) · `lib/screens/profile/settings_screen.dart` (2,506) · `lib/screens/profile/profile_screen.dart` (2,432, 27 `_build*` on one State, 25 `setState`) · `lib/screens/home/home.dart` (1,957) · `lib/screens/gym/gym_setup_screen.dart` (1,910, 26 `setState`) · `lib/core/widgets/side_menu.dart` (1,338) · `lib/core/services/firestore_service.dart` (39.7 KB, mixed concerns)
**Dependencies** `TEST-03` (widget tests first, so refactoring is safe) · **Blocking** Onboarding a second engineer

**What exists / what is missing**
40 files exceed 800 LOC; 65 exceed 500. The top five screens total 12,177 LOC. Every `setState` in a
2,400-line State class rebuilds a very large subtree, which is also a performance issue (`PERF-04`).
`firestore_service.dart` mixes user CRUD, activity logging, streaks, notifications, device context and
PII migration.

**Acceptance Criteria**
- Each of the top 5 screens split into a feature directory: `screen.dart` (composition only) + `widgets/` + a controller or provider holding state.
- No file in `lib/screens` exceeds 800 LOC.
- `firestore_service.dart` split by concern (`user_repository`, `activity_service`, `streak_service`, `device_context_service`).
- `side_menu.dart` split into section widgets.
- Behaviour verified unchanged by the widget tests written in `TEST-03`.

**DoD** §0.5 plus no behavioural regression in the test suite.
**Technical Notes** Do **not** attempt this before `TEST-03`. Refactoring 12,000 lines of untested UI is how regressions ship.
**Risks** Pure-cost work with no user-visible benefit. Sequence after launch unless a second engineer joins, in which case do it first.

---

#### `ARCH-03` Resolve the repository layer — commit or delete

**Status** 🚧 Partial · **Priority** Medium · **Complexity** M · **Est** 1 w either direction
**Version** v1.1.0 · **Milestone** M6 · **Owner** Software Architect
**Labels** `architecture` `abstraction` `decision-needed`
**Modules** Frontend · Backend · Testing
**Files** `lib/core/repositories/` (4 files: `dish_repository.dart`, `food_log_repository.dart`, `meal_plan_repository.dart`, `shopping_repository.dart`) against **81 services**
**Dependencies** `ARCH-04` · **Blocking** A coherent testing story

**What exists / what is missing**
Four repositories exist. Their only distinguishing responsibility is intercepting `TestModeService`
(`meal_plan_repository.dart:29`, `shopping_repository.dart:14`, `food_log_repository.dart:25`,
`dish_repository.dart:29`). They do not hide Firestore from the UI — screens still call services
directly throughout — and they do not provide a testing seam beyond the test-mode flag. **The abstraction
is abandoned.**

**Acceptance Criteria**
- An explicit architectural decision recorded as an ADR in `docs/`.
- **Option A (commit):** every data-touching service gets a repository; screens call only repositories; repositories are interface-backed for testing.
- **Option B (delete):** the four repositories are removed, test-mode interception moves into the services, and `docs/ARCHITECTURE.md` stops claiming a repository layer.
- Whichever is chosen, the code and the documentation agree.

**DoD** §0.5 plus an ADR.
**Technical Notes** Recommendation: **Option A for the ~15 services with real logic, Option B for the rest.** A blanket repository over 81 singletons is ceremony; a targeted one over the AI, meal-plan, food-log, community and billing services is a genuine testing seam.

---

#### `ARCH-04` Introduce dependency injection and service interfaces

**Status** ❌ Missing · **Priority** High · **Complexity** L · **Est** 2 w
**Version** v1.1.0 · **Milestone** M6 · **Owner** Principal Engineer
**Labels** `architecture` `testability` `di` `solid`
**Modules** Backend · Frontend · Testing
**Files** All 81 services (`static final _instance = Foo._internal(); factory Foo() => _instance;`) · ~100 direct call sites of `AIService()`, `FirestoreService()`, `AuthService()`
**Dependencies** — · **Required before** `TEST-02`, `TEST-03`, `ARCH-02` · **Blocking** Test coverage above ~1 %

**What exists / what is missing**
Every service is a hand-rolled singleton with no interface. Interface Segregation and Dependency
Inversion are entirely absent. **This is the root cause of the 1.05 % test coverage** — a service graph
that can only be constructed against a live Firebase instance cannot be unit-tested, so the only tests
that exist are for pure functions (`calorie_calculator`, `allergen_safety`, `onboarding_projection`,
`streak_logic`, `meal_plan_parse`, `ai_credit_model`, `cost_analytics`, `water_reminder_schedule`,
`i18n_parity`).

**Acceptance Criteria**
- `get_it` (or constructor injection) introduced.
- The ~15 services with real business logic get abstract interfaces.
- Existing singleton `factory` constructors retained as a compatibility shim so migration is incremental and non-breaking.
- At least 5 services covered by unit tests with fake implementations, proving the seam works.
- `docs/ARCHITECTURE.md` documents the pattern and the migration status.

**DoD** §0.5 plus 5 newly-testable services with tests.
**Technical Notes** Do not convert all 81 at once. Convert on demand as each service gets tests. The compatibility shim is what makes this safe.
**Risks** A half-migrated DI graph is more confusing than either end state. Track migration status explicitly in the doc.

---

#### `ARCH-05` Consolidate the three overlapping remote-config systems

**Status** 🚧 Partial · **Priority** Medium · **Complexity** M · **Est** 3 d
**Version** v0.9.8 · **Milestone** M2 · **Owner** Software Architect
**Labels** `config` `tech-debt` `dead-code` `drift`
**Modules** Backend · Frontend · Firebase
**Files** `lib/core/services/remote_config_service.dart` (Firebase Remote Config: `maintenance_mode`, `min_version`, `ai_model`, `ai_proxy_url`, `max_meal_retries`, 2 feature flags) · `lib/core/services/admin_status_service.dart` (reads `admin_config/global` — **admin-read-only**, so every normal user's read is denied and swallowed) · `lib/core/services/app_config_service.dart` (`app_config/global` — the intended system)
**Dependencies** `ARCH-01` · **Required before** `ADM-09` · **Blocking** Confidence in which config value actually wins

**What exists / what is missing**
Three systems govern overlapping keys with an undocumented precedence order. The `AdminStatusService`
path is **permanently dead** for non-admins: `admin_config/global` is admin-read-only
(`firestore.rules:566-569`), the read is wrapped in `catch (_) {}`, and it silently falls back to Remote
Config. `RemoteConfigService`'s `feature_voice_assistant` / `feature_nutrition_analytics` flags are
superseded by `AppConfigService.isFeatureEnabled`. `ai_proxy_url` is readable from **two** sources — and
`BLK-01` makes getting it wrong catastrophic.

**Acceptance Criteria**
- `AppConfigService` (`app_config/global`) is the single source of truth.
- `AdminStatusService`'s config reads deleted; its ban logic retained and fixed per `SEC-03`.
- `RemoteConfigService` deleted, or retained **only** for A/B experiment values with that scope documented.
- `firebase_remote_config` removed from `pubspec.yaml` if unused.
- A single documented precedence: `app_config/global` → compile-time default. No third path.
- `ai_proxy_url` resolved from exactly one place.
- `docs/SERVICES.md` and `CLAUDE.md` updated.

**DoD** §0.5. **Risks** `min_version` / `maintenance_mode` are safety levers. Verify both still function after consolidation, on device, before deleting the old path.

---

#### `ARCH-06` Data-migration framework — versioned, idempotent, logged

**Status** ❌ Missing · **Priority** High · **Complexity** M · **Est** 1 w
**Version** v0.9.8 · **Milestone** M2 · **Owner** Software Architect
**Labels** `migration` `data` `architecture`
**Modules** Backend · Database · DevOps
**Files** ad-hoc precedents: `firestore_service.verifyAndRepairUserData`, `getPrivateNutritionData` (PII migration), `storage_service._migratePlaintextBoxes`
**Dependencies** — · **Required before** `BLK-08`, `BLK-10`, `SEC-14` · **Blocking** Any schema change against live data

**What exists / what is missing**
`CLAUDE.md` R2 requires migrations to be "versioned, idempotent, logged." Three ad-hoc migrations exist
with no framework, no version tracking, and no record of which users have been migrated. Several
upcoming blockers **require** backfills: user-doc split (`BLK-10`), counter reconciliation (`BLK-08`),
streak/reputation recompute (`SEC-14`), notification-path migration (`BLK-03`).

**Acceptance Criteria**
- A `migrations/` module with a registry of numbered, named migrations.
- `users/{uid}.schema_version` (or a server-side migration-state collection) tracks per-document progress.
- Each migration is idempotent, resumable, batched, rate-limited, and writes progress + errors to a log collection.
- An admin-triggered dry-run mode reports what *would* change.
- Rollback strategy documented per migration (or explicitly marked one-way).
- The `BLK-10` user-doc split implemented as the first real migration on this framework.

**DoD** §0.5 plus one migration executed with a report.
**Risks** Un-resumable migrations that fail midway leave inconsistent data. Batching and progress tracking are mandatory, not optional.

---

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Modules | Files | Deps | Acceptance / DoD summary | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `ARCH-07` | ❌ | Offline write queue + conflict resolution + sync-status UI | Low | L | 1–2 w | v1.2.0 / M7 | Architect | Frontend, Database, UX | `lib/core/services/storage_service.dart`, Firestore settings | `ARCH-04` | Queue pending writes locally, replay on reconnect, last-write-wins or per-field merge documented, a visible sync indicator, conflict UX for weight/food entries; §0.5. Prior roadmap deferred this pending retention data — that decision stands until D7 data exists | Half-built offline is worse than none; the current honest state (Firestore SDK cache only) is acceptable for v1 |
| `ARCH-08` | ❌ | Bound the Firestore local cache | Low | XS | 1 h | v0.9.8 / M2 | Architect | Database, Performance | `lib/core/services/app_initialization_service.dart:213-215` | — | Replace `CACHE_SIZE_UNLIMITED` with an explicit bound (e.g. 100 MB); measure on-device cache growth over a week; §0.5 | Too small a cache increases reads and cost — measure before choosing |
| `ARCH-09` | ❌ | Split `functions/index.js` (980 LOC, mixed concerns) | Medium | S | 2 d | v0.9.8 / M2 | Backend | Backend | `functions/index.js` (AI proxy + push fan-out + broadcasts + 2 cron producers in one file) | — | Split into `ai.js`, `push.js`, `broadcasts.js`, `cron.js`; `index.js` becomes re-exports only; no behaviour change; deploy verified; §0.5 | A bad split breaks exports and silently un-deploys a trigger — verify every function is still listed after deploy |
| `ARCH-10` | ❌ | Migrate Cloud Functions to v2 API | Medium | M | 1 w | v1.1.0 / M6 | Backend | Backend, DevOps | all `functions/*.js` (currently `functions.https.onRequest`, `functions.firestore.document`) | `ARCH-09` | All functions on v2; concurrency and CPU tuned; `maxInstances` set on every function (`SEC-26`); native `fetch` replaces `node-fetch`; deploy verified; prior roadmap tracked this as Phase 5T | v1 and v2 triggers on the same path can double-fire during migration — migrate per-function with verification |
| `ARCH-11` | ❌ | Fix `posts` timestamp-field drift | Medium | S | 1 d | v0.9.8 / M2 | Architect | Database, Firebase | `firestore.indexes.json` (`posts` indexed on `createdAt`, `created_at` **and** `timestamp`), `lib/core/models/community_post.dart` | `ARCH-06` | One canonical timestamp field chosen; a migration backfills it; the two redundant indexes deleted; the documented camelCase-identity / snake_case-everything-else convention in `CLAUDE.md` verified against every model; §0.5 | Deleting an index still in use breaks a query — grep every `orderBy` first |
| `ARCH-12` | ❌ | De-duplicate the triplicated HTTP logic in `AIService` | Medium | S | 1 d | v0.9.8 / M2 | AI Architect | AI, Backend | `lib/core/services/ai/ai_service.dart:330-397`, `:488-571`, `:573-653` | `BLK-01` | One `_post()` helper handling headers, release guard, timeout, status branching; the three public methods become thin wrappers; ~120 duplicated lines removed; §0.5 | This is the most security-sensitive file — a fix applied to one branch currently misses the other two, which is exactly why this matters |

---

## §5 — Infrastructure & Environments

| ID | Status | Title | Prior | Priority | Cx | Est | Version | Owner | Modules | Files | Deps | Acceptance / DoD summary | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `INF-01` | ❌ | 🔥 Separate `dev` / `staging` / `prod` Firebase projects | `S16`, `H12` | Critical | M | 3–4 d | v0.9.7 / M1 | DevOps | DevOps, Firebase, Backend | `.firebaserc` (single project `cookrange-app`), `firebase.json`, `functions/.env` | — | Three projects with `.firebaserc` aliases; `--dart-define` flavour selects the config; `APP_ENV` per project; seeding and demo content only in non-prod; CI deploys to staging on `main`, prod on tag; documented promotion process; §0.5 | Today one project is dev, staging and prod simultaneously — every `BLK-14` / `BLK-11` fix is untestable without this. Highest-leverage infra task |
| `INF-02` | ❌ | Firebase Emulator Suite as the default local workflow | prior arch rec 7 | High | S | 1 d | v0.9.7 / M1 | DevOps | DevOps, Testing | `firebase.json` (emulator ports already configured) | `BLK-13` | `scripts/dev.sh` starts emulators + seeds; rules tests run against the emulator locally and in CI; documented in `docs/`; developers never point local builds at prod | Emulator behaviour differs subtly from prod (rules `get()` cost, index enforcement) — verify critical paths against staging too |
| `INF-03` | ❌ | Deploy Functions, rules and indexes as a repeatable, verified step | `5.2`, `5.3` | Critical | S | 1 d | v0.9.7 / M1 | DevOps | DevOps, Backend, Firebase | `firebase.json`, `.github/workflows/` | `INF-01` | A CI job deploys `functions,firestore:rules,firestore:indexes,storage` to staging and verifies every expected function is listed and every rule file hash matches; the known flakiness (cross-region "failed to update" landing async, back-to-back "operation already in progress") handled with retry + wait | The prior roadmap records this deploy as flaky. Without post-deploy verification a partial deploy looks successful |
| `INF-04` | ❌ | Secret management via Secret Manager, not `.env` | `S0` residual | High | S | 1 d | v0.9.7 / M1 | DevSecOps | DevOps, Security | `functions/index.js:287-289` (Secret Manager commented out), `functions/.env` | `BLK-15` | `OPENROUTER_API_KEY`, Apple `.p8`, Google Play SA JSON bound via `firebase functions:secrets:set`; `functions/.env` holds no secrets; rotation documented | `functions/.env` is gitignored but sits in plaintext on every dev machine and in the deploy bundle |
| `INF-05` | ❌ | Cost budget alerts + spend caps | `5.5`, `S22` | High | XS | 2 h | v0.9.7 / M1 | DevOps | DevOps, Monetization | GCP console, OpenRouter console | — | GCP budget alerts at 50/80/100 % of a defined monthly ceiling; hard OpenRouter spend cap; alerts to a real channel; documented monthly review | A runaway Function or unbounded query is a cost event, not just a perf event |
| `INF-06` | ❌ | Cloud Tasks fan-out to replace the 500-user cron cap | new | High | M | 3 d | v1.0.0 / M4 | Backend | Backend, DevOps | `functions/index.js` (`streakAtRiskNotifier`, `weeklyPlanReadyNotifier`, `resolveBroadcastAudience` — all capped at 500) | `BLK-03` | Paginated enumeration enqueueing Cloud Tasks; no user cap; idempotent per user per day; throughput measured; **breaks at 500 active users today** | Silently capping at 500 means 83 % of a 3,000-DAU base never receives reminders — and nothing reports it |
| `INF-07` | ❌ | Deep-link server files hosted | `5.6` | High | XS | 2 h | v1.0.0 / M4 | DevOps | DevOps, Store, Product | `android/app/src/main/AndroidManifest.xml` (App Links configured), `ios/Runner/Runner.entitlements` | `BLK-16` | `.well-known/assetlinks.json` and `apple-app-site-association` hosted at `cookrangeapp.com` with correct content types; verified with Apple's and Google's validators; a shared referral link opens the app on both platforms | Referral and sharing virality is entirely dead until this is hosted — the client side is already built |

---

## §6 — Backend & Cloud Functions

**Deployed inventory (13 exports, 1,692 LOC).** `aiProxy` · `onInAppNotificationCreated` ·
`onChatMessageCreated` · `onBroadcastCreated` · `drainScheduledBroadcasts` · `streakAtRiskNotifier` ·
`weeklyPlanReadyNotifier` · `scanImage` · `validatePurchase` · `appStoreNotifications` · `playRtdn` ·
`applyReferral` · `deleteUserAccount`.

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Modules | Files | Deps | Acceptance / DoD summary | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `BE-01` | 🚧 | 🔥 Deploy `aiProxy` and set `ai_proxy_url` in `app_config/global` | Critical | S | 1 d | v0.9.7 / M1 | Backend | Backend, AI, Firebase | `functions/index.js:285`, `app_config/global.endpoints.ai_proxy_url` | `INF-01`, `INF-03`, `BLK-14` | Function deployed with the public-invoker role; `ai_proxy_url` set; a real client call from a release build returns real AI content; a `curl` without App Check returns 401; **`BLK-01` is meaningless without this** | The prior roadmap claims 10/12 functions are deployed; this audit could not verify from the repo. Verify explicitly, do not assume |
| `BE-02` | ❌ | 🔥 Align the AI proxy timeout with the client | Critical | XS | 1 h | v0.9.7 / M1 | Backend | Backend, AI | `functions/index.js:292` (`timeoutSeconds: 30`), `lib/core/services/ai/ai_service.dart:25` (90 s client) | — | Both set to the same value (60 s recommended); a long generation either completes or fails consistently; retries no longer stack onto server-killed requests; §0.5 | Today the server kills a request at 30 s while the client waits to 90 s then retries — burning quota on requests that cannot succeed |
| `BE-03` | ❌ | Server-authored notification callable | Critical | M | — | v0.9.7 / M1 | Backend | Backend, Security | see `SEC-06` | `BLK-03` | Tracked in `SEC-06` — listed here for backend inventory completeness | — |
| `BE-04` | ❌ | Server-maintained counters trigger | Critical | M | — | v0.9.7 / M1 | Backend | Backend, Database | see `BLK-08` | — | Tracked in `BLK-08` | — |
| `BE-05` | ❌ | Admin callable for signed application-document URLs | High | S | 1 d | v1.1.0 / M6 | Backend | Backend, Security, Store | `storage.rules` (notes the gap), `lib/screens/admin/application_review_screen.dart` | `BLK-05` | `getApplicationDocumentUrl(uid, fileName)` verifies admin, returns a 15-minute signed URL; the review UI uses it; no public download tokens minted for ID/business documents; audit-logged | Coach/gym approval currently cannot verify evidence at all — reviewers are approving blind |
| `BE-06` | ❌ | `maxInstances` on every Function | High | XS | 1 h | v0.9.7 / M1 | Backend | Backend, DevOps, Security | all `functions/*.js` (only `aiProxy` sets it) | — | Every function has an explicit `maxInstances` sized to its workload; documented rationale; verified after deploy | An uncapped trigger under load is a cost-amplification and quota-exhaustion vector |
| `BE-07` | ❌ | API versioning on the proxy contract | Low | S | 1 d | v1.2.0 / M7 | Backend | Backend, DevOps | `functions/index.js`, `lib/core/services/ai/ai_service.dart` | — | `/v1/` path prefix or an `X-API-Version` header; the server supports N and N−1; a breaking change no longer strands old clients (today the force-update gate is the only lever) | Force-update as the only compatibility mechanism is user-hostile |
| `BE-08` | ❌ | Idempotency on all mutating callables | Medium | S | — | v0.9.9 / M3 | Backend | Backend, Security | see `SEC-24` | — | Tracked in `SEC-24` | — |
| `BE-09` | ❌ | Structured Function logging with correlation IDs | Medium | S | 1 d | v0.9.8 / M2 | Backend | Backend, Observability | all `functions/*.js` | `BLK-17` | Every log line carries a request id, uid and function name; client sends a correlation id; a single user journey is traceable across client → proxy → OpenRouter; log-based metrics defined | Debugging a distributed AI failure without correlation is guesswork |
| `BE-10` | ❌ | Reconcile group `member_count` | Medium | S | 1 d | v1.1.0 / M6 | Backend | Backend, Database | `lib/core/services/community_group_service.dart` (client-incremented) | `BLK-08` | Count maintained by a trigger on `community_groups/{id}/members`; a one-off reconciliation corrects existing values; client writes denied. Carried from the Phase 13 follow-up note | Client-incremented counters drift and are forgeable |

---

## §7 — Firebase: Firestore, Rules, Indexes, Storage

### 7.1 Rules — missing paths (each is a silent-failure class)

| ID | Status | Path | Written by | Priority | Cx | Est | Version | Owner | Deps | Acceptance |
|---|---|---|---|---|---|---|---|---|---|---|
| `FB-01` | ✅ | `users/{uid}/meal_plan_history/{key}` | `weekly_meal_plan_service.dart:191`, `:318` | Critical | XS | 2 h | v0.9.7 / M1 | Firebase Architect | — | Rule written, tested, and deployed — `BLK-06` closed |
| `FB-02` | 🔥 | `notifications/{uid}/items/{id}` | `admin_service.dart:234`, `:316`, `:353`, `:387` | Critical | M | 2–3 d | v0.9.7 / M1 | Firebase Architect | — | Tracked as `BLK-03` |
| `FB-03` | 🔥 | `gyms/{gymId}/logo.jpg` (Storage) | `storage_upload_service.dart:145` | Critical | XS | 4 h | v1.1.0 / M6 | Firebase Architect | — | Tracked as `BLK-07` |
| `FB-04` | ❌ | **Full path/rule reconciliation audit** | every collection | Critical | M | 2 d | v0.9.7 / M1 | Firebase Architect | `BLK-13` | Extract every Firestore and Storage path written or read anywhere in `lib/` and `functions/`; assert each has a rule; a CI script fails on any unmatched path. **Three mismatches were found by hand — this makes the check permanent.** §0.5 |

### 7.2 Rules — authorization holes

| ID | Status | Hole | Rule line | Priority | Tracked as |
|---|---|---|---|---|---|
| `FB-05` | 🔥 | `posts` update lets any user write any non-content field | `firestore.rules:195-199` | Critical | `BLK-08` |
| `FB-06` | 🔥 | `programs` create allows `coach_uid == 'demo'` from any user | `:458-460` | Critical | `BLK-09` |
| `FB-07` | 🔥 | `users/{uid}` read exposes email, IP, device fingerprints | `:68` | Critical | `BLK-10` |
| `FB-08` | 🔥 | `users/{uid}/notifications` create by any authenticated user | `:96` | Critical | `SEC-06` |
| `FB-09` | 🔥 | `users/{uid}/friends` create/update by any authenticated user | `:78-80` | Critical | `SEC-06` |
| `FB-10` | 🔥 | `users/{uid}/friend_requests` create/update by any authenticated user | `:86-87` | Critical | `SEC-06` |
| `FB-11` | 🔥 | `gyms/{gymId}/posts` create by any authenticated user | `:378-381` | High | `SEC-07` |
| `FB-12` | 🔥 | `gym_logos` write/delete by any authenticated user (dead rule, real hole) | `storage.rules` | High | `BLK-07` |
| `FB-13` | 🔥 | Group chat images readable by any authenticated user | `storage.rules` | High | `SEC-13` |
| `FB-14` | ❌ | `dishes` write requires `isAdmin()`, which nothing satisfies | `:178` | Critical | `BLK-11` |

### 7.3 Rules & index hygiene

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `FB-15` | ❌ | Delete dead `challenges` rules + 2 indexes | Medium | XS | 1 h | v0.9.8 / M2 | Firebase Architect | `firestore.rules:296-304`, `firestore.indexes.json` (2 `challenges` indexes) | — | Both removed. **The prior roadmap (13.2) claimed this was done — it was not.** See `DEBT-11` | Re-adding them if Challenges 2.0 ships (`CHL-01`) is trivial; leaving reserved infrastructure for a non-existent feature is how documentation starts lying |
| `FB-16` | ✅ | Delete the orphaned `meal_plan_history` index or add the rule | Medium | XS | 15 m | v0.9.7 / M1 | Firebase Architect | `firestore.indexes.json` | `BLK-06` | Rule added and deployed (preferred option) — the index is no longer orphaned | — |
| `FB-17` | ❌ | Bound every unbounded listener and query | High | M | 2 d | v0.9.8 / M2 | Performance Engineer | `dish_service.dart:17` (unbounded `.get()` on `dishes`, called per plan generation), `:56` (unbounded `.snapshots()`), plus 12 other files using `.snapshots()` with no `.limit()` in-file | `BLK-11` | Every collection query has `.limit()` or is provably single-doc; the `dishes` listener paginated or replaced; a CI lint or review checklist item enforces it. Directly violates the repo's own Performance Playbook (`S23`) | At 75 dishes the cost is trivial; at 5,000 it is 5,000 reads per plan per user |
| `FB-18` | 🚧 | Rules test suite covering every match block | Critical | L | 1 w | v0.9.7 / M1 | QA Lead | `test/firestore_rules/rules.test.mjs` (tracked, **running green in CI** — [run #40](https://github.com/burcok/cookrange/actions/runs/30667024406)) | `BLK-13` | 15 of 71 match blocks covered (economy lock, PII, admin self-grant, content caps), all passing. Still open: the other ~56 blocks, and making the CI job **required** | The suite that would have caught 5 of the 17 blockers now runs and passes for its current scope — extending coverage is the remaining value here |
| `FB-19` | ❌ | Reduce `isAdmin()` read cost | Low | S | 1 d | v1.1.0 / M6 | Firebase Architect | `firestore.rules:27-35` | `SEC-04` | Once admin is a custom claim, `isAdmin()` reads `request.auth.token.admin` instead of `exists()` + `get()` — removing 2 document reads per admin-gated operation | Claim propagation lag; keep the doc check as a fallback during migration |
| `FB-20` | ❌ | Document the field-naming convention as an enforced test | Medium | S | 1 d | v0.9.8 / M2 | Software Architect | `CLAUDE.md` (documents camelCase identity / snake_case everything else), all 48 models | `ARCH-11` | A test asserts every model's `toMap`/`fromMap` key casing matches the convention; the two production bugs this drift already caused (admin user search, admin name columns) have regression tests | The convention is deliberate and documented; the risk is future drift, not the current state |

### 7.4 Firebase service tasks

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `FB-21` | ❌ | Firestore scheduled export + verified restore | Critical | S | 1 d | v0.9.7 / M1 | DevOps | GCP console, `docs/` | `INF-01` | Tracked as `DR-01`/`DR-02` | — |
| `FB-22` | ❌ | Crashlytics release symbol upload | High | S | 1 d | v0.9.9 / M3 | DevOps | `.github/workflows/deploy.yml` | `SEC-18` | Obfuscated release symbols uploaded on every deploy; a test crash produces a readable stack trace in the console | Without this, obfuscated release crashes are undebuggable |
| `FB-23` | ❌ | Firebase Performance traces on the 5 primary screens + startup | High | S | 1 d | v0.9.7 / M1 | Performance Engineer | `lib/core/services/performance_service.dart` (wrapper exists; only one HTTP metric instrumented) | `BLK-17` | Startup trace, plus traces on home, meal plan, community feed, food scan, profile; a measured cold-start number recorded in `docs/` | **Every performance claim in this backlog is a structural inference, because the project produces no measurements** |
| `FB-24` | ❌ | Firestore → BigQuery export | Medium | S | 1 d | v1.0.0 / M4 | DevOps | GCP console | `INF-01` | Export extension installed on `users`, `food_logs`, `posts`, `ai_usage_logs`; scheduled queries for D1/D7/D30 retention, onboarding funnel, paywall conversion. Enable **early** — the data is only useful once it has accrued | Cheap to turn on now, impossible to backfill later |

---

## §8 — Authentication

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Modules | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `AUTH-01` | ✅ | Email/password sign-in, registration, verification polling + resend cooldown, password reset | — | — | — | shipped | — | Auth | `auth_service.dart`, `login_screen.dart`, `register_screen.dart`, `verify_email.dart`, `forgot_password_screen.dart` | — | Verified working | — |
| `AUTH-02` | 🚧 | Google Sign-In — needs SHA-1/256 registered | High | XS | 0.5 d + console | v0.9.9 / M3 | DevOps | Auth, Store | `auth_service.dart`, Firebase console | `BLK-16` | SHA-1 + SHA-256 of both the upload key and the Play App Signing key registered; sign-in verified on a **Play-signed** build, not just debug | Play re-signs the app — registering only the upload key's SHA silently breaks Google Sign-In in production |
| `AUTH-03` | 🚧 | Apple Sign-In — needs App ID + capability | High | XS | 0.5 d + console | v0.9.9 / M3 | DevOps | Auth, Store | `auth_service.dart` (iOS-guarded), Apple Developer console | `BLK-16` | Sign in with Apple capability enabled on the App ID; verified on a TestFlight build; the private-relay email address handled (it is not a deliverable address) | Apple **requires** Sign in with Apple when other social logins exist — omitting it is a rejection |
| `AUTH-04` | ❌ | Login throttling, lockout, enumeration-safe errors | Critical | M | 3–4 d | v0.9.8 / M2 | DevSecOps | Security, Auth | see `SEC-01` | — | Tracked in `SEC-01` | — |
| `AUTH-05` | ❌ | MFA | Medium | L | 1–2 w | v1.2.0 / M7 | DevSecOps | Security, Auth | see `SEC-02` | `SEC-01` | Tracked in `SEC-02` | — |
| `AUTH-06` | 🚧 | Email-verification hard gate — close the `mealPlanGeneration` exemption | Medium | XS | 2 h | v0.9.7 / M1 | Flutter Engineer | Auth, Frontend | `lib/core/utils/route_guard.dart` §C | `BLK-01` | `AppRoutes.mealPlanGeneration` no longer exempt from the verification gate, **or** the exemption is documented with the reason it is safe. Today an unverified account can reach AI generation and consume quota | Removing the exemption may strand accounts mid-onboarding — verify the `OnboardingCompletion` routing still works |
| `AUTH-07` | ❌ | Server-side email-verification enforcement in rules | High | S | 1 d | v0.9.8 / M2 | Security | Security, Firebase | `firestore.rules` | `FB-18` | Write-gated collections additionally require `request.auth.token.email_verified == true`; the client gate becomes defence in depth rather than the only control (`S12`) | Social-auth accounts arrive verified; email accounts must not be locked out of onboarding writes — scope the requirement to post-onboarding collections |
| `AUTH-08` | 🚧 | Session revocation on credential change; mid-session ban | High | M | 2–3 d | v0.9.8 / M2 | DevSecOps | Security, Auth | see `SEC-03` | `BLK-05` | Tracked in `SEC-03` | — |
| `AUTH-09` | ✅ | Single-session enforcement (force logout on session-token mismatch) | — | — | — | shipped | — | Auth | `auth_service.dart` `_startSessionMonitoring` | — | Verified working | — |
| `AUTH-10` | ❌ | Account recovery when the verification email never arrives | Medium | S | 1 d | v1.0.0 / M4 | Product | Auth, UX, Documentation | `verify_email.dart` | — | A self-service path: change the email address before verification, resend with a visible cooldown, and a support contact route; copy explains spam folders and typo'd addresses | A stranded unverified account is unrecoverable today and generates support load |
| `AUTH-11` | ❌ | Delete-account re-authentication hardening | Medium | S | 1 d | v0.9.8 / M2 | Security | Auth, Security, Legal | `auth_service.dart` `deleteAccount`, `settings_screen.dart` danger zone | `BLK-12` | Recent re-authentication required before erasure; the social-auth re-auth path verified for Google **and** Apple; copy states the action is irreversible and lists what is deleted | An unauthenticated erasure path is an account-destruction vector |
| `AUTH-12` | ❌ | Remove email from analytics events | High | XS | 2 h | v0.9.8 / M2 | DevSecOps | Analytics, Legal, Security | `auth_service.dart` (password-reset / verify events) | — | No analytics event carries an email address or any direct identifier (`S17`, `H22`) | Emails in analytics is a straightforward GDPR finding |

---

## §9 — Authorization & Roles

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `AUTHZ-01` | ✅ | `UserRole` enum (`consumer`/`gymOwner`/`coach`/`admin`) + role-aware side menu, quick actions, home card | — | — | — | shipped | — | `user_model.dart`, `side_menu.dart`, `quick_actions_sheet.dart`, `role_quick_card.dart` | — | Verified working | — |
| `AUTHZ-02` | 🔥 | Admin authority via custom claim | Critical | M | 2 d | v0.9.7 / M1 | Security | see `BLK-05`, `SEC-04` | — | Tracked in `BLK-05` + `SEC-04` | — |
| `AUTHZ-03` | ❌ | Granular admin scopes | Low | M | 3–4 d | v1.2.0 / M7 | Security | see `SEC-05` | `SEC-04` | Tracked in `SEC-05` | — |
| `AUTHZ-04` | ✅ | Live role refresh after admin approval (menus/labels update without restart) | — | — | — | shipped | — | `UserProvider` user-doc listener | — | Verified working (Phase 12.4) | — |
| `AUTHZ-05` | ❌ | Document that self-service `coach`/`gymOwner` role writes confer **no capability** | Medium | XS | 2 h | v0.9.8 / M2 | Security | `firestore.rules:45-56`, `docs/COMPLIANCE.md` | `SEC-04` | An ADR records the decision; a rules test asserts a self-written role grants no read or write it did not already have | The reasoning is currently a rules comment only — it must survive future rule edits |

---

## §10 — AI System

### 10.1 Critical AI work

| ID | Status | Title | Priority | Tracked as |
|---|---|---|---|---|
| `AI-01` | ✅ | Remove the mock-data fallback | Critical | `BLK-01` |
| `AI-02` | 🔥 | Deploy the proxy and set `ai_proxy_url` | Critical | `BE-01` |
| `AI-04` | 🔥 | Global spend circuit breaker | Critical | `SEC-10` |
| `AI-05` | 🔥 | Align proxy/client timeouts | Critical | `BE-02` |

---

#### `AI-03` 🔥 Pre-filter the dish catalog before prompting — remove the 180-dish ceiling

**Status** ❌ Missing · **Priority** Critical · **Complexity** M · **Est** 3 d
**Version** v0.9.7 · **Milestone** M1 · **Owner** AI Architect
**Labels** `ai` `token-optimization` `scalability` `product-ceiling`
**Modules** AI · Backend · Product · Performance
**Files** `lib/core/services/ai/prompt_service.dart` (`generateWeeklyMealPlanPrompt` inlines the whole catalog) · `functions/index.js:45` (`MAX_TOTAL_CHARS = 24000`) · `lib/core/services/weekly_meal_plan_service.dart:72` · `lib/core/utils/allergen_safety.dart`
**Dependencies** — · **Required before** `BLK-11` (catalog expansion) · **Blocking** Any dish-catalog growth, and therefore product credibility

**What exists / what is missing**

`generateWeeklyMealPlanPrompt` embeds **every dish** in the catalog at roughly 120 characters each. With
75 dishes that is ~9 KB; add the profile, schema and guard and a request is ~11 KB. The proxy enforces
`MAX_TOTAL_CHARS = 24000`.

**Hard ceiling: approximately 180 dishes before every meal-plan request returns HTTP 413
`payload_too_large`.**

This is the only ceiling in the system that constrains the **product** rather than the infrastructure,
and it is the least obvious. A meal planner cannot ship long-term with a 180-recipe cap — and `BLK-11`
requires growing the catalog to ≥ 300 to stop visible repetition.

The correct pattern already exists in this codebase: `allergen_safety.dart` filters the pool *before* the
model sees it. Extend that idea from safety to relevance.

**Acceptance Criteria**
- A candidate selector narrows the catalog to **40–60 dishes** before prompting, filtered by: allergen safety (existing), dietary restrictions, dislikes, calorie band around the daily target, meal-type coverage (≥ 8 candidates per slot), and category variety.
- Selection is deterministic given the same inputs (so the plan hash stays stable) but varies across regenerations via a seed.
- Prompt size measured and asserted < 8 KB regardless of catalog size.
- A unit test asserts the selector returns ≥ 8 candidates per meal type for a representative set of restrictive profiles, and never returns an allergen-unsafe dish.
- A test asserts prompt size stays bounded with a synthetic 1,000-dish catalog.
- Plan quality manually reviewed against the current output for 5 diverse profiles — variety must not regress.

**DoD** §0.5 plus the 1,000-dish bound test.

**Technical Notes**
Land this **before** expanding the catalog, or expansion breaks generation. Also fixes the unbounded
`dishes` read (`FB-17`) as a side effect: the selector can query with `where` + `limit` instead of
fetching everything.

**Risks**
Over-narrowing produces repetitive plans — the exact problem being solved. Enforce a minimum candidate
count per slot and monitor plan variety.

**Future improvements** `AI-15` embedding-based dish similarity for smarter candidate selection.

---

### 10.2 AI reliability, quality and management

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Modules | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `AI-06` | ❌ | Semantic validation of AI output | High | M | 3 d | v1.0.0 / M4 | AI Architect | AI, Testing | `weekly_meal_plan_service.dart`, `food_analysis_service.dart`, `ai_insight_service.dart` | `AI-03` | Returned `total_calories`, `avg_macros` and per-day macros **cross-checked against the catalog's real nutrition values**; mismatches beyond a tolerance are recomputed server-side or rejected and retried; the same for `NutritionEstimate` (macros must reconcile with the stated calories at 4/4/9); a test suite of malformed and arithmetically-wrong responses asserts rejection | Structure is validated today (`meal_plan_parse_test.dart`); **semantics are not** — a hallucinated or arithmetically wrong plan is accepted and displayed as fact in a health app |
| `AI-07` | ❌ | Fallbacks for meal plan and recipe (real, not fabricated) | High | M | 3 d | v0.9.7 / M1 | AI Architect | AI, Product | `weekly_meal_plan_service.dart`, `recipe_generation_service.dart` | `BLK-01` | When AI is unavailable, generate a **deterministic** plan from the catalog by calorie/macro fit — clearly labelled as a non-AI plan — or show an error state. Never fabricate. Mirrors the `_fallbackInsight` / `_fallbackProjection` pattern that already exists and works | A deterministic fallback is a genuinely useful degraded mode; a fake AI plan is a lie |
| `AI-08` | ❌ | Fix `AiChatService`'s configuration-leaking fallback | Medium | XS | 1 h | v0.9.7 / M1 | AI Architect | AI, UX | `lib/core/services/ai/ai_service.dart:304-306` | `BLK-01` | The canned "I need an API key" string replaced with a branded error state. It currently leaks internal configuration state to end users | Minor, but it is user-visible evidence of a misconfigured backend |
| `AI-09` | ❌ | Consolidate all 17 prompts into `PromptService` with versioning | High | M | 1 w | v0.9.8 / M2 | AI Architect | AI, Documentation | `prompt_service.dart` (4 prompts), `ai_insight_service.dart` (~9 inline), `food_analysis_service.dart` (2), `recipe_generation_service.dart` (1), `ai/ai_chat_service.dart` (1) | `SEC-11` | Every prompt lives in `PromptService`, carries the injection guard, uses `fence()` for user text, and has a version constant; prompt changes are reviewable in one file; `docs/SERVICES.md` documents the catalogue | Prompt fragmentation is why the injection guard covers only 4 of 17 prompts |
| `AI-10` | ❌ | Prompt eval harness with golden outputs | Medium | M | 1 w | v1.0.0 / M4 | AI Architect | AI, Testing | new `test/ai_evals/` | `AI-09` | A fixture set of profiles → expected output shape and quality assertions; run on demand against a real model and in CI against recorded responses; a prompt change that degrades output is caught before ship | Without this, prompt tuning is guesswork and regressions are invisible |
| `AI-11` | ❌ | Provider abstraction (break single-provider lock-in) | Medium | M | 1 w | v1.1.0 / M6 | AI Architect | AI, Backend | `ai_service.dart`, `functions/index.js` | `ARCH-12` | An `AiProvider` interface with an OpenRouter implementation; adding Anthropic or OpenAI direct is a new class, not a rewrite of three duplicated HTTP methods; model routing per request type stays server-side | Single-provider outage is a total AI outage today |
| `AI-12` | ❌ | Externalise `MODEL_PRICING`; alert on `unpriced` | Medium | S | 1 d | v0.9.8 / M2 | AI Architect | AI, Analytics, Backend | `functions/index.js:62-73` (3 models only) | `SEC-10` | Pricing read from `app_config/global`; any request logged with `unpriced: true` raises an alert; the admin cost dashboard flags it visibly | Cost reporting silently under-reports to zero for any unlisted model |
| `AI-13` | ❌ | Streaming responses for chat | Low | M | 3–4 d | v1.2.0 / M7 | AI Architect | AI, Frontend, UX | `ai_chat_screen.dart`, `functions/index.js` | `AI-11` | Token-by-token rendering in AI chat; perceived latency materially reduced; graceful degradation when the provider does not stream | Streaming through a Function requires SSE or a different transport — evaluate Cloud Run |
| `AI-14` | ❌ | Behavioural analytics → ML feature pipeline | Low | XL | 3–6 w | v2.0.0 / Icebox | AI Architect | AI, Analytics, Backend | `FB-24` BigQuery export | `FB-24`, real user data | Event schema → BigQuery → feature tables → model training for adherence prediction and plan adaptation. **Deferred until real data accrues** — carried from prior Phase 6 and `FUTURE_FEATURES` C1. Turn the export on now (`FB-24`) so data accumulates | Building ML before data exists is the classic waste; the export is the only thing needed today |
| `AI-15` | ❌ | Embedding-based dish similarity for candidate selection | Low | M | 1 w | v1.2.0 / Icebox | AI Architect | AI, Database | `AI-03` selector | `AI-03` | Dish embeddings enable "similar to what you liked" and smarter variety than category rules | Only worth it once the catalog exceeds ~500 dishes |
| `AI-16` | ❌ | Dynamic plan adaptation from adherence | Low | M | 1 w | v1.2.0 / Icebox | AI Architect | AI, Product | `weekly_meal_plan_service.dart` | `AI-14` | Plans adapt to which meals the user actually logs vs skips. Carried from `FUTURE_FEATURES` C2 | Needs adherence data volume |
| `AI-17` | ✅ | AI daily insight / Fitness Twin / weekly recap — locale-aware, cached, persisted, `isConfigured`-guarded, credit-metered with rollback | — | — | — | shipped | — | — | `ai_insight_service.dart`, `ai_fitness_twin_screen.dart`, `weekly_recap_screen.dart`, `ai_insight_card.dart`, `weekly_recap_card.dart` | — | Verified working. Stale-while-revalidate; regeneration only on explicit request or input-hash change | — |
| `AI-18` | ✅ | AI risk detection (client-side, zero AI cost) | — | — | — | shipped | — | — | `ai_insight_service.detectRiskLevel()` | — | Verified working | — |
| `AI-19` | ✅ | Deterministic allergen pre-filter | — | — | — | shipped | — | — | `lib/core/utils/allergen_safety.dart` + unit tests | — | Verified working. **Do not replace with prompt instructions** | — |
| `AI-20` | ✅ | AI credit ledger — server-authoritative, read-only client, bonus-first consumption | — | — | — | shipped | — | — | `functions/index.js:197-252`, `ai_credit_service.dart`, `ai_credit_model.dart` + tests | — | Verified working | — |
| `AI-21` | ✅ | Real AI cost metering — tokens × per-model price → logs, aggregates, per-user lifetime | — | — | — | shipped | — | — | `functions/index.js:85-137` | — | Verified working (only via the proxy; debug direct calls are not logged) | — |
| `AI-22` | ❌ | Vision model availability + graceful photo degradation on iOS | High | S | 1 d | v0.9.7 / M1 | AI Architect | AI, Frontend | `food_scan_screen.dart`, `food_analysis_service.dart:110` | — | `isVisionAvailable` correctly hides the photo option; the camera and gallery paths verified on a **physical** iPhone (Simulator-only confirmed so far); the `OPENROUTER_VISION_MODEL` default documented | The iOS crash that made this untestable is fixed (`BLK-02`); physical-device confirmation is still owed once one is available |
| `AI-23` | 🚧 | Voice assistant — verify end to end, then keep or cut | Medium | S | 2 d | v1.0.0 / M4 | AI Architect | AI, Frontend, UX | `lib/core/widgets/voice_assistant_overlay.dart`, `main_scaffold.dart:165` (gated on `NavigationProvider.isVoiceAssistantOpen`), `ai/ai_chat_history_service.dart` (voice↔text transitions), `speech_to_text: ^7.3.0`, `RECORD_AUDIO`, `NSSpeechRecognitionUsageDescription` | `ARCH-05`, `SEC-11` | **The Phase 2 fix held** — the transcript now routes to `AIChatScreen(initialMessage:)` at three call sites (`:451`, `:474`), so it is no longer the "non-functional demo" the original audit described. Verify: Turkish speech recognition accuracy on device, the microphone-permission priming path, behaviour when recognition is unavailable, and that the transcript is `fence()`-guarded before reaching the prompt (`SEC-11`). Then make an explicit keep-or-cut decision — it carries a microphone permission, a speech dependency, and an `AnimationController`-heavy overlay for an unmeasured amount of use. If kept, its `feature_voice_assistant` kill-switch must migrate to `AppConfigService` (`ARCH-05`) rather than being deleted with `RemoteConfigService` | A microphone permission is one of the most trust-sensitive things an app requests. Carrying it for a feature nobody uses is a real cost at store review and in user perception. **Measure usage in M4 before deciding** |

---

## §11 — Nutrition & Meal Planning

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Modules | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `NUT-01` | 🔥 | Dish catalog: seedable server-side, ≥ 300 dishes | Critical | M | 1 w + content | v0.9.7 / M1 | Firebase Architect + PM | Database, Product, AI | see `BLK-11` | `AI-03` | Tracked in `BLK-11` | — |
| `NUT-02` | ✅ | Weekly AI meal plan with Firestore caching + profile-hash invalidation | — | — | — | shipped | — | — | `weekly_meal_plan_service.dart` | — | Verified working; generation path no longer fabricates when unconfigured (`BLK-01` closed) — real end-to-end generation still depends on `BE-01` | — |
| `NUT-03` | ✅ | Per-meal swap/substitution without regenerating the plan | — | — | — | shipped | — | — | `weekly_meal_plan_service.swapMeal()`, `_SwapSheet` in `home.dart` | — | Verified working | — |
| `NUT-04` | ✅ | Meal-plan comparison (2 AI-generated macro approaches) | — | — | — | shipped | — | — | `meal_plan_comparison_sheet.dart`, `generatePlanAlternatesPrompt` | — | Verified working; credit-gated with rollback | — |
| `NUT-05` | ✅ | Meal-plan history — add the missing rule | Critical | XS | 2 h | v0.9.7 / M1 | Firebase Architect | Firebase | see `BLK-06` | — | Rule deployed, tracked in `BLK-06` — closed | — |
| `NUT-06` | ✅ | Meal-plan calendar export (`.ics`) | — | — | — | shipped | — | — | `meal_plan_calendar_service.dart` | — | Verified working | — |
| `NUT-07` | ✅ | Calorie/macro targets (Mifflin-St Jeor) + onboarding projections | — | — | — | shipped | — | — | `calorie_calculator.dart`, `onboarding_projection_service.dart` + 2 test suites | — | Verified working; rates safe-clamped | — |
| `NUT-08` | ❌ | User-submitted dishes with moderation | Low | L | 1–2 w | v1.2.0 / Icebox | PM | Product, Database, Moderation | new | `MOD-01`, `BLK-11` | Users propose dishes with macros and a photo; admin/nutritionist approves before the dish enters the shared catalog; contributor credit; abuse-rate-limited | Wrong macros in a shared catalog is a health-data quality problem — approval must be real, not rubber-stamped |
| `NUT-09` | ❌ | Regional dish catalogs per locale | Low | M | 1 w | v1.2.0 / Icebox | PM | Product, Database, Localization | `dish_data.dart`, `BLK-11` | `I18N-03` | Catalog scoped by locale/region so a new market gets appropriate food; the current 75 dishes are Turkish-first, which is a genuine moat — extend rather than dilute | Ties to `I18N-03` locale expansion |
| `NUT-10` | ❌ | Nutritionist review of the dish catalog's macro accuracy | High | M | 1 w (external) | v1.0.0 / M4 | PM (external reviewer) | Product, Legal | `dish_data.dart` | `BLK-11` | A qualified nutritionist reviews every dish's macros, portion size and allergen tags; corrections applied; the review recorded with a date and reviewer name | This is a **health app**. Publishing wrong macros is a safety and liability issue, and no review has happened |
| `NUT-11` | ❌ | Household / per-person meal scaling | Low | L | 1–2 w | v1.2.0 / Icebox | PM | Product, AI, UX | `cooks_for_others` flag already collected in onboarding | `NUT-01` | If `cooksForOthers`, ask about spouse/child; for children use age bands (0–3 / 3–10) → portion multiplier, child-appropriate side suggestions, baby-food notes for 0–3; home exposes a portion multiplier module. **Carried verbatim from `ONBOARDING_V2.md` §7 shelved list — design TBD** | The flag is already collected, so users may expect the feature. Either build it or stop collecting the flag |
| `NUT-12` | ✅ | Nutrition analytics (trends, consistency score, weekly summary) | — | — | — | shipped | — | — | `nutrition_analytics_service.dart`, `nutrition_analytics_screen.dart` | — | Verified working | — |
| `NUT-13` | ✅ | Foods & Nutrition hub (Browse / Favourites / Insights) | — | — | — | shipped | — | — | `nutrition_hub_screen.dart` | `FB-17` | Verified working, **but** the Browse tab consumes the unbounded `getAllDishesStream()` — fix in `FB-17` | — |
| `NUT-14` | ✅ | Dietary-preference refinement (allergies, restrictions, avoid-list) | — | — | — | shipped | — | — | `dietary_preferences_screen.dart`, `UserNutritionProfile.avoidIngredients` | — | Verified working; threaded into both the recipe and meal-plan prompts | — |

---

## §12 — Recipes

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `RCP-01` | ✅ | AI single-recipe generation — add the `isConfigured` guard | Critical | XS | 2 h | v0.9.7 / M1 | AI Architect | `recipe_generation_service.dart` | `BLK-01` | Guard added; error state on unconfigured AI; no fabricated recipe | Closed with `BLK-01` — `generateRecipe` now guards `isConfigured` and rethrows `AIFatalException` |
| `RCP-02` | ✅ | Recipe detail screen + favourites + personal notes + share | — | — | — | shipped | — | `recipe_detail_screen.dart`, `favorite_service.dart`, `recipe_note_service.dart` | — | Verified working | — |
| `RCP-03` | ✅ | Cooking mode — step PageView, wakelock, progress ring, finish→log + community share | — | — | — | shipped | — | `cooking_mode_screen.dart` | — | Verified working | — |
| `RCP-04` | ❌ | Step-aware cooking timers | Low | S | 1 d | v1.1.0 / M6 | Flutter Engineer | `cooking_mode_screen.dart` | — | Per-step durations parsed from the recipe drive a step-scoped timer with a notification when it elapses; today the timer is a generic stopwatch (carried from the original partial-features table) | Requires timing data in the recipe model or AI output |
| `RCP-05` | ✅ | Recipe filters in Explore (cook time, difficulty) wired to the prompt | — | — | — | shipped | — | `explore_screen.dart`, `PromptService` `maxTotalMinutes`/`difficulty` | — | Verified working | — |
| `RCP-06` | ❌ | Recipe image quality pass | Medium | M | 3 d + content | v1.0.0 / M4 | PM | `dish_image_service.dart` (deterministic LoremFlickr/Unsplash seeds by dish ID) | `BLK-11` | Every catalog dish has a correct, licensed image; the placeholder-image service is replaced with owned or properly-licensed assets served from Storage with a CDN | Stock-photo seeding by keyword produces plausible-but-wrong images; also a licensing exposure for a commercial app |

---

## §13 — Food Logging

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `LOG-01` | ✅ | Food diary + real-time consumed calorie/macro stream on home | — | — | — | shipped | — | `food_log_service.dart`, `food_log_model.dart`, `home.dart` | — | Verified working | — |
| `LOG-02` | ✅ | Recent & frequent foods + quick-add sheet | — | — | — | shipped | — | `recent_food_service.dart`, `quick_add_sheet.dart` | — | Verified working; capped at 20 | — |
| `LOG-03` | 🚧 | Barcode scanning — external API reliability | Medium | S | 2 d | v1.0.0 / M4 | Flutter Engineer | `barcode_lookup_service.dart` (Open Food Facts), `barcode_scan_screen.dart` | — | Timeout, retry and offline handling for the Open Food Facts API; a "not found" path that routes to manual entry; response cached; **the existing permission/camera-unavailable/manual-entry states are genuinely good work — keep them** | Third-party API with no SLA; Turkish product coverage is likely thin — measure hit rate |
| `LOG-04` | 🚧 | Food photo analysis — verify on iOS | High | S | 1 d | v0.9.7 / M1 | AI Architect | `food_scan_screen.dart`, `food_analysis_service.dart` | `AI-22` | Camera and gallery paths verified on a physical iPhone; credit metering and rollback verified; history written to `users/{uid}/food_analyses` | No longer blocked by a crash (`BLK-02` fixed) — just needs a physical device |
| `LOG-05` | ✅ | Express one-tap photo logging with auto meal-type | — | — | — | shipped | — | `FoodScanScreen(expressPhoto:)`, `meal_time_util.dart` | `BLK-02` | Verified working on Android | — |
| `LOG-06` | ✅ | Mark-meal-as-eaten from cooking mode → diary | — | — | — | shipped | — | `cooking_mode_screen.dart`, `food_log_service.logRecipe` | — | Verified working | — |
| `LOG-07` | ✅ | Meal-type nutrition breakdown card | — | — | — | shipped | — | `meal_breakdown_card.dart` | — | Verified working | — |
| `LOG-08` | ❌ | Edit and delete a logged entry | High | S | 1 d | v1.0.0 / M4 | Flutter Engineer | `food_log_service.dart`, `home.dart` | — | A logged meal can be edited (portion, meal type, macros) and deleted; the day's totals and streak recompute correctly; the `recent_foods` upsert is not corrupted by an edit | **A tracking app where a mistyped entry cannot be corrected is a daily-use blocker.** Verify whether an edit path exists — none was found in the audit |
| `LOG-09` | ❌ | Backdated logging (log yesterday's meal) | Medium | S | 1–2 d | v1.0.0 / M4 | Flutter Engineer | `food_log_service.dart`, `home.dart` day selector | `SEC-14` | A user can log to a past date within a bounded window; streak semantics defined explicitly (does backdating restore a broken streak? — decide and document); server-side streak logic honours the decision | Backdating interacts with streak integrity — decide before `SEC-14` locks streaks server-side |
| `LOG-10` | ❌ | Water and exercise entry edit/delete parity | Medium | S | 1 d | v1.0.0 / M4 | Flutter Engineer | `tracking_card.dart`, `exercise_log_service.dart` | `LOG-08` | Same edit/delete affordances as food entries | Inconsistent affordances across trackers is a UX smell |

---

## §14 — Weight, Hydration & Exercise Tracking

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `TRK-01` | ✅ | Weight logging + history + 7-day chart + shared log sheet | — | — | — | shipped | — | `tracking_card.dart`, `weight_log_sheet.dart` | — | Verified working | — |
| `TRK-02` | ✅ | Hydration tracking + water reminders (timezone-correct, multi-time, wake→sleep spread) | — | — | — | shipped | — | `tracking_card.dart`, `push_notification_service.scheduleDailyWaterReminder` + tests | — | Verified working | — |
| `TRK-03` | 🚧 | Exercise logging + MET-based burn feeding TDEE | Medium | S | 2 d | v1.0.0 / M4 | Flutter Engineer | `exercise_log_service.dart` (1,981 B — thin), `exercise_log_sheet.dart` | `LOG-10` | 12 exercise types with MET estimates verified against a reference table; burn feeds the day's target correctly; edit/delete; history view; the service is currently the thinnest in the tracking set | MET-based estimates are approximations — label them as such in the UI to avoid implying precision |
| `TRK-04` | ❌ | Weight-trend analytics beyond 7 days | Medium | S | 2 d | v1.0.0 / M4 | Flutter Engineer | `tracking_card.dart`, `nutrition_analytics_screen.dart` | — | 30/90/all-time weight trend with a moving average; goal-progress projection reconciled with the Fitness Twin's projection so the two do not contradict each other | Two different projections shown to one user is a trust problem |
| `TRK-05` | ❌ | Body measurements (waist, hips, body fat %) | Low | M | 3 d | v1.2.0 / Icebox | PM | new | `BLK-10` | Optional measurements with trend charts; stored as **health PII in `private/nutrition`**, never the public doc | More health PII means more compliance surface — gate behind explicit consent |
| `TRK-06` | ❌ | Health-platform integration (Apple Health / Google Fit) | Low | L | 2 w | v1.2.0 / Icebox | Flutter Engineer | new | `LEG-04` | Read weight and activity, optionally write nutrition; explicit consent per data type; works when denied | Both platforms have strict review requirements for health data; adds significant privacy-policy surface |

---

## §15 — Dashboard & Home

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `HOME-01` | ✅ | Nutrition hero — `AppCalorieRing`, animated macro bars, burned-today chip, mesh-glow | — | — | — | shipped | — | `home.dart`, `app_calorie_ring.dart` | — | Verified working | — |
| `HOME-02` | ✅ | Day selector, meal cards with macro chips, swap sheet, logged state | — | — | — | shipped | — | `home.dart` `_MealCard` | — | Verified working | — |
| `HOME-03` | ✅ | Meal-plan action row (compare / history / calendar / regenerate / analytics) | — | — | — | shipped | — | `home.dart` `_MealIconBtn` | `BLK-06` | Verified working — but History always lands on an empty screen until `BLK-06` | — |
| `HOME-04` | ✅ | `TodaySummaryCard`, `TrackingCard`, `AiInsightCard`, `WeeklyRecapCard`, `RoleQuickCard`, `MealBreakdownCard`, streak + goal-met banners, coachmark | — | — | — | shipped | — | `home/widgets/` | — | Verified working | — |
| `HOME-05` | ❌ | Daily "Bugün" recap card | Medium | S | 1–2 d | v1.0.0 / M4 | Flutter Engineer | `home/widgets/bugun_recap_card.dart` (452 LOC exists) | — | **Verify status.** The prior roadmap lists 15.2 as unchecked (`- [ ]`) while a 452-LOC file exists. Confirm whether it is wired into `home.dart`, computes locally from one `getLogsForDateRange` call, has a SharedPrefs SWR cache, and renders skeleton/empty/success. If wired, mark ✅; if not, finish the wiring | A roadmap/code disagreement — resolve by reading the code, not the roadmap |
| `HOME-06` | ❌ | Reduce home-screen rebuild scope | Medium | M | 2–3 d | v1.1.0 / M6 | Performance Engineer | `home.dart` (1,957 LOC, 19 `setState`) | `ARCH-02`, `FB-23` | `Selector` / `ValueListenableBuilder` replace broad `watch`; each `setState` rebuilds only its subtree; frame timings measured before and after | Cannot claim improvement without `FB-23` measurement first |

---

## §16 — Onboarding

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `ONB-01` | ✅ | Onboarding V2 — pre-registration inverted flow: intro carousel → 14 pages → register → plan generation | — | — | — | shipped | — | `screens/onboarding/v2/` (16 files), `onboarding_flow_screen.dart`, `onboarding_scaffold.dart` | — | Verified working. The most polished user-facing work in the product | — |
| `ONB-02` | ✅ | Logged-in completion mode (legacy incomplete accounts finish in the same V2 flow against the existing uid) | — | — | — | shipped | — | `OnboardingFlowScreen(loggedInCompletion:)`, `onboarding_completion.dart`, `onboarding_flow_resolver.dart` | — | Verified working | — |
| `ONB-03` | ✅ | Meal-plan generation finale (staged copy, two-phase progress, error state, skip) | — | — | — | shipped | — | `meal_plan_generation_screen.dart` | — | Verified working — no longer generates a fake plan in release (`BLK-01` closed); its existing `try/catch` → `_hasError` → `AppErrorState` handling needed no change | — |
| `ONB-04` | 🚧 | Harden `OnboardingCompletion` against a partial write | High | S | 2 d | v0.9.7 / M1 | Flutter Engineer | `screens/onboarding/v2/onboarding_completion.dart` (114 LOC, best-effort persistence) | `ARCH-01` | Every write in `finalizeAndRoute` reports failures to Crashlytics; a failure surfaces a retry rather than routing forward with partial data; the resolver's recovery path is verified by deliberately failing each write | "Best-effort so a write hiccup never strands the account" is the right instinct, but silent partial success means a user reaches home with an incomplete profile and no signal |
| `ONB-05` | ❌ | Onboarding drop-off analytics per page | High | S | 1 d | v1.0.0 / M4 | Product | `onboarding_flow_screen.dart`, `analytics_service.dart` | `FB-24` | A page-view event per onboarding step; a funnel in BigQuery shows exactly where users abandon; the 14-page flow's completion rate is a tracked north-star metric | A 14-page flow before registration is a bold bet — it must be measured, and today it is not |
| `ONB-06` | ❌ | Re-verify the intro/onboarding gate chain end to end | High | S | 1 d | v0.9.7 / M1 | QA Lead | `splash_screen.dart`, `route_guard.dart`, `onboarding_flow_resolver.dart` | — | A test matrix over {new install, unverified email, partial onboarding, complete-no-plan, complete-with-plan, banned, maintenance, force-update} × {email auth, Google, Apple} verified on device. **The intro tour was reported broken three separate times across Phases 13 and 14 with three different root causes** — this matrix is how it stops recurring | Six sequential gates in `RouteGuard` interact in ways single-case testing misses |
| `ONB-07` | ❌ | Replace the raw spinners in `RouteGuard` | Medium | XS | 2 h | v0.9.8 / M2 | UX Engineer | `lib/core/utils/route_guard.dart` (5 raw `CircularProgressIndicator`) | `UI-02` | Branded `AppShimmer` / skeleton transitions. **The routing core violates the project's own R7 rule five times, on the path every navigation passes through** | Highest-visibility instance of `UI-02` |
| `ONB-08` | ❌ | App-icon recolouring as a real premium feature | Low | M | 1 w | v1.2.0 / Icebox | Flutter Engineer | onboarding premium page (locked preview today) | `BLK-04` | Alternate app icons on iOS (arbitrary tint is not possible), themed launcher on Android; evaluate `flutter_dynamic_icon`. **Carried verbatim from `ONBOARDING_V2.md` §7** | Onboarding currently shows a locked preview of a feature that does not exist — either build it or remove the preview |
| `ONB-09` | 🟡 | Remove the orphaned `priority_onboarding_screen` (387 LOC dead code still wired into `RouteGuard`) | Medium | XS | 2 h | v0.9.8 / M2 | Flutter Engineer | `lib/screens/onboarding/priority_onboarding_screen.dart` (387 LOC), `lib/core/utils/app_routes.dart:9` (`priorityOnboarding`), `lib/core/services/route_configuration_service.dart:50` (route registered), `lib/core/utils/route_guard.dart:301` (**counted as an auth route in `_isAuthRoute`**) | `ONB-06` | **Nothing in `lib/` navigates to this route** — verified by grep. It was the Phase 2 replacement for the old stub, then superseded when Onboarding V2 inverted the flow. It remains registered *and* is treated as an auth route, so it silently participates in the six-stage `RouteGuard` gate chain that `ONB-06` must test. Delete the screen, the route constant, the route registration and the `_isAuthRoute` entry — **or** document why it is retained. Re-run `ONB-06`'s gate matrix afterwards | Dead code inside the routing gate chain is exactly the kind of thing that produced three separate "intro tour never shows" regressions across Phases 13 and 14. Removing it simplifies the surface `ONB-06` has to verify |

---

## §17 — Profile

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `PRF-01` | ✅ | Profile view, avatar upload, real post count, streak tier, reputation badge, achievements grid, completeness card, follow button | — | — | — | shipped | — | `profile_screen.dart` (2,432 LOC), `achievements_grid.dart`, `profile_completeness_card.dart` | — | Verified working | — |
| `PRF-02` | ✅ | Private-account enforcement (lock card for non-friends; owner and friends see full) | — | — | — | shipped | — | `profile_screen.dart` `_privacyResolved` gate | `BLK-10` | Verified working — UI-gated over a readable user doc; `BLK-10` makes it real | — |
| `PRF-03` | ✅ | Universal tap-to-profile (`openUserProfile` / `ProfileLink`) | — | — | — | shipped | — | `lib/core/utils/profile_navigation.dart` | — | Verified working | — |
| `PRF-04` | ✅ | Avatar integrity — `AppInitialsAvatar`, no random `pravatar.cc` faces, real photo everywhere | — | — | — | shipped | — | `app_avatar.dart`, `community_service.dart` | — | Verified working | — |
| `PRF-05` | ❌ | Backfill stale denormalized author avatars in old posts | Low | S | 1 d | v1.1.0 / M6 | Backend | `community_service.dart` | `ARCH-06` | A Function backfills `authorPhotoUrl` on historical posts when a user changes their photo, or the client resolves the author's avatar live from the user doc. **Carried from the Phase 14.9 deferred note** | Live resolution is an extra read per post; backfill is a write storm. Choose deliberately |
| `PRF-06` | ❌ | Split `profile_screen.dart` (2,432 LOC, 27 `_build*`, 25 `setState`) | Medium | M | 3–4 d | v1.1.0 / M6 | Principal Engineer | `profile_screen.dart` | `ARCH-02`, `TEST-03` | Tracked under `ARCH-02` | — |

---

## §18 — Settings

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `SET-01` | ✅ | Theme (dark/light + primary colour picker), language picker, change email/password, notification prefs, water + meal reminders, dietary prefs, AI & Credits, referral card, earnings, legal links, data export, delete account, developer test mode, How It Works replay | — | — | — | shipped | — | `settings_screen.dart` (2,506 LOC) | — | Verified working | — |
| `SET-02` | ❌ | Consent Center parity check | High | S | 1 d | v0.9.8 / M2 | Legal | `consent_center_screen.dart`, `consent_service.dart` | `LEG-03` | Every purpose in `ConsentPurpose` is visible, withdrawable, and shows its granted timestamp and policy version; withdrawing analytics consent immediately disables collection (verified); a withdrawn essential purpose explains the consequence | The consent system is genuinely good — verify the UI exposes all of it |
| `SET-03` | ❌ | Split `settings_screen.dart` (2,506 LOC) | Medium | M | 2–3 d | v1.1.0 / M6 | Principal Engineer | `settings_screen.dart` | `ARCH-02` | Tracked under `ARCH-02` | — |
| `SET-04` | ❌ | Test mode must be unreachable in release | High | XS | 2 h | v0.9.7 / M1 | DevSecOps | `test_mode_service.dart`, `settings_screen.dart` Developer section, `test_data_library.dart` (1,073 LOC) | — | The Developer section and `TestModeService` are compiled out or hard-gated on `kDebugMode` in release; `TestDataLibrary` is tree-shaken or moved to `test/`. Today test mode is a SharedPrefs boolean with no build-mode guard, and it intercepts meal plans, food logs, shopping, dishes, gyms, coaches and admin users | A user (or a reviewer) who flips test mode sees fabricated data — a second fake-data path alongside `BLK-01` |

---

## §19 — Notifications & Push

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `NOTIF-01` | 🔥 | Fix the push fan-out path mismatch | Critical | M | 2–3 d | v0.9.7 / M1 | Firebase Architect | see `BLK-03` | — | Tracked in `BLK-03` | — |
| `NOTIF-02` | ❌ | Server-author notifications (closes forgery) | Critical | M | 3–4 d | v0.9.7 / M1 | Security | see `SEC-06` | `BLK-03` | Tracked in `SEC-06` | — |
| `NOTIF-03` | ✅ | Structured notification storage + `NotificationPresenter` (renders in the reader's locale with the real actor name) | — | — | — | shipped | — | `notification_service.dart`, `notification_presenter.dart` | — | Verified working. **This is the right architecture — never store display text** | — |
| `NOTIF-04` | ✅ | Per-group mute preferences (likes/comments/friends/system/referral/reminders) respected client and server | — | — | — | shipped | — | `notification_preferences_service.dart`, `functions/index.js` `TYPE_TO_MUTE_GROUP` | — | Verified working | — |
| `NOTIF-05` | ✅ | Local scheduled reminders — water (block 7001–7012) and meals (block 8001–8008) with reserved ID blocks | — | — | — | shipped | — | `push_notification_service.dart` | — | Verified working. **These use `flutter_local_notifications` directly, not FCM — which is why they work while social push does not** | — |
| `NOTIF-06` | 🚧 | Cron re-engagement producers — remove the 500-user cap | High | M | 3 d | v1.0.0 / M4 | Backend | `functions/index.js` `streakAtRiskNotifier` (daily 17:00 UTC), `weeklyPlanReadyNotifier` (Mon 07:00 UTC) | `INF-06`, `BLK-03` | Tracked in `INF-06`. **Breaks at 500 active users and reports nothing** | — |
| `NOTIF-07` | ✅ | Notification screen with cursor pagination, pull-to-refresh, optimistic mark-all-read, actor avatars, tap-to-profile | — | — | — | shipped | — | `notification_screen.dart` (871 LOC) | — | Verified working | — |
| `NOTIF-08` | ✅ | Tap-routing (foreground/background/cold-start via `getInitialMessage` + drain) | — | — | — | shipped | — | `push_notification_service.dart` `_navigateFromData`, `drainPendingNavigation` | `BLK-03` | Code verified; **behaviour untestable until `BLK-03`** | — |
| `NOTIF-09` | ❌ | Deep tap-routing to the specific entity | Medium | S | 1–2 d | v1.0.0 / M4 | Flutter Engineer | `push_notification_service.dart` (`chat` → `/chat_list`, everything else → `/main`) | `BLK-03` | A like notification opens the post; a friend request opens the requester's profile; a referral opens the referral card; unknown types fall back to `/main` | Routing to a generic screen wastes the notification's intent — a measurable retention loss |
| `NOTIF-10` | ❌ | iOS APNs key uploaded to Firebase | Critical | XS | 1 h + console | v0.9.9 / M3 | DevOps | Firebase console | `BLK-16` | APNs auth key uploaded; a push verified on a physical iPhone. **Push on iOS cannot work without this, so `BLK-03` cannot be verified on iOS** | On the critical path for `BLK-03` verification |
| `NOTIF-11` | ❌ | Notification grouping / collapsing | Low | S | 2 d | v1.1.0 / M6 | Flutter Engineer | `notification_screen.dart`, `functions/index.js` | `BLK-03` | "5 people liked your post" instead of 5 rows; FCM collapse keys used; in-app grouped by post + type | Ungrouped notification spam is a mute/uninstall driver once the feed is active |
| `NOTIF-12` | ❌ | Rich push with images | Low | S | 2 d | v1.2.0 / Icebox | Flutter Engineer | `functions/index.js`, iOS notification service extension | `BLK-03` | Post thumbnail in the push; iOS requires a notification service extension target | Extra native target to maintain |
| `NOTIF-13` | ✅ | Admin broadcast composer + scheduling + audience resolution + 5-min drain cron | — | — | — | shipped | — | `admin_panel_screen.dart` Broadcasts, `AdminService.sendBroadcast`, `onBroadcastCreated`, `drainScheduledBroadcasts` | `BLK-05`, `INF-06` | Code verified; **unusable until `BLK-05`**; audience capped at 500 (`INF-06`) | — |

---

## §20 — Community

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `COM-01` | 🔥 | Close the post-field mutation hole | Critical | S | 1 d | v0.9.7 / M1 | Security | see `BLK-08` | — | Tracked in `BLK-08` | — |
| `COM-02` | ✅ | Feed CRUD, cursor pagination, auto-load-on-scroll with skeleton footer, filters (Global / Following / Saved), topic chips | — | — | — | shipped | — | `community_service.dart` (37.6 KB), `community_screen.dart`, `community_topics.dart` | — | Verified working | — |
| `COM-03` | ✅ | Structured post types (`text`/`recipe`/`progress`/`meal`) with type-specific rich cards and per-type composer fields | — | — | — | shipped | — | `community_post.dart`, `glass_post_card.dart` (1,356 LOC), `create_post_card.dart` (1,320 LOC) | — | Verified working | — |
| `COM-04` | ✅ | Comments (real-time stream + cursor pagination), reactions, draggable reaction button, save/bookmark, mentions with autocomplete + fan-out, "I Cooked This" badge, weekly highlights | — | — | — | shipped | — | `post_detail_screen.dart` (1,708 LOC), `weekly_highlights_card.dart` | — | Verified working | — |
| `COM-05` | 🚧 | Post-delete cascade → move to a Cloud Function | Medium | M | 2 d | v1.1.0 / M6 | Backend | `community_service.dart:381-391` (N+1: one `.get()` per comment plus one per comment's likes) | `ARCH-09` | A Firestore trigger recursively deletes `likes`, `reactions`, `comments` and each comment's `likes` on post delete; the client fires one delete; deeply nested future subcollections handled. The prior roadmap already noted "deeply nested future subcollections still need a Cloud Function trigger" | An N+1 delete loop on a popular post is slow, expensive and can partially fail mid-way, leaving orphans |
| `COM-06` | 🚧 | Block enforcement server-side | High | M | 2–3 d | v0.9.8 / M2 | Security | `community_service.dart` (`getPostsStream` filters blocked authors client-side via `async*`/`yield*`), `users/{uid}/block_list` | `SEC-06` | Blocked users cannot read or write to the blocker's content at the rules level, not merely filtered in the client stream (`S13`); blocking is bidirectional where the product requires it; a rules test covers it | Client-side block filtering means a blocked user can still see everything via a patched client, and can still comment |
| `COM-07` | ✅ | Follow system (`following`/`followers` batch write, streams, counts, notification fan-out, Following feed) | — | — | — | shipped | — | `follow_service.dart`, `profile_screen.dart` | — | Verified working | — |
| `COM-08` | ❌ | Feed ranking beyond reverse-chronological | Low | L | 1–2 w | v1.2.0 / Icebox | PM | `community_service.dart` | `FB-24` | A relevance signal (follows, topic affinity, engagement) blended with recency; measured against D7 return, not vanity engagement | Ranking without data is guessing; requires `FB-24` first |
| `COM-09` | ❌ | Feed partitioning / fan-out model for scale | Low | XL | 3–4 w | v1.2.0 / M7 | Architect | `posts` collection, `firestore.indexes.json` | `FB-24` | Sharded or per-user fan-out feed; the single global `posts` + `timestamp` index becomes a hot-index write bottleneck at ~100k users | Premature at current scale; the ceiling is real and mapped |
| `COM-10` | ✅ | Content keyword filter reading public-read `settings/content_filter` (earlier fail-open bug fixed) | — | — | — | shipped | — | `community_service._checkContent`, `AdminService.updateAdminConfig` mirror | — | Verified working | — |
| `COM-11` | ❌ | UGC rate limits | High | M | 3–4 d | v0.9.8 / M2 | Security | see `SEC-12` | — | Tracked in `SEC-12` | — |

---

## §21 — Community Groups

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `GRP-01` | ✅ | Groups P1 MVP — location-based discovery by city/district, join, group-scoped feed, KVKK-clean location handling | — | — | — | shipped | — | `community_group_service.dart`, `groups_discovery_screen.dart`, `group_detail_screen.dart`, `create_group_screen.dart` (9 composite indexes) | — | Verified working | — |
| `GRP-02` | ❌ | Reconcile `member_count` server-side | Medium | S | 1 d | v1.1.0 / M6 | Backend | see `BE-10` | `BLK-08` | Tracked in `BE-10` | — |
| `GRP-03` | 📋 | **P2** Weekly local group leaderboard | Medium | M | 3 d | v1.1.0 / M6 | PM | new; reuse the `gym_leaderboard_service` pattern | `SEC-14` | Per-group ranking by check-ins / logged days / posts; drives competitive return visits. Exit criterion from `COMMUNITY_GROUPS.md` §5: the median active group has a live leaderboard | Meaningless until streak/log counts are server-authoritative (`SEC-14`) |
| `GRP-04` | 📋 | **P2** Group challenges (time-boxed, opt-in, progress bar, finisher badges) | Medium | M | 4 d | v1.1.0 / M6 | PM | new | `CHL-01`, `GRP-03` | Owner/mods launch a challenge; members opt in; progress and finisher badges. Exit criterion: ≥ 1 challenge/month in the median active group. **Depends on Challenges 2.0 (`CHL-01`) since the original challenge system was sunset** | The `COMMUNITY_GROUPS.md` text says "hook into the existing challenge system" — that system no longer exists |
| `GRP-05` | 📋 | **P2** Events / meetups with RSVP | Medium | M | 4 d | v1.1.0 / M6 | PM | new | `GRP-01` | A group posts an event (date, place, RSVP); local groups → real-world meetups. `COMMUNITY_GROUPS.md` calls this "the strongest retention signal there is" | Real-world meetups introduce safety and liability considerations — needs a code of conduct and a reporting path |
| `GRP-06` | 📋 | **P2** Group activity push (opt-in "new post in {group}") | Medium | S | 2 d | v1.1.0 / M6 | Backend | `notification_preferences_service.dart` per-group mute | `BLK-03` | Opt-in per-group notifications; measurable D7 lift is the exit criterion | Group push is a fast route to notification fatigue — opt-in only, never default |
| `GRP-07` | 📋 | **P2** "New in your city" group suggestions on home and community top | Low | S | 2 d | v1.1.0 / M6 | PM | `home.dart`, `community_screen.dart` | `GRP-01` | Newly-created or fast-growing local groups surfaced | Cold-start: needs group density before it looks alive |
| `GRP-08` | 📋 | **P2** Group cover images | Low | S | 1 d | v1.1.0 / M6 | Flutter Engineer | `storage_upload_service.dart`, `storage.rules` | `BLK-07`, `SEC-13` | Cover upload with owner-scoped Storage rules and NSFW scanning; "visual identity lifts join rates" | Another Storage prefix — **do not repeat `BLK-07`**; add the rule and the scan prefix in the same change |
| `GRP-09` | 📋 | **P2** Role mirroring (a coach's/gym's group auto-suggested to their clients/members) | Low | S | 2 d | v1.1.0 / M6 | PM | `coach_service.dart`, `gym_service.dart` | `GRP-01` | Suggested on the client/member home | Deferred with the gym/coach scope cut |
| `GRP-10` | 📋 | **P3** Moderators (owner promotes members; can remove posts/members) | Medium | M | 3 d | v1.2.0 / M7 | PM | `community_groups/{id}/members.role` (field already exists) | `MOD-01`, `SEC-05` | Owner promotes to `moderator`; scoped removal powers; every action audit-logged | Group moderators are untrusted third parties — scope their powers tightly |
| `GRP-11` | 📋 | **P3** Group post reports into the shared moderation queue | Medium | S | 2 d | v1.2.0 / M7 | Moderation | `reports/{id}`, `admin_reports_screen.dart` | `BLK-05`, `MOD-01` | Group posts reportable; they appear in the admin queue with group context | — |
| `GRP-12` | 📋 | **P3** Invite links / codes for private groups | Low | M | 3 d | v1.2.0 / M7 | PM | `referrals`-style codes, `deep_link_service.dart` | `INF-07` | Code generation, deep-link join, expiry and revocation | Needs `INF-07` hosted deep-link files |
| `GRP-13` | 📋 | **P3** Private / invite-only groups with request-approve join | Low | M | 3 d | v1.2.0 / M7 | PM | `is_public=false` already hides from discovery | `GRP-12` | A join-request queue the owner approves | — |
| `GRP-14` | 📋 | **P3** Suggested groups from city + goal + followed coaches | Low | M | 3 d | v1.2.0 / M7 | PM | new | `GRP-01` | Lightweight recommendations | — |
| `GRP-15` | 📋 | **P3** Group anti-abuse (rate-limit creation, spam detection on group posts) | High | S | 1 d | v0.9.8 / M2 | Security | see `SEC-12` | — | Tracked in `SEC-12` — **pulled forward from P3 because it is a live abuse vector today** | — |

---

## §22 — Friends & Social Graph

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `SOC-01` | 🔥 | Server-author friends and friend requests | Critical | M | 3–4 d | v0.9.7 / M1 | Security | see `SEC-06` | — | Tracked in `SEC-06` | — |
| `SOC-02` | ✅ | Friends — search, request, accept/reject, list; chunked `whereIn` (1 read per 30 friends) | — | — | — | shipped | — | `friend_service.dart` | — | Verified working | — |
| `SOC-03` | ✅ | Global user search with debounce + friendship-status badges | — | — | — | shipped | — | `user_search_screen.dart`, `main_header.dart` | `PERF-08` | Verified working — prefix range queries only; real search needs `PERF-08` | — |
| `SOC-04` | ✅ | Streak Squads (invite codes, leaderboard, member streaks, chunked `whereIn`, collision-retry codes) | — | — | — | shipped | — | `streak_squad_service.dart`, `streak_squad_screen.dart` (1,142 LOC) | `SEC-14` | Verified working — the leaderboard is gameable until `SEC-14` | — |
| `SOC-05` | ✅ | Signals (ephemeral social broadcast) | — | — | — | shipped | — | `signal_service.dart` (2,807 B — thin), `signal_dialog.dart` | — | Verified working | — |
| `SOC-06` | ❌ | Contacts-based friend discovery | Low | M | 3 d | v1.2.0 / Icebox | PM | new | `LEG-04` | Phone-contacts picker with explicit consent and no server-side contact storage. **Carried from Phase 8: "deferred, requires `contacts_service` + a privacy consent flow"** | Uploading a contact book is one of the highest-risk privacy features there is — hash locally, never store |

---

## §23 — Messaging

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `CHAT-01` | ✅ | 1:1 real-time chat (read receipts, typing, presence) + group chat + image messages + push (**the one working push path**) | — | — | — | shipped | — | `chat_service.dart`, `chat_detail_screen.dart` (987 LOC), `chat_list_screen.dart` (1,397 LOC), `onChatMessageCreated` | — | Verified working | — |
| `CHAT-02` | ✅ | Chat header options (view profile, report user), speed-dial label contrast fixed | — | — | — | shipped | — | `chat_detail_screen.dart` `_showMoreOptions()` | — | Verified working | — |
| `CHAT-03` | 🚧 | Scope group chat images to participants | High | M | 2–3 d | v0.9.8 / M2 | Security | see `SEC-13`; `storage.rules` (group chat images readable by any authenticated user) | `SEC-13` | Tracked in `SEC-13`. The rule comment concedes the current model relies on an unguessable filename — **security by obscurity, written down as such** | Chat images are the most private content in the app |
| `CHAT-04` | ❌ | Chat pagination for long histories | Medium | S | 1–2 d | v1.0.0 / M4 | Flutter Engineer | `chat_detail_screen.dart` | `FB-17` | Messages load in pages with reverse-infinite scroll and a `.limit()`; a 5,000-message thread does not load entirely | Verify the current query's bound; an unbounded message listener is a cost and memory problem |
| `CHAT-05` | ❌ | Chat message delete / unsend | Medium | S | 2 d | v1.0.0 / M4 | Flutter Engineer | `chat_service.dart` | — | Delete-for-me and delete-for-everyone within a time window; the Storage image deleted with the message; erasure (`BLK-12`) accounts for it | Deleting one side of a conversation has product and legal nuance — document the choice |
| `CHAT-06` | ❌ | Block enforcement in chat | High | S | 1 d | v0.9.8 / M2 | Security | `chat_service.dart`, `users/{uid}/block_list` | `COM-06` | A blocked user cannot open or send to the blocker's chat, enforced in rules | Blocking that does not stop DMs is not blocking |
| `CHAT-07` | ❌ | Chat moderation and reporting flow into the queue | Medium | S | 2 d | v1.0.0 / M4 | Moderation | `chat_detail_screen.dart` (report writes `reports/{id}` with `targetType: 'user'`), `admin_reports_screen.dart` | `BLK-05`, `MOD-01` | A reported chat is reviewable with enough context to act, without exposing the whole thread to admins beyond what is necessary; retention and access documented in `docs/COMPLIANCE.md` | Admin access to private messages is a serious privacy decision — define the minimum viable disclosure |

---

## §24 — Challenges

> **History that must not be lost:** Challenges were **built** in Phase 3 (model, service, 3 screens,
> sponsored variant, difficulty tiers, deep links, sharing, indexes, rules, i18n) and then **deliberately
> sunset** in Phase 13.2 as a clean removal. `CLAUDE.md`'s MVP-status line still claims challenges are
> shipped — that line is **stale and must be corrected** (`DOC-02`). The removal was also **incomplete**
> (`DEBT-11`).

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `CHL-00` | 🚧 | Finish the Phase 13.2 sunset | Medium | XS | 1 h | v0.9.8 / M2 | Firebase Architect | `firestore.rules:296-304`, `firestore.indexes.json` (2 `challenges` indexes), 4 orphan i18n keys (`notification_prefs.challenges`, `gym.feature_challenges`, `gym.feature_challenges_sub`, plus TR counterparts) | — | Rules block and both indexes removed; orphan keys removed **or** repurposed (`ai.weekly_recap_challenges` and `gym.war_*` are legitimate uses of the word — keep those); parity test green. **The prior roadmap marked this ✅ — it was not done.** See `DEBT-11` | Leaving reserved infrastructure for a removed feature is how a roadmap starts lying about what exists |
| `CHL-01` | 📋 | Challenges 2.0 — purpose-built re-introduction | Low | L | 2–3 w | v1.2.0 / M7 | PM | new; build on the Streak Squad infrastructure | `GAM-01`, `SEC-14`, `CHL-00` | Templated challenges (7-day reset, 30-day fat loss) with join/progress/leaderboard, optional sponsor, completion rewards (badges/bonus credits); a lean `challenges/` schema (template, metric, dates, sponsor, participants subcollection). **Carried from `FUTURE_FEATURES` D2.** Progress must be server-computed (`SEC-14`) — the original version was client-written and gameable | Re-introducing a sunset feature needs a clear reason it will work this time. The honest reason: Streak Squads proved the social hook; challenges add structure. Validate with data before building |
| `CHL-02` | 📋 | Sponsored challenges + sponsorship marketplace | Low | M | 1–2 w | v2.0.0 / Icebox | PM | previously built then removed (`SponsorBadge`, `createSponsoredChallenge`) | `CHL-01`, `REF-04` | Brands sponsor a challenge with a reward and a landing link; revenue share. **Carried from Phase 7 (built, then removed with the sunset) and `FUTURE_FEATURES` E2** | Requires real brand partnerships and ad-disclosure compliance |

---

## §25 — Gamification

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `GAM-01` | 📋 | XP / levels layer (Rookie → Legend) | Low | M | 1–2 w | v1.2.0 / M7 | PM | new; `users/{uid}.xp`, `.level`, `users/{uid}/badges/{id}` | `SEC-14`, `BLK-08` | XP granted **server-side** by a Function on qualifying events (log, post, streak milestone, achievement); level thresholds; a badge cabinet and profile level chip. **Carried from `FUTURE_FEATURES` D3 and the README's Rookie→Legend description, which today has no implementation** | **Grant server-side or it is cheated on day one** — the exact mistake made with streak and reputation |
| `GAM-02` | ✅ | Achievements — 11-badge catalogue, idempotent `earn`, `checkAndGrant` from every success path, `backfillForUser`, live stream, profile grid with bounce unlock | — | — | — | shipped | — | `achievement_service.dart`, `achievement_model.dart` (`kAchievementCatalog`), `achievements_grid.dart` | `SEC-14` | Verified working — but badges derived from streak are only as trustworthy as the streak (`SEC-14`) | — |
| `GAM-03` | ✅ | Streaks with milestone notifications, tier badges (Bronze/Silver/Gold/Diamond), streak-freeze count + auto-consume + welcome gift + snowflake chip | — | — | — | shipped | — | `firestore_service.dart`, `home.dart` welcome header | `SEC-14` | Verified working; **client-computed** — see `SEC-14` | — |
| `GAM-04` | ✅ | Reputation system (`streak×2 + posts×5`, 5 tiers, cached to the user doc) | — | — | — | shipped | — | `reputation_service.dart` | `SEC-14` | Verified working; **client-computed** — see `SEC-14`. Note the formula still references challenges (`×10`), which no longer exist — verify and correct | — |
| `GAM-05` | ✅ | Leaderboards (global + friends streak) | — | — | — | shipped | — | `leaderboard_service.dart`, `leaderboard_screen.dart` | `SEC-14`, `PERF-09` | Verified working — **trivially gameable** until `SEC-14`; needs redesign for scale at `PERF-09` | — |
| `GAM-06` | ❌ | Streak-freeze earn rules | Low | S | 1–2 d | v1.1.0 / M6 | PM | `firestore_service.grantStreakFreeze` (API exists; only the 1-freeze welcome gift grants) | `SEC-14` | Defined earn rules (e.g. 7 consecutive logged days grants 1, cap 3); granted server-side; surfaced in the UI. **Carried from Phase 15.5: "Only UI + earn-rules missing"** — the UI shipped, the earn rules did not | A freeze that can never be earned is a dead-end mechanic |

---

## §26 — Gym Ecosystem

> **Scope note:** deferred to **M6** per §1.9. Screens stay in the codebase behind a kill-switch. All
> gym work is blocked on `BLK-05` (admin approval) and `BLK-03` (approval notifications).

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `GYM-01` | ✅ | Gym data model, setup (3-step), discovery with search + cursor pagination, member management, owner dashboard, per-gym brand colour, member home, QR + GPS check-in, community feed + announcements, weekly leaderboard, Gym Wars, analytics (heatmap, engagement, at-risk, CSV export), verification badge | — | — | — | shipped | — | 11 screens ≈ 10,000 LOC; `gym_service.dart`, `gym_analytics_service.dart`, `gym_leaderboard_service.dart`, `gym_post_service.dart`, `gym_application_service.dart` | — | Code-verified; **operationally blocked** | — |
| `GYM-02` | 🔥 | Unblock gym application review | Critical | — | — | v1.1.0 / M6 | Security | see `BLK-05`, `BLK-03`, `BE-05` | — | Tracked in `BLK-05` (admin reachable), `BLK-03` (approval batch + notification), `BE-05` (reviewers can actually open the evidence documents). **A gym owner can apply today and then nothing happens, forever** | Three separate defects compound into one dead funnel |
| `GYM-03` | 🔥 | Fix gym logo upload | Critical | XS | 4 h | v1.1.0 / M6 | Firebase Architect | see `BLK-07` | — | Tracked in `BLK-07` | — |
| `GYM-04` | ❌ | Gym post membership enforcement | High | S | 1 d | v1.1.0 / M6 | Security | see `SEC-07` | — | Tracked in `SEC-07` | — |
| `GYM-05` | ❌ | Check-in integrity (server geofence + membership + rate limit) | High | M | 2–3 d | v1.1.0 / M6 | Security | see `SEC-08` | `BLK-08` | Tracked in `SEC-08`. **Gym leaderboards and Gym Wars are meaningless until this lands** | — |
| `GYM-06` | 📋 | Gym Wars — full competition UI | Low | M | 1 w | v1.1.0 / M6 | PM | `gym_war_model.dart`, `gym_leaderboard_service.dart`, 2 indexes exist | `GYM-05` | Bracket/versus visuals, live score, war history, winner announcement and rewards. **Carried from `FUTURE_FEATURES` B2** — model and dual-query scoring exist; the competition surface is thin | Scores are fabricable until `GYM-05` |
| `GYM-07` | ❌ | Gym-side commercial model | High | M | 1 w | v1.1.0 / M6 | PM | none | `BLK-04`, `REF-04` | A decision and implementation for how gyms pay (per-seat, flat, revenue share); B2B onboarding; invoicing. **No gym monetization exists in code or in any prior roadmap** | The gym ecosystem is a distribution bet with **no revenue model defined** — decide before building more |
| `GYM-08` | ❌ | Gym staff roles and multi-location | Low | L | 2 w | v1.2.0 / Icebox | PM | `gyms/{id}/members.role` | `SEC-05` | Trainer/receptionist/manager roles with scoped powers; a chain with multiple locations under one owner | Real gyms have staff and branches; a single-owner model will not survive a pilot |
| `GYM-09` | 📋 | White-label branding beyond a brand colour | Low | L | 2 w | v2.0.0 / Icebox | PM | `GymModel.brandColor`, `resolvedBrandColor` | `GYM-07` | Logo in-app, custom splash, optional custom app listing. **Carried from Phase 4 and `FUTURE_FEATURES` B3** — "only after 1–2 design-partner gyms exist" | Per-tenant theming is a large surface; do not build before a paying partner asks |
| `GYM-10` | ❌ | Gym pilot programme (5–10 real gyms) | High | M | 4 w (external) | v1.1.0 / M6 | CTO / PM | — | `GYM-02`, `GYM-07` | 5–10 real gyms onboarded with real members; requirements validated against reality; retention and check-in data measured. **The prior roadmap's own advice: "get one design-partner gym in parallel with the consumer beta to de-risk without building"** | Building more gym features before a pilot is where the runway goes |

---

## §27 — Coach Ecosystem

> **Scope note:** deferred to **M6** per §1.9.

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `COA-01` | ✅ | Coach profiles, vanity referral codes, 3-step application with evidence upload, pending/rejected/needs-info states, competitive discovery (city+district filters, rating sort, rank badges, Top Coaches, trust badges), client management with at-risk detection, dashboard, AI client report, reviews with transaction-updated aggregates, share card | — | — | — | shipped | — | 8 screens; `coach_service.dart`, `coach_application_service.dart`, `coach_review_service.dart`, `coach_profile_model.dart` | — | Code-verified; **operationally blocked** | — |
| `COA-02` | 🔥 | Unblock coach application review | Critical | — | — | v1.1.0 / M6 | Security | see `BLK-05`, `BLK-03`, `BE-05` | — | Tracked in `BLK-05`, `BLK-03`, `BE-05`. Same dead funnel as `GYM-02` | — |
| `COA-03` | ❌ | Coach review integrity (server-side aggregates) | Medium | S | 1 d | v1.1.0 / M6 | Security | see `SEC-09` | — | Tracked in `SEC-09` | — |
| `COA-04` | ❌ | Coach credential verification process | High | M | 1 w | v1.1.0 / M6 | PM / Legal | `application_review_screen.dart`, `BE-05` | `BE-05` | A documented, repeatable verification standard (which certifications are accepted, how they are checked, who checks, what is recorded); the reviewer UI enforces the checklist; the decision and evidence retained per `LEG-05` | **Approving unverified people to give nutrition advice is a liability.** The screens exist; the *standard* does not |
| `COA-05` | ❌ | Coach session billing and scheduling | Low | XL | 3–4 w | v2.0.0 / Icebox | PM | `commission_service.recordCoachSessionCommission` (ready but never called) | `REF-04`, `BLK-04` | Booking, calendar, payment for real-world coaching, commission on completion. **Carried from Phase 5/7: "actual payment processing intentionally deferred pending a payout provider"** | Real-world services can be billed outside IAP; digital content cannot. Get this distinction legally reviewed |
| `COA-06` | ❌ | Coach pilot programme (5–10 real coaches) | High | M | 4 w (external) | v1.1.0 / M6 | CTO / PM | — | `COA-02`, `COA-04` | Real coaches with real clients; requirements validated; retention measured | Same argument as `GYM-10` |

---

## §28 — Marketplace & Programs

> **Scope note:** deferred to **M6** per §1.9.

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `MKT-01` | 🔥 | Close the `coach_uid == 'demo'` injection hole | Critical | XS | 4 h | v1.1.0 / M6 | Security | see `BLK-09` | `BLK-11` | Tracked in `BLK-09` | — |
| `MKT-02` | ✅ | Program model + content weeks/days/sessions, marketplace with category filters, detail screen with enrolment-gated content, My Programs with progress, admin approval queue (`draft→pending→approved/rejected`), demo content seed | — | — | — | shipped | — | `program_service.dart`, `program_content_model.dart`, `program_marketplace_screen.dart`, `program_detail_screen.dart`, `my_programs_screen.dart` (6 indexes) | `BLK-05` | Code-verified; approval unusable until `BLK-05` | — |
| `MKT-03` | 🟡 | Paid programs — the purchase seam | High | M | 1 w | v1.1.0 / M6 | Monetization | `program_detail_screen.dart:57` (`program.paid_coming_soon`), `canViewContent({required bool isEnrolled})` | `BLK-04` | `canViewContent` extended with `hasPurchased`; program purchase via IAP; entitlement per program written server-side; the honest "Available Soon v2.0" banner replaced. **The seam is deliberately clean — one line to wire** | Digital content **must** go through IAP; do not route it to a payout provider |
| `MKT-04` | ❌ | Remove demo programs from production | High | XS | 2 h | v1.1.0 / M6 | Backend | `demo_content_seeder.dart` (3 programs + content, seeded from every client) | `BLK-09`, `INF-01` | Demo content seeded only in dev/staging; production purged of `coach_uid == 'demo'` programs | **Fake marketplace content in a live storefront** is both a trust and a legal-advertising problem |
| `MKT-05` | ❌ | Program refund and dispute policy | Medium | S | 2 d | v1.1.0 / M6 | Legal / PM | `docs/`, store listings | `MKT-03` | A written refund policy consistent with both stores' rules; a dispute path; commission clawback on refund (`SEC-15`) | Selling content without a refund policy invites store escalations |
| `MKT-06` | 📋 | Supplement / partner-brand ecosystem | Low | L | 2–3 w | v2.0.0 / Icebox | PM | `dish_service.dart` + admin dish DB provide the content foundation | business partnerships | Partner catalogue, affiliate links, disclosure. **Carried from Phase 7 and `FUTURE_FEATURES` E1 — "intentionally deferred to v1.8.0 pending business partnerships"** | Business-gated, not engineering-gated |

---

## §29 — Premium, Subscriptions, Credits & Payments

> Decomposed per the brief — no single "Premium" item.

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `MON-01` | 🔥 | End-to-end monetization enablement | Critical | L | 1–2 w + store | v0.9.9 / M3 | CTO | see `BLK-04` | `BLK-16` | Tracked in `BLK-04` | — |
| `MON-02` | ✅ | Subscription model + entitlements (`SubscriptionTier`, `Entitlements`) | — | — | — | shipped | — | `subscription_model.dart`, `user_model.dart` | — | Verified working | — |
| `MON-03` | ✅ | Server-only entitlement ledger `entitlements/{uid}` + mirror to the user doc for UI | — | — | — | shipped | — | `functions/entitlements.js`, `firestore.rules` | — | Verified working | — |
| `MON-04` | 🚧 | Free plan definition and enforcement | High | S | 1–2 d | v0.9.9 / M3 | Product | `functions/index.js:30-31` (`FREE_DAILY_LIMIT = 2`) | `BLK-04` | The free tier's limits documented publicly and in-app **before** launch: 2 AI generations/day, which features are gated, what happens at the limit; verify 2/day is the right number against beta data | 2 free AI generations/day is a very tight funnel. Validate in M4 — it may be the difference between activation and churn |
| `MON-05` | 🚧 | Premium plan definition and value proposition | High | S | 1–2 d | v0.9.9 / M3 | Product | `premium_upgrade_sheet.dart`, `feature_gate_service.dart` `_PaywallSheet` | `MON-04` | An explicit premium feature list; 20 AI generations/day; the paywall copy states the value concretely; pricing set for TR (₺) and international | The paywall exists and is well built; **what it sells is not defined** |
| `MON-06` | ✅ | AI credit system — daily quotas (free 2 / premium 20), bonus-first consumption, server-enforced, rollback, live badge, credits sheet with usage bar and reset countdown | — | — | — | shipped | — | `ai_credit_service.dart`, `ai_credits_sheet.dart`, `ai_credit_badge.dart`, `functions/index.js:197-252` | — | Verified working — the best-engineered part of the monetization stack | — |
| `MON-07` | 🟡 | Credit top-up product (`cookrange_ai_credits_10`) | High | S | 1 d + store | v0.9.9 / M3 | Monetization | `billing_service.dart:13` (TODO), `:103-126` | `BLK-04` | Registered as a **Consumable** in both stores; purchase grants exactly 10 bonus credits server-side, once per transaction; `AiCreditsSheet` CTA works | Consumables must be marked correctly or they can only be bought once |
| `MON-08` | 🔥 | Server-side enforcement of non-AI premium features | High | M | 1 w | v0.9.9 / M3 | Backend | see `SEC-16` | `BLK-04` | Tracked in `SEC-16` | — |
| `MON-09` | ❌ | Feature-gate inventory and audit | High | S | 1 d | v0.9.9 / M3 | Product | `feature_gate_service.dart`, `subscription_model.dart` `Entitlements` | `SEC-16` | A table in `docs/` listing every gated feature, its entitlement flag, its enforcement point (client or server), and whether bypass is materially harmful | Cannot reason about revenue leakage without the inventory |
| `MON-10` | ✅ | Restore Purchases | — | — | — | shipped | — | `billing_service.restorePurchases()`, `premium_upgrade_sheet.dart` | `BLK-04` | Code verified; **untested** until real products exist. Apple requires a working restore path | — |
| `MON-11` | ❌ | Subscription expiration and grace-period handling | High | M | 3 d | v0.9.9 / M3 | Backend | `functions/purchases.js`, `entitlements/{uid}.expires_at` | `BLK-04` | Expiry downgrades the tier and revokes premium features; a billing-retry grace period honoured (Apple/Google both signal it); the user is warned before expiry; an expired-then-renewed account restores cleanly | Revoking premium during a legitimate billing retry is a support disaster; honour the grace period |
| `MON-12` | ❌ | Upgrade / downgrade / plan-change flow | Medium | M | 3 d | v1.0.0 / M4 | Monetization | `premium_upgrade_sheet.dart`, `functions/purchases.js` | `MON-11` | Monthly→yearly upgrade with proration handled by the store; downgrade at period end; the UI reflects the pending change; entitlement dates recomputed on the server | Store proration semantics differ between Apple and Google — implement per platform and test both |
| `MON-13` | ❌ | Refund and chargeback revocation verified | High | S | 2 d | v0.9.9 / M3 | Backend | `functions/purchases.js` `appStoreNotifications`, `playRtdn` (written, **not deployed** — the prior roadmap lists these as the 2 remaining) | `BLK-04` | Both webhooks deployed and receiving; a sandbox refund revokes the entitlement within minutes; commission clawback fires (`SEC-15`) | Un-revoked refunds are direct revenue loss and a fraud vector |
| `MON-14` | ❌ | Family Sharing | Low | M | 3 d | v1.2.0 / Icebox | Monetization | App Store Connect config, `functions/purchases.js` | `MON-11` | Family Sharing enabled for the subscription; the entitlement resolves for family members; documented in the listing | Apple-only; changes entitlement resolution semantics — test carefully |
| `MON-15` | ❌ | Promo codes and offer codes | Low | M | 3 d | v1.2.0 / Icebox | Monetization | store consoles, `functions/purchases.js` | `MON-11` | Introductory offers, win-back offers, promo codes redeemable in-app; validated server-side | Offer eligibility is store-computed — never trust the client |
| `MON-16` | 📋 | Richer credit and subscription tiers | Low | M | 1 w | v1.2.0 / Icebox | Monetization | `ai_credits` (per-source bonus buckets), `ai_credits_sheet.dart` | `MON-07` | +15 / +50 credit packs, extra regenerations, extra scans; `AiCreditsSheet` becomes a small store; paywall copy A/B via `app_config`. **Carried from `FUTURE_FEATURES` A2 and the README** | Do not add SKUs before the base subscription converts |
| `MON-17` | ❌ | Pricing research for the TR market | High | S | 3 d (external) | v0.9.9 / M3 | PM | — | `MON-05` | Competitor pricing surveyed (Yazio, Lifesum, MyFitnessPal in TR); willingness-to-pay tested with beta users; ₺ pricing set with purchasing-power parity considered | Pricing a Turkish-first product at Western tiers kills conversion; guessing is not a strategy |
| `MON-18` | ❌ | Paywall conversion analytics | High | S | 1 d | v1.0.0 / M4 | Product | `feature_gate_service.dart` (`paywall_shown` event exists) | `FB-24` | `paywall_shown` → `purchase_started` → `purchase_completed` funnel with the triggering feature as a dimension; conversion rate per entry point measured | The event exists; **nothing consumes it** |

---

## §30 — Referral, Affiliate & Payouts

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `REF-01` | ✅ | Referral codes (6-char), `referrals/{code}`, server-validated apply (no self-referral, one-per-account, max-uses), premium grant to both sides, commission ledger entry, share sheet, deep link, admin oversight with void | — | — | — | shipped | — | `referral_service.dart`, `functions/economy.js`, `referrals/{code}` | `INF-07` | Verified working — **but shared links do not open the app until `INF-07` hosts the deep-link files** | — |
| `REF-02` | ✅ | Commission tracking (`users/{uid}/commissions`, `payout_requests`), affiliate earnings screen with summary, stream, type/status badges | — | — | — | shipped | — | `commission_service.dart`, `affiliate_earnings_screen.dart` | — | Verified working (tracking layer only) | — |
| `REF-03` | ❌ | Referral fraud resistance | High | M | 2–3 d | v1.1.0 / M6 | Security | see `SEC-15` | `REF-04` | Tracked in `SEC-15`. **Must land before payouts are enabled** | — |
| `REF-04` | 📋 | Payout provider integration (real money out) | Low | XL | 4–6 w | v2.0.0 / M6+ | CTO / Backend | `affiliate_earnings_screen.dart:214` ("payouts coming soon"), `commission_service.dart` | `SEC-15`, `BLK-04`, `LEG-06` | **Carried in full from `FUTURE_FEATURES` A1.** Provider: **Stripe Connect Express** (global, KYC handled) or **iyzico** for TR-only. Data: `users/{uid}/payout_accounts/{id}` (provider account id, status, KYC state); `payout_requests` extended with provider transfer id + webhook status; immutable double-entry `payout_ledger/{id}`. Backend: `createConnectAccount`, `createPayout`, `stripeWebhook` (transfer.paid/failed → ledger + notify). **Server computes the payable balance from approved commissions minus prior payouts — never trust the client for amounts.** Services: `CommissionService` payable-balance calc + new `PayoutService`. UI: KYC redirect via `url_launcher`, account-status card, payout history with provider status, minimum-threshold gate. Compliance: KYC/AML by the provider; tax forms per region; clear ToS on commission terms. Phasing: M (Connect Express + KYC + manual payout) → M (webhooks + automated balance) → M (tax/threshold/ledger hardening) | **Store-rules risk:** Apple and Google forbid taking a cut of *digital* goods outside IAP, but real-world coaching services and physical payouts are permitted. Keep digital program sales on IAP; route only coach-service payouts via the provider. **Legal review required.** Unblocks the entire coach/affiliate revenue narrative in `README.md` |
| `REF-05` | 📋 | Marketplace and payout legal terms | High | M | 2 w (external) | v2.0.0 / M6+ | Legal | `docs/` drafts exist | `REF-04` | Marketplace terms, commission terms, coach agreement, tax handling. **Carried from `FUTURE_FEATURES` L7 — "DRAFTED, activates with A1 payouts"** | Drafted but not lawyer-reviewed |

---

## §31 — Partner & White Label

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `PTR-01` | ✅ | Per-gym brand colour + logo, applied locally to gym screens (not a global theme override) | — | — | — | shipped | — | `GymModel.brandColor`, `GymModelBrandingX.resolvedBrandColor`, `gym_dashboard_screen.dart` | `BLK-07` | Verified working — logo upload broken until `BLK-07` | — |
| `PTR-02` | 📋 | Full white-label | Low | XL | 4–6 w | v2.0.0 / Icebox | PM | see `GYM-09` | `GYM-07`, `GYM-10` | Tracked in `GYM-09`. "Only after 1–2 design-partner gyms exist" | Multi-tenant theming, per-tenant store listings and per-tenant support are a business decision, not a feature |
| `PTR-03` | 📋 | Partner brand / supplement ecosystem | Low | L | 2–3 w | v2.0.0 / Icebox | PM | see `MKT-06` | business partnerships | Tracked in `MKT-06` | — |

---

## §32 — Admin Panel

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `ADM-01` | 🔥 | Make the admin surface reachable | Critical | S | 1–2 d | v0.9.7 / M1 | Security | see `BLK-05` | — | Tracked in `BLK-05`. **~7,400 LOC across 9 screens is unusable today** | — |
| `ADM-02` | ✅ | Admin hub — categorized card grid, `AdminSection` enum + `AdminSectionMeta` single source of truth, shared drawer, `AdminSectionScaffold` chrome | — | — | — | shipped | — | `admin_hub_screen.dart`, `admin_sections.dart`, `admin_nav.dart`, `widgets/admin_section_scaffold.dart` | `BLK-05` | Code verified; unreachable | — |
| `ADM-03` | ✅ | User management — debounced search, role chip, ban/unban, force logout, password reset, per-user data stats, per-user notification send | — | — | — | shipped | — | `admin_user_management_screen.dart` (894 LOC), `admin_service.dart` (37.6 KB) | `BLK-05` | Code verified; unreachable | — |
| `ADM-04` | ✅ | Application review (coach + gym) with evidence links, approve/reject, notes sheet, history | — | — | — | shipped | — | `application_review_screen.dart` (834 LOC) | `BLK-05`, `BLK-03`, `BE-05` | Code verified; **approval batch fails** (`BLK-03`) and evidence documents are unopenable (`BE-05`) | — |
| `ADM-05` | ✅ | Dish DB management (live stream, search, category filter, edit sheet, re-seed, delete) | — | — | — | shipped | — | `admin_dishes_screen.dart` (825 LOC) | `BLK-05`, `FB-17` | Code verified; unreachable; uses the unbounded stream | — |
| `ADM-06` | ✅ | Moderation queue (pending/reviewed, dismiss, remove content, bulk actions, relative timestamps) | — | — | — | shipped | — | `admin_reports_screen.dart` (586 LOC) | `BLK-05` | Code verified; unreachable | — |
| `ADM-07` | ✅ | Cost & profit dashboard — Firestore `count()` aggregates, unit-price model, Firebase + AI breakdown, revenue/ARPU/profit, what-if projection, **real** AI usage from `ai_usage_stats` with by-model/by-type and per-user lookup | — | — | — | shipped | — | `admin_cost_analytics_screen.dart` (579 LOC), `cost_analytics_service.dart`, `cost_analytics_model.dart` + tests | `BLK-05` | Code verified; unreachable. Firebase figures are **estimates** (no GCP Billing API); the AI section is real | — |
| `ADM-08` | ✅ | Abuse monitoring (banned users, top AI consumers with quota %), audit log viewer, privacy-request queue, broadcasts | — | — | — | shipped | — | `admin_panel_screen.dart`, `admin_privacy_requests_screen.dart` | `BLK-05` | Code verified; unreachable | — |
| `ADM-09` | ✅ | Remote app config editor (`app_config/global`: AI model/tokens/quotas, version gate, maintenance, announcement, feature flags, rollout, limits, endpoints) — **editable without a redeploy, read by client and `aiProxy`** | — | — | — | shipped | — | `admin_app_config_screen.dart` (524 LOC), `app_config_service.dart`, `app_config_model.dart` | `BLK-05`, `SEC-10`, `ARCH-05` | Code verified; unreachable. **Genuinely good design** — but needs the server-side ceiling from `SEC-10` so a mistaken edit cannot raise limits platform-wide | — |
| `ADM-10` | ❌ | Replace estimated Firebase costs with the real GCP Billing API | Medium | M | 3 d | v1.1.0 / M6 | DevOps | `cost_analytics_service.dart`, `cost_analytics_model.dart` (`FirebasePricing`, `UsageAssumptions`) | `BLK-05` | Actual billing data via the Cloud Billing API replaces `UsageAssumptions`; the dashboard clearly labels which figures are measured and which are modelled | Estimated costs presented alongside real AI costs invites treating both as fact |
| `ADM-11` | ❌ | Admin action rate limits and dangerous-action confirmations | Medium | S | 2 d | v1.1.0 / M6 | Security | `admin_service.dart` | `BLK-05`, `SEC-05` | Bulk removals and bans require typed confirmation; a rate limit prevents a compromised admin account from mass-destroying content; every action already audit-logged — verify coverage | A compromised admin is the highest-impact account-takeover target |
| `ADM-12` | ❌ | Admin runbook documentation | High | S | 2 d | v0.9.7 / M1 | Technical Writer | `docs/` | `BLK-05` | How to provision the first admin, review an application, handle a report, respond to a DSAR, put the app in maintenance, force an update, grant bonus credits, handle a refund dispute | No runbook exists. The admin surface is unusable **and** undocumented |

---

## §33 — Moderation

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `MOD-01` | 🔥 | Make the moderation queue reachable and staffed | Critical | S | 1 d | v0.9.7 / M1 | Moderation | see `BLK-05`; `admin_reports_screen.dart` | `BLK-05` | An admin can see and action reports; a documented SLA for first response; the queue is checked daily from beta onward | **Launching UGC with no working moderation is a legal and platform-policy exposure.** Both stores require a functioning report-and-action path |
| `MOD-02` | ✅ | Report flows (post, comment, user, squad, group) with reason pickers writing `reports/{id}` | — | — | — | shipped | — | `community_service.reportContent`, `glass_post_card.dart`, `post_detail_screen.dart`, `chat_detail_screen.dart`, `streak_squad_screen.dart` | `MOD-01` | Verified working | — |
| `MOD-03` | ✅ | Keyword content filter (admin-managed list, public-read mirror, 5-min TTL cache, blocks on match) | — | — | — | shipped | — | `community_service._checkContent`, `settings/content_filter` | — | Verified working | — |
| `MOD-04` | 🚧 | Image safety scanning | High | M | 2–3 d | v0.9.8 / M2 | DevSecOps | see `SEC-13`; `functions/media.js` | `BLK-07` | Tracked in `SEC-13`. Cloud Vision must be **enabled in the console**; `SCAN_PREFIXES` must match the real prefixes; a CSAM/NCMEC path is required before public UGC | The function fails open (keeps the image) when Vision is unavailable — which is the current state |
| `MOD-05` | ❌ | Appeal process for moderation decisions | Medium | M | 3 d | v1.0.0 / M4 | Product / Legal | `account_suspended_screen.dart` (890 LOC, appeal modal is informational-only) | `MOD-01` | A real appeal submission path; the appeal appears in an admin queue; the user is notified of the outcome. **The suspension screen currently shows static strings and no real ban data** — carried from the original partial-features table | Banning users with no appeal path is both unfair and a platform-policy risk |
| `MOD-06` | ❌ | Surface real ban data on the suspension screen | Medium | S | 1–2 d | v1.0.0 / M4 | Flutter Engineer | `account_suspended_screen.dart` | `SEC-03`, `MOD-05` | Reason, date, duration and appeal status read from `admin/status/{uid}`; no static placeholder strings | A polished 890-line screen showing fabricated ban details is a façade |
| `MOD-07` | ❌ | Moderator role for non-founder staff | Low | M | 3–4 d | v1.2.0 / M7 | Security | see `SEC-05` | `SEC-05` | Tracked in `SEC-05`. **Required before any non-founder is given admin access** | Full admin for a moderator is over-privileged |
| `MOD-08` | ❌ | Transparency reporting | Low | S | 2 d | v1.2.0 / Icebox | Legal | `admin_audit`, `reports` | `MOD-01` | Periodic counts of reports received, actions taken and appeals upheld; required or expected in several jurisdictions as scale grows | Low priority at current scale; the data is already being collected |

---

## §34 — Analytics

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `ANL-01` | ✅ | `AnalyticsService` — ~35 typed event methods, Hive-backed offline queue with batching and retry, consent-gated (`setConsentEnabled`), privacy-by-default OFF, release-only | — | — | — | shipped | — | `analytics_service.dart` (1,074 LOC) | `SEC-19` | Verified working. The `analytics_cache` Hive box is the one **unencrypted** box (`SEC-19`) | — |
| `ANL-02` | ❌ | Event taxonomy document | High | S | 2 d | v1.0.0 / M4 | Product | `docs/` | — | Every event named, with its parameters, when it fires, and which funnel or metric it serves. **35 event types exist with no documented taxonomy — nobody can tell which are load-bearing** | Undocumented events accumulate, drift and go stale; the funnel is then unbuildable |
| `ANL-03` | ❌ | Activation, retention and conversion funnels | High | M | 3 d | v1.0.0 / M4 | Product | `FB-24` BigQuery + scheduled queries | `FB-24`, `ANL-02` | Funnels built and dashboarded: install → intro → onboarding complete → first plan → first food log → D1 → D7 → D30; paywall shown → purchase; onboarding drop-off per page (`ONB-05`). **North-star metrics defined and reviewed weekly** | The prior roadmap's own advice — "instrument and validate, let real data decide which phase to fund" — cannot be followed without this |
| `ANL-04` | ✅ | Existing funnel events: `intro_completed`, `gym_joined`, `coach_requested`, `food_logged`, `ai_meal_plan_started/generated`, `post_created`, `shopping_list_generated`, `ai_generated`, `ai_cache_hit`, `credit_consumed`, `credit_exhausted`, `paywall_shown`, `admin_action`, `role_upgrade_completed` | — | — | — | shipped | — | across services | `ANL-03` | Verified emitting; **nothing consumes them** | — |
| `ANL-05` | ❌ | Remove all PII from analytics payloads | High | XS | 2 h | v0.9.8 / M2 | DevSecOps | see `AUTH-12` | — | Tracked in `AUTH-12` (`S17`, `H22`) | — |
| `ANL-06` | ❌ | ATT sequencing after disclosure | Medium | S | 1 d | v0.9.9 / M3 | Legal | `att_consent_service.dart` (one-shot, `att_prompted` SharedPrefs key), `NSUserTrackingUsageDescription` | `LEG-03` | The ATT prompt fires **after** an in-app explanation of what tracking means and why, not cold; `AD_ID` permission on Android reconciled with the Play Data Safety declaration | A cold ATT prompt has a very low grant rate and Apple scrutinises the surrounding context |
| `ANL-07` | ❌ | A/B experiment framework | Low | M | 3 d | v1.2.0 / Icebox | Product | `app_config_service.dart` (rollout bucketing exists) | `ANL-03` | Bucketed experiments with a stable assignment, exposure logging, and a documented analysis method; the existing `rollout` bucketing extended | Experimenting without a defined analysis method produces false confidence |

---

## §35 — Monitoring & Observability

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `OBS-01` | 🔥 | Dashboards, alerts and SLOs | Critical | M | 3–5 d | v0.9.7 / M1 | DevOps | see `BLK-17` | `INF-01` | Tracked in `BLK-17` | — |
| `OBS-02` | 🔥 | Denied-permission-rate alert | Critical | XS | 2 h | v0.9.7 / M1 | DevOps | Cloud Monitoring, `ARCH-01` | `ARCH-01` | An alert on Firestore `permission-denied` rate per collection. **This single alert would have surfaced `BLK-03`, `BLK-06`, `BLK-07` and `BLK-11` in production within minutes.** Wire it early and treat any spike as a rules bug | Requires `ARCH-01` first — denied errors currently never leave the device |
| `OBS-03` | 🔥 | Route all swallowed errors to Crashlytics | Critical | M | 1 w | v0.9.7 / M1 | Principal Engineer | see `ARCH-01` / `DEBT-01` | — | Tracked in `ARCH-01` | — |
| `OBS-04` | ❌ | Performance traces + a measured cold-start number | High | S | 1 d | v0.9.7 / M1 | Performance Engineer | see `FB-23` | — | Tracked in `FB-23` | — |
| `OBS-05` | ❌ | Structured production logging | High | S | 1–2 d | v0.9.8 / M2 | Principal Engineer | `log_service.dart`, codebase-wide `debugPrint` | `ARCH-01`, `SEC-22` | A logging abstraction with levels that actually emits in release (to Crashlytics `log()` breadcrumbs or a log sink), redacts PII (`SEC-22`), and is the only sanctioned logging path. **`debugPrint` is a release no-op — the app currently produces no production logs at all** | Verbose release logging costs money and leaks data — levels and redaction are mandatory |
| `OBS-06` | ❌ | Correlation IDs across client → proxy → provider | Medium | S | 1 d | v0.9.8 / M2 | Backend | see `BE-09` | `OBS-05` | Tracked in `BE-09` | — |
| `OBS-07` | ❌ | Synthetic canary journey | Low | M | 3 d | v1.1.0 / M6 | DevOps | new script | `OBS-01` | A scheduled headless run of register → onboard → generate plan → log food, alerting on failure. **This is the automated version of the manual verification that would have caught all seven dead paths** | Test accounts must not pollute production analytics — tag and exclude them |
| `OBS-08` | ❌ | Uptime checks on the AI proxy | Medium | XS | 1 h | v0.9.7 / M1 | DevOps | GCP console | `BE-01` | An uptime check with alerting on the deployed `aiProxy` endpoint | The proxy being down means the entire product's core feature is down |

---

## §36 — Performance

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `PERF-01` | ❌ | 🔥 Establish measurement before optimising | Critical | S | 1 d | v0.9.7 / M1 | Performance Engineer | see `FB-23` | — | Tracked in `FB-23`. **Every performance statement in this backlog is a structural inference, because the project produces no measurements.** No startup benchmark, no frame timings, no load test, no memory profile exists | Optimising without measurement is how effort is wasted on the wrong thing |
| `PERF-02` | ❌ | Bound the `dishes` queries | High | M | 2 d | v0.9.8 / M2 | Performance Engineer | see `FB-17`; `dish_service.dart:17`, `:56` | `AI-03` | Tracked in `FB-17` | — |
| `PERF-03` | ❌ | Eliminate the N+1 loops | Medium | M | 1 w | v1.1.0 / M6 | Performance Engineer | `community_service.dart` (3 loops incl. the post-delete cascade), `community_group_service.dart`, `firestore_service.dart`, `friend_service.dart`, `gym_service.dart`, `referral_service.dart`, `streak_squad_service.dart`, `demo_content_seeder.dart` (1 each) | `COM-05` | Each loop either batched with `whereIn` (≤ 30), denormalized, or moved to a Function; measured read-count reduction recorded | Cascades that partially fail leave orphans — Functions are the right home |
| `PERF-04` | ❌ | Reduce rebuild scope in the large screens | Medium | M | 3 d | v1.1.0 / M6 | Performance Engineer | `home.dart` (19 `setState`), `profile_screen.dart` (25), `gym_setup_screen.dart` (26), `admin_panel_screen.dart` (29) | `FB-23`, `ARCH-02` | `Selector` / `ValueListenableBuilder` replace broad `watch`; frame timings measured before and after; 60 fps on a mid-range Android device verified | Cannot claim an improvement without `FB-23` |
| `PERF-05` | ✅ | Image performance — 48 `CachedNetworkImage` + 14 `AppImage` vs only 3 raw `Image.network`; uploads resized, compressed, EXIF-stripped, off-thread | — | — | — | shipped | — | `app_image.dart`, `storage_upload_service.dart` | `PERF-11` | Verified working — materially better than typical | — |
| `PERF-06` | ❌ | Shard the `ai_usage_stats/global` counter | High | S | 1–2 d | v1.0.0 / M4 | Backend | `functions/index.js:109-116` | `SEC-10` | The global aggregate sharded (N sub-documents summed on read) or written via a debounced aggregator. **One increment per AI request approaches Firestore's ~1 write/s/document soft limit at ~4 req/s — reached around 100k users** | A hot document silently throttles and starts failing writes; the current code is best-effort so the failure is invisible |
| `PERF-07` | ❌ | `aiProxy` concurrency and instance sizing | High | S | 1–2 d | v1.0.0 / M4 | Backend | `functions/index.js:290-292` (`maxInstances: 20`, `memory: '256MB'`) | `PERF-10`, `BE-02` | Sized from real load-test data; **20 instances × ~5 s ≈ 4 req/s sustained**, which will queue on a Monday-morning plan-generation spike; consider Cloud Run for better concurrency and connection reuse | Under-provisioning turns a traffic spike into a total AI outage |
| `PERF-08` | ❌ | Full-text search engine | High | L | 1–2 w | v1.1.0 / M6 | Backend | `admin_service.searchUsers` (prefix range), `user_search_screen.dart`, `gym_service.searchGyms`, `coach_service.searchCoaches`, `dish_service` | `INF-01` | Typesense or Algolia fed by Firestore triggers; fuzzy, multi-token, typo-tolerant search across users, dishes, coaches, gyms and programs. **Prefix range queries become inadequate around 10k users** | Search quality is a visible product-quality signal; prefix matching feels broken to users |
| `PERF-09` | ❌ | Redesign leaderboards for scale | Medium | L | 1–2 w | v1.1.0 / M6 | Backend | `leaderboard_service.dart` (`orderBy onboarding_data.streak desc, limit 50`), `gym_leaderboard_service.dart` | `SEC-14` | Maintained rollup documents or Redis sorted sets behind a Function; ranking does not require a full scan; **Firestore cannot rank at scale without this — the ceiling is ~50k users** | Combined with `SEC-14`: today the leaderboard is both un-scalable and gameable |
| `PERF-10` | ❌ | Load-test the AI proxy | High | S | 1–2 d | v1.0.0 / M4 | Performance Engineer | `scripts/load_test.js` exists (configurable concurrency, P50/P90/P95/P99, error-rate exit code) | `BE-01` | The existing script run against staging at realistic concurrency; P95 latency, error rate and cost-per-request recorded; `maxInstances` and timeouts sized from the result. **`GO_LIVE.md` §5.4 is unchecked — the script was written but never run** | Publishing a paid AI endpoint without a load profile is how the first traffic spike becomes an outage and a bill |
| `PERF-11` | ❌ | Replace raw `Image.network` in the share cards | Low | XS | 1 h | v1.0.0 / M4 | Flutter Engineer | `coach_share_card.dart:210`, `gym_share_card.dart:213`, `lib/scripts/seed_db.dart:226` | — | Share cards capture to PNG via `RepaintBoundary`; an uncached network image will render **blank** at capture time. Use a pre-warmed `CachedNetworkImageProvider` or await the image before capture | Silently produces broken share images — a virality feature that fails invisibly |
| `PERF-12` | ❌ | Frame-timing / jank regression harness | Low | S | 2 d | v1.1.0 / M6 | Performance Engineer | `scripts/` | `FB-23` | A repeatable harness capturing frame timings on the 5 primary screens; a budget defined; regressions flagged. **Carried from `FUTURE_FEATURES` G2** | Manual jank testing does not scale and is not comparable between runs |
| `PERF-13` | ❌ | Memory profile and leak check | Medium | S | 2 d | v1.0.0 / M4 | Performance Engineer | `leak_tracker` is already a dev dependency but never run | `TEST-03` | A leak-tracker pass in CI on the widget tests; a memory profile recorded on a long session (1 h of navigation); the 7 open Hive boxes and the unbounded Firestore cache (`ARCH-08`) measured | `leak_tracker` is a declared dependency that has never been used — free coverage left on the table |
| `PERF-14` | ❌ | Reduce splash-screen animation gate | Low | XS | 2 h | v1.0.0 / M4 | UX Engineer | `splash_screen.dart:649` (hard `await Future.delayed(1500 ms)`) plus sequential controller `forward()`/`reverse()` | `FB-23` | Perceived startup becomes work-bound, not animation-bound; the app opens as soon as it is ready. **Measure first** — the animation may currently be masking real init time, in which case fix the init, not the animation | Cutting the animation without measuring could expose a slow init as a blank screen |

---

## §37 — Accessibility

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `A11Y-01` | 🚧 | Screen-reader pass on the 10 primary flows | High | L | 2 w | v1.0.0 / M4 | UX Engineer | 32 `Semantics`/`semanticLabel` sites across **329 files** | `UI-02` | TalkBack and VoiceOver verified end to end on: onboarding, login, home, log food, meal plan, recipe, community feed, create post, chat, settings. Every interactive element has a label; reading order is logical; state changes are announced. **`CLAUDE.md` lists accessibility as shipped in Phase 2–3.5; the code does not support that claim** | For a health app in regulated markets this is a compliance exposure, not only a quality gap |
| `A11Y-02` | ❌ | Contrast audit (AA) | High | M | 3 d | v1.0.0 / M4 | UX Engineer | `app_palette.dart`, the glassmorphism surfaces | `UI-01` | Every text/background pair meets WCAG AA in both themes; the glass surfaces specifically verified (frosted blur over arbitrary content is the highest-risk pattern); the existing high-contrast path (`AppGlassCard` → solid surface) verified | Glassmorphism and contrast are in direct tension — this must be measured, not eyeballed |
| `A11Y-03` | ❌ | Minimum touch-target audit (44×44) | Medium | S | 2 d | v1.0.0 / M4 | UX Engineer | all interactive widgets | — | Every tappable element ≥ 44×44 logical pixels; the compact filter pills and icon buttons specifically checked | Small targets fail both accessibility guidance and everyday usability |
| `A11Y-04` | ❌ | Dynamic type / font-scale support | Medium | M | 3 d | v1.0.0 / M4 | UX Engineer | `screen_util_service.createResponsiveMediaQuery` (clamps text scaling) | `UI-05` | Layouts survive 200 % font scale without clipping or overlap; the current clamp reviewed — clamping text scale is an accessibility anti-pattern unless narrowly justified | Clamping is a shortcut that breaks users who need large text |
| `A11Y-05` | 🚧 | Reduced-motion coverage | Medium | S | 2 d | v1.0.0 / M4 | UX Engineer | reduced-motion honoured in `achievements_grid.dart`, `coachmark_tip.dart`, `AppSheet`, intro; **not** across the 42 files using `AnimationController` | `UI-02` | `MediaQuery.disableAnimations` honoured in every animated widget; a single helper wraps the check so it cannot be forgotten | Partial coverage means the setting appears not to work |
| `A11Y-06` | ❌ | Accessibility regression tests | Medium | M | 3 d | v1.1.0 / M6 | QA Lead | `test/` | `TEST-03` | Widget tests asserting semantic labels on the primary flows; a CI check for interactive widgets missing labels | Manual a11y passes decay immediately without tests |

---

## §38 — Localization

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `I18N-01` | ✅ | EN/TR at 2,722 keys each, exact parity, no empty values, CI-enforced by `test/i18n_parity_test.dart`; `screen.section.element` naming; AI responses forced into the user's locale; locale-tagged AI caches | — | — | — | shipped | — | `assets/localization/{en,tr}.json`, `app_localizations.dart`, `prompt_service.localeInstruction` | `BLK-13` | Verified working. **The strongest dimension in the audit — better than most funded startups.** Protect the parity test | — |
| `I18N-02` | ❌ | Remove orphaned i18n keys | Low | XS | 1 h | v0.9.8 / M2 | Technical Writer | 4 orphan challenge keys (`notification_prefs.challenges`, `gym.feature_challenges`, `gym.feature_challenges_sub` + TR) | `CHL-00` | Orphans removed; legitimate uses of the word "challenge" (`ai.weekly_recap_challenges`, `gym.war_*`, `intro.page3_*`) **kept or reworded deliberately** — note `intro.page3_title` still says "Community & Challenges" for a feature that no longer exists | User-visible copy promising a removed feature is a trust problem, not just an orphan key |
| `I18N-03` | 📋 | Additional locales beyond EN/TR | Low | M per locale | 1 w per locale | v1.2.0 / Icebox | PM | `assets/localization/`, `app_localizations.dart` | `NUT-09` | The language picker is already an extensible `AppSheet` list — a new locale is a new JSON file plus a dish catalog (`NUT-09`) and legal-document translation. **Carried from Phase 9 and `FUTURE_FEATURES` F1** | Localizing the UI without localizing the food catalog and legal documents produces a half-translated product |
| `I18N-04` | ❌ | Localize the server-side push copy | High | S | 1–2 d | v0.9.7 / M1 | Backend | `functions/index.js:490-535` (`getPushText` is **English-only**) | `BLK-03` | The recipient's locale read from their user doc; push title/body rendered in that locale, matching the in-app `NotificationPresenter` behaviour. **In-app notifications are correctly localized; push is hardcoded English** — a visible inconsistency for the Turkish-first audience | Undermines the product's strongest differentiator at the most visible touchpoint |
| `I18N-05` | ❌ | Locale-aware number, date and unit formatting audit | Medium | S | 2 d | v1.0.0 / M4 | Flutter Engineer | `intl` is a dependency; usage not audited | — | Dates, decimals, weights (kg) and currency (₺) formatted per locale everywhere; no hardcoded `dd/MM/yyyy` or `.` decimal separators | Turkish uses `,` as the decimal separator — a hardcoded `.` looks broken to the primary audience |
| `I18N-06` | ❌ | Turkish copy review by a native speaker | High | S | 3 d (external) | v1.0.0 / M4 | PM (external) | `assets/localization/tr.json` (2,722 values) | — | A native Turkish speaker reviews every user-visible string for naturalness, tone and fitness-domain terminology; corrections applied | 2,722 machine-or-developer-written Turkish strings in a Turkish-first product carry real quality risk. Parity is verified; **quality is not** |

---

## §39 — Design System & UI

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `UI-01` | ✅ | Design system — 14 DS components (`AppButton`, `AppCard`/`AppGlassCard`, `AppSheet`, `AppShimmer`/skeletons, `AppEmptyState`/`AppErrorState`, `AppCalorieRing`, `AppFilterBar`/`AppFilterPill`, `AppTextField`, `AppSnackBar`, `AppTransitions`, `AppSelectors`, `AppAvatar`, `PermissionPrimer`) over semantic token layers (`AppPalette`, `AppText`, `AppSpacing`, `AppRadius`, `AppSize`, `AppElevation`, `AppMotion`, `AppGradients`) | — | — | — | shipped | — | `lib/core/widgets/ds/`, `lib/core/theme/` | — | Verified working. Glassmorphism v2 with glass tokens, blur constants, and a high-contrast/reduce-transparency fallback path | — |
| `UI-02` | ❌ | Replace the 87 raw `CircularProgressIndicator` instances | High | M | 1 w | v0.9.8 / M2 | UX Engineer | 87 sites, including **5 in `lib/core/utils/route_guard.dart`** — the file every navigation passes through | — | Every loading state uses `AppShimmer`/`AppSkeleton*` or a context-appropriate skeleton; `route_guard.dart` fixed first (`ONB-07`); a CI grep prevents new raw spinners. **`CLAUDE.md` R7 states verbatim: "No raw `CircularProgressIndicator` dropped on a blank screen" — the routing core does exactly that five times** | The project's own most-stated design rule is its most-violated one |
| `UI-03` | ❌ | Migrate the 334 hardcoded colours | Medium | L | 1–2 w | v1.1.0 / M6 | UX Engineer | 120 `Color(0xFF…)` + 214 `Colors.white`/`Colors.black` in `lib/screens`. Worst: `gym_setup_screen.dart` (15), `account_suspended_screen.dart` (15), `program_detail_screen.dart` (11), `gym_analytics_screen.dart` (8), `generic_error_screen.dart` (8) | `A11Y-02` | All non-deliberate literals replaced with `AppPalette` roles; deliberate exceptions (image scrims, colour-picker swatches) annotated with a comment; **dark mode verified on the gym, programs and error surfaces, which are very likely broken today** | `CLAUDE.md` R6 says "never hardcode a color". Dark mode is defined but not applied on these screens |
| `UI-04` | ❌ | Dark-mode verification sweep | High | M | 3 d | v1.0.0 / M4 | UX Engineer | all 75 screens | `UI-03` | Every screen screenshotted in both themes on both platforms and reviewed; a golden-test suite locks the result (`TEST-05`) | Both themes are fully defined; the risk is application, not definition |
| `UI-05` | ❌ | Responsive audit | Medium | M | 3 d | v1.0.0 / M4 | UX Engineer | `screen_util_service.dart`, design-px tokens with `.r`/`.w`/`.h` | `A11Y-04` | Verified on a small phone (SE-class), a large phone, and with 200 % font scale; no clipping or overflow. **The Phase 3.5 notes record a real 172 px overflow that had to be fixed — assume there are more** | Design-px scaling breaks at the extremes |
| `UI-06` | ✅ | Context-aware skeletons (`AppSkeletonMealCard`, `AppSkeletonStatGrid`, `AppSkeletonChart`, `AppSkeletonList`) | — | — | — | shipped | — | `app_shimmer.dart` | `UI-02` | Verified working — but 87 raw spinners still bypass them | — |
| `UI-07` | ✅ | Shared `AppFilterBar` across all four discovery surfaces (gym, coach, marketplace, community) — single source of truth | — | — | — | shipped | — | `app_filter_bar.dart` | — | Verified working | — |
| `UI-08` | ❌ | Empty/error/loading state completeness audit | High | M | 3 d | v1.0.0 / M4 | UX Engineer | every `StreamBuilder`/`FutureBuilder` | `ARCH-01` | Every async surface has all four states, and **a permission-denied failure renders an error state, never an empty state** (`ARCH-01`). A checklist per screen recorded | `AppEmptyState` currently masks `BLK-06` and `BLK-11`. Good empty states hiding broken features is the worst outcome |
| `UI-09` | 📋 | Tablet / large-screen layouts | Low | M | 1 w | v1.2.0 / Icebox | UX Engineer | none | `UI-05` | Two-pane layouts on tablets; the app currently has no tablet-specific layout and no landscape handling beyond `UISupportedInterfaceOrientations`. **Carried from `FUTURE_FEATURES` F2** | Both stores show tablet screenshots; a phone-stretched layout reviews badly |
| `UI-10` | ❌ | Remove the dead `flutter_native_splash` configuration | Low | XS | 1 h | v0.9.8 / M2 | Flutter Engineer | `pubspec.yaml` (25-line config block; **the package is not in `dev_dependencies`**) | — | Either add the package and generate the splash, or delete the dead config | 25 lines of configuration that does nothing is a trap for the next engineer |
| `UI-11` | ❌ | Haptics consistency audit | Low | XS | 2 h | v1.0.0 / M4 | UX Engineer | `AppButton` (has haptics), other interactive surfaces | — | Haptics on meaningful actions only, consistent across platforms, respecting the system setting | Inconsistent haptics feel unfinished |

---

## §40 — CI/CD & Release Automation

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `CI-01` | ✅ | Get all four CI jobs green | Critical | S | 4 h | v0.9.7 / M1 | DevOps | see `BLK-13`, `CI-11`, `CI-12` | — | **All four confirmed green in real CI** ([run #46](https://github.com/burcok/cookrange/actions/runs/30690211684)) — `analyze-and-test`, `firestore-rules`, `secret-scan`, `build-android`. First time in this repo's history | — |
| `CI-02` | ❌ | Branch protection requiring green CI | Critical | XS | 30 m | v0.9.7 / M1 | DevOps | GitHub settings | `CI-01` | `main` protected; all four checks required; no direct pushes; the 97-commit history shows direct commits to `main` throughout | Without protection, a red `main` recurs immediately |
| `CI-03` | 🚧 | Rules tests running in CI | Critical | L | 1 w | v0.9.7 / M1 | QA Lead | see `FB-18`; `.github/workflows/ci.yml` `firestore-rules` job | `BLK-13` | **The job now runs and is green** (15/15, real CI run linked in `FB-18`). Full-coverage bar tracked in `FB-18` | — |
| `CI-04` | ❌ | Verify the deploy workflow end to end | High | S | 1 d | v0.9.9 / M3 | DevOps | `.github/workflows/deploy.yml` | `BLK-16` | One successful TestFlight upload and one Play internal upload from CI; the keychain cleanup step verified; secret rotation documented | A 200-line signing workflow that has never run will not work first time — budget for iteration |
| `CI-05` | ❌ | Obfuscated release builds + symbol upload | High | S | 1 d | v0.9.9 / M3 | DevOps | see `SEC-18`, `FB-22` | `BLK-16` | Tracked in `SEC-18` + `FB-22` | — |
| `CI-06` | ❌ | Staged rollout and rollback lever | High | S | 1 d | v1.0.0 / M5 | DevOps | Play Console staged rollout, App Store phased release, `app_config/global.version.force_update` | `BLK-16` | Releases go out at 5 % → 20 % → 50 % → 100 % with crash-rate gates; the force-update lever tested as a rollback mechanism (`min_supported` bump); a documented rollback runbook | The force-update gate is the **only** rollback lever for a client app — test it before you need it |
| `CI-07` | ❌ | Automated changelog and What's New | Low | S | 1 d | v1.0.0 / M5 | DevOps | `whats_new_service.dart`, `whats_new_sheet.dart` (SharedPrefs version-bump gate exists) | `CI-06` | Release notes generated from commits, feeding both the store listing and the in-app What's New sheet in EN+TR | The in-app mechanism exists; the content pipeline does not |
| `CI-08` | ❌ | Pre-commit hooks | Low | XS | 2 h | v0.9.8 / M2 | DevOps | `.githooks/` or `lefthook` | `CI-01` | `dart format` + `flutter analyze` + a secret scan run before commit. **44 unformatted files reached `main`** because nothing checked locally | Cheap prevention of the exact failure that made CI red |
| `CI-09` | ❌ | Dependabot / dependency update automation | Medium | XS | 1 h | v0.9.8 / M2 | DevOps | `.github/dependabot.yml` | `SEC-28` | Dependabot on `pub` and `npm`; weekly PRs; security advisories reviewed. `flutter pub outdated` previously reported 78 newer versions | Manual dependency review does not happen |
| `CI-10` | ❌ | Emulator-based integration tests in CI | Medium | M | 3 d | v1.1.0 / M6 | QA Lead | see `TEST-02`; `INF-02` | `TEST-02` | Tracked in `TEST-02` | — |
| `CI-11` | ✅ | `analyze-and-test` job failed in CI across 3 separate, unrelated root causes | Critical | L (grew well past the original S–M estimate) | ~6 h total | v0.9.7 / M1 | DevOps | `.github/workflows/ci.yml` (Flutter pin, firebase_options placeholder — both jobs) · `.gitignore` (`**/build/`) · `assets/Fonts/` → `assets/fonts/` (17-file case rename) | — | **Fully diagnosed and fixed, verified in a real Ubuntu container matching CI's exact architecture — not guessed.** Three independent bugs stacked on top of each other, each one hiding the next until the previous was fixed: **(1)** `flutter pub get` failed — 9 direct dependencies bumped past what the never-updated Flutter `3.24.0` pin's Dart 3.5.0 supports (`dependency_overrides`/`DEBT-42` was a red herring; overrides bypass version-solve checking). Fixed by bumping the pin to `3.44.4`, matching local dev — **confirmed green in [run #42](https://github.com/burcok/cookrange/actions/runs/30669425771)**. **(2)** With `pub get` fixed, `flutter analyze` then failed with 3 "Undefined name 'DefaultFirebaseOptions'" errors (`lib/main.dart`, `app_initialization_service.dart`, `seed_db.dart`) — `ci.yml`'s placeholder for the gitignored `lib/firebase_options.dart` was literally just a comment, never a real stub (`DEBT-52`'s real severity: it doesn't just block a device build, it fails static analysis outright). This has been broken since `ci.yml` was created — invisible until (1) was fixed, since analyze was never reached before. Fixed with a minimal valid `DefaultFirebaseOptions.currentPlatform` stub, added to **both** `analyze-and-test` and `build-android` (which had no placeholder step at all — silently broken the same way). **(3)** Analyze then failed once more on `warning • The asset directory 'assets/fonts/' doesn't exist`. Root cause: git tracks `assets/**F**onts/` (capital F) but all 17 `pubspec.yaml` font declarations say `assets/**f**onts/` (lowercase) — a genuine, repo-wide case mismatch invisible for the project's entire life because **macOS's filesystem is case-insensitive** (every local dev machine silently resolved the mismatch) while Linux (CI, and every real Android device) is not. Fixed via a case-only `git mv` (two-step, since a direct rename no-ops on a case-insensitive filesystem). Also found and removed while in that directory: 54 accidentally-committed Xcode build-cache files (47 under `assets/Fonts/build/`, 7 under `android/build/` — a misconfigured derived-data path, unrelated to the case bug) — `.gitignore` broadened from `/build/` (root-only) to `**/build/` so this can't recur silently. **Verification methodology**: installed `colima`+`docker` (no Docker Desktop on this machine), ran a real `ubuntu:24.04` container under `--platform linux/amd64` (matching GitHub's actual runner architecture, not just "some Linux"), cloned Flutter `3.44.4` and the actual repo state via `git archive` of a `git stash create` snapshot — i.e. tested the **exact bytes about to be pushed**, not an approximation. `pub get`, `dart format`, `flutter analyze --no-fatal-infos`, and `flutter test` all exit 0 in that container. **All 3 fixes confirmed in a real CI run** ([#44](https://github.com/burcok/cookrange/actions/runs/30687453667)): `analyze-and-test` genuinely green end to end (2m 29s — `Get dependencies`, `Verify formatting`, `Analyze code`, `Run tests` all succeeded), `firestore-rules` and `secret-scan` green as before. This card's own scope is complete | `deploy.yml` deliberately **not** given the same `firebase_options.dart` placeholder — it builds real release artifacts for actual store distribution, so a fake-credentials stub would be actively wrong, not just incomplete; that gap stays tracked under `DEBT-52`/`BLK-16`'s existing scope. Font-rendering correctness itself (as opposed to the analyzer/asset-declaration check) is unverified on a real device — worth a spot-check next time the app runs on Android. **`build-android` now fails on a 4th, distinct issue — see `CI-12`, opened separately rather than folded in here** |
| `CI-12` | ✅ | `build-android`'s `flutter build apk --debug` step failed in CI — first time this step had ever executed | Critical | S–M | ~2 h diagnosis + fix | v0.9.7 / M1 | DevOps | `android/gradle.properties` (1 line removed) | — | **Root cause confirmed by reproduction, not guessed.** Set up a real Android SDK (platform 36, NDK 28.2.13676358, build-tools 36.0.0, licenses accepted) inside a fresh `ubuntu:24.04` container and hit the *exact* same error CI showed: `Value '/Applications/Android Studio.app/Contents/jbr/Contents/Home' given for org.gradle.java.home Gradle property is invalid`. Real cause: `android/gradle.properties` hardcoded `org.gradle.java.home` to an absolute macOS-only path — Android Studio's bundled JBR. It worked silently on this one machine (confirmed: that exact path genuinely exists here, with a real JBR) and would fail identically on **any** other environment — every CI runner, any teammate's machine, any Mac without Android Studio installed at that exact location. Git history shows this line has **never** been portable — it previously hardcoded a different local path (`/opt/homebrew/opt/openjdk@17`, commit `3000ba7`) before being swapped to the Android Studio JBR path — same failure class as `CI-11`'s `assets/Fonts` case bug: a value true on exactly one machine. **Fix:** removed the line entirely rather than replacing it with yet another hardcoded path, letting Gradle use the ambient `JAVA_HOME` that `ci.yml`'s own "Set up Java" step already sets correctly. Verified the fix doesn't break the local Mac build either (still succeeds, ~62s). **Confirmed in real CI**: [run #46](https://github.com/burcok/cookrange/actions/runs/30690211684) — `build-android` `success`, all four jobs green for the first time in this repo's history | An arm64-native container was tried first for faster iteration but hit an unrelated snag (AAPT2 ships x86_64-only native binaries; the arm64 image lacked x86_64 emulation library support) — reverted to `--platform linux/amd64` (matching CI/GitHub exactly) for the real confirmation, which is the only one that counts |

---

## §41 — Testing

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `TEST-01` | 🚧 | Commit and run the Firestore rules test suite | Critical | L | 1 w | v0.9.7 / M1 | QA Lead | `test/firestore_rules/rules.test.mjs` (tracked, **green in CI**) | `BLK-13` | Committed and running (15/71 match blocks, all passing). Still open: cover the other ~56 blocks per §7.2; make the CI job required. **This suite would have caught 5 of the 17 blockers. It is the single highest-value test investment in this backlog** | Rules tests need the emulator; keep them fast or they get skipped |
| `TEST-02` | ❌ | Integration tests for the critical flows | Critical | L | 2 w | v1.0.0 / M4 | QA Lead | `integration_test/` (does not exist) | `ARCH-04`, `INF-02` | End-to-end against the emulator: register → verify → onboard → generate plan → log food → view analytics; login → community → post → comment; purchase → entitlement (sandbox). **Zero integration tests exist today** | Integration tests are the only automated defence against the class of defect that produced this entire backlog |
| `TEST-03` | ❌ | Widget tests for real screens | High | L | 2 w | v1.0.0 / M4 | QA Lead | `test/widget_test.dart` is 92 LOC covering `ErrorFallbackWidget` + `UnknownRouteScreen` only | `ARCH-04` | The 10 primary screens have widget tests covering loading, empty, error and success states with faked services; **the meal-plan screen specifically asserts an error state when AI is unconfigured** (`BLK-01` regression test) | Required before `ARCH-02` refactoring — otherwise 12,000 lines of untested UI get restructured blind |
| `TEST-04` | ✅ | Unit tests — 78 tests across 11 files: `calorie_calculator` (20), `streak_logic` (8), `meal_plan_parse` (8), `onboarding_projection`, `water_reminder_schedule`, `allergen_safety`, `ai_credit_model` (6), `cost_analytics` (3), `i18n_parity` (2), `app_lifecycle_service` (3), `widget_test` | — | — | — | shipped | — | `test/` | `BLK-13` | Verified — genuinely good pure-logic coverage of the maths and safety code. All 78 pass; all 11 files tracked | — |
| `TEST-05` | ❌ | Golden tests for the DS components | Medium | M | 1 w | v1.1.0 / M6 | QA Lead | `test/goldens/` | `TEST-03` | Golden images for all 14 DS components in both themes at two font scales; a visual regression fails the build. **Carried from `FUTURE_FEATURES` G1** | Goldens are brittle across platforms — pin the test environment |
| `TEST-06` | ❌ | Cloud Functions unit tests | High | M | 1 w | v0.9.8 / M2 | QA Lead | `functions/` (**no tests at all**) | `INF-02` | `enforceRateLimitAndQuota`, `isPremium`, `pricingFor`, `recordUsage`, `resolveBroadcastAudience`, purchase validation and `deleteUserAccount` unit-tested against the emulator; the fail-closed quota path specifically tested | 1,692 LOC of the most security-critical code in the project has **zero tests**, including the money and quota paths |
| `TEST-07` | ❌ | Test coverage reporting and a floor | Medium | S | 1 d | v1.0.0 / M4 | QA Lead | `.github/workflows/ci.yml` | `TEST-03` | Coverage measured and reported per PR; a floor set (start at the current ~1 % and ratchet); the floor never decreases | Coverage as a target invites gaming; use it as a ratchet, not a goal |
| `TEST-08` | ❌ | Manual QA test plan and device matrix | High | M | 3 d | v1.0.0 / M4 | QA Lead | `docs/` | `BLK-16` | A written plan per release covering every primary flow on: iPhone SE-class, current iPhone, mid-range Android, current Android; both themes, both locales, and denied-permission paths. **Every one of the seven dead paths would have been caught by one honest manual pass** | The single most effective quality intervention available right now, and the cheapest |
| `TEST-09` | ❌ | Red-team prompt-injection suite | High | M | 3 d | v0.9.8 / M2 | AI Architect | see `SEC-11` | `AI-09` | Tracked in `SEC-11` | — |
| `TEST-10` | ✅ | Fix the `app_lifecycle_service_test` mock signature | Critical | XS | 1 h | v0.9.7 / M1 | QA Lead | `test/app_lifecycle_service_test.dart` (`MockFirestoreService` was missing `syncDeviceContext` **and** `verifyAndRepairUserData` overrides — the second one only surfaced once the first was fixed) | `BLK-13` | All 78 tests green — verified locally and re-confirmed the fix isn't a rubber stamp by breaking `_endSession` and watching 2 of 3 tests correctly fail | — |

---

## §42 — Documentation

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `DOC-01` | 🔥 | Reconcile documentation with reality | Critical | M | 2 d | v0.9.7 / M1 | Technical Writer | `CLAUDE.md` (49 KB), `README.md` (22 KB), `ARCHITECTURE.md`, `AGENTS.md`, `docs/*` (486 KB total) | `CHL-00`, `BLK-05` | Every false claim corrected: (a) "challenges fully shipped" — **deliberately sunset in Phase 13.2**; ~~(b) admin gate documented as `admin/status/{uid}` — rules use `admin_roles/{uid}`~~ **fixed** —
`firestore.rules`'s own comment and `docs/SECURITY.md` §4 both corrected with `BLK-05`; ~~(c) `meal_plan_history` documented as working — no rule~~ **fixed** — rule written, tested, and deployed with `BLK-06`; (d) `notifications/{uid}/items` documented as the in-app path — the client writes `users/{uid}/notifications`; (e) "10/12 functions deployed" — unverifiable, and `APP_ENV=development` makes App Check and purchases inert regardless; (f) "accessibility semantics" listed as shipped — 32 sites in 329 files. **Documentation that confidently describes non-existent features is worse than no documentation, because it prevents discovery** | The docs are the primary onboarding artifact for any future engineer and for AI-assisted work. Wrong docs actively cause defects |
| `DOC-02` | ❌ | Rewrite the README to match the product | High | S | 1 d | v1.0.0 / M5 | Technical Writer | `README.md` | `DOC-01` | The README describes **the consumer nutrition app that will actually ship**, with the "Fitness Operating System" framing clearly marked as vision. Features described but absent (XP/levels, challenges, payouts, white-label, supplements) moved to a clearly-labelled roadmap section. **Carried from the prior roadmap's own founder recommendation: "the README is a vision doc; don't let it set the v1 scope"** | A README selling an OS while the app ships a meal planner damages credibility with both users and investors |
| `DOC-03` | ❌ | Runbooks | High | M | 3 d | v0.9.7 / M1 | Technical Writer | `docs/` | `ADM-12`, `DR-02` | Runbooks for: fresh-environment bootstrap (incl. the first admin and the dish seed), deploy + verify, rollback via force-update, restore from backup, incident response, DSAR handling, key rotation, account-takeover response. **None exist** | Every operational task is currently tribal knowledge held by one person |
| `DOC-04` | ❌ | Architecture Decision Records | Medium | S | 2 d ongoing | v0.9.8 / M2 | Software Architect | `docs/adr/` | — | ADRs for the decisions this backlog forces: repository layer (`ARCH-03`), config consolidation (`ARCH-05`), notification path (`BLK-03`), user-doc split (`BLK-10`), consumer-only v1 scope (§1.9), offline strategy (`ARCH-07`) | Undocumented decisions get re-litigated and silently reversed |
| `DOC-05` | ❌ | Keep `docs/` in sync — enforce R8 | Medium | XS | ongoing | continuous | Technical Writer | `CLAUDE.md` R8, `docs/INDEX.md` | `DOC-01` | Every task's DoD already requires the owning doc to change in the same commit (§0.5). A PR template checklist makes it visible; drift is treated as a defect | R8 exists and was not followed — which is how `DOC-01` accumulated. The rule needs a mechanism, not just a statement |
| `DOC-06` | ❌ | API documentation for the proxy contract | Low | S | 1 d | v1.1.0 / M6 | Technical Writer | `functions/index.js` | `BE-07` | The `aiProxy` request/response contract, error codes (402 quota, 429 rate, 413 payload, 502 upstream, 503 quota-store), and versioning documented | Client and server contract drift is currently invisible |
| `DOC-07` | ❌ | Retire the superseded roadmap documents | Medium | XS | 1 h | v0.9.7 / M1 | Technical Writer | `docs/roadmap/GO_LIVE.md`, `FUTURE_FEATURES.md`, `COMMUNITY_GROUPS.md`, `ONBOARDING_V2.md`, `PHASE_15_ENGAGEMENT.md` | this document | Each superseded file gets a header pointing to `TODO.md` as the single source of truth, **or** is deleted after its content is confirmed present here (§50 traceability matrix). `GO_LIVE.md`'s console-step detail and `COMMUNITY_GROUPS.md`'s product thesis are worth retaining as reference — mark them reference-only, not backlog | Two competing backlogs is how the previous drift started |

---

## §43 — Store Readiness

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `STORE-01` | 🔥 | Developer programme enrolment, signing, store records | Critical | M | 1–2 w wall clock | v0.9.9 / M3 | CTO | see `BLK-16` | — | Tracked in `BLK-16`. **Longest lead time in the backlog — start day one** | — |
| `STORE-02` | ✅ | iOS photo-library usage description | Critical | XS | 1 h | v0.9.7 / M1 | Flutter Engineer | see `BLK-02` | — | Tracked in `BLK-02`, closed | — |
| `STORE-03` | ❌ | Store listing assets and metadata | High | M | 1 w | v1.0.0 / M4 | PM | `cookrange-icon.png`, `cookrange-logo.png` exist | `BLK-16` | Icon, screenshots (phone + tablet, both platforms), preview video, title, subtitle, description, keywords — all in EN and TR; age rating questionnaires completed | Screenshots showing features that will not ship (challenges, payouts) is a rejection and a trust risk |
| `STORE-04` | ❌ | Privacy nutrition labels and Play Data Safety | Critical | M | 3 d | v0.9.9 / M3 | Legal | App Store Connect, Play Console | `BLK-10`, `BLK-12`, `LEG-01` | Accurate declarations of every data type collected, its purpose, whether it is linked to identity, and whether it is used for tracking. Must reconcile with: health data, IP and device fingerprints (`BLK-10`), the `AD_ID` permission, ATT, analytics, Crashlytics, and OpenRouter as a cross-border sub-processor | **An inaccurate privacy declaration is a removal risk, not a warning.** Complete `BLK-10` first so the declaration describes the real data model |
| `STORE-05` | ❌ | Account-deletion requirement compliance | Critical | S | 1 d | v0.9.9 / M3 | Legal | `settings_screen.dart` danger zone, `functions/account.js` | `BLK-12` | In-app deletion present (it is) **and** — per Apple's requirement — the deletion path is discoverable and complete; a web-based deletion request route provided if required | Apple rejects apps with account creation and no in-app deletion. The path exists; verify it is complete per `BLK-12` |
| `STORE-06` | ❌ | Health-app review considerations | High | M | 3 d | v0.9.9 / M3 | Legal / PM | onboarding, meal plan, AI outputs | `LEG-07` | Medical disclaimers present where required; no medical claims in copy or store listing; AI-generated nutrition advice framed as informational, not medical; age rating reflects health content | **An AI generating dietary guidance in a health app attracts elevated review scrutiny.** `BLK-01` shipping fabricated plans into this context would be severe |
| `STORE-07` | ❌ | Third-party licence and attribution audit | Medium | S | 1 d | v1.0.0 / M4 | Legal | `pubspec.yaml` (52 runtime dependencies), fonts (Poppins, Lexend), dish images | `RCP-06` | An in-app licences screen; font licences verified for commercial use; **every dish image's licence verified** (`dish_image_service` currently sources from LoremFlickr/Unsplash by keyword) | Stock-image sourcing by keyword in a commercial app is a licensing exposure |
| `STORE-08` | ❌ | Store review dry run | High | S | 2 d | v1.0.0 / M4 | QA Lead | — | `STORE-03`, `TEST-08` | A self-review against both platforms' guidelines, with reviewer notes and demo credentials prepared; the known-sensitive areas pre-empted (health data, UGC moderation, IAP, tracking) | First submissions get rejected on preventable process issues far more often than on code |

---

## §44 — Legal, Privacy, GDPR & KVKK

> `CLAUDE.md` opens with *"Legal-first is non-negotiable. Data security + KVKK/GDPR compliance are release
> blockers."* This section is the audit of whether that held. **Engineering largely delivered; legal-ops
> and two data-model gaps did not.**

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `LEG-01` | 🔥 | Minimize the world-readable user document | Critical | M | 3–5 d | v0.9.8 / M2 | DevSecOps / Legal | see `BLK-10` | — | Tracked in `BLK-10`. **The most serious privacy finding: email, IP address and device fingerprints readable by every authenticated user** | — |
| `LEG-02` | 🔥 | Complete erasure and export | Critical | M | 3–4 d | v0.9.8 / M2 | DevSecOps / Legal | see `BLK-12` | — | Tracked in `BLK-12` (Art. 17, Art. 20) | — |
| `LEG-03` | ✅ | Consent Center — versioned, timestamped, withdrawable, per-purpose, gates Analytics + Crashlytics collection (privacy-by-default OFF) | — | — | — | shipped | — | `consent_service.dart`, `consent_model.dart`, `consent_center_screen.dart`, `consent_prompt_sheet.dart` | `LEG-08` | Verified working — genuinely good compliance engineering. **Carried from `FUTURE_FEATURES` L2** | — |
| `LEG-04` | ✅ | Age gating before collecting DOB and body metrics | — | — | — | shipped | — | `lib/core/utils/age_gate.dart` | — | Verified present. **Carried from `FUTURE_FEATURES` L4.** Verify the minimum age matches both stores' and KVKK's requirements | Children's health data is the highest-risk category — confirm the threshold with counsel |
| `LEG-05` | ❌ | Data-retention policy and TTL enforcement | High | M | 3 d | v0.9.8 / M2 | Legal / Backend | `ai_usage_logs`, `admin_audit`, `login_devices[]`, `last_login_ip`, `failed_login_attempts`, `reports`, chat history | `BLK-10`, `BLK-12` | A written retention period per data category, implemented as a scheduled deletion or anonymisation job; documented in the privacy policy and `docs/COMPLIANCE.md`. **No retention policy or TTL job exists — telemetry and AI logs accumulate indefinitely** | Indefinite retention of IP addresses and AI request logs is a direct GDPR/KVKK finding |
| `LEG-06` | 📋 | Processor DPAs and VERBİS assessment | Critical | M | 2–3 w (external) | v0.9.8 / M2 | Legal (external) | `docs/COMPLIANCE.md` | — | DPAs executed with **OpenRouter** (cross-border AI sub-processor), Google/Firebase, and any other processor; the cross-border transfer register completed; VERBİS registration assessed and filed if required. **Carried from `FUTURE_FEATURES` L5 — "ENGINEERING DONE (legal-ops open)"** | Consent for cross-border transfer is recorded in-app, but the **legal instrument permitting the transfer does not exist**. This is a launch blocker for the Turkish market |
| `LEG-07` | 📋 | Qualified-lawyer review of all legal documents | Critical | M | 2–3 w (external) | v0.9.9 / M3 | Legal (external) | `assets/legal/`, `legal_screen.dart` | `LEG-06` | Privacy policy, terms of use, coach/marketplace terms, medical disclaimer and cookie/tracking disclosure reviewed by a qualified lawyer in both EN and TR. **Carried from `FUTURE_FEATURES` L1: "DRAFTED (pending lawyer review)" and L7: "DRAFTED"** | Shipping self-drafted legal documents for a health app processing special-category data in a KVKK jurisdiction is the highest-severity legal risk in this backlog |
| `LEG-08` | ❌ | Point-of-use consent for AI and photo processing | High | M | 3 d | v0.9.8 / M2 | Legal / Flutter | `consent_service.dart` (recorded at registration), `food_scan_screen.dart`, AI entry points | `LEG-03` | Before health data or a meal photo first leaves the device, a point-of-use disclosure names the recipient (OpenRouter), the purpose, and the cross-border transfer; consent recorded per purpose and withdrawable. **Carried from `GO_LIVE.md` S8 and the prior deferred list** | Bundling AI consent into registration is weaker than GDPR Art. 9 explicit consent requires for health data |
| `LEG-09` | ✅ | DSAR channel (data subject requests) | — | — | — | shipped | — | `privacy_request_service.dart`, `privacy_request_screen.dart`, `admin_privacy_requests_screen.dart` | `BLK-05` | Verified present. **Carried from `FUTURE_FEATURES` L3.** The admin side is unreachable until `BLK-05`, so requests cannot currently be actioned | A DSAR channel that collects requests nobody can action is worse than none — it creates a documented failure to respond within the statutory window |
| `LEG-10` | ✅ | Breach response runbook (document) | — | — | — | shipped | — | `docs/` | `DOC-03` | Verified present. **Carried from `FUTURE_FEATURES` L6.** Never rehearsed | An unrehearsed runbook fails under the 72-hour notification clock |
| `LEG-11` | ✅ | GDPR data export (`DataExportService`) | — | — | — | shipped | — | `data_export_service.dart` | `BLK-12` | Verified present but **incomplete** — see `BLK-12` (wrong chat-image prefix, missing subcollections, no Storage manifest) | An incomplete export is an Art. 20 failure |
| `LEG-12` | ❌ | Sub-processor register and transparency | Medium | S | 1 d | v0.9.8 / M2 | Legal | `docs/COMPLIANCE.md`, privacy policy | `LEG-06` | Every sub-processor listed publicly (Google/Firebase, OpenRouter, Cloud Vision, Apple/Google billing, Open Food Facts, OpenStreetMap tiles, Nominatim geocoding) with purpose and location | Several third-party services receive user-derived data; users cannot currently see who |
| `LEG-13` | ❌ | Legal-compliance checklist as a PR gate | Medium | XS | 2 h | v0.9.8 / M2 | Legal | PR template, `AGENTS.md` §2 | `DOC-05` | Any change touching personal data must state: what is collected, why, where it is stored, retention, consent basis, and whether the privacy policy needs updating. **`AGENTS.md` §2 already defines this checklist — make it a mechanical gate** | The checklist exists and was not applied to the user-doc or telemetry fields — a mechanism is needed, not another rule |

---

## §45 — Disaster Recovery

| ID | Status | Title | Priority | Cx | Est | Version | Owner | Files | Deps | Acceptance / DoD | Risks |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `DR-01` | ❌ | 🔥 Scheduled Firestore backups | Critical | S | 1 d | v0.9.7 / M1 | DevOps | GCP console, `firebase.json` | `INF-01` | Daily scheduled export to a dedicated GCS bucket with lifecycle rules and a documented retention window; Storage bucket versioning enabled; the backup bucket's access restricted. **`GO_LIVE.md` §5.5 is unchecked — no backup exists** | A single mistaken batch delete or a bad migration is currently **unrecoverable**. This is the highest-consequence gap in §45 |
| `DR-02` | ❌ | 🔥 Rehearsed restore | Critical | S | 1 d | v0.9.7 / M1 | DevOps | `docs/` runbook | `DR-01`, `INF-01` | A real restore performed into the staging project and verified; RPO and RTO measured and documented. **An untested backup is not a backup** | Restore procedures fail on first attempt far more often than not |
| `DR-03` | ❌ | Incident response plan | High | S | 2 d | v0.9.8 / M2 | DevOps / Legal | `docs/`, `LEG-10` breach runbook | `OBS-01`, `DOC-03` | Severity levels, on-call expectations for a solo team, communication templates (in-app announcement via `app_config`, store listing note, email), post-incident review template; integrated with the breach runbook | A solo maintainer with no plan improvises during the worst possible hour |
| `DR-04` | ❌ | Key and credential recovery plan | High | S | 1 d | v0.9.9 / M3 | DevOps | Android upload keystore, Apple certificates, Function secrets | `BLK-16` | Every credential backed up in two independent secure locations with documented recovery steps. **Losing the Android upload keystore permanently blocks Play updates** — this is unrecoverable, not merely inconvenient | Single-maintainer projects lose keys. Play App Signing mitigates the keystore risk — enrol (`BLK-16`) |
| `DR-05` | ❌ | Bus-factor mitigation | High | M | ongoing | v1.0.0 / M4 | CTO | `docs/`, `DOC-03` | Every operational task documented well enough for a competent stranger to execute; credentials accessible to at least one other trusted party; the architecture documented accurately (`DOC-01`). **One person holds all context for 115k LOC, 486 KB of partly-inaccurate documentation, and every credential** | — | Identified as a 🟡 risk in the prior roadmap; it is now a 🔴 risk because the operational surface has grown while documentation accuracy has fallen |

---

## §46 — Technical Debt Register

**49 items** (6 resolved this pass — `DEBT-19`, `DEBT-20`, `DEBT-51`, `DEBT-02`, `DEBT-03`, `DEBT-08`,
moved to §46.5). Critical 5 · High 12 · Medium 18 · Low 14.
Remediation: critical + high ≈ **10–12 engineer-weeks**; complete register ≈ **28–34 engineer-weeks**.

### 46.1 🔴 Critical

| ID | Debt | Why it exists | Risk | Impact | Fix | Effort | Tracked as |
|---|---|---|---|---|---|---|---|
| `DEBT-01` | Swallow-and-log error handling (25 bare catches + dozens of log-and-default) | Speed over observability; `debugPrint` felt like logging | **Root cause of `DEBT-04`–`DEBT-06` remaining invisible** (was also root cause of `DEBT-02`, closed with `BLK-01`). `debugPrint` is a release no-op → zero production signal | Features die silently; nobody can state what works | Route every catch to Crashlytics with context; ban bare catches via CI grep; permission-denied renders an error state, not empty | 1 w | `ARCH-01`, `OBS-03` |
| `DEBT-04` | Push fan-out path mismatch; admin path unruled | Trigger written against a documented path the client never adopted | No social push; gym/coach approval batches fail | Retention loop and both ecosystems dead | Pick one path, add the rule, move authorship server-side | 2–3 d | `BLK-03` |
| `DEBT-05` | Admin surface unreachable (`admin_roles` created by nothing) | Rule written before the provisioning path | ~7,400 LOC unusable; no moderation, approvals or cost visibility | No operational capability | `syncAdminClaim` written, custom-claim gating wired, runbook documented — **awaiting deploy**, see `BLK-05` | 1–2 d | `BLK-05` |
| `DEBT-06` | Monetization non-functional end to end | Store setup never started; validation correctly fails closed | Zero revenue | No business | Register products, add credentials, `APP_ENV=production`, sandbox-verify | 1–2 w + store | `BLK-04` |
| `DEBT-07` | All 18 of the project's own security gates unchecked | `GO_LIVE.md` §5S written but never worked | Unknown-unknowns across the whole surface | Compounds every other item | Work `S0`–`S17` in order; make the rules suite pass in CI | 3–4 w | §3 |

### 46.2 🟠 High

| ID | Debt | Risk | Fix | Effort | Tracked as |
|---|---|---|---|---|---|
| `DEBT-09` | Gym logo writes to an unruled Storage prefix; scanner watches the same wrong prefix | Gym setup broken; NSFW scanning misaligned | Align upload, rules and `SCAN_PREFIXES`; close the `isAuthenticated()` hole | 4 h | `BLK-07` |
| `DEBT-10` | Any user can mutate any post's non-content fields | Like-count, `groupId`, `is_announcement` integrity | `hasOnly` + delta constraints, or server-maintained counters | 1 d | `BLK-08` |
| `DEBT-11` | **Challenge sunset incomplete while marked ✅** | `firestore.rules:296-304`, 2 composite indexes and 4 orphan i18n keys survive; `intro.page3_title` still advertises "Community & Challenges" to users | Remove the rules block, both indexes and the orphan keys; reword the intro copy | 1 h | `CHL-00`, `FB-15`, `I18N-02` |
| `DEBT-12` | Marketplace injection via `coach_uid == 'demo'` | Any user publishes to a public storefront | Remove the exemption; seed server-side | 4 h | `BLK-09` |
| `DEBT-13` | User doc world-readable with email, IP, device fingerprints | GDPR/KVKK exposure in the primary market | Split public/private/internal; migrate; narrow the rule | 3–5 d | `BLK-10` |
| `DEBT-14` | Three overlapping config systems, one permanently denied | Unclear precedence on safety levers; `ai_proxy_url` resolvable from two places (and `BLK-01` makes that dangerous) | Consolidate on `AppConfigService`; delete the dead paths | 3 d | `ARCH-05` |
| `DEBT-15` | Dish catalog unseedable in-app; 75 dishes; 180-dish prompt ceiling | Core feature has no content on a fresh project; visible repetition; growth blocked | Server-side seeding; `AI-03` pre-filter; expand to ≥ 300 | 1 w + content | `BLK-11`, `AI-03` |
| `DEBT-16` | GDPR erasure and export incomplete | Residual personal data after a deletion request | Fix the chat-image enumeration; purge `ai_usage_logs`; clean cross-user artefacts | 3–4 d | `BLK-12` |
| `DEBT-17` | Non-AI premium gated client-side only | Paywall bypassable in a repackaged build | Enforce server-side at the cost boundary; publish an enforcement inventory | 1 w | `SEC-16` |
| `DEBT-18` | AI proxy timeout mismatch (30 s server / 90 s client) | Retries stack onto server-killed requests, burning quota | Align both to 60 s | 1 h | `BE-02` |
| `DEBT-21` | `usesCleartextTraffic="true"` in the release manifest | MITM exposure app-wide | Set `false`; verify every network path is HTTPS | 2 h | `SEC-17` |
| `DEBT-22` | Streak and reputation client-written | Leaderboards, achievements and reputation tiers trivially gameable | Move to Functions; add to the protected-field list; reconcile existing values | 1 w | `SEC-14` |

### 46.3 🟡 Medium

| ID | Debt | Risk | Fix | Effort | Tracked as |
|---|---|---|---|---|---|
| `DEBT-23` | No release obfuscation or symbol upload | Dart code readable in shipped binaries; obfuscated crashes undebuggable | `--obfuscate --split-debug-info`; upload symbols | 1 d | `SEC-18`, `FB-22` |
| `DEBT-24` | God objects — 40 files > 800 LOC, 65 > 500 | Unrefactorable; large rebuild scope; blocks a second engineer | Split the top 5 (12,177 LOC) after `TEST-03` | 2–3 w | `ARCH-02` |
| `DEBT-25` | Abandoned repository layer (4 vs 81 services) | Ceremony without benefit; documentation claims a layer that is not there | Commit for the ~15 logic-bearing services; delete elsewhere; write an ADR | 1 w | `ARCH-03` |
| `DEBT-26` | No DI, no interfaces | Root cause of ~1 % test coverage | `get_it` + interfaces for the ~15 services worth testing, with a compatibility shim | 2 w | `ARCH-04` |
| `DEBT-27` | ~10 N+1 loops across 8 services | Read cost; partial-failure orphans on cascades | Batch with `whereIn`; move cascades to Functions | 1 w | `PERF-03`, `COM-05` |
| `DEBT-28` | Unbounded `dishes` `.get()` and `.snapshots()` | Linear read growth per plan generation; violates the repo's own playbook | `.limit()`, filtered queries, pagination | 1 d | `FB-17` |
| `DEBT-29` | Accessibility at 32 sites across 329 files, claimed shipped | Compliance exposure for a health app; unusable with a screen reader | Screen-reader pass on 10 flows; contrast; touch targets; reduced-motion | 2–3 w | `A11Y-01`–`A11Y-05` |
| `DEBT-30` | 87 raw `CircularProgressIndicator`, 5 in `route_guard.dart` | Violates the project's own most-stated design rule, on the navigation hot path | Replace with DS skeletons; CI grep | 1 w | `UI-02`, `ONB-07` |
| `DEBT-31` | 334 hardcoded colours in `lib/screens` | Dark mode very likely broken on gym, programs and error surfaces | Migrate to `AppPalette`; verify both themes on every screen | 1–2 w | `UI-03`, `UI-04` |
| `DEBT-32` | Documentation asserts non-existent features | Prevents discovery of gaps; misleads future engineers and AI-assisted work | Reconcile every claim; rewrite the README; retire superseded roadmaps | 2 d | `DOC-01`, `DOC-02`, `DOC-07` |
| `DEBT-33` | Triplicated HTTP logic in `ai_service.dart` (~120 lines) | A fix to one branch silently misses the other two — in the most security-sensitive file | Extract one `_post()` helper | 1 d | `ARCH-12` |
| `DEBT-34` | Prompts fragmented across 5 files (4 guarded, 13 not) | The injection guard covers 4 of 17 prompts | Consolidate into `PromptService`; add versioning | 1 w | `AI-09`, `SEC-11` |
| `DEBT-35` | Cron notifiers and broadcast audience capped at 500 users | Silently breaks at 500 active users; 83 % of a 3,000-DAU base gets no reminders | Cloud Tasks fan-out with pagination | 3 d | `INF-06` |
| `DEBT-36` | Functions on the v1 API | Missing concurrency controls and modern runtime features | Migrate to v2 per function with verification | 1 w | `ARCH-10` |
| `DEBT-37` | `functions/index.js` is 980 LOC of mixed concerns | Hard to review; a bad edit can silently un-deploy a trigger | Split into `ai.js`, `push.js`, `broadcasts.js`, `cron.js` | 2 d | `ARCH-09` |
| `DEBT-38` | No semantic validation of AI output | A hallucinated or arithmetically wrong plan is displayed as fact in a health app | Cross-check macros against the catalog; reject or recompute | 3 d | `AI-06` |
| `DEBT-39` | `.env` bundled as an asset; debug APK with a live key uploaded as a CI artifact | Key extraction; denial-of-wallet | Remove from assets; `--dart-define`; stop the artifact upload; rotate | 1 d | `BLK-15` |
| `DEBT-40` | `MODEL_PRICING` covers 3 models; unlisted models cost 0 | Cost reporting silently under-reports to zero | Externalise to `app_config`; alert on `unpriced` | 1 d | `AI-12` |

### 46.4 🟢 Low

| ID | Debt | Fix | Effort | Tracked as |
|---|---|---|---|---|
| `DEBT-41` | `uuid: any` unbounded version constraint | Pin it | 1 h | `SEC-28` |
| `DEBT-42` | `dependency_overrides` block undocumented (`analyzer` pinned to 6.4.1, 4 transitive bumps) | Document the reason or remove | 2 h | `SEC-28` |
| `DEBT-43` | Dead `flutter_native_splash` config (25 lines; package not installed) | Add the package or delete the config | 1 h | `UI-10` |
| `DEBT-44` | Dead `challenges` rules + 2 indexes | Remove | 1 h | `CHL-00` |
| `DEBT-45` | `posts` indexed on `createdAt`, `created_at` **and** `timestamp` | Pick one; migrate; delete two indexes | 1 d | `ARCH-11` |
| `DEBT-46` | `analytics_cache` Hive box unencrypted while the other 7 are AES-256 | Open with the same cipher; migrate | 2 h | `SEC-19` |
| `DEBT-47` | `CACHE_SIZE_UNLIMITED` on mobile | Bound it after measuring | 1 h | `ARCH-08` |
| `DEBT-48` | `AdminStatusService._cachedBanStatus` never invalidated | TTL or replace with the live listener | 2 h | `SEC-03` |
| `DEBT-49` | `BillingService.dispose()` disposes a singleton's `ValueNotifier`; `purchase()` throws `StateError` against its documented contract | Make the singleton dispose-safe; return `false` as documented | 1 h | `BLK-04` |
| `DEBT-50` | 25 analyzer `info` hints (redundant arguments, missing braces) | Clean up | 2 h | `CI-01` |
| `DEBT-52` | `lib/firebase_options.dart` gitignored → a fresh clone cannot build without the CI placeholder hack | Generation step documented (`docs/DEVOPS.md` §4: `flutterfire configure`). **The CI placeholder itself was worse than documented** — it was a bare comment, not valid Dart, which broke `flutter analyze` outright (`CI-11`); now a real minimal `DefaultFirebaseOptions` stub in both `ci.yml` jobs. Still open: file stays gitignored by choice, so a device build straight from CI's config still can't reach a real Firebase project | 2 h remaining | `BLK-13`, `CI-11` |
| `DEBT-53` | Splash hard-codes a 1,500 ms delay plus sequential controller waits | Measure, then make startup work-bound | 2 h | `PERF-14` |
| `DEBT-54` | Orphaned `priority_onboarding_screen` (387 LOC) still registered as a route **and** counted as an auth route in `RouteGuard` | Delete the screen, route constant, registration and `_isAuthRoute` entry | 2 h | `ONB-09` |
| `DEBT-55` | Test mode is a SharedPrefs boolean with no build-mode guard; intercepts meal plans, food logs, shopping, dishes, gyms, coaches and admin users; `TestDataLibrary` is 1,073 LOC shipped in release | Hard-gate on `kDebugMode`; move `TestDataLibrary` to `test/` or tree-shake it | 2 h | `SET-04` |

### 46.5 Historical debt — resolved (preserved from the prior register)

Recorded so the history is not lost. All verified fixed.

| Severity | Debt | Resolved in |
|---|---|---|
| 🔴 | No version-controlled Firestore/Storage rules | B1 + Phase 3 |
| 🔴 | AI key placeholder; key belongs server-side | Phase 1 security (Cloud Function proxy) |
| 🔴 | Dashboard "consumed calories" hardcoded to `1350` | B3 real-time food-log stream |
| 🔴 | Fake image upload (random Unsplash stock images) | B4 Firebase Storage |
| 🟠 | Triple `FlutterError.onError` collision; error boundary unwired | Phase 1 error handling |
| 🟠 | `AppLifecycleService` double-observer | Phase 1 architecture |
| 🟠 | Fragile AI JSON parsing (unguarded casts, swallowed failures) | B9 typed exceptions + 3 retries |
| 🟠 | `BanCheckObserver` Firestore read on every navigation | Phase 1 (`forceRefresh: false`) |
| 🟡 | Dead code: `WeightLog` model; duplicate provider factory | Phase 1 |
| 🟡 | Dark mode hardcoded light backgrounds | B11 + Phase 3.5 |
| 🟡 | `performance_service.dart` dead code; no real perf backend | Phase 1 (Firebase Performance) |
| 🟡 | Translations loaded from `lib/` (non-standard asset path) | v0.9.5 (moved to `assets/localization/`) |
| 🟡 | No pagination on the community feed | Phase 3 (`startAfter` cursor) |
| 🟠 | `test/` gitignored; 3 test files and the whole rules suite untracked (`DEBT-19`) | `BLK-13` — 14 files tracked, rules suite green in CI ([run #40](https://github.com/burcok/cookrange/actions/runs/30667024406)) |
| 🟠 | CI red on `main` — format + 3 failing tests (`DEBT-20`) | `BLK-13` — `dart format` clean, mock signature fixed, 78/78 tests pass. Branch protection and pre-commit hooks were listed alongside this debt but are separate, still-open items — tracked as `CI-02`, `CI-08` |
| 🟢 | `pubspec.lock` gitignored but grandfathered into tracking (`DEBT-51`) | `BLK-13` — ignore rule removed, intent matches reality |
| 🔴 | Release AI served fabricated meal plans and recipes (`DEBT-02`) | `BLK-01` — mock block deleted, both services guard `isConfigured` and rethrow, branded error states wired in `home.dart`/`explore_screen.dart`, startup Crashlytics assertion added, regression test added |
| 🔴 | iOS photo-library permission missing — crash on 6 screens (`DEBT-03`) | `BLK-02` — `NSPhotoLibraryUsageDescription` added, 3 of 6 gallery call sites given the `PermissionService` priming they were missing, permanent preflight guard (`scripts/check_ios_permissions.sh`) in CI. Physical-device confirmation and `flutter build ipa` still owed once a signing identity exists (`BLK-16`) |
| 🟠 | `meal_plan_history` has an index but no rule — feature permanently empty (`DEBT-08`) | `BLK-06` — owner rule added, tested (CI's `firestore-rules` job, [run #50](https://github.com/burcok/cookrange/actions/runs/30697804480)), and **deployed to production** with explicit user go-ahead. Both call sites and two adjacent screen-layer catches now report to `CrashlyticsService` |
| 🟡 | No pagination on notifications | v0.9.6 (`getNotificationsPage`) |
| 🟢 | Stray `print()` calls throughout `lib/` (12 files) | v0.9.5 (`debugPrint`) |
| 🟢 | Dead legacy widgets (`custom_back_button`, `gender_picker_modal`, `language_selector`) | v0.9.5 (deleted) |
| 🟢 | Stale `test_output.txt`; misplaced `*_test.dart` in `lib/` | Phase 1 |
| 🟢 | Non-localized signal dialog presets | Confirmed already localized via `translate(preset)` |
| 🟠 | Flutter 3.44 build breakage (iOS arm64 simulator, Kotlin 1.9→2.2.20, AGP→8.11.1, Gradle→8.14.1, compileSdk/targetSdk→36, NDK→28, core-library desugaring, built-in Kotlin plugin, JDK path, Firebase BoM→33.15.0, `mobile_scanner` 5→7) | 2026-06-27 build-system pass |

---

## §47 — Completed Archive

> Full delivery history. Preserved so the record of what was built, when, and why is not lost when the
> forward-looking backlog changes. **Status markers here are the historical claims**; where this audit
> found a claim to be false, the correction is noted inline.

### 47.1 MVP blockers B1–B13 — all closed

| # | Blocker | Implemented in |
|---|---|---|
| B1 | Firestore + Storage security rules | `firestore.rules`, `storage.rules`, `firebase.json`, `firestore.indexes.json` |
| B2 | Real AI key management (client-side guard) | `ai_service.dart` `isConfigured` + placeholder detection — **note: this guard is the mechanism `BLK-01` exploits** |
| B3 | Food/calorie logging (real consumed calories) | `food_log_model.dart`, `food_log_service.dart`, `home.dart` stream |
| B4 | Image upload via Firebase Storage | `storage_upload_service.dart`, `create_post_card.dart`, avatar |
| B5 | Push notifications (FCM + local) | `push_notification_service.dart` — **note: FCM fan-out is broken (`BLK-03`); local notifications work** |
| B6 | Account deletion + data purge | Settings danger zone, `auth_service.deleteAccount`, later `functions/account.js` — **incomplete (`BLK-12`)** |
| B7 | Apple Sign-In | `auth_service.signInWithApple`, iOS-guarded buttons |
| B8 | Profile edit persistence | `profile_screen._pickAndUploadAvatar` |
| B9 | AI robustness (retries + JSON validation) | Typed exceptions + 3 retries + null-safe parse |
| B10 | Community feed pagination | `community_service.fetchPostsPage` |
| B11 | Dark-mode correctness | `main_scaffold.dart` dynamic background |
| B12 | Legal: Privacy Policy + Terms | `legal_screen.dart` — **drafts pending lawyer review (`LEG-07`)** |
| B13 | CI pipeline | `.github/workflows/ci.yml` — **all 4 jobs confirmed green in real CI**, first time ever. `BLK-13` + `CI-11` + `CI-12` all closed |

### 47.2 Phase-by-phase delivery record

**Phase 1 — Foundation (v0.5–v0.6).** Repository layer (3 repos, `home.dart` migrated, test-mode
centralized) · duplicate provider factory removed · `AppLifecycleService` double-observer fixed · dead
`WeightLog` deleted · Apple Sign-In · change email/password in Settings · `BanCheckObserver` read
reduction · `firebase.json` + `.firebaserc` · security rules · Storage dependency + upload service ·
Firebase Remote Config replacing the faux `settings/global` config · navigation dead-code hacks removed ·
`ShoppingRepository` · `NavigationProvider` relocated · offline scope decided (Firestore persistence;
dead `OfflineModeScreen` scaffolding removed) · explicit persistence settings · triple
`FlutterError.onError` collision fixed (`GlobalErrorHandler` sole owner) · error boundary wired into
`MaterialApp.builder` · analytics funnel events added · analytics debug-disabled/release-enabled ·
Firebase Performance (HttpMetric on AI, meal-plan traces) · Crashlytics custom keys · menu-lag fix
(`Selector` per section, accumulating `addPostFrameCallback` removed) · 36 unit + 48 widget tests ·
GitHub Actions CI · TestFlight/Play deploy workflow + `ExportOptions.plist` · AI key behind a Cloud
Function proxy · Firebase console API-key restriction checklist (`docs/firebase-console-setup.md`) ·
App Check with playIntegrity/deviceCheck/debug.

**Phase 2 — Core product (v0.6–v0.7).** `priority_onboarding_screen` stub replaced with a real 2-step
quick setup · allergy/medical safety step · typed `UserNutritionProfile` promoted out of the untyped
`onboardingData` map · profile edit + avatar upload · real post counts via `count()` · AI JSON schema
enforcement + retry · per-meal swap · dish DB auto-seed · deterministic dish imagery · **food/calorie
diary** · weight logging UI + 7-day chart · hydration UI · mark-meal-as-eaten → diary · nutrition
analytics · conversational AI chat · food photo/scan analysis · voice transcript → AI assistant ·
shopping list auto-generation + clipboard share + Firestore sync · Test Mode + `TestDataLibrary` ·
cooking-mode completion + celebration · streak + goal-met surfacing · `subscriptionTier`/entitlements ·
feature-gating framework + paywall · `in_app_purchase` `BillingService`.

**Phase 3 — Community (v0.7–v0.8).** Real image upload · comment pagination + real-time stream ·
like/reaction notification fan-out · feed pagination · functional feed filters (Global / Friends /
Gym) · real reports collection + block list + reason pickers · group chat creation · chat image
messages · live notification stream · notification screen transition + icon-colour fix · **challenges
(created — later sunset in 13.2)** · streak milestones + tier badges · leaderboards · reputation system ·
recursive post-delete cleanup · `getFriendsStream` N+1 fix (chunked `whereIn`).

**Phase 3.5 — Design system & full UI overhaul (v0.9).** Design tokens (`AppSpacing`/`AppRadius`/
`AppSize`/`AppElevation`/`AppMotion`) · typography scale (`AppText`) · semantic colour system
(`AppPalette`) · gradient + glassmorphism kit ("Sunset Energy": `#FF8A3D→#F97300→#FF4E50` + electric
teal `energy` accent) · `AppButton` · `AppCard`/`AppGlassCard` · `AppShimmer`/skeletons ·
`AppEmptyState`/`AppErrorState` · `AppSheet` · `AppCalorieRing` · `AppSegmentedControl`/`AppChipPicker`/
`AppToggle` · `AppTextField` · `AppSnackBar` · `AppTransitions` · **full screen re-skin** (splash,
onboarding ×9, auth ×4, home, meal plan + recipe + cooking mode, food scan + analytics, community ×7,
chat ×6, profile + settings + legal, shopping, challenges + leaderboard, notifications + explore) · UI
fix batch v0.9.1 (meal-plan overflow, meal-card redesign, weight entry → sheet, settings dialogs →
sheets, challenges redesign) · DS wiring batch v0.9.2 · navigation & quick-actions overhaul v0.9.5.

**Phase 4 — Gym ecosystem (v1.1–v1.4).** Role system (`UserRole` enum, role-aware side menu + quick
bar) · gym profile setup (3-step) · member management · owner dashboard + 7-day attendance chart · gym
communities (feed + pinned announcements) · QR + GPS check-in (Haversine geofence) · gym leaderboards +
Gym Wars (dual-query active wars, `AggregateQuery.count` scoring) · gym analytics (retention heatmap,
engagement score, at-risk alerts, top performers, CSV export) · white-label brand colour + logo · gym
data model · gym discovery (debounced search, cursor pagination). **Access gap discovered 2026-06-28:
every screen built and unreachable — fixed in Phase 10.2.**

**Phase 5 — Coach ecosystem (v1.4–v1.6).** Coach profiles + vanity referral codes · client management
with at-risk detection · coach dashboard · AI client reports · commission tracking layer. **Same access
gap as Phase 4 — fixed in Phase 10.2.**

**Phase 6 — AI intelligence (v1.7–v2.0).** AI Fitness Twin (30/60/90-day projections, goal-date
estimate, calorie gap, motivation score) · AI Accountability Partner (cached daily insight) · AI risk
detection (client-side, zero cost) · transformation forecasting · AI coach assistant · behavioural
analytics deferred pending real data.

**Phase 7 — Monetization.** Premium subscription · AI credit system (monthly → later daily) · program
marketplace · sponsored challenges (**later removed with the sunset**) · affiliate/referral commission
tracking · partner brands deferred · coach revenue-share tracking.

**Phase 8 — Growth.** Referral program · invite deep links · social sharing · shareable fitness-score
card · community growth loops · App Links + Universal Links.

**Phase 9 — Scale & launch readiness.** Performance (`RepaintBoundary` sweep) · caching decision ·
9 composite indexes · security hardening · load-test script · monitoring wiring · i18n decision +
language picker · DS-level accessibility semantics · GDPR export · ATT consent · tech-debt cleanup.

**Phase 9.6 — Privacy, notifications, navigation (v0.9.6).** Private-account enforcement + PII moved to
`users/{uid}/private/nutrition` · **structured notifications + `NotificationPresenter`** (no more
pre-rendered text; removed brittle `title.contains("Su")` string-matching) · universal tap-to-profile ·
side-menu localization + dead-item removal.

**Phase 9.7 — Consumer polish (v1.0.x–v1.1).** Favourites · meal-plan history (**rule missing —
`BLK-06`**) · barcode scanning · quick-add recent/frequent · global user search · notification
preferences · exercise log with MET burn · streak freeze · recipe filters · meal-type breakdown ·
dietary refinement · profile as a real bottom tab (`IndexedStack` + glass floating nav) · meal-plan
comparison · recipe notes · challenge difficulty tiers (**later removed**) · calendar `.ics` export ·
hard server-side private-profile enforcement.

**Phase 10 — Activation & access (v1.0.x–v1.1).** Navigation reachability audit · role-upgrade on-ramps
(fixing the gym/coach chicken-and-egg dead ends) · consumer gym discovery · gym member home · coach
directory · unified Discover hub · role-aware home card · stale `comingSoon` flags removed ·
just-in-time permission priming (`PermissionPrimer` + `PermissionService`, camera/location/notification/
photos, denied + permanentlyDenied states) · feature-tour intro onboarding · coachmarks · What's New ·
empty-state CTAs · gym QR join prompt for non-members · profile completeness meter · demo/seed content ·
activation analytics · accessibility & reduced motion on new surfaces.

**Phase 11 — Verification & admin pipeline.** AI Twin history + language-aware AI · test-mode full
coverage (gyms/coaches/programs/challenges) · role-aware labels · ₺ currency sweep · persistent coach
requests · coach + gym approval pipeline (models, services, 3-step application, pending/rejected states,
dashboard gates) · admin applications review panel.

**Phase 12 — AI economy, localization integrity, role navigation.** *(Opened by recovering a
parallel-agent write collision that silently lost the AI-Twin localization work — the origin of rule
R9.)* Centralized language directive in every prompt · locale params + locale-tagged caches · Twin
persistence + load-saved-first + history UI · **monthly → daily credit model (free 2/day, premium
20/day)** · quota on new generations only · consistent gating across all AI paths · optimistic decrement
+ rollback · server-side quota enforcement · tappable credit badge → `AiCreditsSheet` · consumable
top-up plumbing · admin + coach navigation parity · pending-state-aware labels · live role refresh ·
admin operations suite (user management, application history, audit log, reports queue, dashboard) ·
**i18n parity CI gate** · shared-file parallel-write guard (R9) · 4 new indexes · AI state polish ·
analytics funnel events · currency consistency.

**Phase 13 — Consumer polish, glassmorphism v2, marketplace discovery, challenge sunset (2026-06-28).**
Six root-caused defects fixed (intro reachability, profile photo, completeness correctness, meal-plan
action re-surfacing, discover back button) · **challenge sunset — incomplete, see `DEBT-11`** ·
glassmorphism v2 (glass tokens + blur constants + high-contrast/reduce-transparency path + whole-app
re-skin + `RepaintBoundary` sweep) · context-aware skeletons · marketplace discovery 2.0 (81 provinces +
full district dataset, coach reviews with transactional aggregates, city/district filters, competitive
coach directory, 7 new indexes) · admin panel polish + audit-log viewer + localization · "gyms near me"
map discovery with KVKK consent · coach Rising Stars + trust badges · verified-reviews anti-fraud gate ·
**Streak Squads** (replacing the challenge social hook) · `TodaySummaryCard` · personalized intro CTAs ·
coach/gym share cards · server-side AI quota enforcement.

**Phase 13 (second pass) — QA fixes & feature upgrades (2026-06-30).** Self-profile-as-stranger ·
weight-save dismissing the profile · My Programs infinite spinner (missing index + swallowed stream
error + dead retry) · barcode scanner silent black screen → explicit states + manual entry · water
reminder defaults ON · AI credit metering on food analysis · food analysis v2 (photo/vision, health
score, micros, allergens, confidence, portion stepper, history) · Foods & Nutrition hub · shared
`AppFilterBar` across all four discovery surfaces · shopping list source-meal attribution · admin users
list + search fixes + per-user notification send · **Community Groups P1 MVP**.

**Phase 14 — Onboarding recovery, engagement, admin console, marketplace depth.** `intro_seen` moved to
Firestore · `OnboardingFlowResolver` single source of truth · per-step completeness map + gap recovery ·
meal-plan generation finale · **push notifications end-to-end (fan-out triggers, tap-routing, cold-start
drain, token hygiene, preferences surface) — the fan-out path is wrong, see `BLK-03`** · admin broadcast
composer + scheduling + audience resolution · billion-dollar admin console (feature-flag editor, AI
credit admin, maintenance/min-version control, referral oversight, analytics tab, content moderation at
scale, program approval, dish DB management, verification badges, billing oversight, support tools, abuse
monitoring) · chat dark-theme + stub fixes · label-on-top filter pills · program content viewable after
enrollment + My Programs + sample seed + clean paid seam · avatar integrity (`AppInitialsAvatar`, no
random faces) · community auto-pagination · community strategic roadmap (structured post types, rich
composer, save/bookmark, follow, mentions, topic feeds, coach/gym presence, weekly highlights,
moderation-first) · "coming soon" inventory resolved.

**Phase 15 — Daily engagement loop & gamification (2026-06-30).** Smart re-engagement notifications
(3 new types, `reminders` mute group, meal reminder scheduling, 2 cron producers, presenter cases) ·
daily "Bugün" recap card (**status disputed — see `HOME-05`**) · one-tap photo food logging ·
weekly AI coach recap (idempotent per week+locale, low-data free) · streak-freeze UI + **11-badge
achievement system** · "Pişirdim / I Cooked This" community share.

**Phase 16 — Remote config, AI cost metering, AI reliability (2026-07-01).** Remote app config
(`app_config/global` driving client **and** `aiProxy`: model, tokens, quotas, version gate, maintenance,
announcements, kill-switches, rollout, limits — editable without a redeploy) · **real AI cost tracking**
(token usage × per-model price → `ai_usage_logs` + `ai_usage_stats` + per-user lifetime; every call
type-tagged) · AI reliability (default model → `openai/gpt-4o-mini` after the DeepSeek free slug 404'd;
timeout 45→90 s; `MAX_OUTPUT_TOKENS` 1024→8192; server-decided model; public-invoker) · meal-plan
generation fixes (**killed the RouteGuard regeneration loop** — root cause: a stale `AuthService` cache
reverted the flag via `UserProvider._fetchAndMerge`; fixed with the `mealPlanGatePassed` session-static +
`invalidateUserCache()`) · data completeness (`verifyAndRepairUserData`, `syncDeviceContext`) ·
**content moderation fixed** (blocked-keyword list mirrored to public-read `settings/content_filter`;
the filter had been reading an admin-only doc and failing open for normal users) · localization sweep
(~120 hardcoded strings across ~35 files).

### 47.3 Security hardening pass (2026-06-30) — delivered

Server-authoritative AI proxy + credit/entitlement ledger · native-store purchase validation ·
server-side referral/commission/payout logic · field-locked Firestore rules · App Check release providers
· Hive AES-256 encryption · null-safe parsing + content-length caps · prompt-injection guard +
deterministic allergen filter · server-side account erasure + GDPR export · analytics consent-gating +
email removal · `APP_ENV` gating · Functions + rules deployed to `cookrange-app` (claimed 10/12 —
unverified).

### 47.4 Deployment notes worth keeping

- `firebase deploy --only functions,firestore:rules,firestore:indexes` — **cross-region Function deploys are flaky**: "failed to update" often lands asynchronously, and back-to-back deploys hit "operation already in progress." Wait between deploys and **verify the function list afterwards** (`INF-03`).
- `app_config/global` must be created via the admin editor before remote config does anything.
- The OpenRouter account needs credit — the default model (`openai/gpt-4o-mini`) is **paid**.
- `aiProxy` requires the `allUsers` Cloud Functions Invoker role, or the platform returns 401 before the in-code auth runs.
- Deploy `firestore.indexes.json` + `firestore.rules` **before** testing programs and groups.

---

## §48 — Future Ideas, Research & Icebox

> Not scheduled. Not committed. Recorded so nothing is lost. Anything promoted out of here gets a real
> task card in the relevant section first.

### 48.1 Product ideas carried from prior roadmaps

| ID | Idea | Source | Notes |
|---|---|---|---|
| `ICE-01` | Challenges 2.0 | `FUTURE_FEATURES` D2 | Tracked as `CHL-01` |
| `ICE-02` | XP / levels gamification | `FUTURE_FEATURES` D3, README | Tracked as `GAM-01` |
| `ICE-03` | Payout provider integration | `FUTURE_FEATURES` A1 | Tracked as `REF-04` |
| `ICE-04` | Richer credit and subscription tiers | `FUTURE_FEATURES` A2 | Tracked as `MON-16` |
| `ICE-05` | Gym Wars full competition UI | `FUTURE_FEATURES` B2 | Tracked as `GYM-06` |
| `ICE-06` | White-label gym branding | `FUTURE_FEATURES` B3 | Tracked as `GYM-09` |
| `ICE-07` | Behavioural analytics → ML pipeline | `FUTURE_FEATURES` C1 | Tracked as `AI-14` |
| `ICE-08` | Dynamic plan adaptation | `FUTURE_FEATURES` C2 | Tracked as `AI-16` |
| `ICE-09` | Supplement / partner-brand ecosystem | `FUTURE_FEATURES` E1 | Tracked as `MKT-06` |
| `ICE-10` | Challenge / program sponsorship marketplace | `FUTURE_FEATURES` E2 | Tracked as `CHL-02` |
| `ICE-11` | Additional locales | `FUTURE_FEATURES` F1 | Tracked as `I18N-03` |
| `ICE-12` | Tablet / large-screen layouts | `FUTURE_FEATURES` F2 | Tracked as `UI-09` |
| `ICE-13` | Offline write queue | `FUTURE_FEATURES` F3 | Tracked as `ARCH-07` |
| `ICE-14` | Per-household meal scaling | `ONBOARDING_V2` §7 | Tracked as `NUT-11` |
| `ICE-15` | App-icon recolouring as premium | `ONBOARDING_V2` §7 | Tracked as `ONB-08` |
| `ICE-16` | Phone-contacts friend discovery | Phase 8 deferred | Tracked as `SOC-06` |
| `ICE-17` | Groups P2/P3 (leaderboards, challenges, events, moderators, invites, private groups, suggestions) | `COMMUNITY_GROUPS` §5–6 | Tracked as `GRP-03`–`GRP-14` |

### 48.2 New ideas from this audit

| ID | Idea | Rationale |
|---|---|---|
| `ICE-18` | Nutritionist-reviewed "verified" badge on catalog dishes | Turns `NUT-10`'s required review into a visible trust signal and a genuine differentiator against generic trackers |
| `ICE-19` | Turkish regional cuisine collections | The 75-dish Turkish-first catalog is the real moat. Regional collections (Aegean, Southeastern, Black Sea) deepen it in a way global competitors structurally cannot copy |
| `ICE-20` | "Cook with what I have" pantry-driven planning | The ingredient model and recipe generation already exist; a pantry inventory closes the loop between shopping list and meal plan |
| `ICE-21` | Ramadan / religious-fasting meal planning mode | High relevance to the primary market; no global competitor does this well. Requires careful nutritional and cultural review |
| `ICE-22` | Grocery-delivery integration (Getir / Migros / Trendyol) | The shopping list with source-meal attribution is already the right shape for a basket handoff. Partnership-gated |
| `ICE-23` | Family / household accounts | `cooks_for_others` is already collected. A shared plan across a household is a strong retention and referral mechanic |
| `ICE-24` | Dietitian marketplace as a distinct vertical from personal training | Coaches are currently modelled generically; licensed dietitians have different verification, liability and regulatory needs — and are a better fit for a nutrition product |
| `ICE-25` | Meal-plan PDF export | Frequently expected in nutrition products; the `.ics` export shows the pattern is already understood |
| `ICE-26` | Restaurant / eating-out logging | The largest gap in food logging for real users; needs a restaurant nutrition data source |

### 48.3 Research spikes

| ID | Question to answer | Why it matters | Effort |
|---|---|---|---|
| `RES-01` | What is the real cost per active user at 1k / 10k / 100k, measured rather than modelled? | `ADM-07` shows estimates for Firebase and real numbers for AI. The blended figure determines whether the free tier (2 AI/day) is viable | S |
| `RES-02` | Is 2 free AI generations per day the right funnel, or does it prevent activation? | `MON-04` — this single number may decide whether users ever reach the aha moment | S (needs M4 data) |
| `RES-03` | Does a 14-page pre-registration onboarding convert better than a shorter post-registration flow? | The inverted-onboarding bet is the product's boldest UX decision and has never been measured (`ONB-05`) | M |
| `RES-04` | Cloud Run vs Cloud Functions for the AI proxy at scale | `PERF-07` — concurrency, connection reuse and cost profile differ materially above ~10k DAU | S |
| `RES-05` | Typesense vs Algolia vs Firestore-native for search | `PERF-08` — cost, hosting burden and Turkish-language stemming quality | S |
| `RES-06` | Stripe Connect vs iyzico for TR-first payouts | `REF-04` — KYC coverage, TR bank support, fees, and store-policy compatibility | M |
| `RES-07` | Can the dish catalog be grown to 300+ with acceptable macro accuracy without a nutritionist on retainer? | `BLK-11` + `NUT-10` — this is the gating question for the entire content strategy | M |
| `RES-08` | What retention does the Turkish-first positioning actually buy versus global competitors? | The core strategic thesis. Needs M4 cohort data against a stated benchmark | M |

---

## §49 — Long-Term Vision

> Recorded for context and to keep §1.9's scope discipline honest. **None of this is scheduled.** The
> README currently describes much of it as if it exists — `DOC-02` fixes that.

**The stated vision:** *"An AI-Powered Fitness Operating System for Gyms, Coaches & Fitness Communities."*

**The honest position today:** a consumer AI nutrition app with a substantial but unverified gym/coach
surface bolted on. The prior roadmap's own assessment — *"~40 % of a great consumer nutrition app and
~3 % of the operating system"* — was written when `lib/` was 37,200 LOC. It is now 115,129 LOC, and the
consumer app is closer to 85 % **written** / 45 % **verified**. The operating system is perhaps 25 %
written and near 0 % operational, because `BLK-05` and `BLK-03` make both ecosystems unusable.

**A credible three-year shape, in order:**

1. **Year 1 — win the consumer product in Turkey.** Ship v1.0 consumer-only. Prove D30 retention against
   a stated benchmark. Get the dish catalog to 500+ with nutritionist review. Make monetization work.
   Nothing else matters until D30 retention is known.
2. **Year 1–2 — open the coach vertical.** Coaches are the higher-margin, lower-operational-burden side
   of the marketplace and the natural fit for a nutrition product (`ICE-24` — dietitians specifically).
   Requires `COA-04` verification standards and `REF-04` payouts.
3. **Year 2 — open the gym vertical with a real commercial model.** `GYM-07` is undefined today. Gyms are
   a distribution bet: they bring members, but they need a reason to pay. Answer that before building
   more gym features. Run `GYM-10` first.
4. **Year 2–3 — the platform story.** White-label (`GYM-09`), API access, partner brands (`MKT-06`),
   behavioural ML (`AI-14`). This is the Series-A narrative, and it is only credible on top of proven
   consumer retention and a working two-sided marketplace.

**The strategic asset to protect:** the Turkish-first content and localization moat. 2,722 perfectly-
paired localization keys, a Turkish dish catalog, TR-locale-forced AI output, and KVKK-aware
architecture. Global competitors do not do this well and structurally will not prioritise it. Every
roadmap decision should ask whether it deepens that moat or dilutes it.

**The failure mode to avoid,** stated plainly because the prior roadmap warned about it three times and
the codebase drifted toward it anyway: **building the operating system before validating the consumer
app.** Eight product domains, 75 screens and 115k LOC currently serve **zero validated users**. The most
likely way this project fails is not technical — it is running out of runway maintaining an unlaunched
surface this wide.

---

## §50 — Traceability Matrix

> Proof that nothing from any prior report or roadmap disappeared. Every source item maps to a task ID
> in this document.

### 50.1 `GO_LIVE.md` §5S security gates → task IDs

| Prior | Title | Now |
|---|---|---|
| `S0` | Rotate the leaked Admin SA key + secret-scan CI | `BLK-15` |
| `S1` | Lock the `users/{uid}` rule (field whitelist) | `BLK-10`, `SEC-04`, `SEC-14` |
| `S2` | Server-authoritative AI credit + entitlement ledger | ✅ `MON-03`, `AI-20` (rules verified present) |
| `S3` | Server-side purchase validation | `BLK-04`, `MON-13` |
| `S4` | Server-authoritative economy | ✅ `REF-01` (done) + `SEC-15` (fraud resistance) |
| `S5` | Close the open Firestore create rules | `SEC-06` |
| `S6` | Hardened AI proxy + App Check enforcement | `BLK-14`, `BE-01`, `BLK-15`, `SEC-10` |
| `S7` | Server-side erasure + Storage cleanup | `BLK-12` |
| `S8` | Runtime consent enforcement + cross-border disclosure + age gate | `LEG-06`, `LEG-08`, ✅ `LEG-04` |
| `S9` | Storage access control + scanning + EXIF | `BLK-07`, `SEC-13`, ✅ EXIF done |
| `S10` | Minimize the readable user doc | `BLK-10` |
| `S11` | Complete the GDPR export | `BLK-12`, `LEG-11` |
| `S12` | Auth abuse controls | `SEC-01`, `AUTH-07` |
| `S13` | Economy/social integrity | `BLK-08`, `BLK-09`, `SEC-07`, `SEC-08`, `SEC-09`, `SEC-12`, `COM-06` |
| `S14` | Cleartext off + Hive encrypted | `SEC-17`, ✅ Hive done, `SEC-19` (analytics box) |
| `S15` | Obfuscated release, no debug APK | `SEC-18`, `BLK-15` |
| `S16` | Environment isolation + lockfiles | `INF-01`, `SEC-28`, `DEBT-51` |
| `S17` | Analytics consent-gated, no PII | ✅ consent done, `AUTH-12`, `ANL-06` |
| `S18` | FLAG_SECURE / screenshot protection | `SEC-20` |
| `S19` | Root/jailbreak detection | `SEC-21` |
| `S20` | PII-redacting logger | `SEC-22` |
| `S21` | Certificate pinning | `SEC-23` |
| `S22` | Backups/PITR + budget alerts + monitoring + IR runbook | `DR-01`, `DR-02`, `DR-03`, `INF-05`, `BLK-17` |
| `S23` | Tighten counters, bound listeners, Functions gen2 | `BLK-08`, `BE-10`, `FB-17`, `ARCH-10` |

### 50.2 `GO_LIVE.md` Phases 0–7 (console/founder work) → task IDs

| Prior | Now |
|---|---|
| 0.1–0.3 Apple + Google enrolment, Firebase ownership | `BLK-16` |
| 1.1–1.4 App ID, APNs key, certificates, App Check DeviceCheck | `BLK-16`, `NOTIF-10`, `BLK-14` |
| 2.1–2.4 Keystore, Play App Signing, SHA keys, Play Integrity | `BLK-16`, `AUTH-02`, `BLK-14`, `DR-04` |
| 3.1–3.4 Store records, listings, privacy/legal, assets | `STORE-03`, `STORE-04`, `LEG-07` |
| 4.1–4.3 IAP products, sandbox testers | `BLK-04`, `MON-07` |
| 5.1 API key restrictions | ✅ checklist written (`docs/firebase-console-setup.md`) |
| 5.2–5.3 Deploy Functions + secret, rules + indexes | `BE-01`, `INF-03`, `INF-04` |
| 5.4 Load test the proxy | `PERF-10` |
| 5.5 Monitoring + backups | `BLK-17`, `DR-01`, `DR-02` |
| 5.6 Deep-link server files | `INF-07` |
| 5T Functions modernization | `ARCH-10` |
| 5U Reliability & environments | `INF-01`, `DR-03` |
| 6.1–6.4 CI secrets, TestFlight, Play internal, beta criteria | `CI-04`, `TEST-08`, M4 |
| 7.1–7.3 Store review, launch checklist | `STORE-08`, `CI-06`, M5 |

### 50.3 `FUTURE_FEATURES.md` → task IDs

`A1`→`REF-04` · `A2`→`MON-16` · `B1`→✅ shipped · `B2`→`GYM-06` · `B3`→`GYM-09` · `C1`→`AI-14` ·
`C2`→`AI-16` · `C3`→✅ shipped (`LOG-04`) · `D1`→✅ shipped (`COM-03`) · `D2`→`CHL-01` · `D3`→`GAM-01` ·
`E1`→`MKT-06` · `E2`→`CHL-02` · `F1`→`I18N-03` · `F2`→`UI-09` · `F3`→`ARCH-07` · `G1`→`TEST-03`,
`TEST-05` · `G2`→`PERF-12` · `G3`→`OBS-01`, `ANL-03` · `L1`→`LEG-07` · `L2`→✅ `LEG-03` · `L3`→✅ `LEG-09` ·
`L4`→✅ `LEG-04` · `L5`→`LEG-06` · `L6`→✅ `LEG-10` · `L7`→`REF-05`

### 50.4 `COMMUNITY_GROUPS.md` → task IDs

`P1`→✅ `GRP-01` · `P2.1`→`GRP-03` · `P2.2`→`GRP-04` · `P2.3`→`GRP-05` · `P2.4`→`GRP-06` · `P2.5`→`GRP-07` ·
`P2.6`→`GRP-08` · `P2.7`→`GRP-09` · `P3.1`→`GRP-10` · `P3.2`→`GRP-11` · `P3.3`→`GRP-12` · `P3.4`→`GRP-13` ·
`P3.5`→`GRP-14` · `P3.6`→`SEC-12`, `GRP-15` · member_count reconcile→`BE-10`

### 50.5 `ONBOARDING_V2.md` → task IDs

§7 household scaling→`NUT-11` · §7 app-icon recolouring→`ONB-08` · §7 server-side IAP validation→
✅ built, `BLK-04` to enable · §8 finalize-race handling→✅ shipped, hardening in `ONB-04`

### 50.6 Prior TODO phase items not yet complete → task IDs

| Prior item | Now |
|---|---|
| 15.2 Daily "Bugün" recap card (unchecked) | `HOME-05` (status disputed — code exists) |
| 15.5 Streak-freeze earn rules | `GAM-06` |
| Behavioural analytics pipeline (Phase 6, deferred) | `AI-14` |
| Payout processing (Phase 5/7, deferred) | `REF-04` |
| Partner brands (Phase 7, deferred to v1.8) | `MKT-06` |
| Paid programs paywall (Phase 14.12) | `MKT-03` |
| Automatic payouts (Phase 14.12) | `REF-04` |
| Stale post-avatar backfill (Phase 14.9, deferred) | `PRF-05` |
| Step-aware cooking timer (partial-features table) | `RCP-04` |
| Real ban data on the suspension screen (partial-features table) | `MOD-06` |
| Shopping-list check state across cold start (partial-features table) | `SET-01` verify — **re-check; may still be open** |
| Offline write queue / sync UI (Phase 1 decision) | `ARCH-07` |
| Additional locales (Phase 9, deferred) | `I18N-03` |
| Contacts picker (Phase 8, deferred) | `SOC-06` |
| Deep-link server files (Phase 8, deploy-time step) | `INF-07` |
| Consent records + retention policy (Phase 9, "console/legal") | `LEG-05`, `LEG-06` |
| Privacy nutrition labels + store assets (Phase 9, "console/asset") | `STORE-03`, `STORE-04` |
| Cloud Monitoring dashboards + Crashlytics alerts (Phase 9, "console") | `BLK-17`, `OBS-01` |
| Firestore backup schedule (`docs/firebase-console-setup.md`) | `DR-01` |
| 2 remaining purchase webhooks (`appStoreNotifications`, `playRtdn`) | `MON-13` |

### 50.7 Prior "Architecture Recommendations" → task IDs

1 Repository layer→`ARCH-03` · 2 AI behind a backend→✅ built, `BE-01` to deploy · 3 Typed domain model→
✅ `UserNutritionProfile` shipped · 4 Roles/tenancy model→✅ `AUTHZ-01` shipped · 5 Pick one offline
strategy→`ARCH-07` (decision recorded, revisit on retention data) · 6 Event taxonomy + Performance→
`ANL-02`, `FB-23` · 7 Emulator Suite + CI→`INF-02`, `FB-18` · 8 Standardize navigation→✅ 3-tab
`IndexedStack` shipped

### 50.8 Prior "Product Risks" → current status

| Risk | Then | Now |
|---|---|---|
| Security/data breach on open rules | 🔴 | 🟠 — rules are extensive and serious, but 8 authorization holes and 3 missing paths remain (§7) |
| Scope delusion (README sells an OS) | 🔴 | 🔴 **unchanged and worse** — 8 domains, 75 screens, 0 validated users. §1.9 and `DOC-02` are the mitigation |
| AI cost & reliability | 🟠 | 🟠 — cost controls are now genuinely strong (`AI-20`, `AI-21`); the fabrication-as-correctness-risk is fixed (`BLK-01` closed) — remaining reliability risk is availability-only, pending `BE-01`'s proxy deployment |
| App Store rejection | 🟠 | 🟠 — `BLK-02`'s automatic-rejection cause (missing photo-library usage string) is fixed; `STORE-04` and `STORE-06` remain open risks |
| Retention with no push | 🟠 | 🔴 — push is built and **does not work** (`BLK-03`); worse than "not built" because it looks done |
| "Looks done, isn't" | 🟠 | 🔴 **the defining risk of this codebase.** Seven confirmed dead paths; ~1 % coverage means seven is a floor, not a total |
| Single-maintainer bus factor | 🟡 | 🔴 — 115k LOC, 486 KB of partly-inaccurate docs, all credentials with one person (`DR-05`) |
| Two-sided marketplace cold start | 🟡 | 🟡 — unchanged; §1.9's consumer-first cut is the mitigation |

### 50.9 Audit findings `C1`–`C17` (2026-07-31) → task IDs

`C1`→`BLK-01` · `C2`→`BLK-02` · `C3`→`BLK-03` · `C4`→`BLK-04` · `C5`→`BLK-05` · `C6`→`BLK-06` ·
`C7`→`BLK-07` · `C8`→`BLK-08` · `C9`→`BLK-09` · `C10`→`BLK-10` · `C11`→`BLK-11` · `C12`→`BLK-12` ·
`C13`→`BLK-13` · `C14`→`BLK-13`/`DEBT-19` · `C15`→`ARCH-05` · `C16`→`AI-03` · `C17`→`SEC-17`

---

## §51 — Recommended Execution Order

The first ten things to do, in this order. Everything else follows from them.

1. **`BLK-16`** — start Apple + Google enrolment **today**. Longest lead time, blocks M3 and M4, and no
   engineering work compresses it.
2. **`ARCH-01` / `DEBT-01`** — kill swallow-and-log. This converts remaining unknown-unknowns into
   visible failures and is the reason seven defects hid for months.
3. ~~**`BLK-13`** — un-ignore `test/`, fix 3 tests, format 44 files, get CI green, protect `main`.~~
   **Fully done** — all 4 jobs confirmed green in real CI. "Protect `main`" (`CI-02`) is now genuinely
   achievable and recommended as the next step, not yet done (a repository-settings change, flagged
   rather than made unprompted).
4. ~~**`TEST-01` / `FB-18`** — commit and run the rules suite. It would have caught 5 of the 17 blockers.~~
   Committed and running green in CI for its current 15-assertion scope; extending to all 71 match
   blocks is still open.
5. **`INF-01`** — stand up staging. Nothing else can be tested honestly against one shared project.
6. ~~**`BLK-01`**~~ + **`BE-01`** + **`BE-02`** — delete the mock, deploy the proxy, align the timeouts.
   The mock is deleted and both services guard `isConfigured` (`BLK-01` closed); `BE-01`/`BE-02`
   (deploy the proxy, align timeouts) remain open and still dangerous alone without the guard —
   the guard just makes "alone" mean "honest error state," not "silent lie."
7. ~~**`BLK-02`**~~ — the string plus a preflight check landed. Device/`.ipa` verification still
   owed once `BLK-16` gives a signing identity.
8. **`BLK-05`** — one Firestore document plus a custom claim unlocks ~7,400 LOC and both ecosystems.
9. **`BLK-03`** + **`SEC-06`** — fix the notification path and move authorship server-side in one change.
10. **`TEST-08`** — write and execute an honest manual QA pass on physical iOS and Android devices.
    **Every one of the seven dead paths would have been caught by this. It is the cheapest and most
    effective quality intervention available.**

Then: `BLK-06`, `BLK-08`, `BLK-11`+`AI-03`, `BLK-14`, `BLK-15`, `BLK-17`, `DR-01`, `DR-02` → M2 legal
track (`BLK-10`, `BLK-12`, `LEG-06`, `LEG-07`) → M3 commerce (`BLK-04`) → M4 beta.

---

*This backlog was reconstructed from a full source-code audit of commit `e06ca0d`, merged with every
prior TODO, roadmap, phase plan and audit in the repository. Status markers reflect what the code proves,
not what previous documents claimed — and where the two disagreed, the disagreement is recorded rather
than resolved silently.*

*Re-audit after every milestone. Update this file in the same commit as the code (§0.5). If a task is not
in here, it is not planned.*





