# DATA_MODEL.md — Models, Firestore, Indexes, Rules

> Canonical map of the data layer. Before touching a model, a Firestore query, an index, or a
> security rule, read the relevant row here. **Code is truth — if this drifts, fix it.**
> Owners: `lib/core/models/**`, `lib/core/data/**`, `lib/core/repositories/**`,
> `firestore.rules`, `firestore.indexes.json`, `storage.rules`.

---

## 1. Firestore Collection Map

### User-scoped (under `users/{uid}`)
| Path | Purpose | Access (rules) |
|---|---|---|
| `users/{uid}` | Public profile + onboarding_data (streak, goals, activity, role, tier) | Read: any auth · Create/Update: owner or admin · Delete: owner. **FIELD-LOCKED**: clients cannot write `subscription_tier`/`subscription_*`/`ai_credits_*`/`referral_used`/`is_banned` — these are server/admin-only (entitlements + economy are server-authoritative). |
| `users/{uid}/private/nutrition` | **PII**: height/weight/gender/birth_date, allergies, dietary restrictions, disliked foods, avoid ingredients | Owner only |
| `users/{uid}/meal_plans/current` | Current weekly meal plan (+ generationPromptHash) | Owner only |
| `users/{uid}/meal_plan_history/{key}` | Archived weekly plans (key = `YYYY-MM-DD` week start) | Owner only |
| `users/{uid}/food_logs/{logId}` | Daily food diary entries | Owner only |
| `users/{uid}/exercise_logs/{logId}` | Workout logs (MET-based calorie burn) | Owner only |
| `users/{uid}/favorites/{recipeId}` | Saved recipes | Owner only |
| `users/{uid}/recent_foods/{dishId}` | Last ~20 logged foods (quick-add) | Owner only |
| `users/{uid}/lists/{listId}` | Shopping lists | Owner only |
| `users/{uid}/saved_posts/{postId}` | Bookmarked community posts | Owner only |
| `users/{uid}/recipe_notes/{recipeId}` | User notes on recipes | Owner only |
| `users/{uid}/notifications/{id}` | In-app notifications (structured, no stored text) | Owner read/write |
| `users/{uid}/notification_preferences/{prefId}` | Per-group mute prefs | Owner only |
| `users/{uid}/program_enrollments/{programId}` | Enrolled programs + progress | Owner only |
| `users/{uid}/commissions/{id}` | Affiliate/coach commissions | Read owner · **write server-only** (economy is server-authoritative) · no delete |
| `users/{uid}/payout_requests/{id}` | Payout requests | Owner only |
| `users/{uid}/ai_twin_projections/{id}` | Saved AI fitness projections (locale-tagged) | Owner only |
| `users/{uid}/consents/{purpose}` | KVKK/GDPR consent records (granted, policy_version, updated_at) per purpose | Owner only |
| `users/{uid}/following/{targetUid}` | Following graph | Read any auth · create/delete owner |
| `users/{uid}/followers/{sourceUid}` | Follower graph | Read any auth · create/delete sourceUid |
| `users/{uid}/friends/{friendId}` | Accepted friends | Read owner · write any auth |
| `users/{uid}/friend_requests/{id}` | Pending friend requests | Read owner · create any auth · delete owner/requester |
| `users/{uid}/coaching_requests/{clientUid}` | Coach link requests | Read uid or client · write client |
| `users/{uid}/block_list/{blockedId}` | Blocked users | Owner only |

