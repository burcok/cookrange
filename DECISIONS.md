# DECISIONS.md — Architecture Decision Records

> Why Cookrange is built the way it is. **Append-only**: never edit a decision's Context/Decision/
> Reason after the fact — supersede it with a new ADR and mark the old one `Superseded by ADR-nnn`.
>
> Read this before proposing a structural change. Most "obvious improvements" were already
> considered and rejected for a reason recorded here. If the reason no longer holds, that's a new
> ADR — not a silent refactor.

**Status values:** `Accepted` · `Superseded` · `Partially reverted` · `Under review`

> ⚠️ **Provenance.** No ADR log existed before 2026-07-31. ADR-001 … ADR-016 are **reconstructed**
> from the codebase, `docs/`, and commit history; their dates are the period the decision took
> effect, not a recorded decision date. They are accurate as to *what* was decided and *what the
> consequences have been*; treat the stated alternatives as reconstruction. ADR-017 onward are
> recorded live.

---

## ADR-001 — Flutter for both platforms

**Date:** 2025-06 (project inception) · **Status:** Accepted

**Context.** A solo founder needed a nutrition/fitness app on iOS and Android with heavy custom UI
(animated rings, glass surfaces, carousels) and 60fps expectations, on a startup budget.

**Decision.** Single Flutter/Dart codebase targeting iOS + Android.

**Reason.** One codebase for two stores at roughly one engineer's cost; Flutter's compositor gives
the custom, animation-dense design language the product needs without fighting a platform UI kit;
strong Firebase SDK support.

**Alternatives.** React Native (weaker for dense custom animation, heavier native bridge work) ·
native Swift + Kotlin (2× the surface for a solo dev — rejected on cost) · PWA (rejected: needs
push, IAP, camera, barcode, health-data UX).

**Consequences.** ✅ ~115k LOC serves both platforms. ⚠️ Every feature carries a two-platform test
obligation (`docs/PLATFORM.md`). ⚠️ Store-specific work (ATT, App Attest, Play Integrity, signing)
is still fully duplicated and is a live blocker (`BLK-02`, `BLK-16`).

---

## ADR-002 — Firebase as the backend

**Date:** 2025-06 · **Status:** Accepted

**Context.** Needed auth, a realtime database, file storage, push, crash reporting, and remote
config, with no ops capacity to run servers.

**Decision.** Firebase (Auth, Firestore, Storage, FCM, Remote Config, Crashlytics, Performance,
App Check) with Firestore as the source of truth. Custom logic in Cloud Functions only where the
client cannot be trusted.

**Reason.** Managed everything; realtime listeners map cleanly onto the app's live-updating UI;
security rules push authorization into the platform; generous free tier during pre-revenue.

**Alternatives.** Supabase/Postgres (relational fit is better for the marketplace, but weaker
realtime + mobile SDK maturity at the time) · custom Node + Postgres (rejected: ops burden) ·
AWS Amplify (rejected: heavier, worse Flutter story).

**Consequences.** ✅ No servers to run. ⚠️ Firestore reads are the dominant cost line — forced the
query discipline in `CLAUDE.md` §Performance. ⚠️ No joins or full-text search, so denormalization
is pervasive and search is an open gap (`PERF-08`). ⚠️ Vendor lock-in is real and accepted.

---

## ADR-003 — Provider for state management

**Date:** 2025-06 · **Status:** Accepted

**Context.** Needed app-wide session/theme/locale state without ceremony.

**Decision.** `provider` with `ChangeNotifier`. Seven providers, all in `lib/core/providers/`.
Not Riverpod, not Bloc.

**Reason.** Smallest concept count for a solo developer; first-party-adjacent and stable; the app's
state is genuinely simple (session, theme, locale, onboarding draft, nav index) because the
interesting state lives in Firestore streams consumed by `StreamBuilder`.

**Alternatives.** Riverpod (compile-safe, testable, but a second mental model on top of Provider) ·
Bloc (event/state ceremony unjustified at this size) · `setState` only (rejected: cross-screen
session state).

**Consequences.** ✅ Low overhead, easy onboarding. ⚠️ No compile-time safety on provider lookup.
⚠️ Rebuild discipline is manual — hence the `Selector`-over-`watch` rule (`CLAUDE.md` R1).

---

## ADR-004 — Services as hand-rolled singletons

**Date:** 2025-06 · **Status:** Accepted, with a known cost — see Consequences

