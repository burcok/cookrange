# GO_LIVE.md — Launch Roadmap (App Store + Play Store)

> The complete, ordered path from "code is ready" to "live in both stores". Written for the case
> where you do **not yet have** an Apple Developer or Google Play Developer account. Each step says
> **what to do**, **why it matters**, and **what it unblocks**. Console/portal steps can't be done
> by the AI — they're yours; the AI keeps the code/config side correct.
>
> Legend: 👤 = you (account/console) · 🤖 = AI/code · ⏳ = has a waiting period · 💳 = costs money.

---

## Phase 0 — Accounts & Money (do first; everything depends on these)

### 0.1 👤💳⏳ Apple Developer Program — **$99/year**
- **What:** Enroll at [developer.apple.com/programs](https://developer.apple.com/programs/). Individual
  or Organization (Organization needs a D-U-N-S number, adds days).
- **Why:** Without it you cannot create App IDs, signing certificates, provisioning profiles, or
  submit to TestFlight/App Store. **This is the hard blocker for iOS.**
- **Unblocks:** §1 (iOS signing), §3 (App Store Connect), CI iOS deploy.
- **Waiting:** Individual approval is hours–2 days; Organization (D-U-N-S verify) can be 1–2 weeks.

### 0.2 👤💳 Google Play Developer — **$25 one-time**
- **What:** Register at [play.google.com/console](https://play.google.com/console/signup). Identity
  verification required.
- **Why:** Needed to create the app listing, upload the `.aab`, and publish.
- **Unblocks:** §2 (Android signing/listing), CI Android deploy.
- **Waiting:** Identity verification can take up to 48h (sometimes days for new accounts).

### 0.3 👤 Confirm Firebase project ownership
- **What:** Ensure you own the Firebase project `624768719440` (Cookrange) with Owner role.
- **Why:** You'll add APNs keys, App Check, backups, and API-key restrictions.

---

## Phase 1 — iOS Signing & Identity (after 0.1)

### 1.1 👤 Register the App ID
- **What:** Apple Developer → Identifiers → new App ID = **`com.cookrange-ios.app`** (the hyphen
  form — matches Xcode + Firebase). Enable capabilities: Sign in with Apple, Push Notifications,
  Associated Domains (for deep links).
- **Why:** The bundle ID must exist in your account before any cert/profile/upload.
- 🤖 Already correct in code: `ios/Runner.xcodeproj`, `GoogleService-Info.plist`, `ExportOptions.plist`.

### 1.2 👤 APNs Auth Key → Firebase
- **What:** Apple Developer → Keys → create an **APNs key** (.p8). In Firebase Console → Project
  Settings → Cloud Messaging → iOS, upload the .p8 + Key ID + Team ID.
- **Why:** iOS push notifications (chat, social, broadcasts) won't deliver without this.
- **Unblocks:** push on iOS.

### 1.3 👤 Distribution certificate + provisioning profile
- **What:** Create an iOS **Distribution certificate** (.p12) and an **App Store provisioning
  profile** for `com.cookrange-ios.app`.
- **Why:** Required to sign release builds and upload to TestFlight/App Store.
- 🤖 `ios/ExportOptions.plist` already references `"Cookrange App Store"` profile + manual signing.
- **Unblocks:** §5 CI iOS deploy (the secrets are base64 of these).

### 1.4 👤 App Check — DeviceCheck
- **What:** Firebase Console → App Check → register iOS app with **DeviceCheck**.
- **Why:** The `aiProxy` validates App Check tokens; protects your OpenRouter key/quota from abuse.

---

## Phase 2 — Android Signing & Identity (after 0.2)

### 2.1 👤🤖 Create the upload keystore
- **What:** Generate a release keystore:
  `keytool -genkey -v -keystore cookrange-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias cookrange`
  Store it safely (NOT in git). 🤖 wire `android/key.properties` (alias + passwords) and ensure
  `build.gradle` release signing reads it.
- **Why:** Play requires a signed `.aab`. **Losing this keystore = you can never update the app**
  (unless enrolled in Play App Signing — recommended, see 2.2).
- **Unblocks:** release `.aab`, CI Android deploy.

### 2.2 👤 Enroll in Play App Signing
- **What:** When creating the app in Play Console, opt into **Play App Signing** (Google holds the
  app signing key; you hold the upload key).
- **Why:** If you lose the upload key, Google can reset it. Safer.

### 2.3 👤 SHA-1/SHA-256 → Firebase
- **What:** Add the upload key's SHA-1 **and** SHA-256 to Firebase Console → Android app. (Two SHA-1s
  are already there for debug.) Re-download `google-services.json` if it changes.
- **Why:** Google Sign-In + App Check + Dynamic/Deep links need the fingerprints registered.

### 2.4 👤 App Check — Play Integrity
- **What:** Firebase Console → App Check → register Android app with **Play Integrity**.
- **Why:** Same as 1.4 — protects the AI proxy.

---

## Phase 3 — Store Listings & Metadata (parallel with 1–2)

### 3.1 👤 App Store Connect record
- **What:** Create the app in [App Store Connect](https://appstoreconnect.apple.com) using
  `com.cookrange-ios.app`. Fill: name, subtitle, category (Health & Fitness), age rating,
  EN + TR localized descriptions, keywords, support/marketing URLs.
- **Why:** Can't submit a build without the listing.

### 3.2 👤 Play Console listing
- **What:** Create the app, fill store listing (EN + TR), category, content rating questionnaire,
  target audience, data safety form.
- **Why:** Required before production rollout.

### 3.3 👤🤖 Privacy & legal
- **What:** Publish a public **Privacy Policy** + **Terms** URL (you have in-app legal screens; also
  host them at a public URL — e.g. `cookrangeapp.com/privacy`). Fill Apple **Privacy Nutrition
  Labels** + Google **Data Safety** (declare: account, health/fitness, usage, identifiers; AI uses
  text you send). Provide `NSUserTrackingUsageDescription` screenshot for ATT review.
- **Why:** Both stores reject apps without accurate privacy disclosures. Health apps get extra scrutiny.

### 3.4 👤 Assets
- **What:** App icon (1024², already have `cookrange-icon.png`), screenshots for required device
  sizes (6.7"/6.5" iPhone, 12.9" iPad if supported; Android phone/tablet), feature graphic (Play),
  optional preview video.
- **Why:** Listings can't be submitted without the required screenshot sets.

---

## Phase 4 — In-App Purchases (before testing monetization)

### 4.1 👤 App Store Connect — products
- **What:** Create subscriptions `com.cookrange.premium.monthly`, `com.cookrange.premium.yearly`
  (Auto-Renewable, in a Subscription Group) + consumable `cookrange_ai_credits_10`. Add localized
  names/prices. Fill the **Paid Apps agreement** + banking/tax (App Store won't show products until
  this is signed).
- **Why:** `BillingService` references these exact IDs; purchases fail until registered + agreement signed.

### 4.2 👤 Play Console — products
- **What:** Create the matching subscriptions + the consumable `cookrange_ai_credits_10` as a
  **Consumable** managed product. Set up a merchant/payments profile.
- **Why:** Same — `BillingService` + `AiCreditService.addBonusCredits` depend on them.

### 4.3 👤 Sandbox/license testers
- **What:** Add sandbox testers (Apple) and license testers (Google) to test purchases without charge.
- **Why:** Verify the full purchase → entitlement → credit-grant loop before real users.

---

## Phase 5 — Backend Hardening (do before public traffic)

### 5.1 👤 API key restrictions — **see `docs/firebase-console-setup.md`** ✅ (you did §1)
- Android key → Android-app restriction (package + SHA-1); iOS key → bundle-ID restriction; browser
  key → referrer restriction. **Why:** stops key abuse.

### 5.2 👤 Deploy Cloud Functions + secret
- **What:** `firebase functions:secrets:set OPENROUTER_API_KEY` then `firebase deploy --only functions`.
  Set Remote Config `ai_proxy_url` to the deployed `aiProxy` URL.
- **Why:** This is what hides your AI key and enforces server-side quota. Until deployed, the app
  falls back to the (dev-only) local key.
- 🤖 Code ready (`functions/index.js`, `AIService.setProxyUrl`).

### 5.3 👤 Deploy rules + indexes
- **What:** `firebase deploy --only firestore:rules,firestore:indexes,storage:rules`.
- **Why:** Your security model and query indexes must be live in prod, not just in the repo.

### 5.4 👤 Load test the proxy
- **What:** 🤖 `PROXY_URL=… ID_TOKEN=… node scripts/load_test.js` (tune CONCURRENCY/TOTAL).
- **Why:** Confirm the AI proxy + Firestore quota transaction hold up under concurrency before launch.
- **Pass bar:** error rate < 5%, P95 latency acceptable.

### 5.5 👤 Monitoring + backups
- **What:** Crashlytics velocity alerts; Performance alert on `aiProxy` P95 > 5s; scheduled Firestore
  export to a backup bucket (daily, 30-day retention).
- **Why:** You need to see crashes/regressions and be able to restore data.

### 5.6 👤 Deep-link server files
- **What:** Host `/.well-known/apple-app-site-association` (no extension, JSON, app ID
  `<TeamID>.com.cookrange-ios.app`) and `/.well-known/assetlinks.json` (package
  `com.cookrange_android.app` + SHA-256) on `cookrangeapp.com`.
- **Why:** Universal Links (iOS) / App Links (Android) verification; without these, deep links open a
  browser instead of the app.

---

## Phase 6 — Internal/Beta Testing

### 6.1 👤 CI secrets → GitHub
- **What:** Add all secrets from `docs/PLATFORM.md` §5 to the GitHub repo (Apple cert/profile/team +
  ASC API key; Android keystore/passwords + Play service-account JSON; `OPENROUTER_API_KEY`).
- **Why:** `deploy.yml` automates TestFlight + Play internal uploads once these exist.

### 6.2 👤⏳ TestFlight (iOS)
- **What:** First build upload triggers **Export Compliance** + (for external testers) a **Beta App
  Review**. Add internal testers (instant) then external groups.
- **Why:** Real-device validation; external review is a mini App Review (~1 day).

### 6.3 👤 Play Internal Testing (Android)
- **What:** Upload `.aab` to the Internal track; add testers by email/list.
- **Why:** Fast device coverage; surfaces signing/Integrity issues early.

### 6.4 👤🤖 Beta pass criteria
- Auth (email/Google/Apple), onboarding, meal-plan gen, AI chat (proxy mode), purchases (sandbox),
  push (both platforms), deep links, dark/light, EN/TR — all verified on real iOS + Android devices.
  🤖 fixes anything that fails; re-run `flutter analyze` + tests.

---

## Phase 7 — Submission & Launch

### 7.1 👤⏳ App Store review
- **What:** Submit from App Store Connect. Provide a demo account + notes (mention AI, health data,
  ATT). **Why:** Apple review is ~24–48h; health + AI + IAP draw scrutiny. Expect possible rejections
  — common causes: incomplete privacy labels, missing Apple Sign-In, IAP not restorable, demo account
  not working.
- 🤖 Ensure: Apple Sign-In present (it is), purchases restorable (Restore in `AiCreditsSheet`),
  AI degrades gracefully.

### 7.2 👤⏳ Play production review
- **What:** Promote to Production. New accounts may face extended review (days). Staged rollout
  (10%→50%→100%) recommended.

### 7.3 👤 Launch checklist
- [ ] Functions deployed + `ai_proxy_url` set · [ ] Rules/indexes deployed · [ ] API keys restricted
- [ ] IAP products live + agreements signed · [ ] Privacy labels/data-safety accurate
- [ ] Push works both platforms · [ ] Deep-link files hosted · [ ] Crashlytics/Performance alerts on
- [ ] Backups scheduled · [ ] `min_version` set in Remote Config (force-update lever) · [ ] Monitoring dashboards

---

## Phase 8 — Post-Launch
- Watch Crashlytics velocity + Performance for the first 72h; hotfix via staged rollout.
- Use Remote Config `maintenance_mode` / `min_version` to gate if something breaks.
- Roll out IAP price/locale expansion; begin the deferred **payout provider** integration
  (`docs/roadmap/FUTURE_FEATURES.md`) once commission volume justifies it.

---

## Hard-blocker summary (sequence that gates everything)
1. **Apple Developer ($99) + Google Play ($25)** accounts → 2. iOS App ID + signing & Android keystore
→ 3. APNs + App Check → 4. IAP products + agreements → 5. Deploy Functions/rules + restrict keys →
6. TestFlight + Play internal → 7. Store review → 8. Live.

Until Phase 0 accounts exist, the AI can keep code/config launch-ready (✅ done: bundle IDs matched,
ExportOptions, CI workflows, load-test script, console checklist) but **cannot create accounts,
certificates, listings, or submit** — those are yours.
