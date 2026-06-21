# 📜 COOKRANGE PROJECT-SPECIFIC RULES (v2.0)

These rules are hard constraints. All code changes MUST strictly adhere to them.

---

## 1. ARCHITECTURE & CONCERNS
- **Core/UI Separation**: UI logic lives in `lib/screens/` or `lib/widgets/`. Business/state logic belongs to services (`lib/core/services/`) or providers (`lib/core/providers/`).
- **Dependency Paths**: UI elements depend on Store/Providers, which communicate with Services. NEVER reference core business layers directly in UI widgets.
- **Firebase Integrations**: Call through `FirestoreService` or wrappers. Direct Firebase calls inside UI components are FORBIDDEN. Catch exceptions and report to `CrashlyticsService`.

---

## 2. CODING STANDARDS
- **Naming Conventions**:
  - Files: `snake_case.dart`
  - Classes/Types: `PascalCase`
  - Variables/Methods: `camelCase`
- **Performance Rules**:
  - Use `const` constructors wherever possible.
  - Never run computational or API logic directly inside a widget's `build()` function.

---

## 3. COMPONENT & FEATURE PROTOCOL
Every new screen or major component MUST implement the following five pillars:
1. **Logging**: Import and call `LogService` via `logActivity()` or standard level checks.
2. **Analytics**: Log screen views using `logScreenView()` and user choices with `logUserAction()`.
3. **Localization**: Never hardcode text. Translate UI content dynamically:
   `AppLocalizations.of(context).translate('key')`
4. **Theming**: Inherit styles from `ThemeProvider`. Reference dynamic themes:
   `context.watch<ThemeProvider>().primaryColor`
5. **Reusability**: Check `lib/core/services/` for existing utilities/models before writing duplicates.

---

## 4. UI & DESIGN RULES
- **Glass-morphism**: Use semi-transparent container cards, blurred background layouts (`BackdropFilter`), and smooth gradients.
- **Responsiveness**: Use `flutter_screenutil` scaling for size adjustments. Set:
  - Width: `.w`
  - Height: `.h`
  - Text: `.sp`
  - Radius: `.r`
- **Assets**: Prefer existing SVGs from `assets/icons/` or use `FontAwesomeIcons`.

---

## 5. DOCUMENTATION SYNCHRONIZATION
Whenever code changes add, modify, or delete features, services, or files, the agent MUST update the repository documentation:
- **`file_index.md`**: Must be synced immediately if files are created, renamed, or deleted, or if a module's responsibilities expand. Ensure no deleted feature remains listed.
- **`README.md`**: Must be updated if user-facing features, installation guidelines, environment variables, or dependencies are modified.
- **Protocol**: If doc edits are required, the Implementer Agent must generate diffs/patches for `file_index.md` or `README.md` as part of the execution phase.

---

## 6. DESIGN & DESIGN SYSTEM CONSISTENCY
To maintain visual and layout coherence across the application:
- **Style Coherence**: A new page or component MUST follow the exact design patterns, padding, border radius, color schemes, and fonts used by existing pages in `lib/screens/` and `lib/widgets/`.
- **Pre-execution Check**: The agent must inspect existing UI files in the workspace (using token-optimized targeted reads) to copy visual layout styles and widgets before constructing a new interface.
- **State Pattern Mirroring**: State access patterns (e.g. `context.watch<ThemeProvider>()` or `Provider.of<AppState>(context)`) must match the existing provider interaction style exactly. No ad-hoc state solutions are allowed.
