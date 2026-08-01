# PROJECT_STATE.md — Live Status

> **Read this first, every session.** It is the single source of truth for *where the project is
> right now*. Everything else describes how the system works; this says what actually works.
>
> Keep it **small**. Status lines only — no design, no rationale, no task detail. Full task cards
> live in [`TODO.md`](TODO.md); decisions live in [`DECISIONS.md`](DECISIONS.md).

**Last updated:** 2026-08-01 · **Source of record:** `TODO.md` §1 (audit 2026-07-31; `BLK-13` re-verified 2026-08-01; `BLK-01` and `BLK-02` closed 2026-08-01)

---

## 1. Where we are

| | |
|---|---|
| `pubspec.yaml` version | `1.0.0+1` |
| **Honest state** | **v0.9.6 — internal alpha** (not shippable) |
| Current milestone | **M1 — Truth**: make what already exists actually work |
| First shippable | `v1.0.0-beta1`, consumer-only scope, after M1 + M2 + M3 |
| Store presence | None. Neither developer programme is enrolled. |
| Scope decision | **Consumer-only v1.** Gym / coach / programs / marketplace / commissions / payouts deferred to **M6**, kept in-tree behind kill-switches. See [`DECISIONS.md`](DECISIONS.md) ADR-012. |

### Progress to a public v1 — **~30–35 %**

| Dimension | % |
|---|---|
| Feature surface **written** | ~84 % |
| Feature surface **verified functional** | ~45 % |
| Backend / infrastructure configured | ~30 % |
| Security gates closed (`S0`–`S17`) | **0 %** |
| Monetization functional | **0 %** |
| Store readiness | ~10 % |
| Test coverage | ~1 % |
| Accessibility | ~15 % |

> ⚠️ **"Written" ≠ "works."** ~84 % of the feature surface exists in code; only ~45 % is verified
> functional. Seven confirmed dead paths, and no integration tests to bound the real number. Any doc
> that lists a feature as present is describing **code that exists**, not a proven working flow.
> Status lives here and nowhere else.

---

## 2. Health scorecard

| Dimension | Score | One-line reality |
|---|---|---|
| Architecture | 6.5 / 10 | Clean layering; god objects, abandoned repository layer, no DI seam |
| Flutter craft | 7.0 / 10 | Analyzer-clean at 115k LOC, real design system; 87 raw spinners, 334 hardcoded colours |
| Firebase | 6.0 / 10 | 684-line rules with real field-locking; 7 path/rule mismatches, 8 open-write holes |
| AI | 7.0 / 10 | Best-in-class quota/cost/injection/allergen layers; mock-data default fixed (`BLK-01`); real proxy E2E unverified (`BE-01`) |
| **Security** | **4.0 / 10** | Sophisticated design; **all 18 of its own gates unchecked**, App Check unenforced |
| Performance | 6.0 / 10 | Cached images, `pollCount`, pagination; **zero measurement anywhere** |
| UX | 6.5 / 10 | Design system + motion + flawless i18n; accessibility 3/10, loading states 4/10 |
| Scalability | 5.0 / 10 | Fine to ~100k with known work; hard **180-dish prompt ceiling** |
| Code quality | 6.5 / 10 | Readable, null-safe; **swallow-and-log is the systemic defect** |
| Maintainability | 5.5 / 10 | 40 files > 800 LOC, no interfaces, no test seam |
| **Documentation** | **6.5 / 10** | Well-organised and now status-honest (this file); breadth still outruns verification |
| **Testing** | **3.0 / 10** | **~1 % coverage** (unchanged) — but `test/` is now tracked, 0 failing, and **all 4 CI jobs are confirmed green** for the first time in this repo's history |
| Business readiness | 2.0 / 10 | **Zero revenue capability**; premium bypassable |
| Production readiness | 3.0 / 10 | CI green, worst data-integrity blocker fixed; still no monitoring, no backups, no store presence |
| **Weighted composite** | **5.4 / 10** | Strong design instincts, high velocity, **no verification discipline** |

---

## 3. Critical blockers — nothing ships until these close

Full cards in [`TODO.md`](TODO.md) §2.

