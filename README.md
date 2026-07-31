<p align="center">
  <img src="cookrange-icon.png" width="140" alt="Cookrange"/>
</p>

<h1 align="center">Cookrange</h1>

<p align="center">
  <strong>The AI fitness &amp; nutrition operating system for people, coaches, and gyms.</strong><br/>
  Flutter (iOS + Android) · Firebase · OpenRouter AI · English &amp; Turkish
</p>

<p align="center">
  <em>Fitness isn't an information problem — it's a consistency problem.</em>
</p>

<p align="center">
  <sub><strong>Status: v0.9.6 — internal alpha.</strong> Not released on either store.
  Much of the feature surface is built but unverified — see
  <a href="PROJECT_STATE.md">PROJECT_STATE.md</a> for the honest picture.</sub>
</p>

---

## What Cookrange is

A cross-platform mobile app that turns fitness from a guessing game into a guided, social,
AI-assisted habit. Everyone already knows they should eat better and move more. What they lack is a
system that adapts to them and keeps them going on the days motivation doesn't show up.

Cookrange serves four kinds of people from one codebase:

| Role | What they get |
|---|---|
| **Consumer** | AI meal plans, food and exercise logging, recipes, analytics, an AI coach, community, streaks |
| **Coach** | Public profile, client roster, AI client reports, sellable programs, reviews, commissions |
| **Gym owner** | Gym profile, QR check-ins, member community, leaderboards, attendance analytics |
| **Admin** | Moderation, application review, broadcasts, remote config, cost monitoring |

## Vision

Most nutrition apps are databases with a search box: they tell you what you ate after you ate it.
Cookrange is built on three bets.

1. **Personalization has to be real.** Your plan should come from your body, your goals, your
   allergies, your kitchen, and your cooking skill — regenerated when any of those change, not
   picked from a list of templates.
2. **Consistency is social.** People stay for the community, the streak, and the friend who
   notices they missed a day — not for the macro pie chart.
3. **The gym is the missing layer.** Your gym and your coach already exist in your real life.
   An app that connects to them beats one that ignores them. That three-sided marketplace —
   consumers, coaches, gyms — is what a solo tracker can't copy.

---

## Main features

**Nutrition & food** — AI-generated weekly meal plans built from your profile and filtered against
your allergies · five ways to log food (meal plan, quick-add, recipe search, AI description scan,
barcode) · a Turkish + international recipe database · full-screen cooking mode with timers ·
auto-generated shopping lists · hydration, weight, and exercise tracking · 7-day nutrition analytics.

**AI** — a profile-aware nutrition coach you can talk or type to · an "AI Fitness Twin" projecting
your next 30/60/90 days · daily accountability nudges · weekly recaps · nutrition estimates from a
photo or a sentence. Every AI request runs through a server-side proxy with a real per-user quota.

**Community** — a feed of posts, recipes, and progress with reactions and comments · friends and
following · @mentions · 1:1 and group chat · location-based groups · streak squads · achievements,
streaks, and leaderboards.

**Gym & coach** — gym profiles with QR/GPS check-in, branded member feeds, leaderboards, and
attendance analytics · coach profiles with reviews and client management · a program marketplace.

**Platform** — full English/Turkish parity · dark and light themes · GDPR/KVKK data export and
account deletion · a consent center · accessibility semantics.

Complete catalog with per-feature state: [`docs/FEATURES.md`](docs/FEATURES.md).

---

## Technology stack

| | |
|---|---|
| **Platforms** | iOS + Android from a single Flutter codebase |
| **Frontend** | Flutter / Dart · Provider state management · `flutter_screenutil` responsive layout |
| **Backend** | Firebase — Firestore, Auth, Storage, Cloud Messaging, Remote Config, Crashlytics, Performance, App Check |
| **Serverless** | Node.js Cloud Functions — AI proxy, purchase validation, entitlements, notification fan-out, account erasure |
| **AI** | OpenRouter, proxied server-side with per-user quota and real cost metering |
| **Local storage** | Hive (AES-256 encrypted) + SharedPreferences |
| **Localization** | English + Turkish, parity enforced in CI |
| **Scale** | ~115k LOC · 329 files · 42 models · 75 services · 95 screens |

