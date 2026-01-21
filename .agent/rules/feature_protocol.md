# 🚀 Mandatory Feature Protocol

Every new feature or screen **MUST** include these five pillars:

1.  **📝 Logging**: Use `LogService()` for activity (`logActivity`) and info.
2.  **📊 Analytics**: Mandatory `logScreenView()` and `logUserAction()` on all interactions.
3.  **🌍 Localization**: No hardcoded strings. Use `AppLocalizations.of(context).translate()`.
4.  **🎨 Theming**: Use `context.watch<ThemeProvider>().primaryColor` and the Glass-morphism design system.
5.  **🏗 Reuse**: Reuse existing services from `lib/core/services/` instead of rewriting logic.
