# FOKUS — Agent & Session Entry Point

> **Read this first.** Every fresh session or agent starts here. This file plus `docs/` is the
> complete warm-start context. Do not rely on chat history — if it matters, it is in a file.

## What this project is

FOKUS is an AI-assisted focus companion for Android (iOS later): blocks distracting apps during
focus sessions, guides users through **recovery** when tempted (the key differentiator), and
builds habits via streaks. Publisher: Hoffely GmbH. Package id: `ch.hoffely.fokus`.

**Current phase:** Android-only, Phase 1 (MVP core loop) → Phase 2 (engagement features).
No Firebase, no iOS, no monetization until the core loop is validated on-device.

## Read order for a fresh session

1. `CLAUDE.md` (this file) — orientation and rules
2. `fokus-specs.md` — WHAT we are building: scoped, unambiguous build spec
3. `docs/ARCHITECTURE.md` — system shape, module boundaries, tech stack
4. `docs/CONTRACTS.md` — interfaces, state machines, channel names, DB schema. **Binding.**
5. `docs/CONVENTIONS.md` — style, naming, commits, testing bar
6. `docs/TASKBOARD.md` — pick up work here; every task has scope + done-criteria
7. `docs/DECISIONS.md` — why things are the way they are; do not relitigate silently
8. `docs/DISCUSSIONS.md` — MOM of Prashant↔orchestrator discussions; catch up on recent entries
9. `docs/CHANGELOG.md` — what changed, when

`design/` holds the design system, screen specs, and graphics assets — UI tasks consume it.

`planning/` (if present) is local-only business context — product blueprint, store paperwork,
strategy. It is gitignored on purpose. Never commit it. Agents in worktrees will not see it;
they do not need it — everything build-relevant is extracted into `docs/`.

## Team roster (agent roles)

Role briefs live in `agents/` (project root) and are injected verbatim when a role is spawned.
The **orchestrator** (main Cowork session with Prashant) is not spawned — it plans, briefs,
integrates results, and holds the coupled core inline.

| Role | Brief | Spawn for |
|---|---|---|
| Product Manager | `agents/product-manager.md` | Taskboard grooming, copy, listing drafts |
| Tech Lead | `agents/tech-lead.md` | Contract/architecture changes, ADRs, design rulings |
| Mobile Developer | `agents/mobile-developer.md` | `agent-ok` taskboard tasks |
| Code Reviewer | `agents/code-reviewer.md` | Milestone/pre-merge review (worktree, read-only) |
| UX Designer | `agents/ux-designer.md` | Design system, screen specs, graphics production |

Spawn discipline: one taskboard task per spawn, brief = role file + task ID + any extra
constraints; agent returns a summary, orchestrator verifies before marking `done`.

**Orchestrator standing duties (not delegable — subagents cannot see the conversation):**
- Record MOM of every working session with Prashant in `docs/DISCUSSIONS.md` (datetime-stamped,
  decisions + action items) — written at session end and after any significant decision.
- Append `docs/CHANGELOG.md` on every commit batch.
- Keep DECISIONS/TASKBOARD/CHANGELOG consistent before ending a session ("session-end ritual").

## Ownership rules

- **Core (single-author, inline):** Kotlin blocking service, foreground service, session engine,
  intercept flow. Tightly coupled; do not delegate pieces of these to parallel workers.
- **Leaf modules (delegable):** onboarding UI, recovery module screens, stats/streaks UI,
  settings, store copy. Safe for scoped agents — brief must name files, contract, done-criteria.
- Any change to `docs/CONTRACTS.md` requires a `DECISIONS.md` entry and must not be made by a
  leaf-module agent.

## Hard rules

- Offline-first: session timer, blocking, recovery, streaks, stats must work with no network.
- Blocking logic is 100 % native Kotlin. No blocking logic in Dart.
- Privacy: behavioral data stays local. No analytics events beyond what `docs/CONTRACTS.md` lists.
- The accessibility-service disclosure flow ships verbatim as written in `docs/TASKBOARD.md`
  task F-14 — Google Play policy depends on it.
- Update `docs/TASKBOARD.md` status when starting/finishing a task. Append, don't rewrite history.
- Destructive commands (`rm -rf`, `git clean`, `git push --force`, bulk deletes, history rewrites)
  require Prashant's explicit approval — every worker, no exceptions. Non-destructive bash inside
  the project folder is free to use.
