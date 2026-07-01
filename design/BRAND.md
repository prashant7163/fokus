# FOKUS — Brand Identity (v2)

> The design north star. Every screen, asset, and animation traces back to the decisions here.
> Benchmark: calm, premium, Attentive-level polish. FOKUS must never read as a stock Material
> template — and, per D-009, must never read as another Calm/Headspace/Forest clone.
> Companion, not warden. Warmth over authority.
>
> **v2 (2026-07-02, decision D-009):** blue/indigo dropped entirely. Warm neutral-to-light base,
> light theme default, **orange as the single, rationed accent**. Charcoal (never black) for the
> app icon and dark theme. This file supersedes the v1 indigo identity.

---

## 1. Positioning

FOKUS lives in the wellbeing/focus category, which is **crowded and visually converged**. To win
attention and trust, the brand leads with what FOKUS actually *does differently*, not with the
category's shared mood-board.

### 1.1 What the segment looks and sounds like (and why we avoid it)

| The segment cliché | Seen in | Why we don't do it |
|---|---|---|
| Cool blues, purples, teal-night gradients | Calm, Headspace, most meditation apps | Reads as "another meditation app"; blue is the category default. **We dropped it (D-009).** |
| Growing trees / forests / gardens as the reward | Forest, Flora, Plantie | Gamified guilt ("your tree died"); a metaphor we reject. |
| Rounded pastel blobs + a smiling mascot | Headspace | Infantilizing; we celebrate without cartoons. |
| Screen-time dashboards shouting red numbers | Digital-wellbeing tools, StayFocusd | Punitive; the opposite of our compassionate register. |
| Astronaut/space/"deep focus" sci-fi | Brain.fm, focus-music apps | Cold and performative; not human. |

### 1.2 What FOKUS looks and sounds like instead

- **Warm, not cool.** A single earthy orange on warm greys and off-whites — the color of a lamp
  left on, a sunrise, a hearth. Reads as *human and present*, not clinical or nocturnal.
- **The broken ring, not a tree.** Our one persistent symbol is a ring with a small gap — a state
  you are entering, never a cage that closes, never a plant that can die.
- **A companion voice.** Copy speaks like a calm friend in the room: "Instagram can wait." We
  never scold, never gamify shame, never count your failures back at you.
- **In-the-moment, not ambient.** The visual and verbal identity foreground the *moment of
  temptation* — the intercept and the recovery — because that is the one thing no competitor does.

### 1.3 The four differentiators the brand must carry

Everything visual and verbal should ladder up to at least one of these. They are the reason FOKUS
exists and the reason it is not a clone:

1. **In-flow Recovery System** — nobody else meets you *at the moment of temptation* and walks you
   back with breath, a next-smallest-step, water, a stretch, or a graceful shrink. This is the
   product hypothesis and the hero of the brand.
2. **Compassionate structured exits** — leaving is always allowed, always dignified; five honest
   reasons, an emergency door that never lectures. Friction is honest, never a trap.
3. **Earned lock-break flexibility** — streaks grant *tokens* that let you bend a session without
   breaking your streak. Discipline that rewards you with slack, not one that punishes a slip.
4. **100% offline privacy** — behavioral data never leaves the device; zero network in scope. In a
   category quietly hoovering up mood data, "your struggle stays on your phone" is a real edge.

### 1.4 Positioning line

**Focus without the fight.** Not a cage, not a scold, not a screen-time dashboard yelling at you.
FOKUS holds a quiet boundary you set for yourself — and when you're tempted to leave, it meets you
in that exact moment and walks you back, gently.

Emotional register: **warm, steady, present.** A calm friend in the room, not a drill sergeant and
not a meditation narrator.

DE nod (tagline): **„Konzentration ohne Kampf."** (Full DE localization is separate; the tagline
travels.)

---

## 2. Name treatment / logotype direction

- **Wordmark:** `FOKUS` set in the display typeface, all-caps, letter-spacing **+0.06em**
  (tracking-wide, but not airy). The all-caps + generous tracking reads as composed and
  deliberate — the opposite of a frantic to-do app.
