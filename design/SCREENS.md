# FOKUS — Screen Specifications

> Per-screen build specs for Phase A (F-05, F-07–F-12). Layout top-to-bottom, all states,
> actions, accessibility, DE/EN length risk. Tokens from `DESIGN_SYSTEM.md`; copy is EN with
> DE noted where length matters. All copy respects product principles (spec §2): compassionate,
> never punitive, emergency exit always findable. Final strings live in ARB (F-10 owns
> disclosure copy verbatim; do not invent policy wording here).

Conventions used below:
- **CTA1** = primary (filled), **CTA2** = secondary (tonal), **CTA3** = de-emphasized/text.
- Every interactive element ≥ 48 dp; every icon has a TalkBack label; DE strings assumed
  ~30% longer than EN.

---

## 1. Home Dashboard  (F-11)

The calm entry point. Answers "what now?" in under a second and makes the one-tap repeat sacred.

**Layout (top → bottom):**
1. App bar (transparent, scrolls to `surfaceContainer`): FOKUS wordmark left; streak flame chip
   right (amber, "🔥 7" — tappable → stats). Settings gear far right.
2. **Greeting line** — `headlineSmall`, time-aware ("Good evening"), no name required.
3. **Hero card (repeat)** — the biggest element. If a last config exists:
   - `titleMedium` "Pick up where you left off"
   - blocked-app icon row (max 5 + "+N"), duration + strict badge
   - full-width **CTA1 "Start focus — 30 min"** (repeats last config, focus-gradient).
   - Radius `xl`, elevation 2.
4. **Start something new** — CTA2 tonal, "New session" → Start Session config.
5. **Today card** — 4 stats in a 2×2 grid: Focus minutes · Distractions blocked · Most-blocked
   app · Current streak. Small 6 dp stat rings where useful. `bodySmall` labels.
6. **Permissions-health banner** *(conditional)* — only if degraded: amber `tertiaryContainer`
   pill-row "Blocking is paused — accessibility off" + "Fix" text button. Dismiss ≠ hide until
   fixed; re-surfaces (spec §3.11).
7. (Optional) Smart-suggestion card (Phase 2) — inline dismissible, "based on your last 2 weeks".

**States:**
- *First run / no history:* hero card becomes an onboarding-completion nudge or a friendly
  "Start your first session" CTA1; Today card shows empty ring + "Your focus starts here" (ring
  motif, no sad empty art). Streak chip hidden until day 1.
- *Limited mode (permissions skipped):* hero still starts a **timer-only** session; a clear
  inline label "Blocking inactive — timer only" (not an error, honest). Permissions banner shown.
- *Active session exists* (returned to home mid-session): hero replaced by an "In focus — 24:10
  left" resume card → Active Session.
- *Loading:* skeleton shimmer on Today card only; hero + CTA render instantly from cached config.
- *Error (DB read fail):* Today card shows "Couldn't load today's stats" + retry; session start
  still works.

**Actions:** CTA1 repeat (1 tap to running session) · New session · streak chip → stats ·
gear → settings · Fix → permissions.

**Accessibility:** streak chip label "Current streak, 7 days, opens stats". Hero CTA label
includes duration + app count ("Start focus, 30 minutes, blocking 4 apps"). Stat tiles grouped
with semantic labels. Banner announced via live region on appear.

**DE/EN length:** "Pick up where you left off" → DE "Mach da weiter, wo du aufgehört hast" (long)
— allow 2 lines. "Distractions blocked" → DE "Ablenkungen blockiert" fits. Duration on CTA:
keep as "30 Min." abbrev in DE to protect one-line button.

---

## 2. Start Session — Config  (F-11)

Configure and launch. Optimized so common paths are few taps; task anchor is prompted but never
forced.

**Layout (top → bottom):**
1. App bar: back + title "New session". (No save-preset in Phase A — Phase 2.)
2. **Duration** — row of choice chips: 15 · 30 · 60 · 120 · Custom. Default preselect = last used
   or 30. "Custom" opens a wheel/stepper (5–480 min).
