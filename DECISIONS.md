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

## ADR-018 — Group-chat fan-out reads live membership, never denormalizes it onto the chat doc

**Date:** 2026-08-05 · **Status:** Accepted

**Context.** Faz 2 §2.3 paired every `community_groups/{id}` with a `chats/{id}` doc so a group's
messages could reuse `ChatService` unchanged. That chat doc's `participants` array is set once at
creation (`CommunityGroupService.createGroup`: `[owner.uid]`) and never touched again —
`joinGroup`/`approveJoinRequest`/`redeemGroupInvite`/`kickMember`/`banMember` all write
`community_groups/{id}/members`, not this array. `onChatMessageCreated` (push + `unreadCounts`
fan-out) read `participants` directly, so every group member besides the owner silently never got a
notification or an unread count (Faz 2 §2.4 found and closed this).

**Decision.** The fix reads `community_groups/{groupId}/members` (excluding `banned`) at fan-out
time via the Admin SDK, instead of keeping `participants` in sync. Any future server-side code that
needs "who can see this group chat" should do the same: read the `members` subcollection live, never
denormalize group membership into the chat doc's `participants` array.

**Reason.** `participants` is deliberately client-immutable (`canUpdateChatMeta()`, Faz 2 §2.1 —
closing a chat-hijack hole where any participant could add/remove others). Keeping it "correct" for
groups would mean either reopening that rule or funnelling every join/leave/kick/ban/invite-redeem
through a new dedicated server path just to maintain a second copy of membership that already lives
in `members`. Reading `members` directly costs one extra Admin-SDK query (uncapped on purpose — a
notification fan-out that silently drops a real member on a `.limit()` is the same class of bug this
ADR exists to prevent) and needs no rules change, since Admin SDK bypasses rules and `members` is
already the single source of truth `canAccessGroupChat()` itself reads.

**Alternatives.** Denormalize: write `participants` (or a separate `recipient_uids` array) on every
membership-changing call site — rejected for the reasons above, plus every miss is a silent,
unrecoverable notification/unread-count gap for exactly the member it affects, discovered only by a
user complaint, not a test. Cap the `members` read with `.limit()` — rejected: correctness for a
"notify everyone" feature requires everyone, not a page of them.

**Consequences.** ✅ One source of truth for group membership; access control and notification
fan-out can never drift apart. ✅ No rules change, no new index. ⚠️ Cost is O(group size) per
message, same order as the per-recipient FCM/token lookups already done — acceptable today, but a
very large or very chatty group would be the first place to look if Cloud Function cost or latency
for this trigger ever becomes a concern. ⚠️ `unreadCounts` on the chat doc still accumulates a stale
key for a member who is later kicked/banned (harmless — they lose `canAccessGroupChat()` regardless
— but not cleaned up); left as a known, minor hygiene gap, not fixed here.

---

## ADR-019 — Abuse-rate limiting for reports/moderation/appeals: reactive trigger + rules lock, not a write-gating callable

**Date:** 2026-08-05 · **Status:** Accepted

**Context.** Faz 2 §2.6 needed a server-side rate limit on report filing, group moderation actions
(`kickMember`/`banMember`/`muteMember`/`unmuteMember`/`unbanMember`), and moderation appeals, to
blunt mass-reporting brigades and a compromised group-owner/admin account mass-banning. All three
are, today, direct client writes gated by `firestore.rules` (the Faz 2 §2.3 design for group
moderation; the pre-existing design for reports, matching `privacy_requests`). A real sliding-window
limiter needs a counter that goes up on every attempt regardless of client cooperation — rules alone
can't guarantee that (a client could simply never write the counter-bumping doc), so *some* Cloud
Function involvement is unavoidable. The open question was how much: rewrite the write path itself
(a `applyGroupModerationAction`-style callable, mirroring how `BLK-03`/`SEC-06` moved follow/friend-
request writes server-side), or add a lighter enforcement layer on top of the existing writes.

