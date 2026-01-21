# 🏗 Project Standards

Guidelines for architecture and coding in the Cookrange project.

- **Architecture**: Strict "Core/UI" separation. Logic in `lib/core/services/`, UI in `lib/screens/` or `lib/widgets/`.
- **Firebase**: Use `FirestoreService` or specific service wrappers. No direct Firebase calls in widgets.
- **State Management**: Use `Provider`. 
- **Coding Style**:
    - Classes: `PascalCase`
    - Variables/Functions: `camelCase`
    - Files: `snake_case`
- **Performance**: Use `const` constructors and avoid heavy logic in `build()` methods.
- **Error Handling**: Catch and report errors to `CrashlyticsService`.
