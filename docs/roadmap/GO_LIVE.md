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
  Set Remote Config `ai_proxy_url` (and/or `app_config.endpoints.ai_proxy_url`) to the deployed
  `aiProxy` URL.
- **Why:** This is what hides your AI key and enforces server-side quota. Until deployed, the app
  falls back to the local key.
- 🤖 Code ready and **hardened** (`functions/index.js`): model allowlist, `max_tokens`/payload caps,
  **fail-closed** quota, **mandatory App Check** (`APP_CHECK_ENFORCE`), per-uid rate limit,
  `maxInstances`, no wildcard CORS. Credits/premium read from server-only `ai_credits/{uid}` +
  `entitlements/{uid}`, never the user doc. **See Phase 5S for the full security gate.**
- ⚠️ **Grant the `aiProxy` public-invoker role (required or it 401s).** `aiProxy` is an
  `https.onRequest` function; the platform deploys it **private** and returns a 401 HTML page before
  the code runs unless `allUsers` has the Cloud Functions Invoker role. Auth is enforced **in-code**
  (Firebase ID token + App Check + quota + rate-limit + model allowlist) — this is the standard
  Firebase-Callable pattern. Run after deploy:
  ```bash
  gcloud functions add-iam-policy-binding aiProxy \
    --region=us-central1 --member=allUsers --role=roles/cloudfunctions.invoker
  ```
- ⚠️ **AI model = `openai/gpt-4o-mini` (paid).** The old `deepseek/…:free` model was removed from
  OpenRouter (404), so the default is now `gpt-4o-mini` — a **paid** model. The OpenRouter account
  **must carry credit** or every AI call fails. Set the model/quota in `functions/.env`
  (`OPENROUTER_MODEL`, `OPENROUTER_TIMEOUT_S`) and/or `app_config/global` — see next bullet.
- ✅ **Model / tokens / quota are managed remotely (no redeploy).** `aiProxy` reads `app_config/global`
  (Admin SDK, 5-min cache) for model / `max_tokens` / `temperature` / quota and **ignores the
  client-sent model** (cost safety); `AdminAppConfigScreen` edits it live. `MAX_OUTPUT_TOKENS` is
  8192 (large meal-plan JSON). Real OpenRouter token usage is logged to `ai_usage_logs` /
  `ai_usage_stats`.

### 5.3 👤 Deploy rules + indexes
- **What:** `firebase deploy --only firestore:rules,firestore:indexes,storage:rules`.
- **Why:** Your security model and query indexes must be live in prod, not just in the repo.
- ⚠️ Deploy the **field-locked** `users/{uid}` rule and the server-only collection rules (Phase 5S
  §S1/§S5) **only after** the server-side write paths (purchase validation, economy, credit ledger)
  are deployed — otherwise legitimate client writes break. Order matters; see Phase 5S.

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

## Phase 5S — Security Remediation (audit-driven; **release blockers**)

