# FOKUS — Design System (Flutter theme token spec)

> Exact, implementation-ready. Target: `lib/core/theme/`. Every value here is a literal a
> developer can paste. Colors come from `BRAND.md §3`; this file is the machine-readable form.
> Material 3, `useMaterial3: true`.

Suggested file layout:
```
lib/core/theme/
  app_colors.dart      // both ColorSchemes (below)
  app_typography.dart  // TextTheme
  app_spacing.dart     // spacing + radii scales
  app_motion.dart      // durations + curves
  app_theme.dart       // assembles ThemeData light/dark + component themes
  app_components.dart   // shared component style helpers (progress ring etc.)
```

---

## 1. ColorScheme (Dart literals)

> **v2 palette (D-009):** blue/indigo dropped. Warm neutral base, light default, orange accent.
> Values below are the literal machine-readable form of `BRAND.md §3`.

```dart
// app_colors.dart
const lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: Color(0xFFC24A16),        onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFFFE4D2), onPrimaryContainer: Color(0xFF4A1B04),
  secondary: Color(0xFF5A6152),       onSecondary: Color(0xFFFFFFFF),
  secondaryContainer: Color(0xFFDDE7D0), onSecondaryContainer: Color(0xFF26301E),
  tertiary: Color(0xFF785A0B),        onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFFBEBC8), onTertiaryContainer: Color(0xFF4A3200),
  error: Color(0xFFB3261E),           onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),  onErrorContainer: Color(0xFF410E0B),
  surface: Color(0xFFFBF9F6),         onSurface: Color(0xFF22201D),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFAF7F2),
  surfaceContainer: Color(0xFFF5F2EC),
  surfaceContainerHigh: Color(0xFFEFEBE3),
  surfaceContainerHighest: Color(0xFFE9E4DA),
  surfaceVariant: Color(0xFFEAE4DA),  onSurfaceVariant: Color(0xFF55524C),
  outline: Color(0xFF84807A),         outlineVariant: Color(0xFFD6CFC3),
  surfaceTint: Color(0xFFC24A16),
  inverseSurface: Color(0xFF332F2A),  onInverseSurface: Color(0xFFF3EFE9),
  inversePrimary: Color(0xFFFFB68C),
  shadow: Color(0xFF000000),          scrim: Color(0xFF000000),
);

const darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFFFB68C),         onPrimary: Color(0xFF3A1600),
  primaryContainer: Color(0xFF7A3410), onPrimaryContainer: Color(0xFFFFDBC7),
  secondary: Color(0xFFBCCBAC),       onSecondary: Color(0xFF28331C),
  secondaryContainer: Color(0xFF3E4833), onSecondaryContainer: Color(0xFFDDE7D0),
  tertiary: Color(0xFFF2C24E),        onTertiary: Color(0xFF3A2B00),
  tertiaryContainer: Color(0xFF574200), onTertiaryContainer: Color(0xFFFBEBC8),
  error: Color(0xFFFFB4AB),           onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),  onErrorContainer: Color(0xFFFFDAD6),
  surface: Color(0xFF20201E),         onSurface: Color(0xFFECE7E0),
  surfaceContainerLowest: Color(0xFF161513),
  surfaceContainerLow: Color(0xFF201F1D),
  surfaceContainer: Color(0xFF242320),
  surfaceContainerHigh: Color(0xFF2E2C28),
  surfaceContainerHighest: Color(0xFF383530),
  surfaceVariant: Color(0xFF3A382F),  onSurfaceVariant: Color(0xFFCFC8BF),
  outline: Color(0xFF9A968E),         outlineVariant: Color(0xFF3A382F),
  surfaceTint: Color(0xFFFFB68C),
  inverseSurface: Color(0xFFECE7E0),  onInverseSurface: Color(0xFF332F2A),
  inversePrimary: Color(0xFFC24A16),
  shadow: Color(0xFF000000),          scrim: Color(0xFF000000),
);
```

Non-scheme brand extras (put on a `ThemeExtension<FokusColors>`):
```dart
// gradients + rationed signals not expressible as single ColorScheme roles
focusGradient  = LinearGradient([Color(0xFFFF7A30), Color(0xFFE8611F)], 135°)  // ember
calmWash       = LinearGradient([Color(0xFF8FA07E), Color(0xFFB7C3A5)], 160°)  // sage, recovery
streakSignal   = light Color(0xFF785A0B) / dark Color(0xFFF2C24E)   // warm-gold streak
ringTrack      = surfaceVariant   // unfilled part of progress ring
scrimIntercept = scrim @ 0.55 opacity
// On light surfaces the progress-ring arc falls back to solid Rust Color(0xFFC24A16)
// where the ember gradient would drop below AA against Paper.
```

---

## 2. Typography — TextTheme

Family: **Plus Jakarta Sans** (bundled). `fontFamily: 'PlusJakartaSans'`. Countdown uses
`fontFeatures: [FontFeature.tabularFigures()]`.

