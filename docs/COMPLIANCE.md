# COMPLIANCE.md — Legal, Privacy & Data Protection Framework

> **Cookrange is built legal-first.** Every feature that touches personal data must satisfy this
> framework *before* it ships. Data security and lawful processing are treated as release blockers,
> not afterthoughts. This file is the engineering backbone for **KVKK** (Türkiye — Law No. 6698) and
> **GDPR** (EU — Regulation 2016/679) compliance.
>
> ⚠️ **Not legal advice.** This is engineering-grade compliance scaffolding and document drafting,
> authored by an AI, **not a lawyer**. Every in-app legal document and data-flow decision here must be
> **reviewed and signed off by a qualified data-protection lawyer** (ideally one licensed in Türkiye
> *and* the EU) before public launch. See §10.

---

## 1. Scope & Roles
- **Data Controller:** Cookrange (operator: Burak Dereli / the legal entity that ships the app).
- **Applicable regimes:** KVKK (Turkish users) + GDPR (EU/EEA users). Where they differ, apply the
  **stricter** requirement.
- **Special-category data:** Cookrange processes **health & fitness data** (body metrics, allergies,
  dietary restrictions, weight, activity). This is *özel nitelikli kişisel veri* (KVKK Art. 6) /
  *special category data* (GDPR Art. 9) and requires **explicit consent** (açık rıza) — a higher bar
  than ordinary data.

## 2. Core Principles (apply to every feature)
1. **Lawfulness, fairness, transparency** — process only with a valid legal basis (§3) and tell the
   user clearly.
2. **Purpose limitation** — collect for a specific, declared purpose; don't repurpose silently.
3. **Data minimization** — collect the *least* data needed. Prefer **transient, on-device** use over
   storage. *(Reference implementation: "gyms near me" uses location in-memory for distance sort and
   never sends/stores it — see §6.)*
4. **Accuracy** — let users correct their data (profile editing exists).
5. **Storage limitation** — define a retention period; delete when no longer needed.
6. **Integrity & confidentiality** — encryption in transit (HTTPS/Firebase) **and at rest on-device
   (Hive AES-256)**, least-privilege Firestore rules, PII in owner-only subcollections, App Check, no
   secrets in the client. Entitlements/credits/economy/erasure are **server-authoritative** — the
   client is never trusted to grant paid access, mint AI credits, or self-erase (see `DATA_MODEL.md` §7).
7. **Accountability** — document the basis and flow for every data type (this file + `DATA_MODEL.md`).

## 3. Legal Bases
| Basis | When used in Cookrange |
|---|---|
| **Explicit consent** (açık rıza / Art. 9) | Health/fitness data, location, push, tracking (ATT), marketing |
| **Contract performance** | Account, auth, core app function the user signed up for |
| **Legitimate interest** | Security, fraud/abuse prevention, crash diagnostics (balanced, opt-out where feasible) |
| **Legal obligation** | Tax/financial records for paid transactions, breach notifications |

Consent must be **freely given, specific, informed, unambiguous**, and **withdrawable** as easily as
it was given. Record when/what was consented to.

## 4. Data Inventory (what we process, basis, storage, retention)
Cross-reference `docs/DATA_MODEL.md` for exact Firestore paths.

| Data | Examples | Sensitive? | Basis | Stored where | Retention |
|---|---|---|---|---|---|
| Account / identity | email, display name, photo, auth uid | No | Contract | `users/{uid}`, Firebase Auth | Until account deletion |
| Health & fitness PII | height, weight, gender, DOB, allergies, dietary restrictions | **Yes** | Explicit consent | `users/{uid}/private/nutrition` (owner-only) | Until deletion / consent withdrawal |
| Food & exercise logs | meals, calories, workouts | Yes (health) | Explicit consent | `users/{uid}/food_logs`, `exercise_logs` | Until deletion |
| Location | GPS for "gyms near me", GPS check-in | **Yes** | Explicit consent | **Not stored** (in-memory only) | Transient — discarded after use |
| Social content | posts, comments, chats, follows | No | Consent / contract | `posts`, `chats`, … | Until deletion / takedown |
| Device & usage | device model, OS, app version, analytics events | No | **Consent (opt-in)** | Analytics, `logs/{uid}` | Rolling, per policy |
| AI inputs | prompts, profile context sent to OpenRouter | Yes (derived) | Explicit consent | Not persisted by us beyond the call; processor sees it | Per processor policy |
| Payment | purchase receipts, subscription tier | No (handled by store/PSP) | Contract / legal obligation | Store + `users/{uid}` flags | Per tax law |
| Commissions/payouts | earnings, payout account (future) | No | Contract / legal obligation | `commissions`, future PSP | Per tax law |

