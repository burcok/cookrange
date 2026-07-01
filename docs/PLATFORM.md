# PLATFORM.md — iOS & Android Parity

> Cookrange ships to **both** iOS and Android. Every feature must be designed and tested for both.
> This is the checklist + the known platform-specific seams. Consult before any platform-touching
> change (permissions, sign-in, native config, gestures, store submission).

---

## 1. The Parity Rule
When you build or change anything, ask: **"Does this behave correctly on iOS *and* Android?"**
- Respect **safe areas** (notches, home indicator, gesture nav) — `SafeArea` / `MediaQuery.padding`.
- Use **haptics** on meaningful actions (already in `AppButton`/`AppCard`).
- Platform-guard divergent behavior with `Platform.isIOS` / `Platform.isAndroid`.
- Test scroll physics, keyboard insets, and back-gesture on both.
- Never assume a permission flow is identical — see §3.

## 2. Identifiers (must stay matched everywhere)
| | Android | iOS |
|---|---|---|
| Package / Bundle ID | `com.cookrange_android.app` | `com.cookrange-ios.app` |
| Source of truth | `android/app/build.gradle` (`applicationId`, `namespace`) | `ios/Runner.xcodeproj` (`PRODUCT_BUNDLE_IDENTIFIER`) |
| Firebase config | `android/app/google-services.json` | `ios/Runner/GoogleService-Info.plist` |
| Firebase App ID | `1:624768719440:android:6e762e988ba00350ba4f55` | `1:624768719440:ios:20fc7f605a4663c8ba4f55` |

> ⚠️ iOS bundle IDs **cannot contain underscores** (Apple rule) — Cookrange uses a hyphen
> (`com.cookrange-ios.app`). Keep Xcode, `GoogleService-Info.plist`, Firebase Console, App Store
> Connect, and `ios/ExportOptions.plist` all on the hyphen form. Android uses underscores and that
> is consistent across code + config + console.

## 3. Platform-Specific Seams
| Concern | iOS | Android |
|---|---|---|
| Sign-in | Apple Sign-In (required by Apple if Google offered) + Google | Google + email |
| Tracking | **ATT** prompt (`ATTConsentService`, `NSUserTrackingUsageDescription`, one-shot) | n/a |
| App Check | **App Attest (release)** / debug provider only in debug builds | **Play Integrity (release)** / debug provider only in debug builds |
| Push | APNs via FCM (needs APNs key in Firebase) | FCM direct |
| Permissions | `Info.plist` usage strings (camera, mic, photos, location, tracking) | `AndroidManifest.xml` `<uses-permission>` + runtime requests |
| Permission UX | Always precede the OS dialog with `PermissionPrimer.show()` **including a KVKK/GDPR disclosure** (purpose + whether stored + declinable) — see `docs/COMPLIANCE.md` §6 | same |
| Deep links | `Runner.entitlements` `applinks:cookrangeapp.com` + AASA file | `intent-filter autoVerify=true` + assetlinks.json |
| Min OS | iOS deployment target (Podfile/Xcode) | `minSdkVersion` (build.gradle) |
| Build artifact | `.ipa` (App Store / TestFlight) | `.aab` (Play) / `.apk` (debug/CI) |
| Keep-screen-on | `wakelock_plus` (cooking mode) | same |

## 4. Native Config Locations
- **Android:** `android/app/build.gradle` (applicationId, signing, minSdk, desugaring, Firebase BoM),
  `android/app/src/main/AndroidManifest.xml` (permissions, deep-link intent filters, FCM),
  `android/gradle.properties` (JDK path), `key.properties` (release signing, gitignored).
- **iOS:** `ios/Runner.xcodeproj/project.pbxproj` (bundle ID), `ios/Runner/Info.plist` (permission
  strings, ATT), `ios/Runner/Runner.entitlements` (universal links, sign-in with Apple),
  `ios/ExportOptions.plist` (App Store export + provisioning), `ios/Podfile`.

## 5. CI/CD (`.github/workflows/`)
- **ci.yml** (every PR): Flutter 3.24.0 → `dart format --set-exit-if-changed` → `flutter analyze`
  → `flutter test` → Android debug APK build.
- **deploy.yml** (push to main):
  - **deploy-ios** (macos): `pod install` → import Apple cert + provisioning → inject team ID into
    `ExportOptions.plist` → `flutter build ipa --release` → upload to TestFlight (altool).
  - **deploy-android** (ubuntu): decode keystore → `key.properties` → `flutter build appbundle
    --release` → upload to Play internal track.
- **Secrets needed:** `OPENROUTER_API_KEY`; iOS: `APPLE_CERTIFICATE_BASE64`,
  `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISIONING_PROFILE_BASE64`, `APPLE_DEVELOPMENT_TEAM`,
  `APP_STORE_CONNECT_{KEY_ID,ISSUER_ID,PRIVATE_KEY}`; Android: `ANDROID_KEYSTORE_BASE64`,
  `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`,
  `PLAY_STORE_SERVICE_ACCOUNT_JSON`.