- **The "O" is the brand.** The counter of the O is treated as the **focus ring** — a circular
  stroke with a single small gap (**15°**) at the top (like a timer arc that hasn't closed yet),
  plus a small solid **center dot** (the still, centered self / the focus target). This one move
  ties wordmark → app icon → progress ring → loading states into a single system.
  The gap is intentional: focus is a state you're *entering*, never a closed/finished cage.
  A **closed-circle** variant exists (no gap) for contexts where the gap reads as an error at tiny
  sizes — see §9 icon variants; the broken ring is the primary.
- **Lockup:** the ring-mark (ring + dot) may stand alone as the app icon; wordmark used in
  onboarding, splash, store. Minimum wordmark width **96px**; below that, use the mark only.
- **Clear space:** on all sides = height of the "O". Never crowd it.
- **Color:** the ring/mark is **orange** on a charcoal or neutral field; the wordmark is ink on
  light, off-white on charcoal. **Only the mark carries the orange** — never gradient-fill the
  letters, never outline them, never drop-shadow them, never set them in the body typeface.

---

## 3. Color palette (v2)

Philosophy: a **warm neutral base** (off-whites and warm greys — paper, stone, morning light)
with a **single warm accent, orange**, rationed hard. Orange means "you, act here, well done" —
primary action, focus state, celebration, streak — and nothing else, so it never loses its charge.
No blue, no indigo, no purple. No pure black (charcoal instead), no pure white (warm off-white).

A quiet, desaturated **sage** (green, no blue) carries the *recovery* room only — a different,
softer emotional space than the rest of the app. It is a neutral, not a second brand color.

### 3.1 Core brand colors (theme-independent anchors)

| Token | Hex | Role |
|---|---|---|
| **Signal Orange** | `#E8611F` | The brand accent — the ring, the identity, celebration. Icon ring. |
| **Ember (bright)** | `#FF7A30` | Orange on dark/charcoal (the icon ring on charcoal, dark-theme accent) |
| **Rust (deep)** | `#C24A16` | Orange darkened for AA text/actions on light surfaces |
| **Charcoal** | `#2A2723` | App-icon background; dark-theme surface anchor (never `#000000`) |
| **Deep Charcoal** | `#1C1B19` | Dark-theme background — one notch below Charcoal for depth |
| **Warm Ink** | `#22201D` | Darkest neutral for text on light |
| **Paper** | `#F5F2EC` | Lightest warm neutral — light-theme background |
| **Sage** | `#8FA07E` | Recovery accent (green, no blue) — "you're safe here" |

### 3.2 Light scheme — Material 3 ColorScheme roles (default theme)

All pairings below verified WCAG AA (body ≥ 4.5:1, large/non-text ≥ 3:1).

| M3 role | Hex | Notes |
|---|---|---|
| `primary` | `#C24A16` | Rust — orange darkened for AA on light |
| `onPrimary` | `#FFFFFF` | 4.9:1 ✓ |
| `primaryContainer` | `#FFE4D2` | soft orange tint for chips/filled tonal |
| `onPrimaryContainer` | `#4A1B04` | 11.9:1 ✓ |
| `secondary` | `#5A6152` | Sage-neutral, darkened — recovery/secondary on light |
| `onSecondary` | `#FFFFFF` | 6.4:1 ✓ |
| `secondaryContainer` | `#DDE7D0` | breathe/recovery surfaces |
| `onSecondaryContainer` | `#26301E` | 10.8:1 ✓ |
| `tertiary` | `#785A0B` | warm gold — streak/achievement text on light (a warm sibling of orange, not a new hue) |
| `onTertiary` | `#FFFFFF` | 6.4:1 ✓ |
| `tertiaryContainer` | `#FBEBC8` | streak/achievement surfaces |
| `onTertiaryContainer` | `#4A3200` | 10.2:1 ✓ |
| `error` | `#B3261E` | M3 standard, WCAG-clean |
| `onError` | `#FFFFFF` | 6.5:1 ✓ |
| `errorContainer` | `#F9DEDC` | |
| `onErrorContainer` | `#410E0B` | |
| `background` | `#F5F2EC` | Paper |
| `onBackground` | `#22201D` | Warm Ink, 14.5:1 ✓ |
| `surface` | `#FBF9F6` | cards float just above background |
| `onSurface` | `#22201D` | 15.5:1 ✓ |
| `surfaceVariant` | `#EAE4DA` | dividers, inactive tracks |
| `onSurfaceVariant` | `#55524C` | secondary text, 7.4:1 ✓ |
| `outline` | `#84807A` | 3.7:1 vs surface (AA non-text) ✓ |
| `outlineVariant` | `#D6CFC3` | hairlines |
| `surfaceTint` | `#C24A16` | |
| `inverseSurface` | `#332F2A` | snackbars |
| `onInverseSurface` | `#F3EFE9` | |
| `inversePrimary` | `#FFB68C` | |
| `shadow` | `#000000` | used at very low alpha only |
| `scrim` | `#000000` | intercept/overlay scrims @ 55% |

Named surface tiers (elevation-by-tint, see DESIGN_SYSTEM §5):
`surfaceContainerLowest #FFFFFF` · `Low #FAF7F2` · `default #F5F2EC` · `High #EFEBE3` · `Highest #E9E4DA`

### 3.3 Dark scheme — Material 3 ColorScheme roles (charcoal, not black)

Dark is a **variant** now (light is the default hero context, D-009). Base is Charcoal, never
`#000000` — avoids OLED smearing on scroll, feels warmer and softer, and keeps the "lamp left on"
warmth even at night.

| M3 role | Hex | Notes |
|---|---|---|
| `primary` | `#FFB68C` | light ember — AA on charcoal (9.5:1) |
| `onPrimary` | `#3A1600` | ✓ |
| `primaryContainer` | `#7A3410` | filled tonal on dark |
| `onPrimaryContainer` | `#FFDBC7` | 7.0:1 ✓ |
| `secondary` | `#BCCBAC` | Sage — recovery accents glow gently on charcoal (9.5:1) |
| `onSecondary` | `#28331C` | ✓ |
| `secondaryContainer` | `#3E4833` | |
| `onSecondaryContainer` | `#DDE7D0` | ✓ |
| `tertiary` | `#F2C24E` | warm gold — celebration/streak pops on charcoal (8.3:1) |
| `onTertiary` | `#3A2B00` | ✓ |
| `tertiaryContainer` | `#574200` | |
| `onTertiaryContainer` | `#FBEBC8` | ✓ |
| `error` | `#FFB4AB` | |
| `onError` | `#690005` | |
| `errorContainer` | `#93000A` | |
| `onErrorContainer` | `#FFDAD6` | 7.2:1 ✓ |
| `background` | `#1C1B19` | Deep Charcoal |
| `onBackground` | `#ECE7E0` | 14.3:1 ✓ |
| `surface` | `#20201E` | Charcoal surface |
| `onSurface` | `#ECE7E0` | 13.3:1 ✓ |
| `surfaceVariant` | `#3A382F` | |
| `onSurfaceVariant` | `#CFC8BF` | 9.8:1 ✓ |
| `outline` | `#9A968E` | AA non-text (5.5:1) ✓ |
| `outlineVariant` | `#3A382F` | |
| `surfaceTint` | `#FFB68C` | |
| `inverseSurface` | `#ECE7E0` | |
| `onInverseSurface` | `#332F2A` | |
| `inversePrimary` | `#C24A16` | |
| `shadow` | `#000000` | dark theme leans on tint, not shadow |
| `scrim` | `#000000` | |

Named surface tiers (dark):
`surfaceContainerLowest #161513` · `Low #201F1D` · `default #242320` · `High #2E2C28` · `Highest #383530`

### 3.4 Signature gradient (mark + ring only)

**Focus Gradient** — `#FF7A30 → #E8611F` at 135° (light-to-deep ember). Used exclusively for the
progress ring, the app-icon mark, and the completed-session celebration burst. Never as a screen
background, never behind text. This is the "premium" tell; overuse kills it. On light surfaces the
ring may render in solid `#C24A16` where the gradient would drop below AA.

**Calm Wash** (recovery) — `#8FA07E → #B7C3A5` at 160° (sage, no blue). Only inside
recovery-module backgrounds/illustrations. Signals a different, softer emotional room than the
rest of the app. It is a *neutral wash*, not a second accent — kept desaturated so orange stays
the only true signal.

### 3.5 Contrast rules (WCAG AA, non-negotiable)

- Body text ≥ 4.5:1; large/bold text ≥ 3:1; UI component boundaries & the progress ring ≥ 3:1.
- Never place white text on Sage or on the streak-gold at full brightness — always the paired
  `on*Container`/dark ink. Orange used as *text/icon* on light uses Rust `#C24A16` (4.66:1), not
  bright Signal Orange.
- The de-emphasized "Emergency exit" affordance uses `onSurfaceVariant` (7.4:1 light, 9.8:1 dark)
  — **de-emphasized, never low-contrast.** Findability is policy (spec §2.3).

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

- **Grid:** 24×24 dp base, 2 dp live padding (20×20 keyline). Also authored at 48 for large states.
- **Stroke weight:** **2.0 dp** at 24px, scaling proportionally (never below 1.5, never above 2.5
  optically). All icons stroke-based (outline), not filled — lighter, calmer, premium.
  Filled variants only for *selected* nav states.
- **Corner radius on strokes:** **round caps + round joins**, corner radius **2 dp** on any
  right-angle. Softness is the brand; no sharp corners anywhere in the icon set.
- **Terminals:** rounded. **Optical consistency** over mathematical: hand-tune so a circle and a
  square icon feel the same visual weight.
- **The FOKUS ring motif** (broken circle, gap at top, center dot) recurs: use it in the loading
  spinner, the session progress ring, and the empty-state illustrations for continuity.
- **Don't:** mix filled and outline in one row; use Material's default icon set at full weight
  without re-stroking to 2 dp; introduce a second corner-radius language; tint icons anything but
  the neutral scale or (sparingly) orange for the one active/selected element per view.

---

## 6. Motion personality

**"Settle, don't snap."** FOKUS motion is calm, decelerating, and slightly slow — nothing bounces
aggressively, nothing is instant-cut. Transitions breathe.

| Token | Duration | Curve | Use |
|---|---|---|---|
| `motion.instant` | 0 ms | — | state that must not animate (timer digit swap) |
| `motion.quick` | 120 ms | `easeOutCubic` | tap feedback, ripples, chip toggles |
| `motion.base` | 240 ms | `easeInOutCubic` | most transitions, card enters |
| `motion.calm` | 400 ms | `easeOutCubic` | screen transitions, sheet reveals |
| `motion.breath` | 4000 ms | `easeInOutSine` | the breathing circle (inhale/exhale phases) |
| `motion.celebrate` | 700 ms | `easeOutBack` (gentle, overshoot ≤ 1.05) | completion, badge unlock |

- Recovery motion is the slowest and softest in the app — deliberately below the rest so entering
  recovery *feels* like a gear-down. The breathing circle uses `easeInOutSine` because sine matches
  the physiological in-out of real breath.
- Reduced-motion (OS setting): replace all scale/translate with cross-fades at `motion.base`; the
  breathing circle becomes a slow opacity + text-cue pulse (never fully static). Respect
  `MediaQuery.disableAnimations`.
- No motion ever exceeds `motion.calm` for functional UI (only celebrate + breath are longer, and
  both are opt-in emotional moments, not blocking).

---

## 7. Voice notes for visuals (how images should *feel*)

- **Illustration style:** single-weight line art (2.5 dp at illustration scale) on a soft warm
  wash, minimal fill, one or two accent colors from the palette per illustration. Rounded,
  organic, no faces (avoids gendering/aging the user — universal), no clutter.
- **Never depict:** locks, cages, chains, prison bars, red X's, angry phones, guilt imagery, dying
  plants, growing forests (that's the competitor cliché — see §1), meditation-app blue night skies.
- **Do depict:** breath, water, warm light, open space, a calm horizon, a settling ring, the small
  next step. Warmth over coolness always.
- **Copy pairing:** visuals carry warmth so copy can stay short. Celebrations show growth (a filled
  ring, warm light), not trophies-as-status. Never infantilize (no cartoon mascots begging you to
  come back).
- **Empty states** use the ring motif + one warm line, never a sad/empty metaphor.

---

## 8. Accessibility as brand

Accessibility is not a checklist here, it's the premium tell: AA contrast everywhere, ≥ 48 dp
targets, full TalkBack, reduced-motion honored, DE/EN both first-class. A calm product that
excludes people is neither calm nor premium.

---

## 9. App icon — variants & recommendation

Both variants ship as SVG in `design/assets/`: **charcoal background, orange ring + center dot.**

- **`app_icon.svg` — broken ring (15° gap at top). RECOMMENDED / primary.**
  The gap is the whole brand story: focus is a state you *enter*, the ring is never a closed cage.
  It differentiates FOKUS from the sea of solid-circle app icons on the home screen, and it ties
  directly to the in-app progress ring and loading spinner. At the launcher's smallest adaptive
  size the gap remains legible because the stroke is heavy (≈34 px at 512) and the gap sits at a
  predictable 12 o'clock.
- **`app_icon_closed.svg` — closed ring (no gap). Variant.**
  Provided for any surface where the gap could be misread as a rendering glitch (monochrome
  notification icon, tiny favicons, embroidery/merch). Same charcoal + orange + dot.

**Recommendation: ship the broken-ring `app_icon.svg` as the store/launcher icon.** Use the closed
variant only for the Android *monochrome/notification* layer and sub-24 px favicons. The center dot
stays in both. Rationale: the differentiator (a state you enter, not a cage) is worth more on the
crowded launcher than the marginal legibility risk, and the risk is mitigated by heavy stroke +
fixed gap position.
