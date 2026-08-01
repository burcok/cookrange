# FEATURES.md — Capability Catalog

> The answer to **"does Cookrange already do X, and where is it?"**
> If it's here, the code exists. **The State column tells you whether it actually works.**
> If it isn't here at all, check [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md).

### State legend

| | Meaning |
|---|---|
| ✅ | **Working** — demonstrated functional (evidence in `TODO.md` §1.4) |
| 🚧 | **Built, unverified** — code exists; no proof it runs end to end |
| ⛔ | **Built, blocked** — a known defect makes it non-functional. Blocker ID given |
| 🔒 | **Built, kill-switched** — deferred to M6 by scope decision ADR-012 |
| ❌ | **Not built** |

> ⚠️ Far more of this surface is *written* than is *verified*. **A 🚧 is not a promise.** Overall
> progress figures and blocker detail live in [`../PROJECT_STATE.md`](../PROJECT_STATE.md) — this
> document never carries percentages or health scores, so that they can only ever be wrong in one
> place.
>
> **Since** = the milestone the capability first appeared in. The app has never been released, so
> these are internal markers, not shipped versions.

---

## Nutrition & food

| Feature | State | Since | Depends on | Next |
|---|---|---|---|---|
| AI weekly meal plan — hash-cached, allergen-filtered, archived | ⛔ `BLK-01` | v0.5 | `WeeklyMealPlanService`, `aiProxy` | Add the `isConfigured` guard; break the 180-dish ceiling |
| Food logging — dish / recipe / AI-scanned / quick-add / barcode | ✅ | v0.4 | `FoodLogService` | — |
| Recent & frequent foods | ✅ | v0.6 | `RecentFoodService` (Hive) | — |
| Recipe database — TR + international, seeded | ⛔ `BLK-11` | v0.3 | `DishService`, `dish_data.dart` | Unseedable in-app; only 75 dishes, need ≥ 300 |
| Favorites, recipe notes | ✅ | v0.6 | `FavoriteService`, `RecipeNoteService` | — |
| Cooking mode — step pager, timer, wakelock, finish→log | ✅ | v0.7 | `wakelock_plus` | — |
| AI recipe generation — credit-gated | ⛔ `BLK-01` | v0.6 | `RecipeGenerationService` | Same guard as meal plans |
| AI food analysis — describe **or** photo (vision) | 🚧 | v0.9 | `FoodAnalysisService`, vision model | Verify vision path end to end |
| Barcode scanning — with manual-entry fallback | 🚧 | v0.8 | `mobile_scanner`, Open Food Facts | — |
| Nutrition analytics — 7-day bars, macros, adherence | 🚧 | v0.7 | `CalorieCalculator` | — |
| Shopping list — auto-generate, source-meal attribution, sync, `.ics` | ✅ | v0.7 | `ShoppingListSyncService` | — |
| Meal plan history + restore | ⛔ `BLK-06` | v0.8 | index exists, **rule missing** | Add the rule — it's permanently empty without it |
| Hydration, weight, exercise logging | ✅ | v0.6 | `ExerciseLogService` (MET table) | — |

## AI intelligence

| Feature | State | Since | Depends on | Next |
|---|---|---|---|---|
| AI chat coach — profile-aware, voice-bridged | 🚧 | v0.7 | `AiChatService` | Streaming responses |
| AI Fitness Twin — 30/60/90-day projection | ✅ | v0.8 | `AiInsightService` | — |
| Daily accountability insight — cached per day+locale | ✅ | v0.8 | `AiInsightService` | — |
| Weekly AI recap — score, wins, challenges, trend | ✅ | v0.9 | idempotent per week+locale | — |
| Risk detection — client-side, no AI call | ✅ | v0.8 | — | — |
| Voice assistant overlay | 🚧 | v0.7 | `speech_to_text` | — |
| Server-side AI quota — fail-closed, transactional | ✅ | v0.9 | `aiProxy` | — |
| Real cost metering — tokens × model price | ✅ | v0.9.5 | `ai_usage_logs/stats` | — |
| AI credits — 2/day free, 20/day premium, IAP bonus | 🚧 | v0.9 | server ledger | Blocked commercially by `BLK-04` |
| Prompt-injection guard + deterministic allergen filter | ✅ | v0.9 | `PromptService`, `AllergenSafety` | — |