**Context.** ~75 service objects wrap all Firebase and business logic. They needed a single shared
instance and simple call sites.

**Decision.** `static final _instance = Foo._internal(); factory Foo() => _instance;` — call
`Foo()` anywhere. No DI container, no interfaces.

**Reason.** Zero boilerplate, zero wiring, no dependency graph to maintain. Fastest path to feature
velocity for one developer.

**Alternatives.** `get_it` service locator · constructor injection · Riverpod providers as the DI
seam. All rejected at the time as ceremony.

**Consequences.** ⚠️ **This is the single largest source of the project's 2/10 testing score.** With
no interface and no injection point, a service cannot be faked, so no screen or service is unit
testable without live Firebase. Recorded as `ARCH-04`. Any future testability work starts by
extracting interfaces behind these singletons — a large, mechanical, and unavoidable refactor.
Do **not** add new services without considering whether they need a seam.

---

## ADR-005 — Repository layer: adopted, then left incomplete

**Date:** 2025-08 · **Status:** ⚠️ Partially reverted

**Context.** Four repositories (`dish`, `food_log`, `meal_plan`, `shopping`) were introduced to sit
between services and models as in-memory caches.

**Decision.** As shipped: repositories exist for four domains only; every other domain has services
talking to Firestore directly.

**Reason (for the original adoption).** Cache hot reads and give a seam for offline behaviour.

**Consequences.** ⚠️ The layer is **inconsistent** — two ways to reach data depending on domain,
which is worse than either alone. New code should follow the surrounding domain's existing pattern
and **not** extend the repository layer piecemeal. Resolving this (complete it or remove it) is
tracked in `TODO.md` §4, and it is one of the named drags on the architecture score in
`PROJECT_STATE.md` §2.

---

## ADR-006 — AI through OpenRouter behind a Cloud Function proxy

**Date:** 2025-10 · **Status:** Accepted

**Context.** The app makes LLM calls for meal plans, recipes, chat, insights, and food analysis. An
API key in a mobile binary is extractable, and unbounded LLM calls are a denial-of-wallet risk.

**Decision.** OpenRouter as the LLM gateway, reached **only** through the `aiProxy` Cloud Function
in release. The proxy holds the key, picks the model server-side, enforces quota in a Firestore
transaction, rate-limits per uid, and meters real token cost.

**Reason.** OpenRouter abstracts model choice behind one API, so the model is a config value rather
than a code change. The proxy is the only place a per-user quota can be enforced honestly, and it
keeps the key off the device.

**Alternatives.** Direct OpenAI/Anthropic SDK from the client (rejected: key exposure, no quota) ·
a dedicated inference server (rejected: ops) · on-device models (rejected: quality + size).

**Consequences.** ✅ Model, token cap, and quota change from the admin panel with no redeploy
(ADR-011). ✅ Real per-request cost accounting. ⚠️ `aiProxy` is a single point of failure for every
AI feature. ⚠️ The debug-only client key path still exists and is currently shipping — `BLK-15`.

---

## ADR-007 — `in_app_purchase` + own receipt validation, **not** RevenueCat

**Date:** 2026-01 · **Status:** Accepted

**Context.** Premium subscriptions (monthly/yearly) plus a consumable AI-credit pack, on both
stores, with entitlements the client must not be able to forge.

**Decision.** Flutter's first-party `in_app_purchase` plugin on the client; **own** validation in
Cloud Functions (`purchases.js`) against the Apple App Store Server API and the Google Play
Developer API, with purchase-token dedupe (`processed_purchases`) and store webhooks
(`appStoreNotifications`, `playRtdn`) to revoke on refund/chargeback/expiry. Entitlements are
written server-side only to `entitlements/{uid}`.

**Reason.** No per-transaction fee or MRR-based pricing on a pre-revenue product; no third-party
processor in the path holding entitlement truth; the server-authoritative model (ADR-008) already
required Cloud Functions, so validation had a home.

**Alternatives.** **RevenueCat** — the obvious managed option: it would have supplied receipt
validation, webhooks, entitlements, and subscription analytics out of the box, and would have
removed most of `BLK-04`'s remaining work. Rejected on cost-at-scale and on unwillingness to put a
third party between the user and entitlement truth. **This trade should be revisited if
monetization stays blocked** — the build-it-ourselves path is complete in code but has never
processed a real transaction. Also considered: Adapty (same trade), server-less client-trusted
grants (rejected outright — forgeable).

