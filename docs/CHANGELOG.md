# FOKUS — Changelog (living document)

Append-only. One entry per commit batch: date + time (Europe/Zurich), what changed, by whom.
"Why" lives in DECISIONS.md; this file is the "what/when" tracker. Times before 2026-07-02
02:30 retrofitted from git commit timestamps.

| Date · Time | Change | By |
|---|---|---|
| 2026-07-02 00:30 | Step 0: constitution committed (CLAUDE.md, docs/ set), planning/ created local-only, git repo initialized, remote set | Orchestrator |
| 2026-07-02 00:45 | Agent role briefs added (PM, tech-lead, mobile-dev, code-reviewer, ux-designer), roster wired into CLAUDE.md (D-007) | Orchestrator |
| 2026-07-02 01:07 | Restructure: agents/ moved to project root; design/ created; CHANGELOG.md + DISCUSSIONS.md added; fokus-specs.md authored at root; ux-designer brief upgraded (graphics emphasis); destructive-command rule added (D-008) | Orchestrator |
| 2026-07-02 01:18 | Initial design package: BRAND, DESIGN_SYSTEM, SCREENS, FLOWS, STORE_GRAPHICS + 14 SVG assets (icon, mark, 5 recovery illustrations, 6 badges, feature graphic) | ux-designer agent |
| 2026-07-02 01:49 | ROADMAP.md added (E1–E7, M1–M6); B-01/B-02/B-03 stories added to taskboard; D-009 (brand v2), D-010 (session working model) | Orchestrator |
| 2026-07-02 01:49 | Brand v2 executed: blue dropped, charcoal+orange+warm-neutral palette, all SVGs regenerated, icon variants (broken/closed ring), positioning section; website/index.html built (EN/DE toggle, waitlist mailto placeholder) | ux-designer agent |
| 2026-07-02 01:49 | Blueprint audit: 24 inconsistencies cataloged; planning/fokus-blueprint-specs.md created (cleaned full-scope vision, inconsistency register, 6 DECISION-NEEDED items) | product-manager agent |
| 2026-07-02 02:12 | F-01 scaffold: Flutter project (pubspec, lints, l10n EN/DE), M3 theme from DESIGN_SYSTEM.md v2 tokens (schemes, typography, spacing, motion, FokusColors extension), go_router + Riverpod with 6 feature stubs, constants.dart per CONTRACTS §4, Android embedding `ch.hoffely.fokus` (Gradle KTS, AGP 8.7.3/Kotlin 2.1, no network permission in main manifest), dev launcher icons (broken-ring, PIL-generated), GitHub Actions CI (analyze/test/assembleDebug), tests (smoke EN+DE, theme, constants) | Orchestrator (worker session) |
| 2026-07-02 02:14 | D-011 rulings recorded (streak preserve-not-earn, no paused state, onboarding allowlist); specs + CONTRACTS (allowlisted_apps) updated | Orchestrator |
| 2026-07-02 02:45 | Timestamps added to CHANGELOG/DISCUSSIONS/DECISIONS (retrofitted from commits); M2 on-device verification deferred until Prashant returns (build not blocked); worker kickoff prompt v2 with context-checkpoint protocol | Orchestrator |
