# FOKUS — Build Specification

**Status:** Binding for current scope · **Derived from:** Product Requirements Blueprint v1.0
(planning/, local-only) · **Owner:** Prashant (product), tech-lead agent (technical seams)

This document says exactly WHAT we are building now. The blueprint is vision; this is scope.
If blueprint and this file disagree, this file wins for the build. Contracts (interfaces,
schemas, constants) live in `docs/CONTRACTS.md` — this spec defines behavior.

---

## 1. Scope

**IN (this build):** Android app, Flutter + native Kotlin blocking core. App blocking during
timed focus sessions · task anchor · recovery system (5 modules) · structured exit flow ·
streaks + lock-break token earning · today stats · onboarding with permission setup ·
presets + recurring schedules · stats dashboard (day/week/month) + focus score · achievements ·
post-session micro-feedback · local rule-based AI suggestions.

**OUT (needs Prashant's explicit go):** iOS. Firebase/any backend. Accounts/login. Social
rooms. Web unlock portal. Payments/premium gating. Parental mode. Gamification forest.
Cloud AI. Everything runs offline; the app has zero network calls in this scope.

## 2. Product principles (binding on all design/copy decisions)

1. Compassionate, not punitive — redirect, never scold. No guilt language anywhere.
2. The user chose this friction — honor their past self's intent, respect their present agency.
3. Emergency exit always exists and is always findable.
4. Behavioral data never leaves the device.

## 3. Feature specifications

### 3.1 Focus Session
- Configure: apps to block (from installed-app picker), duration (15/30/60/120 min or custom
  5–480 min), task anchor (free text, optional but prompted, max 80 chars), strict mode on/off.
- One-tap repeat: home screen primary CTA re-runs last configuration unchanged.
- Active screen: countdown dominant, task anchor visible, blocked-app icon row, progress ring,
  rotating encouragement line (from l10n set, changes every 90 s), session distraction count,
  de-emphasized "End session" affordance.
- States and transitions: exactly as CONTRACTS.md §2. Timer is wall-clock anchored
  (endEpochMs), not tick-counted — survives process death and doze.
- Completion: full-screen celebration, stats delta, streak update, feedback prompt (1 in 3).

### 3.2 Blocking behavior
- Native detection via AccessibilityService; blocked set cached natively; intercept < 200 ms.
- Intercept screen shows: app name + icon ("Instagram can wait"), time remaining, task anchor,
  primary "Return to focus", secondary "I'm stuck" → recovery, tertiary quiet "Emergency exit".
- Every intercept logs a DistractionAttempt. Repeated attempts (≥ 3 in 5 min) surface the
  recovery suggestion proactively on the intercept screen.
- FOKUS itself, system UI, phone/dialer, and default launcher are never blockable. Currently
  ringing/active calls are never intercepted.

### 3.3 Recovery system (the differentiator — polish over feature count)
Five modules, all offline, each ending in "Ready to continue?" → Resume / End session:

| Module | Behavior | Duration |
|---|---|---|
| Breathe | Animated circle: inhale 4 s, hold 4 s, exhale 4 s; 2 cycles minimum | 30 s |
| Task reset | "What's the next smallest step?" — text input, saved to session notes | ~15 s |
| Stand & stretch | Illustrated movement prompt, gentle timer | 45 s |
| Water break | Guided reset prompt with calm animation | 45 s |
| Shrink session | Offer to reduce remaining time to 10 min ("finish small") | instant |

- Entry points: intercept "I'm stuck", exit-flow reasons stuck/tired, proactive (3.2).
- Every invocation logs RecoveryEvent(type, result resumed|exited). This data is sacred —
  it's the product hypothesis.

### 3.4 Structured exit flow
On early-end attempt, ask "Why are you leaving?" with exactly five options:
finished task (→ counts as completed) · emergency (→ immediate exit, no lecture, no penalty) ·
stuck (→ recovery) · tired (→ recovery) · need one app (→ normal mode: 5-min single-app pass,
session timer keeps running; strict mode: denied with kind copy).
Strict mode shows consequences before confirming an abort: session marked incomplete + streak
impact. If lock-break tokens exist, offer redemption (3.5) as a graceful alternative.

### 3.5 Streaks & lock-break tokens
- Streak day = ≥ 1 completed session of ≥ 10 min in the local calendar day. Timezone changes
  use the device's current zone; a day never counts twice.
- Milestones award tokens per CONTRACTS.md §4 (7 d → 1 … 100 d → 10) plus badges.
- Redeeming a token ends/skips one session with status completed-via-lockbreak: streak intact,
  logged distinctly. Max 3 redemptions per calendar week. Tokens never expire, never purchasable.

### 3.6 Stats & focus score
- Today view (MVP): focus minutes, distractions blocked, most-intercepted app, current streak.
- Dashboard: day/week/month charts — focus time, sessions completed vs aborted, distraction
  count, recovery resume-rate. All computed from local DB.
- Focus score (0–100, weekly): 50 % completion rate + 30 % focus volume vs personal 4-week
  baseline + 20 % recovery resume-rate. Formula is v1 — mark "beta" in UI; revisit with data.

### 3.7 Presets & schedules
- Preset = named bundle: app list, duration, strict mode, recovery on/off. CRUD, no limit in
  this scope (free-tier caps are Phase 3, not built now).
- Schedule = preset + days-of-week + start time (+ duration). WorkManager-triggered
  notification 5 min before, auto-start at time unless user cancels from the notification.
  A schedule never traps: auto-started non-strict sessions keep the normal exit flow.

### 3.8 Achievements
Eight from blueprint: First Session, Early Bird (< 7 am), Night Owl (> 10 pm), Distraction
Destroyer (100 blocks), Recovery Champion (10 resumes), Iron Will (10 strict completions),
Exam Hero (20 h in 7 days), Two Week Warrior (14-day streak). Unlock once, celebrate once.

### 3.9 Micro-feedback
Post-session, sampled 1 in 3: "How was this session?" 😊/😐/😔; on 😔 ask one follow-up
(too long / interrupted / blocking failed / other). Stored locally; no transmission.

### 3.10 Local AI suggestions ("Smart Suggestions — beta")
Rule-based on ≥ 14 days of local data, all opt-in via settings toggle:
- Distraction window: if attempts cluster in an hour-bucket ≥ 4 of last 7 days → suggest a
  session 15 min before that window.
- Optimal length: if completion rate for duration X ≥ 25 points higher than for longer
  sessions → suggest X.
- Recovery ordering: sort recovery menu by personal resume-rate (min 5 samples per module).
- Max one suggestion per day; each shows "why" ("based on your last 2 weeks"); dismissible.

### 3.11 Onboarding & permissions
Three value screens (copy per blueprint §6.7) → **prominent accessibility disclosure screen
(before any settings redirect; explicit consent button; Play-policy-critical wording — PM
drafts, ships verbatim)** → permission checklist (accessibility, usage access, notifications,
battery exemption) each with plain-language why + status badge → app picker → done.
"I'll do this later" → limited mode: timers work, blocking clearly labeled inactive.
Permissions health surfaces on home + settings whenever degraded.

## 4. Non-functional requirements

| Requirement | Bar |
|---|---|
| Intercept latency | < 200 ms from foreground change to intercept visible |
| Session resilience | Survives process kill, reboot, doze; restored within 5 s of boot |
| Permission loss mid-session | Detected ≤ 30 s, user notified, session → failedPermissions — never silent |
| Offline | 100 % of scope functional with radios off |
| Performance | Cold start < 2 s on mid-range device; 60 fps on active-session screen |
| Battery | Foreground service + AccessibilityService overhead < 2 %/h during session |
| Accessibility | TalkBack complete, touch targets ≥ 48 dp, WCAG AA contrast |
| Localization | EN + DE from day 1; all strings in ARB |
| Privacy | Zero network permission usage in this scope; no analytics SDK |

## 5. Acceptance

A feature is done when: its taskboard done-criteria pass · behavior matches this spec ·
CONTRACTS.md is honored · tests per CONVENTIONS.md are green · and the relevant QA-checklist
rows (planning/) pass on-device. Spec changes: propose → Prashant approves → PM/tech-lead
updates this file + DECISIONS entry. No silent drift.
