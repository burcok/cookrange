# KVKK Clarification Text (Aydınlatma Metni)

Last updated: 5 August 2026

*This is a courtesy English translation of Cookrange's Turkish KVKK clarification text. For users in
Türkiye, the Turkish version is the authoritative document. It is prepared by Cookrange as data
controller under Article 10 of Turkish Personal Data Protection Law No. 6698 ("KVKK").*

> **⚠ Not ready to publish — draft.** This document must not be published before the company's
> official registration details (legal name, address, MERSİS number, tax number) are filled in.

## 1. Identity of the Data Controller

The data controller is **Cookrange**, operated by Burak Dereli. The company's official registration
details (legal name, address, MERSİS number, tax number) will be added to this section after legal
counsel review. Contact: **privacy@cookrangeapp.com**.

## 2. Personal Data Processed

- **Identity & contact:** name/display name, email, profile photo, authentication identifier.
- **Special-category data (health):** height, weight, gender, date of birth, activity level, allergies,
  dietary restrictions, nutrition and exercise logs, weight/hydration tracking.
- **Location data:** approximate device location only when you actively use the relevant features
  (for "gyms near me", location is processed only on your device and is not stored on our servers).
- **Gym presence detection (background, separate and explicit-consent-gated):** only when you
  additionally turn this feature on, the moment you enter/exit the boundary of a gym you're a member
  of. Your latitude/longitude coordinates are never sent to or stored on our servers — only the gym's
  name and your entry/exit time are stored. See Section 8 for the full explanation.
- **Tiered progress-sharing data (only at the tier you grant):** if you explicitly grant it for a
  specific gym/coach relationship, only the check-in/attendance data, logging regularity, and (at the
  top tier) weight-trend DIRECTION at the tier you granted — never your raw weight history. Every
  relationship defaults to tier 0 (off). See Section 9 for the full explanation.
- **Transaction & usage data:** subscription/payment confirmations, device information, app-usage
  analytics, community content you create, and AI prompts.

## 3. Purposes of Processing

- Creating your account, authentication, and delivering core App functions;
- Generating personalised meal plans, recipes, nutrition analytics, and AI insights;
- Providing location-based gym discovery and check-in;
- With your separate explicit consent, creating an automatic check-in via background gym presence
  detection, and (if you allow it) notifying mutual friends;
- When you explicitly grant it, sharing a tiered progress summary with your gym/coach;
- Sending notifications, ensuring security, preventing fraud and abuse, diagnosing errors;
- Processing subscriptions and meeting legal obligations (e.g. financial records).

## 4. Legal Grounds for Processing

- **Explicit consent** (KVKK Art. 5/1 and 6/2): health data, location (including gym presence
  detection, obtained as a separate, revocable consent), tiered progress sharing (separate and
  revocable per gym/coach relationship), notifications, marketing.
- **Establishment/performance of a contract** (Art. 5/2-c): account and core service.
- **Legal obligation** (Art. 5/2-ç): financial records and statutory duties.
- **Legitimate interest** (Art. 5/2-f): security, abuse prevention, service improvement.

## 5. Recipients of Data and Purpose of Transfer

To the extent necessary to provide the service, your data is shared with the following processors:
**Google Firebase** (hosting, auth, database, storage, messaging, analytics), **OpenRouter** (AI
inference), **Apple / Google Play** (in-app purchases), **OpenStreetMap** (map tiles). These providers
may process data on servers abroad; such transfers rely on your explicit consent and/or safeguards
compliant with KVKK Art. 9.

## 6. Method of Collection

Data is collected electronically via the mobile App — during sign-up, onboarding, content creation, and
app use — by automated and partly automated means.

## 7. How Long We Keep Your Data

Under KVKK Art. 10 we disclose retention periods here. General principle: personal data is kept until
its processing purpose no longer applies, or until you delete your account — whichever is sooner. The
concrete exceptions and periods below apply on top of that principle.

- **Your account and profile data; special-category health/nutrition data; food and exercise logs;
  favorites; AI history; XP/badge records; consent records; and access log** — everything tied to your
  account is kept only while your account is active. **Using Settings → Delete Account erases this
  data — including your Firebase authentication record and any images you uploaded — server-side, in
  the same operation, irreversibly.** There is no 30-day or similar waiting period: erasure happens the
  moment it is triggered.
- **A gym's or coach's own operational records** — your membership, your check-in/entry-exit history
  (Section 8), and your weekly community-score contribution, for example — belong to that gym/coach/
  community, not to you. These are not currently subject to a separate, coded automatic deletion
  period, and may remain on the gym's/coach's side after you delete your account. To request deletion
  of these records, contact **privacy@cookrangeapp.com** — we will assess the request under KVKK Art.
  7 / GDPR Art. 17.
- **Coach/gym progress summaries** (Section 9) are kept on our server for a **maximum of 7 days** and
  then deleted automatically; changing or fully revoking your sharing tier deletes it immediately
  instead, without waiting for that 7-day cycle.
- **Financial records** (subscription/commission accruals) are kept for the period required by
  applicable tax/accounting law. A gym's own accounting record of a commission earned through you
  continues to be kept on the gym's side even if you delete your account — only the record that
  attributed that earning to you is deleted with your account; the gym's already-accrued earning is
  not retroactively erased.
- **Content you share with another user** (e.g. a message you send in a chat): the other party's copy
  of that content is part of their own record, so deleting your account does not automatically delete
  it. You can delete your own posts/comments in the App at any time, or remove them as part of account
  deletion.