## 5. Third-Party Processors (sub-processors — must be disclosed in Privacy Policy)
- **Google Firebase** (Auth, Firestore, Storage, FCM, Crashlytics, Analytics, Performance, Remote
  Config, App Check) — hosting + infra; data may be processed on Google servers (cross-border).
- **OpenRouter** (LLM inference) — receives AI prompt + profile context via the server proxy.
- **Apple / Google Play** — IAP billing.
- **Payment provider** (future, e.g. Stripe/iyzico) — payouts/KYC.
- **OpenStreetMap tiles** (flutter_map) — map rendering (tile requests carry IP).
Each must appear in the Privacy Policy with purpose + region + safeguard. Cross-border transfers
require a lawful mechanism (KVKK explicit consent / commitment; GDPR SCCs or adequacy).

## 6. The Standard Consent + Disclosure Pattern (MANDATORY for data access)
Before accessing any sensitive resource (location, camera, photos, notifications, health data, AI):
1. **Disclose first** — show a `PermissionPrimer` (or in-flow disclosure) that states: **purpose**,
   **what data**, **whether it's stored**, **legal note (KVKK/GDPR)**, and that the user **can decline**.
2. **Get explicit consent** — only proceed to the OS dialog / processing if the user agrees.
3. **Minimize & honor** — use the least data, for that purpose only; if the user declines, degrade
   gracefully (e.g. keep city-based browsing).

**Reference implementation — "Gyms Near Me"** (`gym_discovery_screen.dart::_activateNearMe`):
`PermissionPrimer.show(...)` with `gym.nearby_consent_*` keys explicitly states location is processed
on-device, **not sent to or stored on our servers (KVKK/GDPR)**, and is declinable — *then* the OS
location prompt runs, and the coordinate lives only in in-memory state for distance sorting.
**Copy this pattern for every new sensitive-data feature.**

## 7. Data Subject Rights (must remain functional)
KVKK Art. 11 / GDPR Art. 15–22 — users can: access, rectify, erase, restrict, port, and object.
- **Access / portability:** ✅ **complete** export — `DataExportService` → JSON from Settings now
  includes private nutrition PII, **all** owner subcollections, authored comments, and a Storage
  manifest (GDPR Art. 20 / KVKK Art. 11).
- **Erasure:** ✅ **server-side recursive erasure** — the `deleteUserAccount` Cloud Function deletes
  the whole `users/{uid}` subtree + `entitlements`/`ai_credits`/`logs`/`notifications` + authored
  `posts`/`signals` + **all** Storage prefixes + the Firebase Auth user (GDPR Art. 17 / KVKK Art. 7).
  This replaces the old partial client-side delete, which left orphaned server data.
- **Rectification:** profile editing.
- **Withdraw consent:** the **Consent Center** (Settings → Privacy & Consents) — one surface to grant/
  withdraw each purpose, backed by `ConsentService` writing versioned, timestamped records to
  `users/{uid}/consents/{purpose}` (demonstrable consent). Plus notification mutes, privacy toggle, and
  OS permission revocation.
- **DSAR channel:** ✅ in-app **Privacy Requests** (Settings → Privacy Requests) — file
  access/rectify/erase/restrict/object/portability/withdraw/other; tracked in `privacy_requests/{id}`;
  admin resolves within the statutory period (KVKK 30 days / GDPR 1 month) via the admin queue.
- **Registration capture (primary):** consent is collected at sign-up with a **two-tier** model —
  a **required, explicit** consent for *essential* processing (health/fitness data, AI, cross-border
  transfer — genuinely necessary to run a nutrition app, so conditioning the account on them is
  defensible) plus **optional opt-in** checkboxes (analytics, marketing) that never block sign-up.
  Recorded versioned via `ConsentService.recordInitialConsents()`. Terms/Privacy acceptance is kept
  separate from the data consent (KVKK wants açık rıza unbundled from the general contract).