## 5b. Cloud Functions Env & AI Proxy Config

**`functions/.env`** (runtime env, not committed):
- `APP_ENV` — `development` | `production` (see §7 / GO_LIVE Phase 5S).
- `OPENROUTER_MODEL` — default model, now **`openai/gpt-4o-mini`** (the old
  `deepseek/…:free` model was removed from OpenRouter → 404). This is a **paid** model, so the
  OpenRouter account needs credit.
- `OPENROUTER_TIMEOUT_S` — request timeout in seconds (default **90**; the client text timeout was
  raised 45→90s to match, so long meal-plan generations don't cut off).

**`aiProxy` (server-authoritative model + usage logging):**
- Reads **`app_config/global`** with the Admin SDK (5-minute in-memory cache) and takes the
  **model, `max_tokens`, `temperature`, and quota FROM THERE** — it **ignores the model the client
  sends** (cost safety). This means model / token / quota can be changed **from the admin panel with
  no redeploy**.
- `MAX_OUTPUT_TOKENS` raised **1024 → 8192** so large meal-plan JSON responses aren't truncated.
- Captures OpenRouter's `usage` token counts on every call and logs the **real** cost to
  `ai_usage_logs` / `ai_usage_stats`.

> ⚠️ **`aiProxy` public-invoker requirement (deploy step).** `aiProxy` is an `https.onRequest`
> function; the Cloud Functions platform deploys it **private**, so the real authentication happens
> **inside the code** (Firebase ID-token verify + App Check). For it to be reachable, the function
> must have `allUsers` granted the **Cloud Functions Invoker** role — otherwise the platform returns
> a **401 HTML** page before the code runs:
> ```bash
> gcloud functions add-iam-policy-binding aiProxy \
>   --region=us-central1 --member=allUsers --role=roles/cloudfunctions.invoker
> ```
> This is the standard pattern for Firebase Callables; security is provided by the in-code layers
> (ID token + quota + rate-limit + model allowlist), not by the platform invoker gate.

## 5c. Remote App Config — `app_config/global`

Firestore **`app_config/global`** (public-read, admin-write, contains **no secrets**) is the
consolidated remote config surface: `ai` (model/tokens/temperature/quota), `version` (force/soft
update), `maintenance`, `announcement`, `features` (kill-switches), `rollout`, `limits`, `endpoints`.
- Client-side `AppConfigService` (cache-first + 6h TTL) drives version-gating (force / soft update),
  maintenance mode, the announcement banner, and feature kill-switches; edited in-app via
  `AdminAppConfigScreen`.
- This consolidates the older scattered Remote Config `ai_proxy_url` / `ai_model` values. The client
  still reads Remote Config `ai_proxy_url` for back-compat; `app_config.endpoints.ai_proxy_url` is
  also honored.

## 6. Platform Pre-Flight (per UI/feature)
- [ ] Safe areas correct on notch + gesture-nav devices (both).
- [ ] Keyboard inset handled (sheets, inputs) on both.
- [ ] Permissions primed (`PermissionPrimer`) before OS dialog; usage strings present in Info.plist /
      AndroidManifest.
- [ ] Apple Sign-In present if Google Sign-In is offered (App Store requirement).
- [ ] Haptics on meaningful actions.
- [ ] Tested in both light + dark, EN + TR, on both platforms.
- [ ] No iOS underscore in bundle ID; identifiers matched across code/config/console.

See also `docs/firebase-console-setup.md` and `docs/roadmap/GO_LIVE.md` for store submission steps.

## 7. Security Hardening (2026-06-30)
**Done:**
- **App Check — real providers in release.** Android uses **Play Integrity**, iOS uses **App Attest**.
  The debug provider is wired **only in debug builds** (no longer forced everywhere).
- **Cloud Functions backend deployed** (10 of 12 functions) to project `cookrange-app`. Config lives in
  `firebase.json` + `.firebaserc`. Function environment via `functions/.env` with an **`APP_ENV`** switch:
  `development` relaxes App Check enforcement and store-credential requirements so functions deploy without
  them; `production` enforces both.
- **Local data-at-rest encryption** — Hive boxes encrypted with **AES-256**; the key is stored in
  `flutter_secure_storage` (Keychain / Keystore).

**Still pending (platform hardening — NOT yet done):**
- `android:usesCleartextTraffic` is **still `true`** in the production manifest (only Hive encryption
  shipped — cleartext disable + `network_security_config` are not done).
- No root / jailbreak / emulator / Frida detection.
- No `FLAG_SECURE` (Android) / iOS screenshot/screen-recording protection.
- No certificate pinning.
- Release build is **not yet `--obfuscate`d**.
