# 🧠 REPOSITORY INTELLIGENCE INDEX (v2.0)

This file is the single source of truth for codebase layout and navigation. The AI must always consult this file before reading or editing any files.

---

## 1. SYSTEM OVERVIEW
Cookrange is a Flutter application.
- **Core Purpose**: Personalized nutrition planning, meal generation, grocery lists, and user preference tracking.
- **Development Language**: Dart (Flutter SDK).

---

## 2. SYSTEM MODULES & LAYOUT

### 2.1 APP ENTRYPOINT
- **Location**: `lib/main.dart`
- **Responsibilities**: App initialization, global providers setup, root theme configuration, and routing bootstrap.

### 2.2 CORE MODELS & DATA
- **Location**: `lib/core/models/` and `lib/core/data/`
- **Responsibilities**: Pure data models (e.g. user, meal, recipe data objects) and static/mock seed data.
- **Rule**: Pure Dart logic only. No UI or Firebase imports.

### 2.3 STATE MANAGEMENT (PROVIDERS)
- **Location**: `lib/core/providers/`
- **Responsibilities**: Application state, user state, and UI states powered by the `Provider` library.
- **Rule**: Connects services to the UI. Do not execute direct networking or raw database operations here.

### 2.4 BUSINESS SERVICES
- **Location**: `lib/core/services/`
- **Responsibilities**: External communications, data operations, and core logic.
  - **Authentication**: `auth_service.dart`
  - **Meal Operations**: `weekly_meal_plan_service.dart`, `recipe_generation_service.dart`, `dish_service.dart`
  - **Database & Storage**: `firestore_service.dart`, `storage_service.dart`
  - **AI Engines**: `lib/core/services/ai/` (orchestrates `ai_service.dart` and `prompt_service.dart`)
  - **Logging & Crashlytics**: `log_service.dart`, `crashlytics_service.dart`
- **Rule**: Strictly no UI dependencies.

### 2.5 USER INTERFACE (UI)
- **Location**: `lib/screens/` (views/pages) and `lib/widgets/` (reusable components)
- **Responsibilities**: Layout styling, glass-morphism panels, input forms, and page routing transitions.
- **Rule**: Strictly no business logic or direct API/Firebase calls. Consume state via `Provider`.

### 2.6 LOCALIZATION, THEME, & CONSTANTS
- **Locations**: `lib/core/localization/`, `lib/core/theme/`, `lib/core/constants/`, and `lib/constants.dart`
- **Responsibilities**: Text translations, dark/light styling theme definitions, and global constants.

---

## 3. DEPENDENCY & SAFETY BOUNDARIES
Strict hierarchy MUST be respected to prevent architectural drift:
```text
UI (lib/screens/, lib/widgets/)
  ↓
Providers (lib/core/providers/)
  ↓
Services (lib/core/services/)
  ↓
Models/Data (lib/core/models/, lib/core/data/)
```
- **Forbidden Dependencies**:
  - UI Screen → Core Service direct calls (must route through Providers if stateful).
  - UI Screen → Direct Firebase API calls.
  - Services/Models → UI Widget imports (UI code must be pure presentation).
  - Circular Imports (e.g., Services importing Providers).