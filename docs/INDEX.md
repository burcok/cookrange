# docs/ — Documentation Index

The Cookrange knowledge base. Start at `../AGENTS.md` for *how to work*, then come here for
*where things are*. **Code is truth; if a doc drifts, fix the doc.**

| Doc | Covers | Owns these source paths |
|---|---|---|
| [`../ARCHITECTURE.md`](../ARCHITECTURE.md) | System layers, data flow, topology | whole `lib/` structure |
| [`DATA_MODEL.md`](DATA_MODEL.md) | Models, Firestore collections, indexes, rules, storage | `lib/core/models`, `lib/core/data`, `lib/core/repositories`, `firestore.*`, `storage.rules` |
| [`SERVICES.md`](SERVICES.md) | 75 services + 4 Cloud Functions | `lib/core/services`, `functions/index.js` |
| [`FRONTEND.md`](FRONTEND.md) | 95 screens, navigation, routing | `lib/screens`, `lib/main.dart`, routes |
| [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) | Tokens, components, motion, a11y | `lib/core/theme`, `lib/core/widgets/ds` |
| [`FEATURES.md`](FEATURES.md) | Feature catalog (what exists, where) | — (cross-cutting) |
| [`PLATFORM.md`](PLATFORM.md) | iOS/Android parity, native config, CI/CD | `android/`, `ios/`, `.github/workflows` |
| [`LOCALIZATION.md`](LOCALIZATION.md) | i18n system, how to add strings | `lib/core/localization`, `assets/localization` |
| [`firebase-console-setup.md`](firebase-console-setup.md) | Firebase Console one-time steps | — |
| [`roadmap/GO_LIVE.md`](roadmap/GO_LIVE.md) | Pre-launch / store submission roadmap | — |
| [`roadmap/FUTURE_FEATURES.md`](roadmap/FUTURE_FEATURES.md) | Missing & future features + per-feature roadmaps | — |
| [`generated/db-schema.md`](generated/db-schema.md) | Flat Firestore schema quick-reference | derived from `DATA_MODEL.md` |

**Also at root:** `CLAUDE.md` (rules R0–R9 + DoD) · `TODO.md` (status/roadmap) ·
`README.md` (product vision).