| ID | Blocker | Domain |
|---|---|---|
| `BLK-03` | 🔥 Push fan-out — code+rules+tests complete, **deploy pending** (with `SEC-06`) | [Community](docs/COMMUNITY.md) |
| `BLK-04` | 🔥 Monetization non-functional end to end | [Premium](docs/PREMIUM.md) |
| `BLK-07` | 🔥 Gym logo upload writes to an unruled Storage prefix | [Gym](docs/GYM_ECOSYSTEM.md) |
| `BLK-08` | 🔥 Any user can mutate any post's non-content fields | [Security](docs/SECURITY.md) |
| `BLK-09` | 🔥 `coach_uid == 'demo'` lets any user publish to the public marketplace | [Coach](docs/COACH_ECOSYSTEM.md) |
| `BLK-10` | 🔥 User doc world-readable with `email`, `last_login_ip`, device fingerprints | [Security](docs/SECURITY.md) |
| `BLK-11` | 🔥 Dish catalog unseedable in-app; only 75 dishes | [Database](docs/DATABASE.md) |
| `BLK-12` | 🔥 GDPR erasure + export incomplete | [Compliance](docs/COMPLIANCE.md) |
| `BLK-14` | 🔥 App Check not enforced (`APP_ENV=development`) | [Security](docs/SECURITY.md) |
| `BLK-15` | 🔥 Live OpenRouter key bundled as a Flutter asset + shipped in CI artifacts | [AI](docs/AI_SYSTEM.md) |
| `BLK-16` | 🔥 No Apple / Google enrolment, no signing identity | [DevOps](docs/DEVOPS.md) |
| `BLK-17` | 🔥 No monitoring, alerting, backups; single environment | [DevOps](docs/DEVOPS.md) |

**Security gates `S0`–`S17`: all 18 open.** See [`docs/SECURITY.md`](docs/SECURITY.md) §8 and
`docs/roadmap/GO_LIVE.md` Phase 5S. `S0` (rotate the leaked Admin SA key) is first and unblocks nothing else — do it now.

---

## 4. Partially working — code exists, flow is broken

| System | Blocked by |
|---|---|
| 🚧 AI meal planning · recipe generation — no longer fabricates when unconfigured (`BLK-01` ✅); real end-to-end generation still unverified | `BE-01` |
| 🚧 Push notifications — every notification type now has a server-authored writer (`notifications.js`/`social.js`); chat push still the only one confirmed live pre-deploy | `BLK-03` |
| 🚧 Admin surface (~7,400 LOC, 9 screens) — reachable now (`BLK-05` ✅); no real admin session has exercised it yet | — |
| 🚧 Monetization (IAP client + server validation both exist) | `BLK-04` |
| 🚧 Gym ecosystem (11 screens) · Coach ecosystem (8 screens) | `BLK-03`, `BLK-07` |
| 🚧 Friends/follow — code+rules complete for server-authored writes (`SEC-06`), deploy pending | `SEC-06` |
| 🚧 Program marketplace | `BLK-09` |
| 🚧 Dish catalog | `BLK-11` |
| 🚧 Moderation (scans wrong prefix; queue reachable but unstaffed) | — |
| 🚧 CD — deploy workflow (TestFlight + Play, never run) | `BLK-16` |

## 5. Verified working

