# FOKUS — Discussion Record (MOM)

Minutes of Prashant ↔ orchestrator working sessions. Append-only, newest last. Purpose:
survive context compaction and give any fresh session the "why" behind recent moves.
Maintained by the orchestrator (standing duty — subagents cannot see conversations).

---

## 2026-07-01 · Kickoff & scoping (backfilled)

- Reviewed FOKUS Product Requirements Blueprint v1.0 (now in planning/, local-only).
- **Decided:** scope = blueprint Phase 1 + 2; cross-platform ambition raised by Prashant;
  orchestrator recommended Flutter shell + native Kotlin blocking core → accepted (D-001).
- Discussed Apple FamilyControls entitlement risk and Google accessibility policy gates.
- Orchestrator gave candid product verdict: recovery system + exit-reason analytics are the
  defensible core; category has brutal retention; distribution is the real risk. Agreed the
  build validates one hypothesis: does in-flow recovery change behavior?

## 2026-07-02 · Android-first, execution model, Step 0 (backfilled)

- **Decided:** Android-only first (D-002); iOS deferred until Android metrics exist.
- Publisher: Hoffely GmbH existing Play account (Hofferly published) → no 14-day closed-test
  mandate; package id `ch.hoffely.fokus` (D-004).
- Prashant raised context-bloat concern → hybrid execution model agreed (D-006): core inline,
  leaf modules to scoped agents, fresh sessions enabled by docs-on-disk.
- Step 0 built and committed; planning/ kept local per Prashant's preference, engineering
  constitution committed (D-005). Kickoff template created for future projects.
- Team roster defined: PM, tech-lead, mobile-developer, code-reviewer, ux-designer + orchestrator
  (D-007).
- **Action items:** Prashant: delete stale .git/*.lock files, push to GitHub, start Play Console
  items #1/#12. Orchestrator: F-01 scaffold next.

## 2026-07-02 · Structure review (7 comments from Prashant)

- agents/ moved to project root; design/ created at root.
- CHANGELOG.md (change tracker) + this DISCUSSIONS.md (MOM) added as living documents.
- **MOM-agent request:** orchestrator pushed back — subagents cannot see the conversation, so
  minute-taking is a standing orchestrator duty (codified in CLAUDE.md) rather than a role.
- ux-designer brief upgraded with stronger graphic-design emphasis; agent deployed to produce
  the initial design/ package.
- fokus-specs.md authored at root: unambiguous build spec distilled from the blueprint;
  blueprint remains product-vision reference in planning/.
- Bash policy clarified: non-destructive commands free inside project; destructive ones need
  Prashant's approval (also enforced by Cowork's own permission prompts) — added to hard rules.
