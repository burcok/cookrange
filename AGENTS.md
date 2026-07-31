# AGENTS.md — How to Work

> **`CLAUDE.md` says what the rules are. This says how to apply them.**
> Read `CLAUDE.md` first, then find your role in §3.

---

## 1. The per-prompt workflow

Run this on every non-trivial task. Do not skip steps.

```
1. ORIENT      PROJECT_STATE.md — is this area working, blocked, or deferred?
                  ↓
2. ROUTE       docs/INDEX.md §2 — which 1–3 docs does this task need?
                  ↓
3. LOAD        Read those docs. Then, and only then, the source files they name.
                  ↓
4. ROLE        Identify your role (§3). Think PM → Architect → Developer (R0).
                  ↓
5. CHECK       Run your role's pre-flight checklist (§3) + the shared one (§2).
                  ↓
6. IMPLEMENT   Smallest correct change. Match surrounding conventions.
                  ↓
7. VERIFY      flutter analyze lib/ → 0 errors. Tests if logic or strings changed.
                  ↓
8. SYNC DOCS   Update the owning doc (§4). PROJECT_STATE.md if status moved.
                  ↓
9. REPORT      What you did, what you verified, what you did NOT verify.
```

Step 9 matters as much as step 6. An unverified change reported as done is how this project reached
84 % written / 45 % working.

---

## 2. Shared pre-flight checklist

Applies to every role. Role-specific items are in §3.

**Always**
- [ ] `flutter analyze lib/` → **0 errors**
- [ ] No silent `catch {}` — log with context or handle it (R4)
- [ ] Smallest change that is correct; no drive-by refactors
- [ ] The owning doc updated in this same task

**Any user-visible string**
- [ ] EN **and** TR added together, key `screen.section.element`
- [ ] Sequential Python `json.load → mutate → json.dump` — never `sed`, never parallel writers (R9)
- [ ] `flutter test test/i18n_parity_test.dart` passes

**Any UI**
- [ ] Dark **and** light correct — `AppPalette.of(context)`, no hex
- [ ] iOS **and** Android considered — safe areas, gestures, haptics
- [ ] Loading / empty / error / success states all designed (`AppShimmer`, `AppEmptyState`, `AppErrorState`)
- [ ] Motion via `AppMotion`; reduced-motion and reduced-transparency respected
- [ ] `const` constructors, `RepaintBoundary` on heavy items, subscriptions cancelled

**Any data change**
- [ ] Caching tier chosen deliberately (R3)
- [ ] Composite index added for every new query shape
- [ ] Security rule added for every new path — **never leave one unguarded**
- [ ] PII to `users/{uid}/private/nutrition`, never the public doc
- [ ] Idempotent seed or migration if reference data / backfill is needed

**Any personal-data access — legal-first**
- [ ] Identified the data; is any of it special-category (health, location, biometric)?
- [ ] Disclosure **before** access: purpose, what data, whether it's stored, KVKK/GDPR note, real decline path
- [ ] Minimized — transient/on-device preferred over stored
- [ ] Legal basis + retention recorded in `docs/COMPLIANCE.md` §4
- [ ] Export and deletion still cover the new data
- [ ] New sub-processor or cross-border transfer → `COMPLIANCE.md` §5 + Privacy Policy
- [ ] Consent/disclosure copy in EN **and** TR

---

## 3. The eight roles

Pick the role matching your task. Multi-domain tasks run the checklists of each role they touch.
Roles are review lenses, not permissions — but the **Must not touch** column is a hard boundary:
changing something there is a separate, explicitly-scoped task.

---

### 3.1 Architecture Agent

**Owns** `docs/ARCHITECTURE.md`, `DECISIONS.md`, layer boundaries, `lib/` structure.

**Responsibilities.** Decide where new code lives. Protect the four-layer vertical. Judge whether a
change needs an ADR. Choose the caching tier. Define implementation order for multi-part work.

**May change** directory structure, provider composition, service boundaries, `DECISIONS.md`.
**Must not touch** security rules (→ Security/Firebase Agent), UI styling (→ Frontend Agent).

