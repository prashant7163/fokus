# FOKUS — Decision Log (ADR-lite)

Append-only. Format: ID, date, decision, why, revisit-when.

## D-001 · 2026-07-01 · Flutter shell + native Kotlin blocking core
Cross-platform UI for future iOS reuse; blocking stays 100 % native (spec principle "native
where it matters"). Chosen over React Native (cleaner platform-channel story next to a
long-lived foreground service) and over pure Kotlin/Compose (would strand the iOS path).
**Revisit when:** iOS work starts, or if channel overhead measurably hurts intercept latency.

## D-002 · 2026-07-02 · Android-only first; iOS deferred
Apple FamilyControls entitlement is an external approval with no SLA; Android is fully within
our control. Validate the core hypothesis (recovery → resume rate) on Android before spending
on iOS. **Revisit when:** Android closed-track metrics exist.

## D-003 · 2026-07-02 · Scope = Phase 1 + local-only Phase 2 subset
No Firebase, no social rooms, no web unlock portal, no billing until core loop is validated.
Everything in scope must run offline. **Revisit when:** F-19 QA passes and early retention
data is in.

## D-004 · 2026-07-02 · Publish under Hoffely GmbH account
Existing org account with published app (Hofferly): production access already unlocked, the
12-tester/14-day closed-test mandate for new personal accounts does not apply, review track
record exists. Package id `ch.hoffely.fokus`. A voluntary closed test still happens — for
recovery-metric data, not for Google.

## D-005 · 2026-07-02 · Docs split: engineering constitution committed, planning local
`CLAUDE.md` + `docs/` are committed — worktree agents and fresh clones must self-orient from
committed files. Business/planning material (PRD blueprint, paperwork tracker, strategy)
stays in gitignored `planning/`. **Revisit when:** a second full-time contributor joins.

## D-006 · 2026-07-02 · Hybrid execution model
Single-author inline work for the coupled core (blocking service, session engine, intercept);
scoped agents for leaf modules and independent review; fresh sessions between phases enabled
by this docs set. Agents brief = files + contract + done-criteria, return summaries.

## D-007 · 2026-07-02 · Named agent roles in docs/agents/
Six roles: PM, tech-lead, mobile-developer, code-reviewer, ux-designer (spawnable briefs) +
orchestrator (main session, documented in CLAUDE.md). Files double as Claude Code custom
agents if copied to `.claude/agents/` (that path is write-protected in Cowork sessions).
PM drafts, Prashant decides; only tech-lead may change contracts; reviewer is read-only.
**Revisit when:** role boundaries cause friction or a real human joins the team.
