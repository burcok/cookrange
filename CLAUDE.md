# CLAUDE.md — Rules for AI Agents

> **This file is loaded into every session. It contains rules only.**
> Facts about the system live in `docs/` and are loaded on demand — never restate them here.
> If you want to know *what exists*, read `docs/INDEX.md`. This file tells you *how to behave*.

---

## 1. Project identity

**Cookrange** — an AI nutrition & fitness platform. Flutter (iOS + Android) + Firebase + a Node.js
Cloud Functions backend + OpenRouter LLM behind a server-side proxy. Bilingual EN/TR. Turkey is the
primary market, so **KVKK and GDPR are release blockers, not features**.

~115k LOC · 329 files · 42 models · 75 services · 95 screens · Provider state · server-authoritative
trust model.

**Current state: `v0.9.6` internal alpha.** Much of the surface is written but unverified.
**Read [`PROJECT_STATE.md`](PROJECT_STATE.md) before assuming any feature works.**

---

## 2. Context loading strategy — read this before you read anything else

**Never read the entire repository. Never scan directories to orient yourself.** The documentation
exists so you don't have to. Repository-wide search is a last resort, not a first step.

**Use documentation as your primary context.** Source code is for verifying a specific unknown
detail, not for discovering what the system does.

### The loading order

1. [`PROJECT_STATE.md`](PROJECT_STATE.md) — what actually works right now
2. [`docs/INDEX.md`](docs/INDEX.md) §2 — the task router: which docs your task needs
3. The 1–3 documents that row names
4. **Only then** the specific source files those documents point at

### Hard limits

- ❌ Don't read `TODO.md` end-to-end (3,000 lines). Jump to the section or task ID you were given.
- ❌ Don't read a doc "for background" if the router didn't list it for your task.
- ❌ Don't `grep` for something the docs already map. If the map is missing it, **fix the map** as
  part of your task.
- ✅ Do read source when a doc is ambiguous, suspect, or silent — then correct the doc.
- ✅ Do stop reading once you can act. Enough context beats complete context.

**Code is truth.** When a doc and the code disagree, the code wins — fix the doc in the same task
and say so in your summary.

---

## 3. Coding philosophy

1. **Smallest correct change.** Targeted edits over rewrites. Don't refactor code the task didn't
   ask about. Don't "clean up" on the way past.
2. **Match the surrounding code.** Its naming, comment density, error handling, and idiom are the
   spec. A change that reads as foreign is a defect even if it works.
3. **Finish the whole task.** Including the localization keys, the security rule, the index, and the
   doc update. A feature that needs a follow-up commit to be correct was not delivered.
4. **Be honest about what you did.** If a step was skipped, if a test fails, if you couldn't verify
   something — say so plainly. Never report unverified work as done.
5. **Optimize by default (R1).** No N+1 reads, no unbounded queries, `const` constructors,
   cancelled subscriptions, minimal rebuilds. The slower path is never the acceptable one.

---

## 4. The rules — R0–R9

These are always active, on every task.

### R0 — Think in three roles before non-trivial work
**PM**: what problem, which edge cases, what does "better than expected" look like? →
**Architect**: data tier, schema, indexes, rules, failure modes, migration, implementation order? →
**Developer**: idiomatic, optimized, matches conventions, all states covered.
Roles are a thinking sequence, not a deliverable. See [`AGENTS.md`](AGENTS.md) for the eight
specialist roles and their review checklists.

### R1 — Optimization is mandatory
Batch/transact where applicable · `const` constructors · lazy/paginated lists · `RepaintBoundary` on
heavy widgets · debounced inputs · subscriptions cancelled in `dispose` · image caching ·
`Selector`/`ValueListenableBuilder` over broad `watch`. Never ship an obviously slower path.

### R2 — Data-layer discipline
Decide deliberately and implement end to end: where the data lives (R3) · the Firestore path and doc
shape · a **composite index in `firestore.indexes.json` for every new query shape** · a **security
rule in `firestore.rules`/`storage.rules` for every new path — never leave a collection unguarded** ·
an idempotent seeder if reference data is needed · versioned, idempotent, logged migrations.
Details: [`docs/DATABASE.md`](docs/DATABASE.md).

### R3 — Pick the caching tier consciously
**In-memory** (session-scoped, cheap to recompute) · **Hive/SharedPreferences** (device-scoped, must
survive restart) · **Firestore** (source of truth, cross-device, auditable). Prefer
stale-while-revalidate: show cached instantly, refresh in background, reconcile. Rationale: ADR-016.

### R4 — Log at every boundary
Every service method, async boundary, and error path logs meaningfully: `debugPrint` for dev,
`CrashlyticsService` with context (screen, uid, operation) for real errors. Log AI call inputs and
outputs, Firestore failures, purchase events, migrations.

> **No silent `catch {}`.** Swallow-and-log is this codebase's single systemic defect (`DEBT-01`) —
> it is why Crashlytics is blind. If you catch, either handle it or re-report it. Never neither.

