# FOKUS — Binding Contracts

> Changes here require a DECISIONS.md entry. Leaf-module agents: consume, don't modify.

## 1. BlockingAdapter (Dart facade ↔ Kotlin impl)

MethodChannel: `fokus/blocking` · EventChannel: `fokus/events`

```dart
abstract class BlockingAdapter {
  Future<PermissionState> getPermissionStatus();
  Future<void> requestPermission(PermissionKind kind); // opens the right settings screen
  Future<List<InstalledApp>> getInstalledApps();
  Future<void> setBlockedApps(List<String> packageNames);
  Future<void> startSession(NativeSessionConfig config); // id, endEpochMs, taskAnchor, strictMode
  Future<void> stopSession(String sessionId);
  Stream<BlockingEvent> get events;
}
```

`PermissionKind`: `accessibility | usageStats | notifications | batteryExemption`
`BlockingEvent`: `distractionAttempt(pkg, ts)` · `interceptShown(pkg)` · `recoveryRequested()`
· `permissionLost(kind)` · `sessionRestored(sessionId)`

## 2. Session state machine

```
idle → pendingStart → active ⇄ recoveryInProgress
active → completed          (timer end OR exit reason "finished task")
active → aborted            (emergency | unlock in future scope | lock-break in future scope)
active → failedPermissions  (permission revoked mid-session)
```

Legal transitions only — enforced in `lib/core/session/session_machine.dart`. The native side
never decides transitions; it reports events, Dart decides, result is pushed back down.

**Exit reasons (enum, logged on every early-exit attempt):**
`finishedTask | emergency | stuck | tired | needApp`

**Recovery types (enum):** `breathe | taskReset | stretch | water | changeDuration`
**Recovery results:** `resumed | exited`

## 3. Database (Drift, current scope)

- `focus_sessions` — id, status, startTime, endTime, plannedMin, actualMin, taskAnchor,
  strictMode, completionReason, exitReason
- `blocked_apps` — packageName, appName, addedAt
- `distraction_attempts` — sessionId, packageName, ts, recoveryInvoked
- `recovery_events` — sessionId, type, startedAt, completedAt, result
- `streak_summary` — singleton row: currentDays, longestDays, lastFocusDate, tokensAvailable,
  tokensLifetime
- `presets` (Phase 2) — name, durationMin, strictMode, recoveryEnabled, blockedAppIds
- `schedules` (Phase 2) — presetId, daysOfWeek, startLocalTime, enabled
- `achievements` (Phase 2) — code, unlockedAt
- `feedback_entries` (Phase 2) — type, rating, text, contextJson, createdAt
- `ai_insights` (Phase 2) — type, contentJson, generatedAt, shownAt, actedOn

Streak rule: a day qualifies with ≥ 1 completed session ≥ 10 min, local calendar day.

## 4. Business constants (single source: `lib/core/constants.dart`)

| Constant | Value |
|---|---|
| Durations offered | 15 / 30 / 60 / 120 min / custom |
| Streak qualifying session | ≥ 10 min completed |
| Lock-break earn milestones | 7 d → 1 · 14 d → 2 · 30 d → 3 · 60 d → 5 · 100 d → 10 |
| Lock-break weekly redeem cap | 3 |
| Post-session feedback sampling | 1 in 3 sessions |
| Free tier limits (Phase 3, not built yet) | 5 apps, 2 h sessions, 1 preset |

## 5. Analytics events (local only — no network sink in current scope)

`session_started, session_completed, session_aborted, distraction_blocked, recovery_started,
recovery_resumed, recovery_exited, exit_reason_selected, streak_incremented, streak_broken`

Nothing else. Adding an event = CONTRACTS change.
