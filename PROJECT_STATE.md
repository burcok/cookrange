# PROJECT_STATE.md — Live Status

> **Read this first, every session.** It is the single source of truth for *where the project is
> right now*. Everything else describes how the system works; this says what actually works.
>
> Keep it **small**. Status lines only — no design, no rationale, no task detail. Full task cards
> live in [`TODO.md`](TODO.md); decisions live in [`DECISIONS.md`](DECISIONS.md).

**Last updated:** 2026-08-01 · **Source of record:** `TODO.md` §1 (audit 2026-07-31; `BLK-13` re-verified 2026-08-01)

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
| AI | 5.5 / 10 | Best-in-class quota/cost/injection/allergen layers; **fatal mock-data default** |
| **Security** | **4.0 / 10** | Sophisticated design; **all 18 of its own gates unchecked**, App Check unenforced |
| Performance | 6.0 / 10 | Cached images, `pollCount`, pagination; **zero measurement anywhere** |
| UX | 6.5 / 10 | Design system + motion + flawless i18n; accessibility 3/10, loading states 4/10 |
| Scalability | 5.0 / 10 | Fine to ~100k with known work; hard **180-dish prompt ceiling** |
| Code quality | 6.5 / 10 | Readable, null-safe; **swallow-and-log is the systemic defect** |
| Maintainability | 5.5 / 10 | 40 files > 800 LOC, no interfaces, no test seam |
| **Documentation** | **6.5 / 10** | Well-organised and now status-honest (this file); breadth still outruns verification |
| **Testing** | **2.5 / 10** | **~1 % coverage** (unchanged) — but `test/` is now tracked, 0 failing, the rules suite runs green in real CI; `CI-11`'s 3 stacked root causes (stale Flutter pin, invalid CI placeholder, a real `assets/Fonts` vs `assets/fonts` case bug) all fixed and container-verified, pending final real-CI confirmation |
| Business readiness | 2.0 / 10 | **Zero revenue capability**; premium bypassable |
| Production readiness | 2.5 / 10 | Two hard ship blockers, CI red, no monitoring, no backups |
| **Weighted composite** | **5.4 / 10** | Strong design instincts, high velocity, **no verification discipline** |

---

## 3. Critical blockers — nothing ships until these close

Full cards in [`TODO.md`](TODO.md) §2.