- **First-run nudge (fallback):** `ConsentPromptSheet` only shows for legacy users who registered
  before consent capture existed (the registration flow sets the seen-flag). It never auto-grants.

**Remaining gaps (deferred, post-hardening):**
- **Point-of-use consent for AI/photo processing → OpenRouter (cross-border):** enforce a
  `ConsentService.hasConsent(aiProcessing/crossBorderTransfer)` check at the call site before sending
  prompts/photos to the LLM processor, not just at registration.
- **Minimize the world-readable user doc:** `email`, IP, and `fcm_token` are currently on the
  any-auth-readable `users/{uid}` doc — move to an owner-only subdocument / server-only field.
- **Storage upload hygiene:** scan uploaded images and strip EXIF (incl. GPS) on profile/post/chat
  uploads before they become readable.
- **Analytics/Crashlytics consent (✅ enforced):** collection is **privacy-by-default OFF** and gated
  on the user's analytics consent — `ConsentService.applyCollectionConsent()` toggles Firebase
  Analytics/Crashlytics collection on/off to match the recorded consent. Raw email is **no longer**
  sent in Analytics events.
- **Remaining (deferred — see "Remaining gaps" below):** point-of-use consent *enforcement* for the
  remaining purposes — chiefly AI/photo processing sent to OpenRouter (cross-border). Tracked in
  `FUTURE_FEATURES.md` (consent hardening).

## 8. In-App Legal Documents (EN + TR)
Legal text lives in **`assets/legal/<base>_<lang>.md`** (NOT in the i18n JSON — keeps it out of the
parity test and lets docs be comprehensive). `lib/screens/legal/legal_screen.dart` loads the right file
by `LegalDocumentType` + active locale and renders it with a dependency-free markdown renderer (`_MarkdownView`:
headings, bullets, tables, bold, rules). Entry points: Register screen + Settings → legal section.

**Drafted (✅ — comprehensive, grounded in §4–§5):**
1. ✅ **Privacy Policy / Gizlilik Politikası** (`privacy_policy_{en,tr}.md`) — full data inventory,
   legal bases, storage/security, **AI processing**, **Cookie/SDK & tracking**, processors, cross-border
   transfer, rights, children, breach, contact. *(Cookie/SDK + AI disclosures live as sections here.)*
2. ✅ **Terms of Use / Kullanım Koşulları** (`terms_of_use_{en,tr}.md`) — eligibility, accounts, health
   disclaimer, acceptable use, UGC licence, coaches/gyms as third parties, subscriptions/credits,
   marketplace, IP, termination, liability, governing law.
3. ✅ **KVKK Aydınlatma Metni** (`kvkk_aydinlatma_{tr,en}.md`) — TR statutory clarification + EN courtesy.
4. ✅ **Açık Rıza Beyanı** (`explicit_consent_{tr,en}.md`) — explicit consent for health data, location,
   AI processing, cross-border transfer, notifications; withdrawable; TR + EN.
5. ⏳ **Coach & Marketplace Agreement** (`marketplace_terms_{en,tr}.md`) — drafted EN+TR (provider
   status, fees/commission, payouts/KYC, taxes, refunds, conduct, liability). **Wires into the UI when
   payments/payouts ship (roadmap A1/L7).**

⚠️ **All drafts are baseline text authored by an AI and MUST be reviewed by a qualified lawyer before
public launch.** Do not copy another app's contracts verbatim (copyright + practice mismatch) — these
are tailored to our actual data flows (§4–§5). Consent logging + a consent center are tracked as roadmap
L2; update these files (both languages) whenever data practices change.