3. **Task anchor** *(prompted, optional)* — text field "What are you focusing on?" 80-char
   counter. Helper `bodySmall`: "Optional — but it helps." Never blocks start.
4. **Apps to block** — summary row "4 apps selected" + edit → app picker (sheet or route,
   reuses onboarding picker component). Shows selected app icons.
5. **Strict mode** — switch row with plain-language subtitle: "Strict mode — no early exits
   except emergencies. Choose this when you really mean it." Off by default. Info icon → sheet
   explaining consequences honestly (no guilt, just facts).
6. **Recovery** toggle (on by default) — "Recovery help when you're tempted" subtitle.
7. Sticky bottom bar: full-width **CTA1 "Start focus"**.

**States:**
- *No apps selected:* CTA still enabled (timer-only allowed) but inline hint "No apps selected —
  this will be a timer-only session." Honest, not blocking.
- *Custom duration active:* chip shows the chosen value ("45 min").
- *Permissions missing:* start proceeds in limited mode with the same honest label; a one-line
  "blocking needs accessibility — set up" link (→ permissions).
- *Loading app list:* picker shows skeleton rows.

**Actions:** CTA1 start (→ Active Session) · edit apps · toggle strict/recovery · custom duration.

**Accessibility:** chips as a radio group ("Duration, 30 minutes, selected"). Switch states
announced. Char counter announced at 70/80. Info sheets fully readable by TalkBack.