> From the full security audit (Flutter + Firebase, 13 domains). The app is currently **not
> production-ready** for payments/economy/health-data until the **P0** items below are done; **P1**
> are pre-public-traffic blockers; **P2** is hardening. Status legend adds: ✅ code done · 🔲 code
> pending · 👤 your console/account action. **Root cause to keep in mind:** the app must stop
> trusting the client for entitlements, economy, identity, and moderation — every fix below moves a
> trust decision server-side.
>
> **Ordering rule (critical):** deploy the *server-side write paths first* (S2 ledger, S3 purchase
> validation, S4 economy), **then** lock the rules (S1, S5). Locking rules before the server can
> write the now-forbidden fields will break live flows.
>
> **🔧 Implementation progress (code committed, NOT yet deployed):**
> - ✅ **Code-complete in repo:** S2 (server credit/entitlement ledger + owner-read/deny-write rules),
>   S3 (`validatePurchase` + App Store/Play verification + dedupe + refund/expiry notification handlers),
>   S4 (`applyReferral` + server commission ledger), S6 (hardened proxy + App Check release providers +
>   **client direct-key fallback removed** in release), S1 (field-locked `users/{uid}` + server-only
>   `commissions`/`referrals`-update rules), plus Hive **at-rest encryption** (S14, key in secure
>   storage) and a **safe URL launcher** for applicant-document links (injection/H17).
> - ✅ **Injection / secure-coding hardening (code-complete):** null-safe parsing of attacker-controlled
>   docs (chat/signal/chat-meta — stored-DoS, H28); a **deterministic allergen safety filter** that
>   strips unsafe dishes from the meal-plan candidate pool before the AI sees it, refusing to generate
>   if none remain (life-safety); a **prompt-injection guard** (user free-text fenced + treated as data)
>   across ingredient/recipe/meal-plan/food-analysis prompts; and **content-length caps** in rules
>   (posts/comments/chat/signals), with AI payload caps already enforced in the proxy (H27).
> - ✅ **Compliance / privacy (code-complete):** S7 **server-side account erasure** (`deleteUserAccount`
>   Cloud Function recursively deletes the whole user subtree + server docs + authored content + all
>   Storage prefixes + the Auth user; client reauths → calls it → signs out); S11 **complete GDPR export**
>   (now includes private nutrition PII + every owner subcollection + authored comments + a Storage
>   manifest); **analytics/Crashlytics gated on consent** (privacy-by-default OFF until the analytics
>   consent is applied; S17); **email removed from Analytics events**; **`failed_login_attempts`
>   locked** to server-only (was unauthenticated-writable).
> - ✅ **Dev/prod env gating:** `functions/config.js` + `functions/.env` `APP_ENV` — in `development`
>   App Check is NOT enforced and purchase validation is inert, so functions **deploy & run with no
>   Apple/Google/App Check setup**. Flip to `production` (+ fill the store/AI creds in `functions/.env`)
>   at go-live. Client mirrors `APP_ENV` in root `.env` (informational; client security gates use the
>   compiled `kReleaseMode`).
> - 🔲 **Still required to ACTIVATE (go-live):** rotate the SA key (S0), provision store credentials +
>   sandbox-test S3, deploy Functions/rules, register Play Integrity/App Attest + enable App Check
>   enforcement, set the OpenRouter spend cap. Run the rules-emulator tests before deploying S1.
> - ✅ **Storage hardening (S9, code-complete + deployed):** chat images scoped to participants
>   (1:1 pair path enforced in storage.rules; group fallback) with unguessable random filenames;
>   client-side EXIF/GPS stripping on every image upload (chat/post/profile/gym); server `scanImage`
>   Cloud Function runs Cloud Vision SafeSearch and deletes unsafe uploads (best-effort until the
>   Vision API is enabled — enable it in production).
> - 🔲 **Deferred (need broader refactor; tracked):** S5 full server-authored notifications/friends;
>   S8 point-of-use consent enforcement for AI/photo processing (the analytics half is done); S10
>   minimize the world-readable user doc (move email/IP/fcm_token off it); and moving
>   `streak`/`reputation` server-side. NSFW enforcement requires enabling the **Cloud Vision API**.
> - ✅ **Text moderation now live for all users** *(audit M7)*: the blocked-keyword list is mirrored
>   to the **public-read** `settings/content_filter` doc (admins write it via `admin_config/global`);
>   `CommunityService._checkContent` reads it there, so the filter no longer fails open for non-admins.
> - 🔲 **Deferred (anti-fraud follow-up; tracked):** a per-uid **UGC rate limiter** (posts/comments/
>   friend-requests/signals). Interim barriers are in place — App Check (blocks scripted/bot clients
>   once enforced) + content-length caps + the reports pipeline. A true sliding-window limiter needs
>   the UGC creates to route through a callable (or a rules-based cooldown counter); scope it before
>   the community economy GA.

### P0 — Critical (do not deploy to production without these)

#### S0 👤 Rotate the leaked Firebase Admin service-account key — **DO THIS FIRST** *(audit C6)*
- **What:** A live Admin SDK private key was found at `secret/…adminsdk….json`. In Firebase Console →
  IAM & Admin → Service Accounts → Keys: **delete the old key, create a new one.** Then delete the
  `secret/` directory from every machine. Cloud Functions use Application Default Credentials —
  `admin.initializeApp()` needs no key file.
- **Why:** This key bypasses all rules + Auth. Anyone who copied it has full backend control until
  rotated. Deleting the file alone is *not* enough — it must be rotated.
- 🔲 Add a **gitleaks/trufflehog** pre-commit + CI gate that fails on any `service_account` JSON / PEM.

#### S1 🤖+👤 Lock the `users/{uid}` rule (field whitelist) *(audit C1, C2)*
- **What:** `users/{uid}` update must allow only safe profile fields; **forbid** `subscription_tier`,
  `user_roles`, `ai_credits_*`, `is_banned`, `streak`, `reputation` from any client write.
- **Why:** Today any user can self-grant premium/admin/credits and self-unban. This is the single
  biggest hole. Deploy **after** S2/S3/S4. ⚠️ Move ban state to `admin/status/{uid}` + a custom claim
  + `revokeRefreshTokens` (server-side), not the user doc.

