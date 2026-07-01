# FOKUS — Architecture

## Shape

Flutter shell + native Kotlin blocking core. All product/UI logic in Dart; everything that
touches OS-level services (app detection, interception, service lifecycle) in Kotlin.

```
┌────────────────────────── Flutter (Dart) ──────────────────────────┐
│  UI (screens, theming)                                             │
│  Session Engine (state machine, timer)     Recovery Engine         │
│  Streaks/Stats     Presets/Schedules       Local AI Suggestions    │
│  Repository layer ── Drift (SQLite)                                │
└───────────────▲────────────────────────────────▲───────────────────┘
                │  MethodChannel `fokus/blocking` │ EventChannel `fokus/events`
┌───────────────┴────────────────────────────────┴───────────────────┐
│                    Android native (Kotlin)                          │
│  BlockingAdapter impl                                               │
│  ├─ FokusAccessibilityService   (foreground-app detection)          │
│  ├─ SessionForegroundService    (session resilience, notification)  │
│  ├─ InterceptActivity           (blocked-app redirect screen)       │
│  ├─ BootReceiver                (restore session after reboot)      │
│  └─ UsageStatsHelper            (supplementary detection)           │
└─────────────────────────────────────────────────────────────────────┘
```

## Module boundaries

| Module | Language | Owns | Must not touch |
|---|---|---|---|
| `lib/core/session/` | Dart | Session state machine, timer | Platform channels directly |
| `lib/core/blocking/` | Dart | `BlockingAdapter` facade over channels | UI |
| `lib/core/data/` | Dart | Drift schema, repositories | — |
| `lib/features/*` | Dart | One screen-cluster each (onboarding, recovery, stats…) | Other features' state |
| `android/.../blocking/` | Kotlin | All OS-level services | Business rules (durations, streaks) |

Features communicate through repositories and the session engine — never feature-to-feature.

## Tech stack (decided — see DECISIONS.md)

| Layer | Choice |
|---|---|
| UI | Flutter, Material 3 |
| State | Riverpod |
| Local DB | Drift (SQLite) |
| Native core | Kotlin, AccessibilityService + UsageStatsManager + Foreground Service |
| CI | GitHub Actions (analyze, test, assembleDebug) |
| Backend | **None in current scope.** Firebase deferred until Phase 2 social/unlock features are green-lit. |

## Intercept flow (the critical path)

1. `FokusAccessibilityService` sees foreground app change → checks against blocked set
   (kept in native-side cache, synced from Dart at session start — no channel round-trip
   on the hot path).
2. Match → launch `InterceptActivity` (native, < 200 ms target) showing task anchor,
   time remaining, "Return to Focus" / "I'm stuck" / de-emphasized emergency exit.
3. "I'm stuck" → deep-links into Flutter recovery flow; result reported back over channel.
4. Every attempt logged as `DistractionAttempt` (see CONTRACTS.md).

## Resilience requirements

- Session state persisted to SQLite on every transition; foreground service restores from DB.
- `BootReceiver` re-arms active sessions after reboot.
- Process kill: `START_STICKY` service + state re-hydration.
- Permission revoked mid-session → session enters `failed_due_to_permissions`, user notified,
  no silent failure.

## Offline

Everything in current scope works with zero network. Any PR introducing a network dependency
into the core loop is wrong by definition.