**Decision.** Keep `reports`/`community_groups/{id}/moderation`/`moderation_appeals` as direct
client writes (`CommunityGroupService`'s five methods are unchanged — Faz 2 §2.6 wires UI onto them,
per the plan's own framing of "already-built service methods"). Add three Firestore `onCreate`
triggers (`functions/moderation.js`: `onReportCreated`, `onGroupModerationActionCreated`,
`onModerationAppealCreated`) that bump a per-uid sliding-window counter
(`functions/rate_limit.js: checkAndBumpSlidingWindow` — same window-start-Timestamp-plus-count shape
as `index.js: enforceRateLimitAndQuota`, generalized) and, once a uid crosses the threshold, stamp a
`{kind}_locked_until` timestamp on `rate_limits/{uid}` (fully server-only collection). `firestore.
rules`' `isReportRateLimited()`/`isModerationRateLimited()`/`isAppealRateLimited()` check that field
before allowing the NEXT write of that kind — `isAdmin()` stays exempt, matching every other
protected-field check in this file (`touchesProtectedGroupFields()` etc.).

**Reason.** A full callable migration for kick/ban/mute is the textbook-correct long-term answer
(ADR-008 already lists "ban state" and "moderation" as things that must be server-only, and the
current client-direct design is, strictly, a gap against that rule) — but it means rewriting five
call sites, denying every existing client-direct rule path, and re-verifying every existing
kick/ban/mute rules test against a new contract, for a task explicitly scoped as "wire the
already-built service methods into a UI" plus "add a rate limit." The reactive-trigger design is
strictly weaker (see Consequences) but is additive: it changes no existing write-success path when
unlocked (confirmed — every pre-existing kick/ban/mute rules test still passes unmodified), needs no
callable, and reuses the exact sliding-window shape already proven in `aiProxy`.

**Alternatives.** Full write-gating callable (`applyGroupModerationAction`, `fileReport`) — rejected
for this pass as materially larger in scope and risk than "add a rate limit" asked for; noted here as
the correct next step if group moderation ever needs to be fully closed against a compromised
owner/admin account, not just rate-limited. Pure `firestore.rules`-only counter (client increments
its own `rate_limits/{uid}` doc in the same batch) — rejected: nothing stops a client from omitting
that write, since rules can only read the CURRENT state of another doc via `get()`, never assert that
the same transaction also updated it — a self-reported counter is not a real rate limit.

**Consequences.** ✅ Zero changes to any existing client-direct write's success path; all pre-existing
`community_groups`/`reports` rules tests pass unmodified. ✅ Reuses one proven pattern (`rate_limit.js`
shared by all three triggers) instead of three bespoke mechanisms. ✅ New surfaces (moderation
appeals) ship with the same protection from day one. ⚠️ **Honest limitation, not to be overclaimed**:
enforcement is reactive — a burst can land up to (the window's max + however many arrive before the
trigger fires, typically on the order of a second or two) writes before the lock actually engages.
This bounds and blunts abuse (turns "unlimited" into "a few dozen actions, then hard-stopped, all of
it sitting in the immutable moderation/reports log for cleanup and audit") — it does not guarantee
zero-over-limit the way a pre-write-gating callable would. ⚠️ Three new Cloud Functions (`onCreate`
triggers) exist only as syntax-checked (`node -c`) code, per this repo's standing limitation (no
functional Cloud Functions test harness, `CLAUDE.md` §8) — they have never fired against live data
here.

---

## ADR-020 — XP backbone: one entry gate extended in place, a ledger for idempotent caps, reputation migrated onto level bands

**Date:** 2026-08-05 · **Status:** Accepted

**Context.** Faz 5 §5.1 needed a server-authoritative XP/level system: points per action, a daily cap
per action that a client retry storm can't bypass, an increasing-interval level curve with a
celebration on level-up, and — since the plan explicitly forbids "two parallel score systems" —
a real migration of the existing `ReputationTier` (previously `streak×2 + postCount×5`, computed in
`functions/progress.js`'s `syncProgress`, itself Faz 0 §0.4's server-authority fix) onto the new XP
economy, not a second economy running alongside it.

**Decision.** Three linked choices, one system:
1. **Single entry gate, extended, not duplicated.** `syncProgress` (already the sole write path for
   achievements/reputation) gained a new `xpEvents[]` request field and an internal `awardXp`
   primitive, rather than a new `awardProgress`-named callable. (The ORIGINAL plan text called this
   function `awardProgress`; the code that actually shipped in Faz 0 named it `syncProgress` — code
   is truth, so the existing name stays, extended in place.) Server-verified events that never need a
   client report at all (`check_in`, `template_accepted`) call the same internal `awardXp` in-process
   from `presence.js`/`gym.js`/`templates.js` — still ONE code path that decides points/caps/ledger
   writes, just multiple legitimate callers.
2. **The ledger IS the cap enforcement, via a deterministic id.** `users/{uid}/xp_events/{eventId}`,
   `eventId = ${kind}_${refId}`. This single string does two jobs at once: it makes a retried award
   for the exact same instance idempotent (the doc already exists → replay the stored outcome), and it
   makes a kind's daily cap unbeatable by a retry storm of brand-new instances (count today's
   already-awarded docs of that `kind`, refuse the next one once at the cap — a capped attempt is
   deliberately never written at all, so cost stays proportional to real awards).
