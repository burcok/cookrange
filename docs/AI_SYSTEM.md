# AI_SYSTEM.md — LLM Architecture, Cost & Safety

> How Cookrange calls a language model, what it costs, and why it can't be abused.
> The proxy's security posture is summarized in [`SECURITY.md`](SECURITY.md) §5; the wire contract is
> in [`API.md`](API.md) §2; credits and quota tiers are in [`PREMIUM.md`](PREMIUM.md).
>
> **Owns:** `lib/core/services/ai/`, the AI feature services, `aiProxy` in `functions/index.js`.

---

## 1. Why this is a safety system, not just a feature

The model's output becomes **meal plans and nutrition guidance for people with allergies**. A wrong
answer is not a bad UX — it can be a health harm. Two consequences run through this whole document:

1. **Never fabricate.** An AI path that returns plausible content when it isn't actually talking to a
   model is the worst possible failure. Release builds serving hardcoded fake meal plans by default
   was exactly this, tracked as `BLK-01` — closed; see §9.
2. **Never trust the model with safety.** Allergen exclusion is enforced **deterministically in Dart**,
   before and after the model — not by asking the model nicely.

---

## 2. Architecture

```
Screen
  └─ AiCreditService          read-only badge; pre-empts an obvious 402
  └─ Feature service          WeeklyMealPlanService · RecipeGenerationService
                              AiChatService · AiInsightService · FoodAnalysisService
       └─ PromptService       template + locale + injection fencing
       └─ AIService           retry, typed errors, JSON parsing, type tagging
            └─ aiProxy  (Cloud Function — MANDATORY in release)
                 ├─ verify Firebase ID token
                 ├─ verify App Check
                 ├─ per-uid rate limit
                 ├─ model allowlist + max_tokens / payload caps
                 ├─ read app_config/global (5-min cache) → model, tokens, temperature, quota
                 ├─ enforceAndConsumeQuota()  ← Firestore transaction, FAIL-CLOSED, 402 if exceeded
                 ├─ POST OpenRouter with the server-held key
                 └─ meter usage → ai_usage_logs · ai_usage_stats · per-user lifetime totals
```

**The proxy is the only trusted party.** It ignores the client's requested model and reads its own
config — a client cannot make the server spend more per call than an admin configured.

> ⚠️ A debug-only direct-key path still exists in `AIService`, and the key is currently bundled as a
> Flutter asset and shipped in CI artifacts (`BLK-15`). Treat that key as already compromised: remove
> it from the bundle (`S6`) and set an OpenRouter hard spend cap.

---

## 3. Models & configuration

| | |
|---|---|
| Provider | OpenRouter (`https://openrouter.ai/api/v1/chat/completions`) |
| Default text model | `openai/gpt-4o-mini` — **paid** |
| Vision model | `.env OPENROUTER_VISION_MODEL`; `AIService.isVisionAvailable` gates the photo option |
| `MAX_OUTPUT_TOKENS` | 8192 (meal-plan JSON is large; 1024 truncated it) |
| Timeout | 90s (`OPENROUTER_TIMEOUT_S`) — client raised 45→90 to match |
| Per-type overrides | `model_by_type`, `max_tokens_by_type` in `app_config/global` |

> ⚠️ The previous default `deepseek/deepseek-chat-v3-0324:free` was **removed from OpenRouter and now
> 404s**. The default is a paid model, so **the OpenRouter account must carry credit or every AI call
> fails**. Free-tier meta-routers were also tried and rate-limited on large plan JSON.

**Model, tokens, temperature, and quota are changed from the admin panel with no redeploy** — client
and proxy read the same `app_config/global` doc (ADR-011).

---

## 4. Features and their call types

Every call carries a `type` that flows to the proxy for per-request cost attribution.

| Type | Service | What it generates |
|---|---|---|
| `meal_plan` | `WeeklyMealPlanService` | Full week of meals from a filtered dish pool |
| `recipe` | `RecipeGenerationService` | A structured recipe from constraints |
| `insight` | `AiInsightService` | Daily accountability nudge; 30/60/90-day fitness twin |
| `weekly_recap` | `AiInsightService` | Week score, wins, challenges, recommendation |
| `food_photo` | `FoodAnalysisService` | Nutrition estimate from a photo (vision) |
| `chat` | `AiChatService` | Profile-aware nutrition coach conversation |

---

## 5. Prompt strategy

`PromptService` owns every template. Structure:

1. **System role** — who the model is, what it must never do, output contract
2. **Structured user context** — goals, macros, restrictions as typed fields, not prose
3. **Fenced user text** — anything the user typed, delimited and explicitly labelled as data
4. **Output schema** — exact JSON shape, with a "return only JSON" instruction
5. **Locale instruction** — respond in the user's language

