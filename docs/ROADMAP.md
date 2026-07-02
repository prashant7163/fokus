# FOKUS — Roadmap: Epics · Milestones · Stories

Structure lives here; **execution state lives only in TASKBOARD.md** (stories = F/B-xx rows).
Progress at a glance = milestones table below + taskboard statuses. Append-only history.

## Epics

| Epic | Name | Stories | Outcome |
|---|---|---|---|
| E1 | Foundation & Blocking Engine | F-01…F-06 | App builds; blocking + session core works natively |
| E2 | Recovery & Core Loop UX | F-07, F-08, F-11 | The differentiator: intercept → recover → resume |
| E3 | Retention Layer | F-09, F-10, F-12 | Streaks, stats, onboarding, permissions health |
| E4 | Engagement (Phase B) | F-13…F-17 | Presets, schedules, dashboard, achievements, local AI |
| E5 | Launch & Store | F-18…F-21 | Review, QA, listing, closed-track release |
| E6 | Brand & Web Presence | B-01, B-02, B-03 | Distinctive brand v2, public website, final store graphics |
| E7 | Deferred (gated on validation) | — | iOS, Firebase/social, web unlock, monetization, parental |

## Milestones (progress checkpoints)

| Milestone | Definition of done | Epics | Status |
|---|---|---|---|
| M1 "It builds" | Scaffold + CI green (analyze, test, assembleDebug) | E1 partial | **done 2026-07-02 13:05** (CI run #4 green: full pipeline over F-01…F-06 + fixes) |
| M2 "It blocks" | Blocked app intercepted < 200 ms on emulator; survives reboot/kill (D-012: emulator is the M2 device; OEM battery behavior deferred to closed track) | E1 | **done 2026-07-02 16:15** (evidence: docs/reviews/M2-emulator-pass.md; <200 ms visible-render on hardware stays a closed-track confirm) |
| M3 "Core loop complete" | Session → intercept → recovery → resume/exit, end-to-end on device | E2 | **done 2026-07-02 16:15** (same pass: stuck→recovery→resumed row, emergency→exit sheet→aborted, unblock verified) |
| M4 "Retention ready" | Streaks/stats/onboarding done; app is daily-usable; closed-track candidate | E3 | **done 2026-07-02 19:45** (F-09…F-12 CI-verified; full first-run → session → intercept → celebrate loop walked on-emulator through the real UI; independent M4 review next) |
| M5 "Engagement complete" | All Phase B features pass done-criteria | E4 | **done 2026-07-02 20:30** (F-13…F-17 CI-verified; schedule auto-start device-verified; QA matrix docs/reviews/M5-qa-matrix.md) |
| M6 "Store-ready" | QA matrix P0s pass; listing approved; release build on closed track | E5, E6 | **build-ready 2026-07-02** — all code + release config done, drafts staged; remainder is Prashant-only (keystore, verbatim copy approval, screenshot composition, upload) — see PUBLISH_READY.md |

Milestone status updates happen here (todo → doing → **done + date**) as part of the
session-end ritual. Brand/website (E6) runs parallel to E1–E3; it never blocks M1–M4.

## Story conventions

- `F-xx` = product/build stories (TASKBOARD Phase A/B/C tables)
- `B-xx` = brand/web stories (TASKBOARD Brand table)
- New stories: append to TASKBOARD with epic tag, owner-type, done-criteria; reference epic here.
