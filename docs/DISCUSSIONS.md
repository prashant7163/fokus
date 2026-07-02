# FOKUS — Discussion Record (MOM)

Minutes of Prashant ↔ orchestrator working sessions. Append-only, newest last. Purpose:
survive context compaction and give any fresh session the "why" behind recent moves.
Maintained by the orchestrator (standing duty — subagents cannot see conversations).

---

> Timestamps: Europe/Zurich. Entries before 2026-07-02 02:30 retrofitted (≈ = approximate).

## 2026-07-01 · (time not recorded) · Kickoff & scoping (backfilled)

- Reviewed FOKUS Product Requirements Blueprint v1.0 (now in planning/, local-only).
- **Decided:** scope = blueprint Phase 1 + 2; cross-platform ambition raised by Prashant;
  orchestrator recommended Flutter shell + native Kotlin blocking core → accepted (D-001).
- Discussed Apple FamilyControls entitlement risk and Google accessibility policy gates.
- Orchestrator gave candid product verdict: recovery system + exit-reason analytics are the
  defensible core; category has brutal retention; distribution is the real risk. Agreed the
  build validates one hypothesis: does in-flow recovery change behavior?

## 2026-07-02 ≈00:05–00:45 · Android-first, execution model, Step 0 (backfilled)

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

## 2026-07-02 ≈00:50–01:20 · Structure review (7 comments from Prashant)

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

## 2026-07-02 ≈01:25–01:50 · Brand v2, roadmap, website, blueprint audit

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

## 2026-07-02 ≈02:00–02:20 · Rulings D-C/D-D/D-E + monetization discussion

- **Prashant ruled (D-011):** lock-breaks/sub-10-min preserve (excuse) but never earn a streak
  day; no `paused` state; always-on apps handled via user allowlist asked at onboarding.
  Specs + CONTRACTS updated (allowlisted_apps table added).
- Git locks cleared by Prashant; worker session landed F-01 scaffold (D-010 model working).
- **Monetization discussed.** Orchestrator recommendation: NO ads ever (an attention-protection
  app selling attention is brand suicide; also negligible revenue at our scale). NO backend/
  accounts needed for monetization: Google Play Billing handles subscriptions + free/paid
  entitlement fully on-device, and Play Console provides conversion/churn/MRR analytics
  natively. Accounts/backend arrive only when features demand them (web unlock, rooms, sync,
  parental) — not for billing. Open telemetry question flagged: validation metrics (D7,
  recovery-resume) need opt-in anonymous analytics OR closed-beta tester exports — needs a
  ruling before Phase B ends (candidate D-012).

## 2026-07-02 ≈01:30–02:12 · Worker session: F-01 scaffold (per D-010)

- Prashant opened this second Cowork session as a build worker; instruction: "claim and
  execute F-01". Claimed on TASKBOARD, executed inline (core-owner work).
- Built: Flutter scaffold — M3 theme straight from DESIGN_SYSTEM.md v2 literals, go_router
  nav skeleton (6 feature stubs matching lib/features/* boundaries), Riverpod wiring,
  l10n EN/DE ARB pipeline, CONTRACTS §4 constants, Android embedding (ch.hoffely.fokus,
  Gradle KTS, gradle-wrapper jar/scripts gitignored per Flutter convention), CI workflow
  (Flutter 3.32.0 pinned: analyze, test, build apk --debug), tests.
- Sandbox constraints noted: no Flutter SDK available in-session (pub.dev/dl.google.com
  blocked by network allowlist) → Dart/Gradle could not be compiled locally. All
  JSON/XML/YAML validated; Dart verified by review only. CI is the real gate.
- Theme decisions within scope: `ThemeMode.light` per D-009 (toggle arrives with F-12);
  Plus Jakarta Sans NOT bundled (font decision still open with Prashant) — TextTheme ships
  metrics only; spec's deprecated `surfaceVariant` role carried as FokusColors.ringTrack.
- Dev launcher icon generated (charcoal + orange broken ring/dot) — placeholder until B-03.
- **F-01 status: review.** Done-criterion "green in CI" is blocked on Prashant's pending
  action item: push repo to GitHub. Once pushed, first Actions run verifies; any fixes are
  small follow-ups under F-01.
- **Action items:** Prashant — push to GitHub, watch first CI run. Orchestrator — mark F-01
  done after CI green; F-02 (Drift schema) is next core task.

## 2026-07-02 02:30–02:50 · Timestamps, worker restart protocol, M2 deferral

- Prashant: (1) timestamps now required in CHANGELOG/DISCUSSIONS/DECISIONS — done, historical
  entries retrofitted from commit times (≈ where approximate); (2) worker kickoff prompt to
  include a context-checkpoint step — added as v2 prompt (worker cannot run /compact on
  itself; it checkpoints at task boundaries and signals Prashant to compact/restart);
  (3) repo pushed, CI gate for F-01 now live on GitHub Actions; (4) M2 on-device verification
  deferred until Prashant returns — recorded in ROADMAP; build proceeds on emulator/unit
  evidence, F-03..F-05 stay `review` until device pass.
- **Action items:** Prashant — watch first Actions run (F-01 → done if green), device pass for
  M2 when back, font ruling (bundle Plus Jakarta Sans: orchestrator recommends yes).
  Worker — use kickoff prompt v2 (in this entry's session, stored in CLAUDE.md workflow ref).
