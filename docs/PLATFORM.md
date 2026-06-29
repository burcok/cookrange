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
| App Check | DeviceCheck (release) / debug | Play Integrity (release) / debug |
| Push | APNs via FCM (needs APNs key in Firebase) | FCM direct |
| Permissions | `Info.plist` usage strings (camera, mic, photos, location, tracking) | `AndroidManifest.xml` `<uses-permission>` + runtime requests |
| Permission UX | Always precede the OS dialog with `PermissionPrimer.show()` | same |
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
