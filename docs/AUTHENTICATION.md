# AUTHENTICATION.md — Identity, Session & Account Lifecycle

> Every path a user takes into, through, and out of an account. Security posture and known gaps live
> in [`SECURITY.md`](SECURITY.md) §3; user-doc shape lives in [`DATABASE.md`](DATABASE.md).
>
> **Owns:** `auth_service.dart`, `lib/screens/auth/`, `route_guard.dart`, `user_provider.dart`.

---

## 1. Components

| Piece | File | Responsibility |
|---|---|---|
| `AuthService` | `core/services/auth_service.dart` | Firebase Auth wrapper: sign-in/up, verification, reset, session tracking. Holds the app `navigatorKey`. In-memory user cache |
| `UserProvider` | `core/providers/user_provider.dart` | Holds `UserModel`; **live Firestore listener** on `users/{uid}`; merges public doc + private nutrition |
| `RouteGuard` | `core/utils/route_guard.dart` | Wraps every route except `intro`; decides where an account may go |
| `FirestoreService` | `core/services/firestore_service.dart` | User doc CRUD, `verifyAndRepairUserData`, device-context sync |
| `AdminStatusService` | `core/services/admin_status_service.dart` | Real-time ban/admin status stream feeding the guard |

---

## 2. Supported methods

| Method | Platforms | Notes |
|---|---|---|
| Email + password | both | Requires email verification before app access |
| Google Sign-In | both | Pre-verified — skips the email gate |
| Apple Sign-In | iOS | **Mandatory**: Apple requires it wherever Google is offered |

---

## 3. Registration

Onboarding runs **before** registration (ADR-013), so by the time this screen appears the user has
already completed 14 personalization pages held in memory.

```
Intro carousel → Onboarding (14 pages, in memory, no uid)
   → Register screen
       ├─ email + password + confirm
       └─ consent capture (two tiers)
            ├─ REQUIRED: Terms, Privacy, essential data (health / AI / cross-border transfer)
            └─ OPTIONAL: analytics, marketing
   → createUserWithEmailAndPassword
   → ConsentService.recordInitialConsents(...)
   → OnboardingCompletion.finalizeAndRoute(...)
       ├─ persistV2Profile → public onboarding_data + private nutrition + displayName
       ├─ schedule water reminder
       ├─ repopulate UserProvider via copyWith  ← see the trap below
       └─ route: email auth → /verify_email · social auth → /meal_plan_generation
```

> ⚠️ **The `copyWith` trap.** `persistV2Profile` writes through `FirestoreService` and does **not**
> invalidate the `AuthService` cache, so re-fetching the user here can return a stale doc and revert
> the flags just written. `OnboardingCompletion` therefore builds the new `UserProvider` state with
> `copyWith` rather than re-reading. This has caused a meal-plan generation loop before — don't
> "simplify" it into a refetch.

Every write in the completion tail is **best-effort**: a hiccup must never strand a created account
with no profile.

## 4. Login

```
Login screen → email+password | Google
   → AuthService.signIn*
   → session record + device context written
   → UserProvider.loadUser()  (public doc + private nutrition, starts live listener)
   → RouteGuard resolves the destination
```

Live password validation on input. Concurrent-login detection runs on the session record.

> ⚠️ No throttling or lockout (`AUTH-04`), and error messages distinguish "no such user" from "wrong
> password" — an enumeration leak. Both are open (`SECURITY.md` §3).

---

## 5. RouteGuard — the gate order

Wraps every route except `intro` and `onboardingV2` (both pre-auth). It reads cached `UserProvider`
state, so it costs no Firestore read per navigation.

| # | Check | Fail → |
|---|---|---|
| 0 | Maintenance mode / force update (`AppConfigService`) | `MaintenanceScreen` / `ForceUpdateScreen` |
| A | **Ban** — real-time `AdminStatusService` | `AccountSuspendedScreen` |
| B | Auth initialized? | wait |
| C | Logged out on a protected route | `login` |
| D | Logged in on an auth route | `main` |
| E | **Email verified** — hard gate | `verifyEmail` (only `/verify_email` and `/meal_plan_generation` allowed through) |
| F | `onboarding_completed == false` | `OnboardingFlowScreen(loggedInCompletion: true)` |
| — | otherwise | requested route |

Gate 0 renders before everything else. Social auth arrives pre-verified and skips E.

---

## 6. Email verification

Hard gate — an unverified email-auth account can reach nothing but the verification screen.

- 5-second poll for verification status; 180-second resend cooldown
- On success: `onboarding_completed == true` → `/meal_plan_generation`; otherwise back into
  `OnboardingFlowScreen(loggedInCompletion: true)`
- Verification is **not** enforced in Firestore rules — UI-gated only. Open (`S12`).

## 7. Password reset

Standard Firebase reset email from `forgot_password_screen`. The reset link opens
`reset_password_screen` via deep link. The user's email is **not** sent to analytics (it used to be —
removed under `S17`).

---

## 8. Session & token handling

- **Tokens** are managed entirely by the Firebase Auth SDK: ID tokens auto-refresh (~1h), refresh
  tokens persist across restarts. The app never stores or hand-rolls a token.
- **ID tokens are the credential for every server call** — `aiProxy` and all callables verify them
  in-code alongside App Check.
- **Live user listener**: `UserProvider` holds a Firestore listener on `users/{uid}`, so an admin
  flipping a role or tier updates menus and gates **without a restart**.
- **`AuthService` in-memory cache** with `invalidateUserCache()`. Call it after any out-of-band write
  to the user doc, or the next read returns stale state (see §3).
- **Device context** (`syncDeviceContext`) is written on every app open/resume — not just `is_online`.
- **Force logout** — admin-triggered; the client signs out on the next status check.
  True revocation needs server-side `revokeRefreshTokens`, which lands with `S1`.

---

## 9. Account deletion — GDPR Art. 17 / KVKK Art. 7

**Server-authoritative.** The client never deletes user data itself.

```
Settings → Delete account
   → re-authenticate (Firebase requirement for a sensitive operation)
   → AuthService.deleteAccount()
   → deleteUserAccount callable (functions/account.js, Admin SDK)
        ├─ recursive delete of the whole users/{uid} subtree
        ├─ server-side docs (entitlements, ai_credits, …)
        ├─ authored content
        ├─ all Storage prefixes (profile_photos, post_images, chat_images, *_applications)
        └─ the Firebase Auth user
   → client signs out
```

> ⚠️ Erasure coverage is still incomplete (`BLK-12`). The predecessor deleted only 6 subcollections
> and no Storage at all — leaving health PII and identity documents behind, which is a reportable
> breach, not a bug. Verify coverage against the live collection list in [`DATABASE.md`](DATABASE.md)
> whenever a new user subcollection is added. **Adding a user subcollection means updating the
> erasure function and the export in the same task.**

Related: data export (`DataExportService`) and the DSAR channel are owned by
[`COMPLIANCE.md`](COMPLIANCE.md) §7.

---

## 10. Adding an auth-touching change

- [ ] Does `RouteGuard` need a new gate, or does an existing one cover it? Order matters
- [ ] Does `UserProvider` need `copyWith` rather than a refetch? (§3)
- [ ] Does a new user subcollection need adding to **both** erasure and export? (§9)
- [ ] Is the check enforced server-side, or only in the UI?
- [ ] Does the error message leak whether an account exists?
- [ ] Consent implications → [`COMPLIANCE.md`](COMPLIANCE.md) §9