| Style | Size (sp) | Weight | Line-height | Tracking | Use |
|---|---|---|---|---|---|
| `displayLarge` | 57 | 700 | 1.12 | -0.5 | rarely; big celebration number |
| `displayMedium` | 45 | 700 | 1.16 | 0 | — |
| `displaySmall` | 36 | 600 | 1.22 | 0 | section hero |
| **`countdown`** (custom) | 72 | 600 | 1.0 | -1.0 | active-session timer, tabular figures |
| `headlineLarge` | 32 | 700 | 1.25 | 0 | screen titles (celebration) |
| `headlineMedium` | 28 | 600 | 1.29 | 0 | screen titles |
| `headlineSmall` | 24 | 600 | 1.33 | 0 | card headers, module titles |
| `titleLarge` | 22 | 600 | 1.27 | 0 | app bar, dialog titles |
| `titleMedium` | 16 | 600 | 1.5 | 0.15 | list item titles, buttons(large) |
| `titleSmall` | 14 | 600 | 1.43 | 0.1 | chips, overlines |
| `bodyLarge` | 16 | 400 | 1.5 | 0.15 | primary body, recovery copy |
| `bodyMedium` | 14 | 400 | 1.43 | 0.1 | default body |
| `bodySmall` | 12 | 400 | 1.33 | 0.2 | captions, timestamps |
| `labelLarge` | 14 | 600 | 1.43 | 0.1 | button text |
| `labelMedium` | 12 | 600 | 1.33 | 0.2 | small button/tab |
| `labelSmall` | 11 | 600 | 1.45 | 0.3 | badges |

Rules:
- Text scale: honor OS `textScaleFactor` up to 1.3× without clipping (test every screen at 1.3×).
- Countdown is the only place tracking goes to -1.0; everything else ≥ 0 for DE legibility.
- Max line length for body copy: ~40 chars (recovery), ~60 (settings) — keeps calm.

---

## 3. Spacing scale (8pt base, with 4 half-step)

```dart
// app_spacing.dart  — name: value(dp)
space.xxs = 4    space.xs = 8    space.sm = 12   space.md = 16
space.lg = 24    space.xl = 32   space.xxl = 48  space.xxxl = 64
screenPadding = 20   // default horizontal screen inset (roomier than M3 16 = premium/calm)
sectionGap = 32      // between major blocks
cardPadding = 20
minTouchTarget = 48  // enforced on every interactive element (spec §4)
```
Whitespace is a feature. When in doubt, add one step. Recovery screens use +1 step everywhere.

---

## 4. Radii scale

```dart
// app_spacing.dart
radius.xs = 8      // chips, small tags
radius.sm = 12     // buttons, text fields, small cards
radius.md = 16     // standard cards
radius.lg = 24     // large cards, bottom sheets (top corners)
radius.xl = 32     // hero cards, celebration card, recovery module container
radius.full = 999  // pills, FAB, avatar, chips (stadium)
```
Global default corner language is soft. Nothing sharper than `radius.xs`. Bottom sheets: top
corners `radius.lg`. The progress ring is a true circle (not in this scale).

---

## 5. Elevation policy

Dark theme leans on **surface tint tiers**, not shadow (shadows disappear on dark anyway).
Light theme uses **soft, low shadows** + tint. No harsh Material default shadows.

| Level | Light | Dark |
|---|---|---|
| 0 flat | `background` | `background` |
| 1 card resting | `surfaceContainerLow` + shadow y2 blur8 @6% | `surfaceContainerLow`, no shadow |
| 2 card raised / app bar scrolled | `surfaceContainer` + shadow y4 blur12 @8% | `surfaceContainer` |
| 3 sheets, dialogs | `surfaceContainerHigh` + shadow y8 blur24 @10% | `surfaceContainerHigh` |
| 4 menus, FAB pressed | `surfaceContainerHighest` + shadow y12 blur32 @12% | `surfaceContainerHighest` |

Shadow color: `shadow` (black) at the listed low alpha only. Never a colored shadow.
The intercept & recovery overlays use a full-screen `scrim @ 0.55` beneath the content card.

---

## 6. Motion tokens

```dart
// app_motion.dart
class FokusMotion {
  static const instant   = Duration.zero;
  static const quick     = Duration(milliseconds: 120);
  static const base      = Duration(milliseconds: 240);
  static const calm      = Duration(milliseconds: 400);
  static const breath    = Duration(milliseconds: 4000);
  static const celebrate = Duration(milliseconds: 700);

  static const curveQuick     = Curves.easeOutCubic;
  static const curveBase      = Curves.easeInOutCubic;
  static const curveCalm      = Curves.easeOutCubic;
  static const curveBreath    = Curves.easeInOutSine;
  static const curveCelebrate = Curves.easeOutBack; // clamp overshoot visually ≤1.05
}
```
Page transitions: `SharedAxisTransition` (horizontal) at `calm` for forward nav; fade-through
at `base` for tab/root swaps. Reduced-motion: all → fade at `base`; breath → opacity pulse.

---

## 7. Component styles

### 7.1 Buttons (all min height 48 dp, target ≥ 48×48)