### R5 — Performance-grade UX on both platforms
`AnimationController` / implicit animations with intentional `AppMotion` curves and durations; 60fps,
no jank, no abrupt state jumps. Test iOS **and** Android: platform-guard where needed
(`Platform.isIOS`), respect safe areas, Cupertino-correct gestures, haptics on meaningful actions.

### R6 — Theme and i18n are never optional
**Never hardcode a color** — `AppPalette.of(context)` / design tokens only; every surface correct in
dark and light. **Every user-visible string gets EN and TR keys in the same change**, named
`screen.section.element`. `test/i18n_parity_test.dart` must pass.

### R7 — Flagship design language
Every surface should read as a top-tier product — including the states people skip: **loading,
empty, error, success, sheets, pickers, transitions**. No bare `CircularProgressIndicator`, no
default grey error text, no abrupt modal. Build the component once in `lib/core/widgets/ds/` and
reuse it. Details: [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md).

### R8 — Keep the documentation alive
See §7. Non-negotiable and part of the Definition of Done.

### R9 — Shared-file parallel-write guard
**Never let two agents or two tool calls write the same shared file concurrently.** This has already
silently destroyed localization keys once.
- `en.json` / `tr.json`: sequential Python `json.load → mutate → json.dump`, one key group at a
  time. **Never `sed`.**
- `firestore.indexes.json` · `firestore.rules` · `storage.rules`: one writer per turn.
- Parallel sub-agents get **disjoint file sets**. If two need the same file, serialize them or have
  one collect both changes and write once.

---

## 5. Architecture rules

**The four layers, one direction:**
`screens/` + `widgets/` → `core/providers/` → `core/services/` → `core/models/` + `core/data/`

1. **UI never touches Firebase.** No `cloud_firestore` import in a screen or widget — go through a
   service. A service never imports a UI widget.
2. **Services are singletons**: `static final _instance = Foo._internal(); factory Foo() => _instance;`
   Never `new` a service.
3. **No new architectural layers** without explicit instruction. The structure in
   [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) is the structure.
4. **Don't extend the repository layer.** It covers four domains and was left incomplete (ADR-005).
   Follow the surrounding domain's existing pattern.
5. **PII belongs in `users/{uid}/private/nutrition`**, never the public user doc (ADR-009).
6. **The client is never the authority** for entitlements, AI credits, the economy, roles, ban state,
   or moderation. Those are server-only (ADR-008, [`docs/SECURITY.md`](docs/SECURITY.md)).

---

## 6. Security rules

Full model: [`docs/SECURITY.md`](docs/SECURITY.md). Non-negotiable minimums on every task:

- **Never write a secret into client code, a `.env` shipped as an asset, a doc, or a log.**
- **Every new Firestore/Storage path gets a rule in the same change.** Default deny.
- **Never make a value-bearing field client-writable** (`subscription_*`, `ai_credits_*`,
  `user_roles`, `is_banned`, `referral_used`, commissions, counters that gate rewards).
- **Content-length caps in rules** for any user-authored free text.
- **Never log PII** — no email, IP, body metrics, or health data in analytics events or logs.
- **Personal data needs disclosure + consent *before* access**, with purpose, whether it's stored,
  and a real decline path. Health and location are special-category: explicit consent
  (*açık rıza*). Framework: [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) §6, §9.
- **Minimize.** Prefer transient/on-device over stored. Reference implementation: the "gyms near me"
  consent gate — location used on-device, never stored.
- **Deploy order matters**: server write paths ship before rules lock (ADR-008).

---

## 7. Documentation update rules

**Update only affected documentation** — surgically, in the same task, never a rewrite for a
one-line change.

| You touched | Update |
|---|---|
| `lib/core/models/`, `firestore.rules`, `firestore.indexes.json`, `storage.rules` | `docs/DATABASE.md` |
| `lib/core/services/`, `functions/` | `docs/SERVICES.md` (+ `docs/API.md` if a contract changed) |
| `lib/screens/`, `lib/main.dart`, routes | `docs/FRONTEND.md` |
| `lib/core/theme/`, `lib/core/widgets/ds/` | `docs/DESIGN_SYSTEM.md` |
| `assets/localization/` | `docs/LOCALIZATION.md` (only if the system changed) |
| `android/`, `ios/` | `docs/PLATFORM.md` |
| `.github/workflows/`, `firebase.json` | `docs/DEVOPS.md` |
| `test/` | `docs/TESTING.md` |
| Anything touching personal data or consent | `docs/COMPLIANCE.md` |
| A user-facing capability appeared or disappeared | `docs/FEATURES.md` **and** `README.md` |
| A blocker opened/closed, or a system started/stopped working | **`PROJECT_STATE.md`** |
| A structural choice that constrains future work | **`DECISIONS.md`** (new ADR, append-only) |
| Task scope or status | `TODO.md` |
| A shipped roadmap item | move it out of `docs/roadmap/FUTURE_FEATURES.md` |

**Two rules that keep this system trustworthy:**