- **Location data:** as explained in Section 2, the live location used for "gyms near me" is never
  stored on our servers. See Section 8 for how gym-presence entry/exit events are retained.

For any data category not separately listed above, the rule is the general principle at the top of
this section: kept while your account is active, until you delete it.

## 8. Gym Presence Detection (Automatic Check-In) — Full Explanation

Section 2 briefly introduces this feature; because it is gated by its own separate, explicit consent,
we explain it fully here.

- **What triggers it:** only when you are a member of a gym **and** have separately turned this feature
  on for that gym, entering its location boundary and remaining there for a confirmation period
  ("dwell" — merely walking past does not trigger it) may create an automatic check-in; the record
  closes when you leave. If exit information never reaches us for any reason (the app being closed, the
  phone powering off, etc.), a visit left open is automatically closed by the system after at most 4
  hours as a safety measure.
- **Data processed:** only your entry/exit time, the visit's duration, and the gym's name — your
  coordinates (latitude/longitude) are **never sent to or stored on our servers at any stage**; this is
  a consequence of the App's design (location is never transmitted to the server for this feature at
  all), not merely a promise.
- **Consent mechanism:** this is a separate consent purpose and is **off by default**. It is never
  granted automatically at sign-up; you can only turn it on by going through its own non-skippable
  screen that explains, step by step, what it does, what is stored, what is never stored, who can see
  it, its legal basis, and how to turn it off. Even after granting this, you must separately turn it on
  for each individual gym — the general consent only unlocks the feature; it never starts tracking any
  gym on its own.
- **How many gyms at once:** because of the device operating system's background boundary-monitoring
  capacity, at most **3 gyms** can be tracked for automatic check-in at the same time.
- **Who can see it:** the gym's owner sees only your "currently inside" status, at the level of the
  member list; additionally, if you allow it (a separate toggle you can turn off at any time), mutual
  friends who are also members of the same gym may receive a notification that you've arrived — this
  notification never contains your location, only that you're "at this gym," is limited to reasonable
  hours of the day, and you can separately mute any specific friend from these notifications.
- **Server-side verification:** before a check-in record can be created, your membership, the gym's own
  setting for this feature, your general consent, and your separate per-gym permission are all
  re-verified server-side on every single event — none of it is accepted on the strength of your
  device's own claim. A repeat check-in at the same gym is not opened within 10 minutes of your last
  exit (rate limiting).
- **How to withdraw:** the moment you turn this consent off in the Consent Center, our server stops
  creating **any new** entry/exit record for you — this check is re-verified server-side on every
  request, not just at initial setup. To also fully stop your device from continuing to monitor that
  gym's boundary in the background, we recommend additionally turning off automatic check-in for that
  specific gym from the gym's own screen (or revoking the "Always" location permission at the OS
  level).

## 9. Tiered Progress Sharing (Coach/Gym Access)

A gym owner or your coach can see a limited summary of your progress only if you explicitly grant it.
This is a 4-tier system:

- **Tier 0 — Off (default):** the starting state for every gym/coach relationship; no data is shared
  or generated until you decide otherwise.
- **Tier 1 — Attendance:** your check-in frequency, current streak, and last visit.
- **Tier 2 — Attendance + adherence:** adds your logging regularity (plan-adherence percentage, where
  data exists).
- **Tier 3 — Attendance + adherence + weight trend:** adds only your weight's **direction and
  approximate magnitude** (e.g. "trending slightly down") — your raw weight history or any single
  weight value is **never** shared through this path.

You grant, raise, lower, or revoke (with one tap) your permission separately for each gym/coach
relationship (Settings → Consent Center → Progress Sharing); granting it for one gym never carries over
to another gym or to your coach.

- **How it's generated:** when a summary is requested, our server re-verifies, every single time, that
  the requester is genuinely your gym's owner or your active coach **and** checks the tier you've
  granted; without that verification (or while your tier is 0), no data is returned. The same
  requester can generate at most one summary per member per day.
- **AI:** if you also have AI-processing and cross-border-transfer consent, the summary is written
  using AI; otherwise a template narrative is built only from the permitted numeric fields, without any
  AI call — your AI consent is never bypassed through this path.
- **Retention:** a generated summary is kept on our server for a **maximum of 7 days** and deleted
  automatically; changing or revoking your tier deletes it immediately instead, without waiting for
  that 7-day cycle.
- **Access log:** in a log tied to your account, you can see for yourself who viewed a summary about
  your progress, and when. This log remains as a historical record even if you later revoke that
  relationship's tier; it is deleted, along with the rest of your account data, when you delete your
  account.
- **Invitation:** a gym/coach may send you a one-time, informational notification for a relationship
  you haven't shared with yet ("want to share your progress?") — this notification by itself never
  grants access to any data.

## 10. Your Rights as a Data Subject (KVKK Art. 11)

You have the right to: learn whether your data is processed and request information; learn the purpose
and whether it is used accordingly; know the third parties to whom it is transferred at home or abroad;
request correction of incomplete/incorrect data; request erasure or destruction where processed contrary
to law; request that such actions be notified to third parties; object to outcomes arising solely from
automated analysis; and seek compensation for damages.

To exercise these rights, contact **privacy@cookrangeapp.com**; you may also export your data
(Settings → export your data) or delete your account (Settings → Delete Account) in the App. Requests
are concluded within the statutory period (max 30 days).

---

*Draft pending review by qualified legal counsel and assessment of VERBİS registration where applicable,
before public launch.*
