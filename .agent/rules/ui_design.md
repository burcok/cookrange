# 🎨 UI & Design Rules

Rules for maintaining the Cookrange aesthetic.

- **Design System**: Glass-morphism. Use blur effects and semi-transparent containers.
- **Responsiveness**: Mandatory `flutter_screenutil` usage for all dimensions (`.w`, `.h`, `.sp`, `.r`).
- **Colors**: Never hardcode colors. Use the dynamic `primaryColor` from `ThemeProvider`.
- **Typography**: Follow the defined styles in `lib/core/theme/app_theme.dart`.
- **Icons**: Use `FontAwesomeIcons` or existing SVGs from `assets/icons/`.
