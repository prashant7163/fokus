# FOKUS — Taskboard

Status: `todo | doing | review | done | blocked`. Owner: `core` = single-author inline work
(tightly coupled); `agent-ok` = safe to delegate with a scoped brief.

## Phase A — Foundation & core loop (maps to blueprint Phase 1)

| ID | Task | Owner | Status | Done when |
|---|---|---|---|---|
| F-01 | Flutter scaffold: project, theme (M3), nav, Riverpod, CI | core (worker session, 2026-07-02) | done | `flutter analyze` + `assembleDebug` green in CI — VERIFIED: CI run #1 green on 395779f (orchestrator checked GitHub Actions 2026-07-02 ~12:20) |
| F-02 | Drift schema + repositories per CONTRACTS §3 | core (worker session, 2026-07-02) | done | Schema matches contract; repo unit tests pass — 40 unit tests + schema-contract guard written; sandbox cannot run Dart, CI run is the verification gate |
| F-03 | Kotlin: AccessibilityService + blocked-set cache + detection | core (worker session, 2026-07-02) | review | Blocked app detected < 200 ms on test device — service + cache + channels built, decision logic JVM-tested (9 cases); <200 ms device check deferred to M2 pass |
| F-04 | Kotlin: SessionForegroundService + BootReceiver + resilience | core (worker session, 2026-07-02) | review | Session survives process kill + reboot — service (START_STICKY, wall-clock re-hydration) + BootReceiver built, plan logic JVM-tested (10 cases); kill/reboot device check deferred to M2 pass |
| F-05 | Kotlin: InterceptActivity (anchor, countdown, 3 CTAs) | core (worker session, 2026-07-02) | review | Renders from a cold intercept; buttons wired to channel — activity per SCREENS §4 (code-built UI, no engine), CTAs wired (events + fokus:// deep links), proactive hint JVM-tested; cold-render emulator check deferred to M2 pass |
| F-06 | Dart: session state machine + timer + channel facade | core (worker session, 2026-07-02) | done | All CONTRACTS §2 transitions unit-tested — VERIFIED: CI run #4 green (full pipeline incl. all Dart tests, 2026-07-02 13:05) |
| F-07 | Recovery flow: 5 modules + result logging | agent-ok | todo | Each module completable; RecoveryEvent rows written; resume returns to session |
| F-08 | Structured exit flow (5 reasons, strict-mode consequences) | agent-ok | todo | Every early exit writes exitReason; strict mode blocks needApp path |
| F-09 | Streaks + today stats + session-complete screen | agent-ok | todo | Streak unit tests incl. timezone/day-boundary; today view shows 4 stats |
| F-10 | Onboarding: 3 value screens + permission setup + disclosure | agent-ok | todo | Disclosure precedes accessibility request (Play policy); "later" → limited mode |
| F-11 | Home dashboard + start-session config screen | agent-ok | todo | One-tap repeat of last config works |
| F-12 | Settings/profile: permissions health, notifications | agent-ok | todo | Revoked permission surfaces as warning banner |
| F-22 | P1 fixes from F-18 core review per D-013 (attempt journal, stopSession tiebreak, expiry cache clear, ts-containment attribution) | core (mobile-dev agent, 2026-07-02) | review | All 4 P1s fixed with tests per D-013; review report findings marked resolved — CI is the verification gate (sandbox cannot run flutter/gradle) |

## Phase B — Engagement (blueprint Phase 2, local-only subset)

| ID | Task | Owner | Status | Done when |
|---|---|---|---|---|
| F-13 | Presets CRUD + schedules (WorkManager) | core | todo | Scheduled session auto-starts at local time |
| F-14 | Stats dashboard day/week/month + focus score | agent-ok | todo | Charts render from fixtures + real data |
| F-15 | Achievements engine + badge screen | agent-ok | todo | All 8 CONTRACTS-listed triggers fire once |
| F-16 | Post-session micro-feedback + contextual triggers | agent-ok | todo | 1-in-3 sampling; 😔 branch captures reason |
| F-17 | Local AI suggestions (distraction windows, optimal length, recovery ordering) | core | todo | Suggestions from ≥ 2 weeks of fixture data match expected |

Deferred (needs explicit go): Firebase/social rooms, web unlock portal, monetization, iOS.

## Brand & Web (E6 — parallel track, never blocks Phase A)

| ID | Task | Owner | Status | Done when |
|---|---|---|---|---|
| B-01 | Brand v2: drop blue; charcoal + orange ring/dot icon; neutral-to-light system; distinctive vs crowded wellbeing segment | agent-ok (ux-designer) | review | BRAND/DESIGN_SYSTEM/assets updated to v2; Prashant approves |
| B-02 | Public website (single page, website/): brand showcase, differentiators, waitlist CTA | agent-ok (ux-designer) | review | Site renders locally; copy approved; domain TBD flagged |
| B-03 | Final store graphics from real screenshots | agent-ok | todo | 8 screenshots + feature graphic per STORE_GRAPHICS.md; needs M4 |

## Phase C — Ship

| ID | Task | Owner | Status | Done when |
|---|---|---|---|---|
| F-18 | Milestone code review (independent agent) on F-02…F-06 | agent-ok (code-reviewer, 2026-07-02) | done | Findings triaged; P0s fixed — verdict approve-with-fixes, 0 P0; triage in D-013; P1 fixes → F-22 |
| F-19 | On-device QA per checklist (Samsung/Pixel/Xiaomi) | user | todo | P0 rows all pass (checklist in planning/) |
| F-20 | Play listing, declarations, data-safety answers | agent-ok | todo | Drafts in planning/ approved by Prashant |
| F-21 | Release build, signing, upload to closed track | user + core | todo | Build live on closed track |
