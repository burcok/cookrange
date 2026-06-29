# LOCALIZATION.md — i18n System

> Cookrange ships **EN + TR** in strict parity, enforced by a CI test. Every user-visible string
> must exist in **both** files in the same change. Owner: `lib/core/localization/`,
> `assets/localization/{en,tr}.json`, `test/i18n_parity_test.dart`.

---

## 1. How it works
- **`AppLocalizations`** (`app_localizations.dart`) loads `assets/localization/{en|tr}.json` into a
  nested map. `supportedLocales = [en, tr]`; non-tr falls back to en.
- **Access:** `AppLocalizations.of(context).translate('screen.section.element')`.
  - Dot-path navigates the nested JSON; missing key returns the key (debug-logged).
  - Variables: `translate('key', variables: {'name': x})` replaces `{name}` in the value.
  - Arrays: `translateArray('key')` returns `List<String>`.
- **Locale state:** `LanguageProvider` (persists `language_code` in SharedPreferences; defaults to
  device language tr→tr else en). Settings has a language picker sheet (EN/TR with flag + checkmark).
- ~**2,082** keys across ~65 top-level sections (splash, onboarding, auth, home, community, gym,
  coach, ai, admin, …).

## 2. Adding a string (the ONLY correct way — R9)
**Never** edit the JSON with `sed` or a raw patch (silent key-loss risk). Always a sequential
Python `load → mutate → dump`, EN first then TR:

```python
import json
for lang, value in [('en','English text'), ('tr','Türkçe metin')]:
    p = f'assets/localization/{lang}.json'
    with open(p, encoding='utf-8') as f: d = json.load(f)
    d.setdefault('screen', {}).setdefault('section', {})['element'] = value
    with open(p, 'w', encoding='utf-8') as f:
        json.dump(d, f, indent=2, ensure_ascii=False); f.write('\n')
```

- Key naming: `screen.section.element` (e.g. `settings.account.change_email`).
- If two agents add keys in parallel, **serialize** them (one shared file owner per turn).
- Both files must end up with the **identical key set** and **no empty values**.

## 3. The CI gate — `test/i18n_parity_test.dart`
Two assertions:
1. `en.json` and `tr.json` have the **same flattened key set** (fails with a diff if not).
2. **No value is an empty string** in either file.

Run after every localization change:
```bash
flutter test test/i18n_parity_test.dart
```
This gates PRs — a divergence or empty string fails CI.

## 4. Notifications are localized at render time
Never store display text in a notification. `NotificationService.sendNotification(...)` stores
structured data; `NotificationPresenter` renders title/body from `notifications.feed.*` keys on the
**reader's** device, so it's always in their language with the real actor name. Add new notification
copy as `notifications.feed.*` keys (EN+TR) using `{actor}`/`{emoji}`/`{days}` vars.

## 5. Adding a new locale (future)
Infra is ready. To add e.g. German: drop `assets/localization/de.json` (full parity), add
`Locale('de')` to `supportedLocales` + the delegate's `isSupported`, handle the code in
`AppLocalizations.load` and `LanguageProvider`, and extend the parity test to the new file.
Currently a product decision keeps it EN+TR; the Settings picker is already a scalable sheet.
