# AGENTS.md — Cookrange AI Operating Manual

> **This is the first file any AI agent reads before touching the Cookrange codebase.**
> It defines *how* to work. The *what* (rules) lives in `CLAUDE.md`; the *where*
> (code map) lives in `docs/`. Read this, then the relevant `docs/` file for your task,
> then act. **You should almost never need to `grep` blind — the map already exists.**

---

## 0. The 30-Second Orientation

Cookrange is a **Flutter (iOS + Android) + Firebase** AI fitness/nutrition platform.
274 Dart files, ~100K LOC, 42 models, 75 services, 95 screens, a full design system,
and a Node.js Cloud Functions backend.

| You need to… | Read first | Then |
|---|---|---|
| Understand the whole system | `ARCHITECTURE.md` | the specific `docs/` file |
| Change/look at a **data model, Firestore, rules, index** | `docs/DATA_MODEL.md` | the model file |
| Change/look at **business logic, a service, Cloud Function** | `docs/SERVICES.md` | the service file |
| Change/look at a **screen, navigation, route** | `docs/FRONTEND.md` | the screen file |
| Build/restyle **any UI** | `docs/DESIGN_SYSTEM.md` | `lib/core/widgets/ds/` |
| Know **if a feature exists & where** | `docs/FEATURES.md` | — |
| Handle **iOS vs Android** differences | `docs/PLATFORM.md` | — |
| Add/change a **user-facing string** | `docs/LOCALIZATION.md` | both JSON files |
| Plan **launch / store submission** | `docs/roadmap/GO_LIVE.md` | — |
| Build a **future/missing feature** | `docs/roadmap/FUTURE_FEATURES.md` | — |
| Know **what's done / pending** | `TODO.md` | — |

---

## 1. The Mandatory Per-Prompt Workflow

Run this loop **on every non-trivial task**. Do not skip steps.

```
┌─ 1. CLASSIFY ────────────────────────────────────────────────┐
│  Bug fix? Feature? Refactor? Design? Data change? Doc?        │
│  → picks which docs/ file is authoritative for this task.     │
└──────────────────────────────────────────────────────────────┘
            ↓
┌─ 2. READ THE MAP (not the whole repo) ───────────────────────┐
│  Open the relevant docs/ file from the table above.           │
│  It tells you the exact file(s), class(es), and patterns.     │
│  Only then open the actual source file(s).                    │
└──────────────────────────────────────────────────────────────┘
            ↓
┌─ 3. THINK IN 3 ROLES (CLAUDE.md R0) ─────────────────────────┐
│  PM: what problem, what edge cases, what "even better"?       │
│  Architect: data tier, indexes, rules, failure modes?        │
│  Dev: idiomatic, optimized, matches surrounding code?        │
└──────────────────────────────────────────────────────────────┘
            ↓
┌─ 4. CHECK THE PRE-FLIGHT CHECKLIST (§2 below) ───────────────┐
│  Design tokens? Both themes? EN+TR? iOS+Android? Animation?   │
│  Caching tier? Index + rule? Logging? Optimization?           │
└──────────────────────────────────────────────────────────────┘
            ↓
┌─ 5. IMPLEMENT ───────────────────────────────────────────────┐
│  Smallest correct change. Match conventions. No drift (§4).   │
└──────────────────────────────────────────────────────────────┘
            ↓
┌─ 6. VERIFY ──────────────────────────────────────────────────┐
│  flutter analyze lib/  → 0 errors (REQUIRED)                  │
│  flutter test test/i18n_parity_test.dart  → green (if i18n)   │
│  Other tests if logic changed.                                │
└──────────────────────────────────────────────────────────────┘
            ↓
┌─ 7. SYNC DOCS (§3 — THE GOLDEN RULE) ────────────────────────┐
│  If you changed code, update the docs/ file that covers it,   │
│  plus CLAUDE.md tables and TODO.md if scope/status changed.   │
└──────────────────────────────────────────────────────────────┘
```

---

## 2. Pre-Flight Checklist (the "Definition of Done")

Before you consider any task complete, every applicable box must be true.
This is the operational expansion of `CLAUDE.md`'s Definition of Done.

### Always
- [ ] **Read the design type first.** Before writing UI, read `docs/DESIGN_SYSTEM.md`.
      Never hand-roll a `Container`/`ElevatedButton`/hex color when a DS token or
      component exists. Use `AppPalette`, `AppText`, `AppSpacing`, `AppButton`, `AppCard`,
      `AppGlassCard`, `AppSheet`, etc.
- [ ] **`flutter analyze lib/` returns 0 errors.** Non-negotiable.
- [ ] **No silent `catch {}`.** Log via `debugPrint` (dev) + `CrashlyticsService` (real errors),
      with context (screen, uid, operation). See `CLAUDE.md` R4.

