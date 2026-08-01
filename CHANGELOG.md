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

### Fixed — `CI-11`: `analyze-and-test` failed in CI across three independent, stacked bugs (2026-08-01)

Getting this job green meant fixing three unrelated defects, each one hiding the next until the
previous was resolved. All three confirmed by reproduction, not guessed at from log fragments.

**1. `flutter pub get` failed.** Installed Flutter 3.24.0 via `fvm` and ran `pub get` against an
isolated copy of the real `pubspec.yaml`/`pubspec.lock` — the original lead (`DEBT-42`'s undocumented
`dependency_overrides`) turned out to be unrelated; Dart overrides bypass version-solve conflict
checking entirely. Real cause: 9 direct dependencies (`lints`, `vm_service`, `test_api`, `meta`,
`async`, `fake_async`, `url_launcher`, `flutter_timezone`, `device_info_plus`) had been bumped past
what CI's never-updated Flutter `3.24.0` pin's Dart SDK (3.5.0) supports; `ci.yml` was added 3 days
after the last such bump and the two were never cross-checked. Fixed by bumping `ci.yml`/`deploy.yml`
to `3.44.4`, matching local dev, rather than the open-ended downgrade path (2 of the 9 would have
needed real production source-code changes for major-version API differences).
**Confirmed green in a real CI run** ([#42](https://github.com/burcok/cookrange/actions/runs/30669425771)).

**2. With `pub get` fixed, `flutter analyze` failed with 3 "Undefined name 'DefaultFirebaseOptions'"
errors** (`lib/main.dart`, `app_initialization_service.dart`, `seed_db.dart`). `ci.yml`'s placeholder
for the gitignored `lib/firebase_options.dart` was `// Auto-generated placeholder for CI` — a
comment, never a real stub. This has been broken since `ci.yml` was created; invisible until (1) was
fixed, because analyze was never reached before. `build-android` had no placeholder step at all —
silently broken the same way, the whole time. Fixed with a minimal valid
`DefaultFirebaseOptions.currentPlatform` stub in both jobs. `deploy.yml` deliberately **not** given
the same fix — it builds real release artifacts for store distribution, so fake credentials would be
actively wrong there, not just incomplete; tracked under `DEBT-52`/`BLK-16` instead.

**3. Analyze then failed on `warning • The asset directory 'assets/fonts/' doesn't exist'`.** Real
cause: git tracked `assets/**F**onts/` (capital F) while all 17 `pubspec.yaml` font declarations say
`assets/**f**onts/` (lowercase) — invisible for the project's entire life because **macOS's
filesystem is case-insensitive**, silently resolving the mismatch on every local dev machine. Linux
(CI, and real Android devices) is case-sensitive and sees two different, non-existent paths. Fixed
via a case-only `git mv` (two-step, since a direct rename no-ops on a case-insensitive filesystem).
Also found and removed in the same sweep: 54 accidentally-committed Xcode build-cache files (47 under
`assets/Fonts/build/`, 7 under `android/build/` — a misconfigured derived-data path, unrelated to the
case bug). `.gitignore` broadened from `/build/` (root only) to `**/build/` so this can't recur
silently.

**Verification.** No Docker Desktop on this machine — installed `colima` + `docker`, ran a real
`ubuntu:24.04` container under `--platform linux/amd64` (matching GitHub's actual runner
architecture), cloned Flutter `3.44.4`, and tested the **exact bytes about to be pushed** via
`git archive` of a `git stash create` snapshot — not an approximation. `pub get`, `dart format`,
`flutter analyze --no-fatal-infos`, and `flutter test` (78/78) all exit 0 in that container.

**Confirmed in a real CI run** ([#44](https://github.com/burcok/cookrange/actions/runs/30687453667)):
`analyze-and-test` genuinely green end to end in 2m 29s — `Get dependencies`, `Verify formatting`,
`Analyze code`, and `Run tests` all succeeded. `firestore-rules` and `secret-scan` green as before.
**All three of `CI-11`'s root causes are real, fixed, and now proven, not just locally verified.**

`build-android` failed on a **fourth, distinct, previously-unreachable failure** — `flutter build apk
--debug` itself, the first time this exact step has ever executed in this repo's CI history (it was
always blocked upstream before now). Opened as `CI-12`.

### Fixed — `CI-12`: hardcoded local Java path broke `build-android` (2026-08-01)

**Root cause confirmed by reproduction.** Set up a real Android SDK (platform 36, NDK 28.2.13676358,
build-tools 36.0.0, licenses accepted) inside a fresh `ubuntu:24.04` container and hit the exact
error CI showed:

```
Value '/Applications/Android Studio.app/Contents/jbr/Contents/Home' given for
org.gradle.java.home Gradle property is invalid (Java home supplied is invalid)
```

`android/gradle.properties` hardcoded `org.gradle.java.home` to an absolute macOS-only path —
Android Studio's bundled JBR. It worked silently on this one machine (that exact path genuinely
exists here, with a real JBR) and would fail identically everywhere else: every CI runner, any
teammate's machine, any Mac without Android Studio installed at that exact location. Same failure
class as `CI-11`'s `assets/Fonts` case bug — a value true on exactly one machine. Git history shows
this line has **never** been portable: it previously hardcoded a different local path
(`/opt/homebrew/opt/openjdk@17`) before being swapped to the Android Studio path.

**Fix:** removed the line entirely rather than substituting another hardcoded path, letting Gradle
use the ambient `JAVA_HOME` that `ci.yml`'s own "Set up Java" step already sets correctly. Verified
the fix doesn't break the local Mac build (still succeeds, ~62s).

**Confirmed in real CI**: [run #46](https://github.com/burcok/cookrange/actions/runs/30690211684) —
`build-android` succeeded. **All four CI jobs green for the first time in this repo's history.**

`BLK-13`, `CI-11`, and `CI-12` are now fully closed. Four independent, stacked root causes found and
fixed across the three cards, every one confirmed by reproducing it in a real environment rather
than guessed at — a stale Flutter pin, an invalid `firebase_options.dart` placeholder, a repo-wide
font-directory case mismatch, and a hardcoded local Java path. `CI-02` (branch protection) is the
natural next step, now genuinely achievable.

### Fixed — `BLK-01`: release builds silently served hardcoded fake AI meal plans and recipes (2026-08-01)

The single most serious defect in the repository. `AIService.isConfigured` is
`_proxyUrl != null || (_apiKey != null && kDebugMode)` — in a release build with no proxy URL
resolved from Remote Config (the default), it's `false`. `generateCompletion` didn't check it: it
returned 135 lines of hardcoded JSON — seven identical days of `geleneksel_menemen` /
`somonlu_kinoa_bowl` / `izgara_somon_sebze` / `smoothie_bowl_protein`, and a "Mock Healthy Stir Fry"
recipe. Every mock dish ID exists in the real catalog, so the fabricated plan rendered as a
completely plausible one — fabricated health/nutrition guidance presented as personalised AI.
`weekly_meal_plan_service.dart` and `recipe_generation_service.dart` had zero `isConfigured` checks.

**Fix:**
- Deleted the 135-line mock block from `ai_service.dart`; `generateCompletion` now throws
  `AIFatalException` when `!isConfigured`.
- `WeeklyMealPlanService` and `RecipeGenerationService` guard `isConfigured` up front and `rethrow`
  `AIFatalException` past their generic catch instead of swallowing it to `null`/`[]`.
- `home.dart` and `explore_screen.dart` catch `AIFatalException` specifically, log a Crashlytics
  error, and render a branded `AppErrorState` with retry — never a plan, never a blank screen.
  `meal_plan_comparison_sheet.dart` needed no change; its existing generic catch already handled this.
- `AppInitializationService` logs a Crashlytics **error** at startup when a release build resolves
  no AI proxy URL, so a misconfigured deploy is loud immediately instead of discovered from user
  reports.
- New regression test: `test/meal_plan_ai_unavailable_test.dart`. Scope note: it exercises
  `AppErrorState` directly (not a fully mounted `HomeScreen`) with the retry callback omitted —
  `AppButton` reads `ThemeProvider`, whose constructor touches `FirebaseAuth.instance` synchronously,
  and this repo has no Firebase test mocks (ADR-004).
- 4 new EN/TR key pairs; `i18n_parity_test.dart` passes.

**Verified:** `grep -c "Mock Healthy Stir Fry\|geleneksel_menemen" ai_service.dart` → `0`.
`flutter analyze lib/` — 0 errors, 25 infos (unchanged baseline). `flutter test` — 79/79 pass.
Ran on the iOS Simulator with `isConfigured` temporarily forced to `false` (reverted before commit;
a true `--release` run isn't supported on any Simulator, and `kDebugMode` is a framework constant
this fix doesn't re-derive at runtime, so the override exercises the identical branch a release
build would take) — no crash, no fabricated content observed. Did **not** get a live look at the
rendered `AppErrorState` on `home.dart`: this dev account has a pre-existing cached meal plan that
correctly short-circuits before the `isConfigured` guard (`Using cached meal plan for user ...`).
The guard → throw → catch → render chain is verified by reading, not by a live screenshot; see
`BLK-01`'s TODO.md card for the full honest account, including a pre-existing, unrelated finding
that `ExploreScreen` currently has no navigation route into it at all.

**Residual:** `BE-01` (deploy `aiProxy`, set `ai_proxy_url`) is now a hard launch dependency — without
it every release build shows the honest error state, never a working plan. That's the intended
trade: a visible failure instead of a silent lie. `AI-07` (deterministic catalog-based fallback) and
`AI-08` (`AiChatService`'s leaking fallback string) remain open, out of scope here.

### Fixed — `BLK-02`: missing iOS photo-library usage string caused a crash on 6 screens (2026-08-01)

`Info.plist` declared usage strings for camera, location, microphone, speech recognition, and
tracking — but not photos, even though `ImageSource.gallery` is used in six screens. On iOS the app
terminates immediately when the picker is invoked without the matching key, and App Review rejects
binaries that touch the photo library without a purpose string.

**Fix:**
- Added `NSPhotoLibraryUsageDescription` to `Info.plist` with copy naming all six real use cases
  (profile picture, food logging, community posts, gym logos, coach applications). Confirmed
  `NSPhotoLibraryAddUsageDescription` isn't needed — grepped for `PHPhotoLibrary`, `image_gallery_saver`,
  `package:gal`; nothing in this codebase writes to the library.
- Found a related, previously-untracked gap while verifying the six call sites: three of them
  (`chat_detail_screen.dart`, `gym_setup_screen.dart`, `food_scan_screen.dart`) called `ImagePicker`
  directly with no `PermissionService` import anywhere in the file, skipping the app's own in-app
  rationale sheet that the other three already showed correctly. Added the same
  `PermissionService().requestPhotos()` (or `.requestCamera()` for `food_scan_screen.dart`'s shared
  camera/gallery method) call used by the three that already had it.
- New `scripts/check_ios_permissions.sh`: greps `pubspec.yaml` for `image_picker`, `mobile_scanner`,
  `geolocator`, `speech_to_text` and fails if `Info.plist` is missing the usage-description key(s)
  each implies. Wired into `ci.yml` right after checkout. Verified it actually catches the defect:
  ran it against the real, still-broken `Info.plist` before adding the string (failed with the exact
  missing-key message), then again after (passed).

**Verified:** `flutter analyze lib/` — 0 errors, 25 infos (unchanged baseline). `flutter test` —
79/79 pass. On the iOS Simulator: reset the app's photo permission, triggered the avatar picker —
the in-app primer fired, the OS-level request resolved to permanently-denied (a Simulator quirk with
no seeded Photos library, not a crash), and the Settings-redirect sheet correctly opened iOS Settings
with the app still alive underneath. No crash anywhere in the flow — the literal defect this fixes.

**Not done:** physical-iPhone confirmation and a signed `flutter build ipa` — no physical device
available, and no Apple signing identity exists yet (`BLK-16`) regardless.

### Fixed — `BLK-06`: `meal_plan_history` had no security rule, feature was permanently empty (2026-08-01)

`users/{uid}/meal_plan_history/{key}` is written on every plan save and read by a 298-line history
screen. It has a composite index. It had no security rule — catch-all deny — so the write and the
read both failed on every single call, silently: `catchError((e) => debugPrint(...))` on write,
`catch (e) { ... return []; }` on read. The history screen has rendered an empty state, forever,
since this feature shipped.

**Fix:**
- Added `match /meal_plan_history/{historyId} { allow read, write: if isOwner(uid); }` to
  `firestore.rules`, a sibling of the already-working `meal_plans/{planId}` block.
- Both named call sites in `weekly_meal_plan_service.dart` now also report to `CrashlyticsService`
  (`coach_review_service.dart`'s existing idiom — debugPrint for dev, Crashlytics for production —
  not one replacing the other).
- Found two more catch sites in the same state while in `meal_plan_history_screen.dart`:
  `_loadHistory`'s catch had no Crashlytics call, and `_restorePlan`'s Firestore write had no catch
  at all. Both fixed the same way. No new user-facing copy — this is observability, not new UX.
- New rules test in `test/firestore_rules/rules.test.mjs` asserting owner-only read and write.

**Verified:** `flutter analyze lib/` — 0 errors, 25 infos (unchanged). `flutter test` — 79/79 pass.
The rules test itself could not be run locally — no Java on this machine, same pre-existing
constraint as the rest of this suite (`BLK-13`) — CI's `firestore-rules` job
([run #50](https://github.com/burcok/cookrange/actions/runs/30697804480)) ran it for real and it
passed.

**Deployed:** `firebase deploy --only firestore:rules --project cookrange-app`, with explicit
user go-ahead (rules changes are live, shared-infrastructure actions — asked first rather than
folded in silently). Confirmed by the CLI's own output: "released rules firestore.rules to
cloud.firestore." The feature is live for real users as of this deploy.

### Fixed (code) — `BLK-05`: the entire admin surface was unreachable — `syncAdminClaim` NOT YET DEPLOYED (2026-08-01)

`isAdmin()` in `firestore.rules` requires `admin_roles/{uid}.is_admin == true`. Nothing anywhere —
not the client, not any Cloud Function — ever created that document. Meanwhile the client showed
the admin UI based on the client-writable `user_roles` array, at **three** call sites (only one was
previously tracked; found the other two — `role_quick_card.dart`, `settings_screen.dart` — while
fixing the first). Net effect: anyone could summon the admin UI; nobody could use it. ~7,400 LOC
across 9 admin screens presented a fully-populated interface that failed permission-denied on every
read.

**Fix:**
- New Cloud Function `syncAdminClaim` (`functions/admin.js`): a Firestore trigger on
  `admin_roles/{uid}` that mirrors `is_admin` onto a Firebase Auth custom claim
  (`admin.auth().setCustomUserClaims()`), so the client can verify admin-ness itself via the ID
  token instead of trusting a document it can write.
- `UserProvider` gained `isAdmin`, read from `getIdTokenResult().claims['admin']` on every user
  load; fails closed on any error. All three client gates now watch this instead of
  `user.hasRole(UserRole.admin)`.
- `AdminStatusService`'s two dead `admin_config/global` reads (always permission-denied for a
  normal user, silently swallowed, silently falling back to Remote Config) deleted outright.
- Fixed a stale "admin power is gated by `admin/status/{uid}`" claim in two places —
  `firestore.rules`'s own comment and `docs/SECURITY.md` §4 — `admin/status/{uid}/flags` is ban
  state, an unrelated concept; `isAdmin()` has always checked `admin_roles/{uid}`.
- New bootstrap runbook in `docs/SECURITY.md` §4: `admin_roles/{uid}` is `write: false`
  unconditionally, even for an admin, so the Firebase Console is the only way to create it. No
  callable bootstrap function was built — one that can grant admin is itself a privilege-escalation
  surface, and the acceptance criteria only asked for a console step **or** a callable, not both.
- 3 new rules tests: a seeded admin still can't write `admin_roles` via the client SDK; a
  console-provisioned admin can read `admin_audit`/`ai_usage_logs`/`admin_config`; a non-admin is
  denied on all three.

**Verified:** `flutter analyze lib/` — 0 errors, 25 infos (unchanged). `flutter test` — 79/79 pass.
Rules tests written and syntax-checked; not run locally (no Java, same `BLK-13` constraint) — CI's
`firestore-rules` job is the authoritative check once pushed.

**Not deployed — deliberately.** `syncAdminClaim` has zero effect until
`firebase deploy --only functions` runs. Unlike the `meal_plan_history` rule (a declarative,
easily-diffed change), this deploys new, automatically-triggered, privileged code — a materially
bigger risk. Held for a separate, explicit go-ahead rather than folded into this pass. Until
deployed, `admin_roles/{uid}` can still be created via the Console runbook, but the custom claim
won't sync automatically, so the fix isn't complete in production yet.

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