**Review checklist**
- [ ] UI → Provider → Service → Model direction preserved; no UI importing `cloud_firestore`
- [ ] New service is a singleton; nothing `new`s a service
- [ ] No new architectural layer introduced without explicit instruction
- [ ] The repository layer was **not** extended piecemeal (ADR-005)
- [ ] Caching tier chosen and justified (R3)
- [ ] Does this constrain future work? → append an ADR. Does it reverse one? → supersede, don't edit
- [ ] No new god object; if a file passes ~800 LOC, say so even if you don't split it

---

### 3.2 Security Agent

**Owns** `docs/SECURITY.md`, the threat model, `firestore.rules` / `storage.rules` intent, secrets.

**Responsibilities.** Keep the client untrusted. Review every new path, field, and endpoint for
who can read/write it. Guard the ADR-008 deploy order. Own the `S0`–`S17` gate list.

**May change** rules, Cloud Function auth logic, App Check config, `docs/SECURITY.md`.
**Must not** relax a rule to unblock a client feature — fix the client or move the write server-side.

**Review checklist**
- [ ] Every new path has an explicit rule; default is deny
- [ ] No value-bearing field is client-writable (`subscription_*`, `ai_credits_*`, `user_roles`,
      `is_banned`, `referral_used`, commissions, reward-gating counters)
- [ ] Content-length caps on all user-authored free text
- [ ] No secret in client code, a bundled `.env`, a doc, or a log
- [ ] No PII in analytics events, logs, or the world-readable user doc
- [ ] Auth checked server-side, not just hidden in the UI
- [ ] Rate limiting / abuse path considered for anything user-triggerable
- [ ] **Deploy order:** server write paths before rules lock — locking first breaks live flows
- [ ] If this closes an `S`-gate or a `BLK`, update `PROJECT_STATE.md`

---

### 3.3 Frontend Agent

**Owns** `lib/screens/`, `lib/core/widgets/`, `docs/FRONTEND.md`, `docs/DESIGN_SYSTEM.md`.

**Responsibilities.** Build screens and components. Own every visual state. Keep both themes, both
locales, and both platforms correct.

**May change** screens, widgets, DS components, routes, transitions.
**Must not** call Firebase directly, or put business logic in a widget.

**Review checklist**
- [ ] Design tokens only — zero hex, zero raw `TextStyle`, zero magic numbers
- [ ] Dark **and** light verified
- [ ] Loading / empty / error / success / modal all designed — no bare spinner, no grey error text
- [ ] EN + TR keys added; nothing hardcoded in either language
- [ ] iOS + Android: safe areas, keyboard insets, back gesture, haptics
- [ ] `const` constructors; `RepaintBoundary` on heavy or animated list items
- [ ] `Selector` over broad `watch`; inputs debounced
- [ ] Every subscription cancelled in `dispose`; `mounted` checked after every `await`
- [ ] Images via `AppImage` / `CachedNetworkImageProvider` — never raw `Image.network`
- [ ] Accessibility: semantic labels, reduced-motion, reduced-transparency, touch targets ≥ 44pt

---

### 3.4 Backend Agent

**Owns** `functions/`, `docs/API.md`, server-side business logic.

**Responsibilities.** Write Cloud Functions. Own the client↔server contract. Keep authoritative
logic on the server.

**May change** `functions/**`, callable/HTTPS signatures, triggers, `docs/API.md`.
**Must not** change Firestore rules without the Security Agent's checklist, or break a deployed
contract without a client migration path.

**Review checklist**
- [ ] Auth verified in-code: Firebase ID token **and** App Check
- [ ] Input validated and size-capped; never trust a client-supplied model, price, amount, or uid
- [ ] Idempotent — a retried call must not double-grant, double-charge, or double-write
- [ ] Fails **closed**: on error, deny rather than grant
- [ ] Writes wrapped in a transaction where two callers could race
- [ ] Errors logged with context; the client gets a safe message, never a stack trace
- [ ] Cold-start and `maxInstances` considered; no unbounded fan-out
- [ ] Contract change reflected in `docs/API.md` **and** the calling Dart service
- [ ] Deploys land cross-region on this project — verify in the console, don't trust the CLI exit

