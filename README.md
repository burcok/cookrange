<p align="center">
  <img src="cookrange-icon.png" width="140" alt="Cookrange"/>
</p>

<h1 align="center">Cookrange</h1>

<p align="center">
  <strong>The AI fitness & nutrition operating system for people, coaches, and gyms.</strong><br/>
  Flutter (iOS + Android) · Firebase · OpenRouter AI · EN/TR
</p>

<p align="center">
  <em>Fitness isn't an information problem — it's a consistency problem.</em><br/>
  Cookrange combines AI nutrition, behavioral nudges, gym communities, and coach tools into one app.
</p>

---

## Table of Contents

- [What Cookrange Is](#what-cookrange-is)
- **Part 1 — [Developer Guide](#part-1--developer-guide)** (project analysis, setup, architecture)
- **Part 2 — [User Guide](#part-2--user-guide)** (how to use every feature)
- [Documentation Map](#documentation-map)
- [Contributing & the Living-Docs Rule](#contributing--the-living-docs-rule)
- [Contact](#contact)

---

## What Cookrange Is

Cookrange is a cross-platform mobile app that turns fitness from a guessing game into a guided,
social, AI-assisted habit. It serves four kinds of people from one codebase:

| Role | What they get |
|---|---|
| **Consumer** | AI meal plans, food/exercise logging, recipes, analytics, AI coach chat, community, streaks |
| **Coach** | Public profile, client management, AI client reports, sellable programs, reviews, commissions |
| **Gym Owner** | Gym profile, QR check-ins, member community, leaderboards, analytics, gym-vs-gym competition |
| **Admin** | Full moderation, application review, broadcasts, config, billing & abuse monitoring |

**Highlights:** personalized AI weekly meal plans · AI fitness "twin" projections · barcode + photo-free
AI food scanning · gym & coach ecosystems · marketplace programs · premium subscriptions + AI credits ·
referral & commission tracking · full EN/TR localization · dark/light theming · GDPR data export.

---

# Part 1 — Developer Guide

> A comprehensive technical analysis. For the deep maps (every model, service, screen, token), this
> README points into the `docs/` system rather than duplicating it — see the [Documentation Map](#documentation-map).

### At a glance

| | |
|---|---|
| **Platforms** | iOS + Android (single Flutter codebase) |
| **Frontend** | Flutter / Dart · Provider state management · `flutter_screenutil` responsive |
| **Backend** | Firebase: Firestore, Auth, Storage, Cloud Messaging, Remote Config, Crashlytics, Performance, App Check |
| **Serverless** | Node.js Cloud Functions (`functions/index.js`) — AI proxy, notification fan-out |
| **AI** | OpenRouter LLM, proxied + quota-enforced server-side |
| **Localization** | English + Turkish, parity-enforced in CI |
| **Scale** | ~274 Dart files · ~100K LOC · 42 models · 75 services · 95 screens · 25+ design-system widgets |

### Tech-stack rationale
- **Flutter** — one codebase, native 60fps UI, both stores.
- **Firebase** — managed auth, realtime Firestore (source of truth), storage, push, remote config,
  crash/perf monitoring, and App Check abuse protection without running servers.
- **Provider (not Riverpod/Bloc)** — simple, scoped `ChangeNotifier` state; services are singletons.
- **OpenRouter behind a Cloud Function** — the API key never ships in the app; the proxy enforces
  per-user daily quota in a Firestore transaction and validates Firebase ID + App Check tokens.

### Architecture (four layers)
```
Presentation  lib/screens/**, lib/core/widgets/**     UI only; no direct Firebase
     ↓ provider
State         lib/core/providers/**  (7 ChangeNotifiers: User, Theme, Language, Onboarding, …)
     ↓ singletons
Services      lib/core/services/**   (75 singletons — ALL business logic + Firebase access)
     ↓ models
Data          lib/core/models/**, lib/core/data/**, lib/core/repositories/**
     ↓
Backend       Firestore · Storage · Auth · FCM · Remote Config · Crashlytics · App Check
              + functions/index.js (aiProxy, notif fan-out) + OpenRouter
```
**Inviolable:** UI never calls Firebase directly (always via a service) · services are singletons ·
no raw colors/text styles in UI (design tokens only) · PII lives in `users/{uid}/private/nutrition`,
never the public doc. Full detail in [`ARCHITECTURE.md`](ARCHITECTURE.md).

### Repository structure
```
cookrange/
├── CLAUDE.md · AGENTS.md · ARCHITECTURE.md   ← engineering rules / how-to-work / system map
├── README.md · TODO.md                       ← this file / roadmap & status
├── docs/                                      ← the knowledge base (see Documentation Map)
├── lib/
│   ├── main.dart                              app entry: Firebase → MultiProvider → MaterialApp
│   ├── core/
│   │   ├── models/        data models (Firestore ↔ app)
│   │   ├── data/          seed data (dishes, 81 TR provinces + districts)
│   │   ├── repositories/  in-memory caches
│   │   ├── providers/     ChangeNotifier state
│   │   ├── services/      business logic singletons (+ ai/)
│   │   ├── theme/         design tokens (palette, typography, dimensions, gradients)
│   │   ├── widgets/ds/    design-system components (one barrel: ds.dart)
│   │   ├── localization/  AppLocalizations (JSON-backed)
│   │   └── utils/         routes, route guard, navigation helpers
│   └── screens/           95 screens, one dir per feature (consumer + gym/coach/admin)
├── functions/             Cloud Functions (Node.js)
├── scripts/               load_test.js & one-offs
├── test/                  unit + i18n parity tests
├── assets/localization/   en.json · tr.json
└── firestore.rules · firestore.indexes.json · storage.rules · firebase.json
```

### Key data-flow paths
- **Boot:** `main()` → Firebase init → `MultiProvider` → splash runs `AppInitializationService`
  (dotenv/AI, error handler, Firestore persistence + App Check, Hive, Remote Config → AI proxy URL,
  Crashlytics/Analytics/Auth/FCM/Performance, background seeders) → `UserProvider.loadUser()` →
  `RouteGuard` (ban → auth → email-verify → onboarding → main).
- **AI request:** screen → `AiCreditService` (read-only in proxy mode) → feature service →
  `AIService` → **`aiProxy` Cloud Function** (verifies token + App Check, runs
  `enforceAndConsumeQuota` transaction, 402 if exceeded, else OpenRouter) → parsed, credit rolled
  back on failure.
- **Roles:** `UserProvider` holds a live Firestore listener on `users/{uid}`; an admin role/tier flip
  updates menus and gates **without restart**.
- **PII split:** public profile in `users/{uid}`; sensitive nutrition in `users/{uid}/private/nutrition`.
- **Notifications:** structured-only writes → Cloud Function push fan-out → localized at render time
  on the reader's device.

### Local setup
```bash
# Prerequisites: Flutter SDK (3.24+), a Firebase project, an OpenRouter API key (dev)
flutter pub get
echo "OPENROUTER_API_KEY=sk-or-..." > .env   # dev-only key; prod uses the server-side proxy
flutter run                                   # runs on a connected iOS/Android device or simulator
```
Firebase config files (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`)
must be present. Optional local backend: `firebase emulators:start` (auth/firestore/storage/UI ports
in `firebase.json`).

### Quality gates
```bash
flutter analyze lib/                      # MUST be 0 errors
flutter test                              # unit + i18n parity
flutter test test/i18n_parity_test.dart   # after any string change
dart format lib/                          # CI enforces formatting
node scripts/load_test.js                 # AI proxy load test (PROXY_URL + ID_TOKEN)
```
**CI** (`.github/workflows/ci.yml`) on every PR: format check → analyze → test → Android debug build.
**Deploy** (`deploy.yml`) on main: iOS → TestFlight, Android → Play internal. Full launch path in
[`docs/roadmap/GO_LIVE.md`](docs/roadmap/GO_LIVE.md).

### Engineering rules (the short version)
Every change must satisfy the Definition of Done in [`CLAUDE.md`](CLAUDE.md): multi-role reasoning,
optimization, correct data tier + indexes + rules, logging, smooth iOS/Android UX, dark/light + EN/TR,
flagship-grade states (loading/empty/error/modal), `flutter analyze` 0 errors, and **docs updated**.
Before coding, read [`AGENTS.md`](AGENTS.md) (the per-prompt workflow) and the relevant `docs/` file.

**Legal-first (KVKK + GDPR):** data security and lawful processing are release blockers. Any feature
touching personal data must pass the Legal & Privacy checklist (`AGENTS.md` §2) and follow
[`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) — disclose purpose + get consent *before* access, minimize
(prefer transient/on-device over storage), and update the data inventory. (In-app legal documents are
drafts pending qualified-lawyer review before launch.)

---

# Part 2 — User Guide

> How to actually use Cookrange, feature by feature. Everything below is shipped in the app today.

### Getting started
1. **Sign up** with email, Google, or Apple. Verify your email when prompted.
2. **Feature tour** — a quick 5-screen intro shows what the app does (replayable later from Settings).
3. **Onboarding** — a 6-step setup captures your goals, body metrics, activity level, dietary
   preferences, allergies, and cooking level. (Your sensitive data is stored privately and only you
   can see it.) A fast 2-step version exists for returning users.
4. **Your first meal plan** — Cookrange generates a personalized weekly plan with an animated
   progress screen, then drops you on the Home dashboard.

### The Home dashboard (your daily hub)
- **Today's summary** — calorie ring (consumed vs. target), protein/carbs/fat macros, and water intake.
- **Weekly meal plan** — swipe through the days; tap a meal to view the recipe or swap it.
- **Log food** — tap quick-add to log meals (see below). Logged items update your ring in real time.
- **Exercise** — log a workout (running, cycling, weights, …); calories burned adjust your day.
- **AI insight card** — a daily, personalized nudge based on your goal and streak.
- **Streak** — keep your daily streak alive; milestones celebrate you.
- Pull down to refresh.

### Logging food (five ways)
1. **From your meal plan** — tap a planned meal → log it.
2. **Quick-add** — pick from recent/frequent foods you've logged before.
3. **Search the recipe database** — Turkish + international dishes with full nutrition.
4. **AI food scan** — type what you ate ("2 eggs and toast") and AI estimates the nutrition.
5. **Barcode scan** — scan a packaged product to pull its nutrition.

### Recipes & cooking
- **Recipe detail** — ingredients, step-by-step instructions, full macros, and a nutrition card.
- **Favorites** — bookmark recipes (heart icon) and find them under Favorites.
- **Cooking Mode** — a full-screen, step-by-step guide with a built-in timer; your screen stays awake.
  Finishing logs the meal automatically.

### Meal plans & shopping
- **Regenerate** — your plan adapts when your profile changes; past plans are archived and restorable.
- **Shopping list** — auto-generate it from your meal plan, check items off, sync across devices,
  and share it. Export your plan to your calendar (.ics).

### Nutrition analytics
See a 7-day breakdown of calories vs. target, macro ratios, and goal adherence — so you can see
trends, not just today.

### AI tools
- **AI Chat coach** — ask anything ("what should I eat today?", "make a low-carb dinner", "I missed
  my workout"). It knows your profile. Works by voice too.
- **AI Fitness Twin** — a 30/60/90-day projection of your progress, goal date, and a motivation score.
- **Daily accountability & risk nudges** — gentle prompts when your consistency slips.
- **AI credits** — free accounts get 2 AI generations/day, Premium gets 20/day. A live badge shows
  what's left; you can top up with credit packs or upgrade.

### Community & social
- **Feed** — share posts (text, recipes, progress, meals), react, and comment. Filter by Global,
  Friends, Following, your Gym, or Saved; browse by topic (fat loss, muscle, vegetarian, …).
- **Friends & follow** — search people, send requests, follow others; see weekly community highlights.
- **@mentions** — tag people in posts; they get notified.
- **Streak Squads** — form small accountability groups with an invite code and a shared streak goal.
- **Chat** — 1-on-1 and group chats with typing indicators, images, and read receipts.
- **Notifications** — everything that involves you, always in your language; mute categories you don't
  want in Settings.

### For gym members
- **Find & join a gym** — discover gyms by city/district, or tap **Near Me** to sort by distance on a
  map. Cookrange asks first and tells you your location is used only on your device to sort gyms and is
  **not stored** (KVKK/GDPR); you can decline and keep browsing by city. Scan a gym's QR to join and check in.
- **Gym community** — your gym's own feed, announcements, and leaderboard.
- **Check in** — QR, GPS, or manual; climb your gym's leaderboard.

### For gym owners
Apply from the side menu → once approved you get a **Gym Dashboard**: set up your gym (logo, brand
color, location), manage members, display a check-in QR, run a branded community feed, view a
leaderboard, and see analytics (active members, peak hours, retention).

### For coaches
Apply (specializations, certifications, references) → once approved you get a **Coach Dashboard**:
a public profile with reviews and rating, a client roster with at-risk detection, AI-generated client
reports, and the ability to publish **programs** to the marketplace. Clients can rate you.

### Programs marketplace
Browse fitness programs by category, view week-by-week breakdowns and reviews, and **enroll** to track
your progress week by week. (Free programs are live; paid programs are coming with the payments rollout.)

### Premium, credits & referrals
- **Premium** — more AI/day, advanced meal customization, full analytics, and coach-visibility perks.
- **Credit packs** — one-off top-ups for extra AI generations.
- **Referrals** — share your 6-character code or invite link; you and your friend each get a 7-day
  Premium trial. Coaches earn commission when people subscribe via their code (tracked now; payouts
  rolling out).

### Profile & settings
- **Profile** — edit your photo, bio, and body metrics; see your stats, reputation, and completeness.
  Make your profile private so only friends see the details.
- **Settings** — switch **language (English/Turkish)** and **theme (light/dark)**, manage notification
  categories, toggle privacy, **export all your data** (GDPR), copy your referral link, get support,
  and (for staff) open the admin panel.

### Privacy & your data (KVKK / GDPR)
Cookrange is built privacy-first. Your sensitive info (body metrics, allergies, dietary restrictions)
is stored **privately and owner-only**. Sensitive access is **consent-gated** — we tell you the
purpose and whether data is stored *before* asking (e.g. location for "Near Me" is used on your device
and **not stored**). You can **export everything** you've created as a file, or **delete your account
entirely**, from Settings. Full framework: [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md).

---

## Documentation Map

For contributors and AI agents, the full knowledge base lives in `docs/` (so you never have to read
the whole codebase to make a change):

| Doc | Covers |
|---|---|
| [`AGENTS.md`](AGENTS.md) | How to work: per-prompt workflow, pre-flight checklist, anti-drift rules |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | System layers, data flow, directory map |
| [`CLAUDE.md`](CLAUDE.md) | Engineering rules (R0–R9) + Definition of Done |
| [`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) | Models, Firestore collections, indexes, security & storage rules |
| [`docs/SERVICES.md`](docs/SERVICES.md) | All 75 services + 4 Cloud Functions |
| [`docs/FRONTEND.md`](docs/FRONTEND.md) | All 95 screens, navigation, routing |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Tokens, components, motion, accessibility |
| [`docs/FEATURES.md`](docs/FEATURES.md) | Feature catalog (what exists, where) |
| [`docs/PLATFORM.md`](docs/PLATFORM.md) | iOS/Android parity, native config, CI/CD |
| [`docs/LOCALIZATION.md`](docs/LOCALIZATION.md) | i18n system + how to add strings |
| [`docs/COMPLIANCE.md`](docs/COMPLIANCE.md) | Legal-first framework — KVKK + GDPR, data inventory, consent pattern, per-feature legal checklist |
| [`docs/roadmap/GO_LIVE.md`](docs/roadmap/GO_LIVE.md) | Full App Store + Play Store launch roadmap |
| [`docs/roadmap/FUTURE_FEATURES.md`](docs/roadmap/FUTURE_FEATURES.md) | Missing & future features with build plans |
| [`TODO.md`](TODO.md) | Live status & roadmap |

---

## Contributing & the Living-Docs Rule

This project is built to stay self-documenting. **When you add or change a feature, the documentation
must change in the same task — code is the source of truth, and docs must never drift behind it.**

The rule (enforced via [`AGENTS.md`](AGENTS.md) §3): touch a file → update its owning doc.
- New/changed **model, Firestore rule, or index** → update `docs/DATA_MODEL.md`
- New/changed **service or Cloud Function** → update `docs/SERVICES.md`
- New/changed **screen, route, or navigation** → update `docs/FRONTEND.md`
- New/changed **design token or component** → update `docs/DESIGN_SYSTEM.md`
- **Any new or removed user-facing capability** → update `docs/FEATURES.md` **and this README**
  (both the feature list and the User Guide section)
- Platform/native change → `docs/PLATFORM.md` · localization → `docs/LOCALIZATION.md`
- Shipped a future feature → move it out of `docs/roadmap/FUTURE_FEATURES.md`
- Scope/status change → `TODO.md`

Before committing: `flutter analyze lib/` (0 errors), `flutter test`, and confirm the relevant docs
were updated.

---

## Contact

**Burak Dereli**
📧 [burakdereli05@gmail.com](mailto:burakdereli05@gmail.com) ·
🔗 [github.com/burcok](https://github.com/burcok) ·
[linkedin.com/in/burcok](https://linkedin.com/in/burcok)

<p align="center"><sub><strong>Cookrange — Build consistency. Build identity. Build transformation.</strong></sub></p>
