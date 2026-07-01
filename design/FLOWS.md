# FOKUS — User Flows

> Workflows optimized for friendliness and minimum taps. For each: the happy path, tap counts,
> and — critically — a **friction ledger** marking every point of friction as *intentional*
> (honest, disclosed, user's-past-self's-choice) or *accidental* (a bug in the experience to
> remove). Product principles (spec §2) bind here: honor the friction the user chose, never add
> hidden friction, emergency exit always findable.

Legend: `[tap]` = a user tap. Screens reference `SCREENS.md`.

---

## 1. First run (install → first session)

**Path:**
1. Launch → Value screen 1 → `[tap Next]` → 2 → `[tap Next]` → 3 → `[tap Get started]` (3 taps,
   or `[tap Skip]` = 1 tap to jump ahead).
2. **Accessibility disclosure** → read → `[tap "I understand — continue"]` (1 tap; consent is
   mandatory-to-proceed-with-blocking but "Not now" → limited mode is 1 tap away).
3. Permission checklist → `[tap Set up]` per permission → OS settings → back (each: ~2 taps +
   OS). User may `[tap Continue]` with partial setup → limited mode.
4. App picker → tap suggested distractors (Commonly-blocked section cuts this to a few taps) →
   `[tap Done]`.
5. Land on Home → `[tap Start focus]` → running.

**Tap count to first running session:** ~6 app taps + OS permission dialogs (unavoidable, OS-owned).
With "Skip"/"Not now" a user reaches a (limited-mode) session in ~3 taps.

**Friction ledger:**
- *Intentional:* accessibility disclosure + explicit consent — **required by policy and ethics**
  (spec §3.11, CLAUDE hard rules). Disclosed, un-scary, reversible via "Not now".