| ID | Blocker | Domain |
|---|---|---|
| `BLK-01` | 🔥 Release builds serve **hardcoded fake AI content** by default | [AI](docs/AI_SYSTEM.md) |
| `BLK-02` | 🔥 `NSPhotoLibraryUsageDescription` missing from iOS `Info.plist` — crash + auto-rejection | [Platform](docs/PLATFORM.md) |
| `BLK-03` | 🔥 Push fan-out wired to a path nothing writes | [Community](docs/COMMUNITY.md) |
| `BLK-04` | 🔥 Monetization non-functional end to end | [Premium](docs/PREMIUM.md) |
| `BLK-05` | 🔥 Admin surface unreachable — `admin_roles/{uid}` created by nothing | [Security](docs/SECURITY.md) |
| `BLK-06` | 🔥 `meal_plan_history` has an index but **no rule** → permanently empty | [Database](docs/DATABASE.md) |
| `BLK-07` | 🔥 Gym logo upload writes to an unruled Storage prefix | [Gym](docs/GYM_ECOSYSTEM.md) |
| `BLK-08` | 🔥 Any user can mutate any post's non-content fields | [Security](docs/SECURITY.md) |
| `BLK-09` | 🔥 `coach_uid == 'demo'` lets any user publish to the public marketplace | [Coach](docs/COACH_ECOSYSTEM.md) |
| `BLK-10` | 🔥 User doc world-readable with `email`, `last_login_ip`, device fingerprints | [Security](docs/SECURITY.md) |
| `BLK-11` | 🔥 Dish catalog unseedable in-app; only 75 dishes | [Database](docs/DATABASE.md) |
| `BLK-12` | 🔥 GDPR erasure + export incomplete | [Compliance](docs/COMPLIANCE.md) |
| `BLK-13` | 🚧 Own defects fixed & verified in real CI; **`CI-11`** found 3 stacked root causes (stale Flutter pin; an invalid `firebase_options.dart` CI placeholder; a real `assets/Fonts`/`assets/fonts` case-sensitivity bug masked by macOS for the project's whole life) — all fixed, verified in a real Ubuntu container matching CI exactly, pending final real-CI confirmation | [Testing](docs/TESTING.md) |
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
| 🚧 AI meal planning · recipe generation | `BLK-01` |
| 🚧 Push notifications (chat push works; social/admin push does not) | `BLK-03` |
| 🚧 Admin surface (~7,400 LOC, 9 screens) | `BLK-05` |
| 🚧 Monetization (IAP client + server validation both exist) | `BLK-04` |
| 🚧 Gym ecosystem (11 screens) · Coach ecosystem (8 screens) | `BLK-05`, `BLK-03`, `BLK-07` |
| 🚧 Program marketplace | `BLK-09` |
| 🚧 Meal plan history | `BLK-06` |
| 🚧 Dish catalog | `BLK-11` |
| 🚧 Moderation (scans wrong prefix; queue unreachable) | `BLK-05` |
| 🚧 CI/CD (4 jobs + full deploy workflow, 2/4 confirmed green, 2/4 fix pending re-verification) | — |

## 5. Verified working

Auth (email/Google/Apple) · Onboarding V2 · calorie & macro maths · streak logic · food diary ·
recent/favourite foods · water reminders · weight/hydration/exercise logging · shopping list ·
cooking mode · community feed & comments & reactions · 1:1 + group chat · in-app notifications ·
achievements · AI insight/twin/recap (all guard `isConfigured`) · AI proxy security core ·
allergen pre-filter · prompt-injection guard · Hive AES-256 · consent registry · design system ·
EN/TR parity (2,722 keys) · maintenance + force-update gates · feature kill-switches ·
image upload pipeline · `pollCount` discipline · `flutter analyze lib/` 0 errors ·
Firestore rules test suite (15 assertions, partial coverage) green in real CI.

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
| **M1 — Truth** | `v0.9.7` | Every consumer-path feature demonstrated on a physical iPhone **and** Android against a production-configured backend. All 17 blockers closed. CI green. | 4–6 w |
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
2. **`BLK-01`** — add the `isConfigured` guard so release builds cannot serve fabricated meal plans.
   Fabricated health guidance is the worst failure mode this app has.
3. ~~**`BLK-13`**~~ **Done** — `test/` tracked, 3 failures fixed, rules suite green in real CI
   ([run #40](https://github.com/burcok/cookrange/actions/runs/30667024406)). ~~**`CI-11`**~~ **All 3
   root causes fixed**: stale Flutter pin (confirmed fixed in
   [run #42](https://github.com/burcok/cookrange/actions/runs/30669425771)); an invalid
   `firebase_options.dart` CI placeholder (was literally just a comment, causing 3 undefined-name
   errors — fixed with a real minimal stub); and a genuine `assets/Fonts/` vs `assets/fonts/` case
   mismatch masked by macOS's case-insensitive filesystem for the project's entire life, invisible
   until Linux (CI, real Android devices) tried to resolve it — fixed via case-only rename, plus 54
   accidentally-committed Xcode build-cache files removed along the way. Verified in a real
   `ubuntu:24.04` container matching CI's architecture exactly (no Docker Desktop here — installed
   `colima`). **Push and get the real CI confirmation**, then add branch protection (`CI-02`).
4. **`BLK-02`** — add the missing iOS usage string (one line, prevents 6 crashes + rejection).
5. **`BLK-05` / `BLK-03` / `BLK-06`** — the "shipped but dead" cluster: create `admin_roles`, point
   the push trigger at the real path, add the `meal_plan_history` rule.
6. Then M2 security gates in the order fixed by `GO_LIVE.md` Phase 5S — **server write paths first
   (`S2`→`S3`→`S4`), then lock the rules (`S1`, `S5`)**. Locking first breaks live flows.

---

## 9. Maintaining this file

Update it when — and only when — one of these changes: version, milestone, a blocker opens/closes,
a health score moves, or a system changes column (built → working, or working → broken).
A feature landing in code is **not** a reason to touch §5; moving it to §5 requires demonstrating it
works. Keep the whole file under ~200 lines.
