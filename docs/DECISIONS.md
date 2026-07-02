# FOKUS — Decision Log (ADR-lite)

Append-only. Format: ID, date · time (Europe/Zurich), decision, why, revisit-when.
Times before 2026-07-02 02:30 retrofitted (≈ where not tied to a commit).

## D-001 · 2026-07-01 · Flutter shell + native Kotlin blocking core
Cross-platform UI for future iOS reuse; blocking stays 100 % native (spec principle "native
where it matters"). Chosen over React Native (cleaner platform-channel story next to a
long-lived foreground service) and over pure Kotlin/Compose (would strand the iOS path).
**Revisit when:** iOS work starts, or if channel overhead measurably hurts intercept latency.

## D-002 · 2026-07-02 ≈00:10 · Android-only first; iOS deferred
Apple FamilyControls entitlement is an external approval with no SLA; Android is fully within
our control. Validate the core hypothesis (recovery → resume rate) on Android before spending
on iOS. **Revisit when:** Android closed-track metrics exist.

## D-003 · 2026-07-02 ≈00:10 · Scope = Phase 1 + local-only Phase 2 subset
No Firebase, no social rooms, no web unlock portal, no billing until core loop is validated.
Everything in scope must run offline. **Revisit when:** F-19 QA passes and early retention
data is in.

## D-004 · 2026-07-02 ≈00:20 · Publish under Hoffely GmbH account
Existing org account with published app (Hofferly): production access already unlocked, the
12-tester/14-day closed-test mandate for new personal accounts does not apply, review track
record exists. Package id `ch.hoffely.fokus`. A voluntary closed test still happens — for
recovery-metric data, not for Google.

## D-005 · 2026-07-02 ≈00:20 · Docs split: engineering constitution committed, planning local
`CLAUDE.md` + `docs/` are committed — worktree agents and fresh clones must self-orient from
committed files. Business/planning material (PRD blueprint, paperwork tracker, strategy)
stays in gitignored `planning/`. **Revisit when:** a second full-time contributor joins.

## D-006 · 2026-07-02 ≈00:20 · Hybrid execution model
Single-author inline work for the coupled core (blocking service, session engine, intercept);
scoped agents for leaf modules and independent review; fresh sessions between phases enabled
by this docs set. Agents brief = files + contract + done-criteria, return summaries.

## D-007 · 2026-07-02 00:45 · Named agent roles in docs/agents/
Six roles: PM, tech-lead, mobile-developer, code-reviewer, ux-designer (spawnable briefs) +
orchestrator (main session, documented in CLAUDE.md). Files double as Claude Code custom
agents if copied to `.claude/agents/` (that path is write-protected in Cowork sessions).
PM drafts, Prashant decides; only tech-lead may change contracts; reviewer is read-only.
**Revisit when:** role boundaries cause friction or a real human joins the team.

## D-008 · 2026-07-02 01:07 · Structure v2 per Prashant's review
agents/ and design/ live at project root; docs/ gains CHANGELOG.md (what/when) and
DISCUSSIONS.md (MOM, orchestrator standing duty — not an agent, since subagents cannot see
conversations). fokus-specs.md at root is the binding build spec; blueprint in planning/
remains vision. ux-designer role upgraded to graphics-first (opus). Destructive commands
require Prashant's approval; non-destructive bash is unrestricted in-project.
**Revisit when:** doc set feels heavy for the team size.

## D-009 · 2026-07-02 ≈01:35 · Brand direction v2 (Prashant)
Drop blue/indigo entirely. App icon: dark grey (charcoal) background, orange circle + center
dot. Overall system: neutral-to-light palette, light theme default, orange as the single
accent. Supersedes the v1 indigo palette and the "dark as hero" question. Branding must be
distinctive in a crowded wellbeing segment — lead with differentiators (in-flow recovery,
compassionate exits, earned lock-breaks, offline privacy), not generic calm-app tropes.
**Revisit when:** user testing or store-listing A/B says otherwise.

## D-010 · 2026-07-02 ≈01:35 · Working model: main session = discussion, worker sessions = build
Prashant opens separate Cowork sessions for heavy build work (they coordinate via CLAUDE.md,
TASKBOARD claiming, and MOM); the main session stays available for live discussion. Roadmap
structure in docs/ROADMAP.md; execution state only in TASKBOARD.md.
**Revisit when:** taskboard claiming conflicts appear.

## D-011 · 2026-07-02 02:14 · Prashant's rulings on audit items D-C, D-D, D-E
1. **Streaks (D-C):** lock-break redemptions and sub-10-min sessions never *earn* a streak
   day. A lock-break **excuses** the day: streak neither resets nor increments. Only a
   completed ≥ 10-min session increments.
2. **No `paused` state (D-D):** the session state machine stays as CONTRACTS §2 — the
   temporary 5-min single-app pass in non-strict mode is NOT a pause; the timer keeps running.
3. **Always-on apps (D-E):** user allowlist, asked during onboarding (music/navigation
   examples), editable in settings. Allowlisted apps are never blockable.
Remaining audit items: D-A/D-B (priority semantics — editorial, PM applies), D-F (AI
micro-coaching surface) still open.
**Revisit when:** beta feedback on streak fairness or allowlist abuse.

## D-013 · 2026-07-02 11:54 · F-18 review triage — event-delivery + liveness rulings
Reviewer verdict approve-with-fixes (0 P0 / 4 P1 / 6 P2; docs/reviews/F-18-core-review.md).
Orchestrator rulings on the two contract-adjacent P1s:
1. **P1-A (attempt buffering):** distraction attempts must never drop. Split native buffering:
   critical events (permissionLost, sessionRestored) keep the small in-memory deque;
   distractionAttempt/recoveryRequested go to a persisted native journal (prefs/file),
   unbounded within a session, replayed on Dart attach, cleared only on ack.
2. **P1-C (liveness tiebreak):** Dart decides, always. `stopSession` with a mismatched id
   stops whatever native session is running (never silently no-ops) and emits a diagnostic
   event with both ids.
3. **P1-B:** natural native expiry must clear BlockedSetCache. **P1-D:** replayed attempts
   attribute by timestamp containment (ts within a session's start/end), never
   "most recent session"; unmatched attempts are logged and discarded.
P2s: fix opportunistically during F-07…F-12. Fixes tracked as F-22.
**Revisit when:** journal shows abuse (unbounded growth) or tech-lead review disagrees.

## D-012 · 2026-07-02 03:00 · Device testing = Android emulator; OEM risk shifts to closed track
No physical Android device available. M2 verification runs on the Android Studio emulator on
Prashant's Mac (orchestrator can drive Studio's Run button and interact with the emulator via
screen control, with Prashant's per-app approval). Emulator can verify: blocking intercept +
latency, accessibility-service flow, session resilience (process kill, cold boot), permission
revocation, full UX. Emulator CANNOT verify: OEM battery-killer behavior (Samsung/Xiaomi/
OnePlus), real-device performance. That residual risk moves to the closed-track testers —
their devices are the OEM test fleet, and QA row 9 (battery optimization) is re-tagged as a
closed-track exit criterion instead of a pre-release gate.
**Revisit when:** a physical device (ideally Samsung or Xiaomi) becomes available — even
borrowed for a week before public launch.
