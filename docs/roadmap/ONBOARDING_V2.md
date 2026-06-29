# Onboarding V2 — Pre-Registration Personalized Flow

> **Status:** 🚧 In progress (started 2026-06-29). Replaces the legacy 6-step post-registration onboarding.
> **Owner doc:** this file is the single source of truth for the V2 flow. Update it as phases land.

---

## 1. Vision

A Yazio-grade first-run experience that sells the product *before* asking for an account, then
collects a deeply personalized profile in a warm, name-addressed, single-question-per-screen flow.
Every surface is flagship-grade (R7), 60fps, dark/light, EN/TR, iOS/Android.

**The inversion (core architectural change):** onboarding now runs **before** registration.

```
Splash
  └─► Intro carousel ──[Başla]──► Onboarding (14 pages, in-memory, NO uid)
         │                              │
   [Zaten hesabım var]            [Onayla]
         │                              ▼
         ▼                        Register (email/pw + consent)
       Login ◄──[Zaten hesabım var]─────┘   │  persist EVERYTHING at account creation
         ▲                                   ▼
     [Kayıt ol]──► Onboarding           AI meal-plan generation ──► Home
```

The legacy flow (register → verify → onboarding) is removed. `createUserDocumentOnRegister(user,
onboardingData)` already accepts the full profile at creation, so the inversion fits the existing
data layer cleanly.

---

## 2. Locked product decisions (confirmed with founder 2026-06-29)

| Topic | Decision | Why |
|---|---|---|
| Trust/social-proof page (7) | **Illustrative, clearly-labeled example journeys + science/privacy/KVKK badges.** No fabricated user reviews. | Fake testimonials = deceptive advertising under TKHK + EU UCPD; conflicts with legal-first stance. |
| Premium page (13) | **Teaser + intent capture.** Real purchase fires *after* the account exists, via existing `BillingService`. | No account/uid exists mid-onboarding; a purchase can't attach to a user yet. |
| Projections (5 + 14) | **Clamp to medically-safe rate (~0.5–0.75 kg/wk), show "tahmindir, tıbbi tavsiye değildir" disclaimer.** | Specific outcome promises in a health app carry medical-claim / advertising risk. |

## 3. Engineering calls (flagged — founder may veto)

1. **Height** is collected on **page 4** (age + height + weight) — the spec listed only age+weight, but
   BMI (report) and the water formula (page 11) both require height. Natural grouping; no extra page.
2. **Email verification** becomes a **soft in-app reminder**, not a hard route gate. New flow lands the
   user in the app immediately after registration (Yazio-style). Sensitive/social actions may still
   require verification. Reversible if stricter gating is preferred.

---

## 4. Page-by-page spec

