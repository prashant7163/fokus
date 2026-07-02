# M4 — Milestone Review: F-22 fixes + feature layer (F-07…F-12)

**Reviewer:** code-reviewer agent (independent; not part of the implementation conversation)
**Date:** 2026-07-02
**Scope:** commits `aecc49c..HEAD` (83329d7) — F-22 (D-013 P1 fixes), F-07 recovery, F-08 exit
flow + single-app pass, F-09 streaks/tokens/stats, F-10 onboarding + disclosure, F-11
home/config/active-session + getAppIcons, F-12 settings/theme/fonts, M2 fixes (deep-link path,
`SessionState.hydrated`), CI changes. All touched Dart/Kotlin source read in full; prior context:
`docs/reviews/F-18-core-review.md`, D-013…D-020.
**Verdict:** **approve-with-fixes**

**Verification run locally (not trusted from summaries):**
- `flutter analyze` — clean, 0 issues.
- `flutter test` — 219 tests, all green.
- `cd android && ./gradlew :app:testDebugUnitTest --rerun` — 41 tests across 5 classes
  (AttemptTracker 6, InterceptDecider 12, JournalCore 8, SessionServicePlan 12, StopDecision 3),
  0 failures (re-executed, not cache).

**Findings by severity: P0 = 0 · P1 = 2 · P2 = 7**

---

## The four F-18 P1s — verified fixed

All four D-013 rulings are implemented faithfully, with real (non-tautological) tests:

- **P1-A (attempt buffering)** — `AttemptJournal.kt` + pure `JournalCore`: prefs-persisted,
  unbounded-within-session journal for `distractionAttempt`/`recoveryRequested`; globally
  monotonic seq; replay on every attach; cleared only on ack (or next session start).
  `FokusEventBus` now splits restore-critical (small deque, no longer evictable by attempt
  bursts) from journalled traffic. Dart acks after the durable DB write
  (`session_controller.dart:541-573`) and dedupes replays via the `pkg|ts` guard. The
  at-least-once / crash-mid-replay / stale-ack cases are each unit-tested (`JournalCoreTest.kt`).
- **P1-B (expiry clears cache)** — `SessionServicePlan.clearsCacheOnStop` (true only for
  `Expired`) wired through `SessionForegroundService.stopForPlan` (`:104-109`); the journal is
  deliberately *not* cleared there (un-acked attempts survive), which is the right call.
- **P1-C (stop tiebreak)** — `StopDecision.kt`: stop is unconditional, mismatch emits
  `stopMismatch(requestedId, liveId)`; Dart reconciles by aborting an orphaned live session
  (`session_controller.dart:608-627`). Contract addendum present in CONTRACTS §1 (D-014).
