# CHANGELOG

All notable changes to Cookrange. Format follows [Keep a Changelog](https://keepachangelog.com/);
versioning follows [Semantic Versioning](https://semver.org/).

> Live status is in [`PROJECT_STATE.md`](PROJECT_STATE.md); the backlog is in [`TODO.md`](TODO.md);
> the reasoning behind structural choices is in [`DECISIONS.md`](DECISIONS.md).
>
> **The app has never been publicly released.** Versions below are internal milestones.

---

## [Unreleased]

### Added — documentation system (2026-07-31)

A complete documentation ecosystem, so future contributors and AI agents can understand the project
without scanning the repository.

**New root documents**
- `PROJECT_STATE.md` — live status: version, milestone, progress, the 17 critical blockers, health
  scorecard, next recommended actions. **The single source of truth for status.**
- `DECISIONS.md` — 17 Architecture Decision Records (ADR-001 … ADR-017) covering Flutter, Firebase,
  Provider, singletons, the abandoned repository layer, the AI proxy, `in_app_purchase` vs
  RevenueCat, the server-authoritative trust boundary, the PII split, structured notifications,
  remote app config, the consumer-only v1 scope cut, inverted onboarding, i18n parity, the design
  system, caching tiers, and this documentation architecture.
- `CHANGELOG.md` — this file.

**New technical documents**
- `docs/SECURITY.md` — threat model, adversaries, authorization layers, secrets, the `S0`–`S17` gate
  list, and six attack scenarios walked end to end.
- `docs/AUTHENTICATION.md` — registration, login, OAuth, the `RouteGuard` gate order, email
  verification, session and token handling, GDPR account deletion.
- `docs/AI_SYSTEM.md` — LLM architecture, models, prompt strategy, cost control, quota, injection
  prevention, degradation contract, roadmap.
- `docs/API.md` — all 13 Cloud Functions, request/response contracts, webhooks, triggers, scheduled
  jobs, external services, deploy gotchas.
- `docs/PREMIUM.md` — tiers, products, AI credits, the purchase flow, entitlement truth, referrals,
  commissions, and what blocks revenue.
- `docs/COMMUNITY.md` — feed, social graph, chat, notifications, gamification, moderation layers.
- `docs/GYM_ECOSYSTEM.md` — gym model, onboarding, attendance, GPS-presence privacy pattern,
  analytics, M6 roadmap.
- `docs/COACH_ECOSYSTEM.md` — coach profiles, discovery, client management, reviews, marketplace,
  revenue sharing.
- `docs/TESTING.md` — the honest coverage picture, why it's ~1 %, the target pyramid, priorities.
- `docs/DEVOPS.md` — CI/CD, environments, secrets, Firebase deploy order, release process,
  monitoring gaps.

**Restructured**
- `CLAUDE.md` — rewritten as **rules only**: identity, context-loading strategy, coding philosophy,
  R0–R9, architecture/security/documentation/testing rules, coding standards, forbidden behaviours,
  Definition of Done. Reduced from ~49 KB to ~13 KB by removing service, collection, and feature
  tables that duplicated `docs/`. This file loads into every session, so the saving recurs
  permanently.
- `AGENTS.md` — rewritten around **eight specialist agent roles** (Architecture, Security, Frontend,
  Backend, Firebase, AI, Testing, Documentation), each with responsibilities, allowed changes, and a
  review checklist; plus the per-prompt workflow and anti-drift constraints.
- `docs/INDEX.md` — rewritten as a **task router**: a four-file bootstrap, a task → documents table,
  and a registry recording each document's owned source paths and dependencies.
- `README.md` — refocused as a public product overview (vision, features, stack, setup, roadmap,
  premium, gym and community vision). Internal architecture, security detail, and implementation
  rationale moved to `docs/` and `DECISIONS.md`.
- `docs/FEATURES.md` — rebuilt with an explicit **State** column (✅ working · 🚧 built-unverified ·
  ⛔ blocked · 🔒 kill-switched · ❌ not built) plus Since / Depends on / Next per capability.

**Moved / merged / removed**
- `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`
- `docs/DATA_MODEL.md` → `docs/DATABASE.md`, extended with a collection tree, relationships, data
  lifecycle, and migration strategy
- `docs/generated/db-schema.md` — **deleted**; its flat path tree is folded into `DATABASE.md` §1,
  removing a hand-maintained derived copy
- CI/CD detail moved out of `docs/PLATFORM.md` into `docs/DEVOPS.md`; `PLATFORM.md` now owns native
  parity only

### Fixed — documentation accuracy

The prior documentation asserted capabilities as shipped that do not function, which made it
actively misleading rather than merely incomplete. Corrected in this pass:

- **Status is now separated from description.** Feature documents describe how something is *built*;
  only `PROJECT_STATE.md` claims anything *works*. `README.md` no longer states that every listed
  feature is live in the app.
- **Cloud Function count** — documented as "4" in the index and "10/12" in `SERVICES.md`; verified
  **13** exported functions and corrected in `docs/API.md`.
- **RevenueCat** — referenced as a project dependency in the documentation request; the codebase
  uses `in_app_purchase` with self-hosted receipt validation and has no RevenueCat dependency.
  Recorded as ADR-007 with the trade-off and a note to revisit.
- **`test/` is gitignored** — surfaced in `TESTING.md` and `DEVOPS.md` as the root cause of the ~1 %
  coverage and the red CI pipeline, rather than left implicit.

### Fixed — `BLK-13`: CI quality gate (2026-08-01)

- **`test/` un-ignored and committed.** 6 files were written locally but invisible to git and CI:
  `ai_credit_model_test.dart`, `allergen_safety_test.dart`, `cost_analytics_test.dart`, and the
  entire `test/firestore_rules/` Firestore security-rules suite (15 assertions — the test class that
  would have caught `BLK-06`, `BLK-07`, `BLK-08` at write time). `node_modules` under
  `firestore_rules/` stays excluded via a scoped ignore rule.
- **`pubspec.lock` un-ignored** (`DEBT-51`) — it must be committed for an application; the ignore
  rule contradicted the fact that it was already tracked.
- **3 failing tests fixed** in `app_lifecycle_service_test.dart` — `MockFirestoreService` was missing
  overrides for `syncDeviceContext` and `verifyAndRepairUserData`, added to the real service after
  the mock was written. Verified the fix isn't a rubber stamp by breaking `_endSession` and
  confirming the suite still fails.
- **44 files reformatted** to match `dart format`'s canonical output (whitespace-only; verified by
  comparing whitespace-stripped token streams before/after).
- **`lib/firebase_options.dart` generation documented** (`docs/DEVOPS.md` §4) — `DEBT-52`. The file
  stays gitignored; CI's placeholder hack is unchanged and remains a gap for anyone bootstrapping a
  device build directly from CI's config.
- **Pushed to `main` and verified against real CI rather than trusting a local run** — the whole point
  of the fix. Result:
  [run #40](https://github.com/burcok/cookrange/actions/runs/30667024406), 2 of 4 jobs green.
  - `firestore-rules` — went from failing before it could even install (the directory didn't exist in
    the repo) to **15/15 passing**. Two real bugs surfaced and fixed getting there: `ci.yml` pinned
    Java 17, but `firebase-tools` (installed at `latest`) now hard-requires 21+; and the
    `admin/status` test passed an invalid 3-segment Firestore document reference (`doc()` requires an
    even count) — fixed to the valid path `firestore.rules:32`'s own comment describes.
  - `secret-scan` — green (unchanged).
  - `analyze-and-test` fails at `Get dependencies` (`flutter pub get`) — confirmed **pre-existing**,
    reproducing identically on the commit before this work and one 12 days older. Not caused by this
    fix; not fixed by it either. Opened as `CI-11`, with a lead (`DEBT-42`'s undocumented
    `dependency_overrides` vs. CI's Flutter `3.24.0` pin) rather than a confirmed cause — bumping CI's
    Flutter version has its own re-verification cost, so it's scoped separately rather than folded in
    here.
  - `build-android` — skipped, downstream of the above.

### Fixed — `CI-11`: stale Flutter version pin blocked `pub get` in CI (2026-08-01)

- **Root cause confirmed by reproduction, not guessed.** Installed Flutter 3.24.0 via `fvm` and ran
  `flutter pub get` against an isolated copy of the real `pubspec.yaml`/`pubspec.lock` — the original
  lead (`DEBT-42`'s undocumented `dependency_overrides`) turned out to be unrelated; Dart overrides
  bypass version-solve conflict checking entirely, so they were never the cause.
- **Real cause:** 9 direct `pubspec.yaml` dependencies (`lints`, `vm_service`, `test_api`, `meta`,
  `async`, `fake_async`, `url_launcher`, `flutter_timezone`, `device_info_plus`) had been bumped, at
  some point after `.github/workflows/ci.yml` was added (3 days after the last such bump, per git
  history — the two were never cross-checked), to versions requiring a newer Dart SDK than CI's pinned
  Flutter 3.24.0 (Dart 3.5.0) provides. Pub's solver surfaces one conflict at a time, so fixing them
  individually kept revealing more; 2 of the 9 would have needed actual production source-code changes
  for real major-version API differences (`flutter_timezone`'s `getLocalTimezone()` return type
  changed at 5.0.0; `device_info_plus` likely similar, unconfirmed).
- **Fix chosen over the alternative:** bumped `ci.yml` and `deploy.yml`'s Flutter pin to `3.44.4`,
  matching local dev exactly, rather than the open-ended dependency-downgrade path. Verified clean
  under the new pin: `flutter pub get`, `flutter analyze lib/` (0 errors), `dart format` (0 diff),
  `flutter test` (78/78) — all re-run fresh, not assumed from earlier in the session.
- **Not yet confirmed against a real CI run** — the fix is applied and locally verified; the next push
  settles whether all 4 jobs are actually green.

---

## [0.9.6] — 2026-07-31 — *internal alpha*

Full audit (`TODO.md`) established the honest baseline: ~84 % of the feature surface written, ~45 %
verified functional, 17 critical blockers, all 18 security gates open, ~1 % test coverage.
Scope decision: **consumer-only v1** — gym, coach, programs, marketplace, commissions, and payouts
deferred to M6 behind kill-switches (ADR-012).

## [0.9.5] — 2026-07 — *admin, config & cost*
Centralized admin navigation (categorized hub grid + shared section scaffold) · remote app
configuration service with feature kill-switches and maintenance/force-update gates · AI usage
tracking with per-user lookup and per-request-type categorization · Cloud Functions backend, cost
analytics, and mandatory AI data-usage consent flows · achievement tracking, weekly recap, and
streak calendar.

## [0.9.x] — 2026-06 — *security hardening & onboarding V2*
Server-authoritative trust boundary (ADR-008): entitlements, AI credits, referral economy, purchase
validation, and account erasure moved to Cloud Functions behind field-locked rules · Hive AES-256
encryption · consent-gated analytics · deterministic allergen filter · prompt-injection guard ·
Onboarding V2, inverted to run before registration (ADR-013).

## [0.9.0] and earlier — *feature build-out*
Design system · food scanning · nutrition analytics · cooking mode · community · shopping list ·
settings · referral program · deep linking · ATT consent · accessibility semantics · GDPR data
export · social sharing · gym and coach ecosystems · program marketplace. Phase-by-phase record:
`TODO.md` §47.2.

---

## Maintaining this file

- Add to **[Unreleased]** as work lands; move it under a version heading at release.
- Group entries as **Added · Changed · Fixed · Removed · Security**.
- Write for a reader who wasn't there: what changed and why it matters, not the file names touched.
- A structural change also needs an ADR in [`DECISIONS.md`](DECISIONS.md).
- A status change also needs [`PROJECT_STATE.md`](PROJECT_STATE.md).