#### S2 ✅ Server-authoritative AI credit + entitlement ledger *(audit C1-prereq, C3)*
- ✅ Done in `functions/index.js`: credits live in server-only `ai_credits/{uid}`; premium read from
  server-only `entitlements/{uid}`. 🔲 Add rules: both `allow read: if isOwner(uid); allow write: if
  false;` (owner-read for the badge, server-write only).

#### S3 🤖+👤 Server-side purchase validation (native store APIs) *(audit C7, H30, H31)*
- **What:** A Cloud Function validates every purchase against the **App Store Server API** (JWS) and
  **Google Play Developer API**, dedupes the purchase token, then writes `entitlements/{uid}`
  tier+expiry and `ai_credits` bonus via Admin SDK. RTDN / App Store Server Notifications → revoke on
  refund/chargeback/expiry. **Never grant premium/credits client-side.**
- 👤 Needs: Apple `.p8` key + Key ID/Issuer ID/Bundle ID; Google Play service-account JSON
  (`androidpublisher` scope); registered product IDs (Phase 4). Store as Function secrets.
- ✅ Read enforcement is already server-side (S2). 🔲 The validation Functions + client rewire pending.
- **Gate:** must pass a **sandbox purchase → entitlement → credit** test before S1 rules lock.

#### S4 🤖 Server-authoritative economy (commissions / payouts / referrals) *(audit C8)*
- **What:** `applyReferral` callable (no self-referral, one-per-account, `max_uses`, append-only
  `used_by_uids`); commissions/payouts written **only** by Functions after validation. Lock those
  collections to read-own / deny client write.
- **Why:** Today commissions are forgeable at any amount and payouts pay a self-computed balance —
  direct fraud once payouts launch.

#### S5 🤖+👤 Close the open Firestore create rules *(audit C9)*
- **What:** `notifications/{uid}/items`, `users/{uid}/friends`, `friend_requests`,
  `failed_login_attempts` → **server-authored only** (`create: if false` + Cloud Function that derives
  the actor from `request.auth` and verifies the underlying edge). Re-fetch `actorName` server-side.
- **Why:** Any user can currently push-spam/impersonate any other user and write into anyone's
  friend/notification subcollections.

#### S6 ✅+👤 Hardened AI proxy + App Check enforcement *(audit C3, C4, C5)*
- ✅ Done: model allowlist, payload/token caps, fail-closed quota, per-uid rate limit, mandatory
  App Check (`APP_CHECK_ENFORCE`), `maxInstances`, no wildcard CORS (`functions/index.js`).
- ✅ Done client-side: real App Check providers in release — Play Integrity / App Attest
  (`app_initialization_service.dart`). 🔲 Remove the client **direct-key fallback** in `ai_service.dart`
  so a missing `ai_proxy_url` returns the not-configured path instead of calling OpenRouter with the
  bundled key (do this once the proxy is deployed).
