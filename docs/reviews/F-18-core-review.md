# F-18 — Milestone Review: FOKUS Core (F-02…F-06)

**Reviewer:** code-reviewer agent (independent; not part of implementation)
**Date:** 2026-07-02
**Scope:** commits `f846a2d..HEAD` on `main` (F-02 Drift schema, F-03/04/05 Kotlin core, F-06 Dart engine) + F-01 scaffold where it touches the core.
**Verdict:** **approve-with-fixes**

> **Environment constraint honored, stated plainly:** the sandbox cannot reach pub.dev/maven,
> so `flutter analyze`, `flutter test`, `./gradlew testDebugUnitTest`, and `flutter build apk`
> were **not** run here. Every file in scope was read in full. XML (13 files), the CI YAML, and
> the Dart/Kotlin test suites were machine-parsed / read. All correctness findings below are from
> reading, not execution — **CI remains the real green-gate** and none of the P0/P1 items are
> "does it compile" doubts; they are logic/contract findings that a passing build would not catch.

---

## Summary

This is strong, disciplined work. The Dart↔Kotlin seam matches field-for-field. The state machine
is encoded verbatim from CONTRACTS §2 and tested exhaustively and non-tautologically (every
state×trigger pair, legal and illegal, with an independent expectation table). Wall-clock anchoring
is real (remaining always derived from `endEpochMs`, never accumulated) and is exercised for
retroactive completion after process death and reboot. Privacy/policy posture is clean: no network
permission in the main manifest, `canRetrieveWindowContent=false`, no `QUERY_ALL_PACKAGES`,
window-state-only accessibility claim that the code actually respects.

The findings that hold it back from a clean approve are all in the **event-buffering / data-loss**
and **native-cache-lifecycle** seams — exactly the couplings the brief flagged. None is a
compile-blocker; two (P1-A, P1-B) can silently lose the "product hypothesis" data or leave stale
native state, which is why this is approve-*with-fixes* rather than approve.

**Findings by severity:** P0 = 0 · P1 = 4 · P2 = 6

---

## P0 — ship-blockers

None.

---

## P1 — fix before merge

### P1-A · Bounded event buffer silently drops distraction attempts (the product hypothesis data)
**`FokusEventBus.kt:21,71`** — `PENDING_LIMIT = 16`; `emit(...)` does
`buffered && pending.size < PENDING_LIMIT -> pending.addLast(event)` and otherwise **drops the
event with no signal**. `distractionAttempt` is buffered (correctly), but while the Flutter engine
is down (boot, process-kill window, or simply the app never foregrounded) the 17th+ attempt is
lost forever. Per-app debounce is only 1.5 s (`InterceptDecider.DEBOUNCE_MS`), so a user cycling
through several blocked apps repeatedly can exceed 16 buffered attempts in well under a minute.
fokus-specs §3.2 and the F-05 MOM both call this data "the product hypothesis" / "sacred."
The buffer also mixes restore-critical events (`sessionRestored`, `permissionLost`) with
high-volume attempts in the *same* 16-slot deque — a burst of attempts can evict/starve a
`permissionLost` that must never be missed (fokus-specs §4: "never silent").
**Fix direction:** separate the restore-critical channel (must never drop; tiny, bounded by kind)
from the attempt channel; for attempts, either persist to a native scratch store (a
SharedPreferences/append log the engine drains on attach) or raise/instrument the drop so it is
counted, never silent. At minimum, drop-count telemetry so loss is observable. Decide with
tech-lead: this borders on a resilience-contract point.

### P1-B · Natural (native-only) session expiry never clears `BlockedSetCache` prefs
**`SessionForegroundService.kt:93` / `onTick` → `stopAndRemove()`** and
**`SessionServicePlan` `Expired`** stop the service but **do not call
`BlockedSetCache.clearSession()`**. The expired session config persists in SharedPreferences.
Nothing re-blocks (both `InterceptDecider` and `SessionServicePlan` guard on `now >= endEpochMs`),
so this is not a "blocks after expiry" bug — but the stale row lingers until Dart happens to run
`stopSession` (which *is* guarded by `session?.id == sessionId`, `BlockingChannelHandler.kt:70`)
or a new `startSession` overwrites it. If the process is killed after native expiry and before
Dart ever reconciles, `BootReceiver` reads a stale (expired) session; it currently handles it
(`planFor` → `Expired` → no restart, `BootReceiver.kt:23`), so the blast radius is limited to
prefs hygiene and any future code that trusts `BlockedSetCache.session != null` as "a session is
live." **Fix:** clear the native cache on the `Expired`/timer-end branch of the service so native
and Dart agree that no session is live, independent of who runs first.