Detail: [`AI_SYSTEM.md`](AI_SYSTEM.md).

## Social & community

| Feature | State | Since | Depends on | Next |
|---|---|---|---|---|
| Feed — posts, reactions, comments, image carousel | ✅ | v0.5 | `CommunityService` | Post field-mutation hole `BLK-08` |
| Filters & topics — Global/Friends/Following/Gym/Saved | ✅ | v0.7 | `AppFilterBar` | — |
| Friends, follow graph, weekly highlights | ✅ | v0.5 | `FriendService`, `FollowService` | Open creates (`S5`) closed in code+rules, deploy pending |
| @mentions with notification fan-out | ✅ | v0.7 | — | — |
| 1:1 + group chat — typing, images, read status | ✅ | v0.5 | `ChatService` | — |
| In-app notifications — structured, locale-rendered | ✅ | v0.6 | `NotificationPresenter` | — |
| **Push notifications** | 🚧 `BLK-03` | v0.6 | Cloud Functions | Chat push works; social/admin push code+rules written (`notifications.js`/`social.js`), deploy + physical-device verification pending |
| Community groups — location-based | 🚧 | v0.9 | `CommunityGroupService` | — |
| Streak squads | 🚧 | v0.7 | `StreakSquadService` | — |
| Signals — ephemeral, TTL | 🚧 | v0.6 | needs a Firestore TTL policy | — |
| Streaks + milestones | ✅ | v0.4 | unit-tested | Server-side (`SEC-14`) |
| Achievements — 11 badges, idempotent | ✅ | v0.9.5 | `AchievementService` | — |
| Reputation score | 🚧 | v0.7 | — | Client-computed, forgeable |
| Leaderboards — global + friends | 🚧 | v0.7 | — | — |
| Moderation — keyword screen, reports, image scan | ⛔ `BLK-05` | v0.8 | admin queue unreachable | No UGC rate limiter |

Detail: [`COMMUNITY.md`](COMMUNITY.md).

## Gym ecosystem — 🔒 deferred to M6 (ADR-012)

| Feature | State | Since | Notes |
|---|---|---|---|
| Gym profiles, brand colour, verification | 🔒 | v0.8 | — |
| Gym setup | ⛔ `BLK-07` | v0.8 | Logo upload writes to an unruled Storage prefix |
| Membership & check-in — QR / GPS / manual | 🔒 | v0.8 | Weak validation (`S13`) |
| Gym community feed, leaderboard, analytics | 🔒 | v0.8 | — |
| Gym discovery — city/district, 4 sorts, map | 🔒 | v0.9 | "Near Me" is the KVKK reference implementation |
| Gym Wars | ❌ | — | Model + service only; no real UI |

Detail: [`GYM_ECOSYSTEM.md`](GYM_ECOSYSTEM.md).

## Coach & marketplace — 🔒 deferred to M6 (ADR-012)

| Feature | State | Since | Notes |
|---|---|---|---|
| Coach profiles, verification, vanity code | 🔒 | v0.8 | — |
| Application → admin approval → role flip | ⛔ `BLK-05` | v0.8 | Admin unreachable |
| Coach discovery — curation, 4 sorts, filters | 🔒 | v0.9 | — |
| Client management, at-risk detection, AI reports | 🔒 | v0.8 | AI report reads another person's health data |
| Coach reviews — immutable, transactional average | 🔒 | v0.8 | Not gated on a real client link (`S13`) |
| Program marketplace — browse, enroll, track | ⛔ `BLK-09` | v0.8 | `coach_uid=='demo'` lets anyone publish |
| Paid programs | ❌ | — | Deliberately stubbed behind an honest banner |

Detail: [`COACH_ECOSYSTEM.md`](COACH_ECOSYSTEM.md).

## Monetization

| Feature | State | Since | Notes |
|---|---|---|---|
| Premium subscription — monthly / yearly | ⛔ `BLK-04` | v0.9 | Client + server complete; **no store products exist** |
| AI credit top-ups (consumable) | ⛔ `BLK-04` | v0.9 | Same |
| Server-side receipt validation + replay guard | 🚧 | v0.9.5 | Never run against a real store |
| Refund/expiry revocation webhooks | 🚧 | v0.9.5 | Pending store credentials |
| Referral — 6-char codes, 7-day trial both sides | 🚧 | v0.8 | Server-validated |
| Coach commissions | 🚧 | v0.8 | Tracking only — **no payout rail** (`REF-04`) |

