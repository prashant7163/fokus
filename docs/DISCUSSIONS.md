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

## 2026-07-02 02:55–03:05 · No physical device — emulator strategy (D-012)

- Prashant has no Android device; Android Studio + emulator on his Mac is the test rig.
- D-012 recorded: emulator = M2 verification device (orchestrator drives Studio/emulator via
  screen control with approval). OEM battery-killer risk (QA row 9) moves to closed-track
  testers as exit criterion. Revisit if a physical Samsung/Xiaomi becomes available pre-launch.
- **Action items:** Orchestrator — after F-01 CI is green, dry-run the pipeline once (build →
  install scaffold on emulator) to fail fast on toolchain issues before F-03..F-05 land.

## 2026-07-02 02:55–03:15 · Worker session: F-02 + F-03 (kickoff prompt v2)

- Worker (mobile-developer + core author) executed Phase A sequentially per D-010.
- **F-02 → review:** Drift schema per CONTRACTS §3 — all 11 tables shipped at schemaVersion 1
  (incl. Phase 2 tables, to avoid migrations later); repositories for the Phase 1 tables;
  40 unit tests incl. a schema-contract guard test that pins table/column names verbatim
  from §3. Notable choices (implementation, not contract changes): `completionReason`
  values = timerEnd | finishedTask | lockBreak; `feedback_entries.text` kept as SQL name
  via Dart rename; app-lists repo enforces the D-011 "never in both lists" invariant.
- **F-03 → review:** native detection core. Accessibility service reads window-state
  changes only, `canRetrieveWindowContent=false` (privacy + Play policy). Blocked set +
  session config cached natively and persisted to SharedPreferences (hot path has zero
  channel traffic; survives process death). Intercept decision extracted into pure
  `InterceptDecider` (JVM-tested: session expiry, never-blockable incl. launcher/dialer,
  1.5 s per-app debounce). Channel handler implements full CONTRACTS §1 surface; payload
  shapes documented in-code for the F-06 Dart facade. InterceptActivity launch left as a
  TODO(F-05) seam. Native accessibility-service description strings (EN/DE) are
  policy-relevant → PM review flagged.
- **Toolchain notes:** sandbox still cannot reach pub.dev/dl.google.com → codegen + tests
  run in CI only; CI extended (build_runner, libsqlite3, gradle testDebugUnitTest —
  wrapper injected by flutter tool during APK build). Stale .git/HEAD.lock + index.lock
  found and removed (file-delete permission granted in-session); repo-local git identity set.
- **Deferred per M2 ruling:** F-03 <200 ms on-device criterion; row stays `review`.
- **Action items:** Prashant — watch CI run on push (F-02/F-03 verification gate).
  Next worker — F-04 (SessionForegroundService + BootReceiver + resilience); startSession/
  stopSession TODO(F-04) hooks are in BlockingChannelHandler.

## 2026-07-02 03:20–03:50 · Worker session: F-04 + F-05 (kickoff prompt v2)

- Worker (mobile-developer + core author) continued Phase A sequentially per D-010.
- **F-04 → review:** session resilience. SessionForegroundService — persistent countdown
  notification (silent channel), wall-clock anchored ticks at the session's own minute
  boundary, START_STICKY re-hydration from the prefs-backed BlockedSetCache, FGS type
  `specialUse` with a Play-review subtype declaration (no standard type covers app-blocking
  focus timers), and an accessibility-permission watch (emits permissionLost once — no silent
  failure). BootReceiver re-arms live sessions after reboot straight from prefs, engine-free.
  FokusEventBus now buffers restore-critical events (sessionRestored, permissionLost) until
  the Dart sink attaches. Pure SessionServicePlan logic, 10 JVM tests.
- **F-05 → review:** native intercept. Code-built UI (no inflation/androidx on the critical
  path) matching SCREENS §4 1:1 with DESIGN_SYSTEM v2 light literals; task-anchor card omitted
  cleanly when unset; countdown ticks. Proactive recovery hint at ≥ 3 attempts/5 min via pure
  AttemptTracker (JVM-tested); hint pre-selects Breathe. CTA wiring: Return→home; I'm stuck →
  recoveryRequested (CONTRACTS §1, buffered) + `fokus://recovery` deep link; Emergency exit →
  `fokus://exit`. Deep links use Flutter's own deep-linking (flutter_deeplinking_enabled) so
  cold AND warm engine are covered without touching CONTRACTS — **go_router must register
  `/recovery` and `/exit` (F-06/F-07/F-08 seam)**.
