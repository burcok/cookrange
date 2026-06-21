# 🧠 TASK ROUTER ENGINE (v2.0)

This system classifies incoming user requests and routes them into the correct execution pipeline. No code generation occurs at this stage.

---

## 1. TASK CLASSIFICATION MATRIX

### 1.1 BUG FIX
- **Trigger**: Error reports, unexpected behavior, failing tests, or stack traces.
- **Routing**: Minimal patch mode. Direct edit on the single buggy file.
- **Target**: Isolated code block under `lib/`.

### 1.2 FEATURE IMPLEMENTATION
- **Trigger**: Requests for new UI screens, new services, or additional logical capabilities.
- **Routing**: Controlled incremental build.
- **Target**: Providers (`lib/core/providers/`) and UI Screen/Widget additions.

### 1.3 REFACTOR
- **Trigger**: Code duplication, performance cleanups, or code style alignment requests.
- **Routing**: Refactor mode.
- **Target**: `lib/core/services/` or `lib/core/models/`. No behavior changes allowed.

### 1.4 DEBUG / INVESTIGATION
- **Trigger**: "Why is X happening", log analysis, or architecture exploration.
- **Routing**: Analysis mode. No file edits allowed.

---

## 2. RISK LEVELS
- **LOW**: Leaf node UI styling changes, documentation, or minor typos.
- **MEDIUM**: Adding screens, editing single local services, or adding state providers.
- **HIGH**: Editing central databases (`firestore_service.dart`), modifying authentication (`auth_service.dart`), or refactoring app bootstrap (`main.dart`). Requires explicit confirmation.

---

## 3. OUTPUT ROUTER CONTRACT
The router must output:
```json
{
  "task_type": "BUG | FEATURE | REFACTOR | DEBUG",
  "risk_level": "LOW | MEDIUM | HIGH",
  "target_modules": [
    "lib/core/services/auth_service.dart"
  ],
  "context_instructions": "Specify which dependency levels are required"
}
```