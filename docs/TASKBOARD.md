# FOKUS — Taskboard

Status: `todo | doing | review | done | blocked`. Owner: `core` = single-author inline work
(tightly coupled); `agent-ok` = safe to delegate with a scoped brief.

## Phase A — Foundation & core loop (maps to blueprint Phase 1)

| ID | Task | Owner | Status | Done when |
|---|---|---|---|---|
| F-01 | Flutter scaffold: project, theme (M3), nav, Riverpod, CI | core (worker session, 2026-07-02) | done | `flutter analyze` + `assembleDebug` green in CI — VERIFIED: CI run #1 green on 395779f (orchestrator checked GitHub Actions 2026-07-02 ~12:20) |
| F-02 | Drift schema + repositories per CONTRACTS §3 | core (worker session, 2026-07-02) | done | Schema matches contract; repo unit tests pass — 40 unit tests + schema-contract guard written; sandbox cannot run Dart, CI run is the verification gate |
| F-03 | Kotlin: AccessibilityService + blocked-set cache + detection | core (worker session, 2026-07-02) | done | Blocked app detected < 200 ms on test device — VERIFIED in M2 emulator pass (docs/reviews/M2-emulator-pass.md row 1–2): detection instant, visible render 212–384 ms on software-GPU emulator; <200 ms hardware render = closed-track confirm (D-012) |
| F-04 | Kotlin: SessionForegroundService + BootReceiver + resilience | core (worker session, 2026-07-02) | done | Session survives process kill + reboot — VERIFIED in M2 pass (rows 4–6): crash→restart ~2 s, reboot→BootReceiver re-arm without app open, FGS notification live |
| F-05 | Kotlin: InterceptActivity (anchor, countdown, 3 CTAs) | core (worker session, 2026-07-02) | done | Renders from a cold intercept; buttons wired — VERIFIED in M2 pass (rows 1, 7–8; screenshots in docs/reviews/m2-assets/). M2 found+fixed the deep-link host bug (route now in URI path) |
| F-06 | Dart: session state machine + timer + channel facade | core (worker session, 2026-07-02) | done | All CONTRACTS §2 transitions unit-tested — VERIFIED: CI run #4 green (full pipeline incl. all Dart tests, 2026-07-02 13:05) |
| F-07 | Recovery flow: 5 modules + result logging | agent-ok (mobile-dev agent, 2026-07-02) | done | Each module completable; RecoveryEvent rows written; resume returns to session — 5 modules + hub + shrink controller op + abandon-writes-exited; flutter_svg added (pre-approved) — VERIFIED: CI run #7 green on 077d42d (2026-07-02 ~15:00) |
| F-08 | Structured exit flow (5 reasons, strict-mode consequences) | core (worker session, 2026-07-02) | done | Every early exit writes exitReason; strict mode blocks needApp path — VERIFIED: CI run #9 green on 81823c5 (2026-07-02 ~16:05) + on-device e2e in the M2 pass (exit sheet via cold deep link, emergency→aborted/emergency in DB, unblock confirmed) |
| F-09 | Streaks + today stats + session-complete screen | core (worker session, 2026-07-02) | done | Streak unit tests incl. timezone/day-boundary; today view shows 4 stats — VERIFIED: CI run #11 green on e511171 (2026-07-02 ~17:20); derived streak engine (D-017), token award/redemption, complete screen, today view |
| F-10 | Onboarding: 3 value screens + permission setup + disclosure | core (worker session, 2026-07-02) | done | Disclosure precedes accessibility request (Play policy); "later" → limited mode — VERIFIED: CI run #13 green on 535f423 (run #12's only red was plugin-test scoping, D-019). ⚠ disclosure copy is a MARKED PLACEHOLDER — Prashant's verbatim approval is a release blocker |
| F-11 | Home dashboard + start-session config screen | core (worker session, 2026-07-02) | done | One-tap repeat of last config works — VERIFIED: CI run #13 green on 535f423 (2026-07-02 ~19:20); one-tap-repeat test proves 1 tap → running session; home/config/Active Session per SCREENS §1–§3 |
| F-12 | Settings/profile: permissions health, notifications | core (worker session, 2026-07-02) | done | Revoked permission surfaces as warning banner — VERIFIED: CI run #14 green on 64cc2be (2026-07-02 ~19:35); health card + theme toggle + suggestions opt-in + D-011 allowlist editing + Plus Jakarta Sans bundled (D-020) |
| F-22 | P1 fixes from F-18 core review per D-013 (attempt journal, stopSession tiebreak, expiry cache clear, ts-containment attribution) | core (mobile-dev agent, 2026-07-02) | done | All 4 P1s fixed with tests per D-013; review report findings marked resolved — VERIFIED: CI run #7 green on 077d42d (2026-07-02 ~15:00; incl. the start-after-terminal fix from run #6 triage) |

## Phase B — Engagement (blueprint Phase 2, local-only subset)

| ID | Task | Owner | Status | Done when |
|---|---|---|---|---|
| F-13 | Presets CRUD + schedules (WorkManager) | core (worker session, 2026-07-02) | review | Scheduled session auto-starts at local time — presets CRUD + schedule editor UI, native WorkManager arm (reminder T−5 w/ Skip, auto-start w/ never-clobber veto, re-arm after fire, reboot-persistent), restore-with-config row synthesis (D-022), recoveryEnabled wired to the intercept; 13 JVM occurrence/veto tests + 7 Dart tests (226 local); CI is the gate |
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