**Consequences.** ✅ No revenue share, full control, entitlements provably server-only. ⚠️ We own
receipt-validation correctness, store-notification handling, and subscription-state edge cases
(grace periods, billing retry, upgrades) — none of which has been exercised against a real store.
⚠️ Requires Apple `.p8` + Play service-account credentials before anything can be tested (`BLK-04`).
⚠️ No subscription analytics; the admin cost dashboard estimates revenue rather than reading it.

---

## ADR-008 — Server-authoritative trust boundary

**Date:** 2026-06-30 · **Status:** Accepted

**Context.** A security audit found the client could self-grant premium, mint AI credits, self-refer,
forge commissions, and self-unban, because all of that state lived on the client-writable user doc.

**Decision.** The client **renders** state and is never the authority for anything of value or
safety. Premium, AI credits, the referral/commission economy, purchase validation, ban state, and
account erasure move into Cloud Functions with Admin SDK writes; Firestore rules field-lock the user
doc and make the server-owned collections owner-read / server-write.

**Reason.** Any value-bearing field a client can write will eventually be written by a client.

**Alternatives.** Tighter client-side rules alone (rejected: rules cannot validate a purchase
receipt or a referral graph) · trusting the client pre-launch and fixing later (rejected: the
economy would already be poisoned).

**Consequences.** ✅ A coherent, auditable trust model — the strongest part of the codebase's design.
⚠️ **Deploy order is now load-bearing**: server write paths (`S2`→`S3`→`S4`) must ship *before* the
rules lock (`S1`, `S5`), or live flows break. ⚠️ Code-complete but **not activated** — all 18 gates
`S0`–`S17` are open, App Check is unenforced, and the design's guarantees currently hold on paper
only. See `docs/SECURITY.md`.

---

## ADR-009 — PII split into an owner-only subcollection

**Date:** 2025-09 · **Status:** Accepted

**Context.** `users/{uid}` is readable by any authenticated user (needed for profiles, mentions,
leaderboards). Onboarding collects height, weight, gender, birth date, allergies, and dietary
restrictions — health data, special-category under KVKK Art. 6 and GDPR Art. 9.

**Decision.** Health PII lives in `users/{uid}/private/nutrition`, owner-only at the rules layer.
`OnboardingProvider` splits writes via `_toPublicMap()` / `_toPrivateMap()`; `UserProvider` merges
on read so callers see one object.

**Reason.** Special-category data must not be world-readable. Splitting at the storage layer makes
the guarantee structural rather than a UI convention.

**Alternatives.** Field-level rules on one doc (Firestore cannot do per-field reads) · encrypting
PII in the user doc (key management on-device, breaks queries) · a separate top-level collection
(equivalent; subcollection keeps erasure recursive and simple).

**Consequences.** ✅ Health data is structurally owner-only and erasure stays a subtree delete.
⚠️ Every read needs two fetches, merged. ⚠️ The *public* doc still leaks `email`, `last_login_ip`,
and device fingerprints — the same principle applied only halfway. That is `BLK-10`.

---

## ADR-010 — Notifications store structure, never text

**Date:** 2025-11 · **Status:** Accepted

**Context.** A notification written in the actor's language, at write time, is wrong for a reader in
the other language and goes stale when the actor renames themselves.

**Decision.** `NotificationService` persists only structured fields (`type`, `actorUid`, `actorName`,
`actorPhotoUrl`, `relatedId`, `metadata`). `NotificationPresenter` renders title/body/icon/colour on
the **reader's** device from `notifications.feed.*` keys. Legacy docs fall back to stored text.

**Reason.** Correct language and current actor identity at read time, in a bilingual product.

**Alternatives.** Store both languages (doubles writes, still stale on rename) · render server-side
(the server doesn't know the reader's current locale).

**Consequences.** ✅ Always correct language, always current name. ⚠️ New notification types need
EN+TR keys before they can render at all. ⚠️ Push payloads (built in Cloud Functions) still need
their own localization path.

---

## ADR-011 — `app_config/global` as the remote-config surface

**Date:** 2026-07 · **Status:** Accepted (supersedes scattered Firebase Remote Config usage)

**Context.** Operational levers were spread across Firebase Remote Config, an admin-only
`admin_config` doc, and hardcoded constants. Changing the AI model meant a redeploy; the client and
`aiProxy` could disagree about which model was in use.