- **Judgment calls (implementation, not contract changes — flag if disagreeing):**
  (1) distractionAttempt + recoveryRequested events buffered (bounded 16) so engine-dead
  intercepts don't lose attempt data — spec calls it the product hypothesis; original ts
  travels with the event. (2) Intercept renders light-theme always, matching F-01's forced
  ThemeMode.light (D-009); revisit with F-12 theme toggle. (3) stopSession routes through
  onStartCommand so the FGS 5-second contract is honored.
- **Toolchain:** kotlinc unavailable in sandbox (release-assets/maven blocked by allowlist) —
  Kotlin verified by review; all XML machine-validated; CI (gradle testDebugUnitTest) is the
  gate. Stale .git locks appeared once mid-session; file-delete permission granted, cleared.
- **Deferred per M2/D-012:** F-04 kill/reboot device check, F-05 <200 ms cold render — both
  rows stay `review` with F-03.
- **Action items:** Prashant — watch CI on push (F-04/F-05 gate); PM — intercept + notification
  copy EN/DE review (with F-20). Next worker — F-06 (Dart session state machine + timer +
  channel facade); note the deep-link route seam and the buffered-event contract above;
  startSession/stopSession + event payload shapes documented in BlockingChannelHandler.

## 2026-07-02 11:20–11:50 · Worker session: F-06 (kickoff prompt v2)

- Worker (mobile-developer + core author) executed the keystone Dart task connecting
  F-02 (DB), F-03/F-04 (native services), F-05 (intercept).