## 9. Per-Feature Legal Checklist (gate every data-touching feature)
- [ ] Does it collect/process personal data? If yes, identify each data point.
- [ ] Is any of it **sensitive** (health, location, biometric)? → explicit consent required.
- [ ] **Legal basis** chosen and recorded (§3).
- [ ] **Disclosure + consent** shown *before* access (§6 pattern); declinable with graceful fallback.
- [ ] **Data minimization:** is storage actually needed, or can it be transient/on-device?
- [ ] **Storage + retention** defined; reflected in §4 inventory + `DATA_MODEL.md`.
- [ ] **Security:** owner-only Firestore rule, encryption in transit, no PII on public docs/logs.
- [ ] **New sub-processor?** → add to §5 + Privacy Policy.
- [ ] **Cross-border transfer?** → lawful mechanism + disclosure.
- [ ] **User rights** still satisfiable (export/delete cover the new data).
- [ ] **Children:** feature doesn't target under-age users beyond policy.
- [ ] Legal copy added EN+TR; `COMPLIANCE.md` + relevant docs updated.

This checklist is mirrored in `AGENTS.md` §2 so it runs on every prompt.

## 10. Lawyer Review & Ownership
Engineering can build the *mechanisms* (consent flows, minimization, export/delete, rules) and *draft*
the documents. **Legal validity, finalized contract wording, DPO appointment, VERBİS registration
(KVKK data-controller registry, if applicable), and cross-border transfer mechanisms require a
qualified lawyer.** Treat this file as the bridge between code and counsel — keep it accurate so legal
review is fast and grounded in what the app actually does.

## 11. Cross-Border Transfers & VERBİS (roadmap L5)

**Transfer register** — where personal data leaves Türkiye/EEA, and the basis:

| Recipient | Data | Likely region | Basis we rely on |
|---|---|---|---|
| Google Firebase | All app data (auth, Firestore, storage, messaging, analytics) | Google global (often US/EU) | Explicit consent + provider safeguards (Google's SCCs / DPA) |
| OpenRouter | AI prompts + profile context | US/global | Explicit consent (`aiProcessing` + `crossBorderTransfer`) |
| Apple / Google Play | Purchase metadata | Global | Contract / store operator |
| OpenStreetMap | IP at map-tile request | EU/global | Legitimate interest (map rendering) |

**Engineering status:** ✅ transfer disclosed in Privacy Policy §8 + KVKK Aydınlatma §5; ✅ a dedicated
`crossBorderTransfer` consent purpose exists in the Consent Center; ✅ Firebase DPA/SCCs are accepted via
the Firebase console (a one-time owner action).

**Open legal/ops decisions (require counsel):**
- [ ] Confirm whether **VERBİS registration** is required (depends on entity type, employee count, and
  whether processing is a core activity). Register if obligated.
- [ ] Sign/accept each processor's **DPA** (Firebase, OpenRouter, payment provider) in their consoles.
- [ ] Confirm the lawful KVKK transfer mechanism for each recipient (explicit consent vs. commitment
  letter / adequacy) and the GDPR mechanism (SCCs / adequacy) — document the final choice here.

## 12. Data Breach Response Runbook (roadmap L6)

A personal-data breach is any unauthorised access, loss, alteration, or disclosure. Run this on detection:

1. **Detect & contain (hour 0–2):** triggered by Crashlytics/anomaly alerts, a report, or a provider
   notice. Immediately contain (revoke keys/tokens, disable the affected path, rotate secrets via
   `firebase functions:secrets:set`).
2. **Assess (hour 0–24):** what data, how many users, which regions, severity, and whether it is "likely
   to result in risk to rights and freedoms." Record facts in an incident log.
3. **Notify authorities:**
   - **KVKK Board** — "en kısa sürede" (Board practice: **within 72 hours** of becoming aware).
   - **GDPR supervisory authority** — **within 72 hours** unless unlikely to pose a risk.
4. **Notify affected users** — without undue delay where there is high risk; clear language, what
   happened, likely consequences, what we did, what they should do (e.g. change password). Use the
   in-app broadcast + email.
5. **Remediate & review:** fix root cause, add a regression guard/test, update rules, and record
   lessons learned. Append a dated entry below.

**Roles:** incident lead = founder/DPO. **Contact:** privacy@cookrangeapp.com.
**Pre-reqs to have ready:** Crashlytics velocity alerts on; Firestore backups scheduled (see
`docs/roadmap/GO_LIVE.md` §5.5); a way to email all affected users.

*Incident log:* (none yet)