- **P1-D (attribution)** — `_attributeAttempt` (`session_controller.dart:581-601`) uses strict
  window containment over `sessionsStartedBefore(ts)`; the "most recent regardless of window"
  path is gone and `getMostRecentSession` now carries a warning doc comment
  (`session_repository.dart:140-143`). The specific misattribution scenario from F-18 is now a
  regression test (`session_controller_test.dart` "D-013 P1-D: buffered attempt from a dead
  session is NOT misattributed"). Note the window logic is sound even for the grace-minute
  overlap: a session started *after* ts is excluded by `startTime <= ts`, so a late-delivered
  attempt can never leak forward into a newer session.

---

## P0 — ship-blockers

None.

## P1 — fix before merge

### P1-1 · CONTRACTS §1 is missing `getAppIcons` — D-019 claims an addendum that was never written
`docs/CONTRACTS.md:10-23` — the binding `BlockingAdapter` interface lists `grantAppPass` (D-015)
and `ackEvents` (D-014) but **not** `getAppIcons`, while D-019 states "CONTRACTS §1 addendum:
`getAppIcons(packageNames) → Map<pkg, PNG bytes>`". The method exists on both sides of the seam
(`lib/core/blocking/blocking_adapter.dart:170`, `BlockingChannelHandler.kt:106-113`) and is
consumed by F-11. This is pure doc drift, but CONTRACTS is the rubric every future agent codes
against, and the review brief says to flag any drift however small. One-paragraph fix; no code
change.

### P1-2 · Exit/recovery screens can dead-lock all CTAs on a thrown terminal call (`_resolving` latch never resets)
`lib/features/exit/presentation/exit_screen.dart:80-152, 195-211, 302-307` — every terminal path
sets `_resolving = true` *before* awaiting a fallible call and never resets it on error:
- `_grantPass` → `SessionController.grantAppPass` is **deliberately not best-effort** (it
  rethrows channel errors, `session_controller.dart:370-373` — "pretending it was granted would
  gaslight the user"), yet the screen has no catch;
- `_abortNow`/`_pick`/`_redeemLockBreak` can throw `StateError` when the session transitions
  under the user's finger (timer end racing an abort → illegal machine transition;
  `redeemLockBreak`'s token/cap re-check);
- the screen sits inside `PopScope(canPop: false)` whose back handler is `_stay()`, itself
  `_resolving`-guarded.

One exception ⇒ every button *and system back* is permanently dead on the one screen the user
must be able to leave (the strict-mode escape hatch). The DB/state are not corrupted — this is a
UI trap, not a data bug — but the failure mode contradicts the flow's own "never trap the user"
principle. `RecoveryScreen` (`recovery_screen.dart:107-163`) has the same latch pattern with
less fallible calls. Contrast: `home_screen.dart:63-76` and `session_config_screen.dart:62-75`
already do `try/finally { _starting = false; }` — apply the same discipline here, plus a
user-visible failure message for the non-best-effort `grantAppPass`.

## P2 — notes / fix opportunistically

- **P2-1 · `fokus://app/exit?confirm=<reason>` is externally forgeable and auto-aborts; unknown
  reasons default to a `stuck` abort.** The `fokus` scheme intent filter is `BROWSABLE`
  (`AndroidManifest.xml:45-50`), so any app or web link can cold-open `/exit?confirm=stuck`; on
  a non-strict session `_reconcile` aborts immediately with no in-app tap
  (`exit_screen.dart:64-76`), writing an exit-reason row the user never chose (hypothesis-data
  pollution). Worse, an *unrecognized* confirm value maps to `ExitReason.stuck` instead of
  falling back to the reason sheet (`exit_screen.dart:39-46`). The legitimate confirm entry is
  always internal `context.go` navigation (`recovery_screen.dart:131-134`) — it never needs to
  be reachable from the Android intent filter. Suggest: unknown name → show the sheet; and
  treat a confirm arriving via cold deep link with more suspicion (or require one in-app tap).
- **P2-2 · Abandoned recovery leaves the session in `recoveryInProgress` for its remainder.**
  Back/close from a module logs the event as `exited` but never composes resume
  (`recovery_controller.dart:77-82`, `recovery_screen.dart:170-176`), and the session screen
  renders `recoveryInProgress` identically to `active`. Everything self-heals (timer end, exit
  "stay", shrink all compose resume first), and `recovery_events` data is correct — but the
  session row's status is semantically wrong for potentially hours, and anything future that
  keys on `active` vs `recoveryInProgress` will inherit the skew. Cheap fix: abandon →
  `resumeRecovery()` when still running.
- **P2-3 · `BlockedSetCache.startSession` clears the attempt journal before Dart has necessarily
  durably written the replayed entries.** (`BlockedSetCache.kt:87-94`.) The normal order (attach
  → replay → serial DB writes → ack) makes this safe, but a crash between a user-initiated
  start and the in-flight replay writes loses those attempts — a narrow re-opening of the P1-A
  window. Clearing only entries `≤` the highest *acked* seq at start would close it fully.
- **P2-4 · "Exit reason logged on every early-exit attempt" is last-write-wins.** The schema has
  a single `focus_sessions.exitReason` column, so `recordExitReasonAttempt`
  (`session_controller.dart:447-451`, `exit_screen.dart:99`) overwrites prior attempts, and a
  completed session can carry a stale `exitReason` from an attempt the user then abandoned.
  This matches the CONTRACTS §3 schema (so it is compliance-by-schema), but the §2 wording
  ("logged on every early-exit attempt") implies history. Confirm intent with the tech-lead or
  reword the contract; per-attempt history would need a table, not a column.
- **P2-5 · `getAppIcons`/`getInstalledApps` do bitmap draw + PNG compression on the platform
  main thread** (`BlockingChannelHandler.kt:132-160`). For a typical blocked list this is tens
  of ms of jank at home-screen build; move to a background executor and post the result. The
  intercept hot path is unaffected (no channel traffic — verified unchanged).
- **P2-6 · A failed `start()` is invisible to the user.** `SessionController.start` rethrows
  (correctly), but `session_config_screen.dart:62-75` / `home_screen.dart:63-76` let the error
  escape to the zone handler — the Start button just silently does nothing. Show a snackbar in
  the catch.
- **P2-7 · Doc-rot in core files that contradicts shipped decisions.**
  `InterceptActivity.kt:33-34` still says "Plus Jakarta Sans is not bundled yet (open ruling
  with Prashant)" while line 289 loads the bundled font per D-020;
  `session_controller.dart:607` says "F-08 refines exit reasons" (F-08 shipped);
  `settings_screen.dart:31` hardcodes `_version = '0.1.0'` with a bump-together comment
  (package_info_plus would remove the trap). Also `session_complete_screen.dart:175-185`
  recomputes actual minutes from `DateTime.now()` instead of reading the persisted `actualMin`
  (and bypasses `clockProvider`) — correct today, but a second source of truth.

---

## Contract compliance

- **BlockingAdapter seam — MATCH except P1-1.** `ChannelBlockingAdapter` ↔
  `BlockingChannelHandler` payloads align field-for-field for all ten methods, including the
  new `grantAppPass {packageName, endEpochMs}`, `ackEvents {upToSeq}`, `getAppIcons
  {packageNames} → Map<pkg, bytes>`. Event envelope matches: `seq` is emitted for both
  journalled event types and parsed as optional; `stopMismatch {requestedId, liveId}` matches
  D-014's addendum text. Unknown types/kinds still degrade to skip+log.
- **State machine — intact.** No new edges. Shrink is a config change on `active` (D-017
  reasoning holds — `plannedMin = elapsed + 10` keeps `actualMin` honest, tested); lock-break
  lands as `completed` + `CompletionReason.lockBreak` via the existing finishTask edge (D-017);
  recovery-entered-from-exit composes legal transitions (resume → terminal), never invents one.
  Terminal composition on timer-end-during-recovery is preserved.
- **Schema — v2 as ruled.** `recovery_events.note` added with a real `onUpgrade` migration
  (`database.dart`); the D-014 open item is closed exactly as D-017 specified. The
  `.references()` → `customConstraint` change is justified in-code (drift_dev ≤2.31 silently
  dropping REFERENCES) and restates NOT NULL correctly. Pre-release, so no legacy-install FK
  divergence to worry about.
- **Business constants — MATCH.** Durations 15/30/60/120 + custom 5–480, ≥10-min streak
  qualification, milestones 7/14/30/60/100 → 1/2/3/5/10, weekly redeem cap 3, 5-min pass —
  all read from `FokusConstants` (single source), all mirrored in CONTRACTS §4 including the
  D-015 pass row.
- **Analytics §5 — still correctly absent.** No event sink invented; no new writes beyond the
  contracted tables (re-confirmed by reading every repository call in the diff).

## Reliability of the core loop (top priority)

The F-22 changes strengthen exactly the seams F-18 flagged: attempts are now crash-proof
(persisted journal, at-least-once, idempotent consumer), native/Dart liveness disagreements
always resolve in Dart's favor with a diagnostic, and natural expiry leaves no stale native
state for `BootReceiver` to misread. The single-app pass is genuinely native-persisted
(`BlockedSetCache` prefs), wall-clock-expired with zero timers, cleared on start/stop/shrink,
and the decider change is 2 comparisons on the hot path — the < 200 ms budget is untouched.
Policy stays in Dart: the 5-min constant, strict gating (throws), one-pass-at-a-time, and the
never-outlives-session clamp are all controller-side and tested (`single_app_pass_test.dart`,
8 cases). The M2 findings were fixed at the right layer: deep-link routes moved into the URI
*path* with the why documented at the constant (`InterceptActivity.kt:361-366`), and
`SessionState.hydrated` gates every deep-linked decision point (exit `_reconcile`, recovery
`_ensureHydrated`) so the pre-hydration `idle` can no longer be misread as "no session".
Remaining reliability risk is unchanged from D-012: OEM battery killers stay a closed-track
exit criterion.

## Privacy / policy

Clean, and improved. Onboarding order is exactly the Play-safe sequence: value pages →
full-screen disclosure → consent gate → only then any settings redirect; the "Not now" path
provably fires zero redirects and the F-10 test suite asserts `requestedPermissions` stays
empty pre-consent (real assertions against the fake adapter, not widget-presence checks). The
disclosure copy is placeholder-marked *inside the string* in both locales (`[PLACEHOLDER …]` /
`[PLATZHALTER …]`) so it cannot ship silently — the D-018 release-blocker flag on Prashant's
verbatim approval stands. No INTERNET permission in the main manifest, no new manifest
permissions at all in this range; new deps (shared_preferences, flutter_svg,
integration_test, bundled OFL fonts with license surfaced in-app) are local-only. `getAppIcons`
reads launcher icons of apps the *user* selected — no QUERY_ALL_PACKAGES, launcher-intent
queries only. Behavioral data still never leaves drift.

## Performance

Intercept path untouched except two in-memory comparisons (pass check) — structurally still
inside the < 200 ms target; journal append on intercept is one prefs read + `apply()` (async),
acceptable. `AttemptJournal` rewrites the whole JSON array per append (O(n²) per session) —
fine at human attempt rates, worth remembering if telemetry ever shows journal abuse (the
D-013 revisit trigger). Main-thread icon encoding is P2-5. Streak derivation scans all
completed sessions on every read — correct-by-construction per D-017 and fine for MVP volumes.

---

## Code-health trajectory

Still trending the right way, and the discipline survived a 10×-surface expansion: every new
decision worth testing was factored pure first (`JournalCore`, `StopDecision`, `ExitFlow`,
`StreakEngine`) and unit-tested against independent expectation tables; the Dart suite grew
from ~60 to 219 tests and the new ones assert behavior (rows written, events acked, redirects
*not* fired) rather than widget existence. The review-fix loop is genuinely closing: all four
F-18 P1s landed with regression tests that encode the original failure scenario, and M2/F-11
emulator findings were fixed with the "why" documented at the fix site. The debt that exists is
concentrated and honest: error-handling asymmetry in the two no-escape screens (P1-2 — the
feature layer hasn't yet absorbed the core's own "never silent" standard for its *failure*
paths), a deep-link trust boundary nobody has owned yet (P2-1), and a thin layer of stale
comments left behind by fast decision turnover (P2-7). Fix the two P1s — one is a paragraph of
documentation, the other a try/finally pattern already used two files away — and this codebase
enters the beta-prep milestones in better shape than most MVPs enter review.
