# 🧠 MODULE DEPENDENCY GRAPH (v2.0)

This file defines the structural hierarchy of modules in the Cookrange codebase, used for impact analysis, safe refactoring, and dependency validation.

---

## 1. LAYER GRAPH HIERARCHY

The codebase is organized into four main vertical layers:

```text
    [ Presentation Layer ]
      UI Screens & Widgets (lib/screens/, lib/widgets/)
               ↓
    [ State Management Layer ]
      Providers (lib/core/providers/)
               ↓
    [ Infrastructure Services ]
      Services (lib/core/services/, lib/core/services/ai/)
               ↓
    [ Domain Logic & Models ]
      Data & Models (lib/core/models/, lib/core/data/)
```

---

## 2. LAYER DEPENDENCY RULES

### 2.1 USER INTERFACE (UI)
- **Allowed Imports**: `lib/core/providers/`, `lib/core/theme/`, `lib/core/localization/`, `lib/core/widgets/`.
- **FORBIDDEN Imports**:
  - `lib/core/services/` (Direct service manipulation from widgets is blocked).
  - Direct Firebase libraries (`package:cloud_firestore/...`).
  - Speculative utility packages not configured in `pubspec.yaml`.

### 2.2 STATE MANAGEMENT (PROVIDERS)
- **Allowed Imports**: `lib/core/services/`, `lib/core/models/`.
- **FORBIDDEN Imports**:
  - `lib/screens/` or `lib/widgets/` (State must be entirely decoupled from presentation).
  - Business logic calculations (must be routed to services/models).

### 2.3 INFRASTRUCTURE SERVICES
- **Allowed Imports**: `lib/core/models/`, `lib/core/data/`, `lib/core/utils/`.
- **FORBIDDEN Imports**:
  - `lib/core/providers/` (Services must be stateless relative to UI provider wrappers).
  - UI themes or localization contexts.

### 2.4 DOMAIN LOGIC & MODELS
- **Imports**: Pure Dart library packages, models, constants, and data wrappers only.
- **FORBIDDEN Imports**:
  - Anything from UI, Providers, or Services. This layer is the bedrock of the system and must remain compile-safe and stateless.

---

## 3. IMPACT ANALYSIS PROTOCOL
Before modifying any Dart file, the Planner and Validator must trace:
1. **Direct Impact**: The modified file itself.
2. **Upward Impact (Consumers)**: Locate all files that import this module. If changing a signature, all upstream files must be updated.
3. **Downstream Impact (Dependencies)**: Locate services or models imported by this module.

---

## 4. CRITICAL RULES
- **No Circular Imports**: If A imports B, B must never import A. Utilize interfaces or state providers to break cycles.
- **No UI Leaks**: Never pass UI widgets or navigation controllers into service structures.