Auth (email/Google/Apple) · Onboarding V2 · calorie & macro maths · streak logic · food diary ·
recent/favourite foods · water reminders · weight/hydration/exercise logging · shopping list ·
cooking mode · community feed & comments & reactions · 1:1 + group chat · in-app notifications ·
achievements · AI insight/twin/recap (all guard `isConfigured`) · AI proxy security core ·
AI meal-plan/recipe generation degradation path (`BLK-01` — throws + branded error state when
unconfigured, never fabricates; real proxy call path still unverified, see `BE-01`) ·
iOS photo-picker path (`BLK-02` — `NSPhotoLibraryUsageDescription` present, all 6 gallery call sites
prime via `PermissionService`, permanent CI guard against the string going missing again; confirmed
crash-free on Simulator, physical-iPhone confirmation still pending a device) ·
meal plan history (`BLK-06` — owner rule deployed to production, both read/write paths report to
Crashlytics; rules test confirmed passing in CI, full on-device flow not separately walked) ·
admin authorization (`BLK-05` — `syncAdminClaim` deployed and confirmed live via `firebase
functions:list`; all 3 client gates re-pointed at the custom claim; rules tests confirm the
`admin_roles` → `isAdmin()` chain end to end in CI; no real admin session has exercised the 9-screen
surface yet — nobody has been console-provisioned) ·
allergen pre-filter · prompt-injection guard · Hive AES-256 · consent registry · design system ·
EN/TR parity (2,722 keys) · maintenance + force-update gates · feature kill-switches ·
image upload pipeline · `pollCount` discipline · `flutter analyze lib/` 0 errors ·
Firestore rules test suite (22 test cases, partial coverage) green in real CI
([run #30704409637](https://github.com/burcok/cookrange/actions/runs/30704409637), incl. the 4 new
`BLK-03`/`SEC-06` assertions) ·
**CI — all 4 jobs green** (`analyze-and-test`, `firestore-rules`, `secret-scan`, `build-android`),
confirmed in a real run, first time in this repo's history.

Evidence table: `TODO.md` §1.4.

## 6. Not built at all

Integration/widget tests · rules tests in VCS · monitoring & SLOs · structured production logging ·
staging environment · backups & DR · DI / service interfaces · full-text search · payout rail ·
XP/levels · white-label · auth rate-limiting & MFA · server-side streak/reputation · migration
framework · proxy load testing · API versioning · release obfuscation · tablet layouts · offline
write queue · behavioural-analytics ML.

IDs in `TODO.md` §1.6.

---

## 7. Milestones

| Milestone | Version | Exit criterion | Est (solo) |
|---|---|---|---|
| **M1 — Truth** | `v0.9.7` | Every consumer-path feature demonstrated on a physical iPhone **and** Android against a production-configured backend. All 17 blockers closed (`BLK-13` ✅, `BLK-01` ✅, `BLK-02` ✅ code/CI, physical-device confirmation still owed, 14 remain). ~~CI green~~ **✅ done** — all 4 jobs confirmed. | 4–6 w |
| **M2 — Legal** | `v0.9.8` | `S0`–`S17` green. User doc split. Erasure + export complete. Privacy labels + Data Safety filed. DPA executed. Backups live. | 3–4 w ∥ |
| **M3 — Commerce** | `v0.9.9` | Both stores enrolled. 3 products live. One real sandbox purchase → real entitlement. Premium gated server-side. | 3–4 w ∥ |
| **M4 — Beta** | `v1.0.0-beta1` | 50–100 real users. Dish catalog ≥ 300. D7 measured. Crash-free > 99 %. A11y pass on 10 flows. | 4 w |
| **M5 — Launch** | `v1.0.0` | Live on both stores, staged rollout, alerting on, rollback lever tested. | 2–3 w |
| **M6 — Ecosystem** | `v1.1.0` | Gym + coach reopened. 5–10 pilots. Payout rail live. `BLK-09` closed. | 6–8 w |
| **M7 — Scale** | `v1.2.0`+ | Search, BigQuery, Cloud Tasks fan-out. 10k → 100k users. | ongoing |

**To M5:** solo 2.5–3.5 months with the consumer-only cut applied · 2 engineers 1.5–2 months.
Store review is an irreducible 1–2 weeks of wall clock.

---

## 8. Next recommended actions

1. **`S0` — rotate the leaked Firebase Admin service-account key.** Independent of everything; a live
   key bypassing all rules is the highest-severity open item.
2. ~~**`BLK-01`**~~ **Done** — mock block deleted, `isConfigured` guards added to both AI services,
   branded error states wired in `home.dart` / `explore_screen.dart`, startup Crashlytics assertion
   added, regression test in `test/meal_plan_ai_unavailable_test.dart`. Release builds can no longer
   fabricate a meal plan. **Residual:** `BE-01` (deploy `aiProxy` + set `ai_proxy_url`) is now a hard
   launch dependency instead of a silently-degraded one — without it, users see the honest error state
   forever, not a broken app, but the feature doesn't work either.
3. ~~**`BLK-13`** / **`CI-11`** / **`CI-12`**~~ **All done — all 4 CI jobs confirmed green**
   ([run #46](https://github.com/burcok/cookrange/actions/runs/30690211684), commit `091429e`), first
   time in this repo's history. Four stacked root causes found and fixed across the two follow-on
   cards: a stale Flutter CI pin, an invalid `firebase_options.dart` placeholder, a genuine
   `assets/Fonts`/`assets/fonts` case-sensitivity bug masked by macOS project-wide, and a hardcoded
   local-machine-only Java path in `android/gradle.properties`. Every one confirmed by reproduction —
   a real `ubuntu:24.04` container (via `colima`, no Docker Desktop here) matching CI's architecture,
   with a full Android SDK set up for the last one — not guessed at from log fragments. **Recommended
   next step: `CI-02` branch protection**, now genuinely achievable; not done here, since it's a
   repository-settings change outside what was asked for.
4. ~~**`BLK-02`**~~ **Done (code)** — `NSPhotoLibraryUsageDescription` added; found and fixed a related
   gap along the way (3 of 6 gallery call sites had no `PermissionService` priming at all — now all
   six do); added `scripts/check_ios_permissions.sh` as a permanent CI guard so a missing iOS usage
   string can't recur silently. **Residual:** physical-iPhone confirmation and a signed
   `flutter build ipa` are still owed — verified on the Simulator only (no crash, correct primer +
   Settings-redirect flow), and a real device needs `BLK-16` (no signing identity yet) regardless.
5. ~~`BLK-06`~~ **done** — `meal_plan_history` rule deployed to production with your go-ahead, rules
   test confirmed green in CI.
   ~~`BLK-05`~~ **done** — `admin_roles` custom-claim sync (`syncAdminClaim`) deployed to production
   with your go-ahead (`firebase deploy --only functions:syncAdminClaim`, confirmed live via
   `firebase functions:list`); all three client gates, the bootstrap runbook, and rules tests
   shipped alongside it. Followed with a downstream sweep of the ~30 "unreachable until `BLK-05`"
   references across `TODO.md` (`ADM-*`, `MOD-01`, `NOTIF-13`, `MKT-02`, `LEG-09`, etc.) now that
   the fix is confirmed live.
6. **`BLK-03` + `SEC-06`** — **code+rules+tests complete, deploy pending.** One canonical notification
   path (`notifications/{uid}/items/{docId}`), all creation moved server-side
   (`functions/notifications.js`, `social.js`): `createNotification`/`retractNotification` (generic
   social types, actor always re-derived from `context.auth.uid`), `sendAdminNotification`
   (admin-claim-gated), and `followUser`/`unfollowUser`/`sendFriendRequest`/`respondToFriendRequest`/
   `cancelFriendRequest` (edge + notification written atomically). `firestore.rules`: `friends`/
   `friend_requests` locked to server-only, old `users/{uid}/notifications` retired (straight cutover —
   no real users yet to migrate), new canonical path rule added. Found and fixed two adjacent bugs in
   the same files: `executeBroadcast`/`applyReferral` wrote `createdAt` instead of `timestamp` (would
   have silently excluded those docs from the paginated feed once this path became canonical), and
   `executeBroadcast` was double-sending push (its own direct send plus a second generic-text send via
   the trigger it also happened to write into). `getPushText` rewritten with full EN/TR text for all 21
   `NotificationType` values, closing `I18N-04` in the same change. 4 new rules tests written. **Not
   deployed** — held for explicit go-ahead, same as `BLK-05`/`BLK-06`. Physical push delivery **cannot
   be verified in this environment**: no iOS/Android hardware, and the iOS Simulator cannot receive
   real APNs push at all — this is a harder limit than `BLK-01`/`BLK-02`'s partial Simulator
   verification.
7. Then M2 security gates in the order fixed by `GO_LIVE.md` Phase 5S — **server write paths first
   (`S2`→`S3`→`S4`), then lock the rules (`S1`, `S5`)**. Locking first breaks live flows.

---

## 9. Maintaining this file

Update it when — and only when — one of these changes: version, milestone, a blocker opens/closes,
a health score moves, or a system changes column (built → working, or working → broken).
A feature landing in code is **not** a reason to touch §5; moving it to §5 requires demonstrating it
works. Keep the whole file under ~200 lines.