---

### 3.5 Firebase Agent

**Owns** `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `docs/DATABASE.md`, collection shape.

**Responsibilities.** Own the data model on the server side: paths, indexes, rules, quotas, cost.
This role exists separately from Backend because Firestore's cost and rules model is its own
discipline.

**May change** collection shape, indexes, rules, storage paths, seeders, migrations.
**Must not** rename a field in a live collection without a migration, or "fix" the snake/camel
convention mismatch — it is deliberate and documented.

**Review checklist**
- [ ] Path and doc shape recorded in `docs/DATABASE.md` in this same task
- [ ] Composite index added for **every** new `where` + `orderBy` combination
- [ ] Rule added and scoped as tightly as the feature allows
- [ ] Every query has `.limit()`; no unbounded `.snapshots()`
- [ ] Counts via `count()` / `pollCount()`, never `.snapshots().map((s) => s.size)`
- [ ] No N+1 read loop — batch with `whereIn` (≤ 30) or denormalize
- [ ] Denormalized fields have a defined writer and stay consistent
- [ ] Field naming matches the collection's existing convention (see `CLAUDE.md` §9)
- [ ] Seeder is idempotent; migration is versioned, idempotent, and logged
- [ ] Storage paths have size and content-type limits

---

### 3.6 AI Agent

**Owns** `lib/core/services/ai/`, `functions/index.js` (`aiProxy`), `docs/AI_SYSTEM.md`, prompts.

**Responsibilities.** Own prompt quality, model routing, cost, quota, and safe degradation. AI
output here becomes health guidance, so correctness is a safety property.

**May change** prompts, model config, proxy logic, credit accounting, parsing.
**Must not** ship an AI path that fabricates content when unconfigured, or let user text reach a
prompt unfenced.

**Review checklist**
- [ ] **Degrades gracefully** — guards `AIService().isConfigured`, and never substitutes mock or
      hardcoded content for a real response in release (`BLK-01` is exactly this failure)
- [ ] User-supplied text is fenced and treated as data — prompt-injection guard applied
- [ ] Output parsed defensively; malformed JSON handled, never trusted blindly
- [ ] Allergen / safety filters applied **before** the model sees candidates, and on its output
- [ ] Quota checked and consumed server-side; credit rolled back on failure
- [ ] Call tagged with a `type` so per-request cost lands in `ai_usage_logs`
- [ ] Model, `max_tokens`, temperature read from `app_config/global` — not hardcoded, not client-sent
- [ ] Token cost of a prompt change estimated; the 180-dish prompt ceiling respected
- [ ] Locale honoured — the user gets output in their language

---

### 3.7 Testing Agent

**Owns** `test/`, `docs/TESTING.md`, CI quality gates.

**Responsibilities.** Make correctness provable. At ~1 % coverage with `test/` gitignored, this role
is currently the highest-leverage one in the project.

**May change** tests, test fixtures, CI test config, `.gitignore`'s test entry.
**Must not** weaken or delete a test to make a build pass.

**Review checklist**
- [ ] New pure logic has a unit test — calculators, parsers, schedulers, filters, safety checks
- [ ] The test actually fails when the logic is broken (verify by breaking it)
- [ ] Edge cases covered: empty, null, boundary, timezone, locale
- [ ] No test depends on network, wall-clock time, or live Firebase
- [ ] Tests are deterministic — no ordering dependence, no flake
- [ ] The full suite was **run**, and the real result reported
- [ ] Coverage change noted in `docs/TESTING.md` if meaningful
- [ ] Untestable-by-design code (ADR-004) is called out rather than skipped silently

---

### 3.8 Documentation Agent

**Owns** every `.md`. Guardian of the system in `docs/INDEX.md`.

**Responsibilities.** Keep docs true, routed, and non-duplicated. Documentation drift is the failure
mode that makes every other agent unreliable.

**May change** any doc, the router, doc structure.
**Must not** create a new document when an existing one owns the topic, or restate a fact that lives
elsewhere.

**Review checklist**
- [ ] The fact lives in exactly **one** doc; everything else links to it
- [ ] Status went to `PROJECT_STATE.md` — not into a feature doc
- [ ] No feature described as working on the strength of it having been written
- [ ] `docs/INDEX.md` §2 routes to the doc; §3 lists its owned source paths
- [ ] Edit is surgical — a row, a line, a count. Not a rewrite for a one-line change
- [ ] Links resolve; no reference to a moved or deleted file
- [ ] A structural decision produced an ADR in `DECISIONS.md`
- [ ] `CHANGELOG.md` updated if this is a release or a structural change
- [ ] Nothing new added to `CLAUDE.md` that isn't a rule

---

## 4. The golden rule: docs sync in the same task

**Documentation drift is the #1 failure mode of an AI-maintained codebase.** The whole point of
`docs/` is that the next agent trusts it instead of re-reading the repo. Change code without
updating its doc and you've poisoned that trust for everyone after you.

The routing table lives in [`CLAUDE.md`](CLAUDE.md) §7. Two rules restated because they are the ones
that broke last time:

1. **Status has exactly one home** — `PROJECT_STATE.md`. Feature docs describe construction, never
   condition.
2. **Written ≠ working.** Do not promote a system to "verified working" because you just wrote it.

Keep edits surgical. If a doc and the code disagree, **the code is truth** — fix the doc and say so.

---

## 5. Anti-drift constraints

Hard limits that stop the architecture degrading one reasonable-looking change at a time.

1. **Layer discipline** — UI → Providers → Services → Models. UI never calls Firebase.
2. **Singletons for services.** Never `new` one.
3. **No speculative refactors.** Don't clean up working code the task didn't name.
4. **No new layers** without instruction.
5. **No raw colors, text styles, or magic numbers** in UI.
6. **R9 shared-file safety** — disjoint file sets for parallel agents; localization edits sequential.
7. **`mounted` check** after every `await` before `setState` or `context`.
8. **Graceful AI degradation** — no-op cleanly when `isConfigured == false`; never fabricate.
9. **Never widen scope silently.** If the right fix is bigger than the task, say so and let the user
   decide — don't quietly do it, and don't quietly skip it.

---

## 6. Verification commands

```bash
flutter analyze lib/                          # MUST be 0 errors before done
flutter test test/i18n_parity_test.dart       # after any localization change
flutter test                                  # full suite if logic changed
dart format lib/                              # CI enforces formatting
node scripts/load_test.js                     # AI proxy load test (needs PROXY_URL + ID_TOKEN)
```

CI runs on every PR: `dart format` → `flutter analyze` → `flutter test` → Android debug build.
**CI is currently red on `main` (`BLK-13`)** — don't read a green local run as a green pipeline.
Details: [`docs/DEVOPS.md`](docs/DEVOPS.md), [`docs/TESTING.md`](docs/TESTING.md).

---

## 7. Parallel and sub-agent work

For large multi-part features you may fan out (by role, or by subsystem). When you do:

- **Disjoint file sets per agent (R9).** If two need the same shared file — `en.json`, `tr.json`,
  `firestore.rules`, `firestore.indexes.json`, `storage.rules` — serialize them, or have one agent
  collect both changes and write once. This rule exists because parallel writers silently dropped
  localization keys.
- Have each agent return **structured findings**; synthesize and write yourself.
- Give each agent its **role checklist** from §3 — that's what the roles are for.
- One agent owns `PROJECT_STATE.md` for the whole operation. Never let two update status.

---

**TL;DR** — Orient in `PROJECT_STATE.md`, route through `docs/INDEX.md`, work your role's checklist,
make the smallest correct change, verify it, update the doc you just made stale, and report honestly
what you did and did not confirm.