**Decision.** One public-read / admin-write Firestore doc, `app_config/global`, holding `ai`,
`version`, `maintenance`, `announcement`, `features` (kill-switches), `rollout`, `limits`, and
`endpoints`. **No secrets.** Read by `AppConfigService` on the client (cache-first, 6h TTL) *and* by
`aiProxy` server-side (5-min cache).

**Reason.** One document both sides read means they cannot disagree. Firestore gives an admin UI,
audit logging, and instant propagation that Remote Config's publish cycle does not.

**Alternatives.** Firebase Remote Config alone (server-side reads awkward; no admin-panel editing;
no audit trail) · env vars in Functions (needs a redeploy — the exact problem).

**Consequences.** ✅ Model, token caps, quotas, version gates, maintenance mode, announcements, and
feature kill-switches all change from the admin panel with no redeploy. ✅ A working incident lever.
⚠️ Public-read, so **nothing secret may ever go in it**. ⚠️ A bad admin write can degrade every
client at once — every field has a fail-safe default and kill-switches default **on**.

---

## ADR-012 — Consumer-only v1; gym/coach deferred to M6

**Date:** 2026-07-31 · **Status:** Accepted

**Context.** Gym, coach, programs, marketplace, commissions and payouts total ~25,000 LOC across 19
screens. All of it is blocked on the same two defects (`BLK-05`, `BLK-03`) and serves zero validated
demand. Solo path to launch was 4–6 months.

**Decision.** Cut all six domains from v1.0. They stay in the codebase behind
`AppConfigService.isFeatureEnabled` kill-switches — **not deleted** — and launch in M6 after the
consumer product proves retention.

**Reason.** Removes `BLK-07`, `BLK-09`, the payout gap, and most of `BLK-05`'s blast radius, taking
the solo path to 2.5–3.5 months. The three-sided marketplace is the most strategically valuable
asset in the codebase, which is exactly why it should launch against a proven consumer base rather
than alongside an unvalidated one.

**Alternatives.** Ship everything (rejected: doubles the blocker surface and the review risk) ·
delete the code (rejected: destroys the M6 asset).

**Consequences.** ✅ Halves the path to launch. ⚠️ Kill-switched code still needs to compile, still
carries security rules, and still rots — budget maintenance for it. ⚠️ Docs must keep describing it
(`GYM_ECOSYSTEM.md`, `COACH_ECOSYSTEM.md`) while `PROJECT_STATE.md` marks it deferred.

---

## ADR-013 — Onboarding runs before registration

**Date:** 2026-06 · **Status:** Accepted

**Context.** Post-registration onboarding put a 14-page form between a fresh account and any value,
and account creation before any demonstrated value maximised drop-off.

**Decision.** Invert the flow: intro carousel → 14 onboarding pages → register → meal-plan
generation → home. `OnboardingProvider` accumulates everything **in memory with no uid**;
`OnboardingCompletion.finalizeAndRoute` persists once an account exists. The same flow runs in
`loggedInCompletion` mode for accounts with `onboarding_completed == false`.

**Reason.** Show the personalized projection (BMI, macros, goal ETA) *before* asking for an account.

**Alternatives.** Anonymous Firebase accounts then link (rejected: orphaned-account cleanup, quota
noise) · shorter onboarding (rejected: the projection needs the inputs).

**Consequences.** ✅ Value before commitment. ⚠️ All onboarding state is in memory — a crash before
registration loses it. ⚠️ Two persistence entry points must stay behaviourally identical, hence the
shared `OnboardingCompletion` tail. ⚠️ Legacy post-registration onboarding was fully removed.

---

## ADR-014 — EN/TR parity enforced by a CI test

**Date:** 2025-07 · **Status:** Accepted

**Context.** Turkey is the primary market; English is required for the store and for growth. A
missing key renders a raw key path to a user.

**Decision.** Two JSON files (`en.json`, `tr.json`), both updated in the same change, with
`test/i18n_parity_test.dart` failing CI on any key present in one and absent from the other.
Localization edits are sequential Python `json.load → mutate → json.dump` — never `sed`, never two
parallel writers (`CLAUDE.md` R9).

**Reason.** Parity is mechanically checkable, so it should be a gate, not a discipline.

**Alternatives.** ARB + `flutter_gen` (codegen friction for a two-locale app) · a translation
platform (unjustified at this size).

**Consequences.** ✅ 2,722 keys at exact parity — the highest-quality subsystem in the project.
⚠️ Adding a third locale means a real migration (`LOCALIZATION.md` §6). ⚠️ R9 exists because
parallel writers silently dropped keys once already.