- 👤 Register **Play Integrity** + **App Attest** (Phase 1.4 / 2.4) and **enable App Check enforcement**
  for Functions/Firestore/Storage in the console. 👤 Set a **hard spend cap** on the OpenRouter account
  — and **top up OpenRouter credit**, since the default model is now the **paid** `openai/gpt-4o-mini`
  (the old free DeepSeek model was 404'd). 👤 Grant `aiProxy` the **public-invoker** role (Phase 5.2)
  or the platform returns 401 before the in-code auth runs.
- 👤 Stop writing the real `OPENROUTER_API_KEY` into the bundled `.env` for distributed builds — only
  the proxy URL needs to reach the client.

#### S7 🤖+👤 Server-side account deletion + Storage cleanup (right to erasure) *(audit C10)*
- **What:** A Cloud Function recursively deletes **all** subcollections (food_analyses, achievements,
  consents, ai_*, exercise_logs, recipe_notes, favorites, lists, recent_foods, commissions,
  payout_requests, following/followers, program_enrollments) + Storage prefixes (`profile_photos/`,
  `post_images/`, `chat_images/`, `*_applications/`) and anonymizes authored posts/comments/chats.
  Current `firestore_service.deleteUserData` deletes only 6 subcollections and no Storage.
- **Why:** GDPR Art.17 / KVKK Art.7 — leaving health PII + ID documents behind is a reportable breach.

#### S8 🤖+👤 Enforce consent at runtime + disclose cross-border AI transfer *(audit C11)*
- **What:** Gate AI calls, photo analysis, and Analytics/Crashlytics on a checked, versioned consent
  record. Add point-of-use disclosure before health data/meal photos leave the device. Document
  **OpenRouter as a sub-processor** with a DPA/SCC (cross-border transfer). Add an **age gate** before
  collecting DOB + body metrics.
- **Why:** GDPR Art.9/44 + KVKK Art.6/9 explicit-consent + cross-border rules; the project's own
  "legal-first / KVKK is a release blocker" mandate.

### P1 — High (before public traffic / scale)

- **S9 🤖+👤 Storage access control** *(H1, H2, H3)* — scope `chat_images`/`post_images` to chat/owner
  membership with unguessable filenames; stop minting public download tokens for ID/business docs
  (serve admins a short-lived signed URL via an `isAdmin` callable); add an `onObjectFinalized`
  scanner (Cloud Vision SafeSearch + CSAM/NCMEC) + **EXIF/GPS stripping**.
- **S10 🤖 Minimize the readable user doc** *(H24)* — move email, last-login **IP**, device history,
  `fcm_token` off the world-readable doc into an owner-only/server-only doc; expose only public
  profile fields to other users.
- **S11 🤖 Complete the GDPR data export** *(H21)* — include `private/nutrition` PII + all
  subcollections + a Storage manifest (currently omits the most sensitive data).
- **S12 🤖+👤 Auth abuse controls** *(H8, M1, H9)* — login throttle/lockout + reCAPTCHA/App Check on
  auth; generic enumeration-safe error messages; enforce email-verification server-side in rules.
- **S13 🤖 Economy/social integrity** *(H4–H7, H25, H26)* — counters via validated increments;
  reviews require a real client relationship; check-ins need membership+geofence+rate-limit;
  marketplace `coach_uid=='demo'` restricted to a server seeder; **server-side block enforcement**;
  per-uid rate limits on all UGC; length caps on posts/chat/AI input.
- **S14 👤🤖 Transport + at-rest hardening** *(H14, H15)* — `usesCleartextTraffic="false"` +
  `network_security_config.xml`; encrypt Hive boxes (`HiveAesCipher` + key in `flutter_secure_storage`).
- **S15 👤 Release build hygiene** *(H16)* — ship `flutter build appbundle --release --obfuscate
  --split-debug-info=…`; **never** distribute the debug APK; remove the AI key from the bundled `.env`.
- **S16 👤 Environment isolation + reproducible builds** *(H12, H13)* — separate `dev`/`staging`/`prod`
  Firebase projects (`.firebaserc` aliases); **commit `pubspec.lock` + `functions/package-lock.json`**;
  add Dependabot.
- **S17 🤖+👤 Analytics privacy** *(H22, H23)* — gate Analytics/Crashlytics on consent; **remove email
  from Analytics events** (`auth_service` password-reset/verify events); wire ATT after disclosure.

### P2 — Hardening (defense-in-depth; post-launch acceptable)

- **S18** FLAG_SECURE / iOS screenshot protection on sensitive screens (health PII, QR check-in, password).
- **S19** Root/jailbreak/emulator/Frida detection; refuse payments on compromised devices.
- **S20** PII-redacting logger; strip `debugPrint` PII in release.
- **S21** Certificate/public-key pinning for Firebase + the AI proxy (once endpoints are stable).
- **S22** Backups/PITR + budget alerts + monitoring + incident-response runbook (also Phase 5.5).
- **S23** Tighten remaining rules (member_count/achievement/squad/challenge/referral counters), bound
  unbounded listeners/queries (`.limit()` + aggregation), migrate Functions to gen2 + native fetch.

### 5S.✓ Security go-live gate (all P0 + P1 must be ✅ before production)
- [ ] S0 SA key rotated + secret-scan CI · [ ] S1 user-doc rule locked (after S2–S4) · [ ] S2 ledger rules deployed
- [ ] S3 purchase validation sandbox-passed · [ ] S4 economy server-authored · [ ] S5 open creates closed
- [ ] S6 proxy deployed + App Check enforced + key fallback removed + OpenRouter spend cap
- [ ] S7 server-side erasure + Storage cleanup · [ ] S8 consent enforced + cross-border DPA + age gate
- [ ] S9 storage scoped + scanned · [ ] S10 user doc minimized · [ ] S11 export complete · [ ] S12 auth abuse controls
- [ ] S13 economy/social integrity · [ ] S14 cleartext off + Hive encrypted · [ ] S15 obfuscated release, no debug APK
- [ ] S16 env isolation + lockfiles committed · [ ] S17 analytics consent-gated, no PII

---

> ⚠️ **Deploy flakiness on this project (known behavior).** Functions run **cross-region**
> (`us-central1` functions / `europe-west10` DB), so the CLI often prints `failed to update` even
> though the deploy actually lands **asynchronously** — verify in the console rather than trusting the
> CLI exit. Back-to-back deploys return `operation already in progress` (code 9) — **wait between
> deploys**. The Node 20 deprecation + gen1 `firebase-functions` warnings are still deferred (Phase 5T).

## Phase 5T — Cloud Functions modernization (scheduled migration)

> ✅ Done: `functions/package.json` `engines.node` bumped to **22** (Node 20 decommissions
> 2026-10-30). 🔲 Scheduled (do as ONE tested migration, ideally after Phase 5S §S16 staging exists):
> - **gen1 → gen2** (`firebase-functions` v6: `onRequest`/`onCall`/`onDocumentCreated`/`onObjectFinalized`/
>   `onSchedule`). Removes the deprecation warning; better cold-start/concurrency.
> - **Region collocation**: move the Firestore-trigger functions (`onInAppNotificationCreated`,
>   `onChatMessageCreated`, `onBroadcastCreated`) to **`europe-west10`** (the DB region) to cut latency.
>   ⚠️ Must delete the old `us-central1` versions in the SAME deploy or you get **duplicate triggers
>   (double push)**. This is why it needs a tested, atomic migration — do NOT do it piecemeal on the
>   flaky-deploy project. Verify in staging first.

## Phase 5U — Reliability & Environments (infra runbook)

> Mostly console/account actions (your side). `.firebaserc` currently has `default = cookrange-app`.

**Environment separation (prod / staging / dev):**
1. 👤 Create `cookrange-staging` (and optionally `cookrange-dev`) Firebase projects.
2. 👤🤖 Add Flutter **flavors** (dev/staging/prod) with per-flavor application IDs + their own
   `google-services.json` / `GoogleService-Info.plist` + generated `firebase_options`. Wire
   `flutter run --flavor staging` etc.
3. 👤 `firebase use --add` → map aliases `staging`/`prod`; deploy with `firebase deploy -P staging`.
4. CI: deploy rules/functions to **staging on `develop`**, prod only on tagged release.

**Backups & recovery:**
- 👤 Firestore → **enable Point-in-time recovery (PITR)** (7-day window) — one click; covers most data-loss.
- 👤 Firestore → **Backup schedule** → daily, 7–30 day retention (or scheduled GCS export).
- 👤 Set **TTL policies** on ephemeral collections to cap storage cost: `signals.expiresAt`,
  old `logs`, `processed_purchases` (dedupe rows can expire after the refund window).

**Monitoring & alerting:**
- 👤 Crashlytics → velocity alerts on; Performance → custom alert on **`aiProxy` P95 > 5s**.
- 👤 **Cloud Billing → Budgets → budget + email/Pub/Sub alert** (critical for cost — pairs with the
  in-app cost dashboard). Add a separate **OpenRouter hard spend cap**.
- 👤 Cloud Monitoring uptime check on the `aiProxy` URL.

**Incident response (levers already in code):** Remote Config `maintenance_mode` + `min_version`
(force-update) — document the runbook for flipping them.

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
- [ ] **Phase 5S security gate fully green (all P0 + P1)** — see the 5S.✓ checklist; this is a hard blocker
- [ ] Functions deployed + `ai_proxy_url` set · [ ] `aiProxy` **public-invoker role granted** (else 401) · [ ] Rules/indexes deployed (field-locked) · [ ] API keys restricted
- [ ] App Check **enforcement on** (Functions/Firestore/Storage) · [ ] SA key rotated · [ ] OpenRouter spend cap set + **credit topped up** (paid `gpt-4o-mini`)
- [ ] IAP products live + agreements signed · [ ] **Server-side receipt validation passing** · [ ] Privacy labels/data-safety accurate
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
→ 3. APNs + App Check → 4. IAP products + agreements → **4.5. Phase 5S security remediation (rotate SA
key, server-side entitlements/economy/erasure/consent, then lock rules) — release blocker** →
5. Deploy Functions/rules + restrict keys → 6. TestFlight + Play internal → 7. Store review → 8. Live.

> ⚠️ The single most important gate is **Phase 5S**: until the client-trust holes (premium/role/credit
> self-grant, forgeable economy, open creates, incomplete erasure, unenforced consent) are closed,
> the app must not process payments or go to public production. Code progress so far: aiProxy hardened,
> server-side credit/entitlement ledger, real App Check providers (✅); purchase validation, economy
> Functions, rules lock, erasure/consent (🔲 pending).

Until Phase 0 accounts exist, the AI can keep code/config launch-ready (✅ done: bundle IDs matched,
ExportOptions, CI workflows, load-test script, console checklist) but **cannot create accounts,
certificates, listings, or submit** — those are yours.