**Rules for changing a prompt**
- Estimate the token cost before and after — prompts run on every user, every week
- Respect the **180-dish prompt ceiling**: the candidate pool cannot grow indefinitely, which is a
  hard scalability limit on the meal planner (`TODO.md` §1.1)
- Any new free-text insertion point needs fencing (§7)
- Changing the output schema means changing the parser in the same task

---

## 6. Cost control

Firestore reads and AI calls are the two dominant cost lines.

| Layer | Mechanism |
|---|---|
| **Quota** | Free 2/day · Premium 20/day · IAP bonus credits never reset. Enforced **server-side, fail-closed**, in a Firestore transaction; bonus burned first; auto-reset at midnight |
| **Rate limit** | Per-uid window in the proxy, independent of daily quota |
| **Caps** | Model allowlist · `max_tokens` · payload size |
| **Caching** | Meal plans hash-cached on the profile (profile change → regenerate, otherwise reuse) · daily insight cached in SharedPrefs per date+locale · weekly recap idempotent per week+locale via Firestore |
| **Free paths** | Low-data weekly recap (<3 days logged) costs no credit · client-side risk detection uses no AI at all |
| **Metering** | Real OpenRouter `usage` tokens × per-model price → `ai_usage_logs` (per request) + `ai_usage_stats` (`global` + `day_YYYY-MM-DD`) + per-user lifetime totals |

The admin cost dashboard reads `ai_usage_stats` — **that AI number is real measurement**, unlike the
Firebase figures beside it, which are estimates. Per-user lookup queries `ai_usage_logs` by uid.

> Logging only happens through the proxy. Debug direct-key calls are invisible to cost tracking.

---

## 7. Prompt-injection prevention

User-controlled text reaches prompts from profile fields, food descriptions, chat messages, and
recipe constraints. `PromptService` fences all of it: delimited, explicitly declared as data, and
never concatenated into the instruction section.

Applied across ingredient validation, recipe generation, meal planning, and food analysis.

**Rule:** any new insertion point for user text goes through the guard. Assume every free-text field
contains `"ignore previous instructions"`.

---

## 8. Validation & failure handling

### Error hierarchy
| Exception | Meaning | Behaviour |
|---|---|---|
| `AIRetryableException` | Transient — timeout, 5xx, rate limit | Retry up to 3× |
| `AIQuotaExceededException` | HTTP 402 from the proxy | Surface the credits sheet; no retry |
| `AIJsonParseException` | Response wasn't the contracted shape | Retry once, then fail visibly |
| `AIFatalException` | Bad request, auth failure, no config | Abort, log, degrade |

### The degradation contract
Every AI feature **must** no-op cleanly when `AIService().isConfigured == false` — show a real
"unavailable" state. It must **never** substitute mock or hardcoded content. `BLK-01` was precisely
this contract being violated in release builds; the meal-plan and recipe paths now enforce it too.

Credits are rolled back server-side on a failed generation.

### Allergen safety — deterministic, not model-trusted
`utils/allergen_safety.dart` filters the candidate dish pool against the user's allergies and
avoid-list **before** the model sees it, and **refuses to generate at all** if nothing safe remains.
Unit-tested. This is defense in depth: the model is also told the restrictions, but is never the
control.

---

## 9. Known issues in this domain

| ID | Issue |
|---|---|
| `BLK-15` 🔥 | Live OpenRouter key bundled as a Flutter asset and shipped in CI artifacts |
| `S6` | Client direct-key fallback still present; App Check unenforced; no OpenRouter spend cap |
| `PERF-10` | `aiProxy` never load-tested under real concurrency (`scripts/load_test.js` exists, unrun) |
| `BE-07` | No API versioning on the proxy contract |
| — | 180-dish prompt ceiling caps meal-plan variety |
| — | Push/notification copy from Functions has no localization path |

---

## 10. Roadmap

**Near term (M1–M2)** — close `BLK-15`; enforce App Check; set a spend cap; load-test
the proxy; version the contract.

**Mid term** — per-type model routing to trade cost against quality (schema exists in
`app_config.ai.model_by_type`, unused); streaming responses for chat; a prompt-regression test set so
prompt edits are measurable rather than vibes.

**Long term** — behavioural analytics → ML pipeline (`AI-14`); on-device models for trivial
classification; retrieval over the dish catalog to break the 180-dish ceiling. Details:
[`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) §C.

---

## 11. Checklist for AI changes

See [`../AGENTS.md`](../AGENTS.md) §3.6. The five that matter most:

1. Does it degrade to a visible "unavailable" state, never to fabricated content?
2. Is all user text fenced?
3. Is the output parsed defensively and safety-filtered deterministically?
4. Is quota consumed server-side and rolled back on failure?
5. Is the call `type`-tagged so its cost is attributable?