**DE/EN length:** Strict subtitle long in DE ("Strenger Modus — kein vorzeitiges Beenden außer
im Notfall.") — allow wrap. Chip labels numeric, safe. "Start focus" → "Fokus starten" fits.

---

## 3. Active Session  (F-11 / core; the screen users watch)

Dark-first hero. Countdown dominant, everything else supportive and quiet. 60 fps required.

**Layout (top → bottom), centered composition:**
1. Minimal top bar: no back button (prevents accidental leave); small "Session" label + strict
   badge if on.
2. **Progress ring + countdown** — the centerpiece. Big ring (stroke 12), focus-gradient arc
   sweeping toward the top gap; `countdown` text "24:32" centered inside, tabular figures.
   Below the number, `bodyMedium` "left".
3. **Task anchor** — `titleMedium`, centered, `onSurfaceVariant`, e.g. "Write the intro section".
   If none set, this line is omitted (no empty placeholder).
4. **Blocked-app icon row** — small muted app icons, centered, "+N" overflow. `bodySmall`
   caption "Blocked while you focus".
5. **Encouragement line** — `bodyLarge`, `secondary`, rotates every 90 s from l10n set with a
   soft cross-fade (`calm`). Warm, never nagging: "You're doing the thing." / "Steady."
6. **Distraction count** *(only if > 0)* — quiet `bodySmall` pill "2 redirects so far" — framed
   as neutral fact, not shaming.
7. Bottom: **CTA3 de-emphasized "End session"** — `TextButton`, `onSurfaceVariant`, generous
   space above it. (This is the honest, findable exit → Exit-Reason flow.)

**States:**
- *Running (default):* ring animates continuously from `endEpochMs`.
- *Restored after kill/reboot:* on entry, a 1-line snackbar "Session restored" (`base`); ring
  recomputes from wall-clock — no reset.
- *Recovery in progress:* screen dims to scrim, recovery sheet over it (session context stays
  visible behind).
- *Paused for permission loss (failedPermissions):* ring turns `onSurfaceVariant` (desaturated),
  banner "Blocking stopped — accessibility was turned off" + "Resume protection"/"End". Never
  silent (spec §4).
- *< 60 s remaining:* subtle amber tint enters the ring's leading edge; encouragement switches
  to "Almost there."
- *Completion:* auto-transition to Session Complete at 00:00 with `celebrate` motion.

**Actions:** End session (CTA3 → Exit-Reason) · that's it by design — minimal surface to leave.

**Accessibility:** countdown exposed as an accessible label updating each *minute* (not each
second — avoids TalkBack spam): "24 minutes left". Ring is decorative (`ExcludeSemantics`) since
the number carries it. "End session" clearly labeled. Reduced-motion: ring updates without the
continuous sweep animation (steps per minute), encouragement cross-fades only.

**DE/EN length:** encouragement lines vary — cap at 2 lines, curate DE set for length.
"End session" → "Beenden" (short, good). "left" → "übrig".

---

## 4. Blocked-App Intercept  (F-05, native InterceptActivity)

The moment of temptation. Must render < 200 ms from cold, feel warm not accusatory, and route to
recovery. Rendered natively (Kotlin) but must match this design 1:1. Full-screen over the blocked
app, `scrim`-less (it *is* the surface) — uses `background`.

**Layout (top → bottom), centered:**
1. Top: small FOKUS ring mark (reassures "this is your app, not a system error").
2. **App identity** — the blocked app's icon (real, from PackageManager) + headline
   `headlineSmall` "**Instagram can wait.**" (app name interpolated; warm, gently firm; never
   "BLOCKED"/red).
3. **Time remaining** — `titleMedium` "24 minutes left in your session".
4. **Task anchor** *(if set)* — `bodyLarge` in a soft `surfaceContainerLow` card: "You're here
   to: Write the intro section." Reconnects them to their own intent.
5. **CTA1 "Return to focus"** — full-width, focus-gradient. Closes intercept, goes home-screen /
   previous safe app.
6. **CTA2 "I'm stuck"** — tonal → deep-links Flutter recovery flow.
7. **Proactive recovery hint** *(conditional, ≥ 3 attempts in 5 min)*: a gentle inline card
   above CTA2 "Tempted a few times — a 30-second breather might help" + it pre-selects Breathe.
   Warm, not "you failed again".
8. Bottom: **CTA3 "Emergency exit"** — de-emphasized text, always present (spec §2.3, §3.4) →
   Exit-Reason flow (or immediate exit on emergency reason).

**States:**
- *Default intercept.*
- *Repeated attempts (≥3/5min):* proactive hint shown (spec §3.2).
- *Strict mode:* same layout; "Emergency exit" still present (emergency is never blocked), but
  the exit flow's needApp path will be denied kindly.
- *Active call in progress:* intercept **not shown** (spec §3.2) — nothing to design, but note
  for native: suppress.
- *No task anchor set:* omit step 4 cleanly.

**Actions:** Return to focus (CTA1) · I'm stuck (CTA2 → recovery) · Emergency exit (CTA3).

**Accessibility:** headline announced first on appear (TalkBack focus). App icon has label
"Instagram icon". Buttons full-width, ≥ 56 dp here (high-stakes, thumb-friendly). High contrast
maintained in both themes. Because it's native, replicate `Semantics`/contentDescription
carefully.

**DE/EN length:** "Instagram can wait." → DE "Instagram kann warten." fits. "Return to focus" →
"Zurück zum Fokus" (fits full-width). "I'm stuck" → "Ich hänge fest" (fine). "24 minutes left in
your session" → DE longer "Noch 24 Minuten in deiner Session" — allow wrap to 2 lines.

---

## 5. Recovery Flow — 5 Modules  (F-07)  ⭐ the emotional heart

A separate, softer visual room: `calmGradient` fields, +1 spacing step everywhere, slowest
motion, Sage accent. Entered as a **modal sheet over the dimmed session** (context stays behind
scrim) OR full-route from intercept. Each module ends identically: **"Ready to continue?"** →
Resume / End session. Every invocation logs `RecoveryEvent(type, result)` (spec §3.3 — sacred).

**Recovery hub (if entered without a preselected module):**
- Title `headlineSmall` "Take a moment." Subtitle `bodyMedium` "No rush. Pick what you need."
- A calm vertical list of 5 module cards, each: soft illustration thumbnail + name + 1-line
  benefit + duration. Order may be personalized later (spec §3.10) — default order below.
- Bottom: quiet "Skip — back to session" text link (recovery is never a trap).

Shared module chrome: close/handle at top (dismiss = back to intercept, logged as neither), a
calm heading, the module body, then the **"Ready to continue?"** footer with two buttons:
**CTA1 "Resume focus"** (Sage-tinted primary) · **CTA3 "End session"** (de-emphasized →
Exit-Reason). No timers pressure the choice.

### 5.1 Breathe  (30 s, 2 cycles min · inhale 4s / hold 4s / exhale 4s)
- **Body:** the breathing circle (see `assets/recovery_breathe.svg`) using the ring geometry +
  `calmGradient`. It expands over 4 s (inhale), holds 4 s (steady, subtle glow), contracts 4 s
  (exhale). Phase word cross-fades in center: "Breathe in" / "Hold" / "Breathe out".
- Cycle counter dots below (2 min). A soft ambient scale is the whole UI — generous whitespace.
- **States:** running · completed (dots filled, circle settles) → "Ready to continue?".
- **Reduced-motion:** circle opacity-pulses instead of scaling; phase words still guide with a
  progress bar. Never remove the breath guidance.
- **Accessibility:** phase changes announced ("Breathe in", "Hold", "Breathe out") via live
  region timed to phases; whole circle `ExcludeSemantics`. Haptic tick at each phase boundary
  (light impact) as a non-visual cue.
- **Motion:** `breath` (4000 ms `easeInOutSine`) per phase — the app's signature calm.

### 5.2 Task reset  (~15 s · text input → session notes)
- **Body:** heading "What's the next smallest step?" + a single calm text field (autofocus
  optional — avoid keyboard jump-scare; consider tap-to-focus). Example ghost text: "Open the
  doc and write one sentence." Saved to session notes on Resume.
- **States:** empty · typed · saved. Empty is fine — Resume works without input (never force).
- **Accessibility:** field labeled; save confirmed by returning to session with a subtle
  "Noted." snackbar.
- **Length:** DE heading "Was ist der kleinste nächste Schritt?" fits one line.

### 5.3 Stand & stretch  (45 s · illustrated movement + gentle timer)
- **Body:** `assets/recovery_stretch.svg` illustration (figure-free, an abstract stretch/
  reaching motion or a gently arcing form) + a soft 45 s ring timer (Sage) + prompt "Stand up.
  Reach up, roll your shoulders, look away from the screen." Prompt may rotate 1–2 cues.
- **States:** running (timer) · done. Skippable ("I've stretched" completes early — honors
  agency).
- **Accessibility:** cues announced; timer exposed as "45 seconds". Not motion-dependent.

### 5.4 Water break  (45 s · guided reset + calm animation)
- **Body:** `assets/recovery_water.svg` (a calm rising water-line / droplet ripple, Sage→blue
  calm gradient) + prompt "Go get some water. We'll be here." + gentle 45 s ring. Warm, human.
- **States:** running · done · "I'm back" early-complete.
- **Accessibility:** ripple `ExcludeSemantics`; prompt read aloud; timer labeled.

### 5.5 Shrink session  (instant · reduce remaining to 10 min — "finish small")
- **Body:** `assets/recovery_taskreset.svg`-style calm card. Heading "Finish small?" + copy
  "Shrink the rest to 10 minutes and end on a win." Shows current-remaining → 10 min visual
  (two small rings). Note: contract enum name is `changeDuration`.
- **CTA1 "Shrink to 10 min"** (applies, returns to Active Session with new `endEpochMs`,
  recomputed wall-clock) · **CTA3 "Keep full time"** (back to session unchanged).
- **States:** applicable (remaining > 10 min) · not applicable (remaining ≤ 10 min → module
  hidden from hub / shown disabled with reason).
- **Accessibility:** clearly announce the new duration on apply. Confirm via snackbar "Session
  shortened to 10 minutes."
- This is framed as kindness (a graceful landing), never as giving up.

**Recovery flow — global accessibility & DE/EN:** all module copy ≤ 2 lines; DE curated for
length. "Ready to continue?" → "Bereit weiterzumachen?" (fits). "Resume focus" → "Weiter im
Fokus" / "End session" → "Beenden". Sheet is TalkBack-navigable; escape/dismiss returns to
intercept. Reduced-motion honored per module. **This flow gets the most whitespace and the
slowest, softest motion in the entire product.**

---

## 6. Exit-Reason Flow  (F-08)

On any early-end attempt: "Why are you leaving?" with **exactly five** options (spec §3.4). Warm,
no guilt, emergency always immediate. Bottom sheet over dimmed session.

**Layout:**
1. Handle + heading `headlineSmall` "Why are you leaving?" Subtitle `bodyMedium` "No judgment —
   this just helps." 
2. **Five option rows** (each ≥ 56 dp, icon + label + outcome hint):
   - **Finished my task** → counts as completed (celebratory path). Hint "Nice — counts as done."
   - **Emergency** → immediate exit, no lecture, no streak penalty. Hint "Leave now."
   - **I'm stuck** → recovery flow. Hint "Try a 30-sec reset."
   - **I'm tired** → recovery flow. Hint "Take a breather."
   - **I need one app** → normal mode: 5-min single-app pass, timer keeps running; strict mode:
     denied kindly. Hint "Quick 5-minute pass."
3. Bottom: **CTA3 "Stay in focus"** (dismiss — the friendly default is to stay).

**Sub-states:**
- *needApp (normal mode):* → single-app picker of currently-blocked apps → grants a 5-min pass;
  snackbar "5-minute pass — Instagram. Timer's still running." A quiet countdown chip appears on
  Active Session for the pass. No guilt.
- *needApp (strict mode):* kind denial sheet "Strict mode is on — this one's locked until your
  session ends. You've got this." + offers recovery instead. Emergency still available.
- *emergency:* exits immediately to Home, session → aborted (no penalty framing, no streak-loss
  guilt shown at this moment). Later stats reflect it neutrally.
- *finishedTask:* → Session Complete (celebration), status completed.
- *stuck / tired:* → Recovery hub (preselect Breathe for tired, hub for stuck).

**Strict-mode abort (when user insists on leaving a strict session via emergency-adjacent path):**
before confirming a non-emergency abort, show consequences honestly (spec §3.4): a dialog
"End early? This session won't count and your streak resets." + "End anyway" (CTA, not red-scary)
/ "Keep going" (CTA1). If lock-break tokens exist, offer redemption as a graceful alternative
("Use a lock-break token to end without breaking your streak — 2 left"). Emergency reason bypasses
all of this.

**Accessibility:** each option row states its outcome in the label ("Emergency, leave now, no
penalty"). Sheet dismissible. Strict consequences dialog fully readable; no time pressure.

**DE/EN length:** option labels short in both. Hints may wrap. "Why are you leaving?" → "Warum
gehst du?" (fits). "I need one app" → "Ich brauche eine App" (fits). Outcome hints curated.

---

## 7. Session Complete  (F-09)

Full-screen celebration. Warm, earned, never infantilizing. `celebrate` motion, focus-gradient
ring closing + soft amber burst (rationed warmth).

**Layout (top → bottom), centered:**
1. **Completed ring** — the progress ring filling to close its gap once, with a gentle amber
   pulse (`celebrate`). Center: a check or the ring-mark, not a trophy.
2. **Headline** `headlineLarge` — warm + specific: "30 minutes, done." (varies by outcome:
   completed / completed-via-lockbreak / finished-early-as-done).
3. **Stat delta card** — "+30 focus minutes" · "3 distractions redirected" · task anchor echoed
   "You worked on: Write the intro."
4. **Streak update** — if streak incremented: amber flame + "7-day streak" with a small
   grow animation. If a milestone/token earned: inline "You earned a lock-break token 🎟" +
   badge peek (achievements celebrated once — spec §3.8).
5. **Micro-feedback** *(sampled 1 in 3, spec §3.9)*: "How was this session?" 😊 😐 😔 (44+ dp
   each, padded to 48). On 😔 → one follow-up chip row (too long / interrupted / blocking failed
   / other). Skippable.
6. Bottom: **CTA1 "Done"** (→ Home) · **CTA2 "Start another"** (→ repeat config, one-tap keep).

**States:**
- *Standard completion.*
- *Completed-via-lockbreak:* headline acknowledges gracefully "Wrapped with a lock-break — streak
  safe." No shaming.
- *Aborted/emergency:* **does NOT show this screen** — emergency exits go straight home with, at
  most, a neutral "Session ended" toast. No celebration, but also no guilt screen.
- *Achievement unlocked:* badge appears with `celebrate`; only first unlock (spec §3.8).
- *Feedback not sampled (2 of 3):* skip step 5 entirely.

**Actions:** Done · Start another · feedback taps (optional).

**Accessibility:** celebration announced concisely ("Session complete. 30 focus minutes. 7 day
streak."). Emoji buttons have text labels ("Good", "Okay", "Rough"). Confetti/burst is
`ExcludeSemantics` + suppressed under reduced-motion (replaced with a static filled ring + amber
tint).

**DE/EN length:** "30 minutes, done." → "30 Minuten, geschafft." (fits). "Start another" →
"Noch eine" / "Weiter" (short). Feedback follow-up chips longer in DE — allow 2-line chips.

---

## 8. Onboarding  (F-10)

Three value screens → **accessibility disclosure (verbatim, PM-owned, Play-critical)** → permission
checklist → app picker → done. Never guilt; "I'll do this later" is respected → limited mode.
Calm, generously spaced, one idea per screen.

### 8.1 Value screens (3, swipeable, skip always available)
Each: a recovery-family illustration + `headlineMedium` + one `bodyLarge` line + page dots +
"Next"/"Skip". Content (final copy per blueprint §6.7 — placeholders here):
1. **Block the noise** — "Choose what to pause. Focus without the pull." (illustration: settling
   ring / quiet space).
2. **Recovery, not willpower** — "When you're tempted, we help you reset — not scold you."
   (breathe illustration). *This screen sells the differentiator — give it the best art.*
3. **Build the streak** — "Small wins, stacked. Watch your focus grow." (badge/plant motif).
- Bottom: "Get started" CTA1 on last screen; "Skip" text top-right throughout.

### 8.2 Accessibility disclosure  (⚠ verbatim, F-14/F-10 owned)
- **Full-screen, before any settings redirect.** Plain-language explanation of *why* FOKUS uses
  the AccessibilityService (to detect the foreground app and show the intercept), what data it
  reads, that it stays on-device, and that the user consents.
- Layout: heading, the disclosure body (scrollable, PM-drafted exact wording — DO NOT invent),
  and an **explicit consent button** "I understand — continue" (CTA1) + "Not now" (CTA3 →
  limited mode). No settings redirect fires until consent is tapped.
- Accessibility: entire disclosure readable by TalkBack top-to-bottom before the consent control;
  consent button not reachable by skipping the text (place after it in reading order).
- **Design note:** this screen ships the wording as written in the taskboard; the *visual frame*
  (spacing, calm tone, a small reassuring ring mark, no alarming iconography) is ours — keep it
  trustworthy and un-scary. No red, no warning triangles; this is consent, not danger.

### 8.3 Permission checklist
- A vertical list, one card per permission, each: name, plain-language "why", **status badge**
  (Active / Action needed), and a "Set up" button that deep-links the correct settings screen.
  Permissions (spec §3.11): **Accessibility** (core blocking), **Usage access** (supplementary
  detection), **Notifications** (session + schedule alerts), **Battery exemption** (survive doze).
- Copy each "why" as a benefit, not a demand: e.g. "So FOKUS can gently step in when you open a
  blocked app." Battery: "So your session keeps running even when the phone sleeps."
- Progress affordance: "2 of 4 set up" — informational, never a nag.
- Bottom: "Continue" CTA1 (enabled always — partial setup → limited mode with honest labels) +
  the running note "You can finish these anytime in Settings."

**States:** each permission Active / Action needed / (mid-flow) checking. Returning from settings
re-reads status live. Denied → stays "Action needed", no penalty, limited mode explained.

### 8.4 App picker
- Search field + list of installed, launchable apps (icon + name + toggle). Suggested/common
  distractors surfaced at top ("Commonly blocked" section — Social, Video) to cut taps.
  System/FOKUS/dialer/launcher excluded (spec §3.2) — not shown.
- Multi-select toggles; running count "4 selected"; sticky "Done" CTA1.
- **States:** loading (skeleton), empty search, all-deselected (allowed → timer-only).
- **Accessibility:** each row "Instagram, blocked, toggle". Search announces result count.

**Onboarding DE/EN length:** value headlines short; disclosure body is fixed DE+EN (PM). Permission
"why" lines run long in DE — design for 3-line cards. "I'll do this later" → "Später erledigen".

---

## 9. Settings / Permissions-health  (F-12)

Utility screen; calm, scannable. Surfaces permission health prominently (spec §3.11) and a warning
banner when any permission is revoked.

**Layout (top → bottom, grouped list):**
1. App bar "Settings".
2. **Permissions health card (top, prominent):** overall status line + per-permission rows with
   status badges + "Fix" where degraded. If a permission was lost, an `errorContainer` banner at
   the very top: "Blocking is off — accessibility was turned off. Fix to protect sessions." (This
   one is genuinely error-red; mid-session loss is the one place red is warranted.)
3. **Notifications** — toggles: session alerts, schedule reminders (Phase 2 schedules), completion.
4. **Recovery** — default recovery on/off, (Phase 2: reorder by resume-rate toggle for AI).
5. **Appearance** — theme: System / Light / Dark (dark is the calm default hero).
6. **Smart Suggestions (beta)** — opt-in master toggle (spec §3.10), off by default, with the
   "based on your last 2 weeks, on-device" reassurance.
7. **Blocked apps** — shortcut to app picker.
8. **Privacy** — a plain statement "Everything stays on your device. No accounts, no tracking."
   (Reinforces principle §2.4; a trust anchor, not just legalese.)
9. **About** — version, publisher (Hoffely GmbH), licenses.

**States:**
- *All healthy:* green status card, no banner.
- *Degraded (permission missing but not mid-session loss):* amber "Action needed" rows + "Fix".
- *Revoked mid-session (failedPermissions):* red top banner (only genuinely-error case).
- *Limited mode:* clear explanation of what's inactive + how to enable.

**Actions:** each toggle · Fix (→ settings deep-link) · theme select · open picker · licenses.

**Accessibility:** status badges have text ("Accessibility: active" / "…: action needed"). Banner
is a live region. Toggles announce state. Theme is a radio group.

**DE/EN length:** "Action needed" → "Aktion nötig" (fits badge). Setting subtitles long in DE —
allow 2 lines per row. "Smart Suggestions (beta)" → "Intelligente Vorschläge (Beta)" (fits, may
wrap).

---

## Cross-screen state coverage summary

| Screen | Loading | Empty | Error | Success/primary |
|---|---|---|---|---|
| Home | skeleton (Today only) | first-run nudge + ring motif | stats retry, start still works | hero repeat CTA |
| Start config | picker skeleton | no-apps → timer-only hint | — | Start focus |
| Active | restore snackbar | n/a (never empty) | permission-loss banner | running ring |
| Intercept | must be instant (<200ms) | n/a | (native fallback = fail-open, don't block) | Return to focus |
| Recovery | module load = instant | hub with 5 cards | — | Ready to continue? |
| Exit-reason | instant sheet | n/a | strict-deny sub-state | Stay in focus (default) |
| Complete | instant | n/a (only on success) | — | Done / Start another |
| Onboarding | app-list skeleton | empty search | perm-denied → limited | Get started / Done |
| Settings | list skeleton | n/a | perm-lost red banner | healthy green card |

**Global:** every screen tested at textScale 1.3×, both themes, TalkBack pass, ≥48 dp targets,
DE strings. Emergency exit findable on every screen where a session can be left.