3. **Reputation migrates onto XP LEVEL bands, not a second formula.** `tierFromLevel` (level 1-4
   newcomer, 5-9 active, 10-19 contributor, 20-34 expert, 35+ legend) replaces `tierFromScore`'s old
   score-cutoff table entirely — the old formula is deleted, not kept running alongside XP.
   `reputation_score` keeps being written, but now as a plain mirror of `xp` (never an independently
   computed number again), so any consumer still reading that exact field name doesn't break. A user
   who predates this system gets `xp` seeded from their old `reputation_score` the first time
   `awardXp` ever touches their doc — read-time migration, no backfill script.

**Reason.** (1) avoids the exact failure mode the task was warned against — "a second, parallel entry
point" — and keeps every existing trust-boundary comment in `progress.js` valid instead of forking it.
(2) a single Firestore doc id is cheaper and more auditable than a separate counters-with-transactions
scheme, and reuses this repo's own established idiom (`presence_notify_log`'s per-day dedup key,
`plan_offers`' `.create()`-fails-if-exists semantics) rather than inventing a new one. (3) tying tier to
LEVEL (not raw XP) means retuning the level curve later never requires re-deriving tier thresholds —
they're already expressed in the same unit the curve produces.

**Alternatives.** A dedicated `awardXp` HTTPS callable, separate from `syncProgress` — rejected: the
task explicitly asked for one entry gate, and a second callable would mean either duplicating the
achievement/reputation read-write batch or racing two separate writes to the same user doc. Storing a
running per-kind-per-day counter directly on the user doc (e.g. `xp_daily.<kind>.count`) instead of a
ledger — rejected: no natural idempotency key for retries (a counter increment isn't self-describing
the way a doc id is), and no audit trail of individual awards. Reusing the OLD score's numeric
thresholds (50/150/350/700) as level-band cutoffs directly — rejected: XP accumulates far faster than
the old formula ever did (a single day's meal logs + streak already approaches the old "active"
cutoff), so the old absolute numbers would compress every tier into the first couple of weeks; bands
expressed in LEVEL instead of raw XP stay meaningful regardless of how the point table gets tuned later.

**Consequences.** ✅ Zero new client-facing entry points — one callable, one trust model, one place to
audit. ✅ `profile_screen.dart`'s existing tier chip needed ZERO code changes to reflect the new
formula — `ReputationData`'s shape didn't change, only what feeds it. ✅ 151/151 rules suite (149
baseline + 2 new: client cannot self-write `xp`/`level`/`level_updated_at`, `xp_events` is
owner-read/nobody-write). ⚠️ **Honest limitation**: a capped (rejected) attempt is never ledgered, so a
retry of that SAME specific instance after a day boundary rolls over would award on the retry —
low-stakes (XP has no monetary equivalent by design) and rare (every call site reports immediately
after the local action), but not theoretically airtight. ⚠️ Cannot independently re-derive which
flavor of a `food_logs` doc is a "recipe cook" vs. a plain log (no queryable field for that yet) — the
exact same pre-existing, already-accepted gap the `justCookedAndLogged` achievement flag already
carried; XP inherits it rather than worsening it. ⚠️ Like every other Cloud Function change across
Faz 0-4, this has been syntax-checked (`node -c`) and had its module graph `require()`'d, never fired
against live production data — no functional execution harness exists for Cloud Functions in this repo
(`CLAUDE.md` §8).

---

## ADR-021 — Gym invite-code generation stays client-direct; redemption stays server-only

**Date:** 2026-08-05 · **Status:** Accepted

**Context.** Faz 6 §6.1 extends `referrals/{code}` with a `type: 'gym'` variant for poster/QR user
acquisition — the same collection `applyReferral` already redeems server-side (ADR-008: value-bearing
writes are server-only). The open question was whether MINTING a gym code needed a new callable too,
mirroring `applyReferral`'s shape, or could stay a plain client write like every other owner-scoped
gym doc (gym profile, gym posts, QR check-in token).

**Decision.** Creating a gym invite code stays a plain client-side Firestore write, gated entirely by
`firestore.rules`: `type=='gym'` requires `gym_id` and a server-evaluated `get()` cross-check that
`request.auth.uid` really is `gyms/{gym_id}.owner_uid` — the exact pattern every sibling owner-scoped
gym rule already uses (`members`, `posts`, `checkins`, `private/qr_token`). No new callable was added.
`applyReferral` (redemption, `functions/economy.js`) is untouched and remains the only path that ever
grants a reward or writes a commission.

