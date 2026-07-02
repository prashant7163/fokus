# M2 Emulator Pass — Evidence Report

**Date:** 2026-07-02 15:40–16:15 (Europe/Zurich) · **Runner:** worker session (Claude Code)
**Device:** Android Studio AVD `Medium_Phone_API_35` (Pixel-class, Android 15, arm64,
production image — no root), software GPU (swiftshader). Strategy per **D-012**: the
emulator is the M2 device; OEM battery-killer behavior is deferred to the closed track.

**Builds under test:** debug APK from `81823c5` (F-08) plus the two fixes found *by this
pass* (deep-link path + hydration gate, committed immediately after as the M2 fix commit —
the final e2e ran on the fixed build).

## How the session was armed

The start-config UI lands with F-11, so `integration_test/m2_arm_session_test.dart` drives
the REAL stack (Dart `SessionController.start` → MethodChannel → `BlockedSetCache` +
`SessionForegroundService`), blocking `com.android.chrome` for 30 min. Everything after
that is stock adb: launching apps, tapping the real UI, screencaps, pulling the drift DB
via `run-as`.

## Checklist results

| # | Criterion | Result | Evidence |
|---|---|---|---|
| 1 | Blocked app detection → intercept fires | **PASS** | InterceptActivity START logged before Chrome even finished rendering; screenshot `m2-assets/intercept-chrome.png` (matches SCREENS §4: ring, icon, "Chrome can wait.", countdown, anchor card, 3 CTAs) |
| 2 | Intercept latency < 200 ms | **PASS (detection) / hardware-confirm (render)** | Detection→launch-request: same-millisecond-class (START precedes the blocked app's own `Displayed`). Full visible render: 212–384 ms warm, ~1.1 s cold, **on a software-GPU emulator** — not representative of hardware. Confirm <200 ms visible on a real device in closed track (D-012 residual). |
| 3 | DistractionAttempt pipeline (journal → Dart → DB) | **PASS** | 16 attempt rows in `distraction_attempts`, all attributed to the correct live session (D-013 P1-A at-least-once + P1-D ts-containment verified in production path) |
| 4 | Session survives process kill | **PASS** | `am crash` → process (pid 5120) restarted as 6145 in ~2 s (START_STICKY); both services re-bound; next Chrome open intercepted. Note: `am kill` is a no-op while the FGS runs — the process is protected. |
| 5 | Session survives reboot | **PASS** | `adb reboot` → BootReceiver re-armed FGS (isForeground=true, notification id 1001) + accessibility rebound **without opening the app**; Chrome intercepted post-boot (screenshot `intercept-after-reboot.png`) |
| 6 | FGS countdown notification | **PASS** | `fokus_session` channel, IMPORTANCE_LOW, ongoing, specialUse subtype — visible once POST_NOTIFICATIONS granted |
| 7 | Intercept → "I'm stuck" → recovery hub | **PASS (after fix 1)** | Deep link opens `/recovery` hub (screenshot `recovery-hub-via-stuck.png`); Breathe module runs (`breathe-module.png`); `recovery_events` row written and closed `resumed` |
| 8 | Intercept → "Emergency exit" → exit flow | **PASS (after fix 2)** | F-08 sheet renders from a cold engine (`exit-sheet.png`); Emergency → session `aborted/emergency` in DB, native prefs cleared, Chrome opens freely afterwards (0 intercepts) |
| 9 | Permission loss mid-session → failedPermissions, never silent | **PASS (incidental)** | When the accessibility grant was wiped by a package update mid-session, the FGS watch detected it and the session transitioned to `failedPermissions` with the event surfaced to Dart — exactly the fokus-specs §4 bar. (The visible health UI is F-12.) |
| 10 | Session end → unblock | **PASS** | After emergency abort: native session prefs cleared, Chrome foregrounds uninhibited |

**M3 core loop** (session → intercept → recovery → resume / exit) is covered by rows 7–8
plus the resume path: `RecoveryEvent(breathe, resumed)` written; the resume-after-terminal
edge (session had gone failedPermissions mid-recovery) degraded gracefully to home with the
event still closed — no crash, no data loss.

## Bugs found by this pass (both fixed in the M2 fix commit)

1. **Deep links dead on arrival (F-05):** `fokus://recovery` / `fokus://exit` put the route
   in the URI *host*; Flutter's Android embedding forwards only path+query, so the engine
   always booted at `/`. Fixed: `fokus://app/recovery`, `fokus://app/exit` (route in the
   path; scheme-only intent filter unchanged).
2. **Cold-start hydration race (F-06/F-08):** deep-linked screens read the transient
   pre-hydration `idle` as "no session" — the emergency-exit link bounced home instead of
   showing the sheet. Fixed: `SessionState.hydrated` flag; the exit sheet waits for it, and
   the recovery screen defers `RecoveryController.begin` until hydration concludes (else the
   proactive `?module=breathe` cold path would skip its RecoveryEvent row).
   Regression-tested in `exit_screen_test.dart` ("cold-start deep link…").

## Emulator/test caveats worth knowing (not app bugs)

- adb-granted accessibility (`settings put secure …`) is cleared by every package
  update/reinstall — real users grant via Settings UI. Useful side effect: it exercised the
  permission-loss path (row 9). F-12's permissions-health banner is the user-facing answer.
- `am force-stop` puts the app in stopped state: **BOOT_COMPLETED is not delivered** until
  the user opens the app once (Android by design). A user who force-stops FOKUS from
  Settings ends blocking until the next app open — mirror of the OEM battery-killer risk
  already tracked as a closed-track exit criterion (D-012, QA row 9).
- The arm-test APK re-runs its test `main()` on every cold start (created two stray
  sessions during the pass, cleaned via `run-as` DB edit). Future device passes should
  swap back to the real APK immediately after arming — noted in the test file docstring.
- Latency numbers on swiftshader are a floor for correctness, not a performance claim.

## Verdict

**M2 done** (D-012 scope) and the **M3 core loop is verified on-device** end-to-end.
Residual for closed track: <200 ms visible-render on hardware, OEM battery behavior.