1. **Status lives in `PROJECT_STATE.md` and nowhere else.** Feature docs describe how something is
   *built*; they never claim it works. Do not put percentages, health scores, or blocker lists in a
   feature doc.
2. **Never document a feature as present because you just wrote it.** Written ≠ working. Moving a
   system into `PROJECT_STATE.md` §5 requires demonstrating it runs.

---

## 8. Testing requirements

Full strategy: [`docs/TESTING.md`](docs/TESTING.md). Current coverage is ~1 % — `test/` is now
tracked (`BLK-13`), which makes coverage countable, not higher. Treat every claim of correctness as
unproven until you run something.

**Before any task is done:**

```bash
flutter analyze lib/                          # MUST be 0 errors — non-negotiable
flutter test test/i18n_parity_test.dart       # after ANY localization change
flutter test                                  # if you changed logic
dart format lib/                              # CI enforces this
```

- **New pure logic gets a unit test.** Calculators, parsers, schedulers, filters, safety checks —
  anything with no Firebase dependency has no excuse.
- **Never delete or weaken a test to make it pass.** A failing test is information.
- **Never claim a test passed without running it.**
- Firebase-dependent code is currently untestable by design (ADR-004) — say so rather than
  pretending otherwise.

---

## 9. Coding standards

- **Comments only where the WHY is non-obvious.** No narrating what the code says.
- `mounted` check before every `setState` or `context` use after an `await`.
- `unawaited()` (with `dart:async`) for intentional fire-and-forget.
- `StatefulBuilder` inside `showDialog` for dialog-local loading state.
- Cursor pagination via `DocumentSnapshot startAfter` (`community_service.dart:fetchPostsPage`).
- Platform guards: `if (Platform.isIOS)` for Apple Sign-In and Apple-specific UI.
- **Field naming** — the `users/{uid}` doc mirrors Firebase Auth in **camelCase** (`displayName`,
  `photoURL`, `email`); **everything else on it is snake_case** (`created_at`, `is_online`,
  `onboarding_data`, `user_role`, `is_banned`). Other collections denormalize as
  `display_name`/`photo_url` (snake) and are internally consistent — **do not "fix" those** without
  a data migration. Reading the user doc's name as `display_name` returns null; this has already
  broken admin search once.
- **Images:** display via `AppImage` or `CachedNetworkImageProvider` — **never** raw `Image.network`
  or `NetworkImage`. Upload only via `StorageUploadService` (resize, compress, EXIF strip, off-thread).
- **Counts:** `count()` aggregation or `pollCount()` — never `.snapshots().map((s) => s.size)`.
- **Queries:** always `.limit()`. An unbounded listener re-reads every matching doc on every change.

---

## 10. Forbidden behaviours

Doing any of these is a failed task, regardless of whether the code works.

| ❌ Never | Why |
|---|---|
| Read the whole repository, or scan directories to orient | The docs exist for this (§2) |
| Restate `docs/` content inside `CLAUDE.md` | This file loads every session; duplication costs tokens forever |
| Put status, percentages, or blockers in a feature doc | Status has exactly one owner (§7) |
| Document something as working because you wrote it | Written ≠ working — the drift that broke the previous docs |
| Refactor beyond the task's scope | Unreviewable diffs; ADR-005 is what that produces |
| Add a Firestore path without a rule | Silent-failure class; already caused `BLK-06`, `BLK-07` |
| Add a query without an index | Fails in production only |
| Write a user-visible string in one language | Breaks the CI parity gate |
| Hardcode a color or text style in UI | Breaks dark mode structurally |
| `catch {}` with no log or handling | Blinds Crashlytics (R4) |
| Let two writers touch `en.json`/`tr.json`/rules concurrently | Has already destroyed keys (R9) |
| Make a value-bearing field client-writable | The entire ADR-008 audit exists because of this |
| Commit a secret, or log PII | Rotation is expensive; a breach is reportable |
| Claim a command succeeded without running it | Destroys the only trust the system has |
| Create a new doc when an existing one owns the topic | Duplication is the failure mode of doc systems |

---

## 11. Definition of Done

Every task must pass all applicable boxes:

☑ Multi-role reasoning applied (R0) · ☑ Optimized (R1) · ☑ Data tier + index + rule + seed correct
(R2/R3) · ☑ Logged, no silent catch (R4) · ☑ Smooth on iOS **and** Android (R5) · ☑ Dark/Light +
EN/TR (R6) · ☑ All states designed — loading/empty/error/success/modal (R7) · ☑ Security minimums
met (§6) · ☑ `flutter analyze lib/` **0 errors** · ☑ Relevant tests run and reported honestly (§8) ·
☑ Owning doc updated, and `PROJECT_STATE.md` / `DECISIONS.md` if status or a structural choice
changed (§7)

---

**Next:** [`AGENTS.md`](AGENTS.md) for the per-prompt workflow and your specialist role ·
[`docs/INDEX.md`](docs/INDEX.md) to find the documents for your task.
