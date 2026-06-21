# 🛡️ ANTI-DRIFT GUARD (v3.0)

This safety subsystem prevents architectural drift, speculative redesigns, scope creep, and stale documentation.

---

## 1. ARCHITECTURAL IMMUTABILITY

The system layout is static. The agent must NEVER introduce:
- New layers not mapped in `file_index.md`.
- Unapproved dependencies (e.g. importing UI components in core models, or importing services directly in UI screens).
- Raw direct API or Firebase operations in UI widget trees (must utilize `lib/core/services/` wrappers).

---

## 2. REFACTOR AND SCOPE LIMITS

- **No Speculative Cleanup**: Refactoring working logic "for cleanliness" or "better styling" is forbidden unless the task explicitly commands a refactoring effort.
- **Simplest Working Path**: Prefer local, localized bug fixes and single-file additions over wide-scale module generalizations.
- **Single-Layer Scoping**: Avoid modifications that span multiple layers simultaneously. If a change touches both State and UI, split the task into distinct step-by-step patches.

---

## 3. DOCUMENTATION DRIFT PREVENTION
Failing to maintain documentation when the repository structure or features change is considered architectural drift:
- If a file is added, modified, renamed, or deleted, `file_index.md` MUST be updated in the same patch.
- If a feature is added, modified, or removed, both `file_index.md` and `README.md` MUST be updated.
- Leaving stale feature descriptions or dead paths in documentation files is a critical failure.

---

## 4. DESIGN DRIFT PREVENTION
- All UI changes must adhere strictly to the Glass-morphism design system rules in `agent_rules.md`.
- Any new screen or widget layout must mirror the style, spacing, theme provider integration, and helper widgets of existing views under `lib/screens/` and `lib/widgets/`. Divergent aesthetics are treated as drift.

---

## 5. SAFETY & DRIFT SELF-CHECK
Before final delivery, the Validator Agent must run these checks:
1. Was this exact modification requested by the user? (If NO → reject).
2. Does the edit cross module boundaries without permission? (If YES → reject).
3. Were new patterns or generic wrappers created? (If YES → reject).
4. Have all structural or feature changes been synchronized with `file_index.md` and `README.md`? (If NO → reject).
5. Does the layout design conform to existing screens in the codebase? (If NO → reject).