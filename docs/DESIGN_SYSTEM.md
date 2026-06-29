# DESIGN_SYSTEM.md — Tokens, Components, Motion, A11y

> **Read this before writing or restyling ANY UI.** Never hand-roll a `Container`/
> `ElevatedButton`/hex color when a token or component exists. One import gives you everything:
> `import 'package:cookrange/core/widgets/ds/ds.dart';`
> Owners: `lib/core/theme/**` (tokens), `lib/core/widgets/ds/**` (components).
> Design direction: **"Sunset Energy"** — warm orange brand + cool teal accent, soft shadows,
> rounded radii, glassmorphism for premium surfaces, mesh-glow depth, 60fps motion.

---

## 1. Tokens

### AppPalette — `app_palette.dart` · `AppPalette.of(context)` / `context.palette`
Theme-aware semantic roles (resolve per brightness). **Never use raw hex in UI.**

**Brand (static):** `brand` #F97300 · `brandSoft` #FFB266 · `sunsetA/B/C` (gradient stops) ·
`energyLight` #0FB9A6 · `energyDark` #2DD4BF.

**Surfaces:** `background` · `surface` · `surfaceVariant` · `surfaceElevated`.
**Text:** `textPrimary` · `textSecondary` · `textTertiary` · `textInverse`.
**Lines:** `border` · `divider`.
**Status:** `success` · `warning` · `error` · `info`.
**Macros:** `protein` (blue) · `carbs` (amber) · `fat` (purple) · `calories` (orange).
**Dynamic:** `energy` · `energySoft` · `shadow` · `scrim` · `shimmerBase` · `shimmerHighlight`.
**Glass:** `glassFill` (70%/55%) · `glassStroke` · `glassHighlight` · blur sigmas
`glassBlurSubtle` 8 · `glassBlurDefault` 16 · `glassBlurStrong` 28.

> Live brand color: `ThemeProvider.primaryColor` (user-customizable, default `brand`).
> Migrating legacy: `Color(0xFF2E3A59)` → `textPrimary`, `Color(0xFF0D1117)` → `background`,
> white cards → `surface`.

### AppText — `app_typography.dart` · `AppText.of(context)` (Poppins, sizes in `.sp`)
`displayL` 40/800 · `displayM` 34/800 · `headlineL` 26/bold · `headlineM` 22/bold ·
`headlineS` 18/700 · `titleL` 16/600 · `titleM` 14/600 · `bodyL` 15/400 · `bodyM` 13/400 ·
`labelL` 15/600 · `labelM` 13/500 · `labelS` 11/500 · `overline` 11/700 (all-caps eyebrow).

### AppSpacing / AppRadius / AppSize / AppElevation — `app_dimensions.dart`
Design-px; apply `.r/.w/.h` at call site.
- **AppSpacing:** xxxs 2 · xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32 · xxxl 48 ·
  `screenH` 20 · `screenV` 16.
- **AppRadius:** xs 6 · sm 10 · md 14 · lg 18 · xl 24 · xxl 32 · `full` 999 · `card` 20 ·
  `sheet` 28 · `button` 14 · `input` 14.
- **AppSize:** `touchTarget` 48 · icon xs/sm/md/lg/xl = 14/18/22/28/36 · avatar sm/md/lg/xl =
  32/44/64/96 · `buttonHeight` 52 (sm 40) · `fabSize` 56 · sheet handle 36×4.
- **AppElevation:** blur sm/md/lg = 8/16/28 · opacity light/medium/strong = .06/.10/.18 ·
  offsets sm/md/lg = (0,2)/(0,6)/(0,12).

### AppMotion — `app_dimensions.dart`
**Durations:** `instant` 120ms · `fast` 200ms · `normal` 320ms · `slow` 480ms · `ambient` 1200ms.
**Curves:** `standard` easeOutCubic · `emphasized` easeOutBack · `decelerate` easeOut ·
`accelerate` easeIn · `spring` elasticOut.

### AppGradients — `app_gradients.dart`
`brand(primary)` warm linear · `brandSoft(primary,{dark})` subtle wash · `energy(palette)` cool ·
`ring(primary)` sweep (calorie ring) · `meshGlow(palette, primary)` → List<Widget> of 2 radial
blobs (Stack behind content for depth).

---

## 2. Components — `lib/core/widgets/ds/` (barrel: `ds.dart`)