- *Intentional:* per-permission "why" before each redirect — earns trust, reduces later confusion.
- *Accidental to avoid:* forcing all 4 permissions before any session (we don't — limited mode
  exists). Forcing app selection (we don't — timer-only allowed). A long value carousel with no
  skip (skip is always present).
- *Design guard:* never block "Continue"/"Start" on completeness; honesty labels replace hard gates.

---

## 2. One-tap repeat session  (sacred — spec §3.1)

**Path:** Open app → Home hero card already shows last config → `[tap "Start focus — 30 min"]` →
**running**.

**Tap count: 1.** This is the single most important interaction in the product. Nothing —
no confirm dialog, no "are you sure", no re-picking apps — sits between the user and restarting
their proven setup.

**Friction ledger:**
- *Zero intentional friction here by design.* Any confirm step added later is **accidental
  friction** and must be rejected in review.
- Config is cached and rendered instantly (no spinner) so the CTA is tappable on frame 1.
- "Start another" on Session Complete is the same one-tap repeat from the celebration screen.

---

## 3. Distraction intercept → recovery → resume  (the core loop)

**Path (happy — user redirects themselves):**
1. User opens a blocked app (e.g. Instagram) mid-session.
2. **Intercept** appears < 200 ms: "Instagram can wait" + time left + task anchor.
3. `[tap "Return to focus"]` → back to focus. **1 tap, loop closed.** (Ideal outcome.)

**Path (tempted — needs help):**
1–2. As above.
3. `[tap "I'm stuck"]` → **Recovery hub** (or preselected Breathe if proactive-triggered).
4. `[tap a module]` → e.g. **Breathe** (30 s guided) → completes.
5. **"Ready to continue?"** → `[tap "Resume focus"]` → back to session. **~3 taps + 30 s calm.**
   - Alternatively `[tap "End session"]` → Exit-Reason flow (still no guilt).

**Proactive branch (≥ 3 attempts in 5 min, spec §3.2):** intercept surfaces a gentle recovery
hint pre-selecting Breathe → `[tap the hint]` skips the hub (1 fewer tap when the user is
clearly struggling — friendliness where it matters most).

**Friction ledger:**
- *Intentional:* the intercept itself — this **is** the boundary the user set. It's warm, fast,
  and offers the easy way back (Return to focus is the primary CTA).
- *Intentional:* recovery is offered, never forced — "Return to focus" is always the top button;
  recovery is opt-in for those who want it.
- *Accidental to avoid:* intercept latency > 200 ms (feels broken), any dead-end without a warm
  primary action, recovery that can't be skipped (it always can), guilt copy on repeated attempts
  (we reframe as gentle help, not "you failed again").
- *Data note:* every RecoveryEvent(type, result) logged — this loop IS the product hypothesis.

---

## 4. Early exit  (leaving before the timer ends)

**Path (normal mode):**
1. On Active Session `[tap "End session"]` (de-emphasized but findable).
2. **Exit-Reason** sheet: `[tap one of 5 reasons]`.
   - **Finished task** → Session Complete (counts as done). 2 taps.
   - **Emergency** → **immediate exit**, no lecture, no penalty. 2 taps, and the 2nd tap leaves
     *now*. (Emergency is sacred — spec §2.3.)
   - **Stuck / Tired** → Recovery flow (chance to stay, still free to leave).
   - **Need one app** → single-app pass picker → `[tap app]` → 5-min pass, timer keeps running.
     3 taps, session not abandoned.

**Path (strict mode):**
- Same entry. Non-emergency abort shows **honest consequences first** (spec §3.4): "This session
  won't count and your streak resets" → `[tap "End anyway"]` or `[tap "Keep going"]`. If tokens
  exist, redemption offered as a graceful alternative. **Emergency reason skips all of this and
  exits immediately.**
- "Need one app" in strict → kind denial + recovery offer. Emergency still available.

**Friction ledger:**
- *Intentional (and disclosed):* strict-mode consequence dialog — the user *chose* strict mode
  knowing this; showing consequences honors their past intent and is stated up-front at config
  time. Never a surprise.
- *Intentional:* asking "why are you leaving?" — one lightweight step that routes stuck/tired
  users to help. Framed "no judgment".
- *Non-negotiable:* **emergency exit is always ≤ 2 taps and never gated by strict mode or
  consequence dialogs.** Any build where emergency requires a hold-to-confirm, a delay, or a
  consequences screen is a policy violation (spec §2.3), not a design choice.
- *Accidental to avoid:* hiding "End session", making the exit reasons feel like an interrogation,
  penalty framing on emergency, dark-pattern "are you REALLY sure" loops.

---

## 5. Streak celebration & milestone

**Path:** Session completes (≥ 10 min) → **Session Complete** screen → streak increments inline
with a small grow animation → if a milestone hit (7/14/30/60/100 d, spec §3.5): "You earned a
lock-break token 🎟" + badge peek, celebrated **once** → `[tap Done]` or `[tap Start another]`.

**Tap count:** 0 extra taps to *see* the celebration (it's on the completion screen the user is
already on). 1 tap to leave.

**Friction ledger:**
- *Intentional (positive):* the celebration pause — a deliberate, earned moment; the one place we
  slow down to acknowledge the user. `celebrate` motion, rationed amber warmth.
- *Design guard against dark patterns:* celebrate **without** infantilizing (no cartoon mascot,
  no trophy-as-status pressure) and **without** streak-anxiety manipulation — a broken streak is
  reported neutrally later, never with a red guilt-scream. Lock-break tokens exist precisely to
  relieve streak pressure gracefully (streak intact via redemption).
- *Accidental to avoid:* multiple celebration modals stacking, achievement re-firing (unlock once
  — spec §3.8), blocking the "Done" CTA behind an animation, any "share your streak!" nag (no
  social in scope, and even later it must be opt-in).

---

## Global friction principles (apply to every flow)

- **Honest friction only.** Every point of resistance must be (a) something the user chose
  (strict mode, blocking their own apps), (b) required by policy (accessibility disclosure), or
  (c) genuinely protective (permission-loss notice). If none of those, it's a bug.
- **Emergency exit is uncompromised** on every screen a session can be left from — ≤ 2 taps,
  de-emphasized but AA-contrast and ≥ 48 dp, never delayed or hold-to-confirm.
- **One-tap repeat is uncompromised** — no step may be inserted before a proven-config restart.
- **No guilt anywhere** — copy redirects, never scolds; leaving is always allowed; data is never
  weaponized against the user.
- **Minimize taps on the common path, add taps only where the user asked for a boundary.**
