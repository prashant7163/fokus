# FOKUS — Taskboard

Status: `todo | doing | review | done | blocked`. Owner: `core` = single-author inline work
(tightly coupled); `agent-ok` = safe to delegate with a scoped brief.

## Phase A — Foundation & core loop (maps to blueprint Phase 1)

| ID | Task | Owner | Status | Done when |
|---|---|---|---|---|
| F-01 | Flutter scaffold: project, theme (M3), nav, Riverpod, CI | core (worker session, 2026-07-02) | review | `flutter analyze` + `assembleDebug` green in CI — scaffold committed; CI run blocked until repo is pushed to GitHub (Prashant action item) |
| F-02 | Drift schema + repositories per CONTRACTS §3 | core (worker session, 2026-07-02) | doing | Schema matches contract; repo unit tests pass |
| F-03 | Kotlin: AccessibilityService + blocked-set cache + detection | core | todo | Blocked app detected < 200 ms on test device |
| F-04 | Kotlin: SessionForegroundService + BootReceiver + resilience | core | todo | Session survives process kill + reboot |
| F-05 | Kotlin: InterceptActivity (anchor, countdown, 3 CTAs) | core | todo | Renders from a cold intercept; buttons wired to channel |
| F-06 | Dart: session state machine + timer + channel facade | core | todo | All CONTRACTS §2 transitions unit-tested |
| F-07 | Recovery flow: 5 modules + result logging | agent-ok | todo | Each module completable; RecoveryEvent rows written; resume returns to session |
| F-08 | Structured exit flow (5 reasons, strict-mode consequences) | agent-ok | todo | Every early exit writes exitReason; strict mode blocks needApp path |
| F-09 | Streaks + today stats + session-complete screen | agent-ok | todo | Streak unit tests incl. timezone/day-boundary; today view shows 4 stats |
| F-10 | Onboarding: 3 value screens + permission setup + disclosure | agent-ok | todo | Disclosure precedes accessibility request (Play policy); "later" → limited mode |
| F-11 | Home dashboard + start-session config screen | agent-ok | todo | One-tap repeat of last config works |
| F-12 | Settings/profile: permissions health, notifications | agent-ok | todo | Revoked permission surfaces as warning banner |

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
| F-18 | Milestone code review (independent agent) on F-03…F-06 | agent-ok | todo | Findings triaged; P0s fixed |
| F-19 | On-device QA per checklist (Samsung/Pixel/Xiaomi) | user | todo | P0 rows all pass (checklist in planning/) |
| F-20 | Play listing, declarations, data-safety answers | agent-ok | todo | Drafts in planning/ approved by Prashant |
| F-21 | Release build, signing, upload to closed track | user + core | todo | Build live on closed track |
