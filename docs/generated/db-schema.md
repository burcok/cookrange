# db-schema.md (generated reference)

> Flat quick-reference of every Firestore path. Derived from `docs/DATA_MODEL.md` (the authoritative
> source — full field lists, models, indexes, and rules live there). Regenerate this when collections
> change.

```
users/{uid}                                    public profile + onboarding_data, role, tier
  ├─ private/nutrition                          PII (height/weight/gender/dob, allergies, restrictions)
  ├─ meal_plans/current                         current weekly plan
  ├─ meal_plan_history/{YYYY-MM-DD}             archived weekly plans
  ├─ food_logs/{id}                             daily food diary
  ├─ exercise_logs/{id}                         workout logs
  ├─ favorites/{recipeId}                        saved recipes
  ├─ recent_foods/{dishId}                       quick-add cache (~20)
  ├─ lists/{listId}                              shopping lists
  ├─ saved_posts/{postId}                        bookmarked posts
  ├─ recipe_notes/{recipeId}                     user recipe notes
  ├─ notifications/{id}                          structured in-app notifications
  ├─ notification_preferences/{id}               per-group mute prefs
  ├─ program_enrollments/{programId}             enrolled programs + progress
  ├─ commissions/{id}                            affiliate/coach commissions
  ├─ payout_requests/{id}                        payout requests
  ├─ ai_twin_projections/{id}                    saved AI projections (locale-tagged)
  ├─ following/{targetUid} · followers/{srcUid}  social graph
  ├─ friends/{id} · friend_requests/{id}         friendship
  ├─ coaching_requests/{clientUid}               coach link requests
  └─ block_list/{blockedId}                      blocked users

dishes/{id}                                     recipe DB (admin-write)
posts/{id}                                      community posts
  ├─ comments/{id}                               (+ likes/{userId})
  ├─ likes/{userId} · reactions/{userId}
chats/{id}/messages/{id}                        chat threads + messages
signals/{id}                                    ephemeral broadcasts (TTL)
reports/{id}                                    moderation (admin-read)
challenges/{id}                                 legacy challenges
referrals/{code}                                referral codes

gyms/{id}                                       gym profiles
  ├─ members/{id} · checkins/{id}
  └─ posts/{id}/comments/{id}                    gym feed
gym_wars/{id}                                   gym vs gym
gym_applications/{id}                           gym owner applications

coach_profiles/{uid}                            coach profiles
  ├─ clients/{clientUid}
  └─ reviews/{reviewerUid}                       immutable
coach_applications/{id}                         coach applications

programs/{id}/weeks/{id}/sessions/{id}          marketplace programs
squads/{id}                                     streak squads

ai_credits/{uid}                                daily AI quota (server-authoritative)
admin_audit/{id}                                append-only admin log
admin_config/{doc}                              flags / maintenance / AI model / keywords
broadcasts/{id}                                 admin broadcasts
seeds/{doc}                                     idempotent seed gates
logs/{uid}                                      activity/login audit
failed_login_attempts/{id}                      brute-force tracking
settings/{doc}                                  read-only app config

# Storage
profile_photos/{uid} · post_images/{uid}/{f} · chat_images/{uid}/{f}
gym_applications/{uid}/documents/{f} · coach_applications/{uid}/documents/{f}
gym_logos/{gymId}/{f}
```
