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
- ux-designer agent deployed → initial design package delivered (design/ + 14 SVGs). Brand
  motif: "broken-O focus ring" (345° arc, 15° gap — focus as a state you enter, not a cage);
  indigo/sage/amber palette, dark theme as hero, Plus Jakarta Sans bundled.
- **Open design questions for Prashant:** (1) dark-as-default vs follow-system; (2) bundle
  font TTFs in repo — OK? (3) draw remaining 2 badges now or at F-15; (4) store tagline
  "Focus without the fight." kept or PM owns; (5) disclosure copy confirmed as PM-owned.

## 2026-07-02 · Brand v2, roadmap, website, blueprint audit

- Prashant's 7-point review: brand direction v2 (D-009 — no blue, charcoal+orange icon,
  neutral-to-light system); distinctive positioning vs crowded segment; website; epics/
  milestones roadmap; blueprint cleanup; blank-context resumability; parallel sessions.
- MOM-agent → orchestrator duty (unchanged); parallel work → D-010: Prashant opens worker
  sessions, main session stays for discussion. Dark-as-default question superseded by D-009.
- docs/ROADMAP.md created (E1–E7, M1–M6); stories stay in TASKBOARD (B-xx added).
- ux-designer executed B-01/B-02: v2 palette (Signal Orange/charcoal/Paper neutrals, sage
  recovery wash), all assets regenerated, broken-ring icon recommended over closed variant,
  website/index.html (single file, EN/DE toggle, no domain hardcoded).
- PM audit: 24 blueprint inconsistencies → planning/fokus-blueprint-specs.md with register.
- **Orchestrator flags:** trademark check for "Fokus" (CH/EU) before brand hardens; domain
  decision (fokus.app vs fokusapp.ch) blocks website links + waitlist inbox.
- **DECISION-NEEDED (from PM audit, awaiting Prashant):** D-A P0 definition vs billing P1;
  D-B priority column semantics; D-C lock-break/sub-10-min streak semantics; D-D paused/
  scheduled states exist?; D-E always-on apps (music/nav) whitelist policy; D-F AI
  micro-coaching = 6th recovery module or suggestion surface.
- **Action items:** Prashant — review brand v2 + website, answer D-A…D-F, icon variant
  sign-off, domain + waitlist inbox, trademark check, git locks + push. Orchestrator — next:
  F-01 scaffold (suggest worker session per D-010).
