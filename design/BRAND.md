# FOKUS — Brand Identity

> The design north star. Every screen, asset, and animation traces back to the decisions here.
> Benchmark: calm, premium, Attentive-level polish. FOKUS must never read as a stock Material
> template. Companion, not warden. Warmth over authority.

---

## 1. Positioning in one line

**A calm room you step into on purpose.** Not a cage, not a scold, not a productivity dashboard
screaming at you. FOKUS holds a quiet boundary you set for yourself, and meets you with warmth
the moment you're tempted to leave.

Emotional register: **steady, spacious, kind.** Think a good breathing coach, not a drill sergeant.

---

## 2. Name treatment / logotype direction

- **Wordmark:** `FOKUS` set in the display typeface, all-caps, letter-spacing **+0.06em**
  (tracking-wide, but not airy). The all-caps + generous tracking reads as composed and
  deliberate — the opposite of a frantic to-do app.
- **The "O" is the brand.** The counter of the O is treated as the **focus ring** — a broken
  circular stroke with a single small gap at the top (like a timer arc that hasn't closed yet).
  This one move ties wordmark → app icon → progress ring → loading states into a single system.
  The gap is intentional: focus is a state you're *entering*, never a closed/finished cage.
- **Lockup:** mark (ring-O) may stand alone as the app icon; wordmark used in onboarding,
  splash, store. Minimum wordmark width **96px**; below that, use the mark only.
- **Clear space:** on all sides = height of the "O". Never crowd it.
- **Don't:** add drop shadows to the wordmark, outline it, gradient-fill the letters, or set it
  in the body typeface. The gradient lives only in the ring/mark, never the letters.

---

## 3. Color palette

Philosophy: a **calm, slightly cool base** (focus, night, stillness) with a **single warm
signal color** for encouragement and celebration. The warmth is rationed on purpose — it means
"you, well done" and nothing else, so it never loses its charge. No pure black, no pure white,
no saturated Material default blue/purple.

### 3.1 Core brand colors (theme-independent anchors)

| Token | Hex | Role |
|---|---|---|
| **Focus Indigo** | `#5B6CFF` | Primary brand hue — the ring, primary actions, focus state |
| **Deep Ink** | `#161A2E` | Darkest brand neutral — dark-theme surfaces, light-theme text |
| **Warm Amber** | `#FFB86B` | The rationed warm signal — celebration, streak flame, praise |
| **Sage Calm** | `#8FD3C4` | Recovery / breathe accent — soothing, "you're safe here" |
| **Mist** | `#F4F5FB` | Lightest neutral — light-theme background |

### 3.2 Light scheme — Material 3 ColorScheme roles

| M3 role | Hex | Notes |
|---|---|---|
| `primary` | `#4C5BE0` | Focus Indigo, darkened for AA on light |
| `onPrimary` | `#FFFFFF` | contrast 5.1:1 ✓ |
| `primaryContainer` | `#E1E4FF` | soft indigo tint for chips/filled tonal |
| `onPrimaryContainer` | `#141A4A` | 12.4:1 ✓ |
| `secondary` | `#3E7D71` | Sage, darkened — recovery accents on light |
| `onSecondary` | `#FFFFFF` | ✓ |
| `secondaryContainer` | `#C6EFE5` | breathe surfaces |
| `onSecondaryContainer` | `#0C2B25` | ✓ |
| `tertiary` | `#B5691E` | Amber, darkened — celebration text/icons on light |
| `onTertiary` | `#FFFFFF` | ✓ |
| `tertiaryContainer` | `#FFE2C2` | streak/achievement surfaces |
| `onTertiaryContainer` | `#3A1E00` | ✓ |
| `error` | `#B3261E` | M3 standard, WCAG-clean |
| `onError` | `#FFFFFF` | ✓ |
| `errorContainer` | `#F9DEDC` | |
| `onErrorContainer` | `#410E0B` | |
| `background` | `#F4F5FB` | Mist |
| `onBackground` | `#161A2E` | Deep Ink, 14.8:1 ✓ |
| `surface` | `#FBFBFE` | cards float just above background |
| `onSurface` | `#161A2E` | ✓ |
| `surfaceVariant` | `#E3E4EE` | dividers, inactive tracks |
| `onSurfaceVariant` | `#484A5B` | secondary text, 7.1:1 ✓ |
| `outline` | `#767888` | 3.1:1 vs surface (AA non-text) ✓ |
| `outlineVariant` | `#C7C9D6` | hairlines |
| `surfaceTint` | `#4C5BE0` | |
| `inverseSurface` | `#2E3142` | snackbars |
| `onInverseSurface` | `#F1F1F8` | |
| `inversePrimary` | `#B9C0FF` | |
| `shadow` | `#000000` | used at very low alpha only |
| `scrim` | `#000000` | intercept/overlay scrims @ 55% |

Named surface tiers (elevation-by-tint, see DESIGN_SYSTEM §5):
`surfaceContainerLowest #FFFFFF` · `Low #F6F6FC` · `default #F1F2F9` · `High #EBEcF5` · `Highest #E5E6F1`

### 3.3 Dark scheme — Material 3 ColorScheme roles

Dark is the **default hero context** for the active-session and recovery screens (calm at night,
OLED-friendly, less blue-light before sleep). Base is Deep Ink, never `#000000` (avoids OLED
smearing on scroll and feels softer).

| M3 role | Hex | Notes |
|---|---|---|
| `primary` | `#B9C0FF` | light indigo — AA on dark surfaces (8.9:1) |
| `onPrimary` | `#232A66` | ✓ |
| `primaryContainer` | `#3A4290` | filled tonal on dark |
| `onPrimaryContainer` | `#E1E4FF` | ✓ |
| `secondary` | `#8FD3C4` | Sage — recovery accents glow gently on dark |
| `onSecondary` | `#0C2B25` | ✓ |
| `secondaryContainer` | `#265049` | |
| `onSecondaryContainer` | `#C6EFE5` | ✓ |
| `tertiary` | `#FFB86B` | Warm Amber at full strength — celebration pops on dark |
| `onTertiary` | `#4A2600` | ✓ |
| `tertiaryContainer` | `#6B3F14` | |
| `onTertiaryContainer` | `#FFE2C2` | ✓ |
| `error` | `#FFB4AB` | |
| `onError` | `#690005` | |
| `errorContainer` | `#93000A` | |
| `onErrorContainer` | `#FFDAD6` | |
| `background` | `#101322` | one notch below Deep Ink for depth |
| `onBackground` | `#E7E8F2` | 15.1:1 ✓ |
| `surface` | `#161A2E` | Deep Ink |
| `onSurface` | `#E7E8F2` | ✓ |
| `surfaceVariant` | `#2B2E42` | |
| `onSurfaceVariant` | `#C3C5D6` | 9.6:1 ✓ |
| `outline` | `#8D8FA0` | AA non-text ✓ |
| `outlineVariant` | `#3A3D52` | |
| `surfaceTint` | `#B9C0FF` | |
| `inverseSurface` | `#E7E8F2` | |
| `onInverseSurface` | `#2E3142` | |
| `inversePrimary` | `#4C5BE0` | |
| `shadow` | `#000000` | dark theme leans on tint, not shadow |
| `scrim` | `#000000` | |

Named surface tiers (dark):
`surfaceContainerLowest #0B0E1A` · `Low #191D31` · `default #1D2136` · `High #262A40` · `Highest #31354C`

### 3.4 Signature gradient (mark + ring only)

**Focus Gradient** — `#5B6CFF → #7A6BFF` at 135°. Used exclusively for the progress ring, the
app-icon mark, and the completed-session celebration burst. Never as a screen background, never
behind text. This is the "premium" tell; overuse kills it.

**Calm Gradient** (recovery) — `#8FD3C4 → #A9C7F0` at 160°. Only inside recovery-module
backgrounds/illustrations. Signals a different, softer emotional room than the rest of the app.

### 3.5 Contrast rules (WCAG AA, non-negotiable)

- Body text ≥ 4.5:1; large/bold text ≥ 3:1; UI component boundaries & the progress ring ≥ 3:1.
- Never place white text on Warm Amber or Sage at their full brightness — always the paired
  `on*Container`/dark ink. Amber-on-dark uses `onTertiary #4A2600` for any text over it.
- The de-emphasized "Emergency exit" affordance uses `onSurfaceVariant` (7:1 on light, 9.6:1 on
  dark) — **de-emphasized, never low-contrast.** Findability is policy (spec §2.3).

---

## 4. Typography

Primary: **Plus Jakarta Sans** (Google Fonts) — a geometric-humanist sans with warmth in the
round shapes and enough personality to not read as system default. Calm, modern, excellent
numerals for countdowns.
Numeric display for the big countdown: **Plus Jakarta Sans** with `fontFeatures: tabular figures`
so the timer doesn't jitter as digits change.

- **Display / countdown:** Plus Jakarta Sans, weights 600–700.
- **Headings & UI:** Plus Jakarta Sans, 500–700.
- **Body:** Plus Jakarta Sans, 400–500.
- **Fallback stack:** `Plus Jakarta Sans → Inter → Roboto → system-ui → sans-serif`.
  Ship the font bundled (offline-first — no Google Fonts network fetch at runtime; spec §4 zero
  network). Use `google_fonts` package in *asset* mode or add TTFs to `assets/fonts/`.

Rationale: one family, many weights = coherent + small footprint + no runtime download. DE has
long compound words (see §6) — Plus Jakarta Sans stays legible when tracked tight.

Full scale with sizes/weights/line-heights lives in `DESIGN_SYSTEM.md §2`.

---

## 5. Iconography

- **Grid:** 24×24 dp base, 2 dp live padding (20×20 keyline). Also authored at 48 for large
  states.
- **Stroke weight:** **2.0 dp** at 24px, scaling proportionally (never below 1.5, never above
  2.5 optically). All icons stroke-based (outline), not filled — lighter, calmer, premium.
  Filled variants only for *selected* nav states.
- **Corner radius on strokes:** **round caps + round joins**, corner radius **2 dp** on any
  right-angle. Softness is the brand; no sharp corners anywhere in the icon set.
- **Terminals:** rounded. **Optical consistency** over mathematical: hand-tune so a circle and a
  square icon feel the same visual weight.
- **The FOKUS ring motif** (broken circle, gap at top) recurs: use it in the loading spinner,
  the session progress ring, and the empty-state illustrations for continuity.
- **Don't:** mix filled and outline in one row; use Material's default icon set at full weight
  (too heavy) without re-stroking to 2 dp; introduce a second corner radius language.

---

## 6. Motion personality

**"Settle, don't snap."** FOKUS motion is calm, decelerating, and slightly slow — nothing
bounces aggressively, nothing is instant-cut. Transitions breathe.

| Token | Duration | Curve | Use |
|---|---|---|---|
| `motion.instant` | 0 ms | — | state that must not animate (timer digit swap) |
| `motion.quick` | 120 ms | `easeOutCubic` | tap feedback, ripples, chip toggles |
| `motion.base` | 240 ms | `easeInOutCubic` | most transitions, card enters |
| `motion.calm` | 400 ms | `easeOutCubic` | screen transitions, sheet reveals |
| `motion.breath` | 4000 ms | `easeInOutSine` | the breathing circle (inhale/exhale phases) |
| `motion.celebrate` | 700 ms | `easeOutBack` (gentle, overshoot ≤ 1.05) | completion, badge unlock |

- Recovery motion is the slowest and softest in the app — deliberately below the rest so
  entering recovery *feels* like a gear-down. The breathing circle uses `easeInOutSine` because
  sine matches the physiological in-out of real breath.
- Reduced-motion (OS setting): replace all scale/translate with cross-fades at `motion.base`;
  the breathing circle becomes a slow opacity + text-cue pulse (never fully static — the cue
  still guides breath). Respect `MediaQuery.disableAnimations`.
- No motion ever exceeds `motion.calm` for functional UI (only celebrate + breath are longer,
  and both are opt-in emotional moments, not blocking).

---

## 7. Voice notes for visuals (how images should *feel*)

- **Illustration style:** single-weight line art (2.5 dp at illustration scale) on soft
  gradient/blur field, minimal fill, one or two accent colors from palette per illustration.
  Rounded, organic, no faces (avoids gendering/aging the user — universal), no clutter.
- **Never depict:** locks, cages, chains, prison bars, red X's, angry phones, guilt imagery.
  The blocking metaphor is a *gentle boundary / held space*, never punishment.
- **Do depict:** breath, water, plants, open space, soft light, a calm horizon, a settling ring.
- **Copy pairing:** visuals carry warmth so copy can stay short. Celebrations show growth
  (a filled ring, a small plant), not trophies-as-status. Never infantilize (no cartoon
  mascots begging you to come back).
- **Empty states** use the ring motif + one warm line, never a sad/empty metaphor.

---

## 8. Accessibility as brand

Accessibility is not a checklist here, it's the premium tell: AA contrast everywhere, ≥ 48 dp
targets, full TalkBack, reduced-motion honored, DE/EN both first-class. A calm product that
excludes people is neither calm nor premium.