---

## Installation

**Prerequisites** — Flutter SDK 3.24+, a Firebase project, an OpenRouter API key (development only),
Xcode (iOS) and/or Android Studio.

```bash
git clone https://github.com/burcok/cookrange.git
cd cookrange
flutter pub get
```

Add your Firebase config files:
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Create `.env` in the project root:

```bash
OPENROUTER_API_KEY=sk-or-...   # development only — release builds use the server-side proxy
APP_ENV=development
```

```bash
flutter run
```

## Development setup

```bash
flutter analyze lib/                      # must report 0 errors
flutter test                              # unit + i18n parity tests
flutter test test/i18n_parity_test.dart   # after changing any user-facing string
dart format lib/                          # CI enforces formatting
```

Optional local backend:

```bash
firebase emulators:start
```

**Before contributing**, read [`CLAUDE.md`](CLAUDE.md) (engineering rules and Definition of Done) and
[`AGENTS.md`](AGENTS.md) (workflow and review checklists). The one rule worth stating up front:
**when you change code, update the document that covers it in the same change.** Code is the source
of truth, and the docs must not drift behind it.

> Note: `test/` is currently in `.gitignore` and CI is red on `main` — see
> [`docs/TESTING.md`](docs/TESTING.md) before trusting a local green run.

---

## Screenshots

> _To be added._ Store-ready captures are produced during **M4 — Beta**: 6.7" and 6.5" iPhone,
> Android phone and tablet, plus a Play feature graphic. Required set and sizes:
> [`docs/roadmap/GO_LIVE.md`](docs/roadmap/GO_LIVE.md) Phase 3.4.

| Home dashboard | Meal plan | AI coach | Community |
|---|---|---|---|
| _pending_ | _pending_ | _pending_ | _pending_ |

---

## Product roadmap

| Milestone | Version | Theme |
|---|---|---|
| **M1 — Truth** | v0.9.7 | Make what already exists actually work; close all 17 blockers; CI green |
| **M2 — Legal** | v0.9.8 | KVKK/GDPR complete: erasure, export, privacy filings, backups |
| **M3 — Commerce** | v0.9.9 | Store enrolment, live products, one real sandbox purchase → real entitlement |
| **M4 — Beta** | v1.0.0-beta1 | 50–100 real testers, ≥ 300 recipes, retention measured |
| **M5 — Launch** | v1.0.0 | Consumer-only public launch on both stores |
| **M6 — Ecosystem** | v1.1.0 | Reopen gym + coach with pilot partners and a payout rail |
| **M7 — Scale** | v1.2.0+ | Search, analytics pipeline, 10k → 100k users |

**v1.0 ships consumer-only.** Gym, coach, programs, marketplace, and payouts are deliberately held
back to M6 so the consumer product can prove retention first — they stay in the codebase behind
feature flags. Reasoning: [`DECISIONS.md`](DECISIONS.md) ADR-012.

Detail: [`PROJECT_STATE.md`](PROJECT_STATE.md) · [`docs/roadmap/GO_LIVE.md`](docs/roadmap/GO_LIVE.md).

---

## Premium

Free accounts get the whole product — logging, meal plans, recipes, community, streaks — with **2 AI
generations per day**. Premium raises that to **20 per day** and adds advanced meal customization,
full analytics history, and coach-visibility perks. One-off credit packs top up AI generations
without a subscription, and a referral code gives both people a 7-day trial.

The principle: **the core product is free and complete.** Premium buys more AI, not access to your
own data.

Monthly and yearly subscriptions are planned for both stores; entitlements are validated
server-side. Details: [`docs/PREMIUM.md`](docs/PREMIUM.md).