Detail: [`PREMIUM.md`](PREMIUM.md).

## Growth & retention

| Feature | State | Since |
|---|---|---|
| Deep links — universal + custom scheme | 🚧 | v0.8 |
| Social sharing + shareable fitness card (PNG) | ✅ | v0.8 |
| "What's New" once-per-version sheet | ✅ | v0.9 |
| Coachmark tips, profile completeness card | ✅ | v0.9 |
| Meal reminders, streak-at-risk, weekly-plan-ready nudges | ⛔ `BLK-03` | v0.9.5 |

## Admin & ops

| Feature | State | Since | Notes |
|---|---|---|---|
| Admin hub — categorized grid + nav drawer | ⛔ `BLK-05` | v0.9.5 | **Entire surface unreachable** — `admin_roles/{uid}` created by nothing |
| User management — ban, role, force logout, reset | ⛔ `BLK-05` | v0.9 | — |
| Application review (coach + gym) | ⛔ `BLK-05` | v0.8 | — |
| Moderation queue + bulk takedown | ⛔ `BLK-05` | v0.8 | — |
| Remote app config — models, gates, kill-switches | ✅ | v0.9.5 | Client **and** proxy, no redeploy |
| Maintenance mode + force-update gates | ✅ | v0.9.5 | The working incident levers |
| Cost & profit dashboard | 🚧 | v0.9.5 | AI cost real; Firebase cost estimated |
| Append-only audit log | 🚧 | v0.9 | — |
| Broadcasts | 🚧 | v0.9 | — |

## Platform & compliance

| Feature | State | Notes |
|---|---|---|
| EN/TR localization — 2,722 keys, exact parity, CI-gated | ✅ | Highest-quality subsystem in the project |
| Dark/light themes + live brand colour | 🚧 | Both defined; **120 hex + 214 `Colors.white/black` literals leak** |
| Design system — 14 components over semantic tokens | ✅ | — |
| iOS + Android — Apple/Google sign-in, ATT, guards, haptics | ⛔ `BLK-02` | `NSPhotoLibraryUsageDescription` missing → crash + auto-rejection |
| In-app legal docs (Privacy, Terms, KVKK, Açık Rıza) EN+TR | 🚧 | Drafted; **lawyer review pending** |
| Consent Center — per-purpose, versioned, withdrawable | ✅ | `ConsentService` |
| DSAR channel + admin queue | ⛔ `BLK-05` | Queue unreachable |
| GDPR export + account erasure | ⛔ `BLK-12` | Coverage incomplete |
| Age gating (min 16) | ✅ | Onboarding birth date |
| Hive AES-256 at rest | ✅ | Key in `flutter_secure_storage` |
| App Check | ⛔ `BLK-14` | Providers wired; **enforcement off** |
| Accessibility | 🚧 | DS-level semantics on a few components; no screen-reader, contrast, or touch-target pass |
| Crashlytics / Analytics / Performance | 🚧 | Consent-gated; **Crashlytics blinded by swallow-and-log** |
| Offline — Firestore persistence + Hive | 🚧 | No write queue, no conflict resolution |

## Not built

Integration & widget tests · rules tests in VCS · monitoring, alerting, SLOs · structured production
logging · staging environment · backups & DR · DI / service interfaces · full-text search · payout
rail · challenges (deliberately sunset) · XP/levels · white-label beyond a brand colour · auth
rate-limiting & MFA · server-side streak/reputation · migration framework · proxy load testing ·
API versioning · release obfuscation · tablet layouts · offline write queue · behavioural-analytics ML.

IDs in `TODO.md` §1.6. Build plans in [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md).

---

## Maintaining this file

- A new capability gets a row **and** a `README.md` update — same task.
- New code lands as **🚧**, never ✅. Promotion to ✅ requires demonstrating it works, and the same
  promotion in `PROJECT_STATE.md` §5.
- When a blocker closes, update the row's State **and** `PROJECT_STATE.md` §3.
- Never add a percentage or health score here.
