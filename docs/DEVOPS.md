# DEVOPS.md — CI/CD, Environments & Release

> How code gets built, verified, and shipped. Test *content* lives in [`TESTING.md`](TESTING.md);
> native config lives in [`PLATFORM.md`](PLATFORM.md); the ordered launch path lives in
> [`roadmap/GO_LIVE.md`](roadmap/GO_LIVE.md).
>
> **Owns:** `.github/workflows/`, `firebase.json`, `.firebaserc`, environment and secret management.

---

## 1. CI — `.github/workflows/ci.yml`

Runs on every PR. Flutter 3.44.4 (`CI-11` — bumped from a stale 3.24.0 pin that predated the
project's own dependency versions and made `flutter pub get` fail outright in CI).

```
dart format --set-exit-if-changed   →   flutter analyze   →   flutter test   →   Android debug APK
```

> **All 4 jobs are confirmed green** (`analyze-and-test`, `firestore-rules`, `secret-scan`,
> `build-android` — [run #46](https://github.com/burcok/cookrange/actions/runs/30690211684)), the
> first time in this repo's history. `analyze-and-test` had failed at `Get dependencies` on 3 stacked
> root causes (tracked as `CI-11`); `build-android` failed downstream of it, plus one root cause of its
> own (`CI-12`). Both are fixed and confirmed — see `PROJECT_STATE.md`/`CHANGELOG.md` for the detail.
> A green local run is still not the same claim as a green pipeline — always check the real one.

Match CI locally before calling a task done:

```bash
dart format lib/
flutter analyze lib/
flutter test
```

## 2. CD — `.github/workflows/deploy.yml`

Runs on push to `main`. **Never executed successfully** — no signing identity exists yet (`BLK-16`).

| Job | Runner | Steps |
|---|---|---|
| `deploy-ios` | macOS | `pod install` → import cert + provisioning profile → inject team ID into `ExportOptions.plist` → `flutter build ipa --release` → upload to TestFlight (altool) |
| `deploy-android` | Ubuntu | decode keystore → write `key.properties` → `flutter build appbundle --release` → upload to the Play internal track |

> ⚠️ Release builds are **not obfuscated** (`CI-05`). Ship with
> `--obfuscate --split-debug-info=<dir>` and upload symbols, and **never distribute the debug APK** —
> it currently carries the bundled OpenRouter key (`BLK-15`).

---

## 3. Secrets

**Nothing secret is committed. Ever.** `app_config/global` is public-read — it must never hold one.

| Secret | Home | State |
|---|---|---|
| `OPENROUTER_API_KEY` | `functions/.env` (server) | 🔥 also bundled as a Flutter asset — `BLK-15` |
| Firebase Admin SA key | Nowhere — Functions use ADC | 🔥 a live key was committed — rotate (`S0`) |
| `APPLE_CERTIFICATE_BASE64` / `_PASSWORD` | GitHub secrets | Not created |
| `APPLE_PROVISIONING_PROFILE_BASE64`, `APPLE_DEVELOPMENT_TEAM` | GitHub secrets | Not created |
| `APP_STORE_CONNECT_{KEY_ID,ISSUER_ID,PRIVATE_KEY}` | GitHub secrets | Not created |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD` | GitHub secrets | Not created |
| `PLAY_STORE_SERVICE_ACCOUNT_JSON` | GitHub secrets | Not created |
| Apple `.p8` + Play service account (purchase validation) | Function secrets | Not provisioned (`BLK-04`) |

A **secret-scanning gate** (gitleaks / trufflehog, pre-commit + CI, failing on any `service_account`
JSON or PEM) is still to be added. Deleting a leaked key is not rotation — **rotate**.

---

## 4. Environments

> ⚠️ **There is exactly one environment.** `.firebaserc` has `default = cookrange-app`. There is no
> staging and no dev project, so *every* rules or Functions deploy is a production deploy against
> real data (`INF-01`).

**Target separation** (`GO_LIVE.md` Phase 5U):

1. Create `cookrange-staging` (and optionally `cookrange-dev`)
2. Add Flutter **flavors** (dev/staging/prod) with per-flavor application IDs, their own
   `google-services.json` / `GoogleService-Info.plist`, and generated `firebase_options`
3. `firebase use --add` to map aliases; deploy with `firebase deploy -P staging`
4. CI deploys to **staging on `develop`**, production only on a tagged release

### Runtime config

| Layer | Where | Changes require |
|---|---|---|
| `APP_ENV` (Functions) | `functions/.env` — `development` \| `production` | Redeploy |
| Model, tokens, quota, version gates, kill-switches | Firestore `app_config/global` | **Nothing** — admin panel, live |
| Legacy flags | Firebase Remote Config | Publish (being superseded — ADR-011) |

`APP_ENV=development` relaxes App Check enforcement and store-credential requirements so Functions
deploy without Apple/Google setup. **It is currently `development` in production** (`BLK-14`).

### Local setup — `lib/firebase_options.dart`

Gitignored (`.gitignore:53`) and **not** committed — it holds only public client identifiers (API
key, app ID, project ID; no secret), but keeping it generated-not-checked-in is what lets flavors
(above) each carry their own without a merge conflict. A fresh clone has no way to build until it
exists:

```bash
dart pub global activate flutterfire_cli   # once per machine
flutterfire configure --project=cookrange-app
```

This writes `lib/firebase_options.dart` and registers the platform apps it doesn't already find in
the project. CI does not run this — it writes a placeholder instead (`ci.yml`, "Create
firebase_options.dart placeholder" step, in both `analyze-and-test` and `build-android`).

That placeholder must be **real, minimal, valid Dart** — a bare comment doesn't work
(`CI-11`, found the hard way: `main.dart` and two other files reference
`DefaultFirebaseOptions.currentPlatform` at the top level, so `flutter analyze` needs the class to
exist even though nothing ever calls `Firebase.initializeApp()` in that job). The placeholder defines
`DefaultFirebaseOptions.currentPlatform` with dummy values — enough to satisfy the analyzer and the
debug APK build, never enough to actually reach Firebase.

Committing the real file (still `DEBT-52`) remains a gap for anyone bootstrapping a device build
straight from CI's config — the placeholder only gets analyze/test/debug-build this far, not a
working Firebase connection.

---

## 5. Deploying Firebase

```bash
firebase deploy --only functions
firebase deploy --only firestore:rules,firestore:indexes,storage:rules
```

**Order is load-bearing (ADR-008).** Deploy server write paths (`S2` ledger → `S3` purchases →
`S4` economy) **before** locking rules (`S1`, `S5`). Locking first breaks live client writes.
Run the rules-emulator suite before `S1`.

### After deploying `aiProxy` — required, or it 401s

```bash
gcloud functions add-iam-policy-binding aiProxy \
  --region=us-central1 --member=allUsers --role=roles/cloudfunctions.invoker
```

`aiProxy` is `https.onRequest`; the platform deploys it **private** and returns a 401 HTML page
before your code runs. All real auth is in-code — the standard Firebase-callable pattern.

### Known deploy behaviour on this project
- ⚠️ Functions run in `us-central1`, Firestore in `europe-west10`. The CLI frequently prints
  `failed to update` while the deploy **lands asynchronously**. **Verify in the console; don't trust
  the CLI exit code.**
- ⚠️ Back-to-back deploys return `operation already in progress` (code 9). Wait between them.
- Functions are gen1 on Node 22. The gen2 migration **and** region collocation must be done as one
  atomic, staging-verified change — piecemeal produces **duplicate triggers and double pushes**
  (`GO_LIVE.md` Phase 5T).

---

## 6. Release process

```
1. All Definition-of-Done boxes green (CLAUDE.md §11)
2. CI green on main                                   ← all 4 jobs confirmed (run #46; `CI-11`/`CI-12`
                                                          closed)
3. Bump version in pubspec.yaml
4. Update CHANGELOG.md
5. Update PROJECT_STATE.md — version, milestone, blockers
6. Tag the release
7. deploy.yml → TestFlight + Play internal
8. Verify on real iOS AND Android hardware
9. Promote: TestFlight external → App Store · Play internal → staged rollout 10% → 50% → 100%
10. Watch Crashlytics velocity + Performance for 72h
```

The launch gate is `GO_LIVE.md` Phase 7.3, whose hard precondition is the **Phase 5S security gate
fully green**.

---

## 7. Monitoring, backups, recovery

> ⚠️ **None of this exists** (`BLK-17`). No monitoring, no alerting, no backups, no DR plan, single
> environment. A production service cannot be operated or recovered in this state.

**Required before public traffic:**

| Area | Action |
|---|---|
| Crashlytics | Velocity alerts on |
| Performance | Custom alert: `aiProxy` P95 > 5s |
| Uptime | Cloud Monitoring check on the `aiProxy` URL |
| Cost | Cloud Billing budget + email/Pub/Sub alert; **separate OpenRouter hard spend cap** |
| Backups | Firestore **PITR** (7-day window — one click) + daily scheduled backup, 7–30 day retention |
| TTL | Policies on `signals.expiresAt`, old `logs`, `processed_purchases` (after the refund window) |
| Runbook | Documented restore procedure, tested at least once |

**Incident levers already in code:** `app_config/global` → `maintenance` (locks the app to a
maintenance screen) and `version.force_update` (forces an upgrade). Both apply without a redeploy and
are evaluated first in `RouteGuard`. **Test both before you need them.**

---

## 8. Console setup

One-time Firebase Console steps (API key restrictions, App Check registration, APNs upload) are in
[`firebase-console-setup.md`](firebase-console-setup.md). Store enrolment, signing, listings, and IAP
products are in [`roadmap/GO_LIVE.md`](roadmap/GO_LIVE.md) Phases 0–4 — all owner actions that no
agent can perform.