### P1-C · `stopSession` is a silent no-op on any id mismatch
**`BlockingChannelHandler.kt:70`** — stop only proceeds when
`BlockedSetCache.session?.id == sessionId`. Dart's `_terminate` (session_controller.dart:458)
already wrote the DB terminal row and treats the native call as best-effort (`_silently`), so a
mismatch means the DB says "terminal" while native may still hold a *different* armed session and
keep blocking. This is the "who wins if native and Dart disagree about liveness" case the brief
called out. In the normal path the ids match; the risk is a re-arm/restore race where native holds
session B while Dart terminates session A. **Fix:** either clear unconditionally on `stopSession`
(the foreground service is single-session by design), or have Dart reconcile: if native reports a
different live session on next event, disarm it. Confirm intended tiebreak with tech-lead —
CONTRACTS §2 says "Dart decides," so Dart's terminal decision should win and native should be
forced to drop whatever it holds.

### P1-D · Replayed-attempt attribution can attach to the wrong session after reboot
**`session_controller.dart:353` `_logAttempt`** — when no live session, orphan attempts are
attributed to `getMostRecentSession()` (most recent by `startTime`, **any status**,
session_repository.dart:132) if `ts` falls within `[start, end + 1 min]`. After a reboot where a
*new* session is started, and a buffered attempt from the *previous, dead* session replays, the
"most recent" session is the new one. If the old attempt's `ts` happens to fall inside the new
session's window (clock skew, overlapping windows, or a quick relaunch-restart), it is misattributed
to the new session, corrupting per-session distraction counts. The `+1 min` grace widens this. The
existing test (`replay after retroactive completion attributes by ts window`) only covers the
single-session case. **Fix:** attribute by the session whose window *actually contains* `ts`,
preferring an exact/terminal match over "most recent"; query candidate sessions by time window
rather than taking the single most-recent row. Low probability, but it silently corrupts the
hypothesis dataset when it hits.

---

## P2 — notes / follow-ups

- **P2-A · Manual clock change extends/shortens a session unbounded.**
  `endEpochMs` is `System.currentTimeMillis()`-based on both sides, so a user setting the clock
  *backward* mid-session makes `remaining` grow and the session run past its intended real
  duration; forward makes it complete early/retroactively. DST/timezone shifts are fine (epoch is
  monotonic across zone changes), but a manual wall-clock set is not defended. Spec §3.1 promises
  "survives DST" — it does; it says nothing about adversarial clock sets. Accept as known behavior
  or add an elapsed-based sanity clamp; note it in DECISIONS so it is not a surprise later.
  (session_controller.dart `syncWithClock`; SessionServicePlan.planFor.)

- **P2-B · `getActiveSession()` assumes at most one non-terminal row** (`..limit(1)`,
  session_repository.dart:60). The state machine should guarantee this, but nothing at the DB layer
  enforces "only one active session." A partial-write race (P1-C-adjacent) could leave two. Consider
  a guard/assert or a unique partial index; low likelihood given the pendingStart lock.

- **P2-C · CONTRACT GAP (already escalated, restated for the record):** CONTRACTS §5 lists 10
  analytics events; §3 defines no table/sink. F-06 correctly invented nothing and writes nothing.
  This is the right call — flagging so the milestone sign-off does not read the absence as a bug.
  Needs the tech-lead/telemetry ruling (D-012-adjacent) before any feature depends on these events.

- **P2-D · `distraction_attempts.recoveryInvoked` is never set by the core.** The column and
  `markRecoveryInvoked` exist (distraction_repository.dart:28) but nothing in F-05/F-06 links an
  intercept's attempt row to a subsequent `recoveryRequested`. The intercept fires
  `emitDistractionAttempt` then, separately, `emitRecoveryRequested` with no correlation id, so
  Dart cannot mark the originating attempt. Fine for now (F-07 owns recovery), but the correlation
  is impossible with the current event shapes — flag for F-07 so the flag isn't quietly stranded.

- **P2-E · `getMostRecentSession` is documented as "one-tap repeat (F-11)" but is load-bearing in
  attribution.** (session_repository.dart:131 vs its use at session_controller.dart:353.) Dual-purpose
  helper; see P1-D. At least update the doc comment so a future editor doesn't change its ordering
  semantics for F-11 and silently break attribution.

- **P2-F · `specialUse` FGS subtype string is a Play-review liability, not a code bug.**
  The declared subtype (AndroidManifest.xml:90) is honest and well-written, but `specialUse` is the
  category Google most often rejects. This is the correct technical choice (no standard type fits
  app-blocking timers), but it must be paired with the Play Console justification at submission.
  Track as a release-gate item, not a merge blocker.

---

