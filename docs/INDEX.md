# INDEX.md — Documentation Router

> **This file exists to stop you reading things you don't need.** Find your task in §2, read only
> the documents on that row, then open source. Reading the repository to orient yourself is a
> failure of this index — if a row is wrong or missing, fix the row.

---

## 1. The bootstrap (always, in this order)

| # | File | Why |
|---|---|---|
| 1 | [`../PROJECT_STATE.md`](../PROJECT_STATE.md) | What actually works *right now*, blockers, milestone. **Status lives only here.** |
| 2 | [`INDEX.md`](INDEX.md) | This router — which docs your task needs |
| 3 | [`../CLAUDE.md`](../CLAUDE.md) | The rules every change must satisfy |
| 4 | [`../AGENTS.md`](../AGENTS.md) | How to work + which agent role you're in |

Those four are the whole orientation. **Do not read `TODO.md` end-to-end** — it is a 3,000-line
backlog. Jump to the section or task ID you were given.

---

## 2. Task router

Read the **Read** column top-to-bottom, then open source. Everything not listed is out of scope.

| Your task | Read (in order) | Then open |
|---|---|---|
| **Add / change a data model, collection, index, or rule** | [`DATABASE.md`](DATABASE.md) | `lib/core/models/`, `firestore.*` |
| **Add / change business logic, a service, a Cloud Function** | [`SERVICES.md`](SERVICES.md) | `lib/core/services/`, `functions/` |
| **Add / change a screen, route, navigation** | [`FRONTEND.md`](FRONTEND.md) | `lib/screens/` |
| **Build or restyle any UI** | [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | `lib/core/widgets/ds/` |
| **Add or change a user-visible string** | [`LOCALIZATION.md`](LOCALIZATION.md) | `assets/localization/{en,tr}.json` |
| **Anything auth: login, register, OAuth, session, reset, deletion** | [`AUTHENTICATION.md`](AUTHENTICATION.md) → [`SECURITY.md`](SECURITY.md) | `auth_service.dart`, `route_guard.dart` |
| **Anything security: rules, abuse, secrets, threat, hardening** | [`SECURITY.md`](SECURITY.md) → [`DATABASE.md`](DATABASE.md) §7 | `firestore.rules`, `functions/` |
| **Anything AI: prompts, models, cost, quota, fallback** | [`AI_SYSTEM.md`](AI_SYSTEM.md) → [`API.md`](API.md) §2 | `lib/core/services/ai/`, `functions/index.js` |
| **Anything premium: paywall, credits, IAP, entitlements** | [`PREMIUM.md`](PREMIUM.md) → [`API.md`](API.md) §3 | `billing_service.dart`, `functions/purchases.js` |
| **Anything social: feed, comments, chat, friends, groups, moderation** | [`COMMUNITY.md`](COMMUNITY.md) | `community_service.dart`, `chat_service.dart` |
| **Anything gym** | [`GYM_ECOSYSTEM.md`](GYM_ECOSYSTEM.md) | `lib/screens/gym/`, `gym_service.dart` |
| **Anything coach / programs / marketplace** | [`COACH_ECOSYSTEM.md`](COACH_ECOSYSTEM.md) | `lib/screens/coach/`, `coach_service.dart` |
| **Personal data, consent, KVKK/GDPR, legal copy** | [`COMPLIANCE.md`](COMPLIANCE.md) → [`SECURITY.md`](SECURITY.md) §7 | the feature + `consent_service.dart` |
| **Write or fix a test; touch CI's test gate** | [`TESTING.md`](TESTING.md) | `test/` |
| **CI/CD, deploy, environments, secrets, release** | [`DEVOPS.md`](DEVOPS.md) | `.github/workflows/`, `firebase.json` |
| **iOS vs Android behaviour, native config, permissions** | [`PLATFORM.md`](PLATFORM.md) | `android/`, `ios/` |
| **Call or change a backend contract** | [`API.md`](API.md) | `functions/` |
| **"Does Cookrange already do X?"** | [`FEATURES.md`](FEATURES.md) | — |
| **Understand the whole system** | [`ARCHITECTURE.md`](ARCHITECTURE.md) | — |
| **Why is it built this way?** | [`../DECISIONS.md`](../DECISIONS.md) | — |
| **What's the status / what should I do next?** | [`../PROJECT_STATE.md`](../PROJECT_STATE.md) | — |
| **Plan launch / store submission** | [`roadmap/GO_LIVE.md`](roadmap/GO_LIVE.md) | — |
| **Build a future / not-yet-existing feature** | [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) | — |

---

## 3. Document registry

Each document has **one** responsibility. If information belongs to two docs, it lives in the owner
and the other one links to it.

### Root

| Doc | Owns | Update when |
|---|---|---|
| [`../PROJECT_STATE.md`](../PROJECT_STATE.md) | **Status.** Version, milestone, progress, blockers, health | A blocker opens/closes, a system changes state, version/milestone moves |
| [`../CLAUDE.md`](../CLAUDE.md) | **Rules.** R0–R9, Definition of Done, context strategy, forbidden behaviour | A rule changes (rare) |
| [`../AGENTS.md`](../AGENTS.md) | **Roles & workflow.** 8 agent roles, per-prompt loop, pre-flight checklist | A role's scope or the workflow changes |
| [`../DECISIONS.md`](../DECISIONS.md) | **Why.** Architecture Decision Records, append-only | Any decision that constrains future work |
| [`../README.md`](../README.md) | **Public face.** Vision, features, stack, setup | A user-facing capability or the product story changes |
| [`../TODO.md`](../TODO.md) | **Backlog.** Task cards, IDs, estimates, traceability | Work is planned, scoped, or completed |
| [`../CHANGELOG.md`](../CHANGELOG.md) | **History.** Notable changes per version | A release or a structural change lands |

### docs/ — technical

| Doc | Owns these source paths | Depends on |
|---|---|---|
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | whole `lib/` structure, layer contract, data flow | — |
| [`DATABASE.md`](DATABASE.md) | `lib/core/models/`, `lib/core/data/`, `lib/core/repositories/`, `firestore.rules`, `firestore.indexes.json`, `storage.rules` | ARCHITECTURE |
| [`SERVICES.md`](SERVICES.md) | `lib/core/services/`, `functions/` | ARCHITECTURE, DATABASE |
| [`FRONTEND.md`](FRONTEND.md) | `lib/screens/`, `lib/main.dart`, routes | ARCHITECTURE, DESIGN_SYSTEM |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | `lib/core/theme/`, `lib/core/widgets/ds/` | — |
| [`AUTHENTICATION.md`](AUTHENTICATION.md) | `auth_service.dart`, `lib/screens/auth/`, `route_guard.dart` | SECURITY, DATABASE |
| [`SECURITY.md`](SECURITY.md) | threat model, `firestore.rules` intent, secrets, abuse | DATABASE, AUTHENTICATION, COMPLIANCE |
| [`AI_SYSTEM.md`](AI_SYSTEM.md) | `lib/core/services/ai/`, `functions/index.js` aiProxy | SECURITY, PREMIUM, API |
| [`API.md`](API.md) | backend contracts: callables, HTTPS, triggers, external APIs | AI_SYSTEM, PREMIUM |
| [`PREMIUM.md`](PREMIUM.md) | `billing_service.dart`, `functions/purchases.js`, `entitlements.js`, credits | API, SECURITY |
| [`COMMUNITY.md`](COMMUNITY.md) | `community_service.dart`, `chat_service.dart`, social graph, moderation | DATABASE, SECURITY |
| [`GYM_ECOSYSTEM.md`](GYM_ECOSYSTEM.md) | `lib/screens/gym/`, `gym_*_service.dart` | DATABASE, COMMUNITY |
| [`COACH_ECOSYSTEM.md`](COACH_ECOSYSTEM.md) | `lib/screens/coach/`, `lib/screens/programs/`, `coach_*_service.dart` | DATABASE, PREMIUM |
| [`FEATURES.md`](FEATURES.md) | cross-cutting capability catalog | PROJECT_STATE (for status) |
| [`PLATFORM.md`](PLATFORM.md) | `android/`, `ios/`, native config, parity | DEVOPS |
| [`DEVOPS.md`](DEVOPS.md) | `.github/workflows/`, `firebase.json`, envs, secrets, release | PLATFORM, TESTING |
| [`TESTING.md`](TESTING.md) | `test/`, coverage strategy, CI gates | DEVOPS |
| [`LOCALIZATION.md`](LOCALIZATION.md) | `lib/core/localization/`, `assets/localization/` | — |
| [`COMPLIANCE.md`](COMPLIANCE.md) | KVKK/GDPR framework, data inventory, consent pattern, legal docs | SECURITY |
| [`firebase-console-setup.md`](firebase-console-setup.md) | one-time Firebase Console steps | DEVOPS |

### docs/roadmap/ — forward-looking

| Doc | Covers |
|---|---|
| [`roadmap/GO_LIVE.md`](roadmap/GO_LIVE.md) | Store submission path, Phase 5S security gate, infra runbook |
| [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) | Not-yet-built features with build plans |
| [`roadmap/PHASE_15_ENGAGEMENT.md`](roadmap/PHASE_15_ENGAGEMENT.md) | Engagement & gamification phase plan |
| [`roadmap/COMMUNITY_GROUPS.md`](roadmap/COMMUNITY_GROUPS.md) | Location-based groups design |
| [`roadmap/ONBOARDING_V2.md`](roadmap/ONBOARDING_V2.md) | Onboarding V2 design + follow-ups |

---

## 4. Rules for this documentation system

1. **Status lives in `PROJECT_STATE.md` only.** Every other doc describes how something is *built*.
   A feature doc saying "gym check-in exists" means the code exists — not that it works. Never
   duplicate a health score, a blocker, or a percentage outside `PROJECT_STATE.md`.
2. **One owner per fact.** Cross-reference; do not copy. A second copy is a future contradiction.
3. **Code is truth.** If a doc disagrees with code, the doc is wrong — fix it and say so.
4. **Update the owning doc in the same task** that changes its source paths (`AGENTS.md` §4).
5. **Docs describe; they do not promise.** Anything unbuilt belongs in `roadmap/`, not in a
   present-tense feature list.
6. **Blocker IDs are pointers, not copies.** A feature doc may cite `BLK-07` and say what it breaks
   *locally*; it must not restate the blocker's full description or status. **When a blocker closes,
   grep for its ID** — every doc citing it needs the citation removed in that same task, or the
   system starts lying again.
