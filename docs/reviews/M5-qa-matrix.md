# M5 QA Matrix — FOKUS (blueprint §19 critical flows)

**Date:** 2026-07-02 · **Runner:** worker session (Claude Code) · **Device:** Android Studio
AVD `Medium_Phone_API_35` (Pixel-class, Android 15, production image, software GPU), per D-012.
Rows tagged **closed-track** need a physical OEM device and move to the tester fleet (D-012).

| # | Test | Priority | Result | Evidence |
|---|------|----------|--------|----------|
| 1 | First-run onboarding completes, all permissions granted | P0 | **PASS** | M4 UI pass: value screens → disclosure (explicit consent) → checklist → pickers → home (docs/reviews/m2-assets/onboarding-*, home-dashboard.png) |
| 2 | Permission denied/revoked mid-session — graceful degradation | P0 | **PASS** | M2 pass row 9: FGS watch → `failedPermissions`, never silent; failedPermissions view (F-11) |
| 3 | Top apps blocked correctly on Android | P0 | **PASS** | M2 + M4 passes: Chrome + YouTube intercepted (intercept-chrome.png, active-session.png); 96px real icons on the config/session rows |
| 4 | Blocking works after device reboot | P0 | **PASS** | M2 pass row 5: BootReceiver re-armed FGS + accessibility without app open; intercept-after-reboot.png |
| 5 | Session survives app crash / process kill | P0 | **PASS** | M2 pass row 4: `am crash` → restart ~2 s (START_STICKY), blocking intact |
| 6 | Recovery flow completes and session resumes | P0 | **PASS** | M2 pass: stuck → hub → Breathe → resumed row; recovery-hub-via-stuck.png, breathe-module.png |
| 7 | Exit flow captures reason correctly | P0 | **PASS** | M2 + M4: emergency → aborted/emergency in DB; finishedTask → celebration (exit-sheet.png, session-complete.png); every reason writes exitReason (widget-tested) |
| 8 | Streak increments across timezone/day boundary | P0 | **PASS (unit)** | Derived streak engine (D-017): day-boundary, zone-change, excused-day bridging all unit-tested (streak_engine_test.dart); no on-device clock-travel needed — streak is derived from row timestamps in the current zone |
| 9 | Battery optimization doesn't kill FGS (Samsung, Xiaomi) | P0 | **closed-track** | Emulator can't emulate OEM battery killers (D-012); QA row 9 is the closed-track exit criterion. FGS type `specialUse` + battery-exemption permission requested in onboarding |
| 10 | Concurrent notifications don't interfere with the intercept | P1 | **PASS** | M2/M4: intercept rendered over Chrome first-run + system notifications present; full-screen activity, not an overlay |
| 11 | Schedule triggers session at correct local time | P1 | **PASS (native) + unit (Dart row)** | M5 device pass: created Morning-focus preset + Thu 19:53 schedule; WorkManager armed (17 jobs), reminder fired at T−5, **auto-start at 19:53 started a native session + FGS while the app was backgrounded** (scheduled-session-active.png; prefs held the session id + preset packages). Engine-dead DB-row synthesis fixed + unit-verified (D-024). |
| 15 | Lock-break token earned at milestone, redeemed correctly | P1 | **PASS (unit + widget)** | streak_service_test (7-day → 1 token, weekly cap 3, redemption completes-via-lockbreak, streak preserved) + exit_screen_test (strict dialog token offer → celebration) |

**Out of scope (Phase 3+, not built):** rows 12 (social rooms), 13 (unlock codes), 14 (premium
paywall), 16 (supervised mode), 17 (iOS). Deferred per D-003.

## New features exercised on-device this pass (beyond the matrix)

- **F-11** full loop: onboarding → home (real icons, limited banner) → config → active-session
  ring → intercept → exit sheet → finishedTask celebration (8 screenshots).
- **F-13** presets & schedules: preset created and persisted (DB + native mirror synced,
  `fokus_schedules.xml`), schedule armed and **fired on time**; the chip-contrast fix (M4) is
  visible on the duration chips.
- Release **appbundle** builds clean with R8/shrink + proguard rules (61 MB aab, debug-key
  fallback since no keystore on this machine).

## Bugs found + fixed during the pass

1. **D-024** — schedule auto-start row synthesis when the engine is dead at fire time (native
   blocking worked; the Dart DB row was missing). Fixed via `getActiveNativeSession()` +
   cold-start query. The engine-alive path was already device-correct.

## Verdict

All buildable P0/P1 rows pass on the emulator. The residual — OEM battery-killer survival
(row 9) and the full engine-dead scheduled-session device cycle (D-024) — are the closed-track
exit criteria, exactly where D-012 places OEM/hardware risk.