## Contract compliance (verified by reading, field by field)

- **Channel payloads — MATCH.** `BlockingChannelHandler.kt` header contract vs
  `ChannelBlockingAdapter`: `getPermissionStatus` (Map keyed by `PermissionKind.name`, all four
  kinds), `requestPermission {kind}`, `getInstalledApps [{packageName, appName}]`,
  `setBlockedApps {packageNames}`, `startSession {id, endEpochMs, taskAnchor?, strictMode}`,
  `stopSession {sessionId}` — all align 1:1. Event envelope `{type, ...}` and payload keys
  (`pkg`/`ts`, `kind`, `sessionId`) match `FokusEventBus` emitters against `_parse`. Unknown types
  and unknown permission kinds degrade to skip+log, not crash — correct forward-compat posture.
- **State machine — MATCH, exactly 8 edges, ONLY those.** `SessionMachine.transitionTable` equals
  CONTRACTS §2; `session_machine_test.dart` proves it with an independent table and an
  every-illegal-pair sweep, plus an edge-count assertion. Terminal composition (resume→terminal
  from recovery) is done in the controller, not as a new edge — faithful to the contract's shape.
- **Schema — MATCH.** All 11 tables at schemaVersion 1; `schema_contract_test.dart` pins table and
  column names verbatim from §3, including the `feedback_entries.text` SQL-name preservation and
  the `streak_summary` singleton. `PRAGMA foreign_keys = ON` set in `beforeOpen`.
- **D-011 mutual exclusion — MATCH.** `AppListsRepository.addBlockedApp`/`addAllowlistedApp` each
  delete from the other list inside a transaction; `replaceBlockedApps` skips allowlisted packages
  ("allowlist wins"). Tested (7 cases). Enums (`CompletionReason.lockBreak`, exit reasons, recovery
  types/results) mirror §2 and the D-011 "preserve vs earn" vocabulary.

## Reliability of the core loop (the top priority)

The resilience story is genuinely good: START_STICKY + prefs-backed `BlockedSetCache` means the
accessibility hot path has zero channel traffic and survives process death; `BootReceiver` re-arms
from prefs with no engine; retroactive completion is computed identically to a normal tick because
everything derives from `endEpochMs`. The controller's `_hydrate` covers cold start, sessionRestored
replay, DB-terminal-but-native-restored (disarms native), and recoveryInProgress adoption — all
tested. Permission loss mid-session emits once, is state-guarded, and lands `failedPermissions`
with a user notice (never silent) — matches the §4 bar. The gaps are the buffer bound (P1-A) and
the native-cache-clear asymmetry (P1-B/C) — i.e. the edges of resilience, not its center.

## Privacy / policy

Clean. Main manifest has **no** INTERNET (isolated to debug/profile for Flutter tooling — verified),
no `QUERY_ALL_PACKAGES` (uses scoped `<queries>` for launcher intents only), accessibility config
claims `typeWindowStateChanged` + `canRetrieveWindowContent=false` and the service code reads only
`event.packageName` — the "window-state only" claim is true in code, not just in XML. Service
description strings (EN/DE) are explicit about not reading content and not transmitting data —
appropriate, still PM-owned for exact wording. The `specialUse` FGS is declared with a subtype
justification (P2-F is a submission gate, not a code defect).

## Performance

Intercept path is native, code-built (no inflation, no androidx on the critical path), launched
directly from the accessibility callback — structurally consistent with the <200 ms target. The
<200 ms and cold-render numbers are explicitly deferred to on-device (M2/D-012) and cannot be
verified here; that deferral is documented and appropriate.

---

## Code-health trajectory

The trajectory is very healthy and, notably, *self-documenting in the right way*: pure decision
logic (`InterceptDecider`, `SessionServicePlan`, `AttemptTracker`, `SessionMachine`) is factored out
of Android/Flutter framework glue precisely so it can be unit-tested without a device, and it is —
the JVM and Dart suites carry the load-bearing logic, and the tests are written to be
non-tautological (independent expectation tables, exhaustive pair sweeps). The Kotlin layer holds
zero business rules (durations, streak logic, copy live in Dart/ARB), honoring the mechanism-vs-policy
boundary. Comments explain *why* (BAL exemption, 5-second FGS contract, wall-clock anchoring
rationale) rather than restating code. The debt that exists is honest and localized: it clusters in
the event-delivery seam (bounded buffer, mixed-priority queue, attribution heuristic) and the
native-cache lifecycle — all called out above, none structural. Fix the four P1s (ideally with a
tech-lead ruling on P1-A's buffer strategy and P1-C's liveness tiebreak, since both brush the
resilience contract) and this core is a solid, trustworthy foundation for the feature layers to
build on.