**Reason.** A code's own fields (`campaign`, `location_note`, `max_uses`, `printed_at`) carry no value
by themselves — nothing is granted, spent, or unlocked by a code doc merely existing. The rules' `get()`
cross-check already fully closes the one real risk (stamping someone else's `gym_id` on your own code,
proven by a dedicated negative test); a callable would re-implement that exact same ownership check
server-side for no additional security. Value only enters the picture at REDEMPTION time, which is
exactly where server authority already lives and stays.

**Alternatives.** A `createGymInviteCode` callable mirroring `applyReferral`'s transaction shape
(rejected: doubles the code path for a write `firestore.rules` can already fully gate on its own;
ADR-008's server-only bar is for value-bearing fields, and a code's metadata isn't one) · extending
`applyReferral` now to special-case `type=='gym'` (rejected: redemption isn't reachable yet — no deep
link/onboarding step exists until Faz 6 §6.3/§6.4 — so there is nothing real to special-case yet; the
attribution record and gym commission split, §6.5/§6.6, are follow-on work with their own design
questions, not a detail to guess at speculatively here).

**Consequences.** ✅ Zero new Cloud Function surface for a purely descriptive write; the entire security
argument is a one-line rules `get()`, auditable in the same file as every sibling gym rule, proven by
7 new rules-suite tests (176/176 total, 169 baseline + 7). ⚠️ Whoever builds Faz 6 §6.5/§6.6 MUST add
a `type=='gym'` branch to `applyReferral` before real redemption goes live — today it grants the
generic 7-day-both-sides premium reward + a flat ₺5 commission to `owner_uid` for ANY type (it never
reads `type` at all), which is almost certainly not the final desired gym behavior once a dedicated
attribution doc and `gymPremiumShare` commission type exist; shipping redemption without that branch
first would hand every redeeming gym owner an accidental personal premium trial + commission as a
side effect of unmodified generic code. ⚠️ `used_by_uids` stays a plain array on the code's own doc
(pre-existing shape, unchanged) — a gym poster's `max_uses: 5000` default is comfortably inside
Firestore's 1 MiB document limit today, but a genuinely viral code would eventually need this
reworked before §6.5/§6.6 turn gym-code redemption into real traffic.

---

## ADR-022 — Commission reversal: a one-way correlation hash, and paid entries are annotated + offset, never rewritten

**Date:** 2026-08-05 · **Status:** Accepted

**Context.** `functions/purchases.js` revokes premium on refund/chargeback/expiry via three paths
(`validatePurchase`'s own `revoked` branch, `appStoreNotifications`, `playRtdn`), but none of them
reversed the corresponding `users/{ownerUid}/commissions/{id}` ledger entry — a known, previously
flagged gap (`maybeAwardGymCommission`'s own header comment; `docs/SERVICES.md`) left open because
closing it touches shared revocation infrastructure across every commission type. It's also a live
promise in `assets/legal/marketplace_terms_{en,tr}.md` §6/§10 ("commissions on refunded or
charged-back transactions are reversed"), so the gap was a real code/contract mismatch, not
cosmetic. Two design questions forced a choice: (1) how does a commission entry get traced back to
the specific purchase that granted it, given the entry lives in the OWNER's subcollection while
revocation only ever knows the PURCHASER's platform+token; (2) what happens when the matched entry
has already been marked `paid` — real money has, in principle, already moved.

**Decision.** (1) Every purchase-linked commission entry (today, only `gymPremiumShare` —
`referral` is granted at code-redemption time with no store transaction behind it at all, and stays
structurally exempt) carries `purchase_key`: `sha256(platform + ':' + token)`
(`entitlements.js`'s `purchaseCorrelationKey`), NOT the reversible base64url id
`claimPurchaseToken` already uses for `processed_purchases/{id}`. Revocation recomputes the same
hash from whatever platform+token that event carries and runs one
`collectionGroup('commissions').where('purchase_key', '==', key)` query
(`reverseCommissionsForPurchase`) — no dependency on first resolving which uid was affected. (2) A
matched `pending`/`approved` entry is flipped to the existing `rejected` status (`CommissionStatus`,
`commission_service.dart` already excludes it from earnings totals) plus `reversed_at`/
`reversed_reason`. A matched `paid` entry is left completely unmodified except for those same two
annotation fields — never rewritten, never deleted — and a NEW sibling entry is appended instead:
negative `amount`, `status:'pending'`, `adjustment_of`/`adjustment_reason` pointing back at the
original, so it nets against that owner's NEXT manual payout via the same
`pendingAmount`/`totalEarned` arithmetic that already exists. (3) The reversal call is gated to a
genuine refund/revoke signal only — Apple `REFUND`/`REVOKE` (equivalently, `revocationDate` set) and
Google's `voidedPurchaseNotification`/subscription notificationType `12` — and deliberately EXCLUDES
Apple `EXPIRED`/Google notificationType `13`, even though the entitlement-revocation call sitting
right next to each reversal call correctly treats expiry identically to a refund for ACCESS purposes.

**Reason.** `commissions` is owner-readable (`firestore.rules`: `allow read: if request.auth.uid ==
uid`), unlike the fully server-only `processed_purchases` — reusing the same reversible encoding
there would hand the commission owner a decodable copy of the PURCHASER's actual Apple/Google
transaction id, for a field that only ever needs an equality match. A one-way hash gets the same
correlation power with none of that leak. For the paid case: payouts in this codebase are manual
(`CommissionService.requestPayout` is a documented placeholder; `marketplace_terms_{en,tr}.md` §4/§10
say the same) — there is no payment rail for a Cloud Function to even issue a reversal on, so
clawing back cash already sent isn't something a webhook should attempt unilaterally. Rewriting the
paid entry's own amount/status would also falsify a factual record (it WAS earned, it WAS paid, on
that date). An offsetting entry keeps the ledger append-only (matching every other economy ledger in
this codebase — `xp_events`, `engagement_credit_events`, `gym_attributions`) while still making the
owner's NET position correct going forward, and mirrors §10's own "amounts Cookrange owes you may be
offset against amounts you owe Cookrange" language. For (3): an EXPIRED/notificationType-13
subscription simply reached the end of a period it was legitimately paid for and not renewed —
nothing about the ALREADY-COMPLETED purchase that earned the commission becomes invalid just because
a LATER renewal didn't happen. `marketplace_terms_{en,tr}.md` §6/§10 promise reversal specifically
for "refunded or charged-back" transactions, not for ordinary non-renewal — mirroring
entitlement revocation's own EXPIRED handling onto commission reversal would silently claw back a
gym's commission on every single non-renewing member, which is a materially different (and far more
damaging) behavior than what was asked for or promised.

**Alternatives.** Storing the plain `platform_token`-style id (same scheme as `processed_purchases`)
directly on the commission doc (rejected: reversible, and this doc is owner-readable — needless leak
for zero functional gain, since reversal only ever needs equality). Deleting a `pending` entry
outright instead of flipping it to `rejected` (rejected: every other ledger here is append-only, and
`commissions` already denies client delete for the same audit-trail reason — no cause to make the
one server-side write path do what client writes are deliberately forbidden from doing). For the
paid case: silently rewriting the paid entry's `amount`/`status` in place (rejected: falsifies a
factual record); doing nothing at all (rejected: leaves the ledger permanently overstated after a
real refund, directly contradicting the §6/§10 promise this change exists to keep). Mirroring
entitlement revocation's three-way `REFUND`/`REVOKE`/`EXPIRED` trigger set onto commission reversal
verbatim (rejected — and initially the first draft of this change did exactly this before review
caught it: expiry is the single most COMMON of the three events by far, since it fires on every
plain non-renewal, so getting this wrong would have clawed back the majority of gym commissions ever
paid for no legitimate reason).

**Consequences.** ✅ Closes a real legal/contractual gap for the one commission type it currently
applies to, with zero Dart-side model changes required for the pending/approved/rejected path
(`getEarningsSummary` already treats `rejected` correctly) and only a 1-line sign-formatting fix for
the paid/offsetting path (`gym_earnings_screen.dart`/`affiliate_earnings_screen.dart` hardcoded a `+`
prefix that a negative amount would otherwise render as "+₺-15.00"). Any FUTURE purchase-linked
commission type gets reversal for free by writing the same `purchase_key` at grant time — the query
is type-agnostic. ⚠️ Depends on the platform+token available at each of the three revocation call
sites matching, byte-for-byte, whatever platform+token was used at ORIGINAL grant time — this holds
today (the revoked-branch reuses the same request's own token; `appStoreNotifications` uses Apple's
`originalTransactionId`, `playRtdn` the same Google `purchaseToken` `claimPurchaseToken` already
keys on) but does NOT account for Apple's transaction-id hierarchy diverging across subscription
renewals (a renewal's own `transactionId` differs from `originalTransactionId`) — a pre-existing
ambiguity in how `entitlements.latest_transaction_id` itself is matched, not introduced by this
change, and still unresolved. ⚠️ An owner's `pendingAmount` can go net-negative after a clawback
exceeds their other pending commissions — arithmetically correct, and the existing `>0`-gated
payout-request button already hides correctly in that state, but it's a real UI state nobody had
designed for before now.

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