### Any user-visible string
- [ ] **EN + TR added together** in `assets/localization/{en,tr}.json`, same key, same change.
      Use the sequential Python `json.load → mutate → json.dump` pattern (never `sed`). See R9.
- [ ] **`flutter test test/i18n_parity_test.dart` passes** (CI gate).
- [ ] Key follows `screen.section.element` naming.

### Any UI
- [ ] **Dark + Light both correct.** No hardcoded colors — `AppPalette.of(context)` only.
- [ ] **iOS + Android both considered.** Platform-guard where needed (`Platform.isIOS`),
      respect safe areas, Cupertino gestures where they matter, haptics on meaningful actions.
      See `docs/PLATFORM.md`.
- [ ] **Smooth animation.** Use `AppMotion` durations/curves + `AnimationController` /
      implicit animations. Target 60fps. No abrupt state jumps, no jank.
- [ ] **All states designed:** loading (`AppShimmer`/`AppSkeleton*`), empty (`AppEmptyState`),
      error (`AppErrorState`), success, modals (`AppSheet`). No bare `CircularProgressIndicator`.
- [ ] **Accessibility:** glass/blur respects reduce-transparency; animations respect
      reduce-motion; interactive surfaces have semantic labels.
- [ ] **Performance:** `const` constructors, `RepaintBoundary` on heavy/animated list items,
      cancelled subscriptions in `dispose`, debounced inputs, paginated lists, image caching.

### Any data change
- [ ] **Caching tier chosen deliberately** (in-memory / Hive·SharedPrefs / Firestore). See R3.
- [ ] **Firestore index added** to `firestore.indexes.json` for any new query shape.
- [ ] **Security rule added** to `firestore.rules` / `storage.rules` for any new path.
      Never leave a collection unguarded.
- [ ] **Seed/migration** provided if reference data or backfill is needed (idempotent).
- [ ] **PII goes to the private subcollection** (`users/{uid}/private/nutrition`), never the
      public user doc. See `docs/DATA_MODEL.md`.

### Any personal-data access (LEGAL-FIRST — KVKK + GDPR)
> The founder treats data security & legal compliance as release blockers. Full framework:
> `docs/COMPLIANCE.md`. Mirror its §9 checklist here:
- [ ] **Identify the data.** What personal data does this touch? Is any **sensitive** (health,
      location, biometric)? Sensitive data needs **explicit consent** (açık rıza).
- [ ] **Disclose before access.** Show a `PermissionPrimer` / in-flow disclosure stating the
      **purpose**, **what data**, **whether it's stored**, the **KVKK/GDPR note**, and that the user
      **can decline** — *before* the OS dialog or processing. Reference impl:
      `gym_discovery_screen.dart::_activateNearMe` ("location not stored").
- [ ] **Minimize.** Prefer transient/on-device over storage. Don't persist what you don't need.
- [ ] **Legal basis + retention** recorded; update `docs/COMPLIANCE.md` §4 inventory.
- [ ] **Security:** owner-only rule, no PII on public docs/logs, nothing sensitive in plaintext logs.
- [ ] **New sub-processor / cross-border transfer?** → add to `COMPLIANCE.md` §5 + Privacy Policy.
- [ ] **Rights intact:** export/delete still cover the new data; graceful fallback if user declines.
- [ ] Legal copy (consent/disclosure) added **EN+TR**.

### Docs (see §3)
- [ ] **Relevant `docs/` file updated**, plus `CLAUDE.md` / `TODO.md` if needed.

---

## 3. The Golden Rule: Docs Stay In Sync With Code

**Documentation drift is the #1 failure mode of an AI-maintained codebase.** The whole point
of `docs/` is that the *next* agent trusts it instead of re-reading the repo. If you change
code and don't update the doc, you've poisoned that trust.

**When you change a file, update its owning doc — in the same task:**

| If you touch… | Update… |
|---|---|
| `lib/core/models/**`, `firestore.rules`, `firestore.indexes.json`, `storage.rules` | `docs/DATA_MODEL.md` |
| `lib/core/services/**`, `functions/index.js` | `docs/SERVICES.md` |
| `lib/screens/**`, `lib/main.dart`, routes, navigation | `docs/FRONTEND.md` |
| `lib/core/theme/**`, `lib/core/widgets/ds/**` | `docs/DESIGN_SYSTEM.md` |
| Any new/removed user-facing capability | `docs/FEATURES.md` **and** `README.md` (feature list + user guide) |
| iOS/Android config, platform guards | `docs/PLATFORM.md` |
| Anything touching personal data, consent, processors, or legal copy | `docs/COMPLIANCE.md` (+ legal docs) |
| `assets/localization/**`, the i18n system | `docs/LOCALIZATION.md` |
| Anything that changes a "Key Services / Files" table | `CLAUDE.md` |
| Task status, scope, roadmap | `TODO.md` |
| A shipped future-feature | move it out of `docs/roadmap/FUTURE_FEATURES.md` |

