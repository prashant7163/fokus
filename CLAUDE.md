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
2. `docs/ARCHITECTURE.md` — system shape, module boundaries, tech stack
3. `docs/CONTRACTS.md` — interfaces, state machines, channel names, DB schema. **Binding.**
4. `docs/CONVENTIONS.md` — style, naming, commits, testing bar
5. `docs/TASKBOARD.md` — pick up work here; every task has scope + done-criteria
6. `docs/DECISIONS.md` — why things are the way they are; do not relitigate silently

`planning/` (if present) is local-only business context — product blueprint, store paperwork,
strategy. It is gitignored on purpose. Never commit it. Agents in worktrees will not see it;
they do not need it — everything build-relevant is extracted into `docs/`.

## Team roster (agent roles)

Role briefs live in `docs/agents/` and are injected verbatim when a role is spawned.
The **orchestrator** (main Cowork session with Prashant) is not spawned — it plans, briefs,
integrates results, and holds the coupled core inline.

| Role | Brief | Spawn for |
|---|---|---|
| Product Manager | `docs/agents/product-manager.md` | Taskboard grooming, copy, listing drafts |
| Tech Lead | `docs/agents/tech-lead.md` | Contract/architecture changes, ADRs, design rulings |
| Mobile Developer | `docs/agents/mobile-developer.md` | `agent-ok` taskboard tasks |
| Code Reviewer | `docs/agents/code-reviewer.md` | Milestone/pre-merge review (worktree, read-only) |
| UX Designer | `docs/agents/ux-designer.md` | Design system, screen specs, store graphics specs |

Spawn discipline: one taskboard task per spawn, brief = role file + task ID + any extra
constraints; agent returns a summary, orchestrator verifies before marking `done`.

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