| Component | File | Use it for |
|---|---|---|
| **AppButton** | `app_button.dart` | All buttons. Variants: `primary`/`secondary`/`tonal`/`ghost`/`destructive`. Sizes: small 40 / medium 46 / large 52. Built-in `loading` spinner, `icon`/`trailingIcon`, `expand`, press-scale + haptics, disabled 45% opacity. |
| **AppCard** | `app_card.dart` | Standard surface. `onTap` (press-scale + haptic), `bordered`, `elevated` (soft shadow), `radius`, `semanticLabel`. |
| **AppGlassCard** | `app_card.dart` | Premium frosted surface (`BackdropFilter` + glass tokens + inner highlight). **A11y:** solid `surface` fallback when high-contrast/reduce-transparency. |
| **AppSheet** | `app_sheet.dart` | THE bottom sheet. `AppSheet.show<T>(context, child, title)`. Handle, blurred scrim, 350/260ms, safe-area + keyboard aware. A11y: opaque scrim + zero-duration on reduce settings. |
| **AppShimmer / AppSkeleton\*** | `app_shimmer.dart` | Loading. `AppSkeletonList`, `AppSkeletonMealCard`, `AppSkeletonStatGrid`, `AppSkeletonChart`, `AppSkeletonBox`. Ambient shimmer; `ExcludeSemantics`. **No bare spinners.** |
| **AppEmptyState** | `app_state_views.dart` | Empty. `icon`, `title`, `message`, optional `actionLabel`/`onAction`. Fade+scale entrance, `compact` mode, liveRegion. |
| **AppErrorState** | `app_state_views.dart` | Error. `title` (**required**), `message`, `onRetry`. Logs to debug console in debug mode. |
| **AppSnackBar** | `app_snackbar.dart` | Toasts. `.success/.error/.warning/.info(context, msg)` or `.show(...)` with action. Floating, colored icon, auto-hides previous. |
| **AppTextField** | `app_text_field.dart` | Inputs. Label, hint, error, helper, password toggle, formatters, prefix/suffix, multiline. Filled bg, 1.5px→2px focus border (primary, error-aware). |
| **AppTransitions** | `app_transitions.dart` | Route anims: `slideUp` / `slideRight` / `fade` / `fadeScale`. |
| **AppSegmentedControl** | `app_selectors.dart` | iOS-style segmented (2–5 labels), sliding pill. |
| **AppChipPicker\<T>** | `app_selectors.dart` | Single/multi chip selection (`AppChipOption`). |
| **AppToggle** | `app_selectors.dart` | Switch, optional label + description. |
| **AppCalorieRing** | `app_calorie_ring.dart` | Animated sweep-gradient calorie ring; center readout; glow; semantic value. |
| **AppInitialsAvatar** | `app_avatar.dart` | Avatar w/ photo or deterministic initials + hue from name; cached, fade-in. |
| **PermissionPrimer** | `permission_primer.dart` | Pre-OS-dialog rationale sheet (`PermissionPrimer.show` → bool). Precede every cold permission. |

---

## 3. Motion Rules
- Use `AppMotion` durations + curves, `AnimationController` or implicit animations
  (`AnimatedContainer`, `AnimatedOpacity`, `TweenAnimationBuilder`).
- Target **60fps**; no jank, no abrupt jumps. Outgoing = `accelerate`, incoming = `decelerate`,
  emphasis = `emphasized`/`spring`, ambient loops = `ambient`.
- Wrap heavy animated widgets in `RepaintBoundary`.
- Respect **reduce-motion** (collapse durations to zero) via `accessibility_utils.dart`.

## 4. Accessibility — `lib/core/utils/accessibility_utils.dart`
- `isHighContrast(context)` / `reduceTransparency(context)` → glass uses solid `surface` fallback
  (no blur).
- `reduceMotion(context)` → animations snap (Duration.zero).
- Interactive surfaces carry semantic labels; decorative blobs/shimmer use `ExcludeSemantics`;
  empty/error states use `liveRegion`.
- Min touch target = `AppSize.touchTarget` (48).

## 5. Theming Plumbing
- `ThemeProvider` → `ThemeMode` (light/dark) + `primaryColor` (live brand, persisted to prefs +
  Firestore).
- `AppTheme.lightTheme(primaryColor)` / `darkTheme(primaryColor)` in `app_theme.dart`.
- Every new surface must be correct in **both** themes. No hardcoded colors — `AppPalette` only.

---

## 6. Quick "How do I…" Recipes
- **A card?** `AppCard(child: …)` — premium? `AppGlassCard`.
- **A button?** `AppButton(label, onPressed, variant, size)`.
- **A modal?** `AppSheet.show(context: …, title: …, child: …)`.
- **A loading list?** `const AppSkeletonList()` (or meal/stat/chart variant).
- **Empty/error?** `AppEmptyState(...)` / `AppErrorState(title: …, onRetry: …)`.
- **A toast?** `AppSnackBar.success(context, '…')`.
- **Spacing?** `SizedBox(height: AppSpacing.md.h)`. **Radius?** `BorderRadius.circular(AppRadius.card.r)`.
- **Text?** `Text('…', style: AppText.of(context).titleM)`.
- **Color?** `AppPalette.of(context).textPrimary` (never a hex literal).
- **Background depth?** `Stack(children: [...AppGradients.meshGlow(palette, primary), content])`.