Keep doc edits **surgical and accurate** — add the row, fix the line, bump the count. Do not
rewrite a whole doc for a one-line code change. If a doc and the code disagree, the **code is
truth** — fix the doc and note it.

---

## 4. Anti-Drift Constraints (hard limits)

These prevent the agent from quietly degrading the architecture.

1. **Layer discipline.** UI (`screens/`, `widgets/`) → Providers (`core/providers/`) →
   Services (`core/services/`) → Models/Data (`core/models/`, `core/data/`).
   UI **never** calls Firebase directly — always through a service. Never import a UI widget
   into a model or service.
2. **Singletons for services.** `static final _instance = Foo._internal(); factory Foo() => _instance;`
   Never `new` a service.
3. **No speculative refactors.** Don't "clean up" working code unless the task asks for it.
   Prefer the smallest localized change. Don't span multiple layers in one unreviewable patch
   when you can split it.
4. **No new architectural layers** without explicit instruction. The structure in
   `ARCHITECTURE.md` is the structure.
5. **No raw colors / text styles / magic numbers** in UI — design tokens only.
6. **Shared-file write safety (R9).** Never let two parallel agents write the same
   `en.json`/`tr.json`/`firestore.*`/`storage.rules`. Serialize, or give each agent a disjoint
   file set. Localization edits are always sequential Python mutations.
7. **`mounted` check** before every `setState`/`context` use after an `await`.
8. **Graceful AI degradation.** Any AI feature must no-op cleanly when
   `AIService().isConfigured == false`.

---

## 5. Verification Commands

```bash
flutter analyze lib/                          # MUST be 0 errors before done
flutter test test/i18n_parity_test.dart       # after any localization change
flutter test                                  # full suite if logic changed
dart format lib/                              # CI enforces formatting
node scripts/load_test.js                     # AI proxy load test (needs PROXY_URL + ID_TOKEN)
```

CI (`.github/workflows/ci.yml`) runs on every PR: `dart format` check → `flutter analyze`
→ `flutter test` → Android debug build. Match it locally before you call a task done.

---

## 6. Parallel / Sub-Agent Work

For large multi-part features you may fan out to sub-agents (PM / architect / dev, or
per-subsystem). When you do:
- Give each agent a **disjoint file set** (R9). If two need the same shared JSON/rules file,
  serialize them or have one collect both changes and write once.
- Have each agent return **structured findings**, then synthesize and write once yourself.
- The `docs/` files were themselves built this way — keep them the single source of truth.

---

## 7. Where Everything Lives (top-level map)

```
cookrange/
├── CLAUDE.md            ← canonical engineering rules (R0–R9 + DoD)
├── AGENTS.md            ← THIS FILE — how to work
├── ARCHITECTURE.md      ← system architecture & layer map
├── README.md           ← product vision (human-facing)
├── TODO.md             ← roadmap & status (what's done / pending)
├── docs/
│   ├── INDEX.md            ← doc navigation
│   ├── DATA_MODEL.md       ← models, Firestore, indexes, rules, storage
│   ├── SERVICES.md         ← 75 services + 4 Cloud Functions
│   ├── FRONTEND.md         ← screens, navigation, routing
│   ├── DESIGN_SYSTEM.md    ← tokens, components, animation, a11y
│   ├── FEATURES.md         ← feature catalog (what exists, where)
│   ├── PLATFORM.md         ← iOS/Android parity & specifics
│   ├── LOCALIZATION.md     ← i18n system & how to add strings
│   ├── firebase-console-setup.md  ← console one-time steps
│   ├── generated/          ← auto/derived references (db schema, etc.)
│   └── roadmap/
│       ├── GO_LIVE.md          ← pre-launch checklist
│       └── FUTURE_FEATURES.md  ← future features + per-feature roadmaps
├── lib/                ← Flutter app (see ARCHITECTURE.md)
├── functions/          ← Node.js Cloud Functions (AI proxy, notif fan-out)
├── scripts/            ← load_test.js & one-off scripts
├── test/               ← unit + parity tests
├── assets/localization/← en.json, tr.json
└── firestore.rules · firestore.indexes.json · storage.rules · firebase.json
```

---

**TL;DR:** Read the map (`docs/`), think in 3 roles, satisfy the pre-flight checklist,
make the smallest correct change, verify with `flutter analyze`, and **update the doc you
just made stale.** That last step is what keeps this system alive.
