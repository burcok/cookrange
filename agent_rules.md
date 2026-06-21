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

---

## 7. UX/UI KEY LAYOUTS & DESIGN SYSTEM (HARD CONSTRAINTS)
To ensure absolute layout and typography consistency across all screens:
- **Typography & Fonts**:
  - **Poppins**: MUST be used for all headers, titles, navigation items, page labels, and major section titles (`fontFamily: 'Poppins'`).
  - **Lexend**: MUST be used for body text, paragraphs, onboarding options, input fields, statistics, and numerical values (`fontFamily: 'Lexend'`).
- **Back Button**:
  - **Location**: Top-left corner of all sub-pages, detail screens, or secondary views.
  - **Component**: MUST use the custom `CustomBackButton` widget (defined in `lib/widgets/custom_back_button.dart`), which wraps `Icons.arrow_back` with `secondaryColor` and size 28.
- **Navigation Bar (Navbar)**:
  - **Location & Component**: Main navigation bar is anchored to the bottom of the screen, integrated directly inside the custom draggable glassmorphic `QuickActionsSheet` (`DraggableScrollableSheet`).
  - **Tabs Layout**:
    - **Left Side**: Home tab (`Icons.home` / `Icons.home_outlined`).
    - **Right Side**: Community tab (`Icons.people` / `Icons.people_outline`).
    - **Pull Handle**: A draggable grab-bar handle (`_buildHandle()`) at the top center of the sheet allows the user to swipe up to reveal other options.
- **Menu / Drawer Button**:
  - **Location**: Top-left corner of the `MainHeader` on primary/main screens.
  - **Component**: A standard menu button (`Icons.menu`, size 28, color: black) that triggers `context.read<NavigationProvider>().toggleMenu(true)` to slide open the glassmorphic `SideMenu` from the left.
- **Floating Assistant FAB (Voice Assistant)**:
  - **Location**: Positioned exactly in the center of the bottom navigation bar, overflowing the top edge of the `QuickActionsSheet`.
  - **Icon & Action**: Uses `Icons.graphic_eq` (size 36) on a circular orange-gradient button that opens the `VoiceAssistantOverlay`.

---

## 8. AI RULES OPTIMIZATION PROTOCOL
When implementing new features, the agent must continuously adapt and optimize the AI guidelines:
- **Context Preservation**: The agent must read `agent_rules.md` at the start of any feature implementation.
- **Rule Evolution**: If a new feature introduces core changes (e.g., local storage mechanisms, payment flows, database schema changes), the agent MUST update `agent_rules.md` to document the concrete layout constraints and design choices of the newly introduced modules.
- **Rule Optimization**: Periodically check for rule redundancies, token inefficiencies, or outdated dependencies (e.g. ensuring we do not suggest deprecated features), and modify this file to reflect the updated state.
- **Compliance Guard**: Prior to declaring a task completed, the agent must validate the newly written code against the rules in this document. Any deviation is considered a build blocker.

---

## 9. REFRESH MECHANISMS & SCROLL DAMPENING
To provide a smooth, interactive experience and keep data updated:
- **Mandatory Refresh**: Every primary or secondary page displaying dynamic lists or data that can change (e.g., Home, Community Feed, Chat List, Notifications, Shopping List) MUST implement a pull-to-refresh mechanism.
- **Component Reuse**: For visual and architectural consistency, screens MUST use the custom `GlassRefresher` widget (defined in `lib/screens/community/widgets/glass_refresher.dart`) rather than duplicating the custom pull-to-refresh painting logic.
- **Physics Enforcement**: The scrollable widget wrapped by `GlassRefresher` (such as `ListView`, `SingleChildScrollView`, or `CustomScrollView`) MUST use bouncing physics to guarantee that pull-to-refresh functions on all screen sizes, even when the content is short:
  `physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())`
- **Asynchronous Reloading**: The `onRefresh` callback provided to `GlassRefresher` must trigger asynchronous calls to update the state from providers/services (e.g., calling `refreshUser()`, fetching weekly plans, or re-querying Firestore). It must show the loading indicator during the process and properly close/stop the animation upon completion or timeout.
