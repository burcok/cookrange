# Firebase Console Setup Checklist

One-time manual steps that cannot be automated via code.
Complete these before submitting to the App Store / Play Store.

---

## 1. API Key Restrictions (High Priority — do before public launch)

Firebase projects expose browser/iOS/Android API keys in `google-services.json`
and `GoogleService-Info.plist`. Without restrictions these keys can be misused.

### Android key
1. Open [Firebase Console](https://console.firebase.google.com) → Project Settings → General
2. Under **Your apps** → Android app → click the key icon next to the API key
   (or go to [GCP Console](https://console.cloud.google.com) → APIs & Services → Credentials)
3. Select the **Android** key → **Edit**
4. Under **Application restrictions** select **Android apps**
5. Click **Add an item** and enter:
   - Package name: `com.cookrange_android.app` (matches `android/app/build.gradle` + Firebase Console)
   - SHA-1 fingerprint: run `keytool -keystore <your-keystore> -list -v` and paste the SHA-1.
     The Firebase Console already lists two SHA-1 fingerprints for this app
     (`21:e0:b5:…:b1:c7` and `4c:89:a8:…:98:1b`) — add the same ones to the key restriction.
6. Save

### iOS key
1. Same path → iOS key → **Edit**
2. Under **Application restrictions** select **iOS apps**
3. Enter your Bundle ID: `com.cookrange-ios.app` (matches `ios/Runner.xcodeproj` + Firebase Console)
4. Save

### Browser key (used by Firebase Auth redirect)
1. Browser key → **Edit**
2. Under **Website restrictions** → **Add an item**
3. Add your production domain (e.g., `https://cookrangeapp.com/*`)
4. Also add your Firebase Hosting URL: `https://<project-id>.web.app/*`
5. Save

> **Note:** It can take up to 5 minutes for restrictions to propagate.
> Test on a real device after applying to confirm Auth still works.

---

## 2. Firebase App Check (already in code — enable in console)

1. Firebase Console → App Check
2. Enable **Play Integrity** for Android (requires Play Console app registration)
3. Enable **Device Check** for iOS (requires an Apple Developer account key)
4. After enabling, set enforcement mode to **Monitor** first, then **Enforce**
   once you verify no legitimate traffic is being blocked

---

## 3. Cloud Monitoring Alerts

1. Firebase Console → Performance Monitoring → Alerts
2. Create alert: **Network requests P95 latency > 5s** for `aiProxy`
3. Create alert: **Crash rate > 1%** (Crashlytics → Alerts)
4. Set notification email or PagerDuty webhook

---

## 4. Firestore Backups

1. Firebase Console → Firestore → Import/Export
2. Set up a scheduled export to Cloud Storage (daily, 30-day retention)
3. Bucket name: `gs://<project-id>-backups/firestore`

---

## 5. App Store / Play Console

- Register consumable product `cookrange_ai_credits_10` (IAP top-up)
- Register subscription `com.cookrange.premium.monthly` and `com.cookrange.premium.yearly`
- Submit `NSUserTrackingUsageDescription` screenshot for ATT review
- Add Privacy Nutrition Labels in App Store Connect

---

*Last updated: 2026-06-29*
