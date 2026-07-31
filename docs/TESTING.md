# TESTING.md — Testing Strategy

> How correctness is proven — and, right now, mostly isn't.
> CI mechanics live in [`DEVOPS.md`](DEVOPS.md).
>
> ⚠️ **Coverage is ~1 %, three tests fail, and `test/` is in `.gitignore`** (`BLK-13`). Testing is
> the lowest-scoring dimension in the project at **2.0 / 10** and the highest-leverage thing anyone
> can improve. Read this before claiming anything works.

---

## 1. The situation

| | |
|---|---|
| Test files | 11, all unit tests |
| Coverage | **~1 %** of ~115k LOC |
| Failing | **3** |
| Widget tests | 1 (the Flutter scaffold default) |
| Integration tests | **0** |
| Firestore rules tests | **0 in version control** |
| **`test/` tracked in git?** | **No — line 58 of `.gitignore`** |

**The `.gitignore` entry is the root cause.** Tests written locally never reach the repository, so CI
can't run them, so nobody trusts them, so nobody writes them. Un-ignoring `test/` is a one-line
change and the precondition for everything else on this page.

### Why coverage is this low

Not laziness — **architecture** (ADR-004). Services are hand-rolled singletons with no interfaces
and no injection point, so they can't be faked. Any code touching a service therefore needs live
Firebase, which makes it untestable in a unit test. Testability work must start by extracting
interfaces behind those singletons (`ARCH-04`).

Until then the testable surface is **pure logic only** — which is exactly what the existing tests
cover, and they're good.

---

## 2. What exists

| File | Covers |
|---|---|
| `calorie_calculator_test.dart` | Mifflin-St Jeor BMR/TDEE — 20 cases |
| `streak_logic_test.dart` | Streak increment, break, freeze consumption — 8 cases |
| `allergen_safety_test.dart` | Deterministic allergen filter — **safety-critical** |
| `onboarding_projection_test.dart` | BMI, macros, safe-clamped rate, ETA |
| `water_reminder_schedule_test.dart` | `spreadReminderTimes` incl. midnight wrap |
| `meal_plan_parse_test.dart` | Parsing AI meal-plan JSON |
| `ai_credit_model_test.dart` | Credit arithmetic, reset windows |
| `cost_analytics_test.dart` | Cost/revenue projection maths |
| `app_lifecycle_service_test.dart` | Lifecycle transitions |
| `i18n_parity_test.dart` | **EN/TR key parity — the one real CI gate** |
| `widget_test.dart` | Default scaffold smoke test |

These share a shape worth copying: **pure Dart, no Firebase, deterministic, real edge cases.**
`i18n_parity_test.dart` is the model for what a gate should be — mechanical, fast, unarguable.

---

## 3. The pyramid we're aiming at

```
        ╱ E2E ╲            a handful — signup → onboarding → plan → log
      ╱─────────╲
    ╱ Integration ╲        critical flows against the Firebase emulator
  ╱─────────────────╲
╱   Widget + Rules    ╲    every screen's states; every rule's allow/deny
─────────────────────────
      Unit (broad)         all pure logic — calculators, parsers, filters
```

### Priority order

1. **`BLK-13`** — un-ignore `test/`, fix the 3 failures, get CI green. Nothing else counts until a
   gate exists.
2. **`TEST-01` — Firestore rules tests in version control.** Highest value per hour in the whole
   project: rules are where the security model actually lives, and `BLK-06`/`BLK-07`/`BLK-08` are all
   defects a rules test suite would have caught at write time. Also the required safety net before
   the `S1` rules lock.
3. **`TEST-02` — widget tests** for the states that break silently: loading, empty, error, and both
   themes.
4. **`TEST-03` — integration tests** against the emulator for the consumer path: signup → onboarding
   → meal plan → food log.
5. **`ARCH-04` — service interfaces**, which unblocks unit-testing the other 99 %.

---

## 4. Writing tests here

**Unit** — pure logic, no Firebase, no network, no wall clock. Inject time and randomness. Cover
empty, null, boundary, timezone, and locale. Verify the test fails when you break the logic.

**Widget** — pump the widget, assert on the state you care about. Every screen owes tests for
loading / empty / error / content, and for light and dark.

**Rules** — `@firebase/rules-unit-testing` against the emulator. For each collection assert: owner
can read, non-owner cannot, client cannot write server-only fields, content caps hold. Write the
deny cases first; they're the ones that regress.

**Integration** — `integration_test` + the Firebase emulator suite. Seed, act, assert, tear down.

### Rules for every test
- **Never weaken or delete a test to make a build pass.** A failing test is information.
- **Never claim a test passed without running it.**
- Deterministic: no ordering dependence, no real network, no `DateTime.now()` in assertions.
- New pure logic ships with a unit test — calculators, parsers, schedulers, filters, safety checks
  have no excuse.
- Safety-critical logic (allergens, dosing, calorie targets) gets adversarial cases, not just happy paths.

---

## 5. Commands

```bash
flutter test                                  # full suite
flutter test test/i18n_parity_test.dart       # after ANY localization change
flutter test --coverage                       # → coverage/lcov.info
flutter analyze lib/                          # 0 errors — the other hard gate
```

```bash
firebase emulators:exec --only firestore "npm test --prefix functions"
```

---

## 6. CI gates

`.github/workflows/ci.yml` on every PR: `dart format --set-exit-if-changed` → `flutter analyze` →
`flutter test` → Android debug build. Mechanics: [`DEVOPS.md`](DEVOPS.md).

> ⚠️ **CI is red on `main`.** The format and test jobs fail, and the rules job has no files to run
> because `test/` is gitignored. A green local run does not mean a green pipeline.

**Definition of a working gate** (none of these hold yet): CI is green on `main` · a PR that breaks a
test cannot merge · the rules suite runs on every change to `firestore.rules` · coverage is reported
and does not silently fall.

---

## 7. Coverage goals

| Milestone | Target | Focus |
|---|---|---|
| **M1 — Truth** | CI green, `test/` tracked, 3 failures fixed | Make the gate exist |
| **M2 — Legal** | Rules suite covering every collection | Security is only real if it's tested |
| **M4 — Beta** | ~30 % line coverage; consumer path in integration tests | Cover what users actually touch |
| **M6+** | ~60 % on `core/`; widget tests on all primary screens | Sustainable |

Percentages are secondary. **A rules suite and one integration test through the consumer path are
worth more than 60 % line coverage of getters.**

---

## 8. Untestable by design — say so

Firebase-dependent code cannot currently be unit tested (§1). When you touch it:

- Don't fake a test that only asserts a mock returns what you told it to
- Extract the pure logic and test **that**; leave the Firebase call as a thin uncovered shell
- State plainly in your report that the Firebase path is unverified

Pretending coverage exists is worse than admitting it doesn't — that gap is exactly how a project
reaches 84 % written and 45 % working.
