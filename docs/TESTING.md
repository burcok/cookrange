# TESTING.md — Testing Strategy

> How correctness is proven — and, right now, mostly isn't.
> CI mechanics live in [`DEVOPS.md`](DEVOPS.md).
>
> ⚠️ **Coverage is still ~1 % of ~115k LOC** — line coverage hasn't moved. What changed (`BLK-13`):
> `test/` is tracked in git, all 3 previously-failing tests now pass, and the Firestore rules suite
> runs green **in a real CI run**, not just locally
> ([run #40](https://github.com/burcok/cookrange/actions/runs/30667024406)). Testing was the
> lowest-scoring dimension at 2.0 / 10; it is still the highest-leverage thing anyone can improve —
> 1 % coverage means almost everything is still unproven.

---

## 1. The situation

| | |
|---|---|
| Test files | **13** (12 Dart unit/widget + 1 Firestore rules) |
| Coverage | **~1 %** of ~115k LOC |
| Failing | **0** |
| Widget tests | 2 (`widget_test.dart`'s scaffold default; `meal_plan_ai_unavailable_test.dart`'s `AppErrorState` check, `BLK-01`) |
| Integration tests | **0** |
| Firestore rules tests | **16**, in version control (`test/firestore_rules/rules.test.mjs`) |
| **`test/` tracked in git?** | **Yes** |

**Un-ignoring `test/` was the root-cause fix.** Tests written locally were never reaching the
repository, so CI couldn't run them, so nobody trusted them, so nobody wrote them. That gate now
exists — it doesn't retroactively add coverage, it just means new tests (and the 3 that were already
here) actually count from now on.

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
| `meal_plan_ai_unavailable_test.dart` | `AppErrorState` renders the exact copy `home.dart` falls back to when AI is unconfigured (`BLK-01`); `onRetry` omitted — see the file's own comment for why a full `HomeScreen` mount isn't feasible (ADR-004) |
| `firestore_rules/rules.test.mjs` | 16 test cases: economy lock, server-only ledgers, PII isolation, content caps, admin self-grant denial, owner-only `meal_plan_history` (`BLK-06`) — runs against the emulator, not `flutter test` |

These share a shape worth copying: **pure Dart, no Firebase, deterministic, real edge cases** (the one
exception, `meal_plan_ai_unavailable_test.dart`, is a widget test — it needs no Firebase either, since
it exercises a design-system component directly rather than a screen).
`i18n_parity_test.dart` is the model for what a gate should be — mechanical, fast, unarguable.
The first 11 Dart files above were already accurate as "what exists" before `BLK-13` — but 3 of them
(`allergen_safety_test.dart`, `ai_credit_model_test.dart`, `cost_analytics_test.dart`) existed only on
disk, not in git, which this page did not previously say. `meal_plan_ai_unavailable_test.dart` was
added after, with `BLK-01`.

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

1. ~~**`BLK-13`** — un-ignore `test/`, fix the 3 failures, get CI green.~~ **Fixed and confirmed**:
   `test/` tracked, 0 local failures, all 4 CI jobs green
   ([run #46](https://github.com/burcok/cookrange/actions/runs/30690211684)) — `analyze-and-test`'s
   `CI-11` and `build-android`'s `CI-12` were found and fixed after this card closed; see
   `PROJECT_STATE.md` for the live count.
2. ~~**`TEST-01` — Firestore rules tests in version control.**~~ Landed as part of `BLK-13`, since
   grown to 16 test cases in `test/firestore_rules/rules.test.mjs` (`BLK-06` added the
   `meal_plan_history` owner-only case), covering the security model directly. Still needed: extend
   it toward all 71 rule match blocks, not just the 16 covered today.
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
cd test/firestore_rules && npm install
cd ../.. && firebase emulators:exec --only firestore --project demo-cookrange \
  "node --test --test-reporter=spec test/firestore_rules/rules.test.mjs"
```

> Needs a JVM 21+ (`firebase-tools` refuses to start the emulator below that) — `java -version` first.
> Point the last argument at the **file**, not the directory — Node's test runner resolves a bare
> directory as a module to `require()` and throws `MODULE_NOT_FOUND` instead of discovering tests in
> it. Confirmed passing 15/15 both locally and in CI (Temurin 21, bumped from 17 — `BLK-13`/`CI-11`'s
> investigation found `firebase-tools@latest` now hard-requires it).

---

## 6. CI gates

`.github/workflows/ci.yml` on every PR: `dart format --set-exit-if-changed` → `flutter analyze` →
`flutter test` → Android debug build. Mechanics: [`DEVOPS.md`](DEVOPS.md).

> The format, test, and rules jobs were all failing (`BLK-13`) — confirmed fixed in a **real CI run**,
> not just locally: `dart format`/`flutter test` (78/78) and `firestore-rules` (15/15) are green
> ([run #40](https://github.com/burcok/cookrange/actions/runs/30667024406)). `secret-scan` was already
> green. `analyze-and-test` still fails, but on a **confirmed pre-existing, unrelated** issue
> (`Get dependencies` — tracked as `CI-11`), and `build-android` is skipped downstream of it. 2 of 4
> green is real progress, not full green — check `PROJECT_STATE.md` for the current count.

**Definition of a working gate:** CI is green on `main` · a PR that breaks a test cannot merge · the
rules suite runs on every change to `firestore.rules` · coverage is reported and does not silently
fall. Branch protection requiring all four jobs is still open (`BLK-13` acceptance criteria) —
un-ignoring `test/` makes the jobs runnable, it doesn't yet make them required.

---

## 7. Coverage goals

| Milestone | Target | Focus |
|---|---|---|
| **M1 — Truth** | `test/` tracked ✅, 3 failures fixed ✅, CI green ✅ all 4 jobs | Make the gate exist |
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
