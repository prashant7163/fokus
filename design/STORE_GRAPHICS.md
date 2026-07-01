# FOKUS — Play Store Graphics

> Play Console asset specs + concepts + captions (EN + DE). SVG drafts are in `design/assets/`.
> Rasterization / final polish flagged where human tooling is needed. All copy honors product
> principles (spec §2): calm, no guilt, "recovery" is the hero differentiator. Package
> `ch.hoffely.fokus`, publisher Hoffely GmbH.

---

## 1. App icon — 512×512 (hi-res icon)

- **Source:** `design/assets/app_icon.svg` (draft) — broken focus ring in the Focus Gradient on a
  Deep Ink field, centered still-point.
- **Play spec:** 512×512 px, 32-bit PNG (with alpha OK but Play flattens), ≤ 1 MB.
- **Adaptive icon (in-app launcher):** provide foreground (the ring mark) + background (Deep Ink
  gradient) layers. Keep the mark within the **66% safe zone** (≈ center 338 px) — outer ring
  radius in the draft (150 px on 512) sits safely inside. Export `mark.svg` as the foreground
  layer, a flat `#161A2E→#101322` as background.
- **Contrast:** indigo ring on Deep Ink ≈ 4.9:1 (AA for the graphical mark ≥ 3:1) ✓. Legible and
  recognizable at 48 px (tested geometry: 3.6 dp stroke on the 48 px `mark.svg`).
- **Needs human tooling:** SVG → 512 PNG export; adaptive-icon XML (`ic_launcher`) + monochrome
  layer for Android 13 themed icons (supply a single-color version of `mark.svg`).

---

## 2. Feature graphic — 1024×500

- **Source:** `design/assets/feature_graphic.svg` (draft).
- **Concept:** Deep Ink field, soft indigo + sage glow, big broken focus ring on the right, FOKUS
  wordmark + tagline on the left. **Right ~120 px kept clear** — Play overlays the install button
  / video play button there; nothing important lives on the right edge.
- **Tagline (EN):** "Focus without the fight." / sub: "Block distractions. Recover gently. Build
  the streak."
- **Tagline (DE):** "Fokus ohne Kampf." / sub: "Ablenkungen blockieren. Sanft erholen. Serie
  aufbauen."
- **Play spec:** 1024×500 px, 24-bit PNG or JPEG, no alpha, ≤ 15 MB. No essential text near
  edges (Play may crop/scale on some surfaces).
- **Needs human tooling:** SVG → 1024×500 PNG; produce a DE variant of the text layer; confirm
  the wordmark renders with the bundled Plus Jakarta Sans (convert text to outlines on export so
  the store render is font-independent).

---

## 3. Screenshot storyboard — 8 phone screenshots

- **Play spec:** min 2, up to 8. PNG/JPEG, 16:9 or 9:16, each side 320–3840 px. Use **9:16
  portrait, 1080×1920** (or 1284×2778 for a modern device frame). First 2–3 are the ones most
  people see — lead with the differentiator.
- **Style:** device frame optional; each shot pairs a real screen (built from `SCREENS.md`) with
  a short caption band (Deep Ink, Plus Jakarta Sans, amber/indigo accent). Dark theme for the hero
  shots (calm, premium), one or two light shots for balance. Caption band ≤ 5 words primary + one
  supporting line.
- **Needs human tooling:** actual on-device/emulator captures of the built screens, then compose
  with caption bands in Figma. Below is the ordered storyboard + captions to hand to whoever
  composes them.

| # | Screen (from SCREENS.md) | Caption EN (primary) | Caption EN (support) | Caption DE (primary) | Caption DE (support) |
|---|---|---|---|---|---|
| 1 | Active Session (dark, ring + countdown) | **Focus, held.** | A calm session you set yourself. | **Fokus, gehalten.** | Eine Session, die du selbst setzt. |
| 2 | Recovery — Breathe (⭐ differentiator, lead early) | **Tempted? Breathe.** | Recovery, not willpower. | **Versucht? Atme.** | Erholung statt Willenskraft. |
| 3 | Blocked-App Intercept ("Instagram can wait") | **Instagram can wait.** | A warm nudge, never a scold. | **Instagram kann warten.** | Ein sanfter Anstoß, kein Tadel. |
| 4 | Recovery hub (5 modules) | **Five ways to reset.** | Breathe, stretch, water, refocus. | **Fünf Wege zurück.** | Atmen, dehnen, trinken, neu fokussieren. |
| 5 | Home + one-tap repeat hero | **One tap to focus.** | Repeat your best setup instantly. | **Ein Tipp zum Fokus.** | Dein Setup sofort wiederholen. |
| 6 | Session Complete (celebration + streak) | **End on a win.** | Streaks that celebrate, never nag. | **Mit einem Sieg enden.** | Serien, die feiern, nicht nörgeln. |
| 7 | Today stats / streak | **See your focus grow.** | All on your device. Always. | **Sieh deinen Fokus wachsen.** | Alles auf deinem Gerät. Immer. |
| 8 | Privacy / permissions health (settings) | **Private by design.** | No accounts. No tracking. Offline. | **Privat by Design.** | Kein Konto. Kein Tracking. Offline. |

Caption tone guardrails: never imply guilt or failure; frame blocking as a boundary the user
chose; make the recovery differentiator unmissable (shots 2–4). Keep DE captions inside the band
— several DE strings run ~30% longer; the composer should size the band for the DE set and reuse
that height for EN.

---

## 4. Additional store assets (checklist for the human packager)

- [ ] 512 icon PNG (from `app_icon.svg`) + adaptive + monochrome layers.
- [ ] 1024×500 feature graphic PNG, EN + DE text variants (text → outlines).
- [ ] 8 screenshots per locale (EN, DE), 1080×1920, from built screens with caption bands.
- [ ] (Optional) 30-sec promo video — script could follow storyboard order 1→2→6.
- [ ] Short description / full description — **PM-owned** (F-20), not in this design package.
- [ ] Data-safety form answers — driven by "zero network, on-device only" (spec §4); PM/tech-lead.

## 5. Rasterization guidance (repeatable)

All SVGs are authored at clean integer viewBoxes with explicit geometry (no font dependency in
the icon/mark/illustrations). Recommended export path for whoever has tooling:
```
rsvg-convert -w 512 -h 512 app_icon.svg -o ic_launcher_512.png
rsvg-convert -w 1024 -h 500 feature_graphic.svg -o feature_graphic.png   # then flatten, strip alpha
```
For the feature graphic, convert the wordmark/tagline text to paths first (Inkscape: Path → Object
to Path) so the store render doesn't depend on Plus Jakarta Sans being present.
```