| Variant | Fill | Text | Radius | Use |
|---|---|---|---|---|
| **Primary** (`FilledButton`) | `primary`, focus-gradient allowed on the single hero CTA per screen | `onPrimary` | `sm` (12) | main action ("Start focus", "Return to focus") |
| **Secondary** (`FilledButton.tonal`) | `secondaryContainer`/`primaryContainer` | `on*Container` | `sm` | "I'm stuck", alt actions |
| **Text** (`TextButton`) | none | `primary` | `sm` | low-emphasis |
| **Emergency exit** (`TextButton`) | none | `onSurfaceVariant` | `sm` | de-emphasized, **never hidden** — see §8 |
| **Icon** (`IconButton`) | 48×48 hit box, 24 icon | `onSurfaceVariant` | `full` | nav, close |

Button padding: `horizontal 24, vertical 14`. Label: `labelLarge`. Pressed: overlay `onColor @8%`
+ scale 0.98 at `quick`. Disabled: `onSurface @38%` fill/text (M3 standard).
Full-width primary CTAs on session/onboarding screens (thumb-reachable, bottom-anchored).

### 7.2 Cards

`Card` = `surfaceContainerLow` (resting), radius `md` (16), padding `cardPadding` (20), elevation
level 1. Tappable cards get an `InkWell` with `radius.md` splash and 48 dp min height.
Hero cards (home "Start"/"Repeat", celebration): radius `xl` (32), elevation 2, may host the
focus-gradient as a subtle top-edge accent (never full-bleed behind text).

### 7.3 Progress ring (the signature component)

- A `CustomPaint` circle, **stroke 10 dp** (12 on the active-session hero, 6 on small stat
  rings), `StrokeCap.round`.
- **Track:** `surfaceVariant`. **Progress arc:** `focusGradient` (SweepGradient), starting at
  **-90° (12 o'clock)**, sweeping clockwise.
- The signature: the ring is drawn as **345° of arc with a 15° gap at top** even at "full" —
  mirroring the logotype's broken-O. As the session completes, the arc fills toward the gap;
  at 100% a soft warm-gold pulse (`celebrate`) closes the gap momentarily then it re-opens (focus
  is a state you re-enter). Recovery breathing reuses the ring geometry with `calmWash` (sage).
- Animate progress with `base` when a value changes; the second-by-second countdown updates the
  angle continuously via an `AnimationController` synced to `endEpochMs` (wall-clock, not ticks).

### 7.4 Chips

Choice chips (durations, app filter): stadium (`radius.full`), height 40 (hit box padded to 48),
`labelLarge`. Selected: `secondaryContainer` fill + `onSecondaryContainer` text + 1.5 dp
`primary` ring. Unselected: `surfaceContainerHigh` fill, `onSurfaceVariant` text. Toggle at
`quick`.

### 7.5 Text fields (task anchor, task-reset)

`OutlinedInputBorder` radius `sm`, `surfaceContainerLow` fill, `outlineVariant` border → `primary`
2 dp on focus. Counter for the 80-char anchor. Calm placeholder copy, never all-caps.

### 7.6 Status badge (permissions health)

Pill (`radius.full`), `labelMedium`. States:
`Active` = `secondaryContainer`/check · `Action needed` = `tertiaryContainer`/alert (amber, not
red — it's guidance, not failure) · `Inactive/limited` = `surfaceVariant`/dot ·
`Error` (permission lost mid-session) = `errorContainer`/alert (this one *is* red).

### 7.7 Bottom sheet / dialog

Sheet: top radius `lg` (24), `surfaceContainerHigh`, drag handle 32×4 `outlineVariant`, content
padding `lg`. Recovery "Ready to continue?" is a sheet, not a full route (keeps session context
visible behind scrim). Dialogs: radius `lg`, used sparingly (strict-mode consequences).

### 7.8 Snackbar / toast

`inverseSurface`/`onInverseSurface`, radius `sm`, single line, `base` in. Used for "Preset saved",
"5-minute pass active". Never for anything the user must act on.

---

## 8. Emergency-exit component (policy-bound, spec §2.3)

A single reusable widget `EmergencyExitButton`. **Always rendered** on intercept + exit + strict
consequence screens. Style: `TextButton`, `onSurfaceVariant` text, no fill, placed at screen
bottom with `space.lg` separation from primary actions. It is visually quiet but **passes AA
contrast and is ≥ 48 dp** — de-emphasized, never hidden, never disabled, never behind a
confirm-hold trap. Label EN "Emergency exit" / DE "Notausgang". One tap to reveal the exit
reasons; "emergency" reason exits immediately with no lecture and no streak penalty (spec §3.4).

---

## 9. Iconography implementation

Bundle a custom stroked icon set (2 dp, round caps/joins, 2 dp corners) as an icon font or SVG
assets in `assets/icons/`. Do not use raw `Icons.*` at default weight for primary UI; if using
Material Symbols, configure `weight 300, grade 0, opticalSize 24, rounded` to match brand. The
FOKUS ring mark is the app's loading spinner (rotating broken ring, `calm`× loop).