- **F-06 → review:** Dart session engine. Pure `SessionMachine` encodes CONTRACTS §2 verbatim
  as a trigger→states table (8 legal edges; everything else throws IllegalSessionTransition);
  terminal edges leave from `active` only, so terminal outcomes reached mid-recovery are
  composed as resume → terminal (two legal steps, no new edge). `SessionController`
  (Riverpod Notifier) owns the lifecycle: wall-clock-anchored timer (remaining always derived
  from endEpochMs, recomputed on tick/app-resume — never accumulated), every transition
  persisted via the F-02 repositories, distractionAttempt rows written with original native ts,
  buffered-event replay handled idempotently (attempt dedupe on pkg|ts; restored/permission
  events state-guarded), sessionRestored → DB re-hydration with retroactive completion when
  endEpochMs passed while dead, permissionLost → failedPermissions + minimal notice field
  (F-12 owns full UI), emergency exit → aborted/emergency with no penalty. Channel facade
  matches BlockingChannelHandler.kt/FokusEventBus.kt payloads exactly. go_router: `/recovery`
  (forwards `?module=` from the intercept's proactive hint) + `/exit` registered; ExitScreen
  stub (F-08) added.
- **Judgment calls (implementation, not contract changes — flag if disagreeing):**
  (1) `SessionRepository.createSession` gained an optional caller-supplied `id` — native is
  armed before the row is written, so the id must exist first; on native failure no DB row is
  created and the machine returns to a fresh idle. (2) `pendingStart` is held in state during
  native arming to block concurrent double-starts; it remains never-persisted (transient per
  enums.dart). (3) Replayed attempts arriving after a retroactive completion are attributed
  to the most recent session whose window covers the original ts (+1 min grace); orphans drop.
- **CONTRACT GAP (escalation, per brief §8):** CONTRACTS §5 defines 10 analytics events but
  §3 defines no table/sink to record them. No schema invented; nothing is written. Needs a
  tech-lead/orchestrator ruling (likely ties into the D-012-adjacent telemetry question).
- **Toolchain:** sandbox still has no Flutter/Dart — tests written to the F-02 patterns
  (in-memory Drift, ProviderContainer overrides, fake adapter, injected clock/ticker); CI is
  the verification gate. Stale .git/HEAD.lock reappeared; file-delete permission granted
  in-session, cleared.
- **Action items:** Prashant — watch CI on push (F-06 gate). Orchestrator — rule on the §5
  analytics sink gap. Next worker — F-07 (recovery modules; `/recovery` route + preselected
  `module` param and `enterRecovery`/`resumeRecovery`/`abort` controller API are ready seams).

## 2026-07-02 11:50–12:00 · F-18 independent core review (code-reviewer agent)

- Reviewer (fresh-eyes, read-only) audited F-02…F-06: verdict **approve-with-fixes**,
  0 P0 / 4 P1 / 6 P2. Full report: docs/reviews/F-18-core-review.md.
- Verified clean by reading: channel payloads 1:1 both sides, state machine = CONTRACTS §2
  verbatim, schema guard, D-011 mutual exclusion, privacy/policy posture (no INTERNET,
  accessibility window-state only, specialUse FGS declared). Caveat: nothing compiled —
  CI stays the build gate.
- P1s: (A) 16-slot buffer can drop attempt data; (B) natural expiry leaves stale native
  cache; (C) stopSession no-ops on id mismatch; (D) replayed attempts misattribute via
  "most recent session". Orchestrator rulings recorded as D-013; fixes queued as F-22 (core).
- **Action items:** worker session — F-22 before or alongside F-07/F-08 (F-22 first if F-07
  not yet started); P2s opportunistic. Prashant — CI status still unconfirmed in main channel.

## 2026-07-02 12:30–12:40 · CI run #2 red → analyze fixes (main session)

- Prashant relayed CI run #2 failure (Analyze step, 4 findings). Orchestrator fixed inline —
  no gate weakening: (1) tables.dart recursive getter was a real anti-pattern — singleton
  CHECK moved to table-level customConstraints + new guard test inserting id=2 must fail;
  (2) Object? instead of dynamic in ChannelBlockingAdapter._parse; (3) overridden lifecycle
  param renamed back to `state`; (4) redundant enums import dropped in controller test.
- Test/assembleDebug/Kotlin steps were skipped after analyze failure — expect possible new
  findings on next push (run #3). CI run #1 was GREEN on 395779f → F-01 done.
- **Action items:** Prashant — push, watch run #3. Worker — F-22 (D-013) then F-07.

## 2026-07-02 12:45–12:55 · CI run #3 triage (main session)

- Run #3: analyze ✅, 4 failures in session_controller_test "restore & reconcile". Diagnosis:
  controller-side logic verified CORRECT (subscribes at build, serialized handlers, awaited
  hydration; native bus buffers pre-attach events in production). Test-side bug: 4 tests
  emitted events before anything built the controller — the fake's broadcast stream drops
  subscriber-less events; state() then built the controller mid-assertion → idle.
- Fix: `controller()` before emit in the 4 tests (mirrors app boot order) + `hasListener`
  assert in FakeBlockingAdapter.emit so this failure class is loud, not silent.
- **Action items:** Prashant — push, watch run #4 (Kotlin/assembleDebug still first-run
  territory). GitHub connector suggested for orchestrator self-serve CI logs.

## 2026-07-02 13:00–13:10 · CI run #4 GREEN — M1 done (main session)

- Run #4 green across the full pipeline (analyze, Dart tests, Kotlin JVM tests, assembleDebug)
  covering F-01…F-06 plus the run #2/#3 fixes. **Milestone M1 "It builds" done.**
- Taskboard: F-02, F-06 → done (CI-verified). F-03/F-04/F-05 remain `review` — their
  done-criteria need the M2 emulator pass (D-012), not more CI.
- **Next per plan:** worker session → F-22 (D-013 P1 fixes) then F-07 recovery flow / F-08
  exit flow. Prashant (at the Mac, ~20 min) → M2 emulator pass: start session in emulator,
  open blocked app, verify intercept, kill process, reboot. After F-07/F-08: M3.
- **Action items:** Prashant — M2 emulator session when convenient; GitHub connector still
  recommended for orchestrator CI self-serve. Worker — F-22 next.

## 2026-07-02 13:15–13:55 · Worker session — F-22 (D-013 P1 fixes) + F-07 (recovery flow)

Mobile-dev worker session, two tasks each with its own commit. Sandbox cannot run
flutter/gradle (network allowlist) — machine-validated what was possible (brace/JSON/ARB-parity
checks, full read of every touched file); **CI is the verification gate** for both.

**F-22 (D-013 P1 fixes) → review.** All four P1s implemented per the binding D-013 rulings:
- **P1-A** — persisted native `AttemptJournal` (SharedPreferences) for distractionAttempt/
  recoveryRequested: unbounded within a session, replayed on Dart attach, cleared only on ack.
  At-least-once + Dart `pkg|ts` idempotency; monotonic seq survives session clear so a stale ack
  can't match a new session. Restore-critical events keep the in-memory deque. Pure `JournalCore`
  JVM-tested (needs `org.json` test dep — added — since android.jar's is a throwing stub).
- **P1-B** — natural native expiry clears `BlockedSetCache` (pure `SessionServicePlan.clearsCacheOnStop`).
- **P1-C** — `stopSession` never silently no-ops: pure `StopDecision` stops whatever native
  session is live and emits a `stopMismatch` diagnostic with both ids; Dart reconciles (aborts an
  orphaned live session it still tracks, ExitReason.stuck).
- **P1-D** — attribution by timestamp window containment only (`sessionsStartedBefore`), never
  most-recent-regardless-of-window; unmatched attempts logged + discarded. Covered incl. the
  reviewer's misattribution scenario (old buffered attempt + newly started session → attaches to
  the correct old session, not the newer one).
- **CONTRACTS §1 addenda (flagged, D-013-sanctioned, NOT silently extended):** new MethodChannel
  method `ackEvents(upToSeq)` and new event `stopMismatch(requestedId, liveId)`. Tech-lead should
  fold these into CONTRACTS §1 + a DECISIONS note.
- **P2 sweep (files already touched):** P2-E (getMostRecentSession doc — clarified it is F-11-only,
  not attribution) DONE. Not swept (out of P1 scope / need schema or event-shape change): P2-B
  (getActiveSession single-row DB guard), P2-D (recoveryInvoked correlation — needs an event-shape
  change, belongs with F-07's recovery wiring but the correlation id is still absent).

**F-07 (recovery flow) → review.** POLISH-over-speed honored. 5 modules + hub, each ends
"Ready to continue?" → Resume/End. `RecoveryController` guarantees a RecoveryEvent row per
invocation, closed with a result on every path **including back-button/abandon (= exited)**.
Shrink goes through a new `SessionController.shrinkTo` (re-anchors the wall clock, stays `active`
— a config change, not a machine transition, so no new CONTRACTS §2 edge; unit-tested incl.
never-extends guard). l10n EN+DE zero-guilt copy, sage/calm styling, TalkBack labels, ≥48dp,
reduced-motion for breathe. **flutter_svg** added (pre-approved by orchestrator — needs a DECISIONS
entry) + recovery SVGs copied into `assets/recovery/`.
- **CONTRACT GAP (flagged, not invented):** Task-reset's "save the next step to session notes"
  (SCREENS §5.2) has no column — `focus_sessions` only has `taskAnchor` (the original intent, must
  not be overwritten). Persisting the note needs a CONTRACTS §3 column addition (tech-lead). Until
  then the step lives in the recovery flow only; the RecoveryEvent(taskReset) is still logged.
- **F-08 seam:** End-session routes toward `/exit` and aborts with `ExitReason.stuck` as the
  default (exitReason detail is F-08's; noted).

**Action items:** Orchestrator — DECISIONS entries for flutter_svg and for the ackEvents/
stopMismatch CONTRACTS §1 addenda; tech-lead ruling on the task-reset notes column and P2-D
correlation id. Prashant — push both commits, watch CI (real gate). After green: F-08 exit flow.

## 2026-07-02 14:15–14:45 · CI run #6 triage + first full local gate (main session)

- Run #6: analyze RED, 1 finding (unnecessary enums import, recovery_flow_test) — fixed.
- Flutter 3.44.2 is available on this Mac, so the full CI gate ran locally for the first
  time; it surfaced four issues CI had never reached (runs #5/#6 died before the test step):
  1. **FK constraints silently missing** from generated DDL: drift_dev 2.31 + analyzer 10
     parses the bare class name in `.references(FocusSessions, #id)` as a TypeLiteral and
     drops the REFERENCES clause with only a build warning (upstream fix lands in drift 2.34,
     blocked here by the sqlite3 2.x→3.x major chain). Fixed version-proof: the three FK
     columns now use explicit `customConstraint('NOT NULL REFERENCES …')`; F-02's FK test
     passes again. No schema/contract change — this restores what CONTRACTS §3 intends.
  2. **Toolchain skew, root cause of "green CI, red Mac":** pubspec.lock (committed in
     D-014, created under Dart 3.12) requires Dart ≥3.11; CI's Flutter 3.32.0 (Dart 3.8)
     silently re-resolved different package versions and generated different drift code.
     ci.yml bumped to Flutter 3.44.2 — the lockfile is now authoritative on both sides.
  3. **Real product bug (F-06/F-22 seam):** SessionController.start threw
     IllegalSessionTransition from a terminal state — after a completed session the user
     could never start another. start() now resets terminal → fresh idle first (machine
     unchanged; its own doc says a new session starts from a fresh idle).
  4. Two test-hygiene fixes: shrinkTo's never-extends no-op path now refreshes the
     wall-clock-derived `remaining`; recovery End-session widget test scrolls the button
     into view before tapping (600px test surface mis-tapped the footer's Resume).
- Full local gate green: analyze clean, 146 Dart tests, assembleDebug, Kotlin JVM tests.
- **Action items:** watch CI run #7 (should now mirror local exactly). Tech-lead (later,
  unhurried): evaluate the drift 2.34 + drift_flutter 0.3 + sqlite3 3.x upgrade to retire
  the customConstraint workaround.

## 2026-07-02 15:01 · CI run #7 GREEN (main session)

- Run #7 on 077d42d: full pipeline green (analyze, 146 Dart tests, assembleDebug, Kotlin
  JVM tests) — first run on the aligned toolchain (Flutter 3.44.2, lockfile honored).
  Prashant confirmed in-channel; verified via API (completed/success 14:56).
- Taskboard: **F-22 → done, F-07 → done** (their gates were CI). F-03/F-04/F-05 remain
  `review` awaiting the M2 emulator pass (D-012).
- **Next:** worker session — F-08 (structured exit flow; the `/exit` route, ExitScreen stub
  and abort-with-exitReason controller API are ready seams). Prashant — M2 emulator pass
  when convenient. Tech-lead (unhurried) — drift 2.34 upgrade evaluation to retire the
  customConstraint FK workaround (see 14:15 entry).

## 2026-07-02 15:05–15:15 · Handoff: Claude Code becomes the standing worker (main session)

- Prashant moved worker duty to Claude Code desktop (local toolchain: flutter, emulator,
  adb, gh — CI and Mac now aligned; run #7 green on 077d42d; F-22/F-07 done).
- Orchestrator issued the long-run worker prompt: F-08 → M2 emulator pass (now automatable
  locally, closes F-03/04/05) → M3 → retention layer F-09…F-12 → M4 + independent review
  subagent → Phase B F-13…F-17 → M5 → ship prep (B-03, F-20 drafts, QA matrix, release
  build config) → M6 → PUBLISH_READY.md handoff. Billing stays deferred (D-003).
- Standing approvals granted by Prashant for trivial permissions: push, CI iteration, deps
  (w/ DECISIONS entries), emulator/adb, font bundling (closes open question), l10n, P2
  sweeps. CONTRACTS changes allowed w/ same-commit DECISIONS entry. Still gated: destructive
  ops, signing keys, planning/ commits, disclosure/listing verbatim copy, product decisions.
- **Prashant-only remainder tracked for publish:** Play Console app, keystore/signing,
  verbatim copy approvals, screenshots sign-off, domain/waitlist/trademark, D-A/D-B/D-F,
  tester invites, rollout click.