---

## ADR-015 — A token-based design system, and no raw styling

**Date:** 2025-12 · **Status:** Accepted

**Context.** Ad-hoc `Container`/`ElevatedButton`/hex colours made dark mode and a coherent look
impossible to guarantee screen by screen.

**Decision.** Semantic tokens (`AppPalette`, `AppText`, `AppSpacing`, `AppRadius`, `AppMotion`) plus
a component library in `lib/core/widgets/ds/` behind one barrel import. Raw colours and text styles
in UI are forbidden (`CLAUDE.md` R6/R7).

**Reason.** Theme correctness becomes structural: a screen built from tokens is correct in both
themes by construction.

**Alternatives.** Material 3 theming alone (insufficient for the glass/mesh language) · per-screen
styling (the problem).

**Consequences.** ✅ 14 components over semantic token layers; both themes fully defined.
⚠️ Enforcement is by review only, and it has leaked: **120 hex literals + 214 `Colors.white/black`
in `lib/screens`**. A lint rule is the real fix (`TODO.md` §39).

---

## ADR-016 — Three explicit caching tiers

**Date:** 2025-09 · **Status:** Accepted

**Context.** Firestore reads are the dominant cost line, and defaulting every piece of state to a
live listener is how that bill runs away.

**Decision.** Every piece of state is consciously assigned to one of three tiers — in-memory
(session, cheap to recompute) · Hive/SharedPreferences (device-scoped, survives restart) · Firestore
(source of truth, cross-device, auditable) — with stale-while-revalidate preferred. Codified as
`CLAUDE.md` R3, with hard query rules: always `.limit()`, counts via `count()`/`pollCount`, no N+1,
cancel subscriptions in `dispose`.

**Reason.** Cost and correctness are both decided at this choice, so it must be deliberate rather
than default.

**Alternatives.** Firestore for everything (cost) · aggressive local caching everywhere (staleness
and conflict complexity without an offline write queue).

**Consequences.** ✅ `pollCount()` at 28 sites, zero count anti-patterns, pagination throughout.
⚠️ Hive boxes needed encryption once health data entered them (done, AES-256). ⚠️ No offline write
queue and no conflict resolution — the tier model covers reads far better than writes (`ARCH-07`).

---

## ADR-017 — Documentation as the primary agent context

**Date:** 2026-07-31 · **Status:** Accepted

**Context.** The codebase is ~115k LOC across 329 files — far beyond any context window. Agents were
orienting by scanning the repository, which is slow, expensive, and unreliable. Worse, the docs that
did exist asserted features as shipped that do not actually work, so an agent reading them was
confidently misinformed.

**Decision.** A routed documentation system: four bootstrap files (`PROJECT_STATE.md`,
`docs/INDEX.md`, `CLAUDE.md`, `AGENTS.md`) plus ~20 single-responsibility documents loaded on demand
via the `INDEX.md` task router. **Status is separated from description**: `PROJECT_STATE.md` owns
what works; every other doc owns how something is built and makes no claim about whether it runs.

**Reason.** Reading three routed documents beats scanning fifty files, and a doc that quietly
overstates reality is worse than no doc — it converts a research problem into a wrong answer.

**Alternatives.** One large context file (blows the window; no selective loading) · generated docs
from source (captures structure, not intent or status) · no docs, agent explores (the status quo
being replaced).

**Consequences.** ✅ A task-scoped read costs 3–5 documents instead of a repository scan.
⚠️ The system is only as good as its maintenance — a stale router is worse than none, so the
same-task doc-update rule (`AGENTS.md` §4) is load-bearing. ⚠️ Contributors must resist restating
status inside feature docs; that is the specific drift that made the previous docs misleading.

---

## Recording a new decision

Append at the end. Use the next ID. Keep it to the seven headings:

```markdown
## ADR-0nn — <short imperative title>

**Date:** YYYY-MM-DD · **Status:** Accepted

**Context.** What forced a choice.
**Decision.** What we chose, concretely.
**Reason.** Why this one.
**Alternatives.** What else, and why not.
**Consequences.** What this buys (✅) and what it costs (⚠️) — including the costs you expect to
regret. An ADR with no ⚠️ is not finished.
```

A change is ADR-worthy when it constrains future work: a layer, a dependency, a trust boundary, a
data-shape commitment, or a scope cut. Bug fixes and features are not ADRs — they are `TODO.md`.
