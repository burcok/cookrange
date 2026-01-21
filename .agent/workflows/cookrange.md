---
description: Useful commands for Cookrange project development
---

# 🚀 Cookrange Commands

This workflow provides quick access to common development tasks for the Cookrange project.

### 🛠 Development Setup
// turbo
1. **Initialize Project**: Run this after cloning or dependencies change.
   ```bash
   flutter clean && flutter pub get && flutter pub run build_runner build --delete-conflicting-outputs
   ```

### 🧪 Quality & Tests
// turbo
2. **Analyze & Test**: Run lints and all tests.
   ```bash
   flutter analyze && flutter test
   ```

### 📦 Build & Release
// turbo
3. **Build Android (APK)**: Generate a release APK.
   ```bash
   flutter build apk --release
   ```

// turbo
4. **Build iOS (IPA)**: Generate a release IPA (requires Xcode/macOS).
   ```bash
   flutter build ipa --release
   ```

### 🧹 Maintenance
// turbo
5. **Clear Cache**: Fix weird build issues.
   ```bash
   flutter clean && rm -rf ios/Pods ios/Podfile.lock && cd ios && pod install && cd ..
   ```

### 🤖 Localization
// turbo
6. **Regenerate L10n**: Update localization files.
   ```bash
   flutter gen-l10n
   ```