### Global collections
| Path | Purpose | Access (rules) |
|---|---|---|
| `dishes/{id}` | Recipe/dish DB (seeded; TR + intl) | Read any auth · write admin only |
| `posts/{id}` | Community posts | Read any auth · create author · update author/counters · delete author. Content-length capped at rule level. |
| `posts/{id}/comments/{id}` | Post comments | Read any auth · create author · update author/counter · delete author. Content-length capped. |
| `posts/{id}/likes|reactions/{userId}` | Like/reaction toggles | Read any auth · write owner |
| `chats/{id}` | Chat threads (private/group/system/gym) | Participants only |
| `chats/{id}/messages/{id}` | Chat messages | Participants only. Content-length capped. |
| `signals/{id}` | Ephemeral social broadcasts (TTL via expiresAt) | Read any auth · create owner · delete owner. Content-length capped. |
| `notifications/{uid}/items/{id}` | (legacy alias of user notifications) | Owner |
| `reports/{id}` | Moderation reports | Create author only · read/update **admin backend only** |
| `privacy_requests/{id}` | DSAR requests (uid, email, type, message, status, admin_note) | Create owner · read owner/admin · update admin · no delete |
| `challenges/{id}` | Challenges (legacy; mostly sunset) | Read any auth · create/own |
| `referrals/{code}` | Referral codes (owner, usedByUids, maxUses) | Read any auth · create owner · update owner/admin only with `owner_uid` pinned (immutable) |
| `gyms/{id}` | Gym profiles | Read any auth · create owner · update owner/admin · delete owner |
| `gyms/{id}/members/{id}` | Gym members | Read owner/member · write owner |
| `gyms/{id}/posts/{id}` (+ `/comments`) | Gym community feed | Read any auth · create author · delete author/owner |
| `gyms/{id}/checkins/{id}` | QR/GPS/manual check-ins | Read owner/member · create self · no update/delete |
| `gym_wars/{id}` | Gym vs gym competition | Read any auth · create challenger · update challenger |
| `gym_applications/{id}` | Gym owner applications | Read applicant/admin · create applicant · update admin |
| `coach_profiles/{uid}` | Coach public profiles | Read any auth · create owner · update owner/admin |
| `coach_profiles/{uid}/clients/{clientUid}` | Coach↔client links | Read coach/client · write coach/admin |
| `coach_profiles/{uid}/reviews/{reviewerUid}` | Coach reviews (immutable) | Read any auth · create reviewer (rating 1–5) · no update/delete |
| `coach_applications/{id}` | Coach applications | Read applicant/admin · create applicant · update admin |
| `programs/{id}` (+ `/weeks/{id}/sessions`) | Marketplace programs | Read any auth · create coach/demo · update coach/admin · delete coach |
| `squads/{id}` | Streak Squads | Read member · create creator · update member · delete creator |
| `ai_credits/{uid}` | Server AI ledger — daily quota (used_today, reset_at, is_premium, bonus_credits) **+ per-user lifetime totals** (lifetime_requests, lifetime_tokens, lifetime_cost_usd, lifetime_by_type) | Owner read · **server/admin write only** (server-authoritative; client cannot mint credits) |
| `ai_usage_logs/{id}` | Per-request AI usage/cost log written by `aiProxy` (uid, type, model, prompt/completion/total_tokens, cost_usd, unpriced, created_at) | **Server write only** · admin read |
| `ai_usage_stats/{doc}` | Aggregated AI usage rollups: `global` + `day_YYYY-MM-DD` buckets (total cost/requests/tokens, by_model, by_type) | **Server write only** · admin read |
| `entitlements/{uid}` | Premium entitlement (tier, expiry) — source of truth for paid access; server mirrors `subscription_tier` to the user doc | Owner read · **server/admin write only** |
| `processed_purchases/{id}` | Purchase-token replay guard (dedupes IAP tokens so a receipt can't be redeemed twice) | **Fully server-only** (no client read or write) |
| `admin_audit/{id}` | Append-only admin action log | Create admin · read admin · no update/delete |
| `admin_config/{doc}` | Feature flags, maintenance, AI model, blocked keywords | Admin only |
| `app_config/global` | Remote App Config — `ai` (models/limits/toggles), `version` (min/latest per platform, force_update, store URLs, update_message i18n), `maintenance`, `announcement`, `features` (kill-switches), `rollout`, `limits`, `endpoints.ai_proxy_url`. **No secrets.** | **Public read** · admin write |
| `settings/content_filter` | Blocked-keyword list mirrored from admin config for client moderation pre-screen | **Public read** · admin write |
| `broadcasts/{id}` | Admin broadcast messages | Admin create/read/update |
| `seeds/{doc}` | Idempotent seed gates (e.g. `demo.demo_programs_v1`) | Auth read/write |
| `logs/{uid}` | Activity/login audit | Owner |
| `failed_login_attempts/{id}` | Brute-force tracking | Create any · read/update/delete admin |
| `settings/{doc}` | App config (read-only) | Read any auth · no write |

---

## 2. Models (`lib/core/models/`, 42 files)

### User & profile
- **user_model.dart** `UserModel` → `users/{uid}`. Fields: uid, email, displayName, photoURL,
  isOnline, onboardingCompleted, createdAt, lastLoginAt, onboardingData (nested public map),
  subscriptionTier (free/premium/pro), userRoles[], gymMemberships, isPrivate (`is_private`).
  `fromFirestore`, `copyWith`, `withPrivateNutrition()`, `hasRole(UserRole)`.
- **user_nutrition_profile.dart** `UserNutritionProfile` — typed view over onboarding_data +
  private nutrition (gender, birthDate, heightCm, weightKg, activityLevel, primaryGoals,
  allergyIds, dietaryRestrictionIds, dislikedFoodKeys, avoidIngredients, cookingLevel,
  kitchenEquipmentIds, lifestyleProfile, mealSchedule). View-only.
- **user_profile_model.dart** `UserProfile` — composite (UserModel + login history + activity).
- **user_activity_model.dart** `UserActivityItem`, **login_history_model.dart** `LoginHistoryItem`,
  **user_logs_model.dart** `UserLogs` → `logs/{uid}`.
- **subscription_model.dart** `SubscriptionTier {free,premium,pro}` + `Entitlements` (derived
  feature flags: isPaid, isPremiumOrAbove, isPro, weeklyMealPlanGenerations, …).

### Food & nutrition
- **dish_model.dart** `DishModel` → `dishes/{id}`. name/nameEn, descriptions, imageUrl, calories,
  protein/carbs/fat/fiber, category, tags, mealType, prep/cookTime, difficulty, servings,
  ingredients[], instructions[]. `fromFirestore`, `fromJson`, `toJson`, `toRecipe()`.
  Categories: meat, fish, breakfast, vegetarian, vegan, diet, sport, turkish_classic.
- **ingredient_model.dart** `Ingredient` (name, amount, unit, calories) — nested in dishes.
- **recipe_model.dart** `Recipe` — UI model (title, imageUrl, times, servings, difficulty,
  macros{}, ingredients[], instructions[], tags[]). Not Firestore-mapped.
- **food_log_model.dart** `FoodLog` → `users/{uid}/food_logs/{id}` (mealType, dishId, dishName,
  calories, macros, loggedAt, date=YYYY-MM-DD) + `NutritionTotals` + `sumLogs()`.
- **meal_plan_model.dart** `MealPlan` (logical) · **weekly_meal_plan_model.dart**
  `WeeklyMealPlanModel` → `users/{uid}/meal_plans/current` (days[DayMealPlan], totals,
  generationPromptHash, isAiGenerated, aiModel, expiresAt).

### Fitness
- **exercise_log_model.dart** `ExerciseLog` + `ExerciseType` (MET table: running 9.8 … yoga 2.5).
  `estimateCalories(weightKg, minutes)`.
- **checkin_model.dart** `CheckInModel` → `gyms/{id}/checkins/{id}` (uid, method qr/gps/manual).

### Gym
- **gym_model.dart** `GymModel` → `gyms/{id}` (ownerUid, name, address, city, district, isPublic,
  memberCount, subscriptionTier, tags, lat/lng, checkInRadius, qrToken+expiry, brandColor,
  isVerified). **gym_member_model.dart**, **gym_post_model.dart** (`GymPostModel`+`GymCommentModel`),
  **gym_war_model.dart**, **gym_analytics_model.dart** (computed), **gym_application_model.dart**.

### Coach & programs
- **coach_profile_model.dart** `CoachProfileModel` → `coach_profiles/{uid}` (bio, specializations,
  certifications, isAcceptingClients, vanityCode, clientCount, hourlyRate, city, district,
  avgRating, ratingCount, isVerified).
- **coach_client_model.dart** `CoachClientModel`, **coach_review_model.dart** `CoachReviewModel`
  (immutable, transaction-updates coach avgRating), **coach_application_model.dart**.
- **program_model.dart** `ProgramModel` → `programs/{id}` (coach info, difficulty, category,
  durationWeeks, sessionsPerWeek, price, status draft/pending/approved/rejected, enrollmentCount,
  rating). **program_content_model.dart** `ProgramSessionModel`, **program_enrollment_model.dart**
  `ProgramEnrollmentModel` (currentWeek, progressPercent).

### Social
- **community_post.dart** `CommunityPost`+`CommunityComment`+`CommunityUser` → `posts/**`
  (PostType text/recipe/progress/meal, reactions{}, likedByUids[], tags, isEdited).
- **signal_model.dart** `SignalModel` (TTL), **streak_squad_model.dart** `StreakSquadModel`,
  **follow_model.dart** `FollowModel`.
- **chat_model.dart** `ChatModel` (participants, lastMessage, unreadCounts, type, typingUsers) ·
  **message_model.dart** `MessageModel`.
- **notification_model.dart** `NotificationModel` (structured: type enum, actorUid/Name/PhotoUrl,
  relatedId, metadata; legacy title/body fallback). `copyWithRead()`.

### Commerce & analytics
- **commission_model.dart** `CommissionModel` (referral/coachSession/programSale; pending/approved/
  paid/rejected) · **earnings_summary_model.dart** `EarningsSummaryModel` (computed).
- **ai_credit_model.dart** `AiCreditModel` (used, isPremium, resetAt, bonus; freeDailyLimit=2,
  premiumDailyLimit=20; remaining/isExhausted/usagePercent/minutesUntilReset).
- **ai_insight_model.dart** `AiInsightModel` (accountability/riskAlert/projection/tip; riskLevel).
- **consent_model.dart** `ConsentModel` + `ConsentPurpose` enum (healthData, location, aiProcessing,
  crossBorderTransfer, analytics, notifications, marketing) → `users/{uid}/consents/{docId}`. Fields:
  granted, policyVersion, updatedAt. `isUnset`, `isStale` (granted vs `kLegalPolicyVersion`).
  Const `kLegalPolicyVersion` — bump on material legal-text change to trigger re-consent.
- **privacy_request_model.dart** `PrivacyRequestModel` + `PrivacyRequestType` (access, rectification,
  erasure, restriction, objection, portability, withdrawConsent, other) + `PrivacyRequestStatus`
  (pending/inProgress/resolved/rejected) → `privacy_requests/{id}` (DSAR channel).
- **leaderboard_entry_model.dart** `LeaderboardEntryModel` (computed) ·
  **report_model.dart** `ReportModel` → `reports/{id}` · **analytics_event.dart** `AnalyticsEvent`.

---

## 3. Reference Data (`lib/core/data/`)
- **dish_data.dart** — ~3,000 lines; 50+ TR/intl dishes in batches (meat, fish, breakfast).
  Seeded into `dishes/` by `DishSeederService.seedIfEmpty()` (idempotent batch writes).
- **turkish_locations.dart** — all 81 provinces + full district lists (~1,100 districts). Powers
  city/district filters in gym & coach discovery.

## 4. Repositories (`lib/core/repositories/`) — in-memory caches
- **DishRepository** — singleton dish cache (getDishById, prefetch, preload, snapshot; test-mode aware).
- **FoodLogRepository** — todayLogsStream, logMeal/logRecipe, removeLog, getWeeklyLogs.
- **MealPlanRepository** — meal plan CRUD + generation caching.
- **ShoppingRepository** — shopping list (favorites → lists).

---

## 5. Composite Indexes (`firestore.indexes.json`, ~52)

Add an index here for **every new query shape** (`where` + `orderBy` combos). Current families:

- **posts**: createdAt DESC · authorId+timestamp DESC · tags(array)+timestamp DESC ·
  is_announcement+created_at DESC (collection-group)
- **signals**: expiresAt ASC + createdAt DESC
- **messages**: createdAt ASC
- **food_logs**: date DESC + loggedAt DESC · **exercise_logs**: date+loggedAt
- **challenges**: isPublic+endDate · participantIds(array)+createdAt
- **favorites**: savedAt DESC · **recent_foods**: lastLoggedAt DESC, logCount DESC ·
  **meal_plan_history**: archivedAt DESC
- **gyms**: owner_uid · is_public+name · is_public+city+name · is_public+city+member_count DESC ·
  is_public+city+district+name · **members**: joined_at
- **gym_wars**: gym_a_id+status · gym_b_id+status
- **coach_profiles**: is_public+is_accepting_clients+display_name · +city+avg_rating DESC ·
  +city+client_count DESC · +avg_rating DESC · +client_count DESC · +is_verified+avg_rating DESC ·
  **clients**: status+linked_at DESC · **reviews** (collection-group): coachUid+createdAt DESC
- **programs**: is_published+enrollment_count DESC · +category+enrollment_count DESC ·
  coach_uid+created_at DESC · status+created_at DESC · is_published+status+enrollment_count DESC ·
  +status+category+enrollment_count DESC
- **commissions**: created_at DESC · **ai_twin_projections**: locale+generatedAt DESC
- **coach/gym_applications**: status+submittedAt DESC · applicantUid+submittedAt DESC
- **admin_audit**: createdAt DESC · **reports**: status+timestamp DESC · **squads**: memberUids(array)+createdAt DESC
- **privacy_requests**: uid+created_at DESC (user list) · status+created_at DESC (admin queue)
- **following**: followedAt DESC · **users**: onboarding_data.streak DESC (leaderboard)

---

## 6. Storage Rules (`storage.rules`)
| Path | Access |
|---|---|
| `profile_photos/{uid}` | Read any auth · write owner, image <5MB |
| `post_images/{uid}/{file}` | Read any auth · write/delete owner, image |
| `chat_images/{uid}/{file}` | Read any auth · write/delete owner, image |
| `gym_applications/{uid}/documents/{file}` | Owner only, <10MB |
| `coach_applications/{uid}/documents/{file}` | Owner only, <10MB |
| `gym_logos/{gymId}/{file}` | Read any auth · write/delete any auth (app-enforced owner) |

---

## 7. Security-Rule Conventions (when adding a path)
- Default deny. Every new collection gets an explicit rule — never leave one unguarded.
- Owner-only for anything user-private; `request.auth.uid` checks.
- Admin gate via the admin claim/doc check used in `firestore.rules` (see `admin_audit`,
  `admin_config`, `reports`).
- Counters (likes/reactions) get narrow update rules so users can only mutate the counter, not
  the whole doc.
- Immutable collections (reviews, audit) deny update/delete.
- PII never on the public user doc — it lives in `users/{uid}/private/nutrition`.
- **Server-authoritative state is never client-writable.** Entitlements (`entitlements`, the user
  doc's `subscription_*`/`subscription_tier`), AI credits (`ai_credits`, the user doc's
  `ai_credits_*`), economy (`commissions`), and trust flags (`is_banned`, `referral_used`) are
  written only by Cloud Functions / admin. The public user doc is **field-locked**: client updates
  must not touch any of those fields. IAP grants flow through a server purchase verifier guarded by
  `processed_purchases` (replay protection).
- Content-length caps belong in the rule (`request.resource.data.<field>.size() < N`) for any
  user-authored free text — posts, comments, chat messages, signals.