> Shared chrome (`OnboardingScaffold`): radial brand glow · top progress bar + step counter · left
> circular back button · bottom gated "Devam et" (disabled until the page's requirement is met) ·
> 60fps page transitions. Copy is **name-personalized** ("{name}, ...") from page 2 onward.

| # | Page | Collects | Gating | Notes |
|---|------|----------|--------|-------|
| Intro | Feature carousel | — | — | Wordmark + language selector; ≥5 auto-advancing (5s) swipeable slides: AI plan, barcode/food scan, gyms, coaches, community, "who's at the gym 🔒". `Başla` + `Zaten hesabım var`. |
| 1 | Name | `firstName` → `displayName` | non-empty | Warm welcome; sets the personalization token. |
| 2 | Goal + gender | `mainGoal` (single), `gender` | both | Explain *why* gender is asked (BMR accuracy). |
| 3 | Activity + motivators | `activityLevel` (single), `primaryGoals` (≤5 multi) | activity + ≥1 motivator | "Seni heyecanlandıran şeyler" = legacy multi-goal chips. |
| 4 | Body metrics | `age`→`birthDate`, `height`, `weight` | all + age-gate ≥16 | AgeGate (KVKK/GDPR). Height added (see §3). |
| 5 | Target weight | `targetWeight` | set | **Dynamic safe projection** per `mainGoal` (rate, ETA, weekly delta) + disclaimer. |
| 6 | Motivation | — | — | Name-personalized motivational narrative; "AI asistanın yanında". |
| 7 | Trust | — | — | Illustrative example journeys (labeled) + science/privacy/KVKK badges. |
| 8 | Dietary | `allergies`, `dietaryRestrictions`, `dislikedFoods` | optional | Rebuilt; exhaustive coverage + searchable/custom ingredients. |
| 9 | Cooking | `cookingLevel` (single), `kitchenEquipment` (multi) | both | Rebuilt; full equipment coverage. |
| 10 | Lifestyle | `lifestyleProfile`, `mealSchedule` | profile | Keep current logic (founder likes it); restyle to V2. |
| 11 | Water (NEW) | `waterReminderEnabled`, `waterDailyTargetMl`, wake/sleep window | — | Formula from height/weight/age → target; permission primer → daily local schedule. |
| 12 | Household (NEW) | `cooksForOthers` | — | "Evde başka birine de yemek yapıyor musun?" Captured only; per-person logic shelved (§7). |
| 13 | Premium teaser | `wantsPremiumIntent` | — | Chain-locked, decorated; free-text "özel istek" preview (locked) + icon-recolor preview (locked); benefits + cancel-anytime; `Premium Al` (intent) + `Ücretsiz devam et`. |
| 14 | Report | — | — | Personalized: BMI + category, projection, daily calories/macros, water; "neden bizimle" trust block; `Onayla` → Register. |

`Zaten hesabım var` on intro/onboarding → `OnboardingProvider.reset()` → Login.

---

## 5. Data-model changes

**`OnboardingProvider` (in-memory, no uid during flow):** add
`firstName`, `mainGoal`, `waterReminderEnabled`, `waterDailyTargetMl`, `waterWakeTime`,
`waterSleepTime`, `cooksForOthers`, `wantsPremiumIntent`. Expose `publicOnboardingData` /
`privateNutritionData` getters for the registration writer. `reset()` clears all. Per-step Firestore
writes are removed (no uid); persistence is once, at registration.

**Public `users/{uid}.onboarding_data`** gains: `main_goal`, `target_weight`,
`water_reminder` `{enabled, target_ml, wake, sleep}`, `cooks_for_others`. `firstName` → top-level
`displayName`. `wantsPremiumIntent` is transient (drives post-register purchase, not stored here).

**Private `users/{uid}/private/nutrition`** unchanged: `personal_info{gender,birth_date,height,weight}`,
`allergies`, `dietary_restrictions`, `disliked_foods`.

**`UserModel`** gains `water_reminder` (map) + `cooks_for_others` (bool) mirrors for runtime use.

**New service `OnboardingProjectionService`** (pure Dart): BMI + category, BMR/TDEE (reuses
`CalorieCalculator`), calorie/macro targets, safe weekly rate + ETA (clamped), recommended daily water.

---

## 6. Phase plan

- ✅ **P0 Foundations** — `OnboardingProjectionService`; extended `OnboardingProvider` (V2 fields, in-memory); `OnboardingScaffold`; `OnboardingFlowScreen` host.
- ✅ **P1 Intro** carousel — `IntroScreen` (wordmark + EN/TR toggle, 6 auto-advancing/swipeable feature slides incl. premium "gym presence", dots, `Başla` + `Zaten hesabım var`); routes `intro`→new + `onboardingV2` (unwrapped); old `intro_onboarding_screen.dart` removed; Settings "replay" repointed. **Page 1 (Name)** also landed.
- ✅ **P2–P7 pages 2–14** — goal+gender · activity+motivators · age/height/weight · target-weight (live safe projection) · motivation · trust (illustrative) · dietary · cooking · lifestyle · water · household · premium teaser · report. Shared widgets in `v2/widgets/onboarding_widgets.dart`; all gated, personalized, EN/TR.
- ✅ **P8 Registration + routing inversion** — register screen is V2-aware (`_completeV2Onboarding`): persists public `onboarding_data` + private nutrition + `displayName`, sets `onboarding_completed`, records consents, schedules the water reminder, captures premium intent (`pending_premium_intent` pref), populates `UserProvider`, routes to meal-plan generation. Splash: new users → intro (else login); **email verification is now a soft reminder** (no hard gate in Splash/RouteGuard). Login "Kayıt ol" → `onboardingV2`. Water scheduling via `PushNotificationService.scheduleDailyWaterReminder` (now precise + multi-time via `zonedSchedule` — see follow-up below).
- ✅ **P9** docs + `flutter analyze` = 0 + i18n parity green.

### Follow-ups
- ✅ **Premium purchase surface** — home consumes `pending_premium_intent` once (`_maybeSurfacePremiumIntent`) → presents `AiCreditsSheet` (BillingService) for non-premium users.
- ✅ **Soft email banner** — dismissible "verify your email" banner on home (`_buildEmailBanner`) with resend.
- ✅ **Water precise scheduling** — shipped. Added `timezone` + `flutter_timezone`; tz DB initialized in
  `PushNotificationService.initialize()`. `scheduleDailyWaterReminder` now uses `zonedSchedule`
  (`matchDateTimeComponents.time`, **inexact** alarms → no Android 13+ exact-alarm permission) to fire
  several reminders at precise local clock times evenly spread across the wake→sleep window (handles
  midnight wrap), over a reserved id block (7001–7012); `cancelWaterReminder` clears the block. Editable
  post-onboarding from **Settings → Water reminder** (enable + wake/sleep, reschedules/cancels & persists
  `onboarding_data.water_reminder`). Android manifest gained `RECEIVE_BOOT_COMPLETED` + the
  `flutter_local_notifications` boot/scheduled receivers so reminders survive reboot/app-update. Spread
  math is unit-tested (`test/water_reminder_schedule_test.dart`). **Still requires on-device validation**
  (iOS + Android 13+ delivery, tz correctness, reboot reschedule) — can't be exercised in this env.
- ✅ **Legacy onboarding removed** (2026-06-29, option b — logged-in V2 path). Deleted `onboarding_screen.dart`, `steps/`, `screens/onboarding/widgets/`, and `lib/widgets/onboarding_common_widgets.dart`; dropped `AppRoutes.onboarding` and the orphaned `OnboardingProvider` legacy methods (`saveFinalOnboardingData`, `updateOnboardingDataInFirestore`, `logOnboarding*`, + their `AuthService`/`AnalyticsService` imports). Authenticated accounts with `onboarding_completed == false` (legacy incompletes **or** a V2 final-write failure) now complete in `OnboardingFlowScreen(loggedInCompletion: true)` — prefilled from `UserProvider.user.onboardingData` (+ `displayName`), persisted to their existing uid via the shared `OnboardingCompletion.finalizeAndRoute` (best-effort; `UserProvider` rebuilt via `copyWith` to dodge the stale `AuthService` cache). `OnboardingFlowResolver` now returns `main`/`onboardingV2` only (dropped the logged-out `intro` + `firstIncompleteStep` machinery, which also fixes the latent "completed user sent to intro" bug since Firestore `intro_seen` is never written in V2). Splash, RouteGuard (§B+§D), and verify-email repointed to `onboardingV2` + `loggedInCompletionArgs`. `flutter analyze lib/` = 0; `flutter test` green (64).
- ✅ **Tests** — `test/onboarding_projection_test.dart` locks the safe-rate clamping + water bounds + graceful degradation.

> **Preview:** the intro carousel is also reachable via **Settings → Replay intro**.

Each phase: R0–R9 + Definition of Done. Localization keys added EN+TR **sequentially** (R9).

---

## 7. Shelved / future (notes only — do not build yet)

- **Per-household meal scaling** (page 12 follow-up): if `cooksForOthers`, later ask spouse/child/other;
  for child, age bands (0–3 / 3–10) → portion up the main plan, suggest child-appropriate sides or
  (0–3) baby-food notes. Home would expose a portion multiplier / child-suggestion module. Design TBD.
- **App-icon recoloring** as a real premium feature: net-new, hard on iOS (alternate icons only, no
  arbitrary tint). Onboarding shows a *locked preview* only. Revisit with `flutter_dynamic_icon` later.
- **Server-side IAP receipt validation** before GA (BillingService verifies client-side today).