## Gym ecosystem

Gyms get a real presence rather than a listing: a branded profile, QR and GPS check-ins, a
members-only community feed in the gym's colours, member leaderboards, and attendance analytics
showing active members, peak hours, and retention.

The longer-term vision is white-label — a gym running its own branded experience on Cookrange's
infrastructure — plus class scheduling, gym-to-gym competitions, and formal gym↔coach
relationships so a gym can bring its trainers onto the platform with revenue sharing.

Location features follow a strict rule: **"Near Me" sorting happens entirely on your device and no
coordinate is ever stored.** You're told that before the permission dialog appears, and declining
keeps everything else working. Vision and roadmap: [`docs/GYM_ECOSYSTEM.md`](docs/GYM_ECOSYSTEM.md).

## Community

Fitness apps lose people in week three. The community exists to be the reason someone opens the app
on the day they don't feel like it — a feed where progress posts get reactions from people on the
same journey, streak squads where a small group shares one goal, gym feeds tying the app to a
physical place, and location-based groups connecting people who train in the same city.

Notifications are stored as structure, never text, so every message renders in the reader's own
language with the sender's current name. Moderation runs keyword screening, image scanning, user
reports, and an admin queue. Details: [`docs/COMMUNITY.md`](docs/COMMUNITY.md).

---

## Privacy & your data

Built privacy-first, because Turkey's KVKK and the EU's GDPR treat health data as special-category —
and because it's the right default.

- **Sensitive data is isolated.** Body metrics, allergies, and dietary restrictions live in an
  owner-only store that no other user can read.
- **Consent comes before access**, with the purpose, whether the data is stored, and a real option
  to decline.
- **You can take it all with you** — export everything you've created, or delete your account and
  everything in it, from Settings.
- **Analytics are off until you turn them on.**

Framework: [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md). In-app legal documents (Privacy Policy, Terms,
KVKK Aydınlatma Metni, Açık Rıza) are drafted in both languages and **pending qualified legal review
before launch**.

---

## Documentation

Cookrange keeps a routed documentation system so contributors and AI agents can understand any part
of it without reading the codebase.

**Start here:** [`PROJECT_STATE.md`](PROJECT_STATE.md) (what works now) →
[`docs/INDEX.md`](docs/INDEX.md) (which document your task needs).

| Document | Covers |
|---|---|
| [`PROJECT_STATE.md`](PROJECT_STATE.md) | Live status, blockers, milestones — **the only place status lives** |
| [`docs/INDEX.md`](docs/INDEX.md) | The task → documents router |
| [`CLAUDE.md`](CLAUDE.md) · [`AGENTS.md`](AGENTS.md) | Engineering rules · agent roles and workflow |
| [`DECISIONS.md`](DECISIONS.md) | Architecture Decision Records — why it's built this way |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layers, data flow, directory map |
| [`docs/DATABASE.md`](docs/DATABASE.md) · [`docs/API.md`](docs/API.md) | Data model · backend contracts |
| [`docs/SECURITY.md`](docs/SECURITY.md) · [`docs/AUTHENTICATION.md`](docs/AUTHENTICATION.md) | Threat model · identity |
| [`docs/AI_SYSTEM.md`](docs/AI_SYSTEM.md) · [`docs/PREMIUM.md`](docs/PREMIUM.md) | AI architecture · monetization |
| [`docs/FEATURES.md`](docs/FEATURES.md) | Capability catalog with per-feature state |
| [`CHANGELOG.md`](CHANGELOG.md) · [`TODO.md`](TODO.md) | History · backlog |

---

## Contact

**Burak Dereli**
📧 [burakdereli05@gmail.com](mailto:burakdereli05@gmail.com) ·
🔗 [github.com/burcok](https://github.com/burcok) ·
[linkedin.com/in/burcok](https://linkedin.com/in/burcok)

<p align="center"><sub><strong>Cookrange — Build consistency. Build identity. Build transformation.</strong></sub></p>